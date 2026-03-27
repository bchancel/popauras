local _, ns = ...

local Import = {}
ns.Import = Import

local Strings = ns.util.Strings
local Tables = ns.util.Tables

function Import:Decode(text)
  text = Strings.Trim(text or "")
  if not Strings.StartsWith(text, ns.Constants.EXPORT_PREFIX) then
    return nil, "Invalid PopAuras import prefix."
  end

  local encoded = text:sub(#ns.Constants.EXPORT_PREFIX + 1)
  local decoded = Strings.Base64Decode(encoded)
  if decoded == "" then
    return nil, "Failed to decode import string."
  end

  local loaderFunc = loadstring or load
  local loader, err = loaderFunc(decoded)
  if not loader then
    return nil, err or "Invalid import payload."
  end

  local ok, payload = pcall(loader)
  if not ok or type(payload) ~= "table" then
    return nil, "Import payload did not evaluate to a table."
  end

  return payload
end

function Import:Preview(text)
  local payload, err = self:Decode(text)
  if not payload then
    return nil, err
  end

  local count = 0
  for _ in pairs(payload.auras or {}) do
    count = count + 1
  end

  return {
    count = count,
    version = payload.version or 0,
    exportedAt = payload.exportedAt or 0,
    order = payload.order or {},
  }
end

function Import:Apply(text, replace)
  local payload, err = self:Decode(text)
  if not payload then
    return false, err
  end

  if replace then
    ns.Registry:ClearAll()
  end

  local importedOrder = {}
  local idMap = {}

  for _, originalId in ipairs(payload.order or {}) do
    local aura = payload.auras and payload.auras[originalId]
    if aura then
      aura = Tables.DeepCopy(aura)
      local newId = aura.id
      if ns.Registry:GetAura(newId) then
        newId = string.format("%s_copy_%d", newId, math.random(1000, 9999))
      end
      idMap[originalId] = newId
      aura.id = newId
      importedOrder[#importedOrder + 1] = aura
    end
  end

  for _, aura in ipairs(importedOrder) do
    if aura.parentId and idMap[aura.parentId] then
      aura.parentId = idMap[aura.parentId]
    end
    for index, childId in ipairs(aura.children or {}) do
      if idMap[childId] then
        aura.children[index] = idMap[childId]
      end
    end
    ns.Registry:AddAura(aura)
  end

  ns.runtime:RefreshAll()
  if ns.ui.MainWindow and ns.ui.MainWindow.Refresh then
    ns.ui.MainWindow:Refresh()
  end

  return true, payload
end
