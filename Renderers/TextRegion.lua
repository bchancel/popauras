local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts

local TextRegion = {}
ns.renderers.TextRegion = TextRegion

local function PositionText(fontString, parent, anchor, x, y)
  local resolvedAnchor = anchor or "CENTER"
  fontString:ClearAllPoints()
  fontString:SetPoint(resolvedAnchor, parent, resolvedAnchor, x or 0, y or 0)
end

local function ApplyTextRotation(fontString, rotation)
  if fontString and fontString.SetRotation then
    fontString:SetRotation(math.rad(tonumber(rotation or 0) or 0))
  end
end

function TextRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.labelText = instance.frame:CreateFontString(nil, "OVERLAY")
  instance.labelText:SetJustifyH("CENTER")
  instance.labelText:SetJustifyV("MIDDLE")
  instance.labelText:SetWordWrap(true)
  return instance
end

function TextRegion:OnTimerUpdate(now)
  local aura = self.currentAura
  local state = self.currentState
  if not aura or not state then
    return false
  end

  if (state.expirationTime or 0) <= now then
    ns.runtime:RefreshAura(aura.id)
    return false
  end

  return self.frame and self.frame:IsShown()
end

function TextRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state

  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)
  BaseRegion:ApplyCommonAppearance(aura, self.frame, state)

  local backgroundColor = aura.display.backgroundColor or { r = 0, g = 0, b = 0, a = 0.45 }
  if aura.display.showBackground == true and state.show then
    self.frame:SetBackdropColor(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, backgroundColor.a == nil and 0.45 or backgroundColor.a)
  else
    self.frame:SetBackdropColor(0, 0, 0, 0)
  end
  self.frame:SetBackdropBorderColor(0, 0, 0, 0)

  self.labelText:SetShown(state.show and aura.display.showName ~= false)
  self.labelText:SetWidth(math.max(20, (self.frame:GetWidth() or aura.display.width or 200) - 8))
  Fonts.ApplyStyle(self.labelText, aura.display.nameFontStyle, aura.display.nameFontSize)
  Colors.Apply(self.labelText, state.color or aura.display.nameColor or { r = 1, g = 1, b = 1, a = 1 })
  PositionText(self.labelText, self.frame, aura.display.nameAnchor or "CENTER", aura.display.nameOffsetX or 0, aura.display.nameOffsetY or 0)
  ApplyTextRotation(self.labelText, aura.display.nameRotation)
  self.labelText:SetText(ns.TextResolver:Resolve(aura.text.label, state, aura))

  if state.show and state.progressType == "timed" and (state.expirationTime or 0) > GetTime() then
    ns.runtime:RegisterTimedRegion(aura.id, self)
  else
    ns.runtime:UnregisterTimedRegion(aura.id)
  end
end

function TextRegion:Release()
  BaseRegion.Release(self)
end
