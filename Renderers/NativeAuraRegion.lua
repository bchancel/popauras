local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts
local Media = ns.util.Media
local Frames = ns.util.Frames

local Region = {}
ns.renderers.NativeAuraRegion = Region

local EMPTY = {}
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

local function GetTrigger(aura)
  local found
  for _, trigger in ipairs(aura and aura.triggers or EMPTY) do
    if trigger.enabled ~= false then
      if found then return nil end
      found = trigger
    end
  end
  return found
end

local function GetSpellMap(trigger)
  local result = {}
  local function add(value)
    for _, spellID in ipairs(ns.util.Spells:GetAuraSpellIDs(value)) do
      result[spellID] = true
    end
  end
  add(trigger and trigger.spellId)
  for _, value in ipairs(type(trigger and trigger.spellIDs) == "table" and trigger.spellIDs or EMPTY) do add(value) end
  local names = type(trigger and trigger.spellNames) == "table" and trigger.spellNames
    or type(trigger and trigger.exactSpellNames) == "table" and trigger.exactSpellNames or EMPTY
  for _, name in ipairs(names) do add(ns.util.Spells:ResolveConfiguredSpellID(name)) end
  return result
end

local function GetCandidateFilters(trigger)
  return {
    includeSpellIDs = GetSpellMap(trigger),
    isFromPlayerOrPlayerPet = trigger and trigger.castByMe == true and true or nil,
  }
end

local function GetCDMSpellIDs(trigger)
  local result, seen = {}, {}
  local function add(value)
    value = ns.SafeValues:Number(value)
    if value and value > 0 and not seen[value] then
      seen[value] = true
      result[#result + 1] = value
    end
  end
  add(trigger and trigger.spellId)
  for _, value in ipairs(type(trigger and trigger.spellIDs) == "table" and trigger.spellIDs or EMPTY) do
    add(value)
  end
  local names = type(trigger and trigger.spellNames) == "table" and trigger.spellNames
    or type(trigger and trigger.exactSpellNames) == "table" and trigger.exactSpellNames or EMPTY
  for _, name in ipairs(names) do add(ns.util.Spells:ResolveConfiguredSpellID(name)) end
  for spellID in pairs(GetSpellMap(trigger)) do
    add(spellID)
  end
  table.sort(result)
  return result
end

local function GetCandidateSignature(trigger)
  local spellIDs = {}
  for spellID in pairs(GetSpellMap(trigger)) do
    spellIDs[#spellIDs + 1] = spellID
  end
  table.sort(spellIDs)
  return string.format(
    "%s|%s",
    trigger and trigger.castByMe == true and "player" or "any",
    table.concat(spellIDs, ",")
  )
end

function Region:CanHandle(aura)
  if not ns.NativeAuras or not ns.NativeAuras:IsAvailable() then return false end
  if not aura or (aura.kind ~= "icon" and aura.kind ~= "bar") then return false end
  local trigger = GetTrigger(aura)
  if not trigger or trigger.type ~= "aura" or trigger.auraFilter == "missing" then return false end
  local unit = trigger.unit or "player"
  local helpful = trigger.auraType ~= "debuff"
  if unit ~= "player" and unit ~= "target" then return false end
  if (unit == "player" and not helpful) or (unit == "target" and helpful) then return false end
  return next(GetSpellMap(trigger)) ~= nil
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

local oppositePoints = {
  LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP",
  TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT",
  BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT", CENTER = "CENTER",
}

local function ApplyRotation(fontString, degrees)
  if fontString and fontString.SetRotation then
    fontString:SetRotation(math.rad(tonumber(degrees or 0) or 0))
  end
end

local function GetPrimarySpellID(trigger)
  local spellID = ns.SafeValues:Number(trigger and trigger.spellId)
  if spellID and spellID > 0 then return spellID end
  for _, value in ipairs(type(trigger and trigger.spellIDs) == "table" and trigger.spellIDs or EMPTY) do
    spellID = ns.SafeValues:Number(value)
    if spellID and spellID > 0 then return spellID end
  end
  local names = type(trigger and trigger.spellNames) == "table" and trigger.spellNames
    or type(trigger and trigger.exactSpellNames) == "table" and trigger.exactSpellNames or EMPTY
  for _, name in ipairs(names) do
    spellID = ns.util.Spells:ResolveConfiguredSpellID(name)
    if spellID and spellID > 0 then return spellID end
  end
  return 0
end

local function GetConfiguredSpellName(aura)
  local spellID = GetPrimarySpellID(GetTrigger(aura))
  if spellID > 0 and C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and not ns.SafeValues:IsSecret(info) and type(info) == "table" then
      local name = ns.SafeValues:String(info.name)
      if name then return name end
    end
  end
  return aura.name or "Aura"
end

function Region:StyleFallback(aura, isPreview, state)
  local fallback = self.fallback
  if not fallback then return end
  self:ClearCDMTimer()
  local display = aura.display or {}
  local trigger = GetTrigger(aura)
  local spellID = GetPrimarySpellID(trigger)
  local spellName, spellIcon
  if spellID > 0 and C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and not ns.SafeValues:IsSecret(info) and type(info) == "table" then
      spellName = ns.SafeValues:String(info.name)
      spellIcon = ns.SafeValues:Number(info.iconID)
    end
  end
  spellName = isPreview and state and state.name ~= "" and state.name or spellName or aura.name or "Aura"
  spellIcon = ns.util.Spells:ResolveDisplayIcon(aura,
    isPreview and state or { spellId = spellID, icon = spellIcon })
  fallback:SetFrameLevel(self.frame:GetFrameLevel() + (isPreview and 10 or 1))
  local fallbackWidth, fallbackHeight = self.frame:GetWidth(), self.frame:GetHeight()
  Frames.SetExplicitBounds(fallback.bar, fallback, fallbackWidth, fallbackHeight)
  Frames.SetExplicitBounds(fallback.presentation, fallback, fallbackWidth, fallbackHeight)
  fallback.bar:SetFrameLevel(fallback:GetFrameLevel() + 1)
  fallback.presentation:SetFrameLevel(fallback:GetFrameLevel() + 10)

  if aura.kind == "icon" then
    fallback.bar:Hide()
    fallback.background:Hide()
    fallback.icon:ClearAllPoints()
    fallback.icon:SetAllPoints()
  else
    fallback.bar:Show()
    fallback.bar:SetStatusBarTexture(Media:ResolveStatusBarTexture(display.barTexture))
    fallback.bar:SetOrientation(display.orientation or "HORIZONTAL")
    if fallback.bar.SetRotatesTexture then
      fallback.bar:SetRotatesTexture((display.orientation or "HORIZONTAL") == "VERTICAL")
    end
    if fallback.bar.SetReverseFill then fallback.bar:SetReverseFill(display.reverse == true) end
    local remaining = isPreview and state and state.progressType == "timed"
      and math.max(0, (state.expirationTime or 0) - GetTime()) or 1
    local total = isPreview and state and state.progressType == "timed"
      and math.max(0.001, state.duration > 0 and state.duration or remaining) or 1
    fallback.bar:SetMinMaxValues(0, total)
    fallback.bar:SetValue(display.reverse == true and not fallback.bar.SetReverseFill
      and math.max(0, total - remaining) or remaining)
    local color = display.readyLook == true and (display.readyColor or display.color) or display.color
    fallback.bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    fallback.background:SetShown(display.showBackground ~= false)
    fallback.background:SetVertexColor(display.backgroundColor.r, display.backgroundColor.g,
      display.backgroundColor.b, display.backgroundColor.a or 1)
    local width, height = self.frame:GetWidth(), self.frame:GetHeight()
    local iconSize = display.iconMatchBarSize and ((display.orientation or "HORIZONTAL") == "VERTICAL" and width or height)
      or tonumber(display.iconSize or height) or height
    fallback.icon:SetSize(iconSize, iconSize)
    fallback.icon:ClearAllPoints()
    local anchor = display.iconAnchor or "LEFT"
    if anchor == "LEFT_OUTSIDE" then anchor = "LEFT" end
    if anchor == "RIGHT_OUTSIDE" then anchor = "RIGHT" end
    fallback.icon:SetPoint(oppositePoints[anchor] or "CENTER", fallback, anchor,
      tonumber(display.iconOffsetX or 0) or 0, tonumber(display.iconOffsetY or 0) or 0)
  end

  fallback.icon:SetTexture(spellIcon)
  fallback.icon:SetShown(display.icon ~= false)
  local nameOverride = ns.SafeValues:String(aura.text and aura.text.nameOverride)
  local labelTemplate = ns.SafeValues:String(aura.text and aura.text.label) or "%n"
  local label = nameOverride and nameOverride ~= "" and nameOverride or labelTemplate
  fallback.nameText:SetText((label:gsub("%%n", spellName)))
  fallback.nameText:SetShown(display.showName == true)
  fallback.timerText:SetText(isPreview and ns.TextResolver:GetTimerText(state, aura)
    or (display.readyLook == true and (display.readyText or "Ready") or ""))
  fallback.timerText:SetShown(display.showTimer == true)
  local stacks = isPreview and state and tonumber(state.stacks or 0) or 0
  fallback.countText:SetText(stacks > 0 and tostring(stacks) or "")
  fallback.countText:SetShown(display.showStacks == true)
  Fonts.ApplyStyle(fallback.nameText, display.nameFontStyle, display.nameFontSize)
  Fonts.ApplyStyle(fallback.timerText, display.timerFontStyle, display.timerFontSize)
  Fonts.ApplyStyle(fallback.countText, display.stacksFontStyle, display.stacksFontSize)
  Colors.Apply(fallback.nameText, display.nameColor)
  Colors.Apply(fallback.timerText, display.readyLook == true and display.readyTextColor or display.timerColor)
  Colors.Apply(fallback.countText, display.stacksColor)
  PositionText(fallback.nameText, fallback.presentation, fallback.icon,
    display.nameAnchor, display.nameOffsetX, display.nameOffsetY)
  PositionText(fallback.timerText, fallback.presentation, fallback.icon,
    display.timerAnchor, display.timerOffsetX, display.timerOffsetY)
  PositionText(fallback.countText, fallback.presentation, fallback.icon,
    display.stacksAnchor, display.stacksOffsetX, display.stacksOffsetY)
  Frames.ConfigureBarTextBounds(fallback.nameText, fallback.timerText, fallback.presentation,
    display, fallbackWidth, display.orientation or "HORIZONTAL")
  local showSwipe = display.swipe == true and (aura.kind == "icon" or display.icon ~= false)
  fallback.cooldown:SetDrawSwipe(showSwipe)
  fallback.cooldown:SetDrawEdge(showSwipe and display.iconCooldownEdge == true)
  fallback.cooldown:SetDrawBling(showSwipe and display.iconCooldownBling == true)
  ApplyRotation(fallback.nameText, display.nameRotation)
  ApplyRotation(fallback.timerText, display.timerRotation)
  ApplyRotation(fallback.countText, display.stacksRotation)
  fallback:SetShown(isPreview == true or (trigger and trigger.showAlways == true))

  self.currentFallbackState = isPreview and state or nil
  if isPreview and state and state.progressType == "timed" and (state.expirationTime or 0) > GetTime() then
    ns.runtime:RegisterTimedRegion(aura.id, self)
  else
    ns.runtime:UnregisterTimedRegion(aura.id)
  end
end

function Region:IsCurrentCDMSource(source, cooldownID, token)
  if self.cdmSource ~= source or self.cdmCooldownID ~= cooldownID or self.cdmBindingToken ~= token then
    return false
  end
  return ns.CooldownManager:GetFrameCooldownID(source) == cooldownID
end

function Region:SetNativeEnabled(enabled)
  if not self.container or not self.container.SetEnabled then return end
  enabled = enabled == true
  if self.nativeEnabled ~= enabled then
    self.container:SetEnabled(enabled)
    self.nativeEnabled = enabled
  end
end

function Region:SetNativeSuppressed(suppressed)
  if not self.container then return end
  suppressed = suppressed == true
  if suppressed then
    if self.nativeSuppressed ~= true then
      -- SetEnabled(false) stops parsing before the secure slot necessarily
      -- releases its current forbidden AuraButton. Keep it enabled long
      -- enough to apply a match-nothing filter and let Blizzard clear the
      -- assignment, then disable event processing.
      self:SetNativeEnabled(true)
      self.container:SetAuraSlotCandidateFilters("popauras", EMPTY_CANDIDATE_FILTERS)
      self.nativeSuppressed = true
    end
    self:SetNativeEnabled(false)
    return
  end

  if self.nativeSuppressed == true then
    local trigger = GetTrigger(self.currentAura)
    if trigger then
      self.container:SetAuraSlotCandidateFilters("popauras", GetCandidateFilters(trigger))
      self.nativeCandidateSignature = GetCandidateSignature(trigger)
    end
    self.nativeSuppressed = false
  end
  self:SetNativeEnabled(true)
end

function Region:SetLayoutVisible(visible)
  visible = self.loadMatched == true and visible == true
  if self.layoutVisible == visible then return end
  self.layoutVisible = visible
  local aura = self.currentAura
  if aura and aura.parentId and ns.runtime and ns.runtime.ScheduleGroupLayoutRefresh then
    ns.runtime:ScheduleGroupLayoutRefresh(aura.parentId)
  end
end

function Region:LogPresentationDebug(reason)
  local aura = self.currentAura
  local trigger = GetTrigger(aura)
  if not trigger or trigger.debug ~= true or not ns.Debug then return end
  local sourceKind = self.cdmSource and (self.cdmSourceBar and "cdm-bar" or "cdm-icon") or "none"
  local message = string.format("%s loaded=%s source=%s mode=%s layout=%s native=%s timer=%s",
    aura.name or "Aura", tostring(self.loadMatched == true), sourceKind, reason,
    tostring(self.layoutVisible == true), self.nativeSuppressed == true and "suppressed" or "enabled",
    self.cdmDurationStatus or "not-requested")
  if self.lastPresentationDebug == message then return end
  self.lastPresentationDebug = message
  ns.Debug:Log("Aura render", message)
end

function Region:ClearCDMTimer()
  if ns.TimerPresenter then ns.TimerPresenter:UnbindText(self.fallback.timerText) end
  self.fallback.cooldown:Clear()
  self.fallback.bar:SetMinMaxValues(0, 1)
  self.fallback.bar:SetValue(0)
end

function Region:SyncCDMDuration(source)
  self.cdmDurationStatus = "duration-api-unavailable"
  if type(source.GetAuraSpellInstanceID) ~= "function"
      or not C_UnitAuras or not C_UnitAuras.GetAuraDuration then return false end
  local okInstance, instanceID = pcall(source.GetAuraSpellInstanceID, source)
  self.cdmDurationStatus = okInstance and ns.SafeValues:IsSecret(instanceID)
    and "instance-restricted" or "instance-unavailable"
  instanceID = okInstance and ns.SafeValues:Number(instanceID) or nil
  if not instanceID then return false end
  local trigger = GetTrigger(self.currentAura)
  local okDuration, object = pcall(C_UnitAuras.GetAuraDuration, trigger.unit or "player", instanceID)
  self.cdmDurationStatus = "duration-unavailable"
  if not okDuration or ns.SafeValues:IsSecret(object) or object == nil then return false end
  self.cdmDurationStatus = "duration-object"

  -- Keep the opaque object entirely on the presentation path. Blizzard drives
  -- the bar, swipe, and text; addon Lua never reads its restricted timing.
  local display = self.currentAura.display or {}
  if not self.cdmSourceBar then
    local interpolation = Enum.StatusBarInterpolation.Immediate
    self.fallback.bar:SetTimerDuration(object, interpolation, Enum.StatusBarTimerDirection.RemainingTime)
    if ns.TimerPresenter and display.showTimer == true then
      ns.TimerPresenter:BindText(self.fallback.timerText, object, {
        formatter = GetDecimalFormatter(display.timerDecimals),
        expiredText = "", zeroDurationText = "",
      })
    end
  end
  self.fallback.cooldown:SetCooldownFromDurationObject(object, true)
  return true
end

function Region:SyncCDMRenderedState()
  local source = self.cdmSource
  local sourceBar = self.cdmSourceBar
  if not source or self.cdmMode ~= true then return false end
  local hasDuration = not sourceBar and self:SyncCDMDuration(source)
  if not sourceBar and not hasDuration then return false end
  if sourceBar then
    self.cdmDurationStatus = "bar-widgets"
    local okRange, minimum, maximum = pcall(sourceBar.GetMinMaxValues, sourceBar)
    if okRange then self.fallback.bar:SetMinMaxValues(minimum, maximum) end
    local okValue, value = pcall(sourceBar.GetValue, sourceBar)
    if okValue then
      -- These widget setters explicitly accept secret arguments. Pass the
      -- presentation values directly to widgets without inspecting them.
      self.fallback.bar:SetValue(value)
      if self.currentAura.display and self.currentAura.display.showTimer == true then
        self.fallback.timerText:SetFormattedText(self.cdmTimerFormat or "%.1f", value)
      end
    end
  end

  local sourceDuration = self.cdmSourceDuration
  if sourceDuration and type(sourceDuration.GetText) == "function" then
    local okShown, shown = pcall(sourceDuration.IsShown, sourceDuration)
    shown = okShown and ns.SafeValues:Boolean(shown) or nil
    if shown == true then
      local okText, text = pcall(sourceDuration.GetText, sourceDuration)
      if okText then self.fallback.timerText:SetText(text) end
    end
  end
  local sourceApplications = self.cdmSourceApplications
  if sourceApplications and type(sourceApplications.GetText) == "function" then
    local okText, text = pcall(sourceApplications.GetText, sourceApplications)
    if okText then self.fallback.countText:SetText(text) end
  end
  return true
end

function Region:SyncCDMSource()
  local source = self.cdmSource
  if not source or not self.currentAura then return false end
  if ns.CooldownManager:GetFrameCooldownID(source) ~= self.cdmCooldownID then
    self:ClearCDMTimer()
    self.fallback:Hide()
    self:SetLayoutVisible(false)
    self:LogPresentationDebug("source-recycled")
    return self.cdmMode == true
  end

  if self.cdmMode ~= true then return false end
  self:SetNativeSuppressed(self.nativeDurationRequired ~= true)
  local okActive, active = pcall(source.IsActive, source)
  active = okActive and ns.SafeValues:Boolean(active) or nil
  if active ~= true then
    local trigger = GetTrigger(self.currentAura)
    local showAlways = trigger and trigger.showAlways == true
    self:SetLayoutVisible(showAlways)
    if self.cdmPresentedActive ~= false then self:StyleFallback(self.currentAura, false) end
    self.cdmPresentedActive = false
    self.fallback:SetShown(showAlways)
    self:LogPresentationDebug("inactive-or-unavailable")
    return self.cdmMode == true
  end

  local trigger = GetTrigger(self.currentAura)
  local requiredUnit = trigger and (trigger.unit or "player") or "player"
  local okUnit, sourceUnit = pcall(source.GetAuraDataUnit, source)
  sourceUnit = okUnit and ns.SafeValues:String(sourceUnit) or nil
  if sourceUnit ~= requiredUnit then
    local showAlways = trigger and trigger.showAlways == true
    self:SetLayoutVisible(showAlways)
    if self.cdmPresentedActive ~= false then self:StyleFallback(self.currentAura, false) end
    self.cdmPresentedActive = false
    self.fallback:SetShown(showAlways)
    self:LogPresentationDebug("unit-mismatch")
    return self.cdmMode == true
  end
  self:SetLayoutVisible(true)
  self.cdmPresentedActive = true
  if self.nativeDurationRequired == true then
    self.fallback:Hide()
    self:LogPresentationDebug("native-duration")
    return true
  end

  local display = self.currentAura.display or {}
  local color = display.color or { r = 1, g = 1, b = 1, a = 1 }
  self.fallback.bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
  Colors.Apply(self.fallback.timerText, display.timerColor)
  if not self:SyncCDMRenderedState() then
    self:ClearCDMTimer()
    self.fallback:Hide()
    -- CDM active state remains useful even when its instance ID cannot be
    -- passed to GetAuraDuration. Retain native presentation for this region
    -- from now on, rather than disabling both renderers or oscillating as
    -- combat restrictions change. Only Blizzard's exact slot owns duration.
    if self.container then
      self.nativeDurationRequired = true
      self:SetNativeSuppressed(false)
    end
    self:LogPresentationDebug(self.container and "native-duration" or "native-unavailable")
    return true
  end
  self.fallback:Show()
  self:LogPresentationDebug("cdm-duration")
  return true
end

function Region:BindCDMSource(source, cooldownID)
  if self.cdmSource == source and self.cdmCooldownID == cooldownID then return end
  self:ClearCDMTimer()
  self.cdmMode = false
  self.cdmPresentedActive = nil
  self.fallback:Hide()
  self.cdmBindingToken = (self.cdmBindingToken or 0) + 1
  local token = self.cdmBindingToken
  self.cdmSource = source
  self.cdmCooldownID = cooldownID
  self.cdmSourceBar = nil
  self.cdmSourceDuration = nil
  self.cdmSourceApplications = nil
  if self.currentAura and self.currentAura.display
      and self.currentAura.display.hideCDMIcon == true
      and ns.CooldownManager and ns.CooldownManager.ScheduleVisibilityOverrideSync then
    ns.CooldownManager:ScheduleVisibilityOverrideSync()
  end
  if not source or not cooldownID then
    self.cdmMode = false
    return
  end

  local sourceBar
  if type(source.GetBarFrame) == "function" then
    local okBar, bar = pcall(source.GetBarFrame, source)
    if okBar then sourceBar = bar end
  end
  if not sourceBar and (type(source.GetAuraSpellInstanceID) ~= "function"
      or not C_UnitAuras or not C_UnitAuras.GetAuraDuration
      or not self.fallback.bar.SetTimerDuration) then return end
  self.cdmSourceBar = sourceBar
  -- Select one authority as soon as a compatible tracked source is bound,
  -- including while inactive. Combat must not switch native/CDM ownership.
  self.cdmMode = true

  if type(source.GetDurationFontString) == "function" then
    local okDuration, duration = pcall(source.GetDurationFontString, source)
    if okDuration then self.cdmSourceDuration = duration end
  end
  if type(source.GetApplicationsFontString) == "function" then
    local okApplications, applications = pcall(source.GetApplicationsFontString, source)
    if okApplications then self.cdmSourceApplications = applications end
  end

  hooksecurefunc(source, "SetIsActive", function(owner)
    if self:IsCurrentCDMSource(owner, cooldownID, token) then self:SyncCDMSource() end
  end)
  if sourceBar then
    hooksecurefunc(sourceBar, "SetMinMaxValues", function(_, minimum, maximum)
      if self:IsCurrentCDMSource(source, cooldownID, token) and self.cdmMode == true then
        self.fallback.bar:SetMinMaxValues(minimum, maximum)
      end
    end)
    hooksecurefunc(sourceBar, "SetValue", function(_, value)
      if self:IsCurrentCDMSource(source, cooldownID, token) and self.cdmMode == true then
        self.fallback.bar:SetValue(value)
        if self.currentAura and self.currentAura.display and self.currentAura.display.showTimer == true then
          self.fallback.timerText:SetFormattedText(self.cdmTimerFormat or "%.1f", value)
        end
      end
    end)
  end
  if self.cdmSourceDuration then
    hooksecurefunc(self.cdmSourceDuration, "SetText", function(_, text)
      if self:IsCurrentCDMSource(source, cooldownID, token) and self.cdmMode == true then
        self.fallback.timerText:SetText(text)
      end
    end)
  end
  if self.cdmSourceApplications then
    hooksecurefunc(self.cdmSourceApplications, "SetText", function(_, text)
      if self:IsCurrentCDMSource(source, cooldownID, token) and self.cdmMode == true then
        self.fallback.countText:SetText(text)
      end
    end)
  end
end

function Region:InitializeButton(button)
  self.button = button
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.bar = CreateFrame("StatusBar", nil, button)
  button.bar:SetAllPoints()
  button.background = button.bar:CreateTexture(nil, "BACKGROUND")
  button.background:SetAllPoints()
  button.background:SetTexture("Interface\\Buttons\\WHITE8x8")
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetFrameLevel(button:GetFrameLevel() + 2)
  button.cooldown:EnableMouse(false)
  if button.cooldown.SetHideCountdownNumbers then
    button.cooldown:SetHideCountdownNumbers(true)
  end
  button.presentation = CreateFrame("Frame", nil, button)
  button.presentation:SetFrameLevel(button:GetFrameLevel() + 10)
  button.nameText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.timerText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.countText = button.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  self:StyleButton(self.currentAura)
  if self.container then button:SetAllPoints(self.container) end
end

function Region:StyleButton(aura)
  local button = self.button
  if not button or not aura then return end
  local display = aura.display or {}
  local width = tonumber(display.width or aura.position and aura.position.width or 56) or 56
  local height = tonumber(display.height or aura.position and aura.position.height or 56) or 56
  button:SetSize(width, height)
  Frames.SetExplicitBounds(button.bar, button, width, height)
  Frames.SetExplicitBounds(button.presentation, button, width, height)

  if aura.kind == "icon" then
    button.icon:ClearAllPoints()
    button.icon:SetAllPoints()
    button.icon:SetShown(display.icon ~= false)
    button.bar:Hide()
    button.background:Hide()
  else
    button.bar:Show()
    button.bar:SetStatusBarTexture(Media:ResolveStatusBarTexture(display.barTexture))
    button.bar:SetOrientation(display.orientation or "HORIZONTAL")
    if button.bar.SetRotatesTexture then button.bar:SetRotatesTexture((display.orientation or "HORIZONTAL") == "VERTICAL") end
    if button.bar.SetReverseFill then button.bar:SetReverseFill(display.reverse == true) end
    button.bar:SetStatusBarColor(display.color.r, display.color.g, display.color.b, display.color.a or 1)
    button.background:SetShown(display.showBackground ~= false)
    button.background:SetVertexColor(display.backgroundColor.r, display.backgroundColor.g,
      display.backgroundColor.b, display.backgroundColor.a or 1)
    local iconSize = display.iconMatchBarSize and ((display.orientation or "HORIZONTAL") == "VERTICAL" and width or height)
      or tonumber(display.iconSize or height) or height
    button.icon:SetSize(iconSize, iconSize)
    button.icon:ClearAllPoints()
    local anchor = display.iconAnchor or "LEFT"
    if anchor == "LEFT_OUTSIDE" then anchor = "LEFT" end
    if anchor == "RIGHT_OUTSIDE" then anchor = "RIGHT" end
    button.icon:SetPoint(oppositePoints[anchor] or "CENTER", button, anchor,
      tonumber(display.iconOffsetX or 0) or 0, tonumber(display.iconOffsetY or 0) or 0)
    button.icon:SetShown(display.icon ~= false)
  end

  button.cooldown:ClearAllPoints()
  button.cooldown:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 0, 0)
  button.cooldown:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 0, 0)

  button.nameText:SetShown(display.showName == true)
  button.timerText:SetShown(display.showTimer == true)
  button.countText:SetShown(display.showStacks == true)
  Fonts.ApplyStyle(button.nameText, display.nameFontStyle, display.nameFontSize)
  Fonts.ApplyStyle(button.timerText, display.timerFontStyle, display.timerFontSize)
  Fonts.ApplyStyle(button.countText, display.stacksFontStyle, display.stacksFontSize)
  Colors.Apply(button.nameText, display.nameColor)
  Colors.Apply(button.timerText, display.timerColor)
  Colors.Apply(button.countText, display.stacksColor)
  PositionText(button.nameText, button.presentation, button.icon, display.nameAnchor, display.nameOffsetX, display.nameOffsetY)
  PositionText(button.timerText, button.presentation, button.icon, display.timerAnchor, display.timerOffsetX, display.timerOffsetY)
  PositionText(button.countText, button.presentation, button.icon, display.stacksAnchor, display.stacksOffsetX, display.stacksOffsetY)
  Frames.ConfigureBarTextBounds(button.nameText, button.timerText, button.presentation, display, width, display.orientation or "HORIZONTAL")
  ApplyRotation(button.nameText, display.nameRotation)
  ApplyRotation(button.timerText, display.timerRotation)
  ApplyRotation(button.countText, display.stacksRotation)
  if button.icon.SetDesaturated then button.icon:SetDesaturated(display.desaturate == true) end

  local showIconCooldown = display.swipe == true and (aura.kind == "icon" or display.icon ~= false)
  if button.cooldown.SetDrawSwipe then button.cooldown:SetDrawSwipe(showIconCooldown) end
  if button.cooldown.SetDrawEdge then button.cooldown:SetDrawEdge(showIconCooldown and display.iconCooldownEdge == true) end
  if button.cooldown.SetDrawBling then button.cooldown:SetDrawBling(showIconCooldown and display.iconCooldownBling == true) end

  local direction = Enum and Enum.StatusBarTimerDirection and (
    display.reverse == true and Enum.StatusBarTimerDirection.ElapsedTime
      or Enum.StatusBarTimerDirection.RemainingTime) or nil
  local interpolation = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or nil
  local overrideTexture = ns.util.Spells:GetSpellTextureByOverride(display.iconOverrideId, display.iconOverrideName)
  if overrideTexture then
    button:ClearIcon()
    button.icon:SetTexture(overrideTexture)
  else
    button:SetIcon(button.icon)
  end

  local nameOverride = ns.SafeValues:String(aura.text and aura.text.nameOverride)
  local labelTemplate = ns.SafeValues:String(aura.text and aura.text.label) or "%n"
  if (nameOverride and nameOverride ~= "") or labelTemplate ~= "%n" then
    button:ClearSpellName()
    local label = nameOverride and nameOverride ~= "" and nameOverride or labelTemplate
    button.nameText:SetText((label:gsub("%%n", GetConfiguredSpellName(aura))))
  else
    button:SetSpellName(button.nameText)
  end
  button:SetApplicationCount(button.countText)
  button:SetDurationText(button.timerText, {
    formatter = GetDecimalFormatter(display.timerDecimals),
    expiredText = "",
    zeroDurationText = "",
  })
  button:SetDurationCooldown(button.cooldown)
  button:SetDurationBar(button.bar, { direction = direction, interpolation = interpolation })

  local trigger = GetTrigger(aura)
  if trigger and (trigger.unit or "player") == "player" and trigger.auraType ~= "debuff" then
    button:SetCancelAuraButtons("RightButtonUp")
  else
    button:SetCancelAuraButtons(nil)
  end
end

function Region:CreateNative(aura)
  local trigger = GetTrigger(aura)
  local helpful = trigger.auraType ~= "debuff"
  local container = ns.NativeAuras:CreateContainer(self.frame)
  if not container then return false end
  if container.SetParentKey then container:SetParentKey("NativeAuraContainer") end
  if container.SetEnabled then container:SetEnabled(false) end
  self.nativeEnabled = false
  self.nativeSuppressed = false
  container:SetAllPoints()
  container:SetFrameLevel(self.frame:GetFrameLevel() + 5)
  self.container = container
  self.currentAura = aura
  local options = {
    initializeFrame = function(button) self:InitializeButton(button) end,
    candidateFilters = GetCandidateFilters(trigger),
    sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ExpirationOnly or 0,
    sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
  }
  local ok, button = pcall(container.AddAuraSlot, container, "popauras", helpful and "HELPFUL" or "HARMFUL", options)
  if not ok then
    if container.SetEnabled then container:SetEnabled(false) end
    self.container = nil
    self.button = nil
    return false
  end
  self.button = button or self.button
  local unit = trigger.unit or "player"
  container:SetUnit(unit)
  self.nativeUnit = unit
  self.nativeFilterString = helpful and "HELPFUL" or "HARMFUL"
  self.nativeCandidateSignature = GetCandidateSignature(trigger)
  return true
end

function Region:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.isNativeAuraRegion = true
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.frame:SetClipsChildren(false)
  instance.currentAura = aura
  instance.fallback = CreateFrame("Frame", nil, instance.frame)
  instance.fallback:SetAllPoints()
  instance.fallback.bar = CreateFrame("StatusBar", nil, instance.fallback)
  instance.fallback.bar:SetAllPoints()
  instance.fallback.background = instance.fallback.bar:CreateTexture(nil, "BACKGROUND")
  instance.fallback.background:SetAllPoints()
  instance.fallback.background:SetTexture("Interface\\Buttons\\WHITE8x8")
  instance.fallback.presentation = CreateFrame("Frame", nil, instance.fallback)
  instance.fallback.presentation:SetAllPoints()
  instance.fallback.presentation:SetFrameLevel(instance.fallback.bar:GetFrameLevel() + 10)
  instance.fallback.icon = instance.fallback.presentation:CreateTexture(nil, "ARTWORK")
  instance.fallback.cooldown = CreateFrame("Cooldown", nil, instance.fallback.presentation, "CooldownFrameTemplate")
  instance.fallback.cooldown:SetPoint("TOPLEFT", instance.fallback.icon, "TOPLEFT", 0, 0)
  instance.fallback.cooldown:SetPoint("BOTTOMRIGHT", instance.fallback.icon, "BOTTOMRIGHT", 0, 0)
  instance.fallback.cooldown:SetHideCountdownNumbers(true)
  instance.fallback.cooldown:EnableMouse(false)
  instance.fallback.nameText = instance.fallback.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  instance.fallback.timerText = instance.fallback.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  instance.fallback.countText = instance.fallback.presentation:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  instance.fallback:Hide()
  instance:CreateNative(aura)
  return instance
end

function Region:Update(aura, state)
  self.currentAura = aura
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)
  self.frame:EnableMouse(BaseRegion:CanMove(aura))
  self.frame:SetAlpha((aura.display and aura.display.alpha) or 1)
  local trigger = GetTrigger(aura)
  local isPreview = state and state.source == "preview"
  local loadMatched = not state or state.loadMatched ~= false
  self.loadMatched = loadMatched
  if ns.runtime and ns.runtime.SetNativeAuraSourceUnit then
    ns.runtime:SetNativeAuraSourceUnit(
      self,
      loadMatched and not isPreview and trigger and (trigger.unit or "player") or nil)
  end
  if state and state.source == "preview" then
    self:BindCDMSource(nil, nil)
    self:SetLayoutVisible(true)
    self:SetNativeSuppressed(true)
    self:StyleFallback(aura, true, state)
    return
  end
  self:StyleFallback(aura, false)
  if not loadMatched then
    -- The fallback is a normal PopAuras-owned sibling of the forbidden native
    -- container, so it is safe to hide directly. Never let showAlways/Ready
    -- presentation survive a failed load condition.
    self:BindCDMSource(nil, nil)
    self:SetLayoutVisible(false)
    self.fallback:Hide()
    self:SetNativeSuppressed(true)
    self:LogPresentationDebug("unloaded")
    return
  end
  if not self.container then self:CreateNative(aura) end
  if self.container then
    local unit = trigger.unit or "player"
    if self.nativeUnit ~= unit then
      self.container:SetUnit(unit)
      self.nativeUnit = unit
    end

    local filterString = trigger.auraType ~= "debuff" and "HELPFUL" or "HARMFUL"
    if self.nativeFilterString ~= filterString then
      self.container:SetAuraSlotFilterString("popauras", filterString)
      self.nativeFilterString = filterString
    end

    local candidateSignature = GetCandidateSignature(trigger)
    if self.nativeCandidateSignature ~= candidateSignature then
      if self.nativeSuppressed ~= true then
        self.container:SetAuraSlotCandidateFilters("popauras", GetCandidateFilters(trigger))
      end
      self.nativeCandidateSignature = candidateSignature
    end
    -- The AuraButton is styled only by initializeFrame while the slot is being
    -- created. After Blizzard assigns an aura the button may be forbidden, so
    -- Update must never resize or otherwise restyle it.
  end

  local decimals = math.max(0, math.min(2, tonumber(aura.display and aura.display.timerDecimals or 1) or 1))
  self.cdmTimerFormat = "%." .. decimals .. "f"
  local source, cooldownID = ns.CooldownManager:FindAuraStateSource(
    GetCDMSpellIDs(trigger), trigger.unit or "player")
  self:BindCDMSource(source, cooldownID)
  if self:SyncCDMSource() then return end
  -- Without a compatible CDM source, the native container remains authoritative
  -- and intentionally opaque. Preserve its prior layout behavior rather than
  -- trying to observe a forbidden AuraButton.
  if not source then self:SetLayoutVisible(true) end
  self:SetNativeSuppressed(false)
  self:LogPresentationDebug("native-only")
end

function Region:OnTimerUpdate(now)
  local aura = self.currentAura
  local state = self.currentFallbackState
  if not aura or not state or state.source ~= "preview" then
    return false
  end

  local expirationTime = tonumber(state.expirationTime or 0) or 0
  if expirationTime <= now then
    ns.runtime:RefreshAuras({ aura.id })
    return false
  end

  local remaining = math.max(0, expirationTime - now)
  local total = math.max(0.001, tonumber(state.duration or 0) > 0 and state.duration or remaining)
  if aura.kind == "bar" then
    self.fallback.bar:SetMinMaxValues(0, total)
    self.fallback.bar:SetValue(aura.display.reverse == true and not self.fallback.bar.SetReverseFill
      and math.max(0, total - remaining) or remaining)
  end
  if aura.display.showTimer == true then
    self.fallback.timerText:SetText(ns.TextResolver:GetTimerText(state, aura))
  end
  return true
end

function Region:RefreshNativeUnit(unit)
  if self.loadMatched ~= true then return false end
  local trigger = GetTrigger(self.currentAura)
  if not trigger or (trigger.unit or "player") ~= unit then
    return false
  end

  local source, cooldownID = ns.CooldownManager:FindAuraStateSource(GetCDMSpellIDs(trigger), unit)
  self:BindCDMSource(source, cooldownID)
  if self.cdmSource and self:SyncCDMSource() then return true end
  self:SetNativeSuppressed(false)
  if not self.container or self.nativeEnabled ~= true then return false end

  if self.container.UpdateAllAuras then
    self.container:UpdateAllAuras()
    return true
  end
  return false
end

-- Native AuraContainer objects already consume UNIT_AURA themselves. This
-- narrower retry exists only for CDM frames that Blizzard acquires after our
-- initial render, avoiding a duplicate aura-container rebuild on every event.
function Region:RefreshCDMSource(unit)
  if self.loadMatched ~= true then return false end
  local trigger = GetTrigger(self.currentAura)
  if not trigger or (trigger.unit or "player") ~= unit then return false end

  local spellIDs = GetCDMSpellIDs(trigger)
  local source, cooldownID = ns.CooldownManager:FindAuraStateSource(spellIDs, unit)
  if not source and (self.cdmRetryAt == nil or GetTime() >= self.cdmRetryAt) then
    -- A cached miss must not prevent late acquisition. Bound retries for auras
    -- with no CDM entry; UNIT_AURA can otherwise traverse viewers repeatedly.
    self.cdmRetryAt = GetTime() + 0.25
    source, cooldownID = ns.CooldownManager:FindAuraStateSource(spellIDs, unit, true)
  end
  if source and source == self.cdmSource and cooldownID == self.cdmCooldownID
      and self.cdmMode == true then return true end
  self:BindCDMSource(source, cooldownID)
  if self.cdmSource and self:SyncCDMSource() then return true end
  if not source then self:SetLayoutVisible(true) end
  self:SetNativeSuppressed(false)
  return self.cdmSource ~= nil
end

function Region:Release()
  self.loadMatched = false
  if ns.runtime and ns.runtime.SetNativeAuraSourceUnit then
    ns.runtime:SetNativeAuraSourceUnit(self, nil)
  end
  self:SetLayoutVisible(false)
  self.currentFallbackState = nil
  if self.currentAura then ns.runtime:UnregisterTimedRegion(self.currentAura.id) end
  self:BindCDMSource(nil, nil)
  self:SetNativeSuppressed(true)
  self.fallback:Hide()
end
