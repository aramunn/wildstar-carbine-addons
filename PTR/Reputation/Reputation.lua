-----------------------------------------------------------------------------------------------
-- Client Lua Script for Reputation
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

local Reputation = {}

local karRepToColor =
{
	ApolloColor.new("ff9aaea3"),
	ApolloColor.new("ff9aaea3"), -- Neutral
	ApolloColor.new("ff836725"), -- Liked
	ApolloColor.new("ffc1963d"), -- Accepted
	ApolloColor.new("fff1efda"), -- Popular
	ApolloColor.new("fffefbb5"), -- Esteemed
	ApolloColor.new("ffd5b66d"), -- Beloved
}

function Reputation:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Reputation:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- Reputation OnLoad
-----------------------------------------------------------------------------------------------

function Reputation:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Reputation.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Reputation:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("GenericEvent_InitializeReputation", "OnGenericEvent_InitializeReputation", self)
	Apollo.RegisterEventHandler("GenericEvent_DestroyReputation", "OnGenericEvent_DestroyReputation", self)
	Apollo.RegisterEventHandler("ReputationChanged", "OnReputationChanged", self)
end

function Reputation:OnGenericEvent_InitializeReputation(wndParent)
	if self.wndMain and self.wndMain:IsValid() then
		self:ResetData()
		self:PopulateFactionList()
		return
	end

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "ReputationForm", wndParent, self)
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.tReputationLevels = GameLib.GetReputationLevels()
	self.tStrToWndMapping = {}

	-- Default Height Constants
	-- nContainerTop - nBottom - nButtonBottom twice for top and bottom margin
	local wndHeight = Apollo.LoadForm(self.xmlDoc, "ListItemLabel", self.wndMain, self)
	local nLeft, nTop, nRight, nBottom = wndHeight:GetAnchorOffsets()
	local nButtonBottom = ({wndHeight:FindChild("ItemsBtn"):GetAnchorOffsets()})[4]
	local nContainerTop = ({wndHeight:FindChild("ItemsContainer"):GetAnchorOffsets()})[2]
	self.knHeightLabel = nBottom - nTop
	self.knExpandedHeightLabel = (nBottom - nTop) + (nContainerTop - nBottom - nButtonBottom) + (nContainerTop - nBottom - nButtonBottom)
	wndHeight:Destroy()

	wndHeight = Apollo.LoadForm(self.xmlDoc, "ListItemProgress", self.wndMain, self)
	nLeft, nTop, nRight, nBottom = wndHeight:GetAnchorOffsets()
	self.knHeightProgress = nBottom - nTop
	wndHeight:Destroy()

	wndHeight = Apollo.LoadForm(self.xmlDoc, "ListItemTopLevel", self.wndMain, self)
	nLeft, nTop, nRight, nBottom = wndHeight:GetAnchorOffsets()
	nButtonBottom = ({wndHeight:FindChild("ItemsBtn"):GetAnchorOffsets()})[4]
	nContainerTop = ({wndHeight:FindChild("ItemsContainer"):GetAnchorOffsets()})[2]
	self.knHeightTop = nBottom - nTop

	-- nContainerTop - nBottom - nButtonBottom twice for top and bottom margin + extra
	self.knExpandedHeightTop = (nBottom - nTop) + (nContainerTop - nBottom - nButtonBottom) + (nContainerTop - nBottom - nButtonBottom) + 35
	wndHeight:Destroy()

	self.tRepCount = 0

	self.tTopLabels = {}
	self.tSubLabels = {}
	self.tProgress	= {}

	self:ResetData()
	self:PopulateFactionList()
end

-----------------------------------------------------------------------------------------------
-- Reputation Functions
-----------------------------------------------------------------------------------------------

function Reputation:OnReputationChanged(tFaction)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	if self.tStrToWndMapping[tFaction.strParent] then -- Find if the parent and it exists
		for key, wndCurr in pairs(self.tStrToWndMapping[tFaction.strParent]:FindChild("ItemsContainer"):GetChildren()) do
			if wndCurr:GetData() == Apollo.StringToLower(tFaction.nOrder .. tFaction.strName) then
				self:BuildListItemProgress(wndCurr, tFaction)
				return
			end
		end
	end

	-- Add a new entry in the full redraw if we didn't find the parent or itself
	self:ResetData()
	self:PopulateFactionList()
end

function Reputation:OnGenericEvent_DestroyReputation()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
		self.tStrToWndMapping = {}
	end
end

function Reputation:ResetData()
	self.tStrToWndMapping = {}
	self.wndMain:FindChild("FactionList"):DestroyChildren()
end

function Reputation:SortReps(tRepTable)
	self.tTopLabels = {}
	self.tSubLabels = {}
	self.tProgress = {}
	for idx, tReputation in pairs(tRepTable) do
		local bHasParent = tReputation.strParent and Apollo.StringLength(tReputation.strParent) > 0
		if not bHasParent then
			table.insert(self.tTopLabels, tReputation)
		elseif tReputation.bIsLabel then
			table.insert(self.tSubLabels, tReputation)
		else
			table.insert(self.tProgress, tReputation)
		end
	end
end

function Reputation:PopulateFactionList()
	local tReputations = GameLib.GetReputationInfo()
	if not tReputations then
		return
	end

	self.tRepCount = #tReputations
	self:SortReps(tReputations)

	local nSafetyCount = 0
	for idx, tReputation in pairs(self.tTopLabels) do
		nSafetyCount = nSafetyCount + 1
		if nSafetyCount < 99 then
			self:BuildFaction(tReputation, nil)
		end
	end

	for idx, tReputation in pairs (self.tSubLabels) do
		nSafetyCount = nSafetyCount + 1
		if nSafetyCount < 99 then
			self:BuildFaction(tReputation, self.tStrToWndMapping[tReputation.strParent])
		end
	end

	for idx, tReputation in pairs (self.tProgress) do
		nSafetyCount = nSafetyCount + 1
		if nSafetyCount < 99 then
			self:BuildFaction(tReputation, self.tStrToWndMapping[tReputation.strParent])
		end
	end

	-- Else condition is bHasParent but not mapped yet, in which case we try again later
	if nSafetyCount >= 99 then
		for idx, tFaction in pairs(tReputations) do
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, String_GetWeaselString(Apollo.GetString("Reputation_NotFound"), tFaction.strParent))
		end
	end

	-- Sort list
	for key, wndCurr in pairs(self.tStrToWndMapping) do
		wndCurr:FindChild("ItemsContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return (a:GetData() < b:GetData()) end)
	end
	self.wndMain:FindChild("FactionList"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return (a:GetData() < b:GetData()) end)

	self:ResizeItemContainer()
end

function Reputation:BuildFaction(tFaction, wndParent)
	-- This method is agnostic to what level it is at. It must work for level 2 and level 3 data and thus the XML has the same window names at all levels.
	if wndParent and not wndParent:FindChild("ItemsBtn"):IsChecked() then
		return
	end

	local wndCurr = nil
	-- There are 3 types of windows: Progress Bar, Labels with children, and Top Level (which has different bigger button art)
	if not wndParent then
		wndCurr = Apollo.LoadForm(self.xmlDoc, "ListItemTopLevel", self.wndMain:FindChild("FactionList"), self)
		wndCurr = self:BuildTopLevel(wndCurr, tFaction)
	elseif tFaction.bIsLabel then
		wndCurr = Apollo.LoadForm(self.xmlDoc, "ListItemLabel", wndParent:FindChild("ItemsContainer"), self)
		wndCurr:FindChild("ItemsBtn"):SetCheck(true)
		wndCurr:FindChild("ItemsBtnText"):SetText(tFaction.strName)
		self.tStrToWndMapping[tFaction.strName] = wndCurr
	else
		wndCurr = Apollo.LoadForm(self.xmlDoc, "ListItemProgress", wndParent:FindChild("ItemsContainer"), self)
		wndCurr = self:BuildListItemProgress(wndCurr, tFaction)
	end

	-- This data is used for sorting (First by Order then by Name if there is a tie. Lua's "<" operator will handle this on string comparisons.)
	wndCurr:SetData(Apollo.StringToLower(tFaction.nOrder .. tFaction.strName))
end

function Reputation:BuildTopLevel(wndCurr, tFaction)
	wndCurr:FindChild("ItemsBtn"):SetCheck(true)
	wndCurr:FindChild("ItemsBtnText"):SetText(tFaction.strName)
	wndCurr:FindChild("BaseProgressLevelBarC"):Show(not tFaction.bIsLabel)
	if not tFaction.bIsLabel then
		local tLevelData = self.tReputationLevels[tFaction.nLevel]
		wndCurr:FindChild("BaseProgressLevelBar"):SetMax(tLevelData.nMax)
		wndCurr:FindChild("BaseProgressLevelBar"):SetProgress(tFaction.nCurrent)
		wndCurr:FindChild("BaseProgressLevelText"):SetText(String_GetWeaselString(Apollo.GetString("TargetFrame_TextProgress"), Apollo.FormatNumber(tFaction.nCurrent, 0, true), Apollo.FormatNumber(tLevelData.nMax, 0, true)))
	end
	
	self.tStrToWndMapping[tFaction.strName] = wndCurr
	return wndCurr
end

function Reputation:BuildListItemProgress(wndCurr, tFaction)
	local tLevelData = self.tReputationLevels[tFaction.nLevel]
	wndCurr:FindChild("ProgressName"):SetText(tFaction.strName)
	wndCurr:FindChild("ProgressStatus"):SetText(tLevelData.strName)
	wndCurr:FindChild("ProgressStatus"):SetTextColor(karRepToColor[tFaction.nLevel + 1])
	wndCurr:FindChild("ProgressLevelBar"):SetMax(tLevelData.nMax)
	wndCurr:FindChild("ProgressLevelBar"):SetProgress(tFaction.nCurrent)
	wndCurr:FindChild("ProgressLevelBar"):SetBarColor(karRepToColor[tFaction.nLevel + 1])
	wndCurr:FindChild("ProgressLevelBar"):EnableGlow(tFaction.nCurrent > tLevelData.nMin)
	wndCurr:SetTooltip(string.format("%s/%s", Apollo.FormatNumber(tFaction.nCurrent, 0, true), Apollo.FormatNumber(tLevelData.nMax,0,true)))

	local strTooltip = String_GetWeaselString(Apollo.GetString("Reputation_ProgressText"), tFaction.strName, tLevelData.strName, Apollo.FormatNumber(tFaction.nCurrent, 0, true), Apollo.FormatNumber(tLevelData.nMax,0,true))
	return wndCurr
end

-----------------------------------------------------------------------------------------------
-- Resize Code
-----------------------------------------------------------------------------------------------

function Reputation:OnTopLevelToggle(wndHandler, wndControl) -- wndHandler is "ListItemTopLevel's ItemsBtn"
	self:ResizeItemContainer()
end

function Reputation:OnMiddleLevelLabelToggle(wndHandler, wndControl) -- wndHandler "ListItemLabel's ItemsBtn"
	self:ResizeItemContainer()
end

function Reputation:ResizeItemContainer()
	for key, wndTopGroup in pairs(self.wndMain:FindChild("FactionList"):GetChildren()) do
		local wndTopContainer = wndTopGroup:FindChild("ItemsContainer")
		local wndTopButton = wndTopGroup:FindChild("ItemsBtn")
		
		wndTopGroup:Show(#wndTopContainer:GetChildren() > 0)
		if wndTopGroup:IsShown() then
			local nTopHeight = self.knHeightTop

			local nMiddleHeight = 0
			wndTopContainer:Show(wndTopButton:IsChecked())
			
			local bEnableTop = false
			if wndTopButton:IsChecked() then
				nTopHeight = self.knExpandedHeightTop
				local bEnableMid = false
				for idx, wndMiddleGroup in pairs(wndTopContainer:GetChildren()) do
					local wndMiddleContainer = wndMiddleGroup:FindChild("ItemsContainer")
					local wndMiddleButton = wndMiddleGroup:FindChild("ItemsBtn")
					wndMiddleGroup:Show(not wndMiddleContainer or #wndMiddleContainer:GetChildren() > 0)

					if wndMiddleGroup:IsShown() then
						local nBottomHeight = 0
						local nHeightToUse = self.knHeightProgress
						

						-- Special formatting if it has a container (different height, show/hide, and arrange vert)
						if wndMiddleContainer then
							nHeightToUse = self.knHeightLabel
							
							wndMiddleContainer:Show(wndMiddleButton:IsChecked())
							
							if wndMiddleButton:IsChecked() then
								nBottomHeight = self.knHeightProgress * #wndMiddleContainer:GetChildren()
								nHeightToUse = self.knExpandedHeightLabel
							end
							
							if #wndMiddleContainer:GetChildren() > 0 and not bEnableMid then
								bEnableMid = true
							end
							
							wndMiddleContainer:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
						end
						-- End special formatting

						local nLeft, nTop, nRight, nBottom = wndMiddleGroup:GetAnchorOffsets()
						wndMiddleGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nBottomHeight + nHeightToUse)
						nMiddleHeight = nMiddleHeight + nBottomHeight + nHeightToUse
						
						if wndMiddleButton then
							if not bEnableMid then
								wndMiddleButton:SetCheck(false)
							end
							wndMiddleButton:Enable(bEnableMid)
						end
						
						if not bEnableTop then
							bEnableTop = true
						end
					end
				end
				if not bEnableTop then
					wndTopButton:SetCheck(false)
				end
				wndTopButton:Enable(bEnableTop)
			end

			local nLeft, nTop, nRight, nBottom = wndTopGroup:GetAnchorOffsets()
			wndTopGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nMiddleHeight + nTopHeight)
			wndTopGroup:FindChild("ItemsContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
		end
	end

	self.wndMain:FindChild("FactionList"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
end

local ReputationInst = Reputation:new()
ReputationInst:Init()
