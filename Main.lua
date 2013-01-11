local myFrame = CreateFrame("frame")
myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("ADDON_LOADED")
myFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

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
	local ordered_rem_targets = {}
	-- Count our current targets
	for k,v in pairs(myData.renewing_mist_targets) do
		current_rem_targets = current_rem_targets + 1
		table.insert( ordered_rem_targets, v )
	end
	-- Sort the ordered rem targets array
	table.sort( ordered_rem_targets, function(a,b) return a.remainingTime < b.remainingTime end )
	-- Color the TFT button
	if current_rem_targets > 5 then
		myData.uiFrame.tftTexture:SetVertexColor(1, 1, 0);
	else
		myData.uiFrame.tftTexture:SetVertexColor(1, 1, 1);
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
	for k,v in ipairs(ordered_rem_targets) do
		local guid = v.guid
		if myData.players[guid] and myData.statusBars[ status_bar_index ] then
			--Set up the unit name on the bar.
			myData.statusBars[ status_bar_index ].playerName = myData.players[guid].name
			myData.statusBars[ status_bar_index ].value:SetText( myData.players[guid].name)
			if myData.players[guid].classColor then
				myData.statusBars[ status_bar_index ].value:SetTextColor(myData.players[guid].classColor.r, myData.players[guid].classColor.g, myData.players[guid].classColor.b)
			end
			myData.statusBars[ status_bar_index ].value2:SetText(string.format("%4.1f", v.remainingTime) .. "s" )
			--Set the current health percentage
			myData.statusBars[ status_bar_index ].health_pct:SetText( string.format("%4.1f", v.currentHealthPct ) .. "%" )
			local health_level = ( v.currentHealthPct - 35 )
			if health_level < 0 then
				health_level = 0
			elseif health_level > 65 then
				health_level = 65
			end
			local health_green = health_level / 65.0
			local health_red = 1 - health_green
			myData.statusBars[ status_bar_index ].health_pct:SetTextColor(health_red ,  health_green, 0)
			
			--Set the progressbar state
			myData.statusBars[ status_bar_index ]:SetMinMaxValues(0, v.duration)
			myData.statusBars[ status_bar_index ]:SetValue( v.remainingTime )
		else
			myData.statusBars[ status_bar_index ].value:SetText( "" )
			myData.statusBars[ status_bar_index ].value2:SetText( "" )
			myData.statusBars[ status_bar_index ].health_pct:SetText( "" )
		end
		-- Increment the status bar index for the next iteration
		status_bar_index = status_bar_index + 1
	end
end

function remTracker:createStatusBars( cnt )
	for i = 1, cnt, 1 do
		local yOffset = #myData.statusBars * 26 + 20
		-- Create the bar
		local bar = CreateFrame("StatusBar", nil, myData.uiFrame)
		bar:SetPoint("TOPLEFT", 3, -3 - yOffset)
		bar:SetPoint("TOPRIGHT", -3, -3 - yOffset)
		bar:SetHeight(24)
		bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		bar:GetStatusBarTexture():SetHorizTile(false)
		bar:GetStatusBarTexture():SetVertTile(false)
		bar:SetStatusBarColor(0.5, 1, 0.831)
		bar:EnableMouse(true)

		bar.value = bar:CreateFontString(nil, "OVERLAY")
		bar.value:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, 0)
		bar.value:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
		bar.value:SetJustifyH("LEFT")
		bar.value:SetShadowOffset(1, -1)
		bar.value:SetTextColor(0, 1, 0)
		-- Initialize the text with an empty string
		bar.value:SetText( "" )
		
		-- Do we have the player name for this bar?
		bar.value2 = bar:CreateFontString(nil, "OVERLAY")
		bar.value2:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 4, 0)
		bar.value2:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
		bar.value2:SetJustifyH("LEFT")
		bar.value2:SetShadowOffset(1, -1)
		bar.value2:SetTextColor(0, 1, 0)
		-- Initialize the text with an empty string
		bar.value2:SetText( "" )
		
		bar.health_pct = bar:CreateFontString(nil, "OVERLAY")
		bar.health_pct:SetPoint("RIGHT", bar, "RIGHT", 4, 0)
		bar.health_pct:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
		bar.health_pct:SetJustifyH("RIGHT")
		bar.health_pct:SetShadowOffset(1, -1)
		bar.health_pct:SetTextColor(1, 0, 0)
		-- Initialize the text with an empty string
		bar.health_pct:SetText( "" )
		
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
	
	-- Create the ReM Indicator texture
	frame.remTexture = frame:CreateTexture()
	frame.remTexture:SetPoint("TOPLEFT", frame,"TOPLEFT", 0, 32)
	frame.remTexture:SetTexture("Interface\\Icons\\ability_monk_renewingmists")
	frame.remTexture:SetWidth(32)
	frame.remTexture:SetHeight(32)
	frame.remTexture:Show()
	frame.remTexture.spellName = "Renewing Mist"
	frame.remTexture.bounceTime = 0.75
	frame.remTexture.bounceHeight = 7
	frame.remTexture.animationPoint = { "TOPLEFT", frame,"TOPLEFT", 0, 32 }
	frame.remTexture.animationGrow = true
	frame.remTexture.animationGrowHeight = 32
	frame.remTexture.animationTime = 0
	
	-- Create the ReM Indicator texture
	frame.tftTexture = frame:CreateTexture()
	frame.tftTexture:SetPoint("TOPLEFT", frame,"TOPLEFT", 34, 32)
	frame.tftTexture:SetTexture("Interface\\Icons\\ability_monk_thunderfocustea")
	frame.tftTexture:SetWidth(32)
	frame.tftTexture:SetHeight(32)
	frame.tftTexture:Show()
	frame.tftTexture.spellName = "Thunder Focus Tea"
	frame.tftTexture.bounceTime = 0.75
	frame.tftTexture.bounceHeight = 7
	frame.tftTexture.animationPoint = { "TOPLEFT", frame,"TOPLEFT", 34, 32 }
	frame.tftTexture.animationGrow = true
	frame.tftTexture.animationGrowHeight = 32
	frame.tftTexture.animationTime = 0
	
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
	myData.player.spec = GetSpecialization()
	-- Add ourselves to the database of seen players
	remTracker:CacheUserInfoForUnitID( "PLAYER" )
	DEFAULT_CHAT_FRAME:AddMessage( "Renewing Mist Tracker Loaded", 0.5, 1, 0.831 )
end

--frame.remTexture
function remTracker:BounceAnimateFrame(frame, elapsed )
	local start, duration, enable = GetSpellCooldown(frame.spellName)
	local name, rank, icon, powerCost, isFunnel, powerType, castingTime, minRange, maxRange = GetSpellInfo(frame.spellName)
	if powerType then
		local playerPower = UnitPower( "PLAYER", powerType )
		if playerPower < powerCost then
			frame:SetDesaturated(true)
		else
			frame:SetDesaturated(false)
		end
	end
	-- If we have a duration it is on cooldown.
	if duration > 1.0 then
		local remaining_time = start + duration - GetTime()
		local pct_done = 1.0 - remaining_time / duration
		if pct_done <= 0.01 then
			frame:Hide()
		else
			frame:Show()
			-- We are not doing our normal animation so zero that out
			frame.animationTime = 0
			frame:SetPoint(frame.animationPoint[1], frame.animationPoint[2],frame.animationPoint[3], frame.animationPoint[4], frame.animationPoint[5] * pct_done )
			frame:SetHeight(frame.animationGrowHeight * pct_done)
			frame:SetTexCoord(0, 1 , 0, pct_done )
		end
	else
		local animation_time = frame.animationTime + elapsed
		frame.animationTime = animation_time
		-- Make sure the icon is visable if it is not on cooldown.
		frame:Show()
		frame:SetHeight(frame.animationGrowHeight)
		frame:SetTexCoord(0, 1 , 0, 1 )
		local animation_step = math.fmod( animation_time, frame.bounceTime )
		if animation_step < ( frame.bounceTime / 2 ) then
			animation_step = ( animation_step * 2 ) / frame.bounceTime
		else
			-- local a = ( animation_step * 2 )  - frame.bounceTime
			animation_step = 2  - ( 2 * animation_step  / frame.bounceTime )
		end
		frame:SetPoint(frame.animationPoint[1], frame.animationPoint[2],frame.animationPoint[3], frame.animationPoint[4], frame.animationPoint[5]  + ( frame.bounceHeight * animation_step ) )
	end
end

function remTracker:OnUpdate(elapsed)
	-- If we are not in healing spec hide the frame and exit this function
	if not remTracker:IsHealingSpec() then
			myData.uiFrame:Hide()
			return
	else
		myData.uiFrame:Show()
	end
	remTracker:BounceAnimateFrame(myData.uiFrame.remTexture, elapsed )
	remTracker:BounceAnimateFrame(myData.uiFrame.tftTexture, elapsed )
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
		myData.renewing_mist_targets[ myData.player.guid ].guid = myData.player.guid
		myData.renewing_mist_targets[ myData.player.guid ].expirationTime = expirationTime
		myData.renewing_mist_targets[ myData.player.guid ].duration = duration
		myData.renewing_mist_targets[ myData.player.guid ].remainingTime = expirationTime - GetTime()
		if UnitHealthMax("PLAYER") > 0 then
			myData.renewing_mist_targets[ myData.player.guid ].currentHealthPct = UnitHealth("PLAYER") / UnitHealthMax("PLAYER") * 100
		end
	end
	if members then
		for i = 1, members, 1 do
			local unit_id = grp_type .. i
			local unit_guid = UnitGUID(unit_id)
			local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff(unit_id, "Renewing Mist", nil, "PLAYER")
			if name then
 				myData.renewing_mist_targets[ unit_guid ] = {}
				myData.renewing_mist_targets[ unit_guid ].guid = unit_guid
 				myData.renewing_mist_targets[ unit_guid ].expirationTime = expirationTime
 				myData.renewing_mist_targets[ unit_guid ].duration = duration
				myData.renewing_mist_targets[ unit_guid ].remainingTime = expirationTime - GetTime()
				if UnitHealthMax("PLAYER") > 0 then
					myData.renewing_mist_targets[ unit_guid ].currentHealthPct = UnitHealth(unit_id) / UnitHealthMax(unit_id) * 100
				end
				if not myData.players[ unit_guid ] then
					remTracker:CacheUserInfoForUnitID( unit_id )
				end
			end
		end
	end
	remTracker:updateStatusBars()
end

function remTracker:IsHealingSpec()
	return ( myData.player.spec == 2 )
end

function remTracker:CacheUserInfoForUnitID( unit_id )
	-- If we don't have a unit_id just stop here
	if not unit_id then
		return
	end
	local unit_guid = UnitGUID(unit_id)
	local class, className = UnitClass(unit_id)
	myData.players[ unit_guid ] = {}
	myData.players[ unit_guid ].name = UnitName(unit_id)
	myData.players[ unit_guid ].className = className
	if className then
		myData.players[ unit_guid ].classColor = RAID_CLASS_COLORS[className]
	end
end

function OnEvent(self, event, arg1)
  if event == "PLAYER_LOGIN" then
		local localizedClass, englishClass = UnitClass("player");
		if englishClass ~= "MONK" then
			DEFAULT_CHAT_FRAME:AddMessage( "Renewing Mist Tracker: This character is not a monk, not loading.", 0.5, 1, 0.831 )
			return
		end
		remTracker:playerLogin()
	elseif event == "ADDON_LOADED" then
	elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
		-- The spec number is passed to us, but this reads better.
		myData.player.spec = GetSpecialization()
  end
end

remTracker:createUIFrame()
myFrame:SetScript("OnEvent", OnEvent)
