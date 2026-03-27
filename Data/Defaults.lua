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
  iconSize = 32,
  iconMatchBarSize = true,
  iconAnchor = "LEFT",
  iconOffsetX = 0,
  iconOffsetY = 0,
  swipe = true,
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
}

Defaults.load = {
  classes = {},
  specs = {},
  talent = false,
  talents = {},
  level = 0,
  combat = "any",
  equippedItemId = 0,
  instanceType = "",
  encounterId = 0,
  visibility = {
    dungeon = true,
    raid = false,
    open_world = true,
    solo = true,
    arena = false,
    battleground = false,
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

Defaults.baseTrigger = {
  type = "simple",
  enabled = true,
  mode = "always",
}

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
      aura.triggers[1].aliveOnly = false
      aura.triggers[1].ignoreNPCs = false
      aura.triggers[1].spellId = 0
    elseif triggerType == "spell_cooldown" then
      aura.triggers[1].spellId = 0
      aura.triggers[1].showAlways = true
      aura.triggers[1].manualCooldown = 0
      aura.triggers[1].showChargeCooldown = true
    elseif triggerType == "item_cooldown" then
      aura.triggers[1].itemId = 0
      aura.triggers[1].showAlways = true
    elseif triggerType == "cast" then
      aura.triggers[1].unit = "player"
    end
  end

  if kind == "icon" then
    aura.position.width = 56
    aura.position.height = 56
    aura.display.width = 56
    aura.display.height = 56
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
