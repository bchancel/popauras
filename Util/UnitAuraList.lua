local _, ns = ...

-- PopAuras intentionally contains no aura enumeration helpers. This module
-- only translates the existing UI configuration into AuraContainer options.
local UnitAuraList = {}
ns.util.UnitAuraList = UnitAuraList

local TARGET_MODES = { all = true, mine_only = true, mine_or_unowned = true }

function UnitAuraList:GetTriggerConfig(trigger)
  local unit = trigger and trigger.unit or "player"
  local helpful = (trigger and trigger.auraType or "buff") ~= "debuff"
  return unit, helpful
end

function UnitAuraList:GetSourceValue(trigger)
  local unit, helpful = self:GetTriggerConfig(trigger)
  if unit == "target" then return helpful and "target_buff" or "target_debuff" end
  return helpful and "player_buff" or "player_debuff"
end

function UnitAuraList:GetTargetDebuffFilterMode(trigger)
  local mode = tostring(trigger and trigger.targetDebuffFilterMode or "")
  if TARGET_MODES[mode] then return mode end
  return trigger and trigger.targetMineOrUnownedOnly == true and "mine_or_unowned" or "all"
end

function UnitAuraList:ApplyTargetDebuffFilterMode(trigger, value)
  trigger = trigger or {}
  local mode = tostring(value or "all")
  if not TARGET_MODES[mode] then mode = "all" end
  trigger.targetDebuffFilterMode = mode
  trigger.targetMineOrUnownedOnly = mode == "mine_or_unowned"
  return trigger
end

function UnitAuraList:ApplySourceValue(trigger, value)
  trigger = trigger or {}
  value = tostring(value or "player_buff")
  if value == "target_debuff" then
    trigger.unit, trigger.auraType = "target", "debuff"
  elseif value == "target_buff" then
    trigger.unit, trigger.auraType = "target", "buff"
  elseif value == "player_debuff" then
    trigger.unit, trigger.auraType = "player", "debuff"
  else
    trigger.unit, trigger.auraType = "player", "buff"
  end
  if trigger.unit ~= "target" or trigger.auraType ~= "debuff" then
    self:ApplyTargetDebuffFilterMode(trigger, "all")
  end
  return trigger
end

function UnitAuraList:GetNativeOptions(trigger)
  local unit, helpful = self:GetTriggerConfig(trigger)
  local filters = {}
  if unit == "target" and not helpful and self:GetTargetDebuffFilterMode(trigger) == "mine_only" then
    filters.isFromPlayerOrPlayerPet = true
  end
  return {
    unit = unit,
    filterString = helpful and "HELPFUL" or "HARMFUL",
    candidateFilters = filters,
  }
end
