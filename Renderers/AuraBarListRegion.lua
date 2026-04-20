local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts
local Spells = ns.util.Spells
local UnitAuraList = ns.util.UnitAuraList

local AuraBarListRegion = {}
ns.renderers.AuraBarListRegion = AuraBarListRegion

local STATUS_BAR_DIRECTION = Enum and Enum.StatusBarTimerDirection or nil
local STATUS_BAR_INTERPOLATION = Enum and Enum.StatusBarInterpolation or nil
local REAL_TIME_MODIFIER = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime or nil

local function GetTrigger(aura)
  if not aura or type(aura.triggers) ~= "table" then
    return nil
  end
  return aura.triggers[1]
end

local function GetTexturePath(textureKey)
  local textures = {
    DEFAULT = "Interface\\Buttons\\WHITE8x8",
    FLAT = "Interface\\Buttons\\WHITE8x8",
    GLAZE = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar",
  }
  if textureKey == "Interface\\TARGETINGFRAME\\UI-StatusBar" or textureKey == "Interface\\TargetingFrame\\UI-StatusBar" then
    return textures.BLIZZARD
  end
  return textures[textureKey] or textureKey or textures.DEFAULT
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
  fontString:SetRotation(math.rad(tonumber(degrees or 0) or 0))
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

local function ApplyIconPlacement(iconHolder, row, display)
  iconHolder:ClearAllPoints()
  local anchor = display.iconAnchor or "LEFT"
  if anchor == "LEFT_OUTSIDE" then
    anchor = "LEFT"
  elseif anchor == "RIGHT_OUTSIDE" then
    anchor = "RIGHT"
  end
  local offsetX = tonumber(display.iconOffsetX or 0) or 0
  local offsetY = tonumber(display.iconOffsetY or 0) or 0
  local iconPoint = oppositePoints[anchor] or "CENTER"
  iconHolder:SetPoint(iconPoint, row, anchor, offsetX, offsetY)
end

local function GetAuraTooltipFilter(entry)
  if not entry then
    return nil
  end
  return entry.helpful == false and "HARMFUL" or "HELPFUL"
end

local function ShowAuraBarTooltip(owner)
  if not owner or not GameTooltip or not GameTooltip.SetUnitAura then
    return
  end

  local entry = owner._popAurasAuraEntry
  if type(entry) ~= "table" or not entry.unit or not entry.index then
    return
  end

  if GameTooltip_SetDefaultAnchor then
    GameTooltip_SetDefaultAnchor(GameTooltip, owner)
  else
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
  end

  local ok = pcall(GameTooltip.SetUnitAura, GameTooltip, entry.unit, entry.index, GetAuraTooltipFilter(entry))
  if ok then
    GameTooltip:Show()
  else
    GameTooltip:Hide()
  end
end

local function HideAuraBarTooltip(owner)
  if not owner or not GameTooltip then
    return
  end

  local tooltipOwner = GameTooltip:GetOwner()
  if tooltipOwner == owner or tooltipOwner == owner:GetParent() then
    GameTooltip:Hide()
  end
end

local function AttachAuraBarTooltipHandlers(frame)
  if not frame or frame._popAurasTooltipHandlers == true then
    return
  end

  frame:SetScript("OnEnter", ShowAuraBarTooltip)
  frame:SetScript("OnLeave", HideAuraBarTooltip)
  frame:SetScript("OnHide", HideAuraBarTooltip)
  frame._popAurasTooltipHandlers = true
end

local function ApplyStackText(fontString, entry)
  if entry and entry.hasStackDisplayValue == true then
    fontString:SetText(entry.stackDisplayValue)
    return
  end
  fontString:SetText(entry and (entry.stackText or (entry.stacks and entry.stacks > 0 and tostring(entry.stacks) or "")) or "")
end

local function CallDurationObjectMethodRaw(durationObject, methodName)
  if not durationObject then
    return nil
  end

  local method = durationObject[methodName]
  if type(method) ~= "function" then
    return nil
  end

  local ok, result
  if REAL_TIME_MODIFIER ~= nil then
    ok, result = pcall(method, durationObject, REAL_TIME_MODIFIER)
  else
    ok, result = pcall(method, durationObject)
  end

  if not ok then
    return nil
  end

  return result
end

local function GetLiveAuraDurationObject(entry)
  if C_UnitAuras and C_UnitAuras.GetAuraDuration and entry and entry.unit and entry.auraInstanceID then
    local ok, durationObject = pcall(C_UnitAuras.GetAuraDuration, entry.unit, entry.auraInstanceID)
    if ok and durationObject then
      return durationObject
    end
  end
  return entry and entry.durationObject or nil
end

local function ResolveAuraBarLabel(entry)
  if not entry then
    return ""
  end

  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and entry.unit and entry.index then
    local filter = entry.helpful and "HELPFUL" or "HARMFUL"
    local auraData = C_UnitAuras.GetAuraDataByIndex(entry.unit, entry.index, filter)
    if type(auraData) == "table" and auraData.icon ~= nil and auraData.name ~= nil then
      return auraData.name
    end
  end

  return entry.name or ""
end

local function GetAuraHasExpiration(entry)
  if C_UnitAuras and C_UnitAuras.DoesAuraHaveExpirationTime and entry and entry.unit and entry.auraInstanceID then
    local ok, hasExpiration = pcall(C_UnitAuras.DoesAuraHaveExpirationTime, entry.unit, entry.auraInstanceID)
    if ok then
      local safeHasExpiration = nil
      if type(hasExpiration) == "boolean" and not (issecretvalue and issecretvalue(hasExpiration)) then
        safeHasExpiration = hasExpiration
      end
      return hasExpiration, safeHasExpiration
    end
  end

  if type(entry) == "table" and type(entry.hasExpiration) == "boolean"
    and not (issecretvalue and issecretvalue(entry.hasExpiration)) then
    return entry.hasExpiration, entry.hasExpiration
  end

  if entry and entry.isPermanent == true then
    return false, false
  end

  return nil, nil
end

local function ApplyAuraBarTimerVisibility(fontString, entry)
  if not fontString then
    return nil
  end

  local rawHasExpiration, safeHasExpiration = GetAuraHasExpiration(entry)
  if fontString.SetAlphaFromBoolean and rawHasExpiration ~= nil then
    fontString:SetAlphaFromBoolean(rawHasExpiration)
  elseif safeHasExpiration ~= nil then
    fontString:SetAlpha(safeHasExpiration and 1 or 0)
  else
    fontString:SetAlpha(1)
  end

  return safeHasExpiration
end

local function IsAuraVisuallyPermanent(entry)
  if not entry then
    return false
  end

  local _, safeHasExpiration = GetAuraHasExpiration(entry)
  if safeHasExpiration == false then
    return true
  end

  return entry.isPermanent == true
end

local function ApplyAuraBarStackText(fontString, entry)
  if not fontString then
    return
  end

  if C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount and entry and entry.unit and entry.auraInstanceID then
    local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, entry.unit, entry.auraInstanceID, 1, 999)
    if ok then
      if issecretvalue and issecretvalue(count) then
        fontString:SetText(count)
        return
      end
      if type(count) == "number" then
        fontString:SetText(count > 0 and count or "")
        return
      end
      if type(count) == "string" then
        local numeric = tonumber(count)
        if numeric ~= nil then
          fontString:SetText(numeric > 0 and count or "")
        else
          fontString:SetText(count ~= "" and count or "")
        end
        return
      end
    end
  end

  if entry and entry.hasStackDisplayValue == true and not (issecretvalue and issecretvalue(entry.stackDisplayValue)) then
    fontString:SetText(entry.stackDisplayValue or "")
    return
  end

  fontString:SetText(entry and (entry.stackText or (entry.stacks and entry.stacks > 0 and tostring(entry.stacks) or "")) or "")
end

local GetEntryTimerText

local function ApplyAuraBarTimerText(fontString, aura, entry, now)
  if not fontString then
    return
  end
  if not entry then
    fontString:SetAlpha(1)
    fontString:SetText("")
    return
  end

  local safeHasExpiration = ApplyAuraBarTimerVisibility(fontString, entry)
  if entry.isPermanent == true or safeHasExpiration == false then
    fontString:SetText("")
    return
  end

  local durationObject = GetLiveAuraDurationObject(entry)
  if durationObject then
    local remaining = CallDurationObjectMethodRaw(durationObject, "GetRemainingDuration")
    if remaining ~= nil then
      if issecretvalue and issecretvalue(remaining) then
        local decimals = math.max(0, math.min(2, tonumber(aura and aura.display and aura.display.timerDecimals or 1) or 1))
        if decimals > 0 then
          fontString:SetFormattedText("%." .. tostring(decimals) .. "fs", remaining)
        else
          fontString:SetFormattedText("%ds", remaining)
        end
        return
      end

      fontString:SetText(ns.TextResolver:GetTimerText(entry, aura, remaining))
      return
    end
  end

  fontString:SetText(GetEntryTimerText(aura, entry, now))
end

local function GetPermanentAlpha(display)
  local value = tonumber(display and display.permanentAlpha)
  if value == nil then
    return 1
  end
  return math.min(1, math.max(0, value))
end

local function HasLiveTimer(entry, now)
  if not entry or IsAuraVisuallyPermanent(entry) then
    return false
  end

  if entry.durationObject then
    return true
  end

  if type(entry.expirationTime) == "number" and entry.expirationTime > now then
    return true
  end

  local remainingFromObject = ns.TextResolver:GetDurationObjectRemaining(entry, now)
  return remainingFromObject ~= nil and remainingFromObject > 0
end

GetEntryTimerText = function(aura, entry, now)
  if not entry then
    return ""
  end
  now = now or GetTime()

  if entry.isPermanent == true then
    return ""
  end

  local remainingFromObject = ns.TextResolver:GetDurationObjectRemaining(entry, now)
  if remainingFromObject ~= nil then
    if remainingFromObject <= 0 and (entry.expirationTime or 0) <= now then
      return ""
    end
    return ns.TextResolver:GetTimerText(entry, aura, remainingFromObject)
  end

  if (entry.duration or 0) <= 0 and (entry.expirationTime or 0) <= now then
    return ""
  end

  return ns.TextResolver:GetTimerText(entry, aura, remainingFromObject)
end

local function TintColor(color, gamma)
  local base = color or { r = 0, g = 0, b = 0, a = 0.45 }
  local scale = tonumber(gamma or 1) or 1
  return {
    r = math.min(1, math.max(0, (base.r or 0) * scale)),
    g = math.min(1, math.max(0, (base.g or 0) * scale)),
    b = math.min(1, math.max(0, (base.b or 0) * scale)),
    a = base.a == nil and 1 or base.a,
  }
end

local function BuildPreviewEntries()
  local now = GetTime()
  return {
    {
      name = "Power Word: Fortitude",
      icon = 135987,
      duration = 30,
      expirationTime = now + 30,
      hasExpiration = true,
      progressType = "timed",
      value = 30,
      total = 30,
      unit = "player",
    },
    {
      name = "Renew",
      icon = 135953,
      duration = 12,
      expirationTime = now + 12,
      hasExpiration = true,
      progressType = "timed",
      value = 12,
      total = 12,
      unit = "player",
      stacks = 2,
      stackText = "2",
      stackDisplayValue = 2,
      hasStackDisplayValue = true,
    },
    {
      name = "Weakened Soul",
      icon = 136214,
      duration = 8,
      expirationTime = now + 8,
      hasExpiration = true,
      progressType = "timed",
      value = 8,
      total = 8,
      unit = "player",
    },
  }
end

function AuraBarListRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.frame:SetClipsChildren(false)
  instance.rows = {}
  instance.entries = {}
  return instance
end

function AuraBarListRegion:EnsureRow(index)
  local row = self.rows[index]
  if row then
    return row
  end

  row = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
  row:SetClipsChildren(false)

  row.bar = CreateFrame("StatusBar", nil, row)
  row.bar:SetAllPoints()

  row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")

  row.iconHolder = CreateFrame("Frame", nil, row)
  row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
  row.icon:SetAllPoints()

  row.overlay = CreateFrame("Frame", nil, row)
  row.overlay:SetAllPoints()
  row.overlay:SetFrameLevel(row:GetFrameLevel() + 15)

  row.labelText = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.timerText = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.stackText = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")

  row:EnableMouse(false)
  row.iconHolder:EnableMouse(false)
  AttachAuraBarTooltipHandlers(row)
  AttachAuraBarTooltipHandlers(row.iconHolder)

  self.rows[index] = row
  return row
end

function AuraBarListRegion:LayoutRows(aura, count)
  local spacing = tonumber(aura.display.spacing or 4) or 4
  local growth = tostring(aura.display.growth or "DOWN")
  local width = self.frame:GetWidth() or aura.display.width or 220
  local height = self.frame:GetHeight() or aura.display.height or 24
  local previous = nil

  for index = 1, count do
    local row = self:EnsureRow(index)
    row:ClearAllPoints()
    row:SetSize(width, height)

    if previous == nil then
      row:SetAllPoints(self.frame)
    elseif growth == "LEFT" then
      row:SetPoint("TOPRIGHT", previous, "TOPLEFT", -spacing, 0)
    elseif growth == "UP" then
      row:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, spacing)
    elseif growth == "RIGHT" then
      row:SetPoint("TOPLEFT", previous, "TOPRIGHT", spacing, 0)
    else
      row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing)
    end

    previous = row
  end

  for index = count + 1, #self.rows do
    self.rows[index]:Hide()
  end
end

function AuraBarListRegion:ApplyRow(aura, row, entry)
  local display = aura.display or {}
  local orientation = display.orientation or "HORIZONTAL"
  local backgroundColor = TintColor(display.backgroundColor, display.backgroundGamma or 1)
  local color = display.color or { r = 0.1, g = 0.6, b = 1, a = 1 }
  local now = GetTime()
  local isVisuallyPermanent = entry and IsAuraVisuallyPermanent(entry)
  local barAlpha = (entry and isVisuallyPermanent == true)
    and GetPermanentAlpha(display)
    or 1

  row:Show()
  row:SetAlpha(1)
  row.bar:SetAlpha(barAlpha)
  row.iconHolder:SetAlpha(1)
  row.overlay:SetAlpha(1)
  row.bar:SetStatusBarTexture(GetTexturePath(display.barTexture))
  row.bar:SetOrientation(orientation)
  if row.bar.SetRotatesTexture then
    row.bar:SetRotatesTexture(orientation ~= "VERTICAL")
  end
  if row.bar.SetReverseFill then
    row.bar:SetReverseFill(display.reverse == true)
  end
  row.bar:SetStatusBarColor(color.r or 0.1, color.g or 0.6, color.b or 1, color.a == nil and 1 or color.a)
  row.bg:SetShown(display.showBackground ~= false)
  row.bg:SetVertexColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a)

  local tooltipsEnabled = BaseRegion:CanMove(aura) ~= true
  row._popAurasAuraEntry = tooltipsEnabled and entry or nil

  if display.icon ~= false then
    local iconSize = display.iconMatchBarSize and ((orientation == "VERTICAL") and row:GetWidth() or row:GetHeight()) or (display.iconSize or row:GetHeight())
    row.iconHolder:SetSize(iconSize, iconSize)
    ApplyIconPlacement(row.iconHolder, row, display)
    row.icon:SetTexture(Spells:ResolveDisplayIcon(aura, entry))
    row.iconHolder._popAurasAuraEntry = tooltipsEnabled and entry or nil
    row.iconHolder:EnableMouse(tooltipsEnabled)
    row.iconHolder:Show()
  else
    row.iconHolder._popAurasAuraEntry = nil
    row.iconHolder:EnableMouse(false)
    row.iconHolder:Hide()
  end
  row:EnableMouse(tooltipsEnabled)

  row.labelText:SetShown(display.showName == true)
  row.timerText:SetShown(display.showTimer == true)
  row.stackText:SetShown(display.showStacks == true)

  Fonts.ApplyStyle(row.labelText, display.nameFontStyle, display.nameFontSize)
  Fonts.ApplyStyle(row.timerText, display.timerFontStyle, display.timerFontSize)
  Fonts.ApplyStyle(row.stackText, display.stacksFontStyle, display.stacksFontSize)
  Colors.Apply(row.labelText, display.nameColor)
  Colors.Apply(row.timerText, display.timerColor)
  Colors.Apply(row.stackText, display.stacksColor)

  PositionText(row.labelText, row, row.iconHolder, display.nameAnchor, display.nameOffsetX, display.nameOffsetY)
  PositionText(row.timerText, row, row.iconHolder, display.timerAnchor, display.timerOffsetX, display.timerOffsetY)
  PositionText(row.stackText, row, row.iconHolder, display.stacksAnchor, display.stacksOffsetX, display.stacksOffsetY)

  ApplyTextRotation(row.labelText, display.nameRotation)
  ApplyTextRotation(row.timerText, display.timerRotation)
  ApplyTextRotation(row.stackText, display.stacksRotation)

  if aura.kind == "aura_bar_list" then
    row.labelText:SetText(ResolveAuraBarLabel(entry))
  else
    row.labelText:SetText(ns.TextResolver:Resolve(aura.text.label, entry, aura))
  end
  if aura.kind == "aura_bar_list" then
    ApplyAuraBarTimerText(row.timerText, aura, entry, now)
    ApplyAuraBarStackText(row.stackText, entry)
  else
    row.timerText:SetText(GetEntryTimerText(aura, entry, now))
    ApplyStackText(row.stackText, entry)
  end

  local remaining = math.max(0, (entry.expirationTime or 0) - now)
  local hasNumericTimer = isVisuallyPermanent ~= true
    and entry.progressType == "timed"
    and (((entry.expirationTime or 0) > now) or ((entry.duration or 0) > 0))
  local total = hasNumericTimer and ((entry.duration or 0) > 0 and entry.duration or remaining) or 1
  local durationObject = aura.kind == "aura_bar_list" and GetLiveAuraDurationObject(entry) or entry.durationObject
  if durationObject and isVisuallyPermanent ~= true and row.bar.SetTimerDuration then
    local direction = STATUS_BAR_DIRECTION and (
      display.reverse == true
        and STATUS_BAR_DIRECTION.ElapsedTime
        or STATUS_BAR_DIRECTION.RemainingTime
    ) or nil
    local interpolation = STATUS_BAR_INTERPOLATION and STATUS_BAR_INTERPOLATION.Immediate or nil
    row.bar:SetMinMaxValues(0, 1)
    if interpolation ~= nil or direction ~= nil then
      row.bar:SetTimerDuration(durationObject, interpolation, direction)
    else
      row.bar:SetTimerDuration(durationObject)
    end
  else
    row.bar:SetMinMaxValues(0, math.max(0.001, total))
    if hasNumericTimer then
      row.bar:SetValue(display.reverse == true and math.max(0, total - remaining) or remaining)
    else
      row.bar:SetValue(1)
    end
  end
end

function AuraBarListRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state

  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)
  BaseRegion:ApplyCommonAppearance(aura, self.frame, state)

  local entries = state and state.source == "preview"
    and BuildPreviewEntries()
    or (UnitAuraList and UnitAuraList.Collect and UnitAuraList:Collect(GetTrigger(aura)) or {})

  self.entries = entries or {}
  self:LayoutRows(aura, #self.entries)

  for index, entry in ipairs(self.entries) do
    local row = self:EnsureRow(index)
    self:ApplyRow(aura, row, entry)
  end

  if #self.entries == 0 then
    self.frame:Hide()
    ns.runtime:UnregisterTimedRegion(aura.id)
    return
  end

  local hasTimedEntry = false
  for _, entry in ipairs(self.entries) do
    if HasLiveTimer(entry, GetTime()) then
      hasTimedEntry = true
      break
    end
  end

  if hasTimedEntry then
    ns.runtime:RegisterTimedRegion(aura.id, self)
  else
    ns.runtime:UnregisterTimedRegion(aura.id)
  end
end

function AuraBarListRegion:OnTimerUpdate(now)
  local aura = self.currentAura
  if not aura or not self.entries or #self.entries == 0 then
    return false
  end

  local hasLiveEntry = false
  for index, entry in ipairs(self.entries) do
    local row = self.rows[index]
    if row and row:IsShown() then
      local isVisuallyPermanent = IsAuraVisuallyPermanent(entry)
      if isVisuallyPermanent then
        row.bar:SetAlpha(GetPermanentAlpha(aura.display or {}))
        if aura.kind == "aura_bar_list" then
          ApplyAuraBarTimerText(row.timerText, aura, entry, now)
          ApplyAuraBarStackText(row.stackText, entry)
        end
      elseif entry.progressType == "timed" or entry.durationObject ~= nil then
        local remaining = math.max(0, (entry.expirationTime or 0) - now)
        local total = (entry.duration or 0) > 0 and entry.duration or math.max(1, remaining)
        row.bar:SetAlpha(1)
        local durationObject = aura.kind == "aura_bar_list" and GetLiveAuraDurationObject(entry) or entry.durationObject
        if durationObject == nil then
          row.bar:SetMinMaxValues(0, math.max(0.001, total))
          row.bar:SetValue(aura.display.reverse == true and math.max(0, total - remaining) or remaining)
        elseif row.bar.SetTimerDuration then
          local direction = STATUS_BAR_DIRECTION and (
            aura.display.reverse == true
              and STATUS_BAR_DIRECTION.ElapsedTime
              or STATUS_BAR_DIRECTION.RemainingTime
          ) or nil
          local interpolation = STATUS_BAR_INTERPOLATION and STATUS_BAR_INTERPOLATION.Immediate or nil
          if interpolation ~= nil or direction ~= nil then
            row.bar:SetTimerDuration(durationObject, interpolation, direction)
          else
            row.bar:SetTimerDuration(durationObject)
          end
        end
        if aura.kind == "aura_bar_list" then
          ApplyAuraBarTimerText(row.timerText, aura, entry, now)
          ApplyAuraBarStackText(row.stackText, entry)
        else
          row.timerText:SetText(GetEntryTimerText(aura, entry, now))
        end
        if HasLiveTimer(entry, now) then
          hasLiveEntry = true
        end
      end
    end
  end

  if not hasLiveEntry then
    ns.runtime:RefreshAura(aura.id)
    return false
  end

  return true
end
