local _, ns = ...

local Tables = ns.util.Tables
local Anchors = ns.util.Anchors
local UnitAuraList = ns.util.UnitAuraList

local Defaults = {}
ns.Defaults = Defaults

Defaults.database = {
  version = ns.Constants.DB_VERSION,
  auras = {},
  order = {},
  ui = {
    selectedAuraId = nil,
    selectedTriggerIndex = 1,
    activeTab = "display",
    editorMode = "config",
    collapsedGroups = {},
    window = {
      point = "CENTER",
      relativeTo = "UIParent",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      width = 1100,
      height = 700,
    },
  },
  exports = {},
}

Defaults.position = {
  point = "CENTER",
  relativeTo = "UIParent",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
  width = 220,
  height = 32,
}

Defaults.text = {
  label = "%n",
  status = "",
  timer = "%p",
  nameOverride = "",
}

Defaults.display = {
  alpha = 1,
  color = { r = 0.1, g = 0.6, b = 1, a = 1 },
  noStacksBarColorEnabled = false,
  noStacksBarColor = { r = 0.86, g = 0.18, b = 0.18, a = 1 },
  readyLook = false,
  readyColor = { r = 0.16, g = 0.72, b = 0.26, a = 1 },
  barTexture = "FLAT",
  backgroundColor = { r = 0, g = 0, b = 0, a = 0.45 },
  showBackground = true,
  backgroundGamma = 1,
  permanentAlpha = 0.25,
  icon = true,
  iconOverrideId = 0,
  iconOverrideName = "",
  iconSize = 32,
  iconMatchBarSize = true,
  iconAnchor = "LEFT",
  iconOffsetX = 0,
  iconOffsetY = 0,
  swipe = true,
  iconSwipeColor = { r = 0, g = 0, b = 0, a = 0.60 },
  iconCooldownEdge = false,
  iconCooldownBling = false,
  hideCDMIcon = false,
  hideBlizzardSpellAlert = false,
  blizzardSpellAlertSpellId = 0,
  blizzardSpellAlertSpellName = "",
  soundEnabled = false,
  soundMode = "activate",
  soundFile = "None",
  trinketTopSoundFile = "None",
  trinketBottomSoundFile = "None",
  soundChannel = "Master",
  desaturate = false,
  glow = false,
  glowWhenActive = false,
  activeGlowStyle = "NONE",
  showName = true,
  showTimer = true,
  showStacks = true,
  nameFontStyle = "FRIZQT_OUTLINE",
  nameFontSize = 12,
  nameRotation = 0,
  nameColor = { r = 1, g = 1, b = 1, a = 1 },
  nameAnchor = "LEFT",
  nameOffsetX = 6,
  nameOffsetY = 0,
  timerFontStyle = "FRIZQT_OUTLINE",
  timerFontSize = 12,
  timerRotation = 0,
  timerColor = { r = 1, g = 1, b = 1, a = 1 },
  readyText = "Ready",
  readyTextColor = { r = 0.20, g = 0.95, b = 0.20, a = 1 },
  timerDecimals = 1,
  hideReadyTimer = false,
  timerAnchor = "RIGHT",
  timerOffsetX = -6,
  timerOffsetY = 0,
  stacksFontStyle = "FRIZQT_OUTLINE",
  stacksFontSize = 14,
  stacksRotation = 0,
  stacksColor = { r = 1, g = 1, b = 1, a = 1 },
  stacksAnchor = "TOPRIGHT",
  stacksOffsetX = -2,
  stacksOffsetY = -2,
  width = 220,
  height = 32,
  reverse = false,
  orientation = "HORIZONTAL",
  frameStrata = "MEDIUM",
  frameLevel = 1,
  previewAnimate = false,
  spacing = 6,
  growth = "DOWN",
  maintainAuraOrder = false,
  align = "LEFT",
  showOnRaidFrames = false,
  raidFrameIconSize = 18,
  raidFrameAnchor = "BOTTOM",
  raidFrameGrowth = "AUTO",
  raidFrameOffsetX = 0,
  raidFrameOffsetY = 11,
  raidFrameShowGlow = false,
  raidFrameShowDuration = false,
  raidFrameShowStacks = false,
}

Defaults.load = {
  classes = {},
  specs = {},
  talent = false,
  talents = {},
  savedLoadoutMode = "any",
  savedLoadoutSelections = {},
  savedLoadoutId = 0,
  savedLoadoutName = "",
  savedLoadoutSpecId = 0,
  savedLoadoutClassToken = "",
  level = 0,
  combat = "any",
  equippedItemId = 0,
  equippedItemName = "",
  instanceId = 0,
  instanceType = "",
  encounterId = 0,
  visibility = {
    dungeon = true,
    delve = true,
    raid = true,
    open_world = true,
    solo = true,
    arena = true,
    battleground = true,
  },
}

Defaults.interruptTracker = {
  layoutVersion = 2,
  fillMode = "DRAIN",
  sortOrder = "NONE",
  barAlpha = 0.88,
  showFailedKick = true,
  showBarBackground = true,
  barBackgroundColor = { r = 0.09, g = 0.11, b = 0.16, a = 0.94 },
  readyBarAlpha = 0.40,
  paddingX = 6,
  paddingY = 3,
  displayInterruptName = true,
  clickToAnnounce = false,
  announceChannel = "PARTY",
  antiSpam = true,
  soundEnabled = false,
  soundOwnKickOnly = true,
  soundKickSuccess = "None",
  soundKickFailed = "None",
  disabledSpells = {},
}

Defaults.baseAction = {
  type = "glow_unit_frame",
  event = "on_activate",
  enabled = true,
  unit = "%n",
  duration = 4,
}

Defaults.baseTrigger = {
  type = "simple",
  enabled = true,
  mode = "always",
}

local function ApplyTriggerTypeDefaults(trigger)
  if type(trigger) ~= "table" then
    return
  end

  local triggerType = trigger.type or "simple"
  if triggerType == "private_aura" then
    trigger.type = "simple"
    trigger.mode = "never"
    trigger.privateAuraTarget = nil
    triggerType = "simple"
  end

  if triggerType == "aura" then
    trigger.unit = trigger.unit or "player"
    trigger.auraType = trigger.auraType or "buff"
    trigger.auraFilter = trigger.auraFilter or "present"
    trigger.groupRange = trigger.groupRange or "any"
    if trigger.castByMe == nil then
      trigger.castByMe = false
    end
    if trigger.aliveOnly == nil then
      trigger.aliveOnly = false
    end
    if trigger.ignoreNPCs == nil then
      trigger.ignoreNPCs = false
    end
    trigger.spellId = tonumber(trigger.spellId or 0) or 0
    if trigger.unit == "nameplate" then
      -- Hostile helpful auras are rendered only through Blizzard's native
      -- AuraContainer, whose supported category filters intentionally replace
      -- exact spell matching for this preset.
      trigger.auraType = "buff"
      trigger.auraFilter = "present"
      trigger.castByMe = false
      -- Retail currently honors only the unrestricted helpful-aura candidate
      -- set for hostile nameplates. Keep the trigger fixed to that supported
      -- mode now that its redundant Trigger tab is no longer exposed. Retain
      -- legacy category selections so saved data remains forward-compatible.
      trigger.nameplateAllBuffs = true
      trigger.nameplateStealable = trigger.nameplateStealable == true
      trigger.nameplateMagic = trigger.nameplateMagic == true
      trigger.nameplateBossAura = trigger.nameplateBossAura == true
      trigger.nameplatePriorityAura = trigger.nameplatePriorityAura == true
      trigger.nameplateRoleAura = nil
      trigger.nameplateShowAll = nil
      trigger.nameplateShowPersonal = nil
      local maxAuras = math.floor(tonumber(trigger.nameplateMaxAuras or 3) or 3)
      trigger.nameplateMaxAuras = math.max(1, math.min(maxAuras, 8))
    end
  elseif triggerType == "spell_cooldown" then
    trigger.spellId = tonumber(trigger.spellId or 0) or 0
    trigger.cooldownMatch = trigger.cooldownMatch or "cooldown"
    if trigger.showAlways == nil then
      trigger.showAlways = false
    end
    trigger.manualCooldown = tonumber(trigger.manualCooldown or 0) or 0
    if trigger.showChargeCooldown == nil then
      trigger.showChargeCooldown = true
    end
  elseif triggerType == "item_cooldown" then
    trigger.itemId = tonumber(trigger.itemId or 0) or 0
    trigger.itemName = trigger.itemName or ""
    trigger.cooldownMatch = trigger.cooldownMatch or "cooldown"
    if trigger.showAlways == nil then
      trigger.showAlways = false
    end
  elseif triggerType == "trinket_cooldown" then
    if trigger.trinketTop == nil then
      trigger.trinketTop = true
    end
    if trigger.trinketBottom == nil then
      trigger.trinketBottom = true
    end
    if trigger.glowWhileActive == nil then
      trigger.glowWhileActive = false
    end
    if trigger.trinketGrowth ~= "UP" and trigger.trinketGrowth ~= "LEFT" and trigger.trinketGrowth ~= "RIGHT" then
      trigger.trinketGrowth = "DOWN"
    end
    trigger.ignoredTrinkets = trigger.ignoredTrinkets or ""
    trigger.cooldownMatch = trigger.cooldownMatch or "cooldown"
    if trigger.showAlways == nil then
      trigger.showAlways = false
    end
  elseif triggerType == "cast" then
    trigger.unit = trigger.unit or "player"
  elseif triggerType == "spell_cast_event" then
    trigger.unit = "player"
    trigger.spellId = tonumber(trigger.spellId or 0) or 0
    trigger.castEventDuration = tonumber(trigger.castEventDuration or 1) or 1
    trigger.castEventDuration = math.max(0.1, math.min(trigger.castEventDuration, 10))
  elseif triggerType == "death_alert" then
    trigger.alertDuration = tonumber(trigger.alertDuration or 2) or 2
    trigger.maxAlertsPerCombat = tonumber(trigger.maxAlertsPerCombat or 7) or 7
    if trigger.showTank == nil then
      trigger.showTank = true
    end
    if trigger.showHealer == nil then
      trigger.showHealer = true
    end
    if trigger.showDPS == nil then
      trigger.showDPS = true
    end
    trigger.soundTank = trigger.soundTank or "None"
    trigger.soundHealer = trigger.soundHealer or "None"
    trigger.soundDPS = trigger.soundDPS or "None"
  elseif triggerType == "chat" then
    if type(trigger.chatChannels) ~= "table" or #trigger.chatChannels == 0 then
      trigger.chatChannels = { trigger.chatChannel or "WHISPER" }
    end
    trigger.chatChannel = trigger.chatChannel or "WHISPER"
    trigger.chatMessage = trigger.chatMessage or ""
    trigger.chatSource = trigger.chatSource or ""
    trigger.chatDuration = tonumber(trigger.chatDuration or 4) or 4
    if trigger.chatExact == nil then
      trigger.chatExact = false
    end
  elseif triggerType == "aura_list" then
    trigger.unit = trigger.unit or "player"
    trigger.auraType = trigger.auraType or "buff"
    if UnitAuraList then
      UnitAuraList:RetireCasterFilter(trigger)
      UnitAuraList:ApplySortMode(trigger, UnitAuraList:GetSortMode(trigger))
      UnitAuraList:ApplyMaxDuration(trigger, UnitAuraList:GetMaxDuration(trigger))
      UnitAuraList:ApplyMaxRows(trigger, UnitAuraList:GetMaxRows(trigger))
    else
      trigger.auraListFilterMode = nil
      trigger.targetDebuffFilterMode = nil
      trigger.targetMineOrUnownedOnly = nil
      local isPlayerBuff = trigger.unit == "player" and trigger.auraType ~= "debuff"
      if trigger.auraListSortMode ~= "shortest_first"
          and trigger.auraListSortMode ~= "longest_first" then
        trigger.auraListSortMode = isPlayerBuff and "longest_first" or "shortest_first"
      end
      trigger.auraListMaxDuration = math.max(
        0, tonumber(trigger.auraListMaxDuration or 0) or 0)
      local maxRows = math.floor(tonumber(trigger.auraListMaxRows or 0) or 0)
      trigger.auraListMaxRows = math.max(0, math.min(maxRows, 100))
    end
    trigger.hideBlizzardBuffs = trigger.hideBlizzardBuffs == true
    trigger.hideBlizzardDebuffs = trigger.hideBlizzardDebuffs == true
  end
end

function Defaults:ApplyTriggerDefaults(trigger)
  if type(trigger) ~= "table" then
    return trigger
  end
  Tables.MergeDefaults(trigger, self.baseTrigger)
  ApplyTriggerTypeDefaults(trigger)
  return trigger
end

local function NormalizeSavedLoadoutNameKey(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return ""
  end
  return string.lower(value)
end

local function BuildSavedLoadoutSelectionKey(classToken, specID, configID, name)
  classToken = tostring(classToken or "")
  specID = tonumber(specID or 0) or 0
  configID = tonumber(configID or 0) or 0
  if classToken == "" or specID <= 0 then
    return nil
  end

  local nameKey = NormalizeSavedLoadoutNameKey(name)
  if nameKey ~= "" then
    return string.format("%s:%d:name:%s", classToken, specID, nameKey)
  end

  if configID == 0 then
    return nil
  end

  return string.format("%s:%d:config:%d", classToken, specID, configID)
end

local function ApplyLegacySavedLoadoutSelection(load)
  if type(load) ~= "table" then
    return
  end

  load.savedLoadoutSelections = type(load.savedLoadoutSelections) == "table" and load.savedLoadoutSelections or {}
  if next(load.savedLoadoutSelections) ~= nil then
    return
  end

  local configID = tonumber(load.savedLoadoutId or 0) or 0
  local specID = tonumber(load.savedLoadoutSpecId or 0) or 0
  local classToken = tostring(load.savedLoadoutClassToken or "")
  if configID == 0 or specID <= 0 or classToken == "" then
    return
  end

  local key = BuildSavedLoadoutSelectionKey(classToken, specID, configID, load.savedLoadoutName)
  if not key then
    return
  end

  load.savedLoadoutSelections[key] = {
    classToken = classToken,
    className = classToken,
    specID = specID,
    specName = "",
    configID = configID,
    name = tostring(load.savedLoadoutName or ""),
  }
end

function Defaults:ApplyAuraDefaults(aura)
  if type(aura) ~= "table" then
    return aura
  end

  if aura.kind == "private_aura_frame" then
    aura.kind = "group"
    aura.triggers = {}
  end

  if aura.kind == "icon" then
    aura.display = type(aura.display) == "table" and aura.display or {}
    aura.position = type(aura.position) == "table" and aura.position or {}

    if aura.display.width == nil then
      aura.display.width = 56
    end
    if aura.display.height == nil then
      aura.display.height = 56
    end
    if aura.position.width == nil then
      aura.position.width = 56
    end
    if aura.position.height == nil then
      aura.position.height = 56
    end
  end

  aura.load = Tables.MergeDefaults(type(aura.load) == "table" and aura.load or {}, self.load)
  ApplyLegacySavedLoadoutSelection(aura.load)
  aura.display = Tables.MergeDefaults(type(aura.display) == "table" and aura.display or {}, self.display)
  aura.position = Tables.MergeDefaults(type(aura.position) == "table" and aura.position or {}, self.position)
  aura.text = Tables.MergeDefaults(type(aura.text) == "table" and aura.text or {}, self.text)
  aura.conditions = type(aura.conditions) == "table" and aura.conditions or {}
  aura.actions = type(aura.actions) == "table" and aura.actions or {}
  aura.children = type(aura.children) == "table" and aura.children or {}
  aura.enabled = aura.enabled ~= false

  for index, action in ipairs(aura.actions) do
    if type(action) ~= "table" then
      aura.actions[index] = Tables.DeepCopy(self.baseAction)
    else
      Tables.MergeDefaults(action, self.baseAction)
      action.type = action.type or self.baseAction.type
      action.event = action.event or self.baseAction.event
      action.unit = action.unit or self.baseAction.unit
      action.duration = tonumber(action.duration or self.baseAction.duration) or self.baseAction.duration
      action.enabled = action.enabled ~= false
    end
  end

  if aura.kind == "interrupt_tracker" then
    aura.interrupt = Tables.MergeDefaults(type(aura.interrupt) == "table" and aura.interrupt or {}, self.interruptTracker)
  end

  if type(aura.triggers) ~= "table" then
    aura.triggers = {}
  end
  if aura.kind ~= "interrupt_tracker" and aura.kind ~= "group" and aura.kind ~= "dynamic_group" and #aura.triggers == 0 then
    aura.triggers[1] = Tables.DeepCopy(self.baseTrigger)
  end
  if aura.kind == "aura_bar_list" and type(aura.triggers[1]) == "table"
      and (aura.triggers[1].type == nil or aura.triggers[1].type == "simple") then
    aura.triggers[1].type = "aura_list"
  end
  local hasNameplateAuraTrigger = false
  for _, trigger in ipairs(aura.triggers) do
    self:ApplyTriggerDefaults(trigger)
    hasNameplateAuraTrigger = hasNameplateAuraTrigger
      or (trigger.type == "aura" and trigger.unit == "nameplate")
  end
  if hasNameplateAuraTrigger then
    Anchors.ApplyNameplateAnchor(
      aura.position,
      Anchors.GetNameplateAnchor(aura.position)
    )
  end
  if aura.triggerOp ~= "AND" and aura.triggerOp ~= "OR" then
    aura.triggerOp = "AND"
  end

  if aura.kind == "text" then
    aura.display.icon = false
    aura.display.showTimer = false
    aura.display.showStacks = false
    aura.display.showBackground = false
  elseif aura.kind == "interrupt_tracker" then
    aura.display.showStacks = false
  elseif aura.kind == "aura_bar_list" then
    aura.display.iconCooldownEdge = false
    aura.display.iconCooldownBling = false
    aura.display.hideCDMIcon = false
    if aura.display.permanentAlpha == nil then
      aura.display.permanentAlpha = 0.25
    end
  elseif aura.kind == "group" or aura.kind == "dynamic_group" then
    aura.display.icon = false
  end

  return aura
end

Defaults.baseCondition = {
  type = "threshold",
  operator = "<=",
  value = 5,
  action = "color",
  color = { r = 1, g = 0.2, b = 0.2, a = 1 },
}

function Defaults:NewAura(kind, triggerType)
  if kind == "private_aura_frame" then
    kind = "group"
    triggerType = nil
  end
  local removedPrivateAuraTrigger = triggerType == "private_aura"
  if removedPrivateAuraTrigger then
    triggerType = "simple"
  end

  local id = string.format("pa_%d_%d", time(), math.random(1000, 9999))
  local defaultName = kind == "bar" and "New Bar"
    or kind == "icon" and "New Icon"
    or kind == "aura_bar_list" and "Buffs and Debuffs"
    or (kind == "text" and triggerType == "death_alert") and "Death Alert"
    or kind == "text" and "New Text"
    or kind == "dynamic_group" and "New Dynamic Group"
    or kind == "interrupt_tracker" and "New Interrupt Tracker"
    or "New Group"
  local aura = {
    id = id,
    name = defaultName,
    kind = kind,
    parentId = nil,
    children = {},
    load = Tables.DeepCopy(self.load),
    triggers = { Tables.DeepCopy(self.baseTrigger) },
    triggerOp = "AND",
    conditions = {},
    display = Tables.DeepCopy(self.display),
    position = Tables.DeepCopy(self.position),
    text = Tables.DeepCopy(self.text),
    interrupt = kind == "interrupt_tracker" and Tables.DeepCopy(self.interruptTracker) or nil,
    enabled = true,
  }

  if triggerType then
    aura.triggers[1].type = triggerType
    if triggerType == "aura" then
      aura.triggers[1].unit = "player"
      aura.triggers[1].auraType = "buff"
      aura.triggers[1].auraFilter = "present"
      aura.triggers[1].groupRange = "any"
      aura.triggers[1].castByMe = false
      aura.triggers[1].aliveOnly = false
      aura.triggers[1].ignoreNPCs = false
      aura.triggers[1].spellId = 0
    elseif triggerType == "spell_cooldown" then
      aura.triggers[1].spellId = 0
      aura.triggers[1].cooldownMatch = "cooldown"
      aura.triggers[1].showAlways = false
      aura.triggers[1].manualCooldown = 0
      aura.triggers[1].showChargeCooldown = true
    elseif triggerType == "item_cooldown" then
      aura.triggers[1].itemId = 0
      aura.triggers[1].cooldownMatch = "cooldown"
      aura.triggers[1].showAlways = false
    elseif triggerType == "trinket_cooldown" then
      aura.triggers[1].trinketTop = true
      aura.triggers[1].trinketBottom = true
      aura.triggers[1].glowWhileActive = false
      aura.triggers[1].trinketGrowth = "DOWN"
      aura.triggers[1].ignoredTrinkets = ""
      aura.triggers[1].cooldownMatch = "cooldown"
      aura.triggers[1].showAlways = false
    elseif triggerType == "cast" then
      aura.triggers[1].unit = "player"
    elseif triggerType == "spell_cast_event" then
      aura.triggers[1].unit = "player"
      aura.triggers[1].spellId = 0
      aura.triggers[1].castEventDuration = 1
    elseif triggerType == "death_alert" then
      aura.triggers[1].alertDuration = 2
      aura.triggers[1].maxAlertsPerCombat = 7
      aura.triggers[1].showTank = true
      aura.triggers[1].showHealer = true
      aura.triggers[1].showDPS = true
      aura.triggers[1].soundTank = "None"
      aura.triggers[1].soundHealer = "None"
      aura.triggers[1].soundDPS = "None"
    elseif triggerType == "aura_list" then
      aura.triggers[1].unit = "player"
      aura.triggers[1].auraType = "buff"
      aura.triggers[1].auraListSortMode = "longest_first"
      aura.triggers[1].auraListMaxDuration = 0
      aura.triggers[1].auraListMaxRows = 0
      aura.triggers[1].hideBlizzardBuffs = false
      aura.triggers[1].hideBlizzardDebuffs = false
    end

    if removedPrivateAuraTrigger then
      aura.triggers[1].mode = "never"
    end
  end

  if kind == "icon" then
    aura.position.width = 56
    aura.position.height = 56
    aura.display.width = 56
    aura.display.height = 56
  elseif kind == "text" then
    aura.display.icon = false
    aura.display.showBackground = false
    aura.display.showName = true
    aura.display.showTimer = false
    aura.display.showStacks = false
    aura.display.width = 360
    aura.display.height = 48
    aura.display.nameAnchor = "CENTER"
    aura.display.nameOffsetX = 0
    aura.display.nameOffsetY = 0
    aura.display.nameFontStyle = "FRIZQT_THICK"
    aura.display.nameFontSize = 28
    aura.position.width = 360
    aura.position.height = 48
    aura.position.x = 0
    aura.position.y = 180
    aura.text.label = triggerType == "death_alert" and "%n dead" or "%n"
  elseif kind == "interrupt_tracker" then
    aura.triggers = {}
    aura.display.icon = true
    aura.display.showName = true
    aura.display.showTimer = true
    aura.display.showStacks = false
    aura.display.width = 240
    aura.display.height = 34
    aura.display.spacing = 4
    aura.position.width = 240
    aura.position.height = 34
  elseif kind == "group" or kind == "dynamic_group" then
    aura.triggers = {}
    aura.display.icon = false
    aura.position.width = 260
    aura.position.height = 40
  elseif kind == "aura_bar_list" then
    aura.display.icon = true
    aura.display.showName = true
    aura.display.showTimer = true
    aura.display.showStacks = true
    aura.display.width = 220
    aura.display.height = 24
    aura.display.spacing = 0
    aura.display.growth = "DOWN"
    aura.display.iconMatchBarSize = true
    aura.display.backgroundGamma = 1
    aura.display.permanentAlpha = 0.25
    aura.position.width = 220
    aura.position.height = 24
    aura.triggers[1].type = "aura_list"
    aura.triggers[1].unit = "player"
    aura.triggers[1].auraType = "buff"
    aura.triggers[1].auraListSortMode = "longest_first"
    aura.triggers[1].auraListMaxDuration = 0
    aura.triggers[1].auraListMaxRows = 0
    aura.triggers[1].hideBlizzardBuffs = false
    aura.triggers[1].hideBlizzardDebuffs = false
  elseif kind == "bar" then
    aura.display.stacksAnchor = "ICON"
    aura.display.stacksOffsetX = 0
    aura.display.stacksOffsetY = 0
  end

  return aura
end
