local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts

local IconRegion = {}
ns.renderers.IconRegion = IconRegion

local DEFAULT_ICON_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DESATURATED_ICON_COLOR = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
local DEFAULT_TEXT_COLOR = { r = 1, g = 1, b = 1, a = 1 }

function IconRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.icon = instance.frame:CreateTexture(nil, "ARTWORK")
  instance.icon:SetAllPoints()

  instance.cooldown = CreateFrame("Cooldown", nil, instance.frame, "CooldownFrameTemplate")
  instance.cooldown:SetAllPoints()

  instance.overlay = CreateFrame("Frame", nil, instance.frame)
  instance.overlay:SetAllPoints()
  instance.overlay:SetFrameLevel(instance.frame:GetFrameLevel() + 20)

  instance.stackText = instance.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  instance.labelText = instance.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  instance.timerText = instance.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  return instance
end

local function PositionText(fontString, parent, anchor, x, y)
  fontString:ClearAllPoints()
  fontString:SetPoint(anchor or "CENTER", parent, anchor or "CENTER", x or 0, y or 0)
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

local function ConfigureNativeCountdown(cooldown, aura, timerColor)
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
  PositionText(countdownFS, cooldown, aura.display.timerAnchor, aura.display.timerOffsetX, aura.display.timerOffsetY)
  ApplyTextRotation(countdownFS, aura.display.timerRotation)
  if countdownFS.SetMaxLines then
    countdownFS:SetMaxLines(1)
  end
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

local function ResolveDisplayIcon(aura, state)
  local overrideId = aura and aura.display and tonumber(aura.display.iconOverrideId or 0) or 0
  if overrideId > 0 then
    if C_Spell and C_Spell.GetSpellTexture then
      local texture = C_Spell.GetSpellTexture(overrideId)
      if texture then
        return texture
      end
    end
    return overrideId
  end
  return state.icon or 134400
end

function IconRegion:OnTimerUpdate(now)
  local aura = self.currentAura
  local state = self.currentState
  if not aura or not state then
    return false
  end

  local remainingFromObject = ns.TextResolver:GetDurationObjectRemaining(state, now)
  if remainingFromObject ~= nil then
    if remainingFromObject <= 0 then
      ns.runtime:RefreshAura(aura.id)
      return false
    end
  else
    local expirationTime = state.expirationTime or 0
    if expirationTime <= now then
      ns.runtime:RefreshAura(aura.id)
      return false
    end
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

function IconRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame, self.overlay)
  BaseRegion:ApplyCommonAppearance(aura, self.frame, state)
  self.icon:SetTexture(ResolveDisplayIcon(aura, state))
  local remainingFromObject = ns.TextResolver:GetDurationObjectRemaining(state)
  local readyLookActive = aura.display.readyLook == true and ns.TextResolver:IsReadyState(state, remainingFromObject)
  local iconColor = readyLookActive and (aura.display.readyColor or aura.display.color) or DEFAULT_ICON_COLOR
  if state.desaturate then
    iconColor = DESATURATED_ICON_COLOR
  end
  local timerColor = readyLookActive and (aura.display.readyTextColor or aura.display.timerColor) or aura.display.timerColor or DEFAULT_TEXT_COLOR
  local useNativeCooldownText = ShouldUseNativeCooldownText(aura, state, remainingFromObject)
  Colors.Apply(self.icon, iconColor)
  self.icon:SetDesaturated(state.desaturate == true)

  if self.cooldown.SetDrawBling then
    self.cooldown:SetDrawBling(false)
  end
  if self.cooldown.SetDrawEdge then
    self.cooldown:SetDrawEdge(false)
  end
  if self.cooldown.SetDrawSwipe then
    self.cooldown:SetDrawSwipe(aura.display.swipe == true)
  end

  if aura.display.swipe or useNativeCooldownText then
    if state.durationObject and self.cooldown.SetCooldownFromDurationObject then
      self.cooldown:SetCooldownFromDurationObject(state.durationObject, true)
      if self.cooldown.SetHideCountdownNumbers then
        self.cooldown:SetHideCountdownNumbers(not useNativeCooldownText)
      end
      if useNativeCooldownText then
        ConfigureNativeCountdown(self.cooldown, aura, timerColor)
      end
      self.cooldown:Show()
    elseif CanRenderNumericCooldown(state) then
      local remaining = state.expirationTime - GetTime()
      local start = state.expirationTime - (state.duration > 0 and state.duration or remaining)
      self.cooldown:SetCooldown(start, state.duration > 0 and state.duration or remaining)
      if self.cooldown.SetHideCountdownNumbers then
        self.cooldown:SetHideCountdownNumbers(true)
      end
      self.cooldown:Show()
    else
      self.cooldown:Hide()
    end
  else
    if self.cooldown.SetHideCountdownNumbers then
      self.cooldown:SetHideCountdownNumbers(true)
    end
    self.cooldown:Hide()
  end

  ApplyStackText(self.stackText, state)
  self.stackText:SetShown(aura.display.showStacks == true)
  self.labelText:SetShown(aura.display.showName == true)
  self.timerText:SetShown(aura.display.showTimer == true and not useNativeCooldownText)
  Fonts.ApplyStyle(self.stackText, aura.display.stacksFontStyle, aura.display.stacksFontSize)
  Fonts.ApplyStyle(self.labelText, aura.display.nameFontStyle, aura.display.nameFontSize)
  Fonts.ApplyStyle(self.timerText, aura.display.timerFontStyle, aura.display.timerFontSize)
  Colors.Apply(self.stackText, aura.display.stacksColor or { r = 1, g = 1, b = 1, a = 1 })
  Colors.Apply(self.labelText, aura.display.nameColor or { r = 1, g = 1, b = 1, a = 1 })
  Colors.Apply(self.timerText, timerColor)
  PositionText(self.stackText, self.frame, aura.display.stacksAnchor, aura.display.stacksOffsetX, aura.display.stacksOffsetY)
  PositionText(self.labelText, self.frame, aura.display.nameAnchor, aura.display.nameOffsetX, aura.display.nameOffsetY)
  PositionText(self.timerText, self.frame, aura.display.timerAnchor, aura.display.timerOffsetX, aura.display.timerOffsetY)
  ApplyTextRotation(self.stackText, aura.display.stacksRotation)
  ApplyTextRotation(self.labelText, aura.display.nameRotation)
  ApplyTextRotation(self.timerText, aura.display.timerRotation)
  self.labelText:SetText(ns.TextResolver:Resolve(aura.text.label, state, aura))
  if useNativeCooldownText then
    self.timerText:SetText("")
  else
    self.timerText:SetText(ns.TextResolver:GetTimerText(state, aura, remainingFromObject))
  end

  local shouldRegisterTimed = false
  if state.show and aura.display.showTimer == true and not useNativeCooldownText then
    if state.durationObject then
      shouldRegisterTimed = remainingFromObject ~= nil and remainingFromObject > 0
    else
      shouldRegisterTimed = state.progressType == "timed" and (state.expirationTime or 0) > GetTime()
    end
  end

  if shouldRegisterTimed then
    ns.runtime:RegisterTimedRegion(aura.id, self)
  else
    ns.runtime:UnregisterTimedRegion(aura.id)
  end
end
