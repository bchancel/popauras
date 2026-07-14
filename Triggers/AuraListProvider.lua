local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("aura_list", { events = {} })

function provider:Evaluate(trigger, auraConfig)
  local available = ns.NativeAuras and ns.NativeAuras:IsAvailable()
  return ns.Schema.NormalizeRuntimeState({
    show = available,
    matched = available,
    active = available,
    availability = available and "available" or "unavailable",
    unit = trigger and trigger.unit or "player",
    name = auraConfig and auraConfig.name or "Buffs and Debuffs",
    source = "aura_list_native",
    statusText = available and "Native aura list" or "AuraContainer unavailable",
  })
end
