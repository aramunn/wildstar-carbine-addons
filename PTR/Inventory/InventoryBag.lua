-----------------------------------------------------------------------------------------------
-- Client Lua Script for InventoryBag
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "GameLib"
require "Item"
require "Window"
require "Money"
require "AccountItemLib"
require "StorefrontLib"

local InventoryBag = {}
local knSmallIconOption = 42
local knLargeIconOption = 48
local knMaxBags = 4 -- how many bags can the player have
local knSaveVersion = 3
local knPaddingTop = 20

function InventoryBag:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.bCostumesOpen = false
	o.bShouldSortItems = false
	o.nSortItemType = 1

	return o
end

function InventoryBag:Init()
    Apollo.RegisterAddon(self)
end

function InventoryBag:OnSave(eType)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character then
		return {
			nSaveVersion = knSaveVersion,
			bShouldSortItems = self.bShouldSortItems,
			nSortItemType = self.nSortItemType,
		}
	end
	return nil
end

function InventoryBag:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Account then
		self.tSavedData = tSavedData

		if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
			return
		end
	elseif eType == GameLib.CodeEnumAddonSaveLevel.Character  then
		if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
			return
		end

		self.bShouldSortItems = false
		if tSavedData.bShouldSortItems ~= nil then
			self.bShouldSortItems = tSavedData.bShouldSortItems
		end
		self.nSortItemType = 1
		if tSavedData.nSortItemType ~= nil then
			self.nSortItemType = tSavedData.nSortItemType
		end

		if self.wndMain then
			self.wndMainBagWindow:SetSort(self.bShouldSortItems)
			self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortOff"):SetCheck(not self.bShouldSortItems)
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortAlpha"):SetCheck(self.bShouldSortItems and self.nSortItemType == 1)
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortCategory"):SetCheck(self.bShouldSortItems and self.nSortItemType == 2)
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortQuality"):SetCheck(self.bShouldSortItems and self.nSortItemType == 3)
		end
	end
end


function InventoryBag:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("InventoryBag.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

local fnSortItemsByName = function(itemLeft, itemRight)
	if itemLeft == itemRight then
		return 0
	end
	if itemLeft and itemRight == nil then
		return -1
	end
	if itemLeft == nil and itemRight then
		return 1
	end

	local strLeftName = itemLeft:GetName()
	local strRightName = itemRight:GetName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end

	return 0
end

local fnSortItemsByCategory = function(itemLeft, itemRight)
	if itemLeft == itemRight then
		return 0
	end
	if itemLeft and itemRight == nil then
		return -1
	end
	if itemLeft == nil and itemRight then
		return 1
	end

	local strLeftName = itemLeft:GetItemCategoryName()
	local strRightName = itemRight:GetItemCategoryName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end

	local strLeftName = itemLeft:GetName()
	local strRightName = itemRight:GetName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end

	return 0
end

local fnSortItemsByQuality = function(itemLeft, itemRight)
	if itemLeft == itemRight then
		return 0
	end
	if itemLeft and itemRight == nil then
		return -1
	end
	if itemLeft == nil and itemRight then
		return 1
	end

	local eLeftQuality = itemLeft:GetItemQuality()
	local eRightQuality = itemRight:GetItemQuality()
	if eLeftQuality > eRightQuality then
		return -1
	end
	if eLeftQuality < eRightQuality then
		return 1
	end

	local strLeftName = itemLeft:GetName()
	local strRightName = itemRight:GetName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end

	return 0
end

local ktSortFunctions = {fnSortItemsByName, fnSortItemsByCategory, fnSortItemsByQuality}

-- TODO: Mark items as viewed
function InventoryBag:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 				"OnInterfaceMenuListHasLoaded", self)
	self:OnInterfaceMenuListHasLoaded()

	Apollo.RegisterEventHandler("UpdateInventory", 							"OnUpdateInventory", self)
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleInventory", 			"OnToggleVisibility", self) -- TODO: The datachron attachment needs to be brought over
	Apollo.RegisterEventHandler("GuildBank_ShowPersonalInventory", 			"OnToggleVisibilityAlways", self)
	Apollo.RegisterEventHandler("InvokeVendorWindow", 						"OnToggleVisibilityAlways", self)
	Apollo.RegisterEventHandler("ShowBank",									"OnToggleVisibilityAlways", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 				"UpdateBagSlotItems", self) -- using this for bag changes
	Apollo.RegisterEventHandler("PlayerPathMissionUpdate", 					"OnQuestObjectiveUpdated", self) -- route to same event
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 					"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("PlayerPathRefresh", 						"OnQuestObjectiveUpdated", self) -- route to same event
	Apollo.RegisterEventHandler("QuestStateChanged", 						"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("ToggleInventory", 							"OnToggleVisibility", self) -- todo: figure out if show inventory is needed
	Apollo.RegisterEventHandler("ShowInventory", 							"OnToggleVisibilityAlways", self)
	Apollo.RegisterEventHandler("ChallengeUpdated", 						"OnChallengeUpdated", self)
	Apollo.RegisterEventHandler("CharacterCreated", 						"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged",				"OnEquippedItem", self)
	Apollo.RegisterEventHandler("GenerciEvent_CostumesWindowOpened",		"OnGenerciEvent_CostumesWindowOpened", self)
	Apollo.RegisterEventHandler("GenerciEvent_CostumesWindowClosed",		"OnGenerciEvent_CostumesWindowClosed", self)
	Apollo.RegisterEventHandler("GenericEvent_SplitItemStack", 				"OnGenericEvent_SplitItemStack", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Inventory_Salvage", 			"OnLevelUpUnlock_Inventory_Salvage", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Path_Item", 					"OnLevelUpUnlock_Path_Item", self)
	Apollo.RegisterEventHandler("LootStackItemSentToTradeskillBag", 		"OnLootstackItemSentToTradeskillBag", self)
	Apollo.RegisterEventHandler("SupplySatchelOpen", 						"OnSupplySatchelOpen", self)
	Apollo.RegisterEventHandler("SupplySatchelClosed", 						"OnSupplySatchelClosed", self)
	Apollo.RegisterEventHandler("PremiumTierChanged",						"UpdateBagBlocker", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 				"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterEventHandler("StoreLinksRefresh",						"OnStoreLinksRefresh", self)
	Apollo.RegisterEventHandler("SalvageKeyRequiresConfirm",				"OnSalvageKeyRequiresConfirm", self)

	-- TODO Refactor: Investigate these two, we may not need them if we can detect the origin window of a drag
	Apollo.RegisterEventHandler("DragDropSysBegin", "OnSystemBeginDragDrop", self)
	Apollo.RegisterEventHandler("DragDropSysEnd", 	"OnSystemEndDragDrop", self)

	self.wndDeleteConfirm = Apollo.LoadForm(self.xmlDoc, "InventoryDeleteNotice", nil, self)
	self.wndSalvageConfirm = Apollo.LoadForm(self.xmlDoc, "InventorySalvageNotice", nil, self)
	self.wndSalvageWithKeyConfirm = Apollo.LoadForm(self.xmlDoc, "InventorySalvageWithKeyNotice", nil, self)
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "InventoryBag", nil, self)
	self.wndSplit = Apollo.LoadForm(self.xmlDoc, "SplitStackContainer", nil, self)
	self.wndMain:FindChild("VirtualInvToggleBtn"):AttachWindow(self.wndMain:FindChild("VirtualInvContainer"))
	self.wndMain:Show(false, true)
	self.wndSalvageConfirm:Show(false, true)
	self.wndDeleteConfirm:Show(false, true)
	self.wndNewSatchelItemRunner = self.wndMain:FindChild("BGBottom:SatchelBG:SatchelBtn:NewSatchelItemRunner")
	self.wndSalvageAllBtn = self.wndMain:FindChild("SalvageAllBtn")

	-- Variables
	self.nBoxSize = knLargeIconOption
	self.bFirstLoad = true
	self.nLastBagMaxSize = 0
	self.nLastWndMainWidth = self.wndMain:GetWidth()
	self.bSupplySatchelOpen = false

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.nFirstEverWidth = nRight - nLeft
	self.wndMain:SetSizingMinimum(336, 270)
	self.wndMain:SetSizingMaximum(1200, 700)

	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("MainGridContainer"):GetAnchorOffsets()
	self.nFirstEverMainGridHeight = nBottom - nTop

	self.tBagSlots = {}
	self.tBagCounts = {}
	for idx = 1, knMaxBags do
		self.tBagSlots[idx] = self.wndMain:FindChild("BagBtn" .. idx)
		self.tBagCounts[idx] = self.wndMain:FindChild("BagCount" .. idx)
	end

	self.nEquippedBagCount = 0 -- used to identify bag updates
	self:UpdateSquareSize()

	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.wndMainBagWindow = self.wndMain:FindChild("MainBagWindow")
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortOff"):SetCheck(not self.bShouldSortItems)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortAlpha"):SetCheck(self.bShouldSortItems and self.nSortItemType == 1)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortCategory"):SetCheck(self.bShouldSortItems and self.nSortItemType == 2)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortQuality"):SetCheck(self.bShouldSortItems and self.nSortItemType == 3)
	self.wndMain:FindChild("OptionsBtn"):AttachWindow(self.wndMain:FindChild("OptionsContainer"))

	self.wndIconBtnSortDropDown = self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown")
	self.wndIconBtnSortDropDown:AttachWindow(self.wndIconBtnSortDropDown:FindChild("ItemSortPrompt"))

	self:UpdateBagBlocker()
	
	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	self:OnWindowManagementReady()
end

function InventoryBag:OnSupplySatchelOpen()
	self.bSupplySatchelOpen = true
end

function InventoryBag:OnSupplySatchelClosed()
	self.bSupplySatchelOpen = false
end

function InventoryBag:OnLootstackItemSentToTradeskillBag(item)
	self.wndNewSatchelItemRunner:Show(not self.bSupplySatchelOpen)
	Event_ShowTutorial(GameLib.CodeEnumTutorial.TradeskillsInventory)
end

function InventoryBag:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Inventory"), {"InterfaceMenu_ToggleInventory", "Inventory", "Icon_Windows32_UI_CRB_InterfaceMenu_Inventory"})
end

function InventoryBag:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementRegister", {strName = Apollo.GetString("InterfaceMenu_Inventory"), nSaveVersion=3})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_Inventory"), nSaveVersion=3})
	
			if #CraftingLib.GetUniversalSchematicsOwned() > 0 then
			Event_ShowTutorial(GameLib.CodeEnumTutorial.CraftingImprint)
		end
end

function InventoryBag:OnToggleVisibility()
	if self.wndMain:IsShown() then
		self.wndMain:Close()
		Sound.Play(Sound.PlayUIBagClose)
		Apollo.StopTimer("InventoryUpdateTimer")
	else
		self.wndMain:Invoke()
		Sound.Play(Sound.PlayUIBagOpen)
		Apollo.StartTimer("InventoryUpdateTimer")
	end
	if self.bFirstLoad then
		self.bFirstLoad = false
	end

	if self.wndMain:IsShown() then
		self:UpdateSquareSize()
		self:UpdateBagSlotItems()
		self:OnQuestObjectiveUpdated() -- Populate Virtual Inventory Btn from reloadui/load
		self:HelperSetSalvageEnable()
	end
end

function InventoryBag:OnToggleVisibilityAlways()
	self.wndMain:Invoke()
	Apollo.StartTimer("InventoryUpdateTimer")

	if self.bFirstLoad then
		self.bFirstLoad = false
	end

	if self.wndMain:IsShown() then
		self:UpdateSquareSize()
		self:UpdateBagSlotItems()
		self:OnQuestObjectiveUpdated() -- Populate Virtual Inventory Btn from reloadui/load
		self:HelperSetSalvageEnable()
	end
end

function InventoryBag:OnLevelUpUnlock_Inventory_Salvage()
	self:OnToggleVisibilityAlways()
end

function InventoryBag:OnLevelUpUnlock_Path_Item(itemFromPath)
	self:OnToggleVisibilityAlways()
end

-----------------------------------------------------------------------------------------------
-- Main Update Timer
-----------------------------------------------------------------------------------------------
function InventoryBag:OnInventoryClosed(wndHandler, wndControl)
	self.wndMainBagWindow:MarkAllItemsAsSeen()
end

function InventoryBag:UpdateBagSlotItems() -- update our bag display
	local nOldBagCount = self.nEquippedBagCount -- record the old count

	self.nEquippedBagCount = 0	-- reset

	for idx = 1, knMaxBags do
		local itemBag = self.wndMainBagWindow:GetBagItem(idx)
		local wndCtrl = self.wndMain:FindChild("BagBtn"..idx)
		
		if itemBag ~= wndCtrl:GetData() then
			wndCtrl:SetData(itemBag)
			if itemBag then
				self.tBagCounts[idx]:SetText("+" .. itemBag:GetBagSlots())
				local wndRemoveBagIcon = wndCtrl:FindChild("RemoveBagIcon")
				wndRemoveBagIcon:Show(true)
				wndRemoveBagIcon:SetData(itemBag)
				self.nEquippedBagCount = self.nEquippedBagCount + 1
				Tooltip.GetItemTooltipForm(self, wndCtrl, itemBag, {bPrimary = true, bSelling = false})
			else
				self.tBagCounts[idx]:SetText("")
				wndCtrl:SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"white\">%s</T>", Apollo.GetString("Inventory_EmptySlot")))
				wndCtrl:FindChild("RemoveBagIcon"):Show(false)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Drawing Bag Slots
-----------------------------------------------------------------------------------------------

function InventoryBag:OnMainWindowMouseResized()
	self:UpdateSquareSize()
	self.wndMain:FindChild("VirtualInvItems"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.Middle)
end

function InventoryBag:UpdateSquareSize()
	if not self.wndMain then
		return
	end

	if self.wndMainBagWindow then
		self.wndMainBagWindow:SetSquareSize(self.nBoxSize, self.nBoxSize)
	end
end

-----------------------------------------------------------------------------------------------
-- Options
-----------------------------------------------------------------------------------------------
function InventoryBag:OnOptionsMenuToggle(wndHandler, wndControl) -- OptionsBtn

	for idx = 1,4 do
		self.wndMain:FindChild("BagBtn" .. idx):FindChild("RemoveBagIcon"):Show(false)
	end

	self.wndMain:FindChild("IconBtnLarge"):SetCheck(self.nBoxSize == kLargeIconOption)
	self.wndMain:FindChild("IconBtnSmall"):SetCheck(self.nBoxSize == kSmallIconOption)
end

function InventoryBag:OnOptionsAddSizeRows()
	if self.nBoxSize == knSmallIconOption then
		self.nBoxSize = knLargeIconOption
		self:OnMainWindowMouseResized()
		self:UpdateSquareSize()
	end
end

function InventoryBag:OnOptionsRemoveSizeRows()
	if self.nBoxSize == knLargeIconOption then
		self.nBoxSize = knSmallIconOption
		self:OnMainWindowMouseResized()
		self:UpdateSquareSize()
	end
end

-----------------------------------------------------------------------------------------------
-- Supply Satchel
-----------------------------------------------------------------------------------------------

function InventoryBag:OnToggleSupplySatchel(wndHandler, wndControl)
	--ToggleTradeSkillsInventory()
	local tAnchors = {}
	tAnchors.nLeft, tAnchors.nTop, tAnchors.nRight, tAnchors.nBottom = self.wndMain:GetAnchorOffsets()
	Event_FireGenericEvent("ToggleTradeskillInventoryFromBag", tAnchors)
	self.wndNewSatchelItemRunner:Show(false)
end

function InventoryBag:OnItemClick(wndHandler, wndControl, eButton, item)
	local bUnlock = self.bCostumesOpen and item:IsEquippable()
	if bUnlock then
		Event_FireGenericEvent("GenericEvent_CostumeUnlock", item)
	end
	
	return bUnlock
end

function InventoryBag:OnGenerciEvent_CostumesWindowOpened()
	self.bCostumesOpen = true
end

function InventoryBag:OnGenerciEvent_CostumesWindowClosed()
	self.bCostumesOpen = false
end

-----------------------------------------------------------------------------------------------
-- Salvage All
-----------------------------------------------------------------------------------------------

function InventoryBag:OnSalvageAllBtn(wndHandler, wndControl)
	Event_FireGenericEvent("RequestSalvageAll", tAnchors)
end

function InventoryBag:OnDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageAllBtn"):GetData() then
		self:InvokeSalvageConfirmWindow(iData)
	end
	return false
end

function InventoryBag:OnQueryDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageAllBtn"):GetData() then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

-----------------------------------------------------------------------------------------------
-- Virtual Inventory
-----------------------------------------------------------------------------------------------

function InventoryBag:OnQuestObjectiveUpdated()
	self:UpdateVirtualItemInventory()
end

function InventoryBag:OnChallengeUpdated()
	self:UpdateVirtualItemInventory()
end

function InventoryBag:UpdateVirtualItemInventory()
	local tVirtualItems = Item.GetVirtualItems()
	local bThereAreItems = #tVirtualItems > 0

	self.wndMain:FindChild("VirtualInvToggleBtn"):Show(bThereAreItems)
	self.wndMain:FindChild("VirtualInvContainer"):SetData(#tVirtualItems)
	self.wndMain:FindChild("VirtualInvContainer"):Show(self.wndMain:FindChild("VirtualInvToggleBtn"):IsChecked())

	if not bThereAreItems then
		self.wndMain:FindChild("VirtualInvToggleBtn"):SetCheck(false)
		self.wndMain:FindChild("VirtualInvContainer"):Show(false)
	elseif self.wndMain:FindChild("VirtualInvContainer"):GetData() == 0 then
		self.wndMain:FindChild("VirtualInvToggleBtn"):SetCheck(true)
		self.wndMain:FindChild("VirtualInvContainer"):Show(true)
	end

	-- Draw items
	self.wndMain:FindChild("VirtualInvItems"):DestroyChildren()
	local nOnGoingCount = 0
	for key, tCurrItem in pairs(tVirtualItems) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "VirtualItem", self.wndMain:FindChild("VirtualInvItems"), self)
		if tCurrItem.nCount > 1 then
			wndCurr:FindChild("VirtualItemCount"):SetText(tCurrItem.nCount)
		end
		nOnGoingCount = nOnGoingCount + tCurrItem.nCount
		wndCurr:FindChild("VirtualItemDisplay"):SetSprite(tCurrItem.strIcon)
		wndCurr:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\">%s</P><P Font=\"CRB_InterfaceSmall\" TextColor=\"aaaaaaaa\">%s</P>", tCurrItem.strName, tCurrItem.strFlavor))
	end
	self.wndMain:FindChild("VirtualInvToggleBtn"):SetText(String_GetWeaselString(Apollo.GetString("Inventory_VirtualInvBtn"), nOnGoingCount))
	self.wndMain:FindChild("VirtualInvItems"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.Middle)

	-- Adjust heights
	local bShowQuestItems = self.wndMain:FindChild("VirtualInvToggleBtn"):IsChecked()
	if not self.nVirtualButtonHeight then
		local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("VirtualInvToggleBtn"):GetAnchorOffsets()
		self.nVirtualButtonHeight = nBottom - nTop
	end
	if not self.nQuestItemContainerHeight then
		local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("VirtualInvContainer"):GetAnchorOffsets()
		self.nQuestItemContainerHeight = nBottom - nTop
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("BGVirtual"):GetAnchorOffsets()
	nTop = nBottom
	if bThereAreItems then
		nTop = nBottom - self.nVirtualButtonHeight
		if bShowQuestItems then
			nTop = nTop - self.nQuestItemContainerHeight
		end
	end
	self.wndMain:FindChild("BGVirtual"):SetAnchorOffsets(nLeft, nTop, nRight, nBottom)

	local nBagLeft, nBagTop, nBagRight, nBagBottom = self.wndMain:FindChild("BGGridArt"):GetAnchorOffsets()
	self.wndMain:FindChild("BGGridArt"):SetAnchorOffsets(nBagLeft, nBagTop, nBagRight, nTop)
end

-----------------------------------------------------------------------------------------------
-- Drag and Drop
-----------------------------------------------------------------------------------------------

function InventoryBag:OnBagDragDropCancel(wndHandler, wndControl, strType, nIndex, eReason)
	if strType ~= "DDBagItem" or eReason == Apollo.DragDropCancelReason.EscapeKey or eReason == Apollo.DragDropCancelReason.ClickedOnNothing then
		return false
	end

	if eReason == Apollo.DragDropCancelReason.ClickedOnWorld or eReason == Apollo.DragDropCancelReason.DroppedOnNothing then
		self:InvokeDeleteConfirmWindow(nIndex)
	end
	return false
end

-- Trash Icon
function InventoryBag:OnDragDropTrash(wndHandler, wndControl, nX, nY, wndSource, strType, nIndex)
	if strType == "DDBagItem" then
		self:InvokeDeleteConfirmWindow(nIndex)
	end
	return false
end

function InventoryBag:OnQueryDragDropTrash(wndHandler, wndControl, nX, nY, wndSource, strType, nIndex)
	if strType == "DDBagItem" then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

function InventoryBag:OnDragDropNotifyTrash(wndHandler, wndControl, bMe) -- TODO: We can probably replace this with a button mouse over state
	if bMe then
		self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashToggleFlyby")
		self.wndMain:FindChild("TextActionPrompt_Trash"):Show(true)
	else
		self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashTogglePressed")
		self.wndMain:FindChild("TextActionPrompt_Trash"):Show(false)
	end
end
-- End Trash Icon

-- Salvage Icon
function InventoryBag:OnDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageIcon"):GetData() then
		self:InvokeSalvageConfirmWindow(iData)
	end
	return false
end

function InventoryBag:OnQueryDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageIcon"):GetData() then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

function InventoryBag:OnDragDropNotifySalvage(wndHandler, wndControl, bMe) -- TODO: We can probably replace this with a button mouse over state
	if bMe and self.wndMain:FindChild("SalvageIcon"):GetData() then
		self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(true)
	elseif self.wndMain:FindChild("SalvageIcon"):GetData() then
		self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)
	end
end
-- End Salvage Icon

function InventoryBag:HelperSetSalvageEnable()
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil or not unitPlayer:IsValid() then
		return
	end
	
	local tInvItems = unitPlayer:GetInventoryItems()
	for idx, tItem in ipairs(tInvItems) do
		if tItem and tItem.itemInBag and tItem.itemInBag:CanSalvage() and not tItem.itemInBag:CanAutoSalvage() then
			self.wndSalvageAllBtn:Enable(true)
			return
		end
	end
	self.wndSalvageAllBtn:Enable(false)
end


function InventoryBag:OnUpdateInventory()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		return
	end

	self:HelperSetSalvageEnable()
end

function InventoryBag:OnSystemBeginDragDrop(wndSource, strType, iData)
	if strType ~= "DDBagItem" then return end
	self.wndMain:FindChild("TextActionPrompt_Trash"):Show(false)
	self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)

	self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashTogglePressed")

	local item = self.wndMainBagWindow:GetItem(iData)
	if item and item:CanSalvage() then
		self.wndMain:FindChild("SalvageIcon"):SetData(true)
		self.wndSalvageAllBtn:Enable(true)
	else
		self.wndSalvageAllBtn:Enable(false)
	end

	Sound.Play(Sound.PlayUI45LiftVirtual)
end

function InventoryBag:OnSystemEndDragDrop(strType, iData)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:FindChild("TrashIcon") or strType == "DDGuildBankItem" or strType == "DDWarPartyBankItem" or strType == "DDGuildBankItemSplitStack" then
		return -- TODO Investigate if there are other types
	end

	self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashToggleNormal")
	self.wndMain:FindChild("SalvageIcon"):SetData(false)
	self.wndMain:FindChild("TextActionPrompt_Trash"):Show(false)
	self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)
	self:HelperSetSalvageEnable()
	self:UpdateSquareSize()
	Sound.Play(Sound.PlayUI46PlaceVirtual)
end

function InventoryBag:OnEquippedItem(eSlot, itemNew, itemOld)
	if itemNew then
		itemNew:PlayEquipSound()
	else
		itemOld:PlayEquipSound()
	end
end

-----------------------------------------------------------------------------------------------
-- Item Sorting
-----------------------------------------------------------------------------------------------

function InventoryBag:OnOptionsSortItemsOff(wndHandler, wndControl)
	self.bShouldSortItems = false
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndIconBtnSortDropDown:SetCheck(false)
end

function InventoryBag:OnOptionsSortItemsName(wndHandler, wndControl)
	self.bShouldSortItems = true
	self.nSortItemType = 1
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndIconBtnSortDropDown:SetCheck(false)
end

function InventoryBag:OnOptionsSortItemsByCategory(wndHandler, wndControl)
	self.bShouldSortItems = true
	self.nSortItemType = 2
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndIconBtnSortDropDown:SetCheck(false)
end

function InventoryBag:OnOptionsSortItemsByQuality(wndHandler, wndControl)
	self.bShouldSortItems = true
	self.nSortItemType = 3
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndIconBtnSortDropDown:SetCheck(false)
end

-----------------------------------------------------------------------------------------------
-- Delete/Salvage Screen
-----------------------------------------------------------------------------------------------

function InventoryBag:InvokeDeleteConfirmWindow(iData)
	local itemData = Item.GetItemFromInventoryLoc(iData)
	if itemData and not itemData:CanDelete() then
		return
	end
	self.wndDeleteConfirm:SetData(iData)
	self.wndDeleteConfirm:Invoke()
	self.wndDeleteConfirm:FindChild("DeleteBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.DeleteItem, iData)
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(true)
	Sound.Play(Sound.PlayUI55ErrorVirtual)
end

function InventoryBag:InvokeSalvageConfirmWindow(iData)
	local item = Item.GetItemFromInventoryLoc(iData)
	if item:DoesSalvageRequireKey() then
		local nKeyCount = GameLib.SalvageKeyCount()
		self.wndSalvageWithKeyConfirm:SetData(iData)
		self.wndSalvageWithKeyConfirm:Invoke()
		self.wndSalvageWithKeyConfirm:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, iData)
		if nKeyCount == 0 then
			self.wndSalvageWithKeyConfirm:FindChild("Hologram:GetKeysBtn"):Show(StorefrontLib.IsLinkValid(StorefrontLib.CodeEnumStoreLink.LockboxKey))
			self.wndSalvageWithKeyConfirm:FindChild("Hologram:SalvageBtn"):Show(false)
			self.wndSalvageWithKeyConfirm:FindChild("NoticeText"):SetText(Apollo.GetString("Inventory_SalvageNoKey"))
			self.wndSalvageWithKeyConfirm:FindChild("NoticeText"):SetTextColor("Orangered")
		else
			self.wndSalvageWithKeyConfirm:FindChild("Hologram:GetKeysBtn"):Show(false)
			self.wndSalvageWithKeyConfirm:FindChild("Hologram:SalvageBtn"):Show(true)		
			self.wndSalvageWithKeyConfirm:FindChild("NoticeText"):SetText(String_GetWeaselString(Apollo.GetString("Inventory_ConfirmSalvageWithKeyNotice"), nKeyCount))
			self.wndSalvageWithKeyConfirm:FindChild("NoticeText"):SetTextColor("UI_TextHoloTitle")
		end
	else
		self.wndSalvageConfirm:SetData(iData)
		self.wndSalvageConfirm:Invoke()
		self.wndSalvageConfirm:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, iData)
	end
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(true)
	Sound.Play(Sound.PlayUI55ErrorVirtual)
end

-- TODO SECURITY: These confirmations are entirely a UI concept. Code should have a allow/disallow.
function InventoryBag:OnDeleteCancel()
	self.wndDeleteConfirm:SetData(nil)
	self.wndDeleteConfirm:Close()
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(false)
end

function InventoryBag:OnSalvageCancel()
	self.wndSalvageConfirm:SetData(nil)
	self.wndSalvageConfirm:Close()
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(false)
end

function InventoryBag:OnDeleteConfirm()
	self:OnDeleteCancel()
end

function InventoryBag:OnSalvageConfirm()
	Event_ShowTutorial(GameLib.CodeEnumTutorial.CharacterWindow)
	self:OnSalvageCancel()
end

-----------------------------------------------------------------------------------------------
-- Salvage With Key Screen
-----------------------------------------------------------------------------------------------

function InventoryBag:OnSalvageKeyRequiresConfirm(item)
	self:InvokeSalvageConfirmWindow(item:GetInventoryId())
end

function InventoryBag:OnSalvageKeysConfirm()
	self:OnSalvageKeysCancel()
end

function InventoryBag:OnGetMoreSalvageKeysSignal()
	StorefrontLib.OpenLink(StorefrontLib.CodeEnumStoreLink.LockboxKey)
	self:OnSalvageKeysCancel()
end

function InventoryBag:OnSalvageKeysCancel()
	self.wndSalvageWithKeyConfirm:SetData(nil)
	self.wndSalvageWithKeyConfirm:Close()
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- Stack Splitting
-----------------------------------------------------------------------------------------------

function InventoryBag:OnGenericEvent_SplitItemStack(item)
	if not item then 
		return 
	end
	
	local nStackCount = item:GetStackCount()
	if nStackCount < 2 then
		self.wndSplit:Show(false)
		return
	end
	self.wndSplit:Invoke()
	local tMouse = Apollo.GetMouse()
	self.wndSplit:Move(tMouse.x - math.floor(self.wndSplit:GetWidth() / 2) , tMouse.y - knPaddingTop - self.wndSplit:GetHeight(), self.wndSplit:GetWidth(), self.wndSplit:GetHeight())


	self.wndSplit:SetData(item)
	self.wndSplit:FindChild("SplitValue"):SetValue(1)
	self.wndSplit:FindChild("SplitValue"):SetMinMax(1, nStackCount - 1)
	self.wndSplit:Show(true)
end

function InventoryBag:OnSplitStackCloseClick()
	self.wndSplit:Show(false)
end

function InventoryBag:OnSplitStackConfirm(wndHandler, wndCtrl)
	self.wndSplit:Close()
	self.wndMainBagWindow:StartSplitStack(self.wndSplit:GetData(), self.wndSplit:FindChild("SplitValue"):GetValue())
end

function InventoryBag:OnGenerateTooltip(wndControl, wndHandler, tType, item)
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then
		local itemEquipped = item:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		-- Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = item})
	end
end

---------------------------------------------------------------------------------------------------
-- Premium Updates
---------------------------------------------------------------------------------------------------

function InventoryBag:UpdateBagBlocker(ePremiumSystem, nTier)
	if ePremiumSystem == nil then
		ePremiumSystem = AccountItemLib.GetPremiumSystem()
	end
	
	if ePremiumSystem ~= AccountItemLib.CodeEnumPremiumSystem.VIP or self.wndMain == nil or not self.wndMain:IsValid() then
		return
	end
	
	if nTier == nil then
		nTier = AccountItemLib.GetPremiumTier()
	end
	
	local wndBlockerVIPLapse = self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureBags:OptionsConfigureBagsBG:BlockerVIPLapse")
	wndBlockerVIPLapse:Show(nTier == 0)
end

---------------------------------------------------------------------------------------------------
-- Store Updates
---------------------------------------------------------------------------------------------------

function InventoryBag:OnStoreLinksRefresh()
	if self.wndSalvageWithKeyConfirm ~= nil and self.wndSalvageWithKeyConfirm:IsValid() then
		self.wndSalvageWithKeyConfirm:FindChild("Hologram:GetKeysBtn"):Show(StorefrontLib.IsLinkValid(StorefrontLib.CodeEnumStoreLink.LockboxKey))
	end
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------

function InventoryBag:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	local tAnchors =
	{
		[GameLib.CodeEnumTutorialAnchor.Inventory] 		= true,
		[GameLib.CodeEnumTutorialAnchor.InventoryItem] 	= true,
	}
	
	if not tAnchors[eAnchor] or not self.wndMain then 
		return 
	end
	
	local tAnchorMapping =
	{
		[GameLib.CodeEnumTutorialAnchor.Inventory] 		= self.wndMain,
		[GameLib.CodeEnumTutorialAnchor.InventoryItem] 	= self.wndMain:FindChild("BGGridArt")
	}
	
	if tAnchorMapping[eAnchor] then
		Event_FireGenericEvent("Tutorial_ShowCallout", eAnchor, idTutorial, strPopupText, tAnchorMapping[eAnchor])
	end
end

local InventoryBagInst = InventoryBag:new()
InventoryBagInst:Init()
