local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("cast", {
  events = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "PLAYER_TARGET_CHANGED",
  },
})

function provider:GetAffectedAuras(event, ...)
  local unit = ...
  if event == "PLAYER_TARGET_CHANGED" then
    unit = "target"
  end

  if unit ~= "player" and unit ~= "target" then
    return {}
  end

  return ns.Registry:CollectAuraIds(function(aura)
    return ns.TriggerBase:AnyTriggerMatches(aura, "cast", function(trigger)
      return (trigger.unit or "player") == unit
    end)
  end)
end

function provider:ShouldEvaluate(event, ...)
  local unit = ...
  return unit == nil or unit == "player" or unit == "target"
end

function provider:Evaluate(trigger)
  local unit = trigger.unit or "player"
  local name, _, icon, startMS, endMS = UnitCastingInfo(unit)
  local status = "Casting"
  if not name then
    name, _, _, icon, startMS, endMS = UnitChannelInfo(unit)
    status = "Channeling"
  end

  if not name then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "cast", unit = unit })
  end

  local startTime = (startMS or 0) / 1000
  local endTime = (endMS or 0) / 1000
  local duration = math.max(0, endTime - startTime)

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    active = true,
    icon = icon,
    name = name,
    duration = duration,
    expirationTime = endTime,
    progressType = "timed",
    value = duration,
    total = duration,
    unit = unit,
    source = "cast",
    statusText = status,
  })
end
