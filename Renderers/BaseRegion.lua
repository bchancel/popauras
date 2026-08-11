local _, ns = ...

local BaseRegion = {}
ns.renderers.BaseRegion = BaseRegion

local Anchors = ns.util.Anchors
local Frames = ns.util.Frames

local GLOW_TEXTURE = "Interface\\SpellActivationOverlay\\IconAlert"
local GLOW_PADDING_RATIO = 0.18
local GLOW_MIN_PADDING = 8
local GLOW_OUTER_TEXCOORD = { 0.00781250, 0.50781250, 0.27734375, 0.52734375 }
local GLOW_PULSE_TEXCOORD = { 0.00781250, 0.50781250, 0.53515625, 0.78515625 }
local DEFAULT_GLOW_COLOR = { r = 1.00, g = 0.82, b = 0.08, a = 1.00 }

local function ApplyBuiltInGlowColor(glow, color)
  if not glow then return end
  color = type(color) == "table" and color or DEFAULT_GLOW_COLOR
  local r = tonumber(color.r) or DEFAULT_GLOW_COLOR.r
  local g = tonumber(color.g) or DEFAULT_GLOW_COLOR.g
  local b = tonumber(color.b) or DEFAULT_GLOW_COLOR.b
  local a = tonumber(color.a)
  if a == nil then a = DEFAULT_GLOW_COLOR.a end
  if glow.outerGlow then glow.outerGlow:SetVertexColor(r, g, b, 0.78 * a) end
  if glow.outerGlowPulse then glow.outerGlowPulse:SetVertexColor(r, g, b, a) end
end

local function PrepareTintableGlowTexture(texture)
  if not texture then return end
  -- IconAlert is authored with a warm color. Desaturating it first turns the
  -- source into a luminance mask so SetVertexColor can tint it to any chosen
  -- hue without multiplying some channels down to near-black.
  texture:SetDesaturated(true)
end

local function CleanupLegacyGlow(frame)
  if frame and frame.spellActivationAlert and ActionButton_HideOverlayGlow then
    pcall(ActionButton_HideOverlayGlow, frame)
  end
end

local function UpdateUnitFrameGlowHost(frame)
  local host = frame and frame._popAurasUnitFrameGlowHost
  if not host then
    return
  end

  host:ClearAllPoints()
  host:SetAllPoints(frame)
  host:SetFrameStrata(frame:GetFrameStrata())
  host:SetFrameLevel(frame:GetFrameLevel() + 20)
end

local function EnsureUnitFrameGlowHost(frame)
  if not frame then
    return nil
  end

  local host = frame._popAurasUnitFrameGlowHost
  if not host then
    host = CreateFrame("Frame", nil, frame)
    host:EnableMouse(false)
    frame._popAurasUnitFrameGlowHost = host
  end

  UpdateUnitFrameGlowHost(frame)
  return host
end

local function StopBlizzardUnitFrameGlow(frame)
  local host = frame and frame._popAurasUnitFrameGlowHost
  if not host then
    return
  end

  local alertManager = _G.ActionButtonSpellAlertManager
  if type(alertManager) == "table" and type(alertManager.HideAlert) == "function" then
    pcall(alertManager.HideAlert, alertManager, host)
  end
  if host.spellActivationAlert and ActionButton_HideOverlayGlow then
    pcall(ActionButton_HideOverlayGlow, host)
  end
  host:Hide()
end

local function StartBlizzardUnitFrameGlow(frame)
  local host = EnsureUnitFrameGlowHost(frame)
  if not host then
    return false
  end

  host:Show()

  -- Midnight replaced ActionButton_ShowOverlayGlow with the spell-alert
  -- manager. Its current template is Blizzard's animated action-button border.
  local alertManager = _G.ActionButtonSpellAlertManager
  if type(alertManager) == "table" and type(alertManager.ShowAlert) == "function" then
    local ok = pcall(alertManager.ShowAlert, alertManager, host)
    if ok and host.SpellActivationAlert then
      return true
    end
  end

  -- Retain the pre-Midnight path for clients where the legacy helper remains.
  if type(ActionButton_ShowOverlayGlow) == "function" then
    local ok = pcall(ActionButton_ShowOverlayGlow, host)
    if ok and host.spellActivationAlert then
      return true
    end
  end

  StopBlizzardUnitFrameGlow(frame)
  return false
end

local function UpdateBuiltInGlowLayout(frame)
  local glow = frame and frame._popAurasBuiltInGlow
  if not glow then
    return
  end

  local width = math.max(1, frame:GetWidth() or 1)
  local height = math.max(1, frame:GetHeight() or 1)
  local padX = math.max(GLOW_MIN_PADDING, width * GLOW_PADDING_RATIO)
  local padY = math.max(GLOW_MIN_PADDING, height * GLOW_PADDING_RATIO)

  glow:ClearAllPoints()
  glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -padX, padY)
  glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", padX, -padY)
  glow:SetFrameStrata(frame:GetFrameStrata())
  glow:SetFrameLevel(frame:GetFrameLevel())
end

local function EnsureBuiltInGlow(frame, color)
  if not frame then
    return nil
  end

  local glow = frame._popAurasBuiltInGlow
  if glow then
    ApplyBuiltInGlowColor(glow, color)
    UpdateBuiltInGlowLayout(frame)
    return glow
  end

  glow = CreateFrame("Frame", nil, frame)
  glow:Hide()

  glow.outerGlow = glow:CreateTexture(nil, "ARTWORK")
  glow.outerGlow:SetAllPoints()
  glow.outerGlow:SetTexture(GLOW_TEXTURE)
  glow.outerGlow:SetTexCoord(unpack(GLOW_OUTER_TEXCOORD))
  glow.outerGlow:SetBlendMode("ADD")
  PrepareTintableGlowTexture(glow.outerGlow)

  glow.outerGlowPulse = glow:CreateTexture(nil, "OVERLAY")
  glow.outerGlowPulse:SetAllPoints()
  glow.outerGlowPulse:SetTexture(GLOW_TEXTURE)
  glow.outerGlowPulse:SetTexCoord(unpack(GLOW_PULSE_TEXCOORD))
  glow.outerGlowPulse:SetBlendMode("ADD")
  PrepareTintableGlowTexture(glow.outerGlowPulse)
  ApplyBuiltInGlowColor(glow, color)
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

  frame._popAurasBuiltInGlow = glow
  UpdateBuiltInGlowLayout(frame)
  return glow
end

local function StopBuiltInGlow(frame)
  local glow = frame and frame._popAurasBuiltInGlow
  if not glow then
    return
  end

  if glow.pulse and glow.pulse:IsPlaying() then
    glow.pulse:Stop()
  end
  glow:Hide()
end

local function StartBuiltInGlow(frame, color)
  local glow = EnsureBuiltInGlow(frame, color)
  if not glow then
    return
  end

  UpdateBuiltInGlowLayout(frame)
  glow:Show()
  if glow.pulse and not glow.pulse:IsPlaying() then
    glow.pulse:Play()
  end
end

function BaseRegion:CreateFrame(aura)
  local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  if frame.SetParentKey then
    local auraKey = tostring(aura.regionKey or aura.id or "Unknown"):gsub("[^%w_]", "_")
    frame:SetParentKey("PopAurasRegion_" .. auraKey)
  end
  frame.auraId = aura.id
  frame:SetSize(aura.position.width or aura.display.width or 100, aura.position.height or aura.display.height or 32)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0, 0, 0, 0)
  frame:SetBackdropBorderColor(0, 0, 0, 0)
  Frames.MakeMovable(frame, function(self)
    local point, _, relativePoint, x, y = self:GetPoint(1)
    local auraDef = ns.Registry:GetAura(self.auraId)
    if auraDef then
      auraDef.position.point = point
      auraDef.position.relativeTo = auraDef.position.relativeTo or "UIParent"
      auraDef.position.relativePoint = relativePoint
      auraDef.position.x = x
      auraDef.position.y = y
      if ns.ui.MainWindow and ns.ui.MainWindow.RefreshSelection then
        ns.ui.MainWindow:RefreshSelection()
      end
    end
  end)
  return frame
end

function BaseRegion:IsEditModeActive()
  return ns.ui
    and ns.ui.MainWindow
    and ns.ui.MainWindow.IsOpen
    and ns.ui.MainWindow:IsOpen()
end

function BaseRegion:CanMove(aura)
  return aura
    and not aura.parentId
    and self:IsEditModeActive()
end

local function CanCancelPlayerAura(cancelData)
  if type(cancelData) ~= "table" then
    return false
  end
  if cancelData.source == "preview" then
    return false
  end
  if cancelData.unit ~= "player" or cancelData.helpful ~= true then
    return false
  end

  local auraInstanceID = ns.SafeValues:Number(cancelData.auraInstanceID)
  return auraInstanceID ~= nil and auraInstanceID > 0
    and C_UnitAuras ~= nil and C_UnitAuras.CancelAuraByInstanceID ~= nil
end

local function TryCancelPlayerAura(cancelData)
  if not CanCancelPlayerAura(cancelData) then
    return false
  end
  local auraInstanceID = ns.SafeValues:Number(cancelData.auraInstanceID)
  local ok = pcall(C_UnitAuras.CancelAuraByInstanceID, "player", auraInstanceID)
  return ok
end

function BaseRegion:ConfigureAuraCancellation(frame, cancelData)
  if not frame then
    return false
  end

  if frame._popAurasAuraCancelHooked ~= true then
    frame:HookScript("OnMouseUp", function(self, mouseButton)
      if mouseButton ~= "RightButton" then
        return
      end
      TryCancelPlayerAura(self._popAurasAuraCancelData)
    end)
    frame._popAurasAuraCancelHooked = true
  end

  if CanCancelPlayerAura(cancelData) then
    frame._popAurasAuraCancelData = cancelData
    return true
  end

  frame._popAurasAuraCancelData = nil
  return false
end

function BaseRegion:ApplyAnchor(aura, frame)
  if aura and aura.parentId then
    frame:SetSize(
      (aura.position and aura.position.width) or aura.display.width or 100,
      (aura.position and aura.position.height) or aura.display.height or 32
    )
    return
  end
  frame:ClearAllPoints()
  local position = aura.position or {}
  local relative = Anchors.Resolve(position.relativeTo)
  frame:SetPoint(position.point or "CENTER", relative, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
  frame:SetSize(position.width or aura.display.width or 100, position.height or aura.display.height or 32)
end

function BaseRegion:ApplyFrameLayer(aura, frame, overlay)
  local display = aura.display or {}
  local strata = display.frameStrata or "MEDIUM"
  local level = tonumber(display.frameLevel or 1) or 1

  frame:SetFrameStrata(strata)
  frame:SetFrameLevel(level)

  if overlay then
    overlay:SetFrameStrata(strata)
    overlay:SetFrameLevel(level + 1)
  end

  if frame and frame._popAurasBuiltInGlow then
    UpdateBuiltInGlowLayout(frame)
  end
end

local function SetAuraGlow(frame, shouldGlow, color)
  if not frame then
    return
  end

  if shouldGlow then
    if frame._popAurasGlowShown ~= true then
      CleanupLegacyGlow(frame)
      StopBuiltInGlow(frame)
      StartBuiltInGlow(frame, color)
      frame._popAurasGlowShown = true
    elseif frame._popAurasBuiltInGlow then
      ApplyBuiltInGlowColor(frame._popAurasBuiltInGlow, color)
      UpdateBuiltInGlowLayout(frame)
    end
  elseif frame._popAurasGlowShown == true or frame._popAurasBuiltInGlow or frame.spellActivationAlert then
    CleanupLegacyGlow(frame)
    StopBuiltInGlow(frame)
    frame._popAurasGlowShown = false
  end
end

function BaseRegion:SetGlow(frame, shouldGlow, color)
  SetAuraGlow(frame, shouldGlow == true, color)
end

function BaseRegion:SetUnitFrameGlow(frame, shouldGlow)
  if not frame then
    return
  end

  if shouldGlow == true then
    StopBuiltInGlow(frame)
    if StartBlizzardUnitFrameGlow(frame) then
      frame._popAurasUnitFrameGlowFallback = false
      frame._popAurasUnitFrameGlowRenderer = "blizzard_border"
    else
      StartBuiltInGlow(frame)
      frame._popAurasUnitFrameGlowFallback = true
      frame._popAurasUnitFrameGlowRenderer = "fallback_texture"
    end
    frame._popAurasUnitFrameGlowShown = true
    return
  end

  StopBlizzardUnitFrameGlow(frame)
  StopBuiltInGlow(frame)
  frame._popAurasUnitFrameGlowFallback = false
  frame._popAurasUnitFrameGlowShown = false
  frame._popAurasUnitFrameGlowRenderer = nil
end

function BaseRegion:ApplyCommonAppearance(aura, frame, state, glowTarget, activeGlowOverride)
  frame:EnableMouse(self:CanMove(aura))
  frame:SetAlpha((aura.display and aura.display.alpha) or 1)
  if state.show then
    frame:Show()
  else
    frame:Hide()
  end

  local allowActiveGlow = aura == nil or aura.kind ~= "aura_bar_list"
  local activeForGlow = activeGlowOverride
  if activeForGlow == nil then
    activeForGlow = state and state.active == true
  end
  local shouldGlow = state and (state.glow == true or (allowActiveGlow and (aura.display and aura.display.glowWhenActive == true) and activeForGlow == true)) or false
  if not state.show then
    shouldGlow = false
  end

  local resolvedGlowTarget = glowTarget or frame
  local previousGlowTarget = frame._popAurasGlowTarget
  if previousGlowTarget and previousGlowTarget ~= resolvedGlowTarget then
    SetAuraGlow(previousGlowTarget, false)
  end
  if resolvedGlowTarget ~= frame then
    SetAuraGlow(frame, false)
  end
  frame._popAurasGlowTarget = resolvedGlowTarget
  SetAuraGlow(resolvedGlowTarget, shouldGlow,
    aura and aura.display and aura.display.activeGlowColor)
end

function BaseRegion:Release()
  if self.frame then
    if ns.runtime and ns.runtime.UnregisterTimedRegion and self.frame.auraId then
      ns.runtime:UnregisterTimedRegion(self.frame.auraId)
    end
    local glowTarget = self.frame._popAurasGlowTarget
    if glowTarget and glowTarget ~= self.frame then
      SetAuraGlow(glowTarget, false)
    end
    self.frame._popAurasGlowTarget = nil
    SetAuraGlow(self.frame, false)
    self.frame:Hide()
  end
end
