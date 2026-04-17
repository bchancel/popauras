local _, ns = ...

local Tables = ns.util.Tables

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
  readyLook = false,
  readyColor = { r = 0.16, g = 0.72, b = 0.26, a = 1 },
  barTexture = "FLAT",
  backgroundColor = { r = 0, g = 0, b = 0, a = 0.45 },
  showBackground = true,
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
  soundEnabled = false,
  soundMode = "activate",
  soundFile = "None",
  soundChannel = "Master",
  desaturate = false,
  glow = false,
  glowWhenActive = false,
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
  sortOrder = "CD_ASC",
  barAlpha = 0.88,
  showFailedKick = true,
  showBarBackground = true,
  barBackgroundColor = { r = 0.09, g = 0.11, b = 0.16, a = 0.94 },
  readyBarAlpha = 0.40,
  paddingX = 6,
  paddingY = 3,
  displayInterruptName = true,
  clickToAnnounce = true,
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
  if triggerType == "aura" then
    trigger.unit = trigger.unit or "player"
    trigger.auraType = trigger.auraType or "buff"
    trigger.auraFilter = trigger.auraFilter or "present"
    trigger.groupRange = trigger.groupRange or "any"
    if trigger.aliveOnly == nil then
      trigger.aliveOnly = false
    end
    if trigger.ignoreNPCs == nil then
      trigger.ignoreNPCs = false
    end
    trigger.spellId = tonumber(trigger.spellId or 0) or 0
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
  elseif triggerType == "cast" then
    trigger.unit = trigger.unit or "player"
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

function Defaults:ApplyAuraDefaults(aura)
  if type(aura) ~= "table" then
    return aura
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
  aura.display = Tables.MergeDefaults(type(aura.display) == "table" and aura.display or {}, self.display)
  aura.position = Tables.MergeDefaults(type(aura.position) == "table" and aura.position or {}, self.position)
  aura.text = Tables.MergeDefaults(type(aura.text) == "table" and aura.text or {}, self.text)
  aura.conditions = type(aura.conditions) == "table" and aura.conditions or {}
  aura.actions = type(aura.actions) == "table" and aura.actions or {}
  aura.children = type(aura.children) == "table" and aura.children or {}
  aura.enabled = aura.enabled ~= false

  if aura.kind == "interrupt_tracker" then
    aura.interrupt = Tables.MergeDefaults(type(aura.interrupt) == "table" and aura.interrupt or {}, self.interruptTracker)
  end

  if type(aura.triggers) ~= "table" then
    aura.triggers = {}
  end
  if aura.kind ~= "interrupt_tracker" and aura.kind ~= "group" and aura.kind ~= "dynamic_group" and #aura.triggers == 0 then
    aura.triggers[1] = Tables.DeepCopy(self.baseTrigger)
  end
  for _, trigger in ipairs(aura.triggers) do
    self:ApplyTriggerDefaults(trigger)
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
  local id = string.format("pa_%d_%d", time(), math.random(1000, 9999))
  local defaultName = kind == "bar" and "New Bar"
    or kind == "icon" and "New Icon"
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
    elseif triggerType == "cast" then
      aura.triggers[1].unit = "player"
    elseif triggerType == "death_alert" then
      aura.triggers[1].alertDuration = 2
      aura.triggers[1].maxAlertsPerCombat = 7
      aura.triggers[1].showTank = true
      aura.triggers[1].showHealer = true
      aura.triggers[1].showDPS = true
      aura.triggers[1].soundTank = "None"
      aura.triggers[1].soundHealer = "None"
      aura.triggers[1].soundDPS = "None"
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
  elseif kind == "bar" then
    aura.display.stacksAnchor = "ICON"
    aura.display.stacksOffsetX = 0
    aura.display.stacksOffsetY = 0
  end

  return aura
end
