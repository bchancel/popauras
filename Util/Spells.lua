local _, ns = ...

local Spells = {}
ns.util.Spells = Spells

Spells.learnedNameToId = Spells.learnedNameToId or {}

-- Some spellbook abilities apply an aura under a different spell ID. Midnight
-- only provides exact spell-ID filters for secret-safe native aura containers,
-- so these relationships must be explicit rather than learned by scanning all
-- unit auras. These are canonical applied-aura IDs: presentation continues to
-- use the configured spell ID, while matching uses only the actual aura IDs.
local AURA_SPELL_ID_ALIASES = {
  [8921] = { 164812 },   -- Moonfire (cast -> periodic debuff)
  [155625] = { 164812 }, -- Moonfire (Cat Form cast -> periodic debuff)
  [1252871] = { 164812 }, -- Red Moon (ability -> Moonfire periodic debuff)
  [93402] = { 164815 },  -- Sunfire (cast -> periodic debuff)
  [1822] = { 155722 },   -- Rake (cast -> periodic debuff)
  [77758] = { 192090 },  -- Thrash (cast -> stacking periodic debuff)
  [202345] = { 279709 }, -- Starlord (talent -> stacking buff)
  [203720] = { 203819 }, -- Demon Spikes (ability -> active buff)
}

local AURA_ALIAS_RELATED_IDS = {}
for abilitySpellID, auraSpellIDs in pairs(AURA_SPELL_ID_ALIASES) do
  AURA_ALIAS_RELATED_IDS[abilitySpellID] = true
  for _, auraSpellID in ipairs(auraSpellIDs) do AURA_ALIAS_RELATED_IDS[auraSpellID] = true end
end

local function Trim(value)
  if ns.SafeValues:IsSecret(value) then return "" end
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function SafeNumericValue(value)
  local number = ns.SafeValues:Number(value)
  if number ~= nil then return number end
  local text = ns.SafeValues:String(value)
  return text and tonumber(text) or 0
end

local function SafeStringValue(value)
  return ns.SafeValues:String(value)
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

function Spells:ResolveConfiguredSpellID(value)
  local numeric = SafeNumericValue(value)
  if numeric > 0 then return numeric end
  local name = SafeStringValue(value)
  if not name or name == "" then return 0 end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if ok and not ns.SafeValues:IsSecret(info) and type(info) == "table" then
      local spellID = SafeNumericValue(info.spellID)
      local spellName = SafeStringValue(info.name)
      if spellID > 0 then
        self:RememberResolvedSpell(spellID, spellName or name)
        return spellID
      end
    end
  end
  return self:GetRememberedSpellID(name)
end

function Spells:GetAuraSpellIDs(value)
  local spellID = SafeNumericValue(value)
  if spellID <= 0 then
    return {}
  end

  local aliases = AURA_SPELL_ID_ALIASES[spellID]
  if not aliases then
    return { spellID }
  end

  local result = {}
  for _, auraSpellID in ipairs(aliases) do
    result[#result + 1] = auraSpellID
  end
  return result
end

function Spells:IsAuraAliasRelated(value)
  local spellID = SafeNumericValue(value)
  return spellID > 0 and AURA_ALIAS_RELATED_IDS[spellID] == true
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
