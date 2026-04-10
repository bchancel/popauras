local _, ns = ...

local Strings = {}
ns.util.Strings = Strings

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64lookup = {}
for index = 1, #b64chars do
  b64lookup[b64chars:sub(index, index)] = index - 1
end

local function IsSafeStringValue(value)
  return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

function Strings.StartsWith(text, prefix)
  return type(text) == "string" and type(prefix) == "string" and text:sub(1, #prefix) == prefix
end

function Strings.Trim(text)
  if type(text) ~= "string" then
    return text
  end
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Strings.IsSafeString(value)
  return IsSafeStringValue(value)
end

function Strings.SafeName(text, fallback)
  if not IsSafeStringValue(text) then
    return fallback or "Aura"
  end
  text = Strings.Trim(text or "")
  if text == "" then
    return fallback or "Aura"
  end
  return text
end

function Strings.GetSafeShortPlayerName(name)
  if not IsSafeStringValue(name) then
    return nil
  end
  local shortName = name
  if Ambiguate then
    shortName = Ambiguate(name, "short")
  end
  if not IsSafeStringValue(shortName) or shortName == "" then
    return nil
  end
  return shortName
end

function Strings.GetSafeUnitNameParts(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil, nil
  end

  if UnitFullName then
    local fullName, fullRealm = UnitFullName(unit)
    if IsSafeStringValue(fullName) and fullName ~= "" then
      if IsSafeStringValue(fullRealm) and fullRealm ~= "" then
        return fullName, fullRealm
      end
      return fullName, nil
    end
  end

  if UnitName then
    local unitName, unitRealm = UnitName(unit)
    if IsSafeStringValue(unitName) and unitName ~= "" then
      if IsSafeStringValue(unitRealm) and unitRealm ~= "" then
        return unitName, unitRealm
      end
      return unitName, nil
    end
  end

  return nil, nil
end

function Strings.GetSafeUnitDisplayName(unit, includeRealm)
  local name, realm = Strings.GetSafeUnitNameParts(unit)
  if not name then
    return nil
  end
  if includeRealm and realm then
    return string.format("%s-%s", name, realm)
  end
  return name
end

function Strings.Base64Encode(data)
  if type(data) ~= "string" or data == "" then
    return ""
  end

  local result = {}
  for index = 1, #data, 3 do
    local byte1 = data:byte(index) or 0
    local byte2 = data:byte(index + 1)
    local byte3 = data:byte(index + 2)
    local hasByte2 = byte2 ~= nil
    local hasByte3 = byte3 ~= nil
    byte2 = byte2 or 0
    byte3 = byte3 or 0

    local packed = (byte1 * 65536) + (byte2 * 256) + byte3
    local char1 = math.floor(packed / 262144) % 64
    local char2 = math.floor(packed / 4096) % 64
    local char3 = math.floor(packed / 64) % 64
    local char4 = packed % 64

    result[#result + 1] = b64chars:sub(char1 + 1, char1 + 1)
    result[#result + 1] = b64chars:sub(char2 + 1, char2 + 1)
    result[#result + 1] = hasByte2 and b64chars:sub(char3 + 1, char3 + 1) or "="
    result[#result + 1] = hasByte3 and b64chars:sub(char4 + 1, char4 + 1) or "="
  end

  return table.concat(result)
end

function Strings.Base64Decode(data)
  if type(data) ~= "string" or data == "" then
    return ""
  end

  data = data:gsub("[^" .. b64chars .. "=]", "")
  local result = {}
  for index = 1, #data, 4 do
    local char1 = data:sub(index, index)
    local char2 = data:sub(index + 1, index + 1)
    local char3 = data:sub(index + 2, index + 2)
    local char4 = data:sub(index + 3, index + 3)
    if char1 == "" or char2 == "" then
      break
    end

    local value1 = b64lookup[char1]
    local value2 = b64lookup[char2]
    local value3 = char3 ~= "=" and b64lookup[char3] or nil
    local value4 = char4 ~= "=" and b64lookup[char4] or nil

    if value1 == nil or value2 == nil or (char3 ~= "" and char3 ~= "=" and value3 == nil) or (char4 ~= "" and char4 ~= "=" and value4 == nil) then
      return ""
    end

    local packed = (value1 * 262144) + (value2 * 4096) + ((value3 or 0) * 64) + (value4 or 0)
    local byte1 = math.floor(packed / 65536) % 256
    local byte2 = math.floor(packed / 256) % 256
    local byte3 = packed % 256

    result[#result + 1] = string.char(byte1)
    if char3 ~= "=" and char3 ~= "" then
      result[#result + 1] = string.char(byte2)
    end
    if char4 ~= "=" and char4 ~= "" then
      result[#result + 1] = string.char(byte3)
    end
  end

  return table.concat(result)
end
