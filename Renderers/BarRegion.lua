local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Fonts = ns.util.Fonts
local Colors = ns.util.Colors
local Spells = ns.util.Spells

local BarRegion = {}
ns.renderers.BarRegion = BarRegion

local DEFAULT_TEXT_COLOR = { r = 1, g = 1, b = 1, a = 1 }

local STATUS_BAR_DIRECTION = Enum and Enum.StatusBarTimerDirection or nil
local STATUS_BAR_INTERPOLATION = Enum and Enum.StatusBarInterpolation or nil

local function GetTexturePath(textureKey)
  local textures = {
    DEFAULT = "Interface\\Buttons\\WHITE8x8",
    FLAT = "Interface\\Buttons\\WHITE8x8",
    GLAZE = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar",
    CAST = "Interface\\TargetingFrame\\UI-StatusBar",
  }
  if textureKey == "Interface\\TARGETINGFRAME\\UI-StatusBar" or textureKey == "Interface\\TargetingFrame\\UI-StatusBar" then
    return textures.FLAT
  end
  return textures[textureKey] or textureKey or textures.DEFAULT
end

function BarRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)

  instance.bar = CreateFrame("StatusBar", nil, instance.frame)
  instance.bar:SetAllPoints()
  instance.bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  if instance.bar.SetRotatesTexture then
    instance.bar:SetRotatesTexture(false)
  end
  if instance.bar.SetReverseFill then
    instance.bar:SetReverseFill(false)
  end

  instance.bg = instance.bar:CreateTexture(nil, "BACKGROUND")
  instance.bg:SetAllPoints()
  instance.bg:SetTexture("Interface\\Buttons\\WHITE8x8")

  instance.iconHolder = CreateFrame("Frame", nil, instance.frame)
  instance.iconHolder:SetSize(32, 32)
  instance.icon = instance.iconHolder:CreateTexture(nil, "ARTWORK")
  instance.icon:SetAllPoints()

  instance.overlay = CreateFrame("Frame", nil, instance.frame)
  instance.overlay:SetAllPoints()
  instance.overlay:SetFrameLevel(instance.frame:GetFrameLevel() + 20)

  instance.timerCooldown = CreateFrame("Cooldown", nil, instance.overlay, "CooldownFrameTemplate")
  instance.timerCooldown:SetAllPoints()
  instance.timerCooldown:EnableMouse(false)
  if instance.timerCooldown.SetDrawSwipe then
    instance.timerCooldown:SetDrawSwipe(false)
  end
  if instance.timerCooldown.SetDrawEdge then
    instance.timerCooldown:SetDrawEdge(false)
  end
  if instance.timerCooldown.SetDrawBling then
    instance.timerCooldown:SetDrawBling(false)
  end
  if instance.timerCooldown.SetHideCountdownNumbers then
    instance.timerCooldown:SetHideCountdownNumbers(true)
  end

  instance.labelText = instance.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  instance.timerText = instance.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  instance.stackText = instance.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  return instance
end

local function PositionText(fontString, parent, iconParent, anchor, x, y)
  fontString:ClearAllPoints()
  local resolvedAnchor = anchor or "CENTER"
  local resolvedParent = parent
  if resolvedAnchor == "ICON" and iconParent then
    resolvedAnchor = "CENTER"
    resolvedParent = iconParent
  end
  fontString:SetPoint(resolvedAnchor, resolvedParent, resolvedAnchor, x or 0, y or 0)
end

local function ApplyTextRotation(fontString, degrees)
  if not fontString or not fontString.SetRotation then
    return
  end
  local rotation = tonumber(degrees or 0) or 0
  fontString:SetRotation(math.rad(rotation))
end

local function ApplyFontStringColor(fontString, color)
  if not fontString then
    return
  end
  color = color or DEFAULT_TEXT_COLOR
  if fontString.SetTextColor then
    fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a == nil and 1 or color.a)
  elseif fontString.SetVertexColor then
    fontString:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a == nil and 1 or color.a)
  end
end

local function ShouldUseNativeCooldownText(aura, state, remainingFromObject)
  if not aura or not state or aura.display.showTimer ~= true then
    return false
  end
  if not state.durationObject then
    return false
  end
  return remainingFromObject == nil
end

local function ConfigureNativeCountdown(cooldown, frame, iconParent, aura, timerColor)
  if not cooldown then
    return
  end

  if cooldown.SetMinimumCountdownDuration then
    cooldown:SetMinimumCountdownDuration(0)
  end
  if cooldown.SetHideCountdownNumbers then
    cooldown:SetHideCountdownNumbers(false)
  end

  local countdownFS = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString() or nil
  if not countdownFS then
    return
  end

  Fonts.ApplyStyle(countdownFS, aura.display.timerFontStyle, aura.display.timerFontSize)
  ApplyFontStringColor(countdownFS, timerColor)
  PositionText(countdownFS, frame, iconParent, aura.display.timerAnchor, aura.display.timerOffsetX, aura.display.timerOffsetY)
  ApplyTextRotation(countdownFS, aura.display.timerRotation)
  if countdownFS.SetMaxLines then
    countdownFS:SetMaxLines(1)
  end
end

local oppositePoints = {
  LEFT = "RIGHT",
  RIGHT = "LEFT",
  TOP = "BOTTOM",
  BOTTOM = "TOP",
  TOPLEFT = "BOTTOMRIGHT",
  TOPRIGHT = "BOTTOMLEFT",
  BOTTOMLEFT = "TOPRIGHT",
  BOTTOMRIGHT = "TOPLEFT",
  CENTER = "CENTER",
}

local function ApplyIconPlacement(iconHolder, frame, display)
  iconHolder:ClearAllPoints()
  local side = display.iconAnchor or "LEFT"
  if side == "LEFT_OUTSIDE" then
    side = "LEFT"
  elseif side == "RIGHT_OUTSIDE" then
    side = "RIGHT"
  end
  local offsetX = display.iconOffsetX or 0
  local offsetY = display.iconOffsetY or 0
  local iconPoint = oppositePoints[side] or "CENTER"
  iconHolder:SetPoint(iconPoint, frame, side, offsetX, offsetY)
end

local function ApplyStackText(fontString, state)
  if not fontString then
    return
  end
  if state and state.hasStackDisplayValue == true then
    fontString:SetText(state.stackDisplayValue)
    return
  end
  fontString:SetText(state and (state.stackText or (state.stacks and state.stacks > 0 and tostring(state.stacks) or "")) or "")
end

function BarRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame, self.overlay)

  local remainingFromObject = ns.TextResolver:GetDurationObjectRemaining(state)
  local readyLookActive = aura.display.readyLook == true and ns.TextResolver:IsReadyState(state, remainingFromObject)
  local color = readyLookActive and (aura.display.readyColor or aura.display.color) or state.color or aura.display.color
  local timerColor = readyLookActive and (aura.display.readyTextColor or aura.display.timerColor) or aura.display.timerColor or DEFAULT_TEXT_COLOR
  local useNativeCooldownText = ShouldUseNativeCooldownText(aura, state, remainingFromObject)
  if state.durationObject and ns.TimerPresenter then
    ns.TimerPresenter:SetCompletionTimer(self.timerCooldown, state.durationObject, aura.id)
  end
  local orientation = aura.display.orientation or "HORIZONTAL"
  self.bar:SetStatusBarTexture(GetTexturePath(aura.display.barTexture))
  self.bar:SetOrientation(orientation)
  if self.bar.SetRotatesTexture then
    self.bar:SetRotatesTexture(orientation ~= "VERTICAL")
  end
  if self.bar.SetReverseFill then
    self.bar:SetReverseFill(aura.display.reverse == true)
  end
  self.bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
  self.bg:SetShown(aura.display.showBackground ~= false)
  self.bg:SetVertexColor(
    aura.display.backgroundColor.r,
    aura.display.backgroundColor.g,
    aura.display.backgroundColor.b,
    aura.display.backgroundColor.a
  )

  if aura.display.icon then
    self.iconHolder:Show()
    self.iconHolder:SetFrameStrata(aura.display.frameStrata or "MEDIUM")
    self.iconHolder:SetFrameLevel((tonumber(aura.display.frameLevel or 1) or 1) + 1)
    ApplyIconPlacement(self.iconHolder, self.frame, aura.display)
    local iconSize = aura.display.iconMatchBarSize and ((orientation == "VERTICAL") and self.frame:GetWidth() or self.frame:GetHeight()) or (aura.display.iconSize or 32)
    self.iconHolder:SetSize(iconSize, iconSize)
    self.icon:SetTexture(Spells:ResolveDisplayIcon(aura, state))
  else
    self.iconHolder:Hide()
  end

  local glowTarget = aura.display.icon and self.iconHolder or self.frame
  BaseRegion:ApplyCommonAppearance(aura, self.frame, state, glowTarget)
  local cancelEnabled = false
  if state.show and BaseRegion:IsEditModeActive() ~= true then
    cancelEnabled = BaseRegion:ConfigureAuraCancellation(self.frame, state)
  else
    BaseRegion:ConfigureAuraCancellation(self.frame, nil)
  end
  self.frame:EnableMouse(BaseRegion:CanMove(aura) == true or cancelEnabled)

  self.labelText:SetShown(aura.display.showName == true)
  self.timerText:SetShown(aura.display.showTimer == true and not useNativeCooldownText)
  self.stackText:SetShown(aura.display.showStacks == true)
  Fonts.ApplyStyle(self.labelText, aura.display.nameFontStyle, aura.display.nameFontSize)
  Fonts.ApplyStyle(self.timerText, aura.display.timerFontStyle, aura.display.timerFontSize)
  Fonts.ApplyStyle(self.stackText, aura.display.stacksFontStyle, aura.display.stacksFontSize)
  Colors.Apply(self.labelText, aura.display.nameColor or { r = 1, g = 1, b = 1, a = 1 })
  Colors.Apply(self.timerText, timerColor)
  Colors.Apply(self.stackText, aura.display.stacksColor or { r = 1, g = 1, b = 1, a = 1 })
  PositionText(self.labelText, self.frame, self.iconHolder, aura.display.nameAnchor, aura.display.nameOffsetX, aura.display.nameOffsetY)
  PositionText(self.timerText, self.frame, self.iconHolder, aura.display.timerAnchor, aura.display.timerOffsetX, aura.display.timerOffsetY)
  PositionText(self.stackText, self.frame, self.iconHolder, aura.display.stacksAnchor, aura.display.stacksOffsetX, aura.display.stacksOffsetY)
  ApplyTextRotation(self.labelText, aura.display.nameRotation)
  ApplyTextRotation(self.timerText, aura.display.timerRotation)
  ApplyTextRotation(self.stackText, aura.display.stacksRotation)

  local remaining = state.progressType == "timed" and math.max(0, (state.expirationTime or 0) - GetTime()) or state.value
  local total = state.progressType == "timed" and (state.duration > 0 and state.duration or remaining) or math.max(1, state.total or 1)
  local usingDurationObjectTimer = state.durationObject ~= nil and self.bar.SetTimerDuration ~= nil
  local transitioningToOpaqueObjectTimer = usingDurationObjectTimer
    and self._usingDurationObjectTimer ~= true
    and remainingFromObject == nil
  if usingDurationObjectTimer then
    local direction = STATUS_BAR_DIRECTION and (
      aura.display.reverse == true
        and STATUS_BAR_DIRECTION.ElapsedTime
        or STATUS_BAR_DIRECTION.RemainingTime
    ) or nil
    local interpolation = STATUS_BAR_INTERPOLATION and STATUS_BAR_INTERPOLATION.Immediate or nil
    self.bar:SetMinMaxValues(0, 1)
    if transitioningToOpaqueObjectTimer then
      self.bar:SetValue(aura.display.reverse == true and 1 or 0)
    end
    if interpolation ~= nil or direction ~= nil then
      self.bar:SetTimerDuration(state.durationObject, interpolation, direction)
    else
      self.bar:SetTimerDuration(state.durationObject)
    end
  else
    self.bar:SetMinMaxValues(0, math.max(0.001, total))
    local barValue
    if readyLookActive then
      barValue = total
    else
      barValue = aura.display.reverse and not self.bar.SetReverseFill and math.max(0, total - remaining) or remaining
    end
    self.bar:SetValue(barValue)
  end
  self.labelText:SetText(ns.TextResolver:Resolve(aura.text.label, state, aura))
  if useNativeCooldownText then
    self.timerText:SetText("")
  else
    self.timerText:SetText(ns.TextResolver:GetTimerText(state, aura, remainingFromObject))
  end
  ApplyStackText(self.stackText, state)

  if useNativeCooldownText and state.durationObject and self.timerCooldown.SetCooldownFromDurationObject then
    self.timerCooldown:SetCooldownFromDurationObject(state.durationObject, true)
    ConfigureNativeCountdown(self.timerCooldown, self.frame, self.iconHolder, aura, timerColor)
    self.timerCooldown:Show()
  else
    if self.timerCooldown.SetHideCountdownNumbers then
      self.timerCooldown:SetHideCountdownNumbers(true)
    end
    self.timerCooldown:Hide()
  end

  local shouldRegisterTimed = false
  if state.show then
    if state.durationObject then
      shouldRegisterTimed = aura.display.showTimer == true and not useNativeCooldownText and remainingFromObject ~= nil and remainingFromObject > 0
    else
      shouldRegisterTimed = state.progressType == "timed" and (state.expirationTime or 0) > GetTime()
    end
  end

  if shouldRegisterTimed then
    ns.runtime:RegisterTimedRegion(aura.id, self)
  else
    ns.runtime:UnregisterTimedRegion(aura.id)
  end

  self._usingDurationObjectTimer = usingDurationObjectTimer == true
end

function BarRegion:OnTimerUpdate(now)
  local aura = self.currentAura
  local state = self.currentState
  if not aura or not state then
    return false
  end

  local remainingFromObject = ns.TextResolver:GetDurationObjectRemaining(state, now)
  if remainingFromObject ~= nil then
    local numericRemaining = (tonumber(state.expirationTime or 0) or 0) > 0 and math.max(0, (state.expirationTime or 0) - now) or nil
    if numericRemaining and math.abs(numericRemaining - remainingFromObject) > 0.75 then
      local cooldownProvider = ns.providers and ns.providers.spell_cooldown or nil
      if cooldownProvider and cooldownProvider.LogCooldownRenderDebug then
        cooldownProvider:LogCooldownRenderDebug(
          aura,
          state,
          self,
          "render:tick_mismatch",
          string.format("numRem=%0.3f objRem=%0.3f", numericRemaining, remainingFromObject)
        )
      end
    end
    if remainingFromObject <= 0 then
      ns.runtime:RefreshAura(aura.id)
      return false
    end

    if not self.frame:IsShown() then
      return true
    end

    local readyLookActive = aura.display.readyLook == true and ns.TextResolver:IsReadyState(state, remainingFromObject)
    Colors.Apply(
      self.timerText,
      readyLookActive and (aura.display.readyTextColor or aura.display.timerColor) or aura.display.timerColor or DEFAULT_TEXT_COLOR
    )
    self.timerText:SetText(ns.TextResolver:GetTimerText(state, aura, remainingFromObject))
    return true
  end

  local expirationTime = state.expirationTime or 0
  if expirationTime <= now then
    ns.runtime:RefreshAura(aura.id)
    return false
  end

  if not self.frame:IsShown() then
    return true
  end

  local liveRemaining = math.max(0, expirationTime - now)
  local total = state.duration > 0 and state.duration or liveRemaining
  local readyLookActive = aura.display.readyLook == true and ns.TextResolver:IsReadyState(state)

  self.bar:SetMinMaxValues(0, math.max(0.001, total))
  if readyLookActive then
    self.bar:SetValue(total)
  else
    self.bar:SetValue(
      aura.display.reverse == true and not self.bar.SetReverseFill
        and math.max(0, total - liveRemaining)
        or liveRemaining
    )
  end

  Colors.Apply(
    self.timerText,
    readyLookActive and (aura.display.readyTextColor or aura.display.timerColor) or aura.display.timerColor or DEFAULT_TEXT_COLOR
  )
  self.timerText:SetText(ns.TextResolver:GetTimerText(state, aura))
  return true
end
