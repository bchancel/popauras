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

local function SerializeValue(value)
  local valueType = type(value)
  if valueType == "nil" then
    return "nil"
  elseif valueType == "number" or valueType == "boolean" then
    return tostring(value)
  elseif valueType == "string" then
    return string.format("%q", value)
  elseif valueType == "table" then
    local fragments = { "{" }
    local numericKeys = {}
    local keyed = {}

    for key in pairs(value) do
      if type(key) == "number" then
        numericKeys[#numericKeys + 1] = key
      else
        keyed[#keyed + 1] = key
      end
    end

    table.sort(numericKeys)
    table.sort(keyed, function(a, b) return tostring(a) < tostring(b) end)

    for _, key in ipairs(numericKeys) do
      fragments[#fragments + 1] = SerializeValue(value[key]) .. ","
    end
    for _, key in ipairs(keyed) do
      fragments[#fragments + 1] = "[" .. SerializeValue(key) .. "]=" .. SerializeValue(value[key]) .. ","
    end

    fragments[#fragments + 1] = "}"
    return table.concat(fragments)
  end

  return "nil"
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
      payload.auras[auraId] = Tables.DeepCopy(aura)
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
