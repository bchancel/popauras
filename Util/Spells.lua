local _, ns = ...

local Spells = {}
ns.util.Spells = Spells

local function Trim(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local textureCache = {}

local function CacheGet(key)
  local cached = textureCache[key]
  if cached == false then
    return nil
  end
  return cached
end

local function CachePut(key, value)
  textureCache[key] = value or false
  return value
end

function Spells:GetSpellTextureByOverride(iconOverrideId, iconOverrideName)
  local numericId = tonumber(iconOverrideId or 0) or 0
  if numericId > 0 then
    local cacheKey = "id:" .. tostring(numericId)
    local cached = CacheGet(cacheKey)
    if cached ~= nil then
      return cached
    end

    local texture = nil
    if C_Spell and C_Spell.GetSpellTexture then
      texture = C_Spell.GetSpellTexture(numericId)
    end
    if not texture and GetSpellTexture then
      texture = GetSpellTexture(numericId)
    end
    if not texture then
      texture = numericId
    end
    return CachePut(cacheKey, texture)
  end

  local spellName = Trim(iconOverrideName)
  if spellName == "" then
    return nil
  end

  local cacheKey = "name:" .. string.lower(spellName)
  local cached = CacheGet(cacheKey)
  if cached ~= nil then
    return cached
  end

  local texture = nil
  if C_Spell and C_Spell.GetSpellTexture then
    texture = C_Spell.GetSpellTexture(spellName)
  end
  if not texture and GetSpellTexture then
    texture = GetSpellTexture(spellName)
  end

  return CachePut(cacheKey, texture)
end

function Spells:ResolveDisplayIcon(aura, state)
  local display = aura and aura.display or nil
  local texture = display and self:GetSpellTextureByOverride(display.iconOverrideId, display.iconOverrideName) or nil
  return texture or (state and state.icon) or 134400
end
