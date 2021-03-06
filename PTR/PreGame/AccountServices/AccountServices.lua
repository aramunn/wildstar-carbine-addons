-----------------------------------------------------------------------------------------------
-- Client Lua Script for AccountServices
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "CharacterScreenLib"
require "AccountItemLib"
require "PreGameLib"
require "Money"

local AccountServices = {}
local keFireOnPaidTransfer = "Transfer" -- Random Enum (GOTCHA: Free doesn't need to worry about this)
local keFireOnRename = "Rename" -- Random Enum
local keFireOnCredd = "Credd" -- Random Enum
local knMaxCharacterName = 29 --TODO replace with the max length of a character name from PreGameLib once the enum has been created in PreGameLib


local ktRealmPopToString =
{
	Apollo.GetString("RealmPopulation_Low"),
	Apollo.GetString("RealmPopulation_Medium"),
	Apollo.GetString("RealmPopulation_High"),
	Apollo.GetString("RealmPopulation_Full"),
}

local ktRealmTransferResults =
{
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_InvalidRealm]		=	"AccountServices_Error_InvalidRealm",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferOk]							=	"AccountServices_Error_Ok",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_ServerDown]			=	"AccountServices_Error_ServerDown",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterOnline]		=	"AccountServices_Error_CharacterOnline",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_InvalidCharacter]	=	"AccountServices_Error_InvalidCharacter",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterLocked]		=	"AccountServices_Error_CharacterLocked",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_NoCurrency]			=	"AccountServices_Error_NoCurrency",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_DbError]				=	"AccountServices_Error_DbError",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_HasAuction]			=	"AccountServices_Error_HasAuction",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_InGuild]				=	"AccountServices_Error_InGuild",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_HasCREDDExchange]	=	"AccountServices_Error_HasCREDDExchange",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterBusy]		=	"AccountServices_Error_CharacterBusy",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_CharacterCooldown]	=	"AccountServices_Error_CharacterCooldown",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_HasMail]				=	"AccountServices_Error_HasMail",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_ServerFull]			=	"AccountServices_Error_ServerFull",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_Money]				=	"AccountServices_Error_TooMuchMoney",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_HasSavedInstance]	=	"AccountServices_Error_HasSavedInstance",
	[PreGameLib.CodeEnumCharacterModifyResults.RealmTransferFailed_FactionRestricted]	=	"AccountServices_Error_FactionRestricted",
}

local ktCreddRedeemResults =
{
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDFailed_NoCREDD]				=	"AccountServices_CreddError_NoCredd",
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDFailed_NoEntitlement]			=	"AccountServices_CreddError_NoEntitlement",
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDFailed_Internal]				=	"AccountServices_CreddError_Internal",
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDOk]							=	"AccountServices_TransactionCompleteCredd",
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDFailed_InvalidCREDD]			=	"AccountServices_CreddError_InvalidCredd",
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDFailed_PlatformError]			=	"AccountServices_CreddError_PlatformError",
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDFailed_PlatformPermaFail]		=	"AccountServices_CreddError_PlatformError", -- Same
	[PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDFailed_PlatformTempFail]		=	"AccountServices_CreddError_PlatformError", -- Same
}

function AccountServices:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function AccountServices:Init()
	Apollo.RegisterAddon(self)
end

function AccountServices:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AccountServices.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function AccountServices:DebugPrint(strMessage)
	--if self.wndDebugPrint and self.wndDebugPrint:IsValid() then self.wndDebugPrint:Destroy() end
	self.wndDebugPrint = Apollo.LoadForm(self.xmlDoc, "DebugPrint", "AccountServices", self)
	self.wndDebugPrint:SetText(tostring(strMessage))
	self.wndDebugPrint:Show(true)
end

function AccountServices:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("AccountItemUpdate", 				"RedrawAll", self) -- Global catch all method
	Apollo.RegisterEventHandler("SubscriptionExpired",				"RedrawAll", self)
	Apollo.RegisterEventHandler("CharacterList", 					"RedrawAll", self) -- Main most reliable method to RedrawAll

	Apollo.RegisterEventHandler("QueueStatus",						"OnQueueStatus", self) -- This means the character has been queued
	Apollo.RegisterEventHandler("CharacterRename", 					"OnCharacterRename", self)
	Apollo.RegisterEventHandler("CREDDRedeemResult", 				"OnCREDDRedeemResult", self)
	Apollo.RegisterEventHandler("RealmTransferResult", 				"OnRealmTransferResult", self)
	Apollo.RegisterEventHandler("TransferDestinationRealmList", 	"OnTransferDestinationRealmList", self)
	Apollo.RegisterEventHandler("PTRCharacterCopyQueued", 	         "OnPTRCharacterCopyQueued", self)

	Apollo.RegisterEventHandler("Pregame_CreationToSelection", 		"OnPregame_CreationToSelection", self)
	Apollo.RegisterEventHandler("Pregame_CharacterSelected", 		"OnPregame_CharacterSelected", self)
	Apollo.RegisterEventHandler("OpenCharacterCreateBtn", 			"OnOpenCharacterCreateBtn", self)
	Apollo.RegisterEventHandler("CloseAllOpenAccountWindows", 		"OnCloseAllOpenAccountWindows", self)

	Apollo.RegisterTimerHandler("Pregame_RedeemCreddDelay",			"OnPregame_RedeemCreddDelay", self)
	Apollo.RegisterEventHandler("TrustedIPListReady", 				"OnTrustedIPListReady", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "AccountServicesForm", "AccountServices", self)
	self.wndMinimized = Apollo.LoadForm(self.xmlDoc, "MinimizedPicker", "AccountServices", self)

	self.wndMainPicker = self.wndMain:FindChild("MainPicker")
	self.wndRenameFlyout = self.wndMain:FindChild("RenameFlyout")
	self.wndPaidTransferFlyout = self.wndMain:FindChild("PaidTransferFlyout")
	self.wndFreeTransferFlyout = self.wndMain:FindChild("FreeTransferFlyout")
	self.wndTrustedIPFlyout = self.wndMain:FindChild("TrustedIPFlyout")
	self.wndCopyPTRConfirmation = self.wndMain:FindChild("CopyPTRConfirmation")
	self.wndCopyQueued = self.wndMain:FindChild("CopyQueued")
	self.wndMainPicker:FindChild("AvailablePaidRenameBtn"):AttachWindow(self.wndRenameFlyout)
	self.wndMainPicker:FindChild("AvailablePaidRealmBtn"):AttachWindow(self.wndPaidTransferFlyout)
	self.wndMainPicker:FindChild("AvailableFreeRealmBtn"):AttachWindow(self.wndFreeTransferFlyout)
	self.wndMainPicker:FindChild("TrustedIPBtn"):AttachWindow(self.wndTrustedIPFlyout)
	self.wndMainPicker:FindChild("PtrCopyBtn"):AttachWindow(self.wndCopyPTRConfirmation)

	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("HideMainPicker"):GetAnchorOffsets()
	local nLeftMain, nTopMain, nRightMain, nBottomMain = self.wndMain:FindChild("MainPicker"):GetAnchorOffsets()
	self.nAccountServicesGap = math.abs(nBottomMain) - math.abs(nBottom)--Accounting for the gap between the edges of the window and beginning of sprite.
	
	self.wndErrorMessage = nil
	self.wndRenameConfirm = nil
	self.wndTransferConfirm = nil
	self.wndGroupBindConfirm = nil
	self.wndRedeemCreddDelay = nil

	self.bFireCreddOnUpdate = nil
	self.strFireRenameOnUpdate = nil
	self.nFirePaidTransferOnUpdate = nil

	self.nCharacterSelectedPos = 0
	self.strCharacterSelectedName = nil
	self.bCharacterRequiresRename = false

	self:RedrawAll() -- We need to call this on start up and with AccountItemUpdate, so it'll draw no matter what
end

function AccountServices:OnQueueStatus() -- TODO TEMP, Hide everything if a player is in the queue. When they are done, CharacterList will fire.
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Close()
	end
end

function AccountServices:RedrawAll()
	if not self.wndMain then --OnTrustedIPListReady may be called before self.wndMain was set.
		return
	end

	self:HelperCheckTriggers()

	-- Count Account Bound options
	local nCreddEscrow = 0
	local nRenameEscrow = 0
	local nTransferEscrow = 0
	local nCreddBound = AccountItemLib.GetAccountCurrency(PreGameLib.CodeEnumAccountCurrency.CREDD):GetAmount() or 0
	local nRenameBound = AccountItemLib.GetAccountCurrency(PreGameLib.CodeEnumAccountCurrency.NameChange):GetAmount() or 0
	local nTransferBound = AccountItemLib.GetAccountCurrency(PreGameLib.CodeEnumAccountCurrency.RealmTransfer):GetAmount() or 0
	local nTrusedIPs = 0--Will be set if we get IP list
	
	--Setting TrusteIPB information.
	if self.bTrustedIPListReady then
		local arTrustedIPList = AccountItemLib.GetTrustedIPList()
		nTrusedIPs = #arTrustedIPList

		local wndTrustedIPConfirmBtn = self.wndTrustedIPFlyout:FindChild("TrustedIPConfirmBtn")
		local wndTrustedIPContent = self.wndTrustedIPFlyout:FindChild("TrustedIPContent")
		wndTrustedIPContent:DestroyChildren()

		--Adding trusted
		for idx, tIP in pairs(arTrustedIPList) do
			local wndIpRow = Apollo.LoadForm(self.xmlDoc, "TrustedIPButton", wndTrustedIPContent, self)
			wndIpRow:SetData({ ["wndTrustedIPConfirmBtn"] = wndTrustedIPConfirmBtn })
			wndIpRow:FindChild("Button"):SetData({ ["ipAddress"] = tIP.strIPAddress, ["wndTrustedIPConfirmBtn"] = wndTrustedIPConfirmBtn, ["wndTrustedIPContent"] = wndTrustedIPContent } )
			wndIpRow:FindChild("IPNumber"):SetText(tIP.strIPAddress)
			wndIpRow:FindChild("IPDateAdded"):SetText(tIP.strRegisterd)
		end
		wndTrustedIPContent:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	end

	-- Note: When claiming from a group to Account Bound, we'll have to warn a player that they will get the entire group.
	local tFlattenedTable = {}

	for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
		for idx2, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
			table.insert(tFlattenedTable, tPendingAccountItem)
		end
	end

	for idx, tPendingAccountItem in pairs(tFlattenedTable) do
		if tPendingAccountItem.accountCurrency then
			local ePendingType = tPendingAccountItem.accountCurrency.accountCurrencyEnum
			nCreddEscrow = ePendingType == PreGameLib.CodeEnumAccountCurrency.CREDD and (nCreddEscrow + 1) or nCreddEscrow
			nRenameEscrow = ePendingType == PreGameLib.CodeEnumAccountCurrency.NameChange and (nRenameEscrow + 1) or nRenameEscrow
			nTransferEscrow = ePendingType == PreGameLib.CodeEnumAccountCurrency.RealmTransfer and (nTransferEscrow + 1) or nTransferEscrow
		end
	end
	
	AccountItemLib.RequestTrustedIPList()
	
	-- Initialize if > 0
	local bHaveCharacters = g_arCharacters and #g_arCharacters > 0
	local tMyRealmInfo = CharacterScreenLib.GetRealmInfo()
	local bCanFreeRealmTransfer = tMyRealmInfo and tMyRealmInfo.bFreeRealmTransfer or nil
	if bHaveCharacters and (bCanFreeRealmTransfer or math.max(nCreddBound, nCreddEscrow, nRenameBound, nRenameEscrow, nTransferBound, nTransferEscrow, nTrusedIPs) > 0) then
		local bDefaultMinimized = false -- TODO, Console Variable or saved setting
		self.wndMain:Show(not bDefaultMinimized, true)
		self.wndMinimized:Show(bDefaultMinimized, true)

		self:DrawRenameFlyout(nRenameBound, nRenameEscrow)
		self:DrawFreeTransferFlyout()
		self:DrawPaidTransferFlyout(nTransferBound, nTransferEscrow)

		local wndMainPickerButtonList = self.wndMainPicker:FindChild("AvailableScroll")
		local tWindowNameToSubtitle =
		{
			["AvailableFreeRealmBtn"]	=	{ strText = Apollo.GetString("AccountServices_NumRealmsAvailable"), nAmount = bCanFreeRealmTransfer and 1 or 0 }, -- Just for enabling
			["AvailablePaidRealmBtn"]	=	{ strText =  Apollo.GetString("AccountServices_NumAvailable"), nAmount = nTransferBound +  nTransferEscrow },
			["AvailablePaidRenameBtn"]	=	{ strText =  Apollo.GetString("AccountServices_NumAvailable"), nAmount = nRenameBound + nRenameEscrow },
			["PtrCopyBtn"]	=	{ strText =  Apollo.GetString("AccountServices_CopyPTR"), nAmount = 1},-- Just for enabling
			["TrustedIPBtn"]	=	{ strText =  Apollo.GetString("AccountServices_IPAddressSavedCount"), nAmount = nTrusedIPs},
			--["AvailablePaidCreddBtn"]	=	{ Apollo.GetString("AccountServices_NumAvailableCREDDExplain"), nCreddBound + nCreddEscrow }, -- Disabled for now
		}
		local nButtonHeight = 0
		for strButtonName, tData in pairs(tWindowNameToSubtitle) do
			local bValid = tonumber(tData.nAmount) > 0
			local wndCurrButton = wndMainPickerButtonList:FindChild(strButtonName)
			wndCurrButton:FindChild("AvailableBtnSubtitle"):SetTextColor(bValid and ApolloColor.new("UI_TextHoloBodyCyan") or ApolloColor.new("UI_TextMetalBodyHighlight"))
			wndCurrButton:FindChild("AvailableBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(tData.strText, tData.nAmount))
			wndCurrButton:Show(bValid)
			
			if bValid then
				nButtonHeight = nButtonHeight + wndCurrButton:GetHeight()
			end
		end
		wndMainPickerButtonList:FindChild("AvailablePaidRenameBtn"):Enable(not self.bCharacterRequiresRename)

		wndMainPickerButtonList:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)

		local nLeft, nTop, nRight, nBottom = self.wndMainPicker:FindChild("AvailableScroll"):GetAnchorOffsets()
		local nLeftMain, nTopMain, nRightMain, nBottomMain = self.wndMainPicker:GetAnchorOffsets()
		self.wndMainPicker:SetAnchorOffsets(nLeftMain, nTopMain, nRightMain, nTopMain + nTop + nButtonHeight + self.nAccountServicesGap)
	else
		self.wndMain:Close()
		self.wndMinimized:Close()
	end
end

-----------------------------------------------------------------------------------------------
-- Main Picker
-----------------------------------------------------------------------------------------------

function AccountServices:OnPregame_CharacterSelected(tData)
	local tSelected = tData.tSelected
	self.nCharacterSelectedPos = tData.nId
	self.strCharacterSelectedName = tSelected and tSelected.strName or ""
	self.bCharacterRequiresRename = tSelected and tSelected.bRequiresRename

	if self.wndMainPicker and self.wndMainPicker:FindChild("AvailableScroll") then
		self.wndMainPicker:FindChild("AvailableScroll"):FindChild("AvailablePaidRenameBtn"):Enable(not self.bCharacterRequiresRename)
	end

	self:OnRenameCloseBtn()
	self:OnPaidTransferFlyoutCloseBtn()
	self:OnRevokeCancel()
end

function AccountServices:OnOpenCharacterCreateBtn() -- Generic Event, not a btn click
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() then
		self.wndMain:Show(false)
	elseif self.wndMinimized and self.wndMinimized:IsValid() and self.wndMinimized:IsVisible() then
		self.wndMinimized:Show(false)
	end
end

function AccountServices:OnPregame_CreationToSelection() -- Generic Event, not a btn click
	if not self.wndMain:IsShown() then
		self.wndMain:Show(true)
	end
end

function AccountServices:OnShowMainPicker(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Invoke()
	end
	if self.wndMinimized and self.wndMinimized:IsValid() then
		self.wndMinimized:Close()
	end
end

function AccountServices:OnHideMainPicker(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Close()
	end
	if self.wndMinimized and self.wndMinimized:IsValid() then
		self.wndMinimized:Invoke()
	end
end

-----------------------------------------------------------------------------------------------
-- Rename
-----------------------------------------------------------------------------------------------

function AccountServices:DrawRenameFlyout(nRenameBound, nRenameEscrow)
	local bBoundEnable = nRenameBound > 0
	local bEscrowEnable = nRenameEscrow > 0
	self.wndRenameFlyout:FindChild("RenameConfirmBtn"):Enable(false)
	self.wndRenameFlyout:FindChild("RenamePaymentBound"):Enable(bBoundEnable)
	self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):Enable(bEscrowEnable)
	self.wndRenameFlyout:FindChild("RenamePaymentBound"):SetCheck(bBoundEnable)
	self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	self.wndRenameFlyout:FindChild("RenameCharacterFirstNameEntry"):SetPrompt(Apollo.GetString("CRB_FirstName"))
	self.wndRenameFlyout:FindChild("RenameCharacterLastNameEntry"):SetPrompt(Apollo.GetString("CRB_LastName"))
	self.wndRenameFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nRenameBound))
	self.wndRenameFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nRenameEscrow))
	self.wndRenameFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndRenameFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndRenameFlyout:FindChild("CharacterLimit"):SetText(string.format("[%s/%s]", 0, knMaxCharacterName))

end

function AccountServices:OnRenameCloseBtn(wndHandler, wndControl)
	if self.wndRenameFlyout and self.wndRenameFlyout:IsValid() then
		self.wndRenameFlyout:FindChild("StatusFirstValidAlert"):Show(false)
		self.wndRenameFlyout:FindChild("StatusLastValidAlert"):Show(false)
		self.wndRenameFlyout:FindChild("RenameCharacterFirstNameEntry"):SetText("")
		self.wndRenameFlyout:FindChild("RenameCharacterLastNameEntry"):SetText("")
		self.wndRenameFlyout:Close()
		self.strFireRenameOnUpdate = nil
	end
end

function AccountServices:OnRenameInputBoxChanged(wndHandler, wndControl)
	local strFullName = string.format("%s %s", 
		self.wndRenameFlyout:FindChild("RenameCharacterFirstNameEntry"):GetText(), 
		self.wndRenameFlyout:FindChild("RenameCharacterLastNameEntry"):GetText()
	)
	
	local strFirstName = self.wndRenameFlyout:FindChild("RenameCharacterFirstNameEntry"):GetText()
	local nFirstLength = Apollo.StringLength(strFirstName)
	
	local strLastName = self.wndRenameFlyout:FindChild("RenameCharacterLastNameEntry"):GetText()
	local nLastLength = Apollo.StringLength(strLastName)
	
	local strCharacterLimit = string.format("[%s/%s]", nFirstLength+nLastLength, knMaxCharacterName)
	local strColor = nFirstLength+nLastLength > knMaxCharacterName and "Reddish" or "UI_TextHoloBodyCyan"
	self.wndRenameFlyout:FindChild("CharacterLimit"):SetTextColor(ApolloColor.new(strColor))
	self.wndRenameFlyout:FindChild("CharacterLimit"):SetText(strCharacterLimit)
	
	local bFirstValid = CharacterScreenLib.IsCharacterNamePartValid(strFirstName)
	self.wndRenameFlyout:FindChild("StatusFirstValidAlert"):Show(not bFirstValid and nFirstLength > 0)
	
	local bLastValid = CharacterScreenLib.IsCharacterNamePartValid(strLastName)
	self.wndRenameFlyout:FindChild("StatusLastValidAlert"):Show(not bLastValid and nLastLength > 0)
	
	local bFullValid = CharacterScreenLib.IsCharacterNameValid(strFullName)
	self.wndRenameFlyout:FindChild("RenameConfirmBtn"):SetData(strFullName)
	self.wndRenameFlyout:FindChild("RenameConfirmBtn"):Enable(bFullValid)
	
end

function AccountServices:OnRenameConfirmBtn(wndHandler, wndControl)
	local bUsingEscrow = self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):IsChecked()
	local tEscrowData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.NameChange)

	local nCharacterId = self.nCharacterSelectedPos
	if not nCharacterId then
		return
	end

	self:ShowRenameConfirmation(wndHandler:GetData(), tEscrowData)

	self.wndRenameFlyout:Close()
end

function AccountServices:ShowRenameConfirmation(strFullName, tEscrowData)
	self.wndRenameConfirm = Apollo.LoadForm(self.xmlDoc, "RenameConfirmation", "AccountServices", self)
	self.wndRenameConfirm:FindChild("RenameExplanation"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RenameExplanation"), strFullName))
	self.wndRenameConfirm:FindChild("RenameYesBtn"):SetData({ strFullName = strFullName, nEscrowIndex = tEscrowData and tEscrowData.index })
	self.wndRenameConfirm:Invoke()
end

function AccountServices:OnRenameYesBtn(wndHandler, wndControl)
	local strFullName = wndHandler:GetData().strFullName
	local nEscrowIndex = wndHandler:GetData().nEscrowIndex

	if self.wndRenameFlyout:FindChild("RenamePaymentEscrow"):IsChecked() then
		AccountItemLib.ClaimPendingItemGroup(nEscrowIndex)
		self.strFireRenameOnUpdate = strFullName
		-- HelperCatchTriggers will catch the event, detect a non nil self.strFireRenameOnUpdate, then call Rename
	else
		CharacterScreenLib.RenameCharacter(self.nCharacterSelectedPos, strFullName)
	end
	self.wndRenameConfirm:Destroy()
end

function AccountServices:OnRenameNoBtn(wndHandler, wndControl)
	self.strFireRenameOnUpdate = nil
	self.wndRenameConfirm:Destroy()
end

function AccountServices:OnRenameNameEscape(wndHandler, wndControl)
	self.wndRenameFlyout:Close()
end

function AccountServices:OnCopyYesBtn(wndHandler, wndControl)
	CharacterScreenLib.InitiatePTRCharacterCopy(self.nCharacterSelectedPos)
	self.wndCopyPTRConfirmation:Show(false)
end

function AccountServices:OnCopyNoBtn(wndHandler, wndControl)
	self.wndCopyPTRConfirmation:Show(false)
end


-----------------------------------------------------------------------------------------------
-- Transfer
-----------------------------------------------------------------------------------------------

function AccountServices:OnMainPickerCopyCheck(wndHandler, wndControl)
	self.wndCopyPTRConfirmation:FindChild("CopyExplanation"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_CopySelectedName"), self.strCharacterSelectedName))
end

function AccountServices:OnMainPickerFreeRealmCheck(wndHandler, wndControl)
	CharacterScreenLib.GetRealmTransferDestinations(false) -- Leads to TransferDestinationRealmList
end

function AccountServices:OnMainPickerPaidRealmCheck(wndHandler, wndControl)
	CharacterScreenLib.GetRealmTransferDestinations(true) -- Leads to TransferDestinationRealmList
end

function AccountServices:OnTransferDestinationRealmList(tRealmList)
	if not self.wndPaidTransferFlyout and not self.wndPaidTransferFlyout:IsValid() then
		return
	end

	-- Helper Method
	local function HelperGridFactoryProduce(wndGrid, tTargetComparisonId)
		for nRow = 1, wndGrid:GetRowCount() do
			local tRealmData = wndGrid:GetCellLuaData(nRow, 1)
			if tRealmData and tRealmData.nRealmId == tTargetComparisonId then -- GetCellLuaData args are row, col
				return nRow
			end
		end
		return wndGrid:AddRow("") -- GOTCHA: This is a row number
	end

	local bFree = self.wndFreeTransferFlyout:IsVisible() -- If Free, show everything
	local tMyRealmInfo = CharacterScreenLib.GetRealmInfo()
	-- local bFreeRealmTransferSource = tMyRealmInfo and tMyRealmInfo.bFreeRealmTransfer or false -- Not needed currently

	-- Build Grid
	local tMyRealmInfo = CharacterScreenLib.GetRealmInfo()
	local wndGrid = self.wndPaidTransferFlyout:IsVisible() and self.wndPaidTransferFlyout:FindChild("PaidTransferGrid") or self.wndFreeTransferFlyout:FindChild("FreeTransferGrid")
	for idxRealm, tCurr in pairs(tRealmList) do
		if (bFree or not tCurr.bIsFree) and tMyRealmInfo.strName ~= tCurr.strName then
			-- Strings for Cell 1,2,3 respectively
			local strRealmType = tCurr.nRealmPVPType == PreGameLib.CodeEnumRealmPVPType.PVP and Apollo.GetString("RealmSelect_PvP") or Apollo.GetString("RealmSelect_PvE")
			local strLongRealm = "<T Image=\"CRB_Basekit:kitIcon_Holo_Profile\"></T>"..PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RealmNameNum"), tCurr.strName, tCurr.nCount)
			local tCellStrings =
			{
				tCurr.nCount > 0 and strLongRealm or tCurr.strName,
				strRealmType,
				ktRealmPopToString[tCurr.nPopulation + 1],
				tCurr.strNote,
			}

			local wndCurrRow = HelperGridFactoryProduce(wndGrid, tCurr.nRealmId) -- GOTCHA: This is an integer
			wndGrid:SetCellLuaData(wndCurrRow, 1, tCurr)
			for idxCell, strCellString in pairs(tCellStrings) do
				local strSortText = strCellString
				if idxCell == 1 and tCurr.nCount > 0 then
					strSortText = (100 - tCurr.nCount) .. tCurr.strName
				end
				wndGrid:SetCellSortText(wndCurrRow, idxCell, strSortText)
				wndGrid:SetCellDoc(wndCurrRow, idxCell, string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>", strCellString))
			end
		end
	end

	wndGrid:SetColumnText(1, Apollo.GetString("CRB_Name"))
	wndGrid:SetColumnText(2, Apollo.GetString("AccountServices_TypeColHeader"))
	wndGrid:SetColumnText(3, Apollo.GetString("AccountServices_PopHeader"))
	wndGrid:SetColumnText(4, Apollo.GetString("AccountServices_NoteHeader"))
	wndGrid:SetSortColumn(1, true) -- Sort 1st column Ascending
end

function AccountServices:OnPTRCharacterCopyQueued()
	self.wndCopyQueued:FindChild("Body"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_CopyQueued"), self.strCharacterSelectedName))
	self.wndCopyQueued:Invoke()
end

function AccountServices:OnConfirmQueuedBtn(wndHandler, wndControl)
	self.wndCopyQueued:Show(false)
end

function AccountServices:ShowTransferConfirmation(bPaid, nRealmId, strRealm, tEscrowData) -- 4th arg nil for Free Transfers/Account Bound
	if self.wndTransferConfirm and self.wndTransferConfirm:IsValid() then
		self.wndTransferConfirm:Destroy()
	end
	local strPayment = bPaid and Apollo.GetString("AccountServices_PaidRealmTransfer") or Apollo.GetString("AccountServices_FreeRealmTransfer")
	local strExplanation = PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_TransferExplanation"), self.strCharacterSelectedName, strRealm, strPayment)
	self.wndTransferConfirm = Apollo.LoadForm(self.xmlDoc, "TransferConfirmation", "AccountServices", self)
	self.wndTransferConfirm:FindChild("PaidTransferYesBtn"):SetData({ nRealmId = nRealmId, nEscrowIndex = tEscrowData and tEscrowData.index })
	self.wndTransferConfirm:FindChild("FreeTransferYesBtn"):SetData({ nRealmId = nRealmId })
	self.wndTransferConfirm:FindChild("FreeTransferYesBtn"):Show(not bPaid)	
	self.wndTransferConfirm:FindChild("PaidTransferYesBtn"):Show(bPaid)
	self.wndTransferConfirm:FindChild("TransferTitle"):SetText(strPayment)
	self.wndTransferConfirm:FindChild("TransferExplanation"):SetText(strExplanation)
	self.wndTransferConfirm:FindChild("TransferNameInput"):SetMaxTextLength(knMaxCharacterName+1) --They type the space in this.
	self.wndTransferConfirm:FindChild("TransferNameInput"):SetPrompt(self.strCharacterSelectedName)
	self.wndTransferConfirm:FindChild("FreeTransferYesBtn"):Enable(false)
	self.wndTransferConfirm:FindChild("PaidTransferYesBtn"):Enable(false)
	self.wndTransferConfirm:Invoke()
end

function AccountServices:OnTransferNameChanged()
	if self.wndTransferConfirm and self.wndTransferConfirm:IsValid() then
		local strCharName = self.wndTransferConfirm:FindChild("TransferNameInput"):GetText()
		self.wndTransferConfirm:FindChild("FreeTransferYesBtn"):Enable(Apollo.StringToLower(self.strCharacterSelectedName) == Apollo.StringToLower(strCharName))
		self.wndTransferConfirm:FindChild("PaidTransferYesBtn"):Enable(Apollo.StringToLower(self.strCharacterSelectedName) == Apollo.StringToLower(strCharName))
	end
end

function AccountServices:OnFreeTransferYesBtn(wndHandler, wndControl) -- wndHandler is FreeTransferYesBtn, Data is nRealmId
	local bPaid = false
	-- Free won't need to care about nEscrowIndex
	CharacterScreenLib.RealmTransfer(self.nCharacterSelectedPos, wndHandler:GetData().nRealmId, bPaid)
	self.wndTransferConfirm:Destroy()
end

function AccountServices:OnPaidTransferYesBtn(wndHandler, wndControl) -- wndHandler is TransferYesBtn, Data is nRealmId
	local bPaid = true
	local nRealmId = wndHandler:GetData().nRealmId
	local nEscrowIndex = wndHandler:GetData().nEscrowIndex

	if self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):IsChecked() then
		AccountItemLib.ClaimPendingItemGroup(nEscrowIndex)
		self.nFirePaidTransferOnUpdate = nRealmId
		-- HelperCatchTriggers will catch the event, detect a non nil self.nFirePaidTransferOnUpdate, then call Transfer
	else
		CharacterScreenLib.RealmTransfer(self.nCharacterSelectedPos, nRealmId, bPaid)
	end
	self.wndTransferConfirm:Destroy()
end

function AccountServices:OnTransferConfirmNoBtn(wndHandler, wndControl)
	self.nFirePaidTransferOnUpdate = nil
	self.wndTransferConfirm:Destroy()
end

-----------------------------------------------------------------------------------------------
-- Free Transfer
-----------------------------------------------------------------------------------------------

function AccountServices:DrawFreeTransferFlyout()
	self.wndFreeTransferFlyout:FindChild("FreeTransferConfirmBtn"):Enable(false) -- Until grid is clicked
end

function AccountServices:OnFreeTransferGridClick(wndHandler, wndControl, iRow, iCol, eMouseButton)
	local wndGrid = self.wndFreeTransferFlyout:FindChild("FreeTransferGrid")
	local tRealmData = wndGrid:GetCellData(iRow, 1)
	local nRealmId = tRealmData.nRealmId

	local bClicked = wndGrid:GetData() ~= nRealmId
	if bClicked then
		wndGrid:SetData(nRealmId)
	else
		wndGrid:SetData(nil)
		wndGrid:SetCurrentRow(0) -- Deselect grid
	end

	self.wndFreeTransferFlyout:FindChild("FreeTransferConfirmBtn"):Enable(bClicked)
	self.wndFreeTransferFlyout:FindChild("FreeTransferConfirmBtn"):SetData({ nRealmId = nRealmId, strRealm = tRealmData.strName or "" })
	-- Clicking a grid row enables a button that will do FreeTransferConfirmBtn which will do ShowTransferConfirmation
end

function AccountServices:OnFreeTransferConfirmBtn(wndHandler, wndControl)
	local nRealmId = wndHandler:GetData().nRealmId
	local strRealm = wndHandler:GetData().strRealm
	local nCharacterId = self.nCharacterSelectedPos
	if not nCharacterId then
		return
	end

	local bPaid = false
	self:ShowTransferConfirmation(bPaid, nRealmId, strRealm)
	self.wndFreeTransferFlyout:Close()
end

function AccountServices:OnFreeTransferFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndFreeTransferFlyout and self.wndFreeTransferFlyout:IsValid() then
		self.wndFreeTransferFlyout:Close()
	end
end

-----------------------------------------------------------------------------------------------
-- Paid Transfer
-----------------------------------------------------------------------------------------------

function AccountServices:DrawPaidTransferFlyout(nTransferBound, nTransferEscrow)
	local bBoundEnable = nTransferBound > 0
	local bEscrowEnable = nTransferEscrow > 0
	self.wndPaidTransferFlyout:FindChild("TransferPaymentBound"):Enable(bBoundEnable)
	self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):Enable(bEscrowEnable)
	self.wndPaidTransferFlyout:FindChild("TransferPaymentBound"):SetCheck(bBoundEnable)
	self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):SetCheck(not bBoundEnable and bEscrowEnable)
	self.wndPaidTransferFlyout:FindChild("BoundBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nTransferBound))
	self.wndPaidTransferFlyout:FindChild("EscrowBtnSubtitle"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_NumAvailable"), nTransferEscrow))
	self.wndPaidTransferFlyout:FindChild("BoundBtnSubtitle"):SetTextColor(bBoundEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndPaidTransferFlyout:FindChild("EscrowBtnSubtitle"):SetTextColor(bEscrowEnable and ApolloColor.new("UI_BtnTextBlueNormal") or ApolloColor.new("UI_TextMetalBodyHighlight"))
	self.wndPaidTransferFlyout:FindChild("TransferPaymentArrangeHorz"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	self.wndPaidTransferFlyout:FindChild("PaidTransferConfirmBtn"):Enable(false) -- Until grid is clicked
end

function AccountServices:OnPaidTransferGridClick(wndHandler, wndControl, iRow, iCol, eMouseButton)
	local wndGrid = self.wndPaidTransferFlyout:FindChild("PaidTransferGrid")
	local tRealmData = wndGrid:GetCellData(iRow, 1)
	local nRealmId = tRealmData.nRealmId

	local bClicked = wndGrid:GetData() ~= nRealmId
	if bClicked then
		wndGrid:SetData(nRealmId)
	else
		wndGrid:SetData(nil)
		wndGrid:SetCurrentRow(0) -- Deselect grid
	end

	self.wndPaidTransferFlyout:FindChild("PaidTransferConfirmBtn"):Enable(bClicked)
	self.wndPaidTransferFlyout:FindChild("PaidTransferConfirmBtn"):SetData({ nRealmId = nRealmId, strRealm = tRealmData.strName or "" })
	-- Clicking a grid row enables a button that will do FreeTransferConfirmBtn which will do ShowTransferConfirmation
end

function AccountServices:OnPaidTransferConfirmBtn(wndHandler, wndControl)
	local bUsingEscrow = self.wndPaidTransferFlyout:FindChild("TransferPaymentEscrow"):IsChecked()
	local tEscrowData, bGiftableGroup = self:HelperDeterminePayment(bUsingEscrow, PreGameLib.CodeEnumAccountCurrency.RealmTransfer)

	local bPaid = true
	local nRealmId = wndHandler:GetData().nRealmId
	local strRealm = wndHandler:GetData().strRealm
	local nCharacterId = self.nCharacterSelectedPos
	if not nCharacterId then
		return
	end

	self:ShowTransferConfirmation(bPaid, nRealmId, strRealm, tEscrowData)

	self.wndPaidTransferFlyout:Close()
end

function AccountServices:OnPaidTransferFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndPaidTransferFlyout and self.wndPaidTransferFlyout:IsValid() then
		self.wndPaidTransferFlyout:Close()
	end
end

-----------------------------------------------------------------------------------------------
-- Trusted IP
-----------------------------------------------------------------------------------------------

function AccountServices:OnTrustedIPFlyoutCloseBtn(wndHandler, wndControl)
	if self.wndTrustedIPFlyout and self.wndTrustedIPFlyout:IsValid() then
		self.wndTrustedIPFlyout:Close()
	end
end

function AccountServices:OnTrustedIPForgetBtn( wndHandler, wndControl, eMouseButton )
	local arListOfIPsToForget = {}
	
	if not self.wndTrustedIPFlyout then
		self.wndTrustedIPFlyout = self.wndMain:FindChild("TrustedIPFlyout")
	end
	
	local wndTrustedIPContent = self.wndTrustedIPFlyout:FindChild("TrustedIPContent")
	for idx, wndIp in pairs(wndTrustedIPContent:GetChildren()) do
		local wndCheck = wndIp:FindChild("Button")
		if wndCheck:IsChecked() then
			arListOfIPsToForget[#arListOfIPsToForget + 1] = wndCheck:GetData().ipAddress
		end
	end
	
	if #arListOfIPsToForget > 0 then
		AccountItemLib.RevokeTrustedIP(arListOfIPsToForget)
	end
	
	self.wndTrustedIPFlyout:Close()
end

-----------------------------------------------------------------------------------------------
-- Confirmations
-----------------------------------------------------------------------------------------------
function AccountServices:OnCloseAllOpenAccountWindows(wndHandler, wndControl) -- This is triggered from other Pregame
	self:CloseAllOpenAccountWindows()
end

function AccountServices:CloseAllOpenAccountWindows(wndHandler, wndControl)
	self:OnPaidTransferFlyoutCloseBtn()
	self:OnFreeTransferFlyoutCloseBtn()
	self:OnRenameCloseBtn()
	self:OnTrustedIPFlyoutCloseBtn()
end

function AccountServices:HelperCheckTriggers()
	if self.strFireRenameOnUpdate ~= nil then
		CharacterScreenLib.RenameCharacter(self.nCharacterSelectedPos, self.strFireRenameOnUpdate)
		self.strFireRenameOnUpdate = nil
		return
	end

	if self.bFireCreddOnUpdate ~= nil then
		Apollo.CreateTimer("Pregame_RedeemCreddDelay", 1, false)
		Apollo.StartTimer("Pregame_RedeemCreddDelay")
		self.bFireCreddOnUpdate = nil
		return
	end

	if self.nFirePaidTransferOnUpdate ~= nil then
		local bPaid = true
		CharacterScreenLib.RealmTransfer(self.nCharacterSelectedPos, self.nFirePaidTransferOnUpdate, bPaid)
		self.nFirePaidTransferOnUpdate = nil
		return
	end
	-- Free Transfers not needed
end

function AccountServices:OnPregame_RedeemCreddDelay()
	Apollo.StopTimer("Pregame_RedeemCreddDelay")
	AccountItemLib.RedeemCREDD()
	if not self.wndRedeemCreddDelay then
		self.wndRedeemCreddDelay = Apollo.LoadForm(self.xmlDoc, "RedeemCreddDelaySpinner", "AccountServices", self)
	end

	if self.wndLapsedPopup and self.wndLapsedPopup:IsValid() then
		self.wndLapsedPopup:Destroy()
		self.wndLapsedPopup = nil
	end
end

function AccountServices:HelperDeterminePayment(bUsingEscrow, ePendingTypeRequested)
	local tEscrowData = nil
	local bGiftableGroup = bUsingEscrow

	-- If no singles, then pick the smallest group to use
	if bGiftableGroup then
		local nSmallestNumber = 0
		for idx, tPendingAccountItemGroup in pairs(AccountItemLib.GetPendingAccountItemGroups()) do
			for idx2, tPendingAccountItem in pairs(tPendingAccountItemGroup.items) do
				if tPendingAccountItem.accountCurrency and tPendingAccountItem.accountCurrency.accountCurrencyEnum == ePendingTypeRequested then
					local nCurrCount = #tPendingAccountItemGroup.items
					if nSmallestNumber == 0 or nCurrCount < nSmallestNumber then
						nSmallestNumber = nCurrCount
						tEscrowData = tPendingAccountItemGroup
					end
				end
			end
		end
	end

	return tEscrowData, bGiftableGroup
end

-----------------------------------------------------------------------------------------------
-- Error Messages
-----------------------------------------------------------------------------------------------

function AccountServices:OnErrorMessageClose(wndHandler, wndControl)
	if self.wndErrorMessage and self.wndErrorMessage:IsValid() then
		self.wndErrorMessage:Destroy()
	end
end

function AccountServices:OnCREDDRedeemResult(eResult)
	if self.wndErrorMessage and self.wndErrorMessage:IsValid() then
		self.wndErrorMessage:Destroy()
		self.wndErrorMessage = nil
	end

	if self.wndRedeemCreddDelay and self.wndRedeemCreddDelay:IsValid() then
		self.wndRedeemCreddDelay:Destroy()
		self.wndRedeemCreddDelay = nil
	end

	local bSuccess = eResult == PreGameLib.CodeEnumCharacterModifyResults.RedeemCREDDOk
	self.wndErrorMessage = Apollo.LoadForm(self.xmlDoc, "ErrorMessage", "AccountServices", self)
	self.wndErrorMessage:FindChild("ErrorMessageTitle"):SetText(bSuccess and Apollo.GetString("CRB_Success") or Apollo.GetString("CRB_Error"))
	self.wndErrorMessage:FindChild("ErrorMessageTitle"):SetTextColor(bSuccess and "UI_BtnTextGreenNormal" or "UI_BtnTextRedNormal")
	self.wndErrorMessage:FindChild("ErrorMessageBody"):SetText(Apollo.GetString(ktCreddRedeemResults[eResult]))

	if bSuccess then
		self.bCREDDRedeemResultSuccess = true
		
		if self.wndBlackFill and self.wndBlackFill:IsValid() then
			self.wndBlackFill:Destroy()
		end

		if self.wndLapsedBlocker and self.wndLapsedBlocker:IsValid() then
			self.wndLapsedBlocker:Destroy()
		end

		if self.wndLapsedPopup and self.wndLapsedPopup:IsValid() then
			self.wndLapsedPopup:Destroy()
		end
	end

	self:RedrawAll()
end

function AccountServices:OnRealmTransferResult(eResult)
	if self.wndErrorMessage and self.wndErrorMessage:IsValid() then
		self.wndErrorMessage:Destroy()
	end

	local bSuccess = eResult == PreGameLib.CodeEnumCharacterModifyResults.RealmTransferOk
	self.wndErrorMessage = Apollo.LoadForm(self.xmlDoc, "ErrorMessage", "AccountServices", self)
	self.wndErrorMessage:FindChild("ErrorMessageTitle"):SetText(bSuccess and Apollo.GetString("CRB_Success") or Apollo.GetString("CRB_Error"))
	self.wndErrorMessage:FindChild("ErrorMessageTitle"):SetTextColor(bSuccess and "UI_BtnTextGreenNormal" or "UI_BtnTextRedNormal")
	self.wndErrorMessage:FindChild("ErrorMessageBody"):SetText(Apollo.GetString(ktRealmTransferResults[eResult]))

	self:RedrawAll()
end

function AccountServices:OnCharacterRename(eRenameResult, strName)
	if eRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameOk and self.wndMainPicker and self.wndMainPicker:FindChild("AvailableScroll") then
		self.wndMainPicker:FindChild("AvailableScroll"):FindChild("AvailablePaidRenameBtn"):Enable(true)
	end

	self:RedrawAll()
end

-----------------------------------------------------------------------------------------------
-- Group Bind
-----------------------------------------------------------------------------------------------

function AccountServices:ShowGroupBindConfirmation(tEscrowData, tBindData) -- In this case tEscrowData is a tPendingAccountItemGroup (instead of a tPendingAccountItem)
	-- The actual confirmation button will need to be protected
	self.wndGroupBindConfirm = Apollo.LoadForm(self.xmlDoc, "GroupBindConfirmation", "AccountServices", self)
	self.wndGroupBindConfirm:Invoke()

	local strTitle = ""
	local strMessage = ""
	local nCurrCount = #tEscrowData.items
	if nCurrCount == 1 and tBindData.eType == keFireOnCredd then
		strTitle = Apollo.GetString("AccountServices_CREDD")
		strMessage = Apollo.GetString("AccountLogin_RedeemCREDDLogin")
	elseif nCurrCount == 1 and tBindData.eType == keFireOnRename then
		strTitle = Apollo.GetString("CRB_Rename")
		strMessage = PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RenameExplanation"), tBindData.strText)
	elseif nCurrCount == 1 and tBindData.eType == keFireOnPaidTransfer then
		local strPayment = Apollo.GetString("AccountServices_PaidRealmTransfer") -- Only paid transfers can be in a group
		strTitle = Apollo.GetString("AccountServices_PaidRealmTransfer")
		strMessage = PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_TransferExplanation"), self.strCharacterSelectedName, tBindData.strRealm, strPayment)
	else
		strTitle = PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_BindGroupPurchases"), #tEscrowData.items)
		strMessage = Apollo.GetString("AccountServices_GroupBindExplanation")
	end

	self.wndGroupBindConfirm:SetData(tBindData)
	self.wndGroupBindConfirm:FindChild("GroupBindTitle"):SetText(strTitle)
	self.wndGroupBindConfirm:FindChild("GroupBindExplanation"):SetText(strMessage)
	self.wndGroupBindConfirm:FindChild("GroupBindYesBtn"):SetData(tEscrowData.index)
	return self.wndGroupBindConfirm
end

function AccountServices:OnGroupBindYesBtn(wndHandler, wndControl) -- In this case tEscrowData is a tPendingAccountItemGroup (instead of a tPendingAccountItem)
	AccountItemLib.ClaimPendingItemGroup(wndHandler:GetData())

	if self.wndGroupBindConfirm:GetData().eType == keFireOnRename then
		self.strFireRenameOnUpdate = self.wndGroupBindConfirm:GetData().strText
	elseif self.wndGroupBindConfirm:GetData().eType == keFireOnCredd then
		self.bFireCreddOnUpdate = true
	elseif self.wndGroupBindConfirm:GetData().eType == keFireOnPaidTransfer then
		self.nFirePaidTransferOnUpdate = self.wndGroupBindConfirm:GetData().nRealmId
	end

	self.wndGroupBindConfirm:Destroy()
end

function AccountServices:OnGroupBindNoBtn(wndHandler, wndControl)
	self.wndGroupBindConfirm:Destroy()
end

---------------------------------------------------------------------------------------------------
-- Trusted IPs
---------------------------------------------------------------------------------------------------

function AccountServices:OnTrustedIPListReady()
	self.bTrustedIPListReady = true
	self:RedrawAll()
end

function AccountServices:OnTrustedIpBtnCheck(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	tData.wndTrustedIPConfirmBtn:Enable(true)
end

function AccountServices:OnTrustedIpBtnUncheck(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	
	for idx, wndEntry in pairs(tData.wndTrustedIPContent:GetChildren()) do
		if wndEntry:FindChild("Button"):IsChecked() then
			tData.wndTrustedIPConfirmBtn:Enable(true)
			return
		end
	end
	
	tData.wndTrustedIPConfirmBtn:Enable(false)
end

function AccountServices:OnRevokeIP( wndHandler, wndControl, eMouseButton )
	local wndGrid = self.wndTrustedIPFlyout:FindChild("IPsGrid")
	local iRow = wndGrid:GetCurrentRow()
	if iRow > 0 then
		AccountItemLib.RevokeTrustedIP(wndGrid:GetCellText(iRow, 1))
		wndGrid:DeleteRow(iRow)
	end

	self.RedrawAll()
end

function AccountServices:OnRevokeCancel(wndHandler, wndControl)
	if self.wndTrustedIPsFlyout and self.wndTrustedIPsFlyout:IsValid() then
		self.wndTrustedIPsFlyout:Close()
	end
end

---------------------------------------------------------------------------------------------------
-- RandomLastNames
---------------------------------------------------------------------------------------------------

function AccountServices:OnRandomLastName()

	local nId = g_controls:FindChild("EnterBtn"):GetData()
	local tSelected = g_arCharacters[nId]
	
	local nRaceId = tSelected.idRace
	local nFactionId = tSelected.idFaction
	local nGenderId = tSelected.idGender

	local tName = PreGameLib.GetRandomName(nRaceId, nGenderId, nFactionId)

	
	self.wndRenameFlyout:FindChild("RenameCharacterLastNameEntry"):SetText(tName.strLastName)
	self.wndRenameFlyout:FindChild("RenameCharacterFirstNameEntry"):SetText(tName.strFirstName)

	self:OnRenameInputBoxChanged()

end

local AccountServicesInst = AccountServices:new()
AccountServicesInst:Init()
