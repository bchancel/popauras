local _, ns = ...

local Import = {}
ns.Import = Import

local Strings = ns.util.Strings
local Tables = ns.util.Tables

local function DebugLog(message)
  if ns.Debug and ns.Debug.Log then
    ns.Debug:Log("Import", message)
  end
end

local function ComputeChecksum(text)
  local hash = 5381
  for index = 1, #(text or "") do
    hash = ((hash * 33) + string.byte(text, index)) % 4294967291
  end
  return string.format("%08x", hash)
end

local function CompactPreview(text, maxLength)
  if type(text) ~= "string" then
    return ""
  end
  maxLength = math.max(8, tonumber(maxLength or 80) or 80)
  text = text:gsub("[%c]", " ")
  if #text <= maxLength then
    return text
  end
  local headLength = math.floor((maxLength - 5) / 2)
  local tailLength = math.max(1, maxLength - headLength - 5)
  return text:sub(1, headLength) .. " ... " .. text:sub(-tailLength)
end

local function CountEntries(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

function Import:Decode(text)
  local originalText = text
  text = Strings.Trim(text or "")
  local wasQuoted = false
  if type(text) == "string" and text:sub(1, 1) == "\"" and text:sub(-1) == "\"" then
    text = text:sub(2, -2)
    wasQuoted = true
  end
  DebugLog(string.format("Decode start rawLen=%d trimmedLen=%d quoted=%s preview=%s",
    #(tostring(originalText or "")),
    #(tostring(text or "")),
    tostring(wasQuoted),
    CompactPreview(text, 90)))
  if not Strings.StartsWith(text, ns.Constants.EXPORT_PREFIX) then
    DebugLog(string.format("Decode failed invalid-prefix preview=%s", CompactPreview(text, 90)))
    return nil, "Invalid PopAuras import prefix."
  end

  local encoded = text:sub(#ns.Constants.EXPORT_PREFIX + 1)
  local decoded = Strings.Base64Decode(encoded)
  DebugLog(string.format("Decode base64 encodedLen=%d decodedLen=%d decodedChecksum=%s decodedTail=%s",
    #encoded,
    #decoded,
    ComputeChecksum(decoded),
    CompactPreview(decoded:sub(math.max(1, #decoded - 140)), 120)))
  if decoded == "" then
    DebugLog("Decode failed empty-decoded-payload")
    return nil, "Failed to decode import string."
  end

  local loaderFunc = loadstring or load
  local loader, err = loaderFunc(decoded)
  if not loader then
    DebugLog(string.format("Decode parse-failed err=%s decodedLen=%d checksum=%s head=%s tail=%s",
      tostring(err or "unknown"),
      #decoded,
      ComputeChecksum(decoded),
      CompactPreview(decoded:sub(1, 160), 120),
      CompactPreview(decoded:sub(math.max(1, #decoded - 160)), 120)))
    return nil, err or "Invalid import payload."
  end

  local ok, payload = pcall(loader)
  if not ok or type(payload) ~= "table" then
    DebugLog(string.format("Decode eval-failed ok=%s payloadType=%s err=%s",
      tostring(ok),
      type(payload),
      ok and "Import payload did not evaluate to a table." or tostring(payload)))
    return nil, "Import payload did not evaluate to a table."
  end

  DebugLog(string.format("Decode ok auras=%d order=%d version=%s",
    CountEntries(payload.auras),
    #(payload.order or {}),
    tostring(payload.version or "")))

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
    DebugLog(string.format("Apply aborted replace=%s err=%s", tostring(replace == true), tostring(err)))
    return false, err
  end

  if replace then
    DebugLog("Apply clearing existing auras before import")
    ns.Registry:ClearAll()
  end

  local importedOrder = {}
  local idMap = {}

  for _, originalId in ipairs(payload.order or {}) do
    local aura = payload.auras and payload.auras[originalId]
    if aura then
      aura = Tables.DeepCopy(aura)
      local newId = aura.id or originalId
      if ns.Registry:GetAura(newId) then
        newId = string.format("%s_copy_%d", newId, math.random(1000, 9999))
      end
      idMap[originalId] = newId
      aura.id = newId
      importedOrder[#importedOrder + 1] = aura
    end
  end
  DebugLog(string.format("Apply prepared importedOrder=%d replace=%s", #importedOrder, tostring(replace == true)))

  for _, aura in ipairs(importedOrder) do
    if aura.parentId and idMap[aura.parentId] then
      aura.parentId = idMap[aura.parentId]
    end
    for index, childId in ipairs(aura.children or {}) do
      if idMap[childId] then
        aura.children[index] = idMap[childId]
      end
    end
    ns.Defaults:ApplyAuraDefaults(aura)
    ns.Registry:AddAura(aura)
  end
  DebugLog(string.format("Apply complete imported=%d dbAuras=%d", #importedOrder, CountEntries(ns.db and ns.db.auras)))

  ns.runtime:RefreshAll()
  if ns.ui.MainWindow and ns.ui.MainWindow.Refresh then
    ns.ui.MainWindow:Refresh()
  end

  return true, payload
end
