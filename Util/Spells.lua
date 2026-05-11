local _, ns = ...

local Spells = {}
ns.util.Spells = Spells

Spells.learnedNameToId = Spells.learnedNameToId or {}

local function Trim(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function SafeNumericValue(value)
  if value == nil then
    return 0
  end
  if issecretvalue and issecretvalue(value) then
    return 0
  end
  if type(value) == "number" then
    return value
  end
  return tonumber(value or 0) or 0
end

local function SafeStringValue(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "string" then
    return value
  end
  return nil
end

function Spells:NormalizeText(value)
  return Trim(value)
end

function Spells:RememberResolvedSpell(spellID, spellName)
  spellID = tonumber(spellID or 0) or 0
  spellName = Trim(spellName)
  if spellID <= 0 or spellName == "" then
    return
  end

  self.learnedNameToId[string.lower(spellName)] = spellID
end

function Spells:GetRememberedSpellID(spellName)
  spellName = Trim(spellName)
  if spellName == "" then
    return 0
  end
  return tonumber(self.learnedNameToId[string.lower(spellName)] or 0) or 0
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

function Spells:ResolveSpellReference(input)
  input = Trim(input)
  if input == "" then
    return 0, "", "Enter a spell name or spell ID."
  end

  local numericId = tonumber(input)
  if numericId then
    numericId = math.floor(numericId + 0.5)
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(numericId) or nil
    self:RememberResolvedSpell(numericId, spellName)
    return numericId, spellName or ("Spell " .. tostring(numericId)), nil
  end

  if C_Spell and C_Spell.GetSpellInfo then
    local spellInfo = C_Spell.GetSpellInfo(input)
    local resolvedId = spellInfo and tonumber(spellInfo.spellID or 0) or 0
    local resolvedName = spellInfo and spellInfo.name or nil
    if resolvedId > 0 and resolvedName and resolvedName ~= "" then
      self:RememberResolvedSpell(resolvedId, resolvedName)
      return resolvedId, resolvedName, nil
    end
  end

  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local auraData = C_UnitAuras.GetAuraDataBySpellName("player", input, "HELPFUL")
    local auraSpellID = auraData and SafeNumericValue(auraData.spellId) or 0
    local auraSpellName = auraData and SafeStringValue(auraData.name) or nil
    if auraSpellID > 0 and type(auraSpellName) == "string" and auraSpellName ~= "" then
      self:RememberResolvedSpell(auraSpellID, auraSpellName)
      return auraSpellID, auraSpellName, nil
    end

    auraData = C_UnitAuras.GetAuraDataBySpellName("player", input, "HARMFUL")
    auraSpellID = auraData and SafeNumericValue(auraData.spellId) or 0
    auraSpellName = auraData and SafeStringValue(auraData.name) or nil
    if auraSpellID > 0 and type(auraSpellName) == "string" and auraSpellName ~= "" then
      self:RememberResolvedSpell(auraSpellID, auraSpellName)
      return auraSpellID, auraSpellName, nil
    end
  end

  local rememberedID = self:GetRememberedSpellID(input)
  if rememberedID > 0 then
    local rememberedName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(rememberedID) or input
    self:RememberResolvedSpell(rememberedID, rememberedName)
    return rememberedID, rememberedName or input, nil
  end

  local needle = string.lower(input)
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
      and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo
      and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
    local lineCount = C_SpellBook.GetNumSpellBookSkillLines() or 0
    for lineIndex = 1, lineCount do
      local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
      local startIndex = lineInfo and lineInfo.itemIndexOffset and (lineInfo.itemIndexOffset + 1)
      local endIndex = lineInfo and lineInfo.numSpellBookItems and (lineInfo.itemIndexOffset + lineInfo.numSpellBookItems)
      if startIndex and endIndex then
        for slotIndex = startIndex, endIndex do
          local itemInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, Enum.SpellBookSpellBank.Player)
          local spellID = itemInfo and itemInfo.spellID
          if spellID and C_Spell and C_Spell.GetSpellName then
            local spellName = C_Spell.GetSpellName(spellID)
            if spellName and string.lower(spellName) == needle then
              self:RememberResolvedSpell(spellID, spellName)
              return spellID, spellName, nil
            end
          end
        end
      end
    end
  end

  return 0, input, "Spell name not found in your spellbook or current player auras."
end

function Spells:ResolveDisplayIcon(aura, state)
  local display = aura and aura.display or nil
  local texture = display and self:GetSpellTextureByOverride(display.iconOverrideId, display.iconOverrideName) or nil
  return texture or (state and state.icon) or 134400
end
