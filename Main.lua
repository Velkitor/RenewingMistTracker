local myFrame = CreateFrame("frame")
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("ADDON_LOADED")

local myData = {
	player={},
	players={},
	statusBars = {},
	renewing_mist_targets = {}
}

local remTracker = {}
-- Functions Section

function remTracker:updateStatusBars()
	local current_rem_targets = 0
	-- Count our current targets
	for k,v in pairs(myData.renewing_mist_targets) do
		current_rem_targets = current_rem_targets + 1
	end
	if #myData.statusBars < current_rem_targets then
		remTracker:createStatusBars( current_rem_targets - #myData.statusBars)
	end
	-- Hide and show the correct number of bars
	for i = 1, #myData.statusBars, 1 do
		if i <= current_rem_targets then
			myData.statusBars[i]:Show()
		else
			myData.statusBars[i]:Hide()
		end
	end
	-- Add new renewing mist targets
	local status_bar_index = 1
	for k,v in pairs(myData.renewing_mist_targets) do
		if myData.players[k] and myData.statusBars[ status_bar_index ] then
			local duration = v.expirationTime - GetTime()
			myData.statusBars[ status_bar_index ].playerName = myData.players[k].name
			myData.statusBars[ status_bar_index ].value:SetText( myData.players[k].name .. " - (" .. string.format("%4.1f", v.currentHealthPct ) .. "%) " .. string.format("%4.1f", duration) .. "s" )
			myData.statusBars[ status_bar_index ]:SetMinMaxValues(0, v.duration)
			myData.statusBars[ status_bar_index ]:SetValue( duration )
		else
			myData.statusBars[ status_bar_index ].value:SetText( "" )
		end
		-- Increment the status bar index for the next iteration
		status_bar_index = status_bar_index + 1
	end
end

function remTracker:createStatusBars( cnt )
	for i = 1, cnt, 1 do
		local yOffset = #myData.statusBars * 22 + 20
		-- Create the bar
		local bar = CreateFrame("StatusBar", nil, myData.uiFrame)
		bar:SetPoint("TOPLEFT", 3, -3 - yOffset)
		bar:SetPoint("TOPRIGHT", -3, -3 - yOffset)
		bar:SetHeight(20)
		bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		bar:GetStatusBarTexture():SetHorizTile(false)
		bar:GetStatusBarTexture():SetVertTile(false)
		bar:SetStatusBarColor(0.5, 1, 0.831)
		bar:EnableMouse(true)

		-- Do we have the player name for this bar?
		bar.value = bar:CreateFontString(nil, "OVERLAY")
		bar.value:SetPoint("LEFT", bar, "LEFT", 4, 0)
		bar.value:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
		bar.value:SetJustifyH("LEFT")
		bar.value:SetShadowOffset(1, -1)
		bar.value:SetTextColor(0, 1, 0)
		-- Initialize the text with an empty string
		bar.value:SetText( "" )
		-- Hide it so that we don't show empty bars.
		bar:Hide()
		-- Save it to our status bars table
		table.insert( myData.statusBars, bar )
	end
end

function remTracker:createUIFrame()
	local frame = CreateFrame("Frame", "ReMTracker", UIParent)
	-- Orient our UI Frame
	frame:SetSize(200, 20)
	frame:SetPoint("CENTER", UIParent)
	frame:SetBackdrop({
	    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
	    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
	    insets = { left = 3, right = 3, top = 3, bottom = 3, },
	})
	
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetUserPlaced(true)
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	
	-- Create the title text
	frame.titleText = frame:CreateFontString(nil, "OVERLAY")
	frame.titleText:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.titleText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	frame.titleText:SetJustifyH("LEFT")
	frame.titleText:SetShadowOffset(1, -1)
	frame.titleText:SetTextColor(0, 1, 0)
	frame.titleText:SetText( "Renewing Mist Tracker" )
	
	-- Create the lock button
	frame.dragLock = CreateFrame("Button", nil, frame)
	frame.dragLock:SetPoint("RIGHT", frame, "RIGHT", -3, 0)
	frame.dragLock:SetWidth(16)
	frame.dragLock:SetHeight(16)
	frame.dragLock:SetBackdropColor(1,1,1,1)
	-- frame.dragLock:SetBackdrop({
	--     bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
	--     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
	--     insets = { left = 3, right = 3, top = 3, bottom = 3, },
	-- })
	-- Create the texture for the button
	frame.dragLock.texture = frame.dragLock:CreateTexture()
	frame.dragLock.texture:SetPoint("CENTER", frame.dragLock,"CENTER", 0, 0)
	frame.dragLock.texture:SetTexture("Interface\\BUTTONS\\CancelButton-Highlight")
	frame.dragLock.texture:SetWidth(24)
	frame.dragLock.texture:SetHeight(24)
	
	frame.dragLock.toggleDragable = function()
		if not myData.uiFrame.dragDisabled then
			frame.dragLock.texture:SetTexture("Interface\\BUTTONS\\CancelButton-Up")
			frame.dragDisabled = true
			if frame:HasScript("OnDragStart") then
				frame:SetScript("OnDragStart", nil)
			end
		else
			frame.dragLock.texture:SetTexture("Interface\\BUTTONS\\CancelButton-Highlight")
			frame.dragDisabled = false
			frame:SetScript("OnDragStart", frame.StartMoving)
		end
	end
	frame.dragLock:SetScript("OnClick", frame.dragLock.toggleDragable)
	frame.dragLock:Show()
	frame:Show()
	
	myData.uiFrame = frame
end

function remTracker:playerLogin()
	myFrame:SetScript("OnUpdate", remTracker.OnUpdate )
	myData.player.guid = UnitGUID("PLAYER")
	myData.player.name = UnitName("PLAYER")
	-- Add ourselves to the database of seen players
	myData.players[ myData.player.guid ] = {}
	myData.players[ myData.player.guid ].name = myData.player.name
	DEFAULT_CHAT_FRAME:AddMessage( "Renewing Mist Tracker LOADED", 0.5, 1, 0.831 )
end

function remTracker:OnUpdate(self, elapsed)
	-- clear out our targets
	myData.renewing_mist_targets = {}
	local members = GetNumGroupMembers()
	local grp_type = "party"
	if IsInRaid() then
		grp_type = "raid"
	end
	-- Check self
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff("PLAYER", "Renewing Mist", nil, "PLAYER")
	if name then
		myData.renewing_mist_targets[ myData.player.guid ] = {}
		myData.renewing_mist_targets[ myData.player.guid ].expirationTime = expirationTime
		myData.renewing_mist_targets[ myData.player.guid ].duration = duration
		if UnitHealthMax("PLAYER") > 0 then
			myData.renewing_mist_targets[ myData.player.guid ].currentHealthPct = UnitHealth("PLAYER") / UnitHealthMax("PLAYER") * 100
		end
	end
	if members then
		for i = 1, members - 1, 1 do
			local unit_id = grp_type .. i
			local unit_guid = UnitGUID(unit_id)
			local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff(unit_id, "Renewing Mist", nil, "PLAYER")
			if name then
 				myData.renewing_mist_targets[ unit_guid ] = {}
 				myData.renewing_mist_targets[ unit_guid ].expirationTime = expirationTime
 				myData.renewing_mist_targets[ unit_guid ].duration = duration
				if UnitHealthMax("PLAYER") > 0 then
					myData.renewing_mist_targets[ myData.player.guid ].currentHealthPct = UnitHealth(unit_id) / UnitHealthMax(unit_id) * 100
				end
				if not myData.players[ unit_guid ] then
					myData.players[ unit_guid ] = {}
					myData.players[ unit_guid ].name = UnitName(unit_id)
				end
			end
		end
	end
	-- count the rem people
	local cnt = 0
	for k,v in pairs(myData.renewing_mist_targets) do
		cnt = cnt + 1
	end
	remTracker:updateStatusBars()
end


function OnEvent(self, event, addon)
	local localizedClass, englishClass = UnitClass("player");
	if not englishClass then
		DEFAULT_CHAT_FRAME:AddMessage( "Renewing Mist Tracker: This character is not a monk, not loading.", 0.5, 1, 0.831 )
		return
	end
	if englishClass ~= "MONK" then
		DEFAULT_CHAT_FRAME:AddMessage( "Renewing Mist Tracker: This character is not a monk, not loading.", 0.5, 1, 0.831 )
		return
	end
  if event == "PLAYER_LOGIN" then
		remTracker:playerLogin()
	elseif event == "ADDON_LOADED" then

  end
end

remTracker:createUIFrame()
myFrame:SetScript("OnEvent", OnEvent)
