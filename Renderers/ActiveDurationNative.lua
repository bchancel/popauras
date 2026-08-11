local _, ns = ...

-- Blizzard-owned exact-aura presentation for Spell Cooldown bars using the
-- Active Duration appearance. The AuraButton owns presence and timing; addon
-- Lua only configures a verified spell-ID filter and presentation widgets.
local Controller = {}
ns.renderers.ActiveDurationNative = Controller
local Media = ns.util.Media

local EMPTY_CANDIDATE_FILTERS = { includeSpellIDs = {} }
local decimalFormatters = {}

local function GetDecimalFormatter(decimals)
  decimals = math.max(0, math.min(2, tonumber(decimals or 1) or 1))
  if decimalFormatters[decimals] then return decimalFormatters[decimals] end
  if not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter then return nil end
  local formatter = C_StringUtil.CreateNumericRuleFormatter()
  formatter:SetBreakpoints({ {
    threshold = 0,
    step = 10 ^ (-decimals),
    rounding = Enum and Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Nearest or 0,
    format = "%." .. decimals .. "f",
  } })
  decimalFormatters[decimals] = formatter
  return formatter
end

local oppositePoints = {
  LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP",
  TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT",
  BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT", CENTER = "CENTER",
}

local function PositionTimer(fontString, button, iconAnchor, display)
  local anchor = display.timerAnchor or "CENTER"
  local relative = button
  if anchor == "ICON" then
    anchor = "CENTER"
    relative = iconAnchor
  end
  fontString:ClearAllPoints()
  fontString:SetPoint(anchor, relative, anchor,
    tonumber(display.timerOffsetX or 0) or 0,
    tonumber(display.timerOffsetY or 0) or 0)
end

local function BuildCandidateFilters(spellIDs)
  local includeSpellIDs, ordered = {}, {}
  for _, value in ipairs(type(spellIDs) == "table" and spellIDs or {}) do
    local spellID = ns.SafeValues:Number(value)
    if spellID and spellID > 0 and not includeSpellIDs[spellID] then
      includeSpellIDs[spellID] = true
      ordered[#ordered + 1] = spellID
    end
  end
  table.sort(ordered)
  return { includeSpellIDs = includeSpellIDs }, table.concat(ordered, ",")
end

function Controller:InitializeButton(button)
  local aura = self.aura
  local display = aura.display or {}
  button:SetAllPoints(self.container)

  button.bar = CreateFrame("StatusBar", nil, button)
  button.bar:SetAllPoints()
  button.bar:SetStatusBarTexture(Media:ResolveStatusBarTexture(display.barTexture))
  button.bar:SetOrientation(display.orientation or "HORIZONTAL")
  if button.bar.SetRotatesTexture then
    button.bar:SetRotatesTexture((display.orientation or "HORIZONTAL") == "VERTICAL")
  end
  if button.bar.SetReverseFill then button.bar:SetReverseFill(display.reverse == true) end
  button.bar:SetStatusBarColor(1.00, 0.82, 0.08, 1.00)

  -- An opaque native background prevents the underlying cooldown fill/timer
  -- from leaking through while this securely controlled aura slot is shown.
  button.background = button.bar:CreateTexture(nil, "BACKGROUND")
  button.background:SetAllPoints()
  button.background:SetTexture("Interface\\Buttons\\WHITE8x8")
  local background = display.backgroundColor or { r = 0, g = 0, b = 0, a = 1 }
  button.background:SetVertexColor(background.r or 0, background.g or 0, background.b or 0, 1)

  button.iconAnchor = CreateFrame("Frame", nil, button)
  local width, height = button:GetSize()
  local iconSize = display.iconMatchBarSize and (
    (display.orientation or "HORIZONTAL") == "VERTICAL" and width or height)
    or tonumber(display.iconSize or height) or height
  button.iconAnchor:SetSize(iconSize, iconSize)
  local iconSide = display.iconAnchor or "LEFT"
  if iconSide == "LEFT_OUTSIDE" then iconSide = "LEFT" end
  if iconSide == "RIGHT_OUTSIDE" then iconSide = "RIGHT" end
  button.iconAnchor:SetPoint(oppositePoints[iconSide] or "CENTER", button, iconSide,
    tonumber(display.iconOffsetX or 0) or 0,
    tonumber(display.iconOffsetY or 0) or 0)

  button.presentation = CreateFrame("Frame", nil, button)
  button.presentation:SetAllPoints()
  button.presentation:SetFrameLevel(button:GetFrameLevel() + 10)
  button.timerText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ns.util.Fonts.ApplyStyle(button.timerText, display.timerFontStyle, display.timerFontSize)
  ns.util.Colors.Apply(button.timerText, { r = 1.00, g = 0.82, b = 0.08, a = 1.00 })
  PositionTimer(button.timerText, button, button.iconAnchor, display)
  if button.timerText.SetRotation then
    button.timerText:SetRotation(math.rad(tonumber(display.timerRotation or 0) or 0))
  end
  button.timerText:SetShown(display.showTimer == true)

  local direction = Enum and Enum.StatusBarTimerDirection and (
    display.reverse == true and Enum.StatusBarTimerDirection.ElapsedTime
      or Enum.StatusBarTimerDirection.RemainingTime) or nil
  local interpolation = Enum and Enum.StatusBarInterpolation
    and Enum.StatusBarInterpolation.Immediate or nil
  button:SetDurationBar(button.bar, { direction = direction, interpolation = interpolation })
  button:SetDurationText(button.timerText, {
    formatter = GetDecimalFormatter(display.timerDecimals),
    expiredText = "",
    zeroDurationText = "",
  })
end

function Controller:Create(parent, aura, spellIDs)
  if not ns.NativeAuras or not ns.NativeAuras:IsAvailable() then
    return false, ns.NativeAuras and ns.NativeAuras:GetFailureReason()
      or "Native aura containers are unavailable"
  end
  local candidateFilters, signature = BuildCandidateFilters(spellIDs)
  if signature == "" then return false, "No active-duration aura spell IDs" end

  local container, createError = ns.NativeAuras:CreateContainer(parent)
  if not container then return false, createError end
  if container.SetParentKey then container:SetParentKey("ActiveDurationAuraContainer") end
  if container.SetEnabled then container:SetEnabled(false) end
  container:SetAllPoints(parent)
  container:SetFrameLevel(parent:GetFrameLevel() + 30)
  self.container = container
  self.aura = aura
  self.candidateFilters = candidateFilters
  self.candidateSignature = signature

  local options = {
    initializeFrame = function(button) self:InitializeButton(button) end,
    candidateFilters = candidateFilters,
    sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ExpirationOnly or 0,
    sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
  }
  local ok, reason = pcall(container.AddAuraSlot, container,
    "popauras_active_duration", "HELPFUL", options)
  if not ok then
    if container.SetEnabled then container:SetEnabled(false) end
    self.container = nil
    return false, ns.SafeValues:IsSecret(reason) and "Native aura slot creation failed" or tostring(reason)
  end
  container:SetUnit("player")
  container:SetEnabled(true)
  self.enabled = true
  self.suppressed = false
  return true
end

function Controller:Update(spellIDs)
  if not self.container then return false end
  local candidateFilters, signature = BuildCandidateFilters(spellIDs)
  if signature == "" then
    self:SetSuppressed(true)
    return false
  end
  self.candidateFilters = candidateFilters
  if signature ~= self.candidateSignature then
    self.container:SetAuraSlotCandidateFilters("popauras_active_duration", candidateFilters)
    self.candidateSignature = signature
  end
  if self.suppressed == true then
    self.container:SetAuraSlotCandidateFilters("popauras_active_duration", candidateFilters)
    self.suppressed = false
  end
  if self.enabled ~= true then
    self.container:SetEnabled(true)
    self.enabled = true
  end
  return true
end

function Controller:SetSuppressed(suppressed)
  if not self.container or suppressed ~= true then return end
  if self.suppressed ~= true then
    self.container:SetEnabled(true)
    self.container:SetAuraSlotCandidateFilters(
      "popauras_active_duration", EMPTY_CANDIDATE_FILTERS)
    self.suppressed = true
  end
  self.container:SetEnabled(false)
  self.enabled = false
end

function Controller:Release()
  self:SetSuppressed(true)
end

function Controller:New(parent, aura, spellIDs)
  local instance = setmetatable({}, { __index = self })
  local ok, reason = instance:Create(parent, aura, spellIDs)
  if not ok then return nil, reason end
  return instance
end
