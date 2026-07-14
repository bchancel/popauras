local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts
local Frames = ns.util.Frames
local UnitAuraList = ns.util.UnitAuraList

local Region = {}
ns.renderers.AuraBarListRegion = Region
local timerFormatters = {}

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

  button.cooldown:SetShown(display.swipe == true)
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
  button.background = button.bar:CreateTexture(nil, "BACKGROUND")
  button.background:SetAllPoints()
  button.background:SetTexture("Interface\\Buttons\\WHITE8x8")

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints()
  button.cooldown:EnableMouse(false)
  if button.cooldown.SetHideCountdownNumbers then
    button.cooldown:SetHideCountdownNumbers(true)
  end

  button.presentation = CreateFrame("Frame", nil, button)
  button.presentation:SetFrameLevel(button:GetFrameLevel() + 10)
  button.nameText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.timerText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.countText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button:SetCancelAuraButtons("RightButtonUp")
  self.nativeButtons[#self.nativeButtons + 1] = button
  StyleButton(button, self.currentAura)
end

local function NativeSignature(options)
  return string.format("%s|%s", tostring(options.unit), tostring(options.filterString))
end

local function GetExpirationSort(display)
  display = display or {}
  local methods = AuraContainerSortMethod or {}
  local directions = AuraContainerSortDirection or {}
  local sortMethod = methods.ExpirationOnly or methods.Expiration or 0
  -- Aura groups lay out their first element at the anchor. Keep the next aura
  -- to expire at the visual bottom for both downward and upward lists.
  local sortDirection = display.growth == "UP"
    and (directions.Normal or 0)
    or (directions.Reverse or 1)
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
  container:SetPoint("TOPLEFT", self.frame, "TOPLEFT")
  self.nativeButtons = {}
  self.currentAura = aura

  local display = aura.display or {}
  local sortMethod, sortDirection = GetExpirationSort(display)
  local groupOptions = {
    maxFrameCount = tonumber(display.maxAuras or 40) or 40,
    initializeFrame = function(button) self:InitializeNativeButton(button) end,
    candidateFilters = options.candidateFilters,
    sortMethod = sortMethod,
    sortDirection = sortDirection,
    layout = {
      elementSpacingX = tonumber(display.spacing or 0) or 0,
      elementSpacingY = tonumber(display.spacing or 0) or 0,
      elementWidth = tonumber(display.width or 220) or 220,
      elementHeight = tonumber(display.height or 24) or 24,
    },
  }

  local ok, reason = pcall(container.AddAuraGroup, container, "popauras", options.filterString, groupOptions)
  if not ok then
    if container.SetEnabled then container:SetEnabled(false) end
    return nil, reason
  end
  container:SetUnit(options.unit)
  self.container = container
  self.containerSignature = NativeSignature(options)
  self.sortSignature = string.format("%s|%s", tostring(sortMethod), tostring(sortDirection))
  return container
end

local function GetFlowDirection(name, fallback)
  local directions = AnchorUtil and AnchorUtil.FlowDirection or nil
  return directions and directions[name] or fallback
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
  container:SetAuraLayoutAnchorPoint(anchor)
  container:SetAuraLayoutGrowthDirection(horizontal, vertical)
  container:SetAuraLayoutRowWidth((growth == "UP" or growth == "DOWN") and width or math.huge)
  container:SetAuraGroupLayout("popauras", {
    elementSpacingX = spacing,
    elementSpacingY = spacing,
    elementWidth = width,
    elementHeight = tonumber(display.height or 24) or 24,
  })
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

function Region:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.frame:SetClipsChildren(false)
  instance.nativeButtons = {}
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
  self.layoutVisible = true

  if state and state.source == "preview" then
    if self.container and self.nativeEnabled ~= false and self.container.SetEnabled then self.container:SetEnabled(false) end
    self.nativeEnabled = false
    self.errorText:Hide()
    self:ShowPreview(aura)
    return
  end
  self:HidePreview()

  local options = UnitAuraList:GetNativeOptions(GetTrigger(aura))
  local signature = NativeSignature(options)
  if not self.container or self.containerSignature ~= signature then
    if self.container and self.nativeEnabled ~= false and self.container.SetEnabled then self.container:SetEnabled(false) end
    self.nativeEnabled = false
    local _, reason = self:CreateNativeContainer(aura, options)
    if not self.container then
      self.errorText:SetText("Native aura display unavailable: " .. tostring(reason or "unknown error"))
      self.errorText:Show()
      return
    end
  end

  self.errorText:Hide()
  self.container:SetUnit(options.unit)
  self.container:SetAuraGroupCandidateFilters("popauras", options.candidateFilters)
  self.container:SetAuraGroupMaxFrameCount("popauras", tonumber(aura.display.maxAuras or 40) or 40)
  local sortMethod, sortDirection = GetExpirationSort(aura.display)
  local sortSignature = string.format("%s|%s", tostring(sortMethod), tostring(sortDirection))
  if self.sortSignature ~= sortSignature and self.container.SetAuraGroupSortMethod then
    self.container:SetAuraGroupSortMethod("popauras", sortMethod, sortDirection)
    self.sortSignature = sortSignature
  end
  self:ApplyContainerLayout(aura)
  for _, button in ipairs(self.nativeButtons) do StyleButton(button, aura) end
  if self.nativeEnabled ~= true and self.container.SetEnabled then self.container:SetEnabled(true) end
  self.nativeEnabled = true
end

function Region:Release()
  self.layoutVisible = false
  if self.container and self.nativeEnabled ~= false and self.container.SetEnabled then self.container:SetEnabled(false) end
  self.nativeEnabled = false
  self:HidePreview()
  self.errorText:Hide()
end
