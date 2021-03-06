-----------------------------------------------------------------------------------------------
-- Client Lua Script for RewardIcons
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- RewardIcons Module Definition
-----------------------------------------------------------------------------------------------
RewardIcons = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local karRewardIcons =
{
	[Unit.CodeEnumRewardInfoType.Quest] 			= { strName = "Quest", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_ActiveQuest", 	strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_ActiveQuestMulti" },
	[Unit.CodeEnumRewardInfoType.Challenge] 		= { strName = "Challenge", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_Challenge", 		strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_ChallengeMulti" },
	[Unit.CodeEnumRewardInfoType.Explorer] 		= { strName = "Explorer", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathExp", 		strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathExpMulti" },
	[Unit.CodeEnumRewardInfoType.Scientist] 		= { strName = "Scientist", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSci",			strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSciMulti" },
	[Unit.CodeEnumRewardInfoType.Soldier] 		= { strName = "Soldier", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSol", 		strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSolMulti" },
	[Unit.CodeEnumRewardInfoType.Settler] 		= { strName = "Settler", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSet", 		strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSetMulti" },
	[Unit.CodeEnumRewardInfoType.PublicEvent] 	= { strName = "PublicEvent", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PublicEvent", 	strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PublicEventMulti" },
	[Unit.CodeEnumRewardInfoType.Rival] 			= { strName = "Rival", strSingle = "ClientSprites:Icon_Windows_UI_CRB_Rival", 							strMulti = "ClientSprites:Icon_Windows_UI_CRB_Rival" },
	[Unit.CodeEnumRewardInfoType.Friend] 			= { strName = "Friend", strSingle = "ClientSprites:Icon_Windows_UI_CRB_Friend", 						strMulti = "ClientSprites:Icon_Windows_UI_CRB_Friend" },
	[Unit.CodeEnumRewardInfoType.ScientistSpell]	= { strName = "ScientistSpell", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSciSpell",	strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSciSpell" },
	[Unit.CodeEnumRewardInfoType.TSpell]			= { strName = "TSpell", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_ActiveQuest",		strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_ActiveQuestMulti" },
	[Unit.CodeEnumRewardInfoType.Contract]			= { strName = "Contract", strSingle = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_Contract",		strMulti = "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_ContractMulti" },
}

local knDefaultIconWidth = 22
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function RewardIcons:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function RewardIcons:Init()
	Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- RewardIcons OnLoad
-----------------------------------------------------------------------------------------------
function RewardIcons:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RewardIcons.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function RewardIcons:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	self:CreateCallNames()
	
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		self:CreateCallNames()
		
		self:OnKeyBindingUpdated("Path Action")
		self:OnKeyBindingUpdated("Cast Objective Ability")
		
		Apollo.RegisterEventHandler("KeyBindingKeyChanged", "OnKeyBindingUpdated", self)
		Apollo.RegisterEventHandler("PublicEventObjectiveUpdate", "OnObjectiveUpdate", self)
		return Apollo.AddonLoadStatus.Loaded
	end
	return Apollo.AddonLoadStatus.Loading 
end

function RewardIcons:OnObjectiveUpdate(peoUpdated)
	self.peoLastUpdated = peoUpdated
end

function RewardIcons:OnKeyBindingUpdated(strKeybind)
	if strKeybind ~= "Path Action" and strKeybind ~= "Cast Objective Ability" then
		return
	end

	self.strPathActionKeybind = GameLib.GetKeyBinding("PathAction")
	self.bPathActionUsesIcon = false
	if self.strPathActionKeybind == "Unbound" or #self.strPathActionKeybind > 1 then -- Don't show interact
		self.bPathActionUsesIcon = true
	end

	self.strQuestActionKeybind = GameLib.GetKeyBinding("CastObjectiveAbility")
	self.bQuestActionUsesIcon = false
	if self.strQuestActionKeybind == "Unbound" or #self.strQuestActionKeybind > 1 then -- Don't show interact
		self.bQuestActionUsesIcon = true
	end
end

function RewardIcons:HelperDrawRewardTooltip(tRewardInfo, wndRewardIcon, strBracketText, strUnitName, tRewardString)
	if not tRewardInfo or not wndRewardIcon then
		return
	end
	tRewardString = tRewardString or ""

	local strMessage = tRewardInfo.strTitle
	if tRewardInfo.pmMission and tRewardInfo.pmMission:GetName() then
		local pmMission = tRewardInfo.pmMission
		if tRewardInfo.bIsActivated and PlayerPathLib.GetPlayerPathType() ~= PlayerPathLib.PlayerPathType_Explorer then -- todo: see if we can remove this requirement
			strMessage = String_GetWeaselString(Apollo.GetString("Nameplates_ActivateForMission"), pmMission:GetName())
		else
			strMessage = String_GetWeaselString(Apollo.GetString("TargetFrame_MissionProgress"), pmMission:GetName(), pmMission:GetNumCompleted(), pmMission:GetNumNeeded())
		end
	end

	local strProgress = ""
	local nNeeded = tRewardInfo.nNeeded
	local nCompleted = tRewardInfo.nCompleted
	local bShowCount = tRewardInfo.bShowCount
	local bShowPercent = false
	
	if tRewardInfo.eType == Unit.CodeEnumRewardInfoType.PublicEvent and tRewardInfo.peoObjective ~= nil then
		bShowPercent = tRewardInfo.peoObjective:ShowPercent()
	end
	
	if nCompleted ~= nil and nNeeded ~= nil and nNeeded > 0 then
		if bShowCount then
			strProgress = String_GetWeaselString(Apollo.GetString("TargetFrame_Progress"), nCompleted, nNeeded)
		else
			strProgress = String_GetWeaselString(Apollo.GetString("TargetFrame_ProgressPercent"), nCompleted)
		end
	end

	local strNewEntry = ""
	if wndRewardIcon:IsShown() then -- already have a tooltip
		strNewEntry = string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("TargetFrame_RewardProgressTooltip"), strBracketText, strMessage, strProgress))
		tRewardString = tRewardString .. strNewEntry
	else
		strNewEntry = string.format("<P Font=\"CRB_InterfaceMedium\" TextColor=\"Yellow\">%s</P><P Font=\"CRB_InterfaceMedium\">%s</P>", String_GetWeaselString(Apollo.GetString("TargetFrame_UnitText"), strUnitName, strBracketText), String_GetWeaselString(Apollo.GetString("TargetFrame_ShortProgress"), strMessage, strProgress))
		tRewardString = tRewardString .. strNewEntry
		wndRewardIcon:SetTooltip(tRewardString)
	end

	return tRewardString
end

function RewardIcons:HelperDrawBasicRewardTooltip(wndRewardIcon, strBracketText, strUnitName, tRewardString)
	if not wndRewardIcon then
		return
	end
	tRewardString = tRewardString or ""

	return string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</P>", tRewardString, strBracketText)
end

function RewardIcons:HelperLoadRewardIcon(wndRewardPanel, eType)
	local wndCurr = wndRewardPanel:FindChild(karRewardIcons[eType].strName)
	if wndCurr then
		return wndCurr
	end

	wndCurr = Apollo.LoadForm(self.xmlDoc, "RewardIcon", wndRewardPanel, self)
	wndCurr:SetName(karRewardIcons[eType].strName)
	wndCurr:Show(false) -- Visibility is important

	wndCurr:FindChild("Single"):SetSprite(karRewardIcons[eType].strSingle)
	wndCurr:FindChild("Multi"):SetSprite(karRewardIcons[eType].strMulti)

	return wndCurr
end

function RewardIcons:HelperDrawRewardIcon(wndRewardIcon)
	if not wndRewardIcon then
		return 0
	end
	local nResult = 0

	if wndRewardIcon:FindChild("Multi") then -- Show multi if the Single icon if the window is already visible
		wndRewardIcon:FindChild("Multi"):Show(wndRewardIcon:IsShown())
		wndRewardIcon:FindChild("Multi"):ToFront()
	end

	if not wndRewardIcon:IsShown() then -- Plus one to the counter if this is the first instance
		nResult = 1
	end

	wndRewardIcon:Show(true) -- At the very end
	return nResult
end

function RewardIcons:HelperDrawSpellBind(wndIcon, eType)
	wndIcon:FindChild("Single"):Show(false)
	wndIcon:FindChild("Multi"):Show(false)
	wndIcon:FindChild("TargetMark"):Show(false)
	wndIcon:FindChild("Bind"):SetText("")
	
	if eType ~= Unit.CodeEnumRewardInfoType.Quest and eType ~= Unit.CodeEnumRewardInfoType.Contract then -- paths, not quest or contract
		if self.bPathActionUsesIcon then
			wndIcon:FindChild("TargetMark"):Show(true)
		else
			wndIcon:FindChild("Bind"):SetText(self.strPathActionKeybind)
		end
	else -- quest
		if self.bQuestActionUsesIcon then
			wndIcon:FindChild("TargetMark"):Show(true)
		else
			wndIcon:FindChild("Bind"):SetText(self.strQuestActionKeybind)
		end
	end
end

function RewardIcons:HelperFlagOrDefault(tFlags, strFlagName, default)
	if tFlags == nil or tFlags[strFlagName] == nil then
		return default
	end
	
	return tFlags[strFlagName]
end

function RewardIcons:TableEquals(tData1, tData2)
   if tData1 == tData2 then
       return true
   end
   local strType1 = type(tData1)
   local strType2 = type(tData2)
   if strType1 ~= strType2 then
	   return false
   end
   if strType1 ~= "table" or strType2 ~= "table" then
       return false
   end
   for key, value in pairs(tData1) do
       if value ~= tData2[key] and not self:TableEquals(value, tData2[key]) then
           return false
       end
   end
   for key in pairs(tData2) do
       if tData1[key] == nil then
           return false
       end
   end
   return true
end

--[[
Example tFlags:
tFlags =
{
	bVert = true,
	bHideQuests = false,
	bHideChallenges = false,
	bHideMissions = false,
	bHidePublicEvents = false,
	bHideRivals = false,
	bHideFriends = false
}
]]--
function RewardIcons:GenerateUnitRewardIconsForm(wndRewardPanel, unitTarget, tFlags)
	local bIsFriend = unitTarget:IsFriend()
	local bIsRival = unitTarget:IsRival()
	local bIsAccountFriend = false--unitTarget:IsAccountFriend()
	local nFriendshipCount = (bIsFriend and 1 or 0) + (bIsRival and 1 or 0) + (bIsAccountFriend and 1 or 0)

	local tRewardInfo = unitTarget:GetRewardInfo()
	if tRewardInfo == nil and nFriendshipCount == 0 then
		if next(wndRewardPanel:GetChildren()) ~= nil then
			wndRewardPanel:SetData({ ["unitTarget"] = unitTarget })
			wndRewardPanel:DestroyChildren()
		end

		return
	end

	local tRewardString = {} -- temp table to store quest descriptions (builds multi-objective tooltips)

	local tWndRewardPanelData = wndRewardPanel:GetData()
	local nActiveRewardCount = 0
	local nRewardCount = (tRewardInfo ~= nil and #tRewardInfo or 0)
	local tExistingRewardInfo = nil
	local nExistingRewardCount = 0
	local unitExistingTarget = nil
	local tExistingFlags = nil
	local tLastCompleted = { }
	if tWndRewardPanelData ~= nil then
		nExistingRewardCount = tWndRewardPanelData.nIcons
		tExistingRewardInfo = tWndRewardPanelData.tRewardInfo or {}
		unitExistingTarget = tWndRewardPanelData.unitTarget
		tExistingFlags = tWndRewardPanelData.tFlags or {}
		tLastCompleted = tWndRewardPanelData.tLastCompleted or {}
	end
	
	wndRewardPanel:SetData({ 
		["unitTarget"] = unitTarget,
		["nIcons"] = nRewardCount + nFriendshipCount,
		["tFlags"] = tFlags,
		["tRewardInfo"] = tRewardInfo,
		["tLastCompleted"] = tLastCompleted,
	})

	local nCount = nil
	if self.peoLastUpdated ~= nil then
		nCount = self.peoLastUpdated:GetCount()
	end
	local nUnitId = unitTarget:GetId()
	if unitTarget == unitExistingTarget and nRewardCount + nFriendshipCount == nExistingRewardCount
			and self:TableEquals(tRewardInfo, tExistingRewardInfo) and self:TableEquals(tFlags, tExistingFlags) 
			and tLastCompleted[nUnitId] == nCount then
		return
	end
	
	wndRewardPanel:DestroyChildren()
	
	if nRewardCount > 0 then
		for idx = 1, nRewardCount do
			local eType = tRewardInfo[idx].eType

			if tRewardString[eType] == nil then
				tRewardString[eType] = ""
			end
			
			if eType == Unit.CodeEnumRewardInfoType.Quest and not self:HelperFlagOrDefault(tFlags, "bHideQuests", false) then
				local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eType)
				nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)
				tRewardString[eType] = self:HelperDrawRewardTooltip(tRewardInfo[idx], wndCurr, Apollo.GetString("CRB_Quest"), unitTarget:GetName(), tRewardString[eType])
				wndCurr:SetTooltip(tRewardString[eType])
				wndCurr:ToFront()
				if tRewardInfo[idx].splObjective then
					local wndTSpell = self:HelperLoadRewardIcon(wndRewardPanel, Unit.CodeEnumRewardInfoType.TSpell)
					nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndTSpell)
					tRewardString[Unit.CodeEnumRewardInfoType.TSpell] = self:HelperDrawRewardTooltip(tRewardInfo[idx], wndCurr, Apollo.GetString("CRB_Quest"), unitTarget:GetName(), tRewardString[Unit.CodeEnumRewardInfoType.TSpell])
					wndTSpell:SetTooltip(tRewardString[Unit.CodeEnumRewardInfoType.TSpell])
					wndTSpell:ToFront()
					self:HelperDrawSpellBind(wndTSpell, eType)
				end
			elseif eType == Unit.CodeEnumRewardInfoType.Contract and not self:HelperFlagOrDefault(tFlags, "bHideQuests", false) then
				local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eType)
				nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)
				tRewardString[eType] = self:HelperDrawRewardTooltip(tRewardInfo[idx], wndCurr, Apollo.GetString("CRB_Contract"), unitTarget:GetName(), tRewardString[eType])
				wndCurr:SetTooltip(tRewardString[eType])
				wndCurr:ToFront()
				if tRewardInfo[idx].splObjective then
					local wndTSpell = self:HelperLoadRewardIcon(wndRewardPanel, Unit.CodeEnumRewardInfoType.TSpell)
					nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndTSpell)
					tRewardString[Unit.CodeEnumRewardInfoType.TSpell] = self:HelperDrawRewardTooltip(tRewardInfo[idx], wndCurr, Apollo.GetString("CRB_Contract"), unitTarget:GetName(), tRewardString[Unit.CodeEnumRewardInfoType.TSpell])
					wndTSpell:SetTooltip(tRewardString[Unit.CodeEnumRewardInfoType.TSpell])
					wndTSpell:ToFront()
					self:HelperDrawSpellBind(wndTSpell, eType)
				end
			elseif eType == Unit.CodeEnumRewardInfoType.Challenge and not self:HelperFlagOrDefault(tFlags, "bHideChallenges", false) then
					local clgActive = nil

				local tAllChallenges = ChallengesLib.GetActiveChallengeList()
				for index, clgCurr in pairs(tAllChallenges) do
					if tRewardInfo[idx].idChallenge == clgCurr:GetId() and clgCurr:IsActivated() and not clgCurr:IsInCooldown() then
						clgActive = clgCurr
						break
					end
				end

				if clgActive then
					local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eType)
					nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)
					
					local strTempTitle = ""
					if clgActive:ShouldDisplayPercentProgress() then
						strTempTitle = self:HelperDrawRewardTooltip(tRewardInfo[idx], wndCurr, Apollo.GetString("CBCrafting_Challenge"), unitTarget:GetName(), tRewardString[eType])
					else
						strTempTitle = String_GetWeaselString(Apollo.GetString("BuildMap_CategoryProgress"), clgActive:GetName(), clgActive:GetCurrentCount(), clgActive:GetTotalCount())
					end
					
					tRewardString[eType] = string.format("%s<P Font=\"CRB_InterfaceMedium\">%s</P>", tRewardString[eType], strTempTitle)
					
					wndCurr:SetTooltip(tRewardString[eType])
				end
			elseif eType == Unit.CodeEnumRewardInfoType.Soldier or eType == Unit.CodeEnumRewardInfoType.Settler or eType == Unit.CodeEnumRewardInfoType.Explorer and not self:HelperFlagOrDefault(tFlags, "bHideMissions", false) then
				local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eType)
				nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)
				tRewardString[eType] = self:HelperDrawRewardTooltip(tRewardInfo[idx], wndCurr, Apollo.GetString("Nameplates_Mission"), unitTarget:GetName(), tRewardString[eType])
			

				wndCurr:SetTooltip(tRewardString[eType])

				if tRewardInfo[idx].splReward then
					self:HelperDrawSpellBind(wndCurr, eType)
				end	
			elseif eType == Unit.CodeEnumRewardInfoType.Scientist and not self:HelperFlagOrDefault(tFlags, "bHideMissions", false) then
				local pmMission = tRewardInfo[idx].pmMission
				local splSpell = tRewardInfo[idx].splReward

				if pmMission then
					local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eType)

					local strMission = ""
					if pmMission:GetMissionState() >= PathMission.PathMissionState_Unlocked then
						if pmMission:GetType() == PathMission.PathMissionType_Scientist_FieldStudy then
							strMission = String_GetWeaselString(Apollo.GetString("TargetFrame_MissionProgress"), pmMission:GetName(), pmMission:GetNumCompleted(), pmMission:GetNumNeeded())
							local tActions = pmMission:GetScientistFieldStudy()
							if tActions then
								for idx, tEntry in ipairs(tActions) do
									if not tEntry.bIsCompleted then
										strMission = String_GetWeaselString(Apollo.GetString("TargetFrame_FieldStudyAction"), strMission , tEntry.strName)
									end
								end
							end
						else
							strMission = String_GetWeaselString(Apollo.GetString("TargetFrame_MissionProgress"), pmMission:GetName(), pmMission:GetNumCompleted(), pmMission:GetNumNeeded())
						end
					else
						strMission = Apollo.GetString("TargetFrame_UnknownReward")
					end

					nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)

					local strProgress = "" -- specific to #7
					local strUnitName = unitTarget:GetName() -- specific to #7
					local strBracketText = Apollo.GetString("Nameplates_Missions") -- specific to #7
					if wndCurr:IsShown() then -- already have a tooltip
						tRewardString[eType] = string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</P>", tRewardString[eType], strMission)

					else
						tRewardString[eType] = string.format("%s<P Font=\"CRB_InterfaceMedium\" TextColor=\"Yellow\">%s</P>"..
														 "<P Font=\"CRB_InterfaceMedium\">%s</P>", tRewardString[eType], String_GetWeaselString(Apollo.GetString("TargetFrame_HealthShieldText"), strUnitName, strBracketText), strMessage)
					end

					wndCurr:SetTooltip(tRewardString[eType])
				end

				if splSpell then
					local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, Unit.CodeEnumRewardInfoType.ScientistSpell)
					nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)
					if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
						Tooltip.GetSpellTooltipForm(self, wndCurr, splSpell)
					end
				end
			elseif eType == Unit.CodeEnumRewardInfoType.PublicEvent and not self:HelperFlagOrDefault(tFlags, "bHidePublicEvents", false) then
				local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eType)

				local peoEvent = tRewardInfo[idx].peoObjective
				local strTitle = peoEvent:GetEvent():GetName()
				local nCompleted = peoEvent:GetCount()
				local nNeeded = peoEvent:GetRequiredCount()

				nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)

				tLastCompleted[nUnitId] = nCompleted
				local strTempTitle = strTitle
				if peoEvent:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_Exterminate then
					strTempTitle = String_GetWeaselString(Apollo.GetString("Nameplates_NumRemaining"), strTitle, nCompleted)
				elseif peoEvent:ShowPercent() then
					strTempTitle = String_GetWeaselString(Apollo.GetString("Nameplates_PercentCompleted"), strTitle, nCompleted / nNeeded * 100)
				elseif peoEvent:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_TimedWin then -- Very intentionally placed after the ShowPercent() check
					strTempTitle = String_GetWeaselString(Apollo.GetString("RewardInfo_PublicEventTimedWin"), strTitle, nCompleted * 1000, nNeeded * 1000)
				elseif nNeeded > 0 then 
					strTempTitle = String_GetWeaselString(Apollo.GetString("BuildMap_CategoryProgress"), strTitle, nCompleted, nNeeded)
				end

				tRewardString[eType] = string.format("%s<P Font=\"CRB_InterfaceMedium\">%s</P>", tRewardString[eType], strTempTitle)

				wndCurr:ToFront()				
				wndCurr:SetTooltip(tRewardString[eType])
			end
		end
	end

	if ( bIsRival and not self:HelperFlagOrDefault(tFlags, "bHideRivals", false) )
		or ( bIsFriend and not self:HelperFlagOrDefault(tFlags, "bHideFriends", false) )
		  or ( bIsAccountFriend and not self:HelperFlagOrDefault(tFlags, "bHideAccountFriends", false) ) then

		local eTempType = bIsRival and Unit.CodeEnumRewardInfoType.Rival or Unit.CodeEnumRewardInfoType.Friend
		local strTempType = bIsRival and "Rival" or "Friend"
		local strIsAccount = bIsAccountFriend and "TargetFrame_AccountFriend" or "TargetFrame_" .. strTempType

		local wndCurr = self:HelperLoadRewardIcon(wndRewardPanel, eTempType)
		nActiveRewardCount = nActiveRewardCount + self:HelperDrawRewardIcon(wndCurr)
		tRewardString[eTempType] = self:HelperDrawBasicRewardTooltip(wndCurr, Apollo.GetString(strIsAccount), unitTarget:GetName(), tRewardString[eTempType])
		wndCurr:SetTooltip(tRewardString[eTempType])
	end

	if nActiveRewardCount > 0 then
		local nLeft, nTop, nRight, nBottom = wndRewardPanel:GetAnchorOffsets()
		if self:HelperFlagOrDefault(tFlags, "bVert", false) then
			local nHeight = math.ceil(nActiveRewardCount*knDefaultIconWidth/2)
			wndRewardPanel:SetAnchorOffsets(nLeft, -nHeight, nRight, nHeight)
			wndRewardPanel:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.Middle)
		else
			local nWidth = math.ceil(nActiveRewardCount*knDefaultIconWidth/2)
			wndRewardPanel:SetAnchorOffsets(-nWidth, nTop, nWidth, nBottom)
			wndRewardPanel:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.Middle)
		end
	end

	wndRewardPanel:Show(nActiveRewardCount > 0)
end

function RewardIcons:CreateCallNames()
	RewardIcons.GetUnitRewardIconsForm = function (...)
		RewardIcons.GenerateUnitRewardIconsForm(self, ...)
	end
end

-----------------------------------------------------------------------------------------------
-- RewardIcons Instance
-----------------------------------------------------------------------------------------------
local RewardIconsInst = RewardIcons:new()
RewardIconsInst:Init()
