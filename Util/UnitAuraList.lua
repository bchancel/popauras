local _, ns = ...

-- PopAuras intentionally contains no aura enumeration helpers. This module
-- only translates the existing UI configuration into AuraContainer options.
local UnitAuraList = {}
ns.util.UnitAuraList = UnitAuraList

local SORT_MODES = {
  shortest_first = true,
  longest_first = true,
}
local DEFAULT_MAX_ROWS = 0
local MAX_MAX_ROWS = 100

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

function UnitAuraList:GetDefaultSortModeForSourceValue(sourceValue)
  return sourceValue == "player_buff" and "longest_first" or "shortest_first"
end

function UnitAuraList:GetSortMode(trigger)
  local mode = tostring(trigger and trigger.auraListSortMode or "")
  if SORT_MODES[mode] then
    return mode
  end
  return self:GetDefaultSortModeForSourceValue(self:GetSourceValue(trigger))
end

function UnitAuraList:ApplySortMode(trigger, value)
  trigger = trigger or {}
  local mode = tostring(value or "")
  if not SORT_MODES[mode] then
    mode = self:GetDefaultSortModeForSourceValue(self:GetSourceValue(trigger))
  end
  trigger.auraListSortMode = mode
  return trigger
end

function UnitAuraList:RetireCasterFilter(trigger)
  trigger = trigger or {}
  trigger.auraListFilterMode = nil
  trigger.targetDebuffFilterMode = nil
  trigger.targetMineOrUnownedOnly = nil
  return trigger
end

function UnitAuraList:GetMaxDuration(trigger)
  local value = tonumber(trigger and trigger.auraListMaxDuration or 0)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return 0
  end
  return math.max(0, value)
end

function UnitAuraList:ApplyMaxDuration(trigger, value)
  trigger = trigger or {}
  trigger.auraListMaxDuration = self:GetMaxDuration({
    auraListMaxDuration = value,
  })
  return trigger
end

function UnitAuraList:GetMaxRows(trigger)
  local value = math.floor(tonumber(trigger and trigger.auraListMaxRows or DEFAULT_MAX_ROWS)
    or DEFAULT_MAX_ROWS)
  return math.max(0, math.min(value, MAX_MAX_ROWS))
end

function UnitAuraList:ApplyMaxRows(trigger, value)
  trigger = trigger or {}
  trigger.auraListMaxRows = self:GetMaxRows({
    auraListMaxRows = value,
  })
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
  return trigger
end

function UnitAuraList:GetNativeOptions(trigger)
  local unit, helpful = self:GetTriggerConfig(trigger)
  local filters = {}
  local maxDuration = self:GetMaxDuration(trigger)
  if maxDuration > 0 then
    filters.maxDuration = maxDuration
  end
  local maxRows = self:GetMaxRows(trigger)
  return {
    unit = unit,
    filterString = helpful and "HELPFUL" or "HARMFUL",
    candidateFilters = filters,
    -- Blizzard represents an unlimited native group with infinity while the
    -- saved and user-facing value remains a convenient zero.
    maxFrameCount = maxRows > 0 and maxRows or math.huge,
  }
end
