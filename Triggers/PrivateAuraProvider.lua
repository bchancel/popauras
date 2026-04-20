local _, ns = ...

local PrivateAuras = ns.util.PrivateAuras

local provider = ns.TriggerBase:CreateProvider("private_aura", {
  events = {
    "UNIT_AURA",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_TARGET_CHANGED",
  },
})

local function IteratePrivateAuraTriggers(aura)
  return ns.TriggerBase:IterateTriggers(aura, "private_aura")
end

local function IsGroupUnitToken(unit)
  return type(unit) == "string" and (unit:match("^raid%d+$") ~= nil or unit:match("^party%d+$") ~= nil)
end

local function TriggerMatchesUnit(trigger, unit)
  local mode = PrivateAuras:GetTargetMode(trigger)
  if mode == "cotank" then
    return unit == "player" or IsGroupUnitToken(unit)
  end
  return unit == "player"
end

function provider:GetAffectedAuras(event, ...)
  if event == "UNIT_AURA" then
    local unit = ...
    if unit ~= "player" and not IsGroupUnitToken(unit) then
      return {}
    end
    return ns.Registry:CollectAuraIds(function(aura)
      for _, trigger in IteratePrivateAuraTriggers(aura) do
        if TriggerMatchesUnit(trigger, unit) then
          return true
        end
      end
      return false
    end)
  end

  if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_TARGET_CHANGED" then
    return ns.Registry:CollectAuraIds(function(aura)
      local matches = ns.TriggerBase:AnyTriggerMatches(aura, "private_aura")
      return matches == true
    end)
  end

  return {}
end

function provider:Evaluate(trigger, auraConfig)
  local unit = PrivateAuras and PrivateAuras.ResolveUnit and PrivateAuras:ResolveUnit(trigger) or "player"
  local resolved = unit and UnitExists and UnitExists(unit)
  local name = auraConfig and auraConfig.name or "Private Auras"
  local targetMode = PrivateAuras and PrivateAuras.GetTargetMode and PrivateAuras:GetTargetMode(trigger) or "player"

  return ns.Schema.NormalizeRuntimeState({
    show = resolved == true,
    matched = resolved == true,
    active = resolved == true,
    unit = unit,
    matchedUnits = resolved and { unit } or nil,
    name = name,
    icon = 134400,
    source = "private_aura",
    statusText = targetMode == "cotank" and "Co-Tank Private Auras" or "Private Auras",
  })
end
