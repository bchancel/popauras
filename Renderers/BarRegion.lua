local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Fonts = ns.util.Fonts
local Colors = ns.util.Colors
local Spells = ns.util.Spells
local Safe = ns.SafeValues
local Duration = ns.Duration

local BarRegion = {}
ns.renderers.BarRegion = BarRegion

local DEFAULT_TEXT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local ACTIVE_DURATION_COLOR = { r = 1.00, g = 0.82, b = 0.08, a = 1 }

local STATUS_BAR_DIRECTION = Enum and Enum.StatusBarTimerDirection or nil
local STATUS_BAR_INTERPOLATION = Enum and Enum.StatusBarInterpolation or nil

local function CreateActiveBuffBorder(parent)
  local border = CreateFrame("Frame", nil, parent)
  border:SetAllPoints()
  border:Hide()

  local function edge(point, relativePoint, width, height, x, y)
    local texture = border:CreateTexture(nil, "OVERLAY")
    texture:SetColorTexture(1.00, 0.82, 0.08, 1.00)
    if width and width > 0 then texture:SetWidth(width) end
    if height and height > 0 then texture:SetHeight(height) end
    texture:SetPoint(point, border, relativePoint, x or 0, y or 0)
    return texture
  end

  border.top = edge("TOPLEFT", "TOPLEFT", 0, 2, 2, -2)
  border.top:SetPoint("TOPRIGHT", border, "TOPRIGHT", -2, -2)
  border.bottom = edge("BOTTOMLEFT", "BOTTOMLEFT", 0, 2, 2, 2)
  border.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -2, 2)
  border.left = edge("TOPLEFT", "TOPLEFT", 2, 0, 2, -2)
  border.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 2, 2)
  border.right = edge("TOPRIGHT", "TOPRIGHT", 2, 0, -2, -2)
  border.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -2, 2)

  border.pulse = border:CreateAnimationGroup()
  border.pulse:SetLooping("REPEAT")
  local fadeIn = border.pulse:CreateAnimation("Alpha")
  fadeIn:SetOrder(1)
  fadeIn:SetDuration(0.35)
  fadeIn:SetFromAlpha(0.55)
  fadeIn:SetToAlpha(1.00)
  local fadeOut = border.pulse:CreateAnimation("Alpha")
  fadeOut:SetOrder(2)
  fadeOut:SetDuration(0.90)
  fadeOut:SetFromAlpha(1.00)
  fadeOut:SetToAlpha(0.55)

  border:SetScript("OnHide", function(self)
    if self.pulse and self.pulse:IsPlaying() then
      self.pulse:Stop()
    end
    self:SetAlpha(1)
  end)
  return border
end

local function SetActiveBuffBorder(border, enabled, parent)
  if not border then return end
  if enabled then
    border:SetFrameStrata(parent:GetFrameStrata())
    border:SetFrameLevel(parent:GetFrameLevel() + 10)
    border:Show()
    if border.pulse and not border.pulse:IsPlaying() then
      border.pulse:Play()
    end
  else
    if border.pulse and border.pulse:IsPlaying() then
      border.pulse:Stop()
    end
    border:Hide()
  end
end

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
  instance.iconHolder:SetFrameLevel(instance.frame:GetFrameLevel() + 50)
  instance.iconHolder:SetSize(32, 32)
  instance.icon = instance.iconHolder:CreateTexture(nil, "ARTWORK")
  instance.icon:SetAllPoints()

  instance.overlay = CreateFrame("Frame", nil, instance.frame)
  instance.overlay:SetAllPoints()
  instance.overlay:SetFrameLevel(instance.frame:GetFrameLevel() + 50)
  instance.activeBuffBorder = CreateActiveBuffBorder(instance.frame)

  instance.timerOverlay = CreateFrame("Frame", nil, instance.frame)
  instance.timerOverlay:SetAllPoints()
  instance.timerOverlay:SetFrameLevel(instance.frame:GetFrameLevel() + 20)
  instance.timerCooldown = CreateFrame("Cooldown", nil, instance.timerOverlay, "CooldownFrameTemplate")
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
  instance.timerText = instance.timerOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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

function BarRegion:UpdateActiveDurationNative(aura, state)
  local wantsNative = state.activeGlowStyle == "ACTIVE_DURATION"
    and state.loadMatched ~= false and type(state.activeBuffSpellIDs) == "table"
  if not wantsNative then
    if self.activeDurationNative then self.activeDurationNative:Release() end
    return false, "not-requested"
  end

  if not self.activeDurationNative and self.activeDurationNativeFailed ~= true then
    local controllerClass = ns.renderers.ActiveDurationNative
    local controller, reason
    if controllerClass then
      controller, reason = controllerClass:New(self.frame, aura, state.activeBuffSpellIDs)
    end
    if controller then
      self.activeDurationNative = controller
    else
      self.activeDurationNativeFailed = true
      self.activeDurationNativeFailure = reason or "native-create-failed"
    end
  end
  if self.activeDurationNative and self.activeDurationNative:Update(state.activeBuffSpellIDs) then
    return true, "native-aura-slot"
  end
  return false, self.activeDurationNativeFailure or "native-unavailable"
end

function BarRegion:IsCurrentActiveDurationSource(source, cooldownID, token)
  return self.activeDurationSource == source
    and self.activeDurationCooldownID == cooldownID
    and self.activeDurationBindingToken == token
    and self.activeDurationCDMMode == true
end

local function GetActiveDurationSourceState(source)
  if not source or type(source.IsActive) ~= "function" then return nil end
  local okActive, sourceActive = pcall(source.IsActive, source)
  return okActive and Safe:Boolean(sourceActive) or nil
end

function BarRegion:GetCDMActiveDurationTimer(state)
  local manager = ns.CooldownManager
  if not manager or not manager.FindAuraStateSource
    or type(state.activeBuffSpellIDs) ~= "table" then
    return nil, "state-source-unavailable"
  end

  local source = manager:FindAuraStateSource(state.activeBuffSpellIDs, "player")
  if not source then
    -- Tracked-buff frames can be acquired after the cast/UNIT_AURA callback.
    -- Bypass a previously cached empty traversal for this bounded retry.
    source = manager:FindAuraStateSource(state.activeBuffSpellIDs, "player", true)
  end
  if not source then return nil, "state-source-missing" end

  local sourceKind = source.viewerFrame == _G.BuffIconCooldownViewer and "icon"
    or source.viewerFrame == _G.BuffBarCooldownViewer and "bar" or "unknown"
  if type(source.IsActive) ~= "function" then
    return nil, sourceKind .. ":active-api-unavailable"
  end
  local sourceActive = GetActiveDurationSourceState(source)
  if sourceActive ~= true then
    return nil, sourceKind .. (sourceActive == false and ":inactive" or ":active-unavailable")
  end
  if not source or type(source.GetAuraSpellInstanceID) ~= "function"
    or not C_UnitAuras or not C_UnitAuras.GetAuraDuration then
    return nil, sourceKind .. ":duration-api-unavailable"
  end

  local okInstance, auraInstanceID = pcall(source.GetAuraSpellInstanceID, source)
  auraInstanceID = okInstance and Safe:Number(auraInstanceID) or nil
  if not auraInstanceID then return nil, sourceKind .. ":instance-unavailable" end

  local okDuration, durationObject = pcall(C_UnitAuras.GetAuraDuration, "player", auraInstanceID)
  if not okDuration or durationObject == nil then return nil, sourceKind .. ":duration-unavailable" end
  return Duration:BuildTimer(durationObject, "active_buff_cdm", true), sourceKind .. ":duration-object"
end

function BarRegion:BindActiveDurationSource(state, aura)
  local manager = ns.CooldownManager
  local source, cooldownID
  if manager and manager.FindAuraDisplaySource and type(state.activeBuffSpellIDs) == "table" then
    source, cooldownID = manager:FindAuraDisplaySource(state.activeBuffSpellIDs, "player")
  end

  if self.activeDurationSource == source and self.activeDurationCooldownID == cooldownID then
    local sourceActive = GetActiveDurationSourceState(source)
    self.activeDurationCDMMode = source ~= nil and sourceActive == true
    if self.activeDurationCDMMode and self.activeDurationSourceBar then
      local okRange, minimum, maximum = pcall(self.activeDurationSourceBar.GetMinMaxValues, self.activeDurationSourceBar)
      if okRange then pcall(self.bar.SetMinMaxValues, self.bar, minimum, maximum) end
      local okValue, value = pcall(self.activeDurationSourceBar.GetValue, self.activeDurationSourceBar)
      if okValue then pcall(self.bar.SetValue, self.bar, value) end
      if self.activeDurationSourceDuration and type(self.activeDurationSourceDuration.GetText) == "function" then
        local okText, text = pcall(self.activeDurationSourceDuration.GetText, self.activeDurationSourceDuration)
        if okText then self.timerText:SetText(text) end
      end
    end
    return self.activeDurationCDMMode
  end

  self.activeDurationBindingToken = (self.activeDurationBindingToken or 0) + 1
  local token = self.activeDurationBindingToken
  self.activeDurationSource = source
  self.activeDurationCooldownID = cooldownID
  self.activeDurationSourceBar = nil
  self.activeDurationSourceDuration = nil
  self.activeDurationCDMMode = false
  if not source or not cooldownID or type(source.GetBarFrame) ~= "function" then return false end

  local okBar, sourceBar = pcall(source.GetBarFrame, source)
  if not okBar or not sourceBar then return false end
  self.activeDurationSourceBar = sourceBar
  if type(source.GetDurationFontString) == "function" then
    local okDuration, duration = pcall(source.GetDurationFontString, source)
    if okDuration then self.activeDurationSourceDuration = duration end
  end

  hooksecurefunc(source, "SetIsActive", function(owner)
    if self:IsCurrentActiveDurationSource(owner, cooldownID, token) and ns.runtime then
      ns.runtime:RefreshAura(aura.id)
    end
  end)
  hooksecurefunc(sourceBar, "SetMinMaxValues", function(_, minimum, maximum)
    if self:IsCurrentActiveDurationSource(source, cooldownID, token) then
      pcall(self.bar.SetMinMaxValues, self.bar, minimum, maximum)
    end
  end)
  hooksecurefunc(sourceBar, "SetValue", function(_, value)
    if self:IsCurrentActiveDurationSource(source, cooldownID, token) then
      pcall(self.bar.SetValue, self.bar, value)
    end
  end)
  if self.activeDurationSourceDuration then
    hooksecurefunc(self.activeDurationSourceDuration, "SetText", function(_, text)
      if self:IsCurrentActiveDurationSource(source, cooldownID, token) then
        self.timerText:SetText(text)
      end
    end)
  end

  local sourceActive = GetActiveDurationSourceState(source)
  self.activeDurationCDMMode = sourceActive == true
  if self.activeDurationCDMMode then
    local okRange, minimum, maximum = pcall(sourceBar.GetMinMaxValues, sourceBar)
    if okRange then pcall(self.bar.SetMinMaxValues, self.bar, minimum, maximum) end
    local okValue, value = pcall(sourceBar.GetValue, sourceBar)
    if okValue then pcall(self.bar.SetValue, self.bar, value) end
    if self.activeDurationSourceDuration and type(self.activeDurationSourceDuration.GetText) == "function" then
      local okText, text = pcall(self.activeDurationSourceDuration.GetText, self.activeDurationSourceDuration)
      if okText then self.timerText:SetText(text) end
    end
  end
  return self.activeDurationCDMMode
end

function BarRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame, self.overlay)

  -- Keep ordinary timer presentation below the native aura overlay, while
  -- labels, charge text, and the configured icon remain above it.
  local frameLevel = self.frame:GetFrameLevel()
  self.timerOverlay:SetFrameLevel(frameLevel + 20)
  self.overlay:SetFrameLevel(frameLevel + 50)
  self.iconHolder:SetFrameLevel(frameLevel + 50)

  local nativeActiveDuration, nativeActiveDurationDebug =
    self:UpdateActiveDurationNative(aura, state)
  self.activeDurationNativeAuthority = nativeActiveDuration == true

  -- In combat the raw player-aura presence can be unavailable. When Blizzard's
  -- exact AuraContainer slot is unavailable, ask the exact CDM source for its
  -- public active state instead of requiring raw aura presence first.
  local activeDurationRequested = state.activeGlowStyle == "ACTIVE_DURATION"
    and not nativeActiveDuration and state.show and state.active == true
  local activeBuffTimer, activeDurationDebug
  if activeDurationRequested then
    activeBuffTimer, activeDurationDebug = self:GetCDMActiveDurationTimer(state)
  elseif nativeActiveDuration then
    activeDurationDebug = nativeActiveDurationDebug
  else
    activeDurationDebug = nativeActiveDurationDebug or "not-requested"
  end
  self.activeDurationDebug = activeDurationDebug
  local activeBuffDurationObject = activeBuffTimer and activeBuffTimer.object or state.activeBuffDurationObject
  local activeDurationCDMMode = false
  if activeDurationRequested and activeBuffDurationObject == nil then
    activeDurationCDMMode = self:BindActiveDurationSource(state, aura)
  else
    self.activeDurationCDMMode = false
  end
  local activeDurationMode = activeDurationRequested
    and (activeBuffDurationObject ~= nil or activeDurationCDMMode)
  local timerState = state
  if activeDurationMode and not activeDurationCDMMode then
    timerState = {
      active = true,
      isReady = false,
      source = "aura",
      progressType = "timed",
      durationObject = activeBuffDurationObject,
      duration = activeBuffTimer and activeBuffTimer.duration or state.activeBuffDuration,
      expirationTime = activeBuffTimer and activeBuffTimer.expirationTime or state.activeBuffExpirationTime,
      value = activeBuffTimer and activeBuffTimer.duration or state.activeBuffDuration,
      total = activeBuffTimer and activeBuffTimer.duration or state.activeBuffDuration,
    }
  end
  self.currentTimerState = timerState
  self.activeDurationMode = activeDurationMode
  local remainingFromObject = ns.TextResolver:GetDurationObjectRemaining(timerState)
  local readyLookActive = aura.display.readyLook == true and ns.TextResolver:IsReadyState(timerState, remainingFromObject)
  local color = aura.display.color
  if aura.display.noStacksBarColorEnabled == true and state.noCharges == true then
    color = aura.display.noStacksBarColor or color
  end
  if state.color then color = state.color end
  if readyLookActive then color = aura.display.readyColor or aura.display.color end
  if activeDurationMode then color = ACTIVE_DURATION_COLOR end
  local timerColor = readyLookActive and (aura.display.readyTextColor or aura.display.timerColor) or aura.display.timerColor or DEFAULT_TEXT_COLOR
  if activeDurationMode then timerColor = ACTIVE_DURATION_COLOR end
  local useNativeCooldownText = not activeDurationCDMMode and ShouldUseNativeCooldownText(aura, timerState, remainingFromObject)
  if timerState.durationObject and ns.TimerPresenter then
    ns.TimerPresenter:SetCompletionTimer(self.timerCooldown, timerState.durationObject, aura.id)
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

  -- A spell cooldown's normal active state means "cooldown running." The
  -- appearance option instead uses its separately resolved player-buff state.
  local glowTarget = aura.display.icon and self.iconHolder or self.frame
  local activeGlowOverride
  if state.activeBuffGlow == true then
    activeGlowOverride = state.activeGlowStyle == "OUTER_GLOW" and state.active == true and state.activeBuff == true or false
    SetActiveBuffBorder(self.activeBuffBorder,
      state.activeGlowStyle == "INNER_GLOW" and state.show and state.active == true and state.activeBuff == true,
      self.frame)
  else
    SetActiveBuffBorder(self.activeBuffBorder, false, self.frame)
  end
  BaseRegion:ApplyCommonAppearance(aura, self.frame, state, glowTarget, activeGlowOverride)
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

  local remaining = timerState.progressType == "timed" and math.max(0, (timerState.expirationTime or 0) - GetTime()) or timerState.value
  local total = timerState.progressType == "timed" and (timerState.duration > 0 and timerState.duration or remaining) or math.max(1, timerState.total or 1)
  local usingDurationObjectTimer = not activeDurationCDMMode and timerState.durationObject ~= nil and self.bar.SetTimerDuration ~= nil
  local transitioningToOpaqueObjectTimer = usingDurationObjectTimer
    and self._usingDurationObjectTimer ~= true
    and remainingFromObject == nil
  if activeDurationCDMMode then
    -- CDM owns the restricted duration values. Its hooks above feed them
    -- directly into this presentation bar without addon Lua inspecting them.
  elseif usingDurationObjectTimer then
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
      self.bar:SetTimerDuration(timerState.durationObject, interpolation, direction)
    else
      self.bar:SetTimerDuration(timerState.durationObject)
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
  if activeDurationCDMMode then
    -- The CDM duration font string is mirrored by its SetText hook.
  elseif useNativeCooldownText then
    self.timerText:SetText("")
  else
    self.timerText:SetText(ns.TextResolver:GetTimerText(timerState, aura, remainingFromObject))
  end
  ApplyStackText(self.stackText, state)

  if activeDurationCDMMode then
    if self.timerCooldown.SetHideCountdownNumbers then
      self.timerCooldown:SetHideCountdownNumbers(true)
    end
    self.timerCooldown:Hide()
  elseif useNativeCooldownText and timerState.durationObject and self.timerCooldown.SetCooldownFromDurationObject then
    self.timerCooldown:SetCooldownFromDurationObject(timerState.durationObject, true)
    ConfigureNativeCountdown(self.timerCooldown, self.frame, self.iconHolder, aura, timerColor)
    self.timerCooldown:Show()
  else
    if self.timerCooldown.SetHideCountdownNumbers then
      self.timerCooldown:SetHideCountdownNumbers(true)
    end
    self.timerCooldown:Hide()
  end

  local shouldRegisterTimed = false
  if state.show and not activeDurationCDMMode then
    if timerState.durationObject then
      shouldRegisterTimed = aura.display.showTimer == true and not useNativeCooldownText and remainingFromObject ~= nil and remainingFromObject > 0
    else
      shouldRegisterTimed = timerState.progressType == "timed" and (timerState.expirationTime or 0) > GetTime()
    end
  end

  if shouldRegisterTimed then
    ns.runtime:RegisterTimedRegion(aura.id, self)
  else
    ns.runtime:UnregisterTimedRegion(aura.id)
  end

  self._usingDurationObjectTimer = usingDurationObjectTimer == true
end

function BarRegion:Release()
  if self.activeDurationNative then self.activeDurationNative:Release() end
  if self.currentAura and ns.runtime then ns.runtime:UnregisterTimedRegion(self.currentAura.id) end
  self.frame:Hide()
end

function BarRegion:OnTimerUpdate(now)
  local aura = self.currentAura
  local state = self.currentTimerState or self.currentState
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
      self.activeDurationMode and ACTIVE_DURATION_COLOR
        or readyLookActive and (aura.display.readyTextColor or aura.display.timerColor)
        or aura.display.timerColor or DEFAULT_TEXT_COLOR
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
    self.activeDurationMode and ACTIVE_DURATION_COLOR
      or readyLookActive and (aura.display.readyTextColor or aura.display.timerColor)
      or aura.display.timerColor or DEFAULT_TEXT_COLOR
  )
  self.timerText:SetText(ns.TextResolver:GetTimerText(state, aura))
  return true
end
