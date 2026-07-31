local _, ns = ...

local Safe = ns.SafeValues
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts
local Anchors = ns.util.Anchors

local Region = {}
ns.renderers.NameplateAuraRegion = Region

local GROUP_KEY = "popauras"
-- Exact spell-ID filters are intentionally ignored by Blizzard for helpful
-- auras on non-assistable units. An empty dispel-type allowlist is the native,
-- non-identity filter that reliably rejects every hostile helpful aura.
local EMPTY_CANDIDATE_FILTERS = { includeDispelTypes = {} }
local timerFormatters = {}

local CATEGORY_FIELDS = {
  "nameplateStealable",
  "nameplateMagic",
  "nameplateBossAura",
  "nameplatePriorityAura",
}

local VALID_POINTS = {
  TOPLEFT = true, TOP = true, TOPRIGHT = true,
  LEFT = true, CENTER = true, RIGHT = true,
  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function DescribeError(value, fallback)
  if value == nil or Safe:IsSecret(value) then
    return fallback
  end
  return tostring(value)
end

local function GetTimerFormatter(decimals)
  decimals = math.max(0, math.min(2, tonumber(decimals or 1) or 1))
  if timerFormatters[decimals] then
    return timerFormatters[decimals]
  end
  if not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter then
    return nil
  end

  local nearest = Enum and Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Nearest or 0
  local down = Enum and Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Down or 2
  local step = 10 ^ (-decimals)
  local formatter = C_StringUtil.CreateNumericRuleFormatter()
  formatter:SetBreakpoints({
    { threshold = 0, step = step, rounding = nearest, format = "%." .. decimals .. "f" },
    {
      threshold = 60,
      format = "%." .. decimals .. "fm",
      components = { { div = 60, step = step, rounding = nearest } },
    },
    {
      threshold = 3600,
      format = "%dh %dm",
      components = {
        { div = 3600, step = 1, rounding = down },
        { div = 60, mod = 60, step = 1, rounding = down },
      },
    },
  })
  timerFormatters[decimals] = formatter
  return formatter
end

local function FindNameplateTrigger(aura)
  if not aura or aura.kind ~= "icon" or type(aura.triggers) ~= "table" then
    return nil
  end

  local enabledCount = 0
  local match
  for _, trigger in ipairs(aura.triggers) do
    if type(trigger) == "table" and trigger.enabled ~= false then
      enabledCount = enabledCount + 1
      if trigger.type == "aura"
          and trigger.unit == "nameplate"
          and trigger.auraType ~= "debuff"
          and trigger.auraFilter ~= "missing" then
        match = trigger
      end
    end
  end

  return enabledCount == 1 and match or nil
end

function Region:CanHandle(aura)
  return FindNameplateTrigger(aura) ~= nil
end

function Region:IsFeatureEnabled()
  return ns.Features and ns.Features:IsEnabled("feature_nameplate_buffs") == true
end

local function HasCategoryFilter(trigger)
  for _, field in ipairs(CATEGORY_FIELDS) do
    if trigger[field] == true then
      return true
    end
  end
  return false
end

local function BuildCandidateFilters(trigger)
  if trigger.nameplateAllBuffs == true then
    return {}
  end
  if not HasCategoryFilter(trigger) then
    -- An empty category selection must fail closed. An empty candidate table
    -- would mean every helpful aura.
    return EMPTY_CANDIDATE_FILTERS
  end

  local filters = {}
  if trigger.nameplateStealable == true then filters.isStealable = true end
  if trigger.nameplateMagic == true then filters.includeDispelTypes = { Magic = true } end
  if trigger.nameplateBossAura == true then filters.isBossAura = true end
  if trigger.nameplatePriorityAura == true then filters.isPriorityAura = true end
  return filters
end

local function ColorSignature(color)
  color = color or {}
  return table.concat({
    tostring(color.r), tostring(color.g), tostring(color.b), tostring(color.a),
  }, ",")
end

local function BuildSignature(aura, trigger)
  local display = aura.display or {}
  local position = aura.position or {}
  local values = {}
  local function Add(value)
    values[#values + 1] = tostring(value)
  end
  Add(trigger.nameplateAllBuffs)
  Add(trigger.nameplateStealable)
  Add(trigger.nameplateMagic)
  Add(trigger.nameplateBossAura)
  Add(trigger.nameplatePriorityAura)
  Add(trigger.nameplateMaxAuras)
  Add(display.width)
  Add(display.height)
  Add(display.spacing)
  Add(display.growth)
  Add(display.alpha)
  Add(display.showBackground)
  Add(ColorSignature(display.backgroundColor))
  Add(display.icon)
  Add(display.desaturate)
  Add(display.swipe)
  Add(display.reverse)
  Add(display.iconCooldownEdge)
  Add(display.iconCooldownBling)
  Add(ColorSignature(display.iconSwipeColor))
  Add(display.showName)
  Add(display.nameFontStyle)
  Add(display.nameFontSize)
  Add(display.nameAnchor)
  Add(display.nameOffsetX)
  Add(display.nameOffsetY)
  Add(display.nameRotation)
  Add(ColorSignature(display.nameColor))
  Add(display.showTimer)
  Add(display.timerFontStyle)
  Add(display.timerFontSize)
  Add(display.timerAnchor)
  Add(display.timerOffsetX)
  Add(display.timerOffsetY)
  Add(display.timerRotation)
  Add(display.timerDecimals)
  Add(ColorSignature(display.timerColor))
  Add(display.showStacks)
  Add(display.stacksFontStyle)
  Add(display.stacksFontSize)
  Add(display.stacksAnchor)
  Add(display.stacksOffsetX)
  Add(display.stacksOffsetY)
  Add(display.stacksRotation)
  Add(ColorSignature(display.stacksColor))
  Add(display.frameStrata)
  Add(display.frameLevel)
  Add(Anchors.GetNameplateAnchor(position))
  Add(position.x)
  Add(position.y)
  return table.concat(values, "|")
end

local function PositionText(fontString, owner, anchor, x, y)
  local point = VALID_POINTS[anchor] and anchor or "CENTER"
  fontString:ClearAllPoints()
  fontString:SetPoint(point, owner, point, tonumber(x or 0) or 0, tonumber(y or 0) or 0)
end

local function ApplyRotation(fontString, degrees)
  if fontString.SetRotation then
    fontString:SetRotation(math.rad(tonumber(degrees or 0) or 0))
  end
end

local function StyleNativeButton(button, aura)
  local display = aura.display or {}
  local width = math.max(1, tonumber(display.width or 26) or 26)
  local height = math.max(1, tonumber(display.height or 26) or 26)
  button:SetSize(width, height)
  button:EnableMouse(false)

  button.background = button:CreateTexture(nil, "BACKGROUND")
  button.background:SetAllPoints()
  button.background:SetTexture("Interface\\Buttons\\WHITE8x8")
  local backgroundColor = display.backgroundColor or { r = 0, g = 0, b = 0, a = 0.65 }
  button.background:SetVertexColor(
    backgroundColor.r or 0,
    backgroundColor.g or 0,
    backgroundColor.b or 0,
    backgroundColor.a == nil and 0.65 or backgroundColor.a)
  button.background:SetShown(display.showBackground ~= false)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  button.icon:SetDesaturated(display.desaturate == true)
  button.icon:SetShown(display.icon ~= false)

  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints()
  button.cooldown:EnableMouse(false)
  if button.cooldown.SetHideCountdownNumbers then button.cooldown:SetHideCountdownNumbers(true) end
  if button.cooldown.SetDrawSwipe then button.cooldown:SetDrawSwipe(display.swipe == true) end
  if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(display.iconCooldownEdge == true) end
  if button.cooldown.SetDrawBling then button.cooldown:SetDrawBling(display.iconCooldownBling == true) end
  if button.cooldown.SetReverse then button.cooldown:SetReverse(display.reverse == true) end
  local swipeColor = display.iconSwipeColor or { r = 0, g = 0, b = 0, a = 0.60 }
  if button.cooldown.SetSwipeColor then
    button.cooldown:SetSwipeColor(
      swipeColor.r or 0, swipeColor.g or 0, swipeColor.b or 0,
      swipeColor.a == nil and 0.60 or swipeColor.a)
  end
  button.cooldown:SetShown(display.swipe == true)

  button.presentation = CreateFrame("Frame", nil, button)
  button.presentation:SetAllPoints()
  button.presentation:SetFrameLevel(button:GetFrameLevel() + 10)
  button.nameText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.timerText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.countText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  Fonts.ApplyStyle(button.nameText, display.nameFontStyle, display.nameFontSize)
  Fonts.ApplyStyle(button.timerText, display.timerFontStyle, display.timerFontSize)
  Fonts.ApplyStyle(button.countText, display.stacksFontStyle, display.stacksFontSize)
  Colors.Apply(button.nameText, display.nameColor or { r = 1, g = 1, b = 1, a = 1 })
  Colors.Apply(button.timerText, display.timerColor or { r = 1, g = 1, b = 1, a = 1 })
  Colors.Apply(button.countText, display.stacksColor or { r = 1, g = 1, b = 1, a = 1 })
  PositionText(button.nameText, button.presentation, display.nameAnchor, display.nameOffsetX, display.nameOffsetY)
  PositionText(button.timerText, button.presentation, display.timerAnchor, display.timerOffsetX, display.timerOffsetY)
  PositionText(button.countText, button.presentation, display.stacksAnchor, display.stacksOffsetX, display.stacksOffsetY)
  ApplyRotation(button.nameText, display.nameRotation)
  ApplyRotation(button.timerText, display.timerRotation)
  ApplyRotation(button.countText, display.stacksRotation)
  button.nameText:SetShown(display.showName == true)
  button.timerText:SetShown(display.showTimer == true)
  button.countText:SetShown(display.showStacks == true)

  button:SetIcon(button.icon)
  button:SetSpellName(button.nameText)
  button:SetApplicationCount(button.countText)
  button:SetDurationCooldown(button.cooldown)
  button:SetDurationText(button.timerText, {
    formatter = GetTimerFormatter(display.timerDecimals),
    expiredText = "",
    zeroDurationText = "",
  })
end

local function GetFlowDirection(name, fallback)
  local directions = AnchorUtil and AnchorUtil.FlowDirection or nil
  return directions and directions[name] or fallback
end

local function ApplyContainerLayout(container, aura, plate)
  local requiredMethods = {
    "SetFlowLayoutAnchorPoint",
    "SetFlowLayoutGrowthDirection",
    "SetFlowLayoutMaximumLineSize",
    "SetAuraGroupLayout",
  }
  for _, methodName in ipairs(requiredMethods) do
    if type(container[methodName]) ~= "function" then
      return false, methodName .. " is unavailable"
    end
  end

  local display = aura.display or {}
  local position = aura.position or {}
  local growth = display.growth
  if growth ~= "UP" and growth ~= "DOWN" and growth ~= "LEFT" then
    growth = "RIGHT"
  end
  local width = math.max(1, tonumber(display.width or 26) or 26)
  local height = math.max(1, tonumber(display.height or 26) or 26)
  local spacing = math.max(0, tonumber(display.spacing or 3) or 3)
  local point, relativePoint = Anchors.ResolveNameplatePoints(position)
  local horizontal = growth == "LEFT"
    and GetFlowDirection("Left", -1)
    or GetFlowDirection("Right", 1)
  local vertical = growth == "UP"
    and GetFlowDirection("Up", 1)
    or GetFlowDirection("Down", -1)
  local isVertical = growth == "UP" or growth == "DOWN"

  local ok, reason = pcall(function()
    container:ClearAllPoints()
    container:SetPoint(point, plate, relativePoint,
      tonumber(position.x or 0) or 0, tonumber(position.y or 0) or 0)
    container:SetFlowLayoutAnchorPoint(point)
    container:SetFlowLayoutGrowthDirection(horizontal, vertical)
    container:SetFlowLayoutMaximumLineSize(isVertical and width or math.huge)
    container:SetAuraGroupLayout(GROUP_KEY, {
      elementSpacing = spacing,
      lineSpacing = spacing,
      elementSpacingX = spacing,
      elementSpacingY = spacing,
      elementWidth = width,
      elementHeight = height,
    })
  end)
  if not ok then
    return false, DescribeError(reason, "Native nameplate aura layout failed")
  end
  return true
end

local function UnitExistsSafe(unit)
  local ok, value = pcall(UnitExists, unit)
  return ok and Safe:Boolean(value) == true
end

local function IsHostileNPC(unit)
  if not UnitExistsSafe(unit) then
    return false
  end
  local attackOK, canAttack = pcall(UnitCanAttack, "player", unit)
  if not attackOK or Safe:Boolean(canAttack) ~= true then
    return false
  end
  local playerOK, isPlayer = pcall(UnitIsPlayer, unit)
  return playerOK and Safe:Boolean(isPlayer) == false
end

local function GetNameplate(unit)
  if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
    return nil
  end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or Safe:IsSecret(plate) then
    return nil
  end
  return plate
end

local function SetEntryEnabled(entry, enabled)
  if not entry or not entry.container or not entry.container.SetEnabled then
    return
  end
  enabled = enabled == true
  if entry.nativeEnabled ~= enabled then
    entry.container:SetEnabled(enabled)
    entry.nativeEnabled = enabled
  end
end

local function SuppressEntry(entry)
  if not entry or not entry.container then
    return
  end
  if entry.nativeSuppressed ~= true then
    -- Blizzard must securely clear assigned buttons while enabled. Once that
    -- is complete the container can stop listening for this unit.
    SetEntryEnabled(entry, true)
    entry.container:SetAuraGroupCandidateFilters(GROUP_KEY, EMPTY_CANDIDATE_FILTERS)
    entry.nativeSuppressed = true
  end
  SetEntryEnabled(entry, false)
  entry.unit = nil
end

local Manager = {
  activeRegions = {},
}

Manager.frame = CreateFrame("Frame")
Manager.frame:SetScript("OnEvent", function(_, event, unitValue)
  local unit = Safe:String(unitValue)
  if not unit then
    return
  end
  if event == "NAME_PLATE_UNIT_ADDED" then
    for region in pairs(Manager.activeRegions) do
      region:AttachUnit(unit)
    end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    for region in pairs(Manager.activeRegions) do
      region:DetachUnit(unit)
    end
  end
end)

function Manager:SyncRegion(region)
  for index = 1, 40 do
    local unit = "nameplate" .. index
    if UnitExistsSafe(unit) then
      region:AttachUnit(unit)
    end
  end
end

function Manager:Register(region)
  if self.activeRegions[region] then
    return
  end
  local wasEmpty = next(self.activeRegions) == nil
  self.activeRegions[region] = true
  if wasEmpty then
    self.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  end
  self:SyncRegion(region)
end

function Manager:Unregister(region)
  if not self.activeRegions[region] then
    region:DeactivateAll()
    return
  end
  self.activeRegions[region] = nil
  region:DeactivateAll()
  if next(self.activeRegions) == nil then
    self.frame:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    self.frame:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
  end
end

function Region:InitializeNativeButton(button)
  StyleNativeButton(button, self.currentAura)
end

function Region:CreateEntry(plate, unit)
  -- A Blizzard nameplate can be protected/forbidden. Creating the native
  -- template as its child makes the XML OnUpdate handler inherit that tainted
  -- execution context. Keep the container on PopAuras' public UIParent layer
  -- and only anchor it to the public nameplate frame.
  local container, createError = ns.NativeAuras:CreateContainer(UIParent)
  if not container then
    self.lastError = DescribeError(createError, "Native aura containers are unavailable")
    return nil
  end

  self.generation = (self.generation or 0) + 1
  if container.SetParentKey then
    local key = tostring(self.currentAura.id or "Aura"):gsub("[^%w_]", "_")
    container:SetParentKey(string.format("PopAurasNameplate_%s_%d", key, self.generation))
  end
  if container.SetClipsChildren then container:SetClipsChildren(false) end
  if container.SetEnabled then container:SetEnabled(false) end

  local display = self.currentAura.display or {}
  local baseLevel = 0
  if plate.GetFrameLevel then
    local ok, value = pcall(plate.GetFrameLevel, plate)
    baseLevel = ok and Safe:Number(value) or 0
  end
  container:SetFrameStrata(display.frameStrata or "HIGH")
  container:SetFrameLevel((baseLevel or 0) + math.max(1, tonumber(display.frameLevel or 10) or 10))
  container:SetAlpha(tonumber(display.alpha or 1) or 1)

  local trigger = FindNameplateTrigger(self.currentAura)
  local candidateFilters = BuildCandidateFilters(trigger)
  local maxFrameCount = math.max(1, math.min(8,
    math.floor(tonumber(trigger.nameplateMaxAuras or 3) or 3)))
  local sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.Default or 0
  local sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0
  local ok, reason = pcall(container.AddAuraGroup, container, GROUP_KEY, "HELPFUL", {
    maxFrameCount = maxFrameCount,
    initializeFrame = function(button) self:InitializeNativeButton(button) end,
    candidateFilters = candidateFilters,
    sortMethod = sortMethod,
    sortDirection = sortDirection,
    layout = {
      elementSpacing = tonumber(display.spacing or 3) or 3,
      lineSpacing = tonumber(display.spacing or 3) or 3,
      elementSpacingX = tonumber(display.spacing or 3) or 3,
      elementSpacingY = tonumber(display.spacing or 3) or 3,
      elementWidth = tonumber(display.width or 26) or 26,
      elementHeight = tonumber(display.height or 26) or 26,
    },
  })
  if not ok then
    if container.SetEnabled then container:SetEnabled(false) end
    self.lastError = DescribeError(reason, "The native nameplate aura group could not be created")
    return nil
  end

  local layoutOk, layoutReason = ApplyContainerLayout(container, self.currentAura, plate)
  if not layoutOk then
    if container.SetEnabled then container:SetEnabled(false) end
    self.lastError = DescribeError(layoutReason, "The native nameplate aura layout is unavailable")
    return nil
  end
  container:SetUnit(unit)
  return {
    container = container,
    plate = plate,
    unit = unit,
    candidateFilters = candidateFilters,
    nativeEnabled = false,
    nativeSuppressed = false,
  }
end

function Region:ActivateEntry(entry, unit)
  if entry.nativeSuppressed == true then
    entry.container:SetAuraGroupCandidateFilters(GROUP_KEY, entry.candidateFilters)
    entry.nativeSuppressed = false
  end
  entry.container:SetUnit(unit)
  entry.unit = unit
  SetEntryEnabled(entry, true)
end

function Region:AttachUnit(unit)
  if not self.active then
    return
  end
  if not IsHostileNPC(unit) then
    self:DetachUnit(unit)
    return
  end
  local plate = GetNameplate(unit)
  if not plate then
    self:DetachUnit(unit)
    return
  end

  local previous = self.entriesByUnit[unit]
  if previous and previous.plate ~= plate then
    self.entriesByUnit[unit] = nil
    SuppressEntry(previous)
  end

  local entry = self.entriesByPlate[plate]
  if entry and entry.unit and entry.unit ~= unit then
    self.entriesByUnit[entry.unit] = nil
    SuppressEntry(entry)
  end
  if not entry then
    entry = self:CreateEntry(plate, unit)
    if not entry then
      return
    end
    self.entriesByPlate[plate] = entry
  end

  self.entriesByUnit[unit] = entry
  self:ActivateEntry(entry, unit)
end

function Region:DetachUnit(unit)
  local entry = self.entriesByUnit[unit]
  if not entry then
    return
  end
  self.entriesByUnit[unit] = nil
  SuppressEntry(entry)
end

function Region:DeactivateAll()
  for unit in pairs(self.entriesByUnit) do
    self.entriesByUnit[unit] = nil
  end
  for _, entry in pairs(self.entriesByPlate) do
    SuppressEntry(entry)
  end
end

function Region:RetireEntries()
  self:DeactivateAll()
  self.retiredEntries = self.retiredEntries or {}
  for _, entry in pairs(self.entriesByPlate) do
    self.retiredEntries[#self.retiredEntries + 1] = entry
  end
  self.entriesByPlate = {}
  self.entriesByUnit = {}
end

function Region:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.isNameplateAuraRegion = true
  instance.layoutVisible = false
  instance.currentAura = aura
  instance.entriesByPlate = {}
  instance.entriesByUnit = {}
  instance.retiredEntries = {}
  instance.active = false
  instance.generation = 0
  return instance
end

function Region:Update(aura, state)
  if not self:IsFeatureEnabled() then
    self:Release()
    return
  end

  local trigger = FindNameplateTrigger(aura)
  if not trigger then
    Manager:Unregister(self)
    self.active = false
    return
  end

  self.currentAura = aura
  self.layoutVisible = false
  local signature = BuildSignature(aura, trigger)
  local signatureChanged = self.signature and self.signature ~= signature
  if signatureChanged then
    self:RetireEntries()
  end
  self.signature = signature

  local shouldActivate = state and state.loadMatched == true and state.source ~= "preview"
  self.active = shouldActivate == true
  if self.active then
    local wasRegistered = Manager.activeRegions[self] == true
    Manager:Register(self)
    if wasRegistered and signatureChanged then
      Manager:SyncRegion(self)
    end
  else
    Manager:Unregister(self)
  end
end

function Region:Release()
  self.active = false
  self.layoutVisible = false
  Manager:Unregister(self)
  self:RetireEntries()
end
