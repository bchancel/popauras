local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("simple", {
  events = {
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTERING_WORLD",
  },
})

function provider:GetAffectedAuras(event)
  if event == "PLAYER_ENTERING_WORLD" then
    return true
  end

  local mode = event == "PLAYER_TARGET_CHANGED" and "target_exists"
    or (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED") and "in_combat"
    or nil
  if not mode then return {} end

  return ns.Registry:CollectAuraIds(function(aura)
    return ns.TriggerBase:AnyTriggerMatches(aura, "simple", function(trigger)
      return (trigger.mode or "always") == mode
    end)
  end)
end

function provider:Evaluate(trigger)
  local mode = trigger.mode or "always"
  local active = false
  local name = trigger.label or "Basic State"
  local status = mode

  if mode == "always" then
    active = true
  elseif mode == "never" then
    active = false
    status = "Disabled"
  elseif mode == "in_combat" then
    active = InCombatLockdown()
    status = active and "In Combat" or "Out of Combat"
  elseif mode == "target_exists" then
    active = UnitExists("target")
    status = active and "Target Exists" or "No Target"
  end

  return ns.Schema.NormalizeRuntimeState({
    show = active,
    active = active,
    name = name,
    progressType = "static",
    source = "simple",
    statusText = status,
  })
end
