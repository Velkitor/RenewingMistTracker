_G.RenewingMistTracker = {}
local remTracker = _G.RenewingMistTracker

local myFrame = CreateFrame("frame", "RenewingMistTracker")

myFrame:RegisterEvent("PLAYER_LOGIN")
myFrame:RegisterEvent("ADDON_LOADED")
myFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
myFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local myData = {
	player={},
	players={},
	statusBars = {},
	renewing_mist_targets = {},
	renewing_mist_heals = {}
}
local Helpers = {}

-- Functions Section

function remTracker:updateStatusBars()
	local current_rem_targets = 0
	local targets_under_80pct = 0
	local ordered_rem_targets = {}
	-- Count our current targets
	for k,v in pairs(myData.renewing_mist_targets) do
		current_rem_targets = current_rem_targets + 1
		table.insert( ordered_rem_targets, v )
	end
	myData.current_rem_targets = current_rem_targets
	-- Sort the ordered rem targets array
	table.sort( ordered_rem_targets, function(a,b) return a.remainingTime < b.remainingTime end )

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
			if v.currentHealthPct < 80 then
				targets_under_80pct = targets_under_80pct + 1
			end
			local health_level = ( v.currentHealthPct - 35 )
			if health_level < 0 then
				health_level = 0
			elseif health_level > 65 then
				health_level = 65
			end
			local health_green = health_level / 65.0
			local health_red = 1 - health_green
			myData.statusBars[ status_bar_index ].health_pct:SetTextColor(health_red ,  health_green, 0)
			
			--Display the last heal information
			if myData.renewing_mist_heals[ guid ] and #myData.renewing_mist_heals[ guid ] > 0 then
				local heal_info = myData.renewing_mist_heals[ guid ][ #myData.renewing_mist_heals[ guid ] ]
				-- Basic error checking
				if not myData.statusBars[ status_bar_index ].heal_amt.player_guid or myData.statusBars[ status_bar_index ].heal_amt.player_guid ~= guid then
					myData.statusBars[ status_bar_index ].heal_amt.player_guid = guid
					myData.statusBars[ status_bar_index ].heal_amt.updaed_at = 0
				end
				if not myData.statusBars[ status_bar_index ].heal_amt.updaed_at then
					myData.statusBars[ status_bar_index ].heal_amt.updaed_at = 0
				end
				
				-- Set the text if need, otherwise fade it in
				if myData.statusBars[ status_bar_index ].heal_amt.updaed_at < heal_info.seen_at then
					local heal_text = Helpers:ReadableNumber( heal_info.effective, 2)
					if heal_info.over and heal_info.over > 0 then
						heal_text = heal_text .. " (" .. Helpers:ReadableNumber( heal_info.over, 2) .. ")"
					end
					myData.statusBars[ status_bar_index ].heal_amt:SetText( heal_text )
					myData.statusBars[ status_bar_index ].heal_amt.updaed_at = GetTime()
				else
					local delta = GetTime() - myData.statusBars[ status_bar_index ].heal_amt.updaed_at
					local alpha = 0
					--Scale it up for maths reasons!
					if delta < 0 then
						-- should never be the case.
						delta = 0
					else
						delta = delta * 20
					end
					
					if delta > 20 then
						alpha = 0
					elseif delta > 10 then
						alpha = 1
					else
						alpha = math.pow(delta,4) / 10000
					end
					myData.statusBars[ status_bar_index ].heal_amt:SetTextColor(0, 1, 0, alpha)
				end
			else
				myData.statusBars[ status_bar_index ].heal_amt:SetTextColor(0, 1, 0, 0)
				myData.statusBars[ status_bar_index ].heal_amt:SetText( "" )
			end
			
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
	myData.targets_under_80pct = targets_under_80pct
end

function remTracker:createStatusBars( cnt )
	for i = 1, cnt, 1 do
		local yOffset = #myData.statusBars * 26 + 20
		-- Create the bar
	 	local bar = remTracker.ui:CreateProgressBar( "rem_bar" .. #myData.statusBars, remTracker.ui.parent_frame )
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
		
		bar.heal_amt = bar:CreateFontString(nil, "OVERLAY")
		bar.heal_amt:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
		bar.heal_amt:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
		bar.heal_amt:SetJustifyH("CENTER")
		bar.heal_amt:SetShadowOffset(1, -1)
		bar.heal_amt:SetTextColor(0, 1, 0, 0)
		-- Initialize the text with an empty string
		bar.heal_amt:SetText( "" )
		
		-- Hide it so that we don't show empty bars.
		bar:Hide()
		-- Save it to our status bars table
		table.insert( myData.statusBars, bar )
	end
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


function remTracker:AnimateFrame( frame, elapsed )
	if frame.shouldHide and frame.shouldHide() then
		frame:Hide()
		return
	end
	remTracker:BlinkFrame( frame, elapsed )
	remTracker:BounceAnimateFrame(frame, elapsed )
end

function remTracker:BlinkFrame( frame, elapsed )
	if frame.shouldBlink and frame.shouldBlink() then
		local animation_time = frame.blinkAanimationTime or 0
		animation_time = animation_time + elapsed
		frame.blinkAanimationTime = animation_time
		-- Make sure the icon is visable if it is not on cooldown.
		local animation_step = math.sin( (math.fmod( animation_time, 1.5 ) / 1.5 ) * math.pi )
	
		frame:SetVertexColor(1, 1, animation_step);
	else
		frame:SetVertexColor(1, 1, 1);
	end
end
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
		local animation_step = math.sin( (math.fmod( animation_time, frame.bounceTime ) / frame.bounceTime ) * math.pi )

		frame:SetPoint(frame.animationPoint[1], frame.animationPoint[2],frame.animationPoint[3], frame.animationPoint[4], frame.animationPoint[5]  + ( frame.bounceHeight * animation_step ) )
	end
end

function remTracker:OnUpdate(elapsed)
	-- If we are not in healing spec hide the frame and exit this function
	if not remTracker:IsHealingSpec() then
			remTracker.ui:Hide()
			return
	else
		remTracker.ui:Show()
	end
	
	--Update our mana percentage
	local mana = UnitPower("PLAYER", SPELL_POWER_MANA)
	local max_mana = UnitPowerMax("Player",SPELL_POWER_MANA)
	
	if not max_mana or max_mana < 1 or not mana or mana < 1 then
		myData.player.mana_pct = 0
	else
		myData.player.mana_pct = (mana/max_mana) * 100
	end

	-- clear out our targets
	myData.renewing_mist_targets = {}
	-- It is possible that our Uplift will show 1 frame longer than it should... oh well.
	myData.hasRemTarget = false
	local members = GetNumGroupMembers()
	local grp_type = "party"
	if IsInRaid() then
		grp_type = "raid"
	end
	-- Check self
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff("PLAYER", "Renewing Mist", nil, "PLAYER")
	if name then
		if not myData.renewing_mist_heals[myData.player.guid] then
			myData.renewing_mist_heals[myData.player.guid] = {}
		end
		myData.hasRemTarget = true
		myData.renewing_mist_targets[ myData.player.guid ] = {}
		myData.renewing_mist_targets[ myData.player.guid ].guid = myData.player.guid
		myData.renewing_mist_targets[ myData.player.guid ].expirationTime = expirationTime
		myData.renewing_mist_targets[ myData.player.guid ].duration = duration
		myData.renewing_mist_targets[ myData.player.guid ].remainingTime = expirationTime - GetTime()
		if UnitHealthMax("PLAYER") > 0 then
			myData.renewing_mist_targets[ myData.player.guid ].currentHealthPct = UnitHealth("PLAYER") / UnitHealthMax("PLAYER") * 100
		end
	else
		myData.renewing_mist_heals[myData.player.guid] = {}
	end
	if members then
		for i = 1, members, 1 do
			local unit_id = grp_type .. i
			local unit_guid = UnitGUID(unit_id)
			local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff(unit_id, "Renewing Mist", nil, "PLAYER")
			if name then
				if not myData.renewing_mist_heals[ unit_guid ] then
					myData.renewing_mist_heals[ unit_guid ] = {}
				end
				myData.hasRemTarget = true
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
			else
				if not myData.renewing_mist_heals then
					myData.renewing_mist_heals = {}
				end
				myData.renewing_mist_heals[ unit_guid ] = {}
			end
		end
	end
	remTracker:updateStatusBars()
	--Animate our bars after we have collected data.
	remTracker.ui:Animate( elapsed )
	-- remTracker:AnimateFrame(myData.uiFrame.remTexture, elapsed )
	-- remTracker:AnimateFrame(myData.uiFrame.tftTexture, elapsed )
	-- remTracker:AnimateFrame(myData.uiFrame.upliftTexture, elapsed )
	-- remTracker:AnimateFrame(myData.uiFrame.manaTeaTexture, elapsed )
	
	-- Check if we should GC, only collect every 30 seconds
	if not myData.last_gc or GetTime() - myData.last_gc > 30 then
		collectgarbage("collect")
		myData.last_gc = GetTime()
	end
end

function remTracker:IsHealingSpec()
	return ( myData.player.spec == 2 )
end

function remTracker:QueryGlyphs()
	local glyphs = {}
	for i = 1, 6, 1 do
		local glyph_data = {}
		local enabled, glyphType, glyphTooltipIndex, glyphSpell, icon = GetGlyphSocketInfo(i)
		glyph_data.enabled = enabled
		glyph_data.glyph_type = glyphType
		glyph_data.tooltip_index = glyphTooltipIndex
		glyph_data.icon = icon
		glyph_data.spell_id = glyphSpell
		table.insert( glyphs, glyph_data )
	end
	myData.player.glyphs = glyphs
end

function remTracker:HasGlyph( spell_id )
	if not myData.player.glyphs then
		return false
	end
	if #myData.player.glyphs < 1 then
		return false
	end
	for k,v in pairs(myData.player.glyphs) do
		if v.spell_id and v.spell_id == spell_id then
			return true
		end
	end
	return false
end

--This will look nice in the code than remTracker:HasGlyph( 123763 ) 

function remTracker:HasManaTeaGlyph()
	return remTracker:HasGlyph( 123763 )
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

function remTracker:CombatLogEvent(...)
	local params = {...}
	-- If it is not from us, ignore it.
	if params[4] ~= myData.player.guid then
		return
	end
	if params[2] == "SPELL_PERIODIC_HEAL" then
		if params[13] == "Renewing Mist" then
			local heal_info = {}
			heal_info.seen_at = GetTime()
			heal_info.dest_guid = params[8]
			heal_info.amount = params[15]
			heal_info.over = params[16]
			heal_info.absorb = params[17]
			heal_info.effective = heal_info.amount - heal_info.over
			if not myData.renewing_mist_heals[ heal_info.dest_guid ] then
				myData.renewing_mist_heals[ heal_info.dest_guid ] = {}
			end
			table.insert( myData.renewing_mist_heals[ heal_info.dest_guid ], heal_info )
		end
	end
end


function remTracker:RegisterIndicators()
	local true_fn = function() return true end
	local frame = remTracker.ui.parent_frame
	
	local renewing_mist = remTracker.ui:CreateSpellTexture( frame, { "TOPLEFT", frame, "TOPLEFT", 0, 32 }, 32, 32, "Renewing Mist" )
	local thunder_focus_tea = remTracker.ui:CreateSpellTexture( frame, { "TOPLEFT", frame, "TOPLEFT", 34, 32 }, 32, 32, "Thunder Focus Tea" )
	local uplift = remTracker.ui:CreateSpellTexture( frame, { "TOPLEFT", frame, "TOPLEFT", 68, 32 }, 32, 32, "Uplift" )
	local mana_tea = remTracker.ui:CreateSpellTexture( frame, { "TOPLEFT", frame, "TOPLEFT", 170, 32 }, 32, 32, "Mana Tea" )
	
	--Setup all of the indicaors to bounce
	remTracker.ui:Bounce( renewing_mist, 0.75, 7, true_fn )
	remTracker.ui:Bounce( thunder_focus_tea, 0.75, 7, true_fn )
	remTracker.ui:Bounce( uplift, 0.75, 7, true_fn )
	remTracker.ui:Bounce( mana_tea, 0.75, 7, true_fn )
	
	--Set up the grow for cooldowns
	remTracker.ui:SetCooldownGrow( renewing_mist  )
	remTracker.ui:SetCooldownGrow( thunder_focus_tea  )
	remTracker.ui:SetCooldownGrow( mana_tea  )
	
	--Set up the blink for our indicators
	local thunder_focus_tea_blink = function()
			if myData.current_rem_targets > 5 then
				return true
			else
				return false
			end
	end
	remTracker.ui:Blink( thunder_focus_tea, 1.5, thunder_focus_tea_blink )
	
	local uplift_blink = function()
		if myData.targets_under_80pct > 2 then
			return true
		else
			return false
		end
	end
	remTracker.ui:Blink( uplift, 1.5, uplift_blink )
	
	local mana_tea_blink = function()
		if not myData.player.mana_pct or myData.player.mana_pct > 50 then
			return false
		else
			return true
		end
	end
	remTracker.ui:Blink( mana_tea, 1.5, mana_tea_blink )
	
	-- Set up when to hide
	local uplift_should_hide = function()
		return myData.hasRemTarget == false
	end
	remTracker.ui:ShouldHide( uplift, uplift_should_hide )
	local mana_tea_hide = function()
		if not myData.player.mana_pct or myData.player.mana_pct > 90 then
			return true
		end
		if not remTracker:HasManaTeaGlyph() then
			return true
		end
		local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff("PLAYER", "Mana Tea", nil, "PLAYER")
		if not count then
			return true
		end
		if count > 1 then
			return false
		end
		return true
	end
	remTracker.ui:ShouldHide( mana_tea, mana_tea_hide )
end

function OnEvent(self, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local combat_params = {...}
		remTracker:CombatLogEvent(...)
  elseif event == "PLAYER_LOGIN" then
		local localizedClass, englishClass = UnitClass("player")
		if englishClass ~= "MONK" then
			remTracker.ui:Hide()
			DEFAULT_CHAT_FRAME:AddMessage( "Renewing Mist Tracker: This character is not a monk, not loading.", 0.5, 1, 0.831 )
			return
		end
		remTracker:playerLogin()
		remTracker:QueryGlyphs()
	elseif event == "ADDON_LOADED" then
		if not remTracker.ui_loaded then
			remTracker.ui:SetupBaseFrames()
			remTracker.ui_loaded = true
			
			remTracker:RegisterIndicators()
		end
	elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
		-- The spec number is passed to us, but this reads better.
		myData.player.spec = GetSpecialization()
		remTracker:QueryGlyphs()
  end
end

myFrame:SetScript("OnEvent", OnEvent)

-- Helper functions

function Helpers:ReadableNumber(num, places)
    local ret
    local placeValue = ("%%.%df"):format(places or 0)
    if not num then
        return 0
    elseif num >= 1000000000000 then
        ret = placeValue:format(num / 1000000000000) .. " Tril" -- trillion
    elseif num >= 1000000000 then
        ret = placeValue:format(num / 1000000000) .. " Bil" -- billion
    elseif num >= 1000000 then
        ret = placeValue:format(num / 1000000) .. " Mil" -- million
    elseif num >= 1000 then
        ret = placeValue:format(num / 1000) .. "k" -- thousand
    else
        ret = num -- hundreds
    end
    return ret
end