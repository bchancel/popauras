-- Standalone regression: lua tests/LoadEvaluator.lua from the repository root.
local ns = { util = {}, db = { auras = {}, ui = {} } }
local playerClass = "MONK"
function UnitClass() return playerClass, playerClass end
function GetSpecialization() return 1 end
function GetTime() return 0 end
local function Load(path)
  assert(loadfile((repository or ".") .. "/" .. path))("PopAuras", ns)
end
ns.Registry = { GetAura = function(_, id) return ns.db.auras[id] end }
local function Aura(id, kind, parent, class)
  local aura = { id = id, kind = kind, name = id, parentId = parent and parent.id,
    children = {}, load = class and { classes = { [class] = true } } or {} }
  ns.db.auras[id] = aura
  if parent then parent.children[#parent.children + 1] = id end
  return aura
end
Load("Engine/LoadEvaluator.lua")
local evaluator = ns.LoadEvaluator
local function Loaded(aura) return evaluator:MatchesWithAncestors(aura) end

-- Reproduce DruidBars on a monk without requiring group-level class rules.
local druidBars = Aura("DruidBars", "dynamic_group")
local druidOne = Aura("DruidOne", "bar", druidBars, "DRUID")
local druidTwo = Aura("DruidTwo", "bar", druidBars, "DRUID")
assert(evaluator:Matches(druidBars)) -- Its own rules pass, but its children do not.
assert(not Loaded(druidBars) and not Loaded(druidOne) and not Loaded(druidTwo))
playerClass = "DRUID"
assert(Loaded(druidBars) and Loaded(druidOne) and Loaded(druidTwo))
druidOne.enabled = false
druidTwo.triggerActive = false
assert(Loaded(druidBars), "one loaded, inactive child must suffice")
druidTwo.enabled = false
assert(not Loaded(druidBars), "all disabled children must unload the group")

-- Mixed classes never require every child to load; this also covers static groups.
local mixed = Aura("Mixed", "group")
local monk = Aura("Monk", "icon", mixed, "MONK")
local druid = Aura("Druid", "icon", mixed, "DRUID")
for _, class in ipairs({ "MONK", "DRUID" }) do
  playerClass = class
  assert(Loaded(mixed))
  assert(Loaded(monk) ~= Loaded(druid))
end
playerClass = "MAGE"
assert(not Loaded(mixed))

-- Nested groups need a leaf that passes each group's rules along its path.
local root = Aura("Root", "group")
local nested = Aura("Nested", "dynamic_group", root)
local leaf = Aura("Leaf", "bar", nested, "MONK")
playerClass = "MONK"
assert(Loaded(root) and Loaded(nested) and Loaded(leaf))
nested.load.classes = { DRUID = true }
assert(not Loaded(root) and not Loaded(nested) and not Loaded(leaf))
local sibling = Aura("Sibling", "icon", root, "MONK")
assert(Loaded(root) and not Loaded(nested), "a loaded sibling must keep the parent loaded")
sibling.enabled = false
nested.load.classes = nil
root.enabled = false
assert(not Loaded(root) and not Loaded(nested) and not Loaded(leaf))
root.enabled = true
playerClass = "DRUID"
assert(not Loaded(root) and not Loaded(nested))

-- Empty, missing, and cyclic group branches never masquerade as loaded auras.
local empty = Aura("Empty", "group")
root.children[#root.children + 1] = empty.id
root.children[#root.children + 1] = "Missing"
assert(not Loaded(empty) and not Loaded(root))
local cycle = Aura("Cycle", "group", empty)
cycle.children[1] = empty.id
assert(not Loaded(empty) and not Loaded(cycle))
local standalone = Aura("Standalone", "icon", nil, "DRUID")
assert(Loaded(standalone))

-- The actual runtime receives the same effective group load state as the UI.
ns.Schema = { NormalizeRuntimeState = function(state) return state end }
ns.TriggerEngine = { EvaluateAura = function(_, aura)
  return { show = aura.kind == "group" or aura.kind == "dynamic_group", active = false }
end }
ns.ConditionEngine = { Apply = function(_, _, state) return state end }
ns.Render = { RenderAura = function() end }
Load("Engine/RuntimeStore.lua")
playerClass = "MONK"
ns.runtime:RefreshAura(druidBars.id)
assert(ns.runtime:GetState(druidBars.id).loadMatched == false)
assert(ns.runtime:GetPresentation(druidBars.id).show == false)
druidTwo.enabled = true
playerClass = "DRUID"
ns.runtime:RefreshAura(druidTwo.id)
ns.runtime:RefreshAura(druidBars.id)
assert(ns.runtime:GetState(druidTwo.id).loadMatched == true)
assert(ns.runtime:GetState(druidTwo.id).show == false)
assert(ns.runtime:GetState(druidBars.id).loadMatched == true)
assert(ns.runtime:GetState(druidBars.id).show == true)
print("Group load checks passed for mixed children, nested groups, class changes, and runtime state.")
