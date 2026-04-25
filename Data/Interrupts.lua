local _, ns = ...

local Interrupts = {}
ns.Interrupts = Interrupts

Interrupts.CLASS_ORDER = {
  "DEATHKNIGHT",
  "DEMONHUNTER",
  "DRUID",
  "EVOKER",
  "HUNTER",
  "MAGE",
  "MONK",
  "PALADIN",
  "PRIEST",
  "ROGUE",
  "SHAMAN",
  "WARLOCK",
  "WARRIOR",
}

Interrupts.CLASS_INFO = {
  DEATHKNIGHT = { name = "Death Knight", color = { 0.77, 0.12, 0.23 } },
  DEMONHUNTER = { name = "Demon Hunter", color = { 0.64, 0.19, 0.79 } },
  DRUID = { name = "Druid", color = { 1.00, 0.49, 0.04 } },
  EVOKER = { name = "Evoker", color = { 0.20, 0.58, 0.50 } },
  HUNTER = { name = "Hunter", color = { 0.67, 0.83, 0.45 } },
  MAGE = { name = "Mage", color = { 0.41, 0.80, 0.94 } },
  MONK = { name = "Monk", color = { 0.00, 1.00, 0.59 } },
  PALADIN = { name = "Paladin", color = { 0.96, 0.55, 0.73 } },
  PRIEST = { name = "Priest", color = { 1.00, 1.00, 1.00 } },
  ROGUE = { name = "Rogue", color = { 1.00, 0.96, 0.41 } },
  SHAMAN = { name = "Shaman", color = { 0.00, 0.44, 0.87 } },
  WARLOCK = { name = "Warlock", color = { 0.58, 0.51, 0.79 } },
  WARRIOR = { name = "Warrior", color = { 0.78, 0.61, 0.43 } },
}

Interrupts.FILTERS = {
  { class = "DEATHKNIGHT", name = "Death Knight", spells = {
    { id = 47528, label = "Mind Freeze", cd = 15, icon = 237527 },
  } },
  { class = "DEMONHUNTER", name = "Demon Hunter", spells = {
    { id = 183752, label = "Disrupt", cd = 15, icon = 1305153 },
  } },
  { class = "DRUID", name = "Druid", spells = {
    { id = 106839, label = "Skull Bash", cd = 15, icon = 236946 },
    { id = 78675, label = "Solar Beam", cd = 45, icon = 252188 },
  } },
  { class = "EVOKER", name = "Evoker", spells = {
    { id = 351338, label = "Quell", cd = 18, icon = 4622469 },
  } },
  { class = "HUNTER", name = "Hunter", spells = {
    { id = 147362, label = "Counter Shot", cd = 24, icon = 249170 },
    { id = 187707, label = "Muzzle", cd = 15, icon = 1376045 },
  } },
  { class = "MAGE", name = "Mage", spells = {
    { id = 2139, label = "Counterspell", cd = 20, icon = 135856 },
  } },
  { class = "MONK", name = "Monk", spells = {
    { id = 116705, label = "Spear Hand Strike", cd = 15, icon = 608940 },
  } },
  { class = "PALADIN", name = "Paladin", spells = {
    { id = 96231, label = "Rebuke", cd = 15, icon = 523893 },
  } },
  { class = "PRIEST", name = "Priest", spells = {
    { id = 15487, label = "Silence", cd = 30, icon = 458230 },
  } },
  { class = "ROGUE", name = "Rogue", spells = {
    { id = 1766, label = "Kick", cd = 15, icon = 132219 },
  } },
  { class = "SHAMAN", name = "Shaman", spells = {
    { id = 57994, label = "Wind Shear", cd = 12, icon = 136018 },
  } },
  { class = "WARLOCK", name = "Warlock", spells = {
    { id = 19647, ids = { 19647, 132409 }, label = "Spell Lock", cd = 24, icon = 136174 },
    { id = 119914, label = "Axe Toss", cd = 30, icon = 236316 },
  } },
  { class = "WARRIOR", name = "Warrior", spells = {
    { id = 6552, label = "Pummel", cd = 15, icon = 132938 },
  } },
}

Interrupts.SPEC_PRIMARY = {
  [250] = { class = "DEATHKNIGHT", spellID = 47528, cd = 15 },
  [251] = { class = "DEATHKNIGHT", spellID = 47528, cd = 15 },
  [252] = { class = "DEATHKNIGHT", spellID = 47528, cd = 15 },

  [577] = { class = "DEMONHUNTER", spellID = 183752, cd = 15 },
  [581] = { class = "DEMONHUNTER", spellID = 183752, cd = 15 },
  [1480] = { class = "DEMONHUNTER", spellID = 183752, cd = 15 },

  [102] = { class = "DRUID", spellID = 78675, cd = 45 },
  [103] = { class = "DRUID", spellID = 106839, cd = 15 },
  [104] = { class = "DRUID", spellID = 106839, cd = 15 },

  [1467] = { class = "EVOKER", spellID = 351338, cd = 18 },
  [1468] = { class = "EVOKER", spellID = 351338, cd = 18 },
  [1473] = { class = "EVOKER", spellID = 351338, cd = 18 },

  [253] = { class = "HUNTER", spellID = 147362, cd = 24 },
  [254] = { class = "HUNTER", spellID = 147362, cd = 24 },
  [255] = { class = "HUNTER", spellID = 187707, cd = 15 },

  [62] = { class = "MAGE", spellID = 2139, cd = 20 },
  [63] = { class = "MAGE", spellID = 2139, cd = 20 },
  [64] = { class = "MAGE", spellID = 2139, cd = 20 },

  [268] = { class = "MONK", spellID = 116705, cd = 15 },
  [269] = { class = "MONK", spellID = 116705, cd = 15 },

  [66] = { class = "PALADIN", spellID = 96231, cd = 15 },
  [70] = { class = "PALADIN", spellID = 96231, cd = 15 },

  [258] = { class = "PRIEST", spellID = 15487, cd = 30 },

  [259] = { class = "ROGUE", spellID = 1766, cd = 15 },
  [260] = { class = "ROGUE", spellID = 1766, cd = 15 },
  [261] = { class = "ROGUE", spellID = 1766, cd = 15 },

  [262] = { class = "SHAMAN", spellID = 57994, cd = 12 },
  [263] = { class = "SHAMAN", spellID = 57994, cd = 12 },
  [264] = { class = "SHAMAN", spellID = 57994, cd = 30 },

  [265] = { class = "WARLOCK", spellID = 19647, cd = 24 },
  [266] = { class = "WARLOCK", spellID = 119914, cd = 30 },
  [267] = { class = "WARLOCK", spellID = 19647, cd = 24 },

  [71] = { class = "WARRIOR", spellID = 6552, cd = 15 },
  [72] = { class = "WARRIOR", spellID = 6552, cd = 15 },
  [73] = { class = "WARRIOR", spellID = 6552, cd = 15 },
}

Interrupts.SPEC_NO_INTERRUPT = {
  [65] = true,
  [105] = true,
  [270] = true,
  [256] = true,
  [257] = true,
}

Interrupts.CLASS_HAS_NO_KICK_VARIANTS = {
  DRUID = true,
  PALADIN = true,
  PRIEST = true,
}

Interrupts.SPELL_ALIASES = {
  [89766] = 119914,
  [1276467] = 132409,
  [132409] = 132409,
}

Interrupts.CD_REDUCTION_TALENTS = {
  [388039] = { affects = 147362, reduction = 2, name = "Lone Survivor" },
  [412713] = { affects = 351338, pctReduction = 10, name = "Interwoven Threads" },
  [391271] = { affects = 6552, pctReduction = 10, name = "Seasoned Soldier" },
}

Interrupts.BUILTIN_SOUNDS = {
  { name = "None" },
  { name = "Raid Warning", file = "Sound\\Interface\\RaidWarning.ogg" },
  { name = "Error", file = "Sound\\Interface\\IfloopIsEnd.ogg" },
  { name = "Alarm", file = "Sound\\Interface\\AlarmClockWarning1.ogg" },
  { name = "Coin", file = "Sound\\Spells\\SimonGame_Visual_CoinDing.ogg" },
  { name = "Ping", file = "Sound\\Doodad\\BellTollNight.ogg" },
}

Interrupts.SOUND_CHANNELS = {
  { value = "Master", label = "Master" },
  { value = "SFX", label = "SFX" },
  { value = "Ambience", label = "Ambience" },
  { value = "Music", label = "Music" },
  { value = "Dialog", label = "Dialog" },
}

Interrupts.SPELL_INDEX = {}
Interrupts.CLASS_FILTER_LOOKUP = {}

for _, group in ipairs(Interrupts.FILTERS) do
  Interrupts.CLASS_FILTER_LOOKUP[group.class] = group
  for _, spell in ipairs(group.spells) do
    Interrupts.SPELL_INDEX[spell.id] = spell
    if type(spell.ids) == "table" then
      for _, aliasId in ipairs(spell.ids) do
        Interrupts.SPELL_INDEX[aliasId] = spell
      end
    end
  end
end

local function GetLSM()
  if not LibStub then
    return nil
  end
  return LibStub("LibSharedMedia-3.0", true)
end

local SOURCE_SWATCHES = {
  { 0.93, 0.78, 0.24 },
  { 0.40, 0.78, 0.97 },
  { 0.63, 0.85, 0.48 },
  { 0.96, 0.64, 0.34 },
  { 0.82, 0.64, 0.94 },
  { 0.94, 0.58, 0.74 },
}

local function HashString(value)
  local hash = 0
  value = tostring(value or "")
  for index = 1, #value do
    hash = (hash * 33 + value:byte(index)) % 2147483647
  end
  return hash
end

local function CopyColor(r, g, b, a)
  return { r = r, g = g, b = b, a = a == nil and 1 or a }
end

local function GetAddonNameFromPath(file)
  file = tostring(file or ""):gsub("/", "\\")
  return file:match("[Ii]nterface\\[Aa]ddOns\\([^\\]+)")
end

local function NormalizeSourceLabel(label)
  label = tostring(label or "")
  label = label:gsub("^DBM%-VP", "DBM VP ")
  label = label:gsub("^DBM%-", "DBM ")
  label = label:gsub("^SharedMedia[_%-]?", "SharedMedia ")
  label = label:gsub("^LibSharedMedia[_%-]?", "LSM ")
  label = label:gsub("[_%-%s]+", " ")
  label = label:gsub("^%s+", ""):gsub("%s+$", "")
  return label
end

local function GetSourceColor(sourceKey)
  sourceKey = tostring(sourceKey or ""):lower()
  if sourceKey == "disabled" then
    return CopyColor(0.62, 0.68, 0.76)
  end
  if sourceKey == "blizzard" then
    return CopyColor(0.82, 0.86, 0.92)
  end
  if sourceKey == "dbm-core" then
    return CopyColor(0.40, 0.78, 0.97)
  end
  if sourceKey:match("^dbm%-vp") then
    return CopyColor(0.96, 0.64, 0.34)
  end
  if sourceKey == "popauras" then
    return CopyColor(0.93, 0.78, 0.24)
  end
  if sourceKey:find("sharedmedia", 1, true) then
    return CopyColor(0.63, 0.85, 0.48)
  end
  local swatch = SOURCE_SWATCHES[(HashString(sourceKey) % #SOURCE_SWATCHES) + 1]
  return CopyColor(swatch[1], swatch[2], swatch[3])
end

local function GetSoundSourceInfo(name, file)
  if name == "None" then
    return "disabled", "Disabled", GetSourceColor("disabled"), 0
  end

  local addonName = GetAddonNameFromPath(file)
  if addonName == "PopAuras" then
    return "popauras", "PopAuras", GetSourceColor("popauras"), 10
  end
  if addonName == "DBM-Core" then
    return "dbm-core", "DBM Core", GetSourceColor("dbm-core"), 20
  end
  if addonName and addonName:match("^DBM%-VP") then
    return addonName:lower(), NormalizeSourceLabel(addonName), GetSourceColor(addonName), 21
  end
  if addonName and addonName:match("^DBM%-") then
    return addonName:lower(), NormalizeSourceLabel(addonName), GetSourceColor(addonName), 22
  end
  if addonName and addonName:find("SharedMedia", 1, true) then
    return addonName:lower(), NormalizeSourceLabel(addonName), GetSourceColor(addonName), 30
  end
  if addonName and addonName ~= "" then
    return addonName:lower(), NormalizeSourceLabel(addonName), GetSourceColor(addonName), 40
  end
  if tostring(file or "") ~= "" then
    return "blizzard", "Blizzard", GetSourceColor("blizzard"), 15
  end
  return "custom", "Custom", GetSourceColor("custom"), 50
end

local function NormalizeSoundLabel(name)
  local label = tostring(name or "")
  if label == "" then
    return ""
  end

  label = label:gsub("|c%x%x%x%x%x%x%x%x", "")
  label = label:gsub("|r", "")
  label = label:gsub("|T.-|t", "")
  label = label:gsub("%s+", " ")
  label = label:gsub("^%s+", ""):gsub("%s+$", "")

  if label == "" then
    return tostring(name or "")
  end

  return label
end

local function SetDefault(tbl, key, value)
  if tbl[key] == nil then
    tbl[key] = value
  end
end

function Interrupts:GetClassInfo(classToken)
  return self.CLASS_INFO[classToken]
end

function Interrupts:GetClassName(classToken)
  local info = self:GetClassInfo(classToken)
  return info and info.name or tostring(classToken or "")
end

function Interrupts:GetClassColor(classToken)
  local info = self:GetClassInfo(classToken)
  local color = info and info.color
  if not color then
    return 1, 1, 1
  end
  return color[1], color[2], color[3]
end

function Interrupts:GetSpellInfo(spellID)
  spellID = tonumber(spellID or 0) or 0
  if spellID <= 0 then
    return nil
  end
  return self.SPELL_INDEX[self.SPELL_ALIASES[spellID] or spellID] or self.SPELL_INDEX[spellID]
end

function Interrupts:ResolveSpellID(spellID)
  spellID = tonumber(spellID or 0) or 0
  if spellID <= 0 then
    return nil
  end
  local resolved = self.SPELL_ALIASES[spellID] or spellID
  return self.SPELL_INDEX[resolved] and resolved or nil
end

local function GetActiveTalentSpellSet()
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo) then
    return {}
  end

  local configID = C_ClassTalents.GetActiveConfigID()
  if not configID then
    return {}
  end

  local configInfo = C_Traits.GetConfigInfo(configID)
  if not configInfo or type(configInfo.treeIDs) ~= "table" then
    return {}
  end

  local activeTalents = {}
  for _, treeID in ipairs(configInfo.treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
      if nodeInfo and nodeInfo.activeEntry and (nodeInfo.activeRank or 0) > 0 then
        local entryInfo = C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID) or nil
        local definitionInfo = entryInfo and entryInfo.definitionID and C_Traits.GetDefinitionInfo and C_Traits.GetDefinitionInfo(entryInfo.definitionID) or nil
        local talentSpellID = definitionInfo and tonumber(definitionInfo.spellID or 0) or 0
        if talentSpellID > 0 then
          activeTalents[talentSpellID] = true
        end
      end
    end
  end

  return activeTalents
end

local function ApplyTalentCooldownAdjustments(spellID, baseCd, talentMap)
  local adjustedCd = tonumber(baseCd or 0) or 0
  spellID = tonumber(spellID or 0) or 0
  if spellID <= 0 or adjustedCd <= 0 then
    return adjustedCd
  end

  talentMap = type(talentMap) == "table" and talentMap or {}
  for talentSpellID, talent in pairs(Interrupts.CD_REDUCTION_TALENTS or {}) do
    if talentMap[tonumber(talentSpellID or 0) or 0] and talent and talent.affects == spellID then
      if talent.pctReduction then
        adjustedCd = math.floor(adjustedCd * (1 - (talent.pctReduction / 100)) + 0.5)
      elseif talent.reduction then
        adjustedCd = adjustedCd - talent.reduction
      end
    end
  end

  return math.max(1, adjustedCd)
end

function Interrupts:GetPlayerInterrupt()
  local _, classToken = UnitClass("player")
  local specIndex = GetSpecialization and GetSpecialization() or nil
  local specID = specIndex and GetSpecializationInfo and select(1, GetSpecializationInfo(specIndex)) or nil
  if not specID and classToken and self.CLASS_HAS_NO_KICK_VARIANTS and self.CLASS_HAS_NO_KICK_VARIANTS[classToken] then
    return nil
  end
  if specID and self.SPEC_NO_INTERRUPT and self.SPEC_NO_INTERRUPT[specID] then
    return nil
  end
  local primary = specID and self.SPEC_PRIMARY[specID] or nil
  local activeTalents = GetActiveTalentSpellSet()
  if primary then
    local spellInfo = self:GetSpellInfo(primary.spellID)
    local adjustedCd = ApplyTalentCooldownAdjustments(primary.spellID, primary.cd, activeTalents)
    return {
      class = primary.class,
      spellID = primary.spellID,
      cd = adjustedCd,
      icon = spellInfo and spellInfo.icon or nil,
      label = spellInfo and spellInfo.label or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(primary.spellID)) or "Interrupt",
    }
  end

  if not classToken then
    return nil
  end

  local group = self.CLASS_FILTER_LOOKUP[classToken]
  local fallback = group and group.spells and group.spells[1] or nil
  if not fallback then
    return nil
  end

  return {
    class = classToken,
    spellID = fallback.id,
    cd = ApplyTalentCooldownAdjustments(fallback.id, fallback.cd, activeTalents),
    icon = fallback.icon,
    label = fallback.label,
  }
end

function Interrupts:GetInterruptForSpec(specID)
  specID = tonumber(specID or 0) or 0
  if specID <= 0 then
    return nil
  end
  if self.SPEC_NO_INTERRUPT and self.SPEC_NO_INTERRUPT[specID] then
    return nil
  end

  local primary = self.SPEC_PRIMARY and self.SPEC_PRIMARY[specID] or nil
  if not primary then
    return nil
  end

  local spellInfo = self:GetSpellInfo(primary.spellID)
  return {
    class = primary.class,
    spellID = primary.spellID,
    cd = primary.cd,
    icon = spellInfo and spellInfo.icon or nil,
    label = spellInfo and spellInfo.label or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(primary.spellID)) or "Interrupt",
  }
end

function Interrupts:GetInterruptForClass(classToken)
  if not classToken then
    return nil
  end

  local group = self.CLASS_FILTER_LOOKUP and self.CLASS_FILTER_LOOKUP[classToken] or nil
  local fallback = group and group.spells and group.spells[1] or nil
  if not fallback then
    return nil
  end

  return {
    class = classToken,
    spellID = fallback.id,
    cd = fallback.cd,
    icon = fallback.icon,
    label = fallback.label,
  }
end

function Interrupts:GetSoundOptions()
  if self.soundOptionsCache then
    return self.soundOptionsCache
  end

  local out = {}
  local seen = {}

  local function addSound(name, label, file)
    if not name or seen[name] then
      return
    end
    seen[name] = true
    local sourceKey, sourceLabel, sourceColor, sourceSort = GetSoundSourceInfo(name, file)
    out[#out + 1] = {
      name = name,
      label = NormalizeSoundLabel(label or name),
      file = file,
      sourceKey = sourceKey,
      sourceLabel = sourceLabel,
      sourceColor = sourceColor,
      color = sourceColor,
      sourceSort = sourceSort or 99,
    }
  end

  addSound("None", "None", nil)

  local lsm = GetLSM()
  if lsm and lsm.List and lsm.Fetch then
    local list = lsm:List("sound")
    if type(list) == "table" then
      for _, name in ipairs(list) do
        local file = lsm:Fetch("sound", name)
        if file then
          addSound(name, name, file)
        end
      end
    end
  end

  for _, entry in ipairs(self.BUILTIN_SOUNDS) do
    if entry.name ~= "None" then
      addSound(entry.name, entry.name, entry.file)
    end
  end

  table.sort(out, function(a, b)
    if a.sourceSort ~= b.sourceSort then
      return a.sourceSort < b.sourceSort
    end
    if a.sourceLabel ~= b.sourceLabel then
      return tostring(a.sourceLabel or ""):lower() < tostring(b.sourceLabel or ""):lower()
    end
    return tostring(a.label or a.name or ""):lower() < tostring(b.label or b.name or ""):lower()
  end)

  self.soundOptionsCache = out
  return self.soundOptionsCache
end

function Interrupts:GetSoundChannelOptions()
  return self.SOUND_CHANNELS
end

function Interrupts:PlaySound(soundName, channel)
  if not soundName or soundName == "None" then
    return
  end

  local soundChannel = tostring(channel or "Master")

  local lsm = GetLSM()
  if lsm and lsm.Fetch and PlaySoundFile then
    local path = lsm:Fetch("sound", soundName, true)
    if path then
      PlaySoundFile(path, soundChannel)
      return
    end
  end

  for _, entry in ipairs(self.BUILTIN_SOUNDS) do
    if entry.name == soundName and entry.file and PlaySoundFile then
      PlaySoundFile(entry.file, soundChannel)
      return
    end
  end
end

function Interrupts:EnsureAuraDefaults(aura)
  if not aura or aura.kind ~= "interrupt_tracker" then
    return aura and aura.interrupt or {}
  end

  aura.display = aura.display or {}
  aura.position = aura.position or {}
  aura.interrupt = aura.interrupt or {}

  local settings = aura.interrupt
  if (tonumber(settings.layoutVersion or 0) or 0) < 2 then
    if aura.display.icon == false then
      aura.display.icon = true
    end
    if aura.display.showName == false then
      aura.display.showName = true
    end
    if aura.display.showTimer == false then
      aura.display.showTimer = true
    end
    settings.layoutVersion = 2
  end

  SetDefault(settings, "fillMode", "DRAIN")
  SetDefault(settings, "sortOrder", "NONE")
  SetDefault(settings, "barAlpha", 0.88)
  SetDefault(settings, "showFailedKick", true)
  SetDefault(settings, "showBarBackground", true)
  SetDefault(settings, "barBackgroundColor", { r = 0.09, g = 0.11, b = 0.16, a = 0.94 })
  SetDefault(settings, "readyBarAlpha", 0.40)
  SetDefault(settings, "paddingX", 6)
  SetDefault(settings, "paddingY", 3)
  SetDefault(settings, "displayInterruptName", true)
  SetDefault(settings, "clickToAnnounce", false)
  SetDefault(settings, "announceChannel", "PARTY")
  SetDefault(settings, "antiSpam", true)
  SetDefault(settings, "soundEnabled", false)
  SetDefault(settings, "soundOwnKickOnly", true)
  SetDefault(settings, "soundKickSuccess", "None")
  SetDefault(settings, "soundKickFailed", "None")
  settings.disabledSpells = type(settings.disabledSpells) == "table" and settings.disabledSpells or {}

  SetDefault(aura.display, "icon", true)
  SetDefault(aura.display, "showName", true)
  SetDefault(aura.display, "showTimer", true)
  SetDefault(aura.display, "showStacks", false)
  SetDefault(aura.display, "iconMatchBarSize", true)
  SetDefault(aura.display, "iconAnchor", "LEFT")
  SetDefault(aura.display, "iconSize", aura.display.height or 34)
  SetDefault(aura.display, "iconOffsetX", 0)
  SetDefault(aura.display, "iconOffsetY", 0)
  SetDefault(aura.display, "nameFontStyle", "FRIZQT_OUTLINE")
  SetDefault(aura.display, "nameFontSize", 12)
  SetDefault(aura.display, "nameRotation", 0)
  SetDefault(aura.display, "nameAnchor", "LEFT")
  SetDefault(aura.display, "nameOffsetX", 6)
  SetDefault(aura.display, "nameOffsetY", 0)
  SetDefault(aura.display, "nameColor", { r = 1, g = 1, b = 1, a = 1 })
  SetDefault(aura.display, "timerFontStyle", "FRIZQT_OUTLINE")
  SetDefault(aura.display, "timerFontSize", 12)
  SetDefault(aura.display, "timerRotation", 0)
  SetDefault(aura.display, "timerAnchor", "RIGHT")
  SetDefault(aura.display, "timerOffsetX", -6)
  SetDefault(aura.display, "timerOffsetY", 0)
  SetDefault(aura.display, "timerColor", { r = 1, g = 1, b = 1, a = 1 })
  SetDefault(aura.display, "timerDecimals", 0)
  SetDefault(aura.display, "hideReadyTimer", false)
  SetDefault(aura.display, "backgroundColor", { r = 0, g = 0, b = 0, a = 0.45 })
  SetDefault(aura.display, "width", 240)
  SetDefault(aura.display, "height", 34)
  SetDefault(aura.display, "spacing", 4)
  SetDefault(aura.position, "width", aura.display.width)
  SetDefault(aura.position, "height", aura.display.height)

  for _, group in ipairs(self.FILTERS) do
    for _, spell in ipairs(group.spells) do
      if type(spell.ids) == "table" then
        local canonical = spell.id or spell.ids[1]
        if canonical and settings.disabledSpells[canonical] == true then
          for _, spellID in ipairs(spell.ids) do
            settings.disabledSpells[spellID] = true
          end
        end
      end
    end
  end

  return settings
end
