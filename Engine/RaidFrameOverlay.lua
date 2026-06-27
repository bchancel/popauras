local _, ns = ...

local RaidFrameOverlay = {}
ns.RaidFrameOverlay = RaidFrameOverlay

local Fonts = ns.util.Fonts
local Spells = ns.util.Spells

local DEFAULT_ICON_SIZE = 18
local DEFAULT_OFFSET_Y = 11
local ICON_PADDING = 2
local GLOW_TEXTURE = "Interface\\SpellActivationOverlay\\IconAlert"
local GLOW_OUTER_TEXCOORD = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 }
local GLOW_PULSE_TEXCOORD = { 0.00781250, 0.50781250, 0.53515625, 0.78515625 }

local pool = {}
local activeIcons = {}
local iconsByFrame = setmetatable({}, { __mode = "k" })

local function SafeNumber(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "number" then
    return value
  end
  return nil
end

local function CanRenderNumericCooldown(state)
  if type(state) ~= "table" then
    return false
  end
  local start = (state.expirationTime or 0) - (state.duration or 0)
  local duration = state.duration or 0
  if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then
    return false
  end
  return state.progressType == "timed" and duration > 0 and (state.expirationTime or 0) > GetTime()
end

local function GetStackText(state)
  if not state then
    return ""
  end
  if state.hasStackDisplayValue == true and state.stackDisplayValue ~= nil then
    return tostring(state.stackDisplayValue)
  end
  if state.stackText and state.stackText ~= "" then
    return tostring(state.stackText)
  end
  if (tonumber(state.stacks or 0) or 0) > 0 then
    return tostring(state.stacks)
  end
  return ""
end

local function GetRaidFrameSettings(aura)
  local display = aura and aura.display or {}
  local iconSize = math.max(8, tonumber(display.raidFrameIconSize or DEFAULT_ICON_SIZE) or DEFAULT_ICON_SIZE)
  local anchor = tostring(display.raidFrameAnchor or "BOTTOM")
  local growth = tostring(display.raidFrameGrowth or "AUTO")
  local offsetX = tonumber(display.raidFrameOffsetX or 0) or 0
  local offsetY = tonumber(display.raidFrameOffsetY or DEFAULT_OFFSET_Y) or DEFAULT_OFFSET_Y
  return {
    iconSize = iconSize,
    anchor = anchor,
    growth = growth,
    offsetX = offsetX,
    offsetY = offsetY,
    showGlow = display.raidFrameShowGlow == true,
    showDuration = display.raidFrameShowDuration == true,
    showStacks = display.raidFrameShowStacks == true,
  }
end

local function ApplyCooldownAppearance(cooldown, aura)
  if not cooldown then
    return
  end

  local display = aura and aura.display or {}
  local swipeColor = display.iconSwipeColor or { r = 0, g = 0, b = 0, a = 0.60 }

  if cooldown.SetDrawBling then
    cooldown:SetDrawBling(display.iconCooldownBling == true)
  end
  if cooldown.SetDrawEdge then
    cooldown:SetDrawEdge(display.iconCooldownEdge == true)
  end
  if cooldown.SetDrawSwipe then
    cooldown:SetDrawSwipe(true)
  end
  if cooldown.SetReverse then
    cooldown:SetReverse(display.reverse == true)
  end
  if cooldown.SetSwipeColor then
    cooldown:SetSwipeColor(
      swipeColor.r or 0,
      swipeColor.g or 0,
      swipeColor.b or 0,
      swipeColor.a == nil and 1 or swipeColor.a
    )
  end
end

local function EnsureGlow(icon)
  local glow = icon._overlayGlow
  if glow then
    return glow
  end

  glow = CreateFrame("Frame", nil, icon)
  glow:SetFrameLevel(icon:GetFrameLevel() + 1)
  glow:Hide()

  glow.outerGlow = glow:CreateTexture(nil, "ARTWORK")
  glow.outerGlow:SetAllPoints()
  glow.outerGlow:SetTexture(GLOW_TEXTURE)
  glow.outerGlow:SetTexCoord(unpack(GLOW_OUTER_TEXCOORD))
  glow.outerGlow:SetBlendMode("ADD")
  glow.outerGlow:SetVertexColor(1.00, 0.86, 0.20, 0.78)

  glow.outerGlowPulse = glow:CreateTexture(nil, "OVERLAY")
  glow.outerGlowPulse:SetAllPoints()
  glow.outerGlowPulse:SetTexture(GLOW_TEXTURE)
  glow.outerGlowPulse:SetTexCoord(unpack(GLOW_PULSE_TEXCOORD))
  glow.outerGlowPulse:SetBlendMode("ADD")
  glow.outerGlowPulse:SetVertexColor(1.00, 0.95, 0.35, 1.00)
  glow.outerGlowPulse:SetAlpha(0.18)

  glow.pulse = glow.outerGlowPulse:CreateAnimationGroup()
  glow.pulse:SetLooping("REPEAT")
  local fadeIn = glow.pulse:CreateAnimation("Alpha")
  fadeIn:SetOrder(1)
  fadeIn:SetDuration(0.28)
  fadeIn:SetFromAlpha(0.18)
  fadeIn:SetToAlpha(0.70)
  local fadeOut = glow.pulse:CreateAnimation("Alpha")
  fadeOut:SetOrder(2)
  fadeOut:SetDuration(0.85)
  fadeOut:SetFromAlpha(0.70)
  fadeOut:SetToAlpha(0.22)

  glow:SetScript("OnHide", function(self)
    if self.pulse and self.pulse:IsPlaying() then
      self.pulse:Stop()
    end
    if self.outerGlowPulse then
      self.outerGlowPulse:SetAlpha(0.18)
    end
  end)

  icon._overlayGlow = glow
  return glow
end

local function SetGlow(icon, enabled)
  local glow = EnsureGlow(icon)
  if not glow then
    return
  end

  local size = math.max(icon:GetWidth(), icon:GetHeight())
  local padding = math.max(6, size * 0.30)
  glow:ClearAllPoints()
  glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -padding, padding)
  glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", padding, -padding)

  if enabled then
    glow:Show()
    if glow.pulse and not glow.pulse:IsPlaying() then
      glow.pulse:Play()
    end
  else
    glow:Hide()
  end
end

local function AcquireIcon()
  local icon = table.remove(pool)
  if icon then
    return icon
  end

  icon = CreateFrame("Frame", nil, UIParent)
  icon:SetSize(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE)
  icon:SetFrameStrata("HIGH")

  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetAllPoints()

  icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
  icon.cooldown:SetAllPoints()

  icon.overlay = CreateFrame("Frame", nil, icon)
  icon.overlay:SetAllPoints()
  icon.overlay:SetFrameLevel(icon:GetFrameLevel() + 20)

  icon.stackText = icon.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  icon.stackText:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
  icon.stackText:SetJustifyH("RIGHT")
  icon.stackText:SetJustifyV("TOP")

  icon.border = icon:CreateTexture(nil, "BACKGROUND")
  icon.border:SetPoint("TOPLEFT", -1, 1)
  icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
  icon.border:SetTexture("Interface\\Buttons\\WHITE8x8")
  icon.border:SetVertexColor(0, 0, 0, 0.9)

  return icon
end

local function RemoveIconFromFrame(icon)
  local unitFrame = icon and icon._overlayParent
  if not unitFrame then
    return nil
  end

  local icons = iconsByFrame[unitFrame]
  if icons then
    for index = #icons, 1, -1 do
      if icons[index] == icon then
        table.remove(icons, index)
        break
      end
    end
    if #icons == 0 then
      iconsByFrame[unitFrame] = nil
    end
  end

  icon._overlayParent = nil
  return unitFrame
end

local function AddIconToFrame(unitFrame, icon)
  if not unitFrame or not icon then
    return
  end

  local icons = iconsByFrame[unitFrame]
  if not icons then
    icons = {}
    iconsByFrame[unitFrame] = icons
  end

  for _, existing in ipairs(icons) do
    if existing == icon then
      icon._overlayParent = unitFrame
      return
    end
  end

  icons[#icons + 1] = icon
  icon._overlayParent = unitFrame
end

local function ReleaseIcon(icon)
  if not icon then
    return
  end

  RemoveIconFromFrame(icon)
  icon:ClearAllPoints()
  icon:SetParent(UIParent)
  icon:Hide()
  icon.stackText:SetText("")
  icon.stackText:Hide()
  icon.cooldown:Hide()
  if icon.cooldown.SetHideCountdownNumbers then
    icon.cooldown:SetHideCountdownNumbers(true)
  end
  SetGlow(icon, false)
  icon._overlayAuraId = nil
  icon._overlayLayoutKey = nil
  icon._overlayAnchor = nil
  icon._overlayGrowth = nil
  icon._overlayOffsetX = 0
  icon._overlayOffsetY = 0
  icon._overlaySort = 0
  pool[#pool + 1] = icon
end

local function ConfigureCountdown(cooldown, aura, iconSize, showDuration)
  if not cooldown then
    return
  end

  if cooldown.SetMinimumCountdownDuration then
    cooldown:SetMinimumCountdownDuration(0)
  end
  if cooldown.SetHideCountdownNumbers then
    cooldown:SetHideCountdownNumbers(not showDuration)
  end

  if not showDuration then
    return
  end

  local countdownFS = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString() or nil
  if not countdownFS then
    return
  end

  Fonts.ApplyStyle(countdownFS, aura and aura.display and aura.display.timerFontStyle or "FRIZQT_OUTLINE", math.max(10, math.floor(iconSize * 0.55)))
  countdownFS:SetTextColor(1, 1, 1, 1)
  countdownFS:ClearAllPoints()
  countdownFS:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
end

local function ApplyIconState(icon, aura, state)
  local settings = GetRaidFrameSettings(aura)
  local iconSize = settings.iconSize
  local iconTexture = Spells:ResolveDisplayIcon(aura, state)

  icon:SetSize(iconSize, iconSize)
  icon.texture:SetTexture(iconTexture)
  icon.texture:SetDesaturated(state and state.desaturate == true)

  icon._overlayAuraId = aura.id
  icon._overlayAnchor = settings.anchor
  icon._overlayGrowth = settings.growth
  icon._overlayOffsetX = settings.offsetX
  icon._overlayOffsetY = settings.offsetY
  icon._overlayLayoutKey = string.format("%s:%s:%0.2f:%0.2f", settings.anchor, settings.growth, settings.offsetX, settings.offsetY)
  icon._overlaySort = ns.runtime and ns.runtime.GetActivationOrder and ns.runtime:GetActivationOrder(aura.id) or 0

  ApplyCooldownAppearance(icon.cooldown, aura)
  ConfigureCountdown(icon.cooldown, aura, iconSize, settings.showDuration)

  if state.durationObject and icon.cooldown.SetCooldownFromDurationObject then
    icon.cooldown:SetCooldownFromDurationObject(state.durationObject, true)
    icon.cooldown:Show()
  elseif CanRenderNumericCooldown(state) then
    local remaining = (state.expirationTime or 0) - GetTime()
    local startTime = (state.expirationTime or 0) - ((state.duration or 0) > 0 and state.duration or remaining)
    local duration = (state.duration or 0) > 0 and state.duration or remaining
    icon.cooldown:SetCooldown(startTime, duration)
    icon.cooldown:Show()
  else
    icon.cooldown:Hide()
    if icon.cooldown.SetHideCountdownNumbers then
      icon.cooldown:SetHideCountdownNumbers(true)
    end
  end

  local stackText = settings.showStacks and GetStackText(state) or ""
  if stackText ~= "" then
    Fonts.ApplyStyle(icon.stackText, aura and aura.display and aura.display.stacksFontStyle or "FRIZQT_OUTLINE", math.max(9, math.floor(iconSize * 0.42)))
    icon.stackText:SetTextColor(1, 1, 1, 1)
    icon.stackText:SetText(stackText)
    icon.stackText:Show()
  else
    icon.stackText:SetText("")
    icon.stackText:Hide()
  end

  SetGlow(icon, settings.showGlow and state and state.active == true)
end

local function CompareIcons(left, right)
  local leftSort = tonumber(left and left._overlaySort or 0) or 0
  local rightSort = tonumber(right and right._overlaySort or 0) or 0
  if leftSort ~= rightSort then
    return leftSort < rightSort
  end
  return tostring(left and left._overlayAuraId or "") < tostring(right and right._overlayAuraId or "")
end

local function IsRightAnchor(anchor)
  return anchor == "TOPRIGHT" or anchor == "BOTTOMRIGHT" or anchor == "RIGHT" or anchor == "RIGHT_OUTSIDE"
end

local function IsLeftAnchor(anchor)
  return anchor == "TOPLEFT" or anchor == "BOTTOMLEFT" or anchor == "LEFT" or anchor == "LEFT_OUTSIDE"
end

local function IsTopAnchor(anchor)
  return anchor == "TOP" or anchor == "TOPLEFT" or anchor == "TOPRIGHT"
end

local function IsBottomAnchor(anchor)
  return anchor == "BOTTOM" or anchor == "BOTTOMLEFT" or anchor == "BOTTOMRIGHT"
end

local function UseVerticalLayout(anchor)
  return anchor == "LEFT" or anchor == "RIGHT" or anchor == "LEFT_OUTSIDE" or anchor == "RIGHT_OUTSIDE"
end

local function ResolveAnchorBinding(anchor)
  if anchor == "LEFT_OUTSIDE" then
    return "RIGHT", "LEFT"
  elseif anchor == "RIGHT_OUTSIDE" then
    return "LEFT", "RIGHT"
  end
  return anchor, anchor
end

local function ResolveAnchorBaseOffsets(anchor, offsetX, offsetY)
  local baseX = tonumber(offsetX or 0) or 0
  local baseY = tonumber(offsetY or DEFAULT_OFFSET_Y) or DEFAULT_OFFSET_Y

  if anchor == "RIGHT" or anchor == "TOPRIGHT" or anchor == "BOTTOMRIGHT" or anchor == "LEFT_OUTSIDE" then
    baseX = -baseX
  end

  if IsTopAnchor(anchor) then
    baseY = -baseY
  end

  return baseX, baseY
end

local function LayoutDirectionalGroup(unitFrame, icons, anchor, growth, offsetX, offsetY)
  table.sort(icons, CompareIcons)

  local point, relativePoint = ResolveAnchorBinding(anchor)
  local baseX, baseY = ResolveAnchorBaseOffsets(anchor, offsetX, offsetY)
  local cursorX = 0
  local cursorY = 0

  for index, icon in ipairs(icons) do
    icon:ClearAllPoints()
    icon:SetPoint(point, unitFrame, relativePoint, baseX + cursorX, baseY + cursorY)
    icon:Show()

    if index < #icons then
      local width = icon:GetWidth() or DEFAULT_ICON_SIZE
      local height = icon:GetHeight() or DEFAULT_ICON_SIZE
      if growth == "LEFT" then
        cursorX = cursorX - width - ICON_PADDING
      elseif growth == "RIGHT" then
        cursorX = cursorX + width + ICON_PADDING
      elseif growth == "UP" then
        cursorY = cursorY + height + ICON_PADDING
      elseif growth == "DOWN" then
        cursorY = cursorY - height - ICON_PADDING
      end
    end
  end
end

local function LayoutHorizontalGroup(unitFrame, icons, anchor, offsetX, offsetY)
  table.sort(icons, CompareIcons)
  local point, relativePoint = ResolveAnchorBinding(anchor)
  local baseX, baseY = ResolveAnchorBaseOffsets(anchor, offsetX, offsetY)

  local totalSpan = 0
  for index, icon in ipairs(icons) do
    totalSpan = totalSpan + (icon:GetWidth() or DEFAULT_ICON_SIZE)
    if index < #icons then
      totalSpan = totalSpan + ICON_PADDING
    end
  end

  local cursor = 0
  if not IsLeftAnchor(anchor) and not IsRightAnchor(anchor) then
    cursor = -(totalSpan / 2)
  end

  for _, icon in ipairs(icons) do
    local width = icon:GetWidth() or DEFAULT_ICON_SIZE
    local anchorX
    if IsLeftAnchor(anchor) then
      anchorX = baseX + cursor
      cursor = cursor + width + ICON_PADDING
    elseif IsRightAnchor(anchor) then
      anchorX = baseX - cursor
      cursor = cursor + width + ICON_PADDING
    else
      anchorX = baseX + cursor + (width / 2)
      cursor = cursor + width + ICON_PADDING
    end

    icon:ClearAllPoints()
    icon:SetPoint(point, unitFrame, relativePoint, anchorX, baseY)
    icon:Show()
  end
end

local function LayoutVerticalGroup(unitFrame, icons, anchor, offsetX, offsetY)
  table.sort(icons, CompareIcons)
  local point, relativePoint = ResolveAnchorBinding(anchor)
  local baseX, baseY = ResolveAnchorBaseOffsets(anchor, offsetX, offsetY)

  local totalSpan = 0
  for index, icon in ipairs(icons) do
    totalSpan = totalSpan + (icon:GetHeight() or DEFAULT_ICON_SIZE)
    if index < #icons then
      totalSpan = totalSpan + ICON_PADDING
    end
  end

  local cursor = totalSpan / 2
  for _, icon in ipairs(icons) do
    local height = icon:GetHeight() or DEFAULT_ICON_SIZE
    local anchorY = baseY + cursor - (height / 2)

    icon:ClearAllPoints()
    icon:SetPoint(point, unitFrame, relativePoint, baseX, anchorY)
    icon:Show()
    cursor = cursor - height - ICON_PADDING
  end
end

local function RelayoutFrame(unitFrame)
  if not unitFrame then
    return
  end

  local icons = iconsByFrame[unitFrame]
  if not icons or #icons == 0 then
    return
  end

  local groups = {}
  local orderedKeys = {}
  for _, icon in ipairs(icons) do
    if icon then
      icon:SetParent(unitFrame)
      icon:SetFrameStrata("HIGH")
      icon:SetFrameLevel(unitFrame:GetFrameLevel() + 20)
      local layoutKey = icon._overlayLayoutKey or "BOTTOM:AUTO:0:11"
      if not groups[layoutKey] then
        groups[layoutKey] = {
          anchor = icon._overlayAnchor or "BOTTOM",
          growth = icon._overlayGrowth or "AUTO",
          offsetX = tonumber(icon._overlayOffsetX or 0) or 0,
          offsetY = tonumber(icon._overlayOffsetY or DEFAULT_OFFSET_Y) or DEFAULT_OFFSET_Y,
          icons = {},
        }
        orderedKeys[#orderedKeys + 1] = layoutKey
      end
      groups[layoutKey].icons[#groups[layoutKey].icons + 1] = icon
    end
  end

  for _, layoutKey in ipairs(orderedKeys) do
    local group = groups[layoutKey]
    if group then
      if group.growth and group.growth ~= "" and group.growth ~= "AUTO" then
        LayoutDirectionalGroup(unitFrame, group.icons, group.anchor, group.growth, group.offsetX, group.offsetY)
      elseif UseVerticalLayout(group.anchor) then
        LayoutVerticalGroup(unitFrame, group.icons, group.anchor, group.offsetX, group.offsetY)
      else
        LayoutHorizontalGroup(unitFrame, group.icons, group.anchor, group.offsetX, group.offsetY)
      end
    end
  end
end

function RaidFrameOverlay:Update(auraId, aura, state)
  if not auraId or not aura or not state then
    self:Clear(auraId)
    return
  end

  if not state.show or not state.active or not (ns.UnitFrameGlow and ns.UnitFrameGlow.FindUnitFramesForUnit) then
    self:Clear(auraId)
    return
  end

  local matchedUnits = state.matchedUnits
  if type(matchedUnits) ~= "table" or #matchedUnits == 0 then
    self:Clear(auraId)
    return
  end

  local desiredFrames = {}
  local frameUnits = {}
  for _, unitId in ipairs(matchedUnits) do
    local unitFrames = ns.UnitFrameGlow:FindUnitFramesForUnit(unitId)
    for _, unitFrame in ipairs(unitFrames or {}) do
      desiredFrames[unitFrame] = true
      frameUnits[unitFrame] = unitId
    end
  end

  if next(desiredFrames) == nil then
    self:Clear(auraId)
    return
  end

  local auraIcons = activeIcons[auraId]
  if not auraIcons then
    auraIcons = {}
    activeIcons[auraId] = auraIcons
  end

  local affectedFrames = {}
  for unitFrame, icon in pairs(auraIcons) do
    if not desiredFrames[unitFrame] then
      local releasedFrame = RemoveIconFromFrame(icon)
      if releasedFrame then
        affectedFrames[releasedFrame] = true
      end
      ReleaseIcon(icon)
      auraIcons[unitFrame] = nil
    end
  end

  for unitFrame in pairs(desiredFrames) do
    local icon = auraIcons[unitFrame]
    if not icon then
      icon = AcquireIcon()
      auraIcons[unitFrame] = icon
      AddIconToFrame(unitFrame, icon)
    else
      AddIconToFrame(unitFrame, icon)
    end
    local unitState = type(state.unitStates) == "table" and state.unitStates[frameUnits[unitFrame]] or nil
    ApplyIconState(icon, aura, unitState or state)
    affectedFrames[unitFrame] = true
  end

  if next(auraIcons) == nil then
    activeIcons[auraId] = nil
  end

  for unitFrame in pairs(affectedFrames) do
    RelayoutFrame(unitFrame)
  end
end

function RaidFrameOverlay:RepositionForAura(auraId)
  local auraIcons = activeIcons[auraId]
  if not auraIcons then
    return
  end

  local affectedFrames = {}
  for unitFrame in pairs(auraIcons) do
    affectedFrames[unitFrame] = true
  end

  for unitFrame in pairs(affectedFrames) do
    RelayoutFrame(unitFrame)
  end
end

function RaidFrameOverlay:Clear(auraId)
  local auraIcons = auraId and activeIcons[auraId] or nil
  if not auraIcons then
    return
  end

  local affectedFrames = {}
  for unitFrame, icon in pairs(auraIcons) do
    affectedFrames[unitFrame] = true
    ReleaseIcon(icon)
    auraIcons[unitFrame] = nil
  end
  activeIcons[auraId] = nil

  for unitFrame in pairs(affectedFrames) do
    RelayoutFrame(unitFrame)
  end
end

function RaidFrameOverlay:ClearAll()
  for auraId in pairs(activeIcons) do
    self:Clear(auraId)
  end
end
