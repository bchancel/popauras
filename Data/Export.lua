local _, ns = ...

local Export = {}
ns.Export = Export

local Strings = ns.util.Strings
local Tables = ns.util.Tables

local function AppendAuraTree(auraId, orderedIds, seen)
  if not auraId or seen[auraId] then
    return
  end

  local aura = ns.Registry:GetAura(auraId)
  if not aura then
    return
  end

  seen[auraId] = true
  orderedIds[#orderedIds + 1] = auraId

  for _, childId in ipairs(aura.children or {}) do
    AppendAuraTree(childId, orderedIds, seen)
  end
end

local function IsSecretValue(value)
  return issecretvalue and issecretvalue(value) or false
end

local function IsFiniteNumber(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function SerializeNumber(value)
  if not IsFiniteNumber(value) then
    return "0"
  end

  local serialized = string.format("%.17g", value)
  if serialized:find(",", 1, true) then
    serialized = serialized:gsub(",", ".")
  end
  return serialized
end

local function BuildSortKey(value)
  local valueType = type(value)
  if valueType == "number" then
    return "1:" .. SerializeNumber(value)
  elseif valueType == "string" then
    return "2:" .. value
  elseif valueType == "boolean" then
    return "3:" .. tostring(value)
  end
  return "9:" .. tostring(value)
end

local function SerializeValue(value, seen)
  if IsSecretValue(value) then
    return "nil"
  end

  local valueType = type(value)
  if valueType == "nil" then
    return "nil"
  elseif valueType == "number" then
    return SerializeNumber(value)
  elseif valueType == "boolean" then
    return tostring(value)
  elseif valueType == "string" then
    return string.format("%q", value)
  elseif valueType == "table" then
    seen = seen or {}
    if seen[value] then
      return "{}"
    end
    seen[value] = true

    local fragments = { "{" }
    local entries = {}

    for key, nestedValue in pairs(value) do
      local keyType = type(key)
      if not IsSecretValue(key) and (keyType == "number" or keyType == "string" or keyType == "boolean") then
        entries[#entries + 1] = {
          sortKey = BuildSortKey(key),
          key = key,
          value = nestedValue,
        }
      end
    end

    table.sort(entries, function(left, right)
      return left.sortKey < right.sortKey
    end)

    for _, entry in ipairs(entries) do
      fragments[#fragments + 1] = "[" .. SerializeValue(entry.key, seen) .. "]=" .. SerializeValue(entry.value, seen) .. ","
    end

    fragments[#fragments + 1] = "}"
    seen[value] = nil
    return table.concat(fragments)
  end

  return "nil"
end

local function IsEmptyTable(value)
  return type(value) == "table" and next(value) == nil
end

local function ValuesEqual(left, right)
  if left == right then
    return true
  end

  local leftType = type(left)
  if leftType ~= type(right) then
    return false
  end

  if leftType ~= "table" then
    return false
  end

  for key, value in pairs(left) do
    if not ValuesEqual(value, right[key]) then
      return false
    end
  end
  for key, value in pairs(right) do
    if left[key] == nil and value ~= nil then
      return false
    end
  end
  return true
end

local function PruneAgainstDefaults(value, defaults)
  if IsSecretValue(value) then
    return nil
  end

  local valueType = type(value)
  if valueType ~= "table" then
    if defaults ~= nil and ValuesEqual(value, defaults) then
      return nil
    end
    return value
  end

  local result = {}
  for key, nestedValue in pairs(value) do
    if not IsSecretValue(key) then
      local defaultValue = type(defaults) == "table" and defaults[key] or nil
      local prunedValue = PruneAgainstDefaults(nestedValue, defaultValue)
      if prunedValue ~= nil then
        result[key] = prunedValue
      end
    end
  end

  if IsEmptyTable(result) and type(defaults) == "table" then
    return nil
  end
  return result
end

local function BuildTriggerDefaults(trigger)
  local defaults = Tables.DeepCopy(ns.Defaults.baseTrigger)
  defaults.type = trigger and trigger.type or "simple"
  ns.Defaults:ApplyTriggerDefaults(defaults)
  return defaults
end

local function CompactTrigger(trigger)
  local copy = Tables.DeepCopy(trigger or {})
  local defaults = BuildTriggerDefaults(copy)
  local compact = PruneAgainstDefaults(copy, defaults) or {}
  compact.type = copy.type or defaults.type or "simple"
  return compact
end

local function CompactAura(auraId, aura)
  local primaryTriggerType = aura and aura.triggers and aura.triggers[1] and aura.triggers[1].type or nil
  local defaults = ns.Defaults:NewAura(aura.kind, primaryTriggerType)
  local compact = {
    kind = aura.kind,
    name = aura.name,
  }

  if aura.id and aura.id ~= auraId then
    compact.id = aura.id
  end
  if aura.parentId then
    compact.parentId = aura.parentId
  end
  if aura.enabled == false then
    compact.enabled = false
  end

  local children = PruneAgainstDefaults(aura.children or {}, defaults.children or {})
  if children and not IsEmptyTable(children) then
    compact.children = children
  end

  local load = PruneAgainstDefaults(aura.load or {}, defaults.load or {})
  if load and not IsEmptyTable(load) then
    compact.load = load
  end

  local display = PruneAgainstDefaults(aura.display or {}, defaults.display or {})
  if display and not IsEmptyTable(display) then
    compact.display = display
  end

  local position = PruneAgainstDefaults(aura.position or {}, defaults.position or {})
  if position and not IsEmptyTable(position) then
    compact.position = position
  end

  local text = PruneAgainstDefaults(aura.text or {}, defaults.text or {})
  if text and not IsEmptyTable(text) then
    compact.text = text
  end

  local interrupt = PruneAgainstDefaults(aura.interrupt or {}, defaults.interrupt or {})
  if interrupt and not IsEmptyTable(interrupt) then
    compact.interrupt = interrupt
  end

  local conditions = PruneAgainstDefaults(aura.conditions or {}, defaults.conditions or {})
  if conditions and not IsEmptyTable(conditions) then
    compact.conditions = conditions
  end

  if type(aura.actions) == "table" and #aura.actions > 0 then
    compact.actions = {}
    for index, action in ipairs(aura.actions) do
      local actionDefaults = ns.util.Tables.DeepCopy(ns.Defaults.baseAction)
      actionDefaults.type = action.type or actionDefaults.type
      compact.actions[index] = PruneAgainstDefaults(action, actionDefaults) or {}
      compact.actions[index].type = action.type or "glow_unit_frame"
    end
  end

  if aura.triggerOp and aura.triggerOp ~= (defaults.triggerOp or "AND") then
    compact.triggerOp = aura.triggerOp
  end

  if type(aura.triggers) == "table" and #aura.triggers > 0 then
    compact.triggers = {}
    for index, trigger in ipairs(aura.triggers) do
      compact.triggers[index] = CompactTrigger(trigger)
    end
  end

  return compact
end

function Export:BuildPayload(auraIds)
  local payload = {
    version = ns.Constants.EXPORT_VERSION,
    exportedAt = time(),
    auras = {},
    order = {},
  }

  local ids = auraIds or ns.Registry:GetOrder()
  local orderedIds = {}
  local seen = {}
  for _, auraId in ipairs(ids) do
    AppendAuraTree(auraId, orderedIds, seen)
  end

  for _, auraId in ipairs(orderedIds) do
    local aura = ns.Registry:GetAura(auraId)
    if aura then
      payload.auras[auraId] = CompactAura(auraId, aura)
      payload.order[#payload.order + 1] = auraId
    end
  end

  return payload
end

function Export:Encode(auraIds)
  local payload = self:BuildPayload(auraIds)
  local serialized = "return " .. SerializeValue(payload)
  return ns.Constants.EXPORT_PREFIX .. Strings.Base64Encode(serialized), payload
end
