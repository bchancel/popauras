local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts
local Frames = ns.util.Frames
local UnitAuraList = ns.util.UnitAuraList

local Region = {}
ns.renderers.AuraBarListRegion = Region
local timerFormatters = {}
local EMPTY_CANDIDATE_FILTERS = { includeSpellIDs = {} }

local function GetAuraListTimerFormatter(decimals)
  decimals = math.max(0, math.min(2, tonumber(decimals or 1) or 1))
  if timerFormatters[decimals] then return timerFormatters[decimals] end
  if not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter then return nil end
  local nearest = Enum and Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Nearest or 0
  local down = Enum and Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Down or 2
  local step = 10 ^ (-decimals)
  local formatter = C_StringUtil.CreateNumericRuleFormatter()
  formatter:SetBreakpoints({
    {
      threshold = 0,
      step = step,
      rounding = nearest,
      format = "%." .. decimals .. "f",
    },
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
    {
      threshold = 86400,
      format = "%dd %dh",
      components = {
        { div = 86400, step = 1, rounding = down },
        { div = 3600, mod = 24, step = 1, rounding = down },
      },
    },
  })
  timerFormatters[decimals] = formatter
  return formatter
end

local function GetTrigger(aura)
  return aura and type(aura.triggers) == "table" and aura.triggers[1] or {}
end

local function GetTexturePath(textureKey)
  local textures = {
    DEFAULT = "Interface\\Buttons\\WHITE8x8",
    FLAT = "Interface\\Buttons\\WHITE8x8",
    GLAZE = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar",
  }
  return textures[textureKey] or textureKey or textures.DEFAULT
end

local function PositionText(fontString, owner, icon, anchor, x, y)
  fontString:ClearAllPoints()
  if anchor == "ICON" and icon then
    fontString:SetPoint("CENTER", icon, "CENTER", x or 0, y or 0)
  else
    local point = anchor or "CENTER"
    fontString:SetPoint(point, owner, point, x or 0, y or 0)
  end
end

local function ApplyRotation(fontString, degrees)
  if fontString.SetRotation then fontString:SetRotation(math.rad(tonumber(degrees or 0) or 0)) end
end

local oppositePoints = {
  LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP",
  TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT",
  BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT", CENTER = "CENTER",
}

local function StyleButton(button, aura)
  local display = aura.display or {}
  local width = tonumber(display.width or aura.position and aura.position.width or 220) or 220
  local height = tonumber(display.height or aura.position and aura.position.height or 24) or 24
  local orientation = display.orientation or "HORIZONTAL"
  button:SetSize(width, height)
  Frames.SetExplicitBounds(button.bar, button, width, height)
  Frames.SetExplicitBounds(button.cooldown, button, width, height)
  Frames.SetExplicitBounds(button.presentation, button, width, height)

  button.bar:SetStatusBarTexture(GetTexturePath(display.barTexture))
  button.bar:SetOrientation(orientation)
  button.bar:SetStatusBarColor(
    display.color and display.color.r or 0.1,
    display.color and display.color.g or 0.6,
    display.color and display.color.b or 1,
    display.color and display.color.a or 1)
  button.background:SetShown(display.showBackground ~= false)
  button.background:SetVertexColor(
    display.backgroundColor and display.backgroundColor.r or 0,
    display.backgroundColor and display.backgroundColor.g or 0,
    display.backgroundColor and display.backgroundColor.b or 0,
    display.backgroundColor and display.backgroundColor.a or 0.45)

  local iconSize = display.iconMatchBarSize and (orientation == "VERTICAL" and width or height)
    or tonumber(display.iconSize or height) or height
  button.icon:SetSize(iconSize, iconSize)
  button.icon:ClearAllPoints()
  local anchor = display.iconAnchor or "LEFT"
  if anchor == "LEFT_OUTSIDE" then anchor = "LEFT" end
  if anchor == "RIGHT_OUTSIDE" then anchor = "RIGHT" end
  button.icon:SetPoint(oppositePoints[anchor] or "CENTER", button, anchor,
    tonumber(display.iconOffsetX or 0) or 0, tonumber(display.iconOffsetY or 0) or 0)
  button.icon:SetShown(display.icon ~= false)

  button.nameText:SetShown(display.showName == true)
  button.timerText:SetShown(display.showTimer == true)
  button.countText:SetShown(display.showStacks == true)
  Fonts.ApplyStyle(button.nameText, display.nameFontStyle, display.nameFontSize)
  Fonts.ApplyStyle(button.timerText, display.timerFontStyle, display.timerFontSize)
  Fonts.ApplyStyle(button.countText, display.stacksFontStyle, display.stacksFontSize)
  Colors.Apply(button.nameText, display.nameColor or { r = 1, g = 1, b = 1, a = 1 })
  Colors.Apply(button.timerText, display.timerColor or { r = 1, g = 1, b = 1, a = 1 })
  Colors.Apply(button.countText, display.stacksColor or { r = 1, g = 1, b = 1, a = 1 })
  PositionText(button.nameText, button.presentation, button.icon, display.nameAnchor, display.nameOffsetX, display.nameOffsetY)
  PositionText(button.timerText, button.presentation, button.icon, display.timerAnchor, display.timerOffsetX, display.timerOffsetY)
  PositionText(button.countText, button.presentation, button.icon, display.stacksAnchor, display.stacksOffsetX, display.stacksOffsetY)
  Frames.ConfigureBarTextBounds(button.nameText, button.timerText, button.presentation, display, width, orientation)
  ApplyRotation(button.nameText, display.nameRotation)
  ApplyRotation(button.timerText, display.timerRotation)
  ApplyRotation(button.countText, display.stacksRotation)

  -- Keep the duration host available even when the radial swipe is disabled.
  -- Blizzard owns its shown state after SetDurationCooldown binds it, which
  -- lets the child background exist for timed auras but disappear entirely
  -- for zero/infinite-duration auras without addon-side duration inspection.
  if button.cooldown.SetDrawSwipe then button.cooldown:SetDrawSwipe(display.swipe == true) end
  if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(display.iconCooldownEdge == true) end
  if button.cooldown.SetDrawBling then button.cooldown:SetDrawBling(display.iconCooldownBling == true) end

  local direction = Enum and Enum.StatusBarTimerDirection and (
    display.reverse == true and Enum.StatusBarTimerDirection.ElapsedTime
      or Enum.StatusBarTimerDirection.RemainingTime) or nil
  local interpolation = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or nil
  button:SetDurationBar(button.bar, { direction = direction, interpolation = interpolation })
  button:SetIcon(button.icon)
  button:SetSpellName(button.nameText)
  button:SetApplicationCount(button.countText)
  button:SetDurationCooldown(button.cooldown)
  button:SetDurationText(button.timerText, {
    formatter = GetAuraListTimerFormatter(display.timerDecimals),
    expiredText = "",
    zeroDurationText = "",
  })
end

function Region:InitializeNativeButton(button)
  button.bar = CreateFrame("StatusBar", nil, button)
  button.bar:SetAllPoints()

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints()
  button.cooldown:EnableMouse(false)
  button.cooldown:SetFrameLevel(button:GetFrameLevel())
  button.background = button.cooldown:CreateTexture(nil, "BACKGROUND", nil, -8)
  button.background:SetAllPoints()
  button.background:SetTexture("Interface\\Buttons\\WHITE8x8")
  button.bar:SetFrameLevel(button:GetFrameLevel() + 1)
  if button.cooldown.SetHideCountdownNumbers then
    button.cooldown:SetHideCountdownNumbers(true)
  end

  button.presentation = CreateFrame("Frame", nil, button)
  button.presentation:SetFrameLevel(button:GetFrameLevel() + 10)
  button.nameText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.timerText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.countText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button:SetCancelAuraButtons("RightButtonUp")
  StyleButton(button, self.currentAura)
end

local function NativeSignature(options)
  local filters = options.candidateFilters or {}
  return string.format("%s|%s|maxDuration=%s",
    tostring(options.unit),
    tostring(options.filterString),
    tostring(filters.maxDuration))
end

local function PresentationStyleSignature(display)
  return tostring(display and display.swipe == true)
end

local function LayoutSignature(display)
  display = display or {}
  return string.format("%s|%s|%s|%s", tostring(display.growth or "DOWN"),
    tostring(tonumber(display.spacing or 0) or 0),
    tostring(tonumber(display.width or 220) or 220),
    tostring(tonumber(display.height or 24) or 24))
end

local function GetExpirationSort(trigger)
  local methods = AuraContainerSortMethod or {}
  local directions = AuraContainerSortDirection or {}
  local sortMethod = methods.ExpirationOnly or methods.Expiration or 0
  local sortMode = UnitAuraList:GetSortMode(trigger)
  -- Both modes are Blizzard-owned. Normal retains the earliest timed auras
  -- before maxFrameCount is applied; Reverse restores permanent/longest-first
  -- ordering for player-buff lists.
  local sortDirection = sortMode == "longest_first"
    and (directions.Reverse or 1)
    or (directions.Normal or 0)
  return sortMethod, sortDirection
end

function Region:CreateNativeContainer(aura, options)
  local container, createError
  if ns.NativeAuras then
    container, createError = ns.NativeAuras:CreateContainer(self.frame)
  end
  if not container then
    return nil, createError or "Native aura containers are unavailable"
  end
  if container.SetParentKey then container:SetParentKey("AuraListContainer") end
  if container.SetEnabled then container:SetEnabled(false) end
  self.nativeEnabled = false
  self.nativeSuppressed = false
  container:SetPoint("TOPLEFT", self.frame, "TOPLEFT")
  self.container = container
  self.currentAura = aura

  local display = aura.display or {}
  local sortMethod, sortDirection = GetExpirationSort(GetTrigger(aura))
  local groupOptions = {
    maxFrameCount = tonumber(options.maxFrameCount or display.maxAuras or 40) or 40,
    initializeFrame = function(button) self:InitializeNativeButton(button) end,
    candidateFilters = options.candidateFilters,
    sortMethod = sortMethod,
    sortDirection = sortDirection,
    layout = {
      -- 12.1.0 RC renamed the axis-specific spacing fields to primary-axis
      -- spacing. Supplying both generations is safe; each client validates
      -- and consumes the fields it understands.
      elementSpacing = tonumber(display.spacing or 0) or 0,
      lineSpacing = tonumber(display.spacing or 0) or 0,
      elementSpacingX = tonumber(display.spacing or 0) or 0,
      elementSpacingY = tonumber(display.spacing or 0) or 0,
      elementWidth = tonumber(display.width or 220) or 220,
      elementHeight = tonumber(display.height or 24) or 24,
    },
  }

  local ok, reason = pcall(container.AddAuraGroup, container, "popauras", options.filterString, groupOptions)
  if not ok then
    if container.SetEnabled then container:SetEnabled(false) end
    self.container = nil
    return nil, reason
  end
  self:ApplyContainerLayout(aura)
  container:SetUnit(options.unit)
  self.nativeUnit = options.unit
  self.nativeFilterString = options.filterString
  self.containerSignature = NativeSignature(options)
  self.nativeCandidateSignature = self.containerSignature
  self.nativeMaxFrameCount = groupOptions.maxFrameCount
  self.sortSignature = string.format("%s|%s", tostring(sortMethod), tostring(sortDirection))
  self.presentationStyleSignature = PresentationStyleSignature(display)
  return container
end

local function GetFlowDirection(name, fallback)
  local directions = AnchorUtil and AnchorUtil.FlowDirection or nil
  return directions and directions[name] or fallback
end

local function GetFlowLayoutAxis(name, fallback)
  local axes = AnchorUtil and AnchorUtil.FlowLayoutAxis or nil
  return axes and axes[name] or fallback
end

function Region:ApplyContainerLayout(aura)
  local container = self.container
  if not container then return end
  local display = aura.display or {}
  local growth = display.growth or "DOWN"
  local width = tonumber(display.width or 220) or 220
  local spacing = tonumber(display.spacing or 0) or 0
  local right = GetFlowDirection("Right", 1)
  local left = GetFlowDirection("Left", -1)
  local down = GetFlowDirection("Down", -1)
  local up = GetFlowDirection("Up", 1)
  local horizontal = growth == "LEFT" and left or right
  local vertical = growth == "UP" and up or down
  local anchor = growth == "LEFT" and "TOPRIGHT" or growth == "UP" and "BOTTOMLEFT" or "TOPLEFT"
  container:ClearAllPoints()
  container:SetPoint(anchor, self.frame, anchor)

  local isVertical = growth == "UP" or growth == "DOWN"
  if type(container.SetFlowLayoutAxis) == "function" then
    -- Build 68914 made the primary axis explicit and renamed the container
    -- layout API. An unlimited vertical line is the requested single column.
    container:SetFlowLayoutAxis(GetFlowLayoutAxis(isVertical and "Vertical" or "Horizontal",
      isVertical and 1 or 0))
    if type(container.SetFlowLayoutAnchorPoint) == "function" then
      container:SetFlowLayoutAnchorPoint(anchor)
    end
    if type(container.SetFlowLayoutGrowthDirection) == "function" then
      container:SetFlowLayoutGrowthDirection(horizontal, vertical)
    end
    if type(container.SetFlowLayoutMaximumLineSize) == "function" then
      container:SetFlowLayoutMaximumLineSize(nil)
    end
  else
    -- PTR builds before 68914 used a horizontal primary axis. Restricting the
    -- row to one bar width makes Up/Down wrap into a single column.
    if type(container.SetAuraLayoutAnchorPoint) == "function" then
      container:SetAuraLayoutAnchorPoint(anchor)
    end
    if type(container.SetAuraLayoutGrowthDirection) == "function" then
      container:SetAuraLayoutGrowthDirection(horizontal, vertical)
    end
    if type(container.SetAuraLayoutRowWidth) == "function" then
      container:SetAuraLayoutRowWidth(isVertical and width or math.huge)
    end
  end
  if type(container.SetAuraGroupLayout) == "function" then
    container:SetAuraGroupLayout("popauras", {
      elementSpacing = spacing,
      lineSpacing = spacing,
      elementSpacingX = spacing,
      elementSpacingY = spacing,
      elementWidth = width,
      elementHeight = tonumber(display.height or 24) or 24,
    })
  end
  self.layoutSignature = LayoutSignature(display)
end

function Region:EnsurePreviewRows()
  if self.previewRows then return end
  self.previewRows = {}
  for index = 1, 3 do
    local row = CreateFrame("StatusBar", nil, self.frame)
    row:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.timerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.previewRows[index] = row
  end
end

function Region:ShowPreview(aura)
  self:EnsurePreviewRows()
  local names = { "Power Word: Fortitude", "Renew", "Weakened Soul" }
  local icons = { 135987, 135953, 136214 }
  local display = aura.display or {}
  local growth = display.growth or "DOWN"
  local spacing = tonumber(display.spacing or 0) or 0
  local width, height = tonumber(display.width or 220) or 220, tonumber(display.height or 24) or 24
  local previous
  for index, row in ipairs(self.previewRows) do
    row:ClearAllPoints()
    row:SetSize(width, height)
    if not previous then row:SetAllPoints(self.frame)
    elseif growth == "UP" then row:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, spacing)
    elseif growth == "LEFT" then row:SetPoint("TOPRIGHT", previous, "TOPLEFT", -spacing, 0)
    elseif growth == "RIGHT" then row:SetPoint("TOPLEFT", previous, "TOPRIGHT", spacing, 0)
    else row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing) end
    row:SetStatusBarColor(display.color.r, display.color.g, display.color.b, display.color.a or 1)
    row:SetMinMaxValues(0, 30)
    row:SetValue(31 - index * 7)
    row.icon:SetTexture(icons[index])
    row.icon:SetSize(height, height)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("RIGHT", row, "LEFT")
    row.nameText:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.nameText:SetText(names[index])
    row.timerText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.timerText:SetText(tostring(31 - index * 7))
    row.countText:SetPoint("CENTER", row.icon, "CENTER")
    row.countText:SetText(index == 2 and "2" or "")
    row:Show()
    previous = row
  end
end

function Region:HidePreview()
  for _, row in ipairs(self.previewRows or {}) do row:Hide() end
end

function Region:SetNativeEnabled(enabled)
  if not self.container or not self.container.SetEnabled then return end
  enabled = enabled == true
  if self.nativeEnabled ~= enabled then
    self.container:SetEnabled(enabled)
    self.nativeEnabled = enabled
  end
end

function Region:SetNativeSuppressed(suppressed, options)
  if not self.container then return end
  suppressed = suppressed == true
  if suppressed then
    if self.nativeSuppressed ~= true then
      -- Let Blizzard securely clear every assigned row before disabling the
      -- group. The row buttons may already be forbidden at this point.
      self:SetNativeEnabled(true)
      self.container:SetAuraGroupCandidateFilters("popauras", EMPTY_CANDIDATE_FILTERS)
      self.nativeSuppressed = true
    end
    self:SetNativeEnabled(false)
    return
  end

  if self.nativeSuppressed == true and options then
    self.container:SetAuraGroupCandidateFilters("popauras", options.candidateFilters)
    self.nativeCandidateSignature = NativeSignature(options)
    self.nativeSuppressed = false
  end
  self:SetNativeEnabled(true)
end

function Region:RetireNativeContainer()
  local container = self.container
  if not container then return end

  -- AuraButtons are initialized only once and may be forbidden after Blizzard
  -- assigns them. Clear the secure group before retiring its container rather
  -- than trying to restyle those buttons when a presentation option changes.
  self:SetNativeSuppressed(true)
  self.retiredContainers = self.retiredContainers or {}
  self.retiredContainers[#self.retiredContainers + 1] = container
  self.container = nil
  self.nativeEnabled = false
  self.nativeSuppressed = false
  self.nativeUnit = nil
  self.nativeFilterString = nil
  self.containerSignature = nil
  self.nativeCandidateSignature = nil
  self.nativeMaxFrameCount = nil
  self.sortSignature = nil
  self.layoutSignature = nil
  self.presentationStyleSignature = nil
end

function Region:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.frame:SetClipsChildren(false)
  instance.errorText = instance.frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  instance.errorText:SetAllPoints()
  instance.errorText:SetJustifyH("CENTER")
  return instance
end

function Region:Update(aura, state)
  self.currentAura = aura
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)
  self.frame:EnableMouse(BaseRegion:CanMove(aura))
  self.frame:SetAlpha((aura.display and aura.display.alpha) or 1)

  if state and state.source == "preview" then
    self.loadMatched = true
    self.layoutVisible = true
    self:SetNativeSuppressed(true)
    self.errorText:Hide()
    self:ShowPreview(aura)
    return
  end
  self:HidePreview()

  self.loadMatched = state and state.loadMatched == true
  if not self.loadMatched then
    -- RuntimeStore still renders an explicit hidden state when load conditions
    -- fail. Native AuraContainers are presentation authorities, so they must
    -- be securely cleared and disabled instead of ignoring that state.
    self.layoutVisible = false
    self.errorText:Hide()
    self:SetNativeSuppressed(true)
    return
  end
  self.layoutVisible = true

  local options = UnitAuraList:GetNativeOptions(GetTrigger(aura))
  local signature = NativeSignature(options)
  local inCombat = InCombatLockdown and InCombatLockdown() == true
  local buttonStyleSignature = PresentationStyleSignature(aura.display)
  if self.container and not inCombat
      and self.presentationStyleSignature ~= buttonStyleSignature then
    self:RetireNativeContainer()
  end
  if not self.container then
    local _, reason = self:CreateNativeContainer(aura, options)
    if not self.container then
      self.errorText:SetText("Native aura display unavailable: " .. tostring(reason or "unknown error"))
      self.errorText:Show()
      return
    end
  elseif self.containerSignature ~= signature then
    -- Reconfigure Blizzard's existing group instead of abandoning a container
    -- whose assigned AuraButtons may already be forbidden. Clear candidates
    -- first, then change the supported native inputs and restore the group.
    self:SetNativeSuppressed(true)
    if self.nativeFilterString ~= options.filterString then
      self.container:SetAuraGroupFilterString("popauras", options.filterString)
      self.nativeFilterString = options.filterString
    end
    if self.nativeUnit ~= options.unit then
      self.container:SetUnit(options.unit)
      self.nativeUnit = options.unit
    end
    self.containerSignature = signature
  end

  self.errorText:Hide()
  local maxFrameCount = tonumber(options.maxFrameCount or aura.display.maxAuras or 40) or 40
  if not inCombat and self.nativeMaxFrameCount ~= maxFrameCount then
    self.container:SetAuraGroupMaxFrameCount("popauras", maxFrameCount)
    self.nativeMaxFrameCount = maxFrameCount
  end
  local sortMethod, sortDirection = GetExpirationSort(GetTrigger(aura))
  local sortSignature = string.format("%s|%s", tostring(sortMethod), tostring(sortDirection))
  if not inCombat and self.sortSignature ~= sortSignature and self.container.SetAuraGroupSortMethod then
    self.container:SetAuraGroupSortMethod("popauras", sortMethod, sortDirection)
    self.sortSignature = sortSignature
  end
  if not inCombat and self.layoutSignature ~= LayoutSignature(aura.display) then
    self:ApplyContainerLayout(aura)
  end
  self:SetNativeSuppressed(false, options)
end

function Region:RefreshNativeUnit(unit)
  if self.loadMatched ~= true then return false end
  local trigger = GetTrigger(self.currentAura)
  if not trigger or (trigger.unit or "player") ~= unit then
    return false
  end
  if not self.container or self.nativeEnabled ~= true or self.nativeSuppressed == true then
    return false
  end

  -- "target" is a stable unit token even when it starts referring to a new
  -- GUID, so SetUnit("target") would be a no-op. Blizzard exposes this rebuild
  -- specifically for external identity changes while the container continues
  -- to own normal UNIT_AURA updates.
  if self.container.UpdateAllAuras then
    self.container:UpdateAllAuras()
    return true
  end
  return false
end

function Region:Release()
  self.loadMatched = false
  self.layoutVisible = false
  self:SetNativeSuppressed(true)
  self:HidePreview()
  self.errorText:Hide()
end
