local _, ns = ...

local UnitAuraList = ns.util.UnitAuraList

local provider = ns.TriggerBase:CreateProvider("aura_list", {
  events = {
    "UNIT_AURA",
    "PLAYER_TARGET_CHANGED",
  },
})

local function IterateAuraListTriggers(aura)
  return ns.TriggerBase:IterateTriggers(aura, "aura_list")
end

local function TriggerUsesUnit(trigger, unit)
  local triggerUnit = trigger and trigger.unit or "player"
  return triggerUnit == unit
end

function provider:GetAffectedAuras(event, ...)
  if event == "PLAYER_TARGET_CHANGED" then
    return ns.Registry:CollectAuraIds(function(aura)
      for _, trigger in IterateAuraListTriggers(aura) do
        if TriggerUsesUnit(trigger, "target") then
          return true
        end
      end
      return false
    end)
  end

  if event == "UNIT_AURA" then
    local unit = ...
    if unit ~= "player" and unit ~= "target" then
      return {}
    end
    return ns.Registry:CollectAuraIds(function(aura)
      for _, trigger in IterateAuraListTriggers(aura) do
        if TriggerUsesUnit(trigger, unit) then
          return true
        end
      end
      return false
    end)
  end

  return {}
end

function provider:Evaluate(trigger, auraConfig)
  local entries, debugExtra
  if UnitAuraList and UnitAuraList.CollectWithDebug and trigger and trigger.debug == true then
    entries, debugExtra = UnitAuraList:CollectWithDebug(trigger, 1)
  else
    entries = UnitAuraList and UnitAuraList.Collect and UnitAuraList:Collect(trigger, 1) or {}
  end
  local first = entries[1]
  local helpful = (trigger and trigger.auraType or "buff") ~= "debuff"

  if first then
    return ns.Schema.NormalizeRuntimeState({
      show = true,
      matched = true,
      active = true,
      unit = first.unit,
      matchedUnits = { first.unit },
      name = auraConfig and auraConfig.name or first.name or "Buffs and Debuffs",
      icon = first.icon,
      stacks = first.stacks or 0,
      stackText = first.stackText,
      stackDisplayValue = first.stackDisplayValue,
      hasStackDisplayValue = first.hasStackDisplayValue == true,
      duration = first.duration or 0,
      expirationTime = first.expirationTime or 0,
      durationObject = first.durationObject,
      hasExpiration = first.hasExpiration,
      isPermanent = first.isPermanent == true,
      progressType = first.progressType or "static",
      value = first.value or 0,
      total = first.total or 0,
      spellId = first.spellId,
      auraInstanceID = first.auraInstanceID,
      source = "aura_list",
      statusText = helpful and "Buffs" or "Debuffs",
      debugExtra = debugExtra,
    })
  end

  return ns.Schema.NormalizeRuntimeState({
    show = false,
    matched = false,
    active = false,
    unit = trigger and trigger.unit or "player",
    name = auraConfig and auraConfig.name or "Buffs and Debuffs",
    source = "aura_list",
    statusText = helpful and "No Buffs" or "No Debuffs",
    debugExtra = debugExtra,
  })
end
