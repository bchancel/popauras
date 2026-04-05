local _, ns = ...

local Strings = {}
ns.util.Strings = Strings

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

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

  return ((data:gsub(".", function(char)
    local byte = char:byte()
    local bits = ""
    for i = 8, 1, -1 do
      bits = bits .. ((byte % 2 ^ i - byte % 2 ^ (i - 1) > 0) and "1" or "0")
    end
    return bits
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
    if #bits < 6 then
      return ""
    end
    local value = 0
    for i = 1, 6 do
      if bits:sub(i, i) == "1" then
        value = value + 2 ^ (6 - i)
      end
    end
    return b64chars:sub(value + 1, value + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

function Strings.Base64Decode(data)
  if type(data) ~= "string" or data == "" then
    return ""
  end

  data = data:gsub("[^" .. b64chars .. "=]", "")
  return (data:gsub(".", function(char)
    if char == "=" then
      return ""
    end
    local index = b64chars:find(char, 1, true)
    local value = (index or 1) - 1
    local bits = ""
    for i = 6, 1, -1 do
      bits = bits .. ((value % 2 ^ i - value % 2 ^ (i - 1) > 0) and "1" or "0")
    end
    return bits
  end):gsub("%d%d%d%d%d%d%d%d", function(bits)
    local value = 0
    for i = 1, 8 do
      if bits:sub(i, i) == "1" then
        value = value + 2 ^ (8 - i)
      end
    end
    return string.char(value)
  end))
end
