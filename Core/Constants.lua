local _, ns = ...

ns.Features = {
  -- Native nameplate auras remain reversible while they are exercised on PTR.
  feature_nameplate_buffs = true,
}

function ns.Features:IsEnabled(featureName)
  return self[featureName] == true
end

ns.Constants = {
  DB_VERSION = 6,
  EXPORT_VERSION = 1,
  EXPORT_PREFIX = "POPAURAS:1:",
  AURA_KINDS = {
    group = true,
    dynamic_group = true,
    icon = true,
    bar = true,
    text = true,
    interrupt_tracker = true,
    aura_bar_list = true,
  },
  TRIGGER_OPS = {
    AND = true,
    OR = true,
  },
  TAB_KEYS = {
    "display",
    "trigger",
    "actions",
    "load",
    "group",
    "import_export",
  },
}
