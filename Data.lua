local RenewingMistTracker = _G.RenewingMistTracker

local Data = {
	units = {}
}

RenewingMistTracker.data = Data

function Data:LoadUnitInfo( unit_id )
	local guid = UnitGUID( unit_id )
	if not guid then
		return nil
	end
	if Data.units[ guid ] and Data.units[ guid ].name ~= "Unknown" then
		return Data.units[ guid ]
	end
	-- If we had data just update it
	local unit_info = Data.units[ guid ] or {}
	unit_info.guid = guid
	unit_info.name, unit_info.realm = UnitName( unit_id )
	local local_class, class_name = UnitClass( unit_id )
	unit_info.class_name = class_name
	
	Data.units[ guid ] = unit_info
	return unit_info
end

function Data:UpdateUnitHealth( unit_id )
	local unit_info = Data:LoadUnitInfo( unit_id )
	if not unit_info then
		return nil
	end
	unit_info.max_hp = UnitHealthMax(unit_id)
	unit_info.current_hp = UnitHealth(unit_id)
	if unit_info.max_hp and unit_info.max_hp > 0 then
		unit_info.pct_hp = ( unit_info.current_hp / unit_info.max_hp ) * 100
	else
		unit_info.pct_hp = 0
	end

	return unit_info
end

function Data:QuerySpellInfoForUnit( spell_name, unit_id )
	if not spell_name then
		return nil
	end
	if not unit_id then
		return nil
	end
	local unit_info = Data:LoadUnitInfo( unit_id )
	if not unit_info then
		return nil
	end
	local guid = UnitGUID( unit_id )
	local name, rank, icon, count, debuffType, duration, expiration_time, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff, value1, value2, value3 = UnitBuff(unit_id, spell_name, nil, "PLAYER")
		
	if not unit_info[ spell_name ] then
		unit_info[ spell_name ] = {}
	end
	local spell_info = unit_info[ spell_name ]
	
	spell_info.name = name
	spell_info.icon = icon
	spell_info.count = count
	spell_info.duration = duration
	spell_info.expiration_time = expiration_time
	
	return spell_info
end

function Data:UpdateRenewingMistTick( seen_at, target_guid, amount, over, effective)
	local unit_info = Data.units[ target_guid ]
	if not unit_info then
		return
	end
	if not unit_info["Renewing Mist"] then
		return
	end
	local last_heal = unit_info["Renewing Mist"].last_heal or {}
	last_heal.at = seen_at or GetTime()
	last_heal.amount = amount or 0
	last_heal.over = over or 0
	last_heal.effective = effective
	
	unit_info["Renewing Mist"].last_heal = last_heal
end