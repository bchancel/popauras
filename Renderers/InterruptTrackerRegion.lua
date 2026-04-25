local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Fonts = ns.util.Fonts

local InterruptTrackerRegion = {}
ns.renderers.InterruptTrackerRegion = InterruptTrackerRegion

local DEFAULT_READY_COLOR = { r = 0.20, g = 0.95, b = 0.20, a = 1 }
local DEFAULT_BACKGROUND_COLOR = { r = 0.05, g = 0.07, b = 0.10, a = 0.88 }
local DEFAULT_BAR_BACKGROUND_COLOR = { r = 0.09, g = 0.11, b = 0.16, a = 0.94 }
local MAX_BAR_NAME_CHARS = 4

local function GetStatusBarTexture()
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetTrackerSettings(aura)
  return ns.Interrupts:EnsureAuraDefaults(aura)
end

local function IsSelectedInEditor(auraId)
  return ns.ui
    and ns.ui.MainWindow
    and ns.ui.MainWindow.IsOpen
    and ns.ui.MainWindow:IsOpen()
    and ns.db
    and ns.db.ui
    and ns.db.ui.selectedAuraId == auraId
end

local function ApplyTextRotation(fontString, degrees)
  if not fontString or not fontString.SetRotation then
    return
  end
  local rotation = tonumber(degrees or 0) or 0
  fontString:SetRotation(math.rad(rotation))
end

local function ApplyTextJustify(fontString, anchor)
  if not fontString then
    return
  end

  local resolved = tostring(anchor or "LEFT")
  if resolved:find("RIGHT", 1, true) then
    fontString:SetJustifyH("RIGHT")
  elseif resolved:find("CENTER", 1, true) then
    fontString:SetJustifyH("CENTER")
  else
    fontString:SetJustifyH("LEFT")
  end

  if resolved:find("TOP", 1, true) then
    fontString:SetJustifyV("TOP")
  elseif resolved:find("BOTTOM", 1, true) then
    fontString:SetJustifyV("BOTTOM")
  else
    fontString:SetJustifyV("MIDDLE")
  end
end

local function PositionText(fontString, parent, iconParent, anchor, x, y)
  if not fontString or not parent then
    return
  end

  fontString:ClearAllPoints()
  local resolvedAnchor = anchor or "CENTER"
  local resolvedParent = parent
  if resolvedAnchor == "ICON" and iconParent then
    resolvedAnchor = "CENTER"
    resolvedParent = iconParent
  end
  fontString:SetPoint(resolvedAnchor, resolvedParent, resolvedAnchor, x or 0, y or 0)
  ApplyTextJustify(fontString, anchor)
end

local function GetNumeric(value, fallback)
  local number = tonumber(value)
  if number == nil then
    return fallback
  end
  return number
end

local function GetReadyText(aura)
  local readyText = aura and aura.display and aura.display.readyText or nil
  if readyText == nil or readyText == "" or readyText == "Ready" then
    return "READY"
  end
  return tostring(readyText)
end

local function GetReadyColor(aura)
  local color = aura and aura.display and aura.display.readyTextColor or nil
  return color or DEFAULT_READY_COLOR
end

local function FormatRemaining(remaining, decimals)
  decimals = math.max(0, math.min(2, tonumber(decimals or 0) or 0))
  if decimals <= 0 then
    return tostring(math.ceil(remaining))
  end
  return string.format("%." .. decimals .. "f", remaining)
end

local function TruncateUTF8(value, maxChars)
  local text = tostring(value or "")
  local limit = tonumber(maxChars or 0) or 0
  if limit <= 0 or text == "" then
    return text
  end

  if utf8 and utf8.len and utf8.offset then
    local length = utf8.len(text)
    if type(length) == "number" and length > limit then
      local stop = utf8.offset(text, limit + 1)
      if stop then
        return text:sub(1, stop - 1)
      end
    end
    return text
  end

  if #text > limit then
    return text:sub(1, limit)
  end
  return text
end

local function GetBasePlayerName(name)
  local baseName = tostring(name or "Player")
  local dash = baseName:find("-", 1, true)
  if dash then
    baseName = baseName:sub(1, dash - 1)
  end
  return baseName
end

local function GetBarPlayerName(name)
  return TruncateUTF8(GetBasePlayerName(name), MAX_BAR_NAME_CHARS)
end

local function BuildRowLabel(entry, settings)
  local showPlayerName = settings == nil or settings.showPlayerName ~= false
  local showInterruptName = settings and settings.displayInterruptName == true
  local fullPlayerName = GetBasePlayerName(entry and entry.name)
  local shortPlayerName = GetBarPlayerName(entry and entry.name)
  local spellName = tostring((entry and entry.label) or "Interrupt")

  if showPlayerName and showInterruptName then
    return string.format("%s - %s", shortPlayerName, spellName)
  end
  if showPlayerName then
    return fullPlayerName
  end
  if showInterruptName then
    return spellName
  end
  return ""
end

local function ApplyIconPlacement(iconHolder, parent, display, paddingX, paddingY)
  iconHolder:ClearAllPoints()
  local side = display.iconAnchor or "LEFT"
  local offsetX = display.iconOffsetX or 0
  local offsetY = display.iconOffsetY or 0

  if side == "LEFT" or side == "TOPLEFT" or side == "BOTTOMLEFT" then
    offsetX = offsetX + paddingX
  elseif side == "RIGHT" or side == "TOPRIGHT" or side == "BOTTOMRIGHT" then
    offsetX = offsetX - paddingX
  end

  if side == "TOP" or side == "TOPLEFT" or side == "TOPRIGHT" then
    offsetY = offsetY - paddingY
  elseif side == "BOTTOM" or side == "BOTTOMLEFT" or side == "BOTTOMRIGHT" then
    offsetY = offsetY + paddingY
  end

  iconHolder:SetPoint(side, parent, side, offsetX, offsetY)
end

local function GetBarInsets(display, iconShown, iconSize, paddingX)
  local left = paddingX
  local right = paddingX
  local gap = math.max(2, math.floor(paddingX * 0.5))

  if iconShown then
    local anchor = display.iconAnchor or "LEFT"
    if anchor == "LEFT" or anchor == "TOPLEFT" or anchor == "BOTTOMLEFT" then
      left = left + iconSize + gap
    elseif anchor == "RIGHT" or anchor == "TOPRIGHT" or anchor == "BOTTOMRIGHT" then
      right = right + iconSize + gap
    end
  end

  return left, right
end

function InterruptTrackerRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.frame:SetClipsChildren(true)
  instance.frame:SetBackdropColor(0, 0, 0, 0)
  instance.frame:SetBackdropBorderColor(0.20, 0.32, 0.46, 0.88)

  instance.background = instance.frame:CreateTexture(nil, "BACKGROUND")
  instance.background:SetAllPoints()
  instance.background:SetTexture("Interface\\Buttons\\WHITE8x8")
  instance.background:SetVertexColor(
    DEFAULT_BACKGROUND_COLOR.r,
    DEFAULT_BACKGROUND_COLOR.g,
    DEFAULT_BACKGROUND_COLOR.b,
    DEFAULT_BACKGROUND_COLOR.a
  )

  instance.placeholder = instance.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  Fonts.Apply(instance.placeholder, 12, "OUTLINE")
  instance.placeholder:SetPoint("CENTER")
  instance.placeholder:SetTextColor(0.88, 0.92, 1)
  instance.placeholder:SetText("Awaiting interrupt users")

  instance.rows = {}
  instance.elapsed = 0
  instance.isDragging = false
  return instance
end

function InterruptTrackerRegion:StartDragging()
  local aura = self.currentAura
  if not aura or not BaseRegion:CanMove(aura) or InCombatLockdown() then
    return
  end

  self.isDragging = true
  local handler = self.frame and self.frame:GetScript("OnDragStart")
  if handler then
    handler(self.frame)
  elseif self.frame and self.frame.StartMoving then
    self.frame:StartMoving()
  end
end

function InterruptTrackerRegion:StopDragging()
  if not self.frame then
    return
  end

  self.isDragging = false
  local handler = self.frame:GetScript("OnDragStop")
  if handler then
    handler(self.frame)
  elseif self.frame.StopMovingOrSizing then
    self.frame:StopMovingOrSizing()
  end
end

function InterruptTrackerRegion:EnsureRow(index)
  if self.rows[index] then
    return self.rows[index]
  end

  local row = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
  row:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  row:SetClipsChildren(true)

  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  row.bg:SetVertexColor(0.03, 0.05, 0.08, 0.92)

  row.status = CreateFrame("StatusBar", nil, row)
  row.status:SetStatusBarTexture(GetStatusBarTexture())

  row.statusBg = row.status:CreateTexture(nil, "BACKGROUND")
  row.statusBg:SetAllPoints()
  row.statusBg:SetTexture("Interface\\Buttons\\WHITE8x8")
  row.statusBg:SetVertexColor(0.09, 0.11, 0.16, 0.94)

  row.iconHolder = CreateFrame("Frame", nil, row)
  row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
  row.icon:SetAllPoints()
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.overlay = CreateFrame("Frame", nil, row)
  row.overlay:SetAllPoints()
  row.overlay:SetFrameLevel(row:GetFrameLevel() + 15)

  row.textArea = CreateFrame("Frame", nil, row.overlay)
  row.textArea:SetPoint("TOPLEFT", row.status, "TOPLEFT", 6, 0)
  row.textArea:SetPoint("BOTTOMRIGHT", row.status, "BOTTOMRIGHT", -6, 0)

  row.label = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if row.label.SetWordWrap then
    row.label:SetWordWrap(false)
  end
  if row.label.SetMaxLines then
    row.label:SetMaxLines(1)
  end
  row.label:SetShadowColor(0, 0, 0, 0.9)
  row.label:SetShadowOffset(1, -1)

  row.timer = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if row.timer.SetWordWrap then
    row.timer:SetWordWrap(false)
  end
  if row.timer.SetMaxLines then
    row.timer:SetMaxLines(1)
  end
  row.timer:SetShadowColor(0, 0, 0, 0.9)
  row.timer:SetShadowOffset(1, -1)

  row.clickTarget = CreateFrame("Frame", nil, row)
  row.clickTarget:SetAllPoints()
  row.clickTarget:SetFrameLevel(row.overlay:GetFrameLevel() + 5)
  row.clickTarget:RegisterForDrag("LeftButton")
  row.clickTarget:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then
      return
    end
    if self.currentAura and BaseRegion:CanMove(self.currentAura) then
      return
    end
    if row._entry then
      InterruptTrackerRegion.AnnounceEntry(self, row._entry)
    end
  end)
  row.clickTarget:SetScript("OnDragStart", function()
    if self.currentAura and BaseRegion:CanMove(self.currentAura) then
      self:StartDragging()
    end
  end)
  row.clickTarget:SetScript("OnDragStop", function()
    if self.currentAura and BaseRegion:CanMove(self.currentAura) then
      self:StopDragging()
    end
  end)

  self.rows[index] = row
  return row
end

function InterruptTrackerRegion:PlayRowSound(entry)
  if not entry then
    return
  end

  local aura = self.currentAura
  local settings = aura and GetTrackerSettings(aura) or nil
  if not settings or settings.soundEnabled ~= true then
    return
  end

  if settings.soundOwnKickOnly == true and entry.isLocal ~= true then
    return
  end

  if entry.kickResult == "success" then
    ns.Interrupts:PlaySound(settings.soundKickSuccess)
  elseif entry.kickResult == "failed" then
    ns.Interrupts:PlaySound(settings.soundKickFailed)
  end
end

function InterruptTrackerRegion:AnnounceEntry(entry)
  local aura = self.currentAura
  local settings = aura and GetTrackerSettings(aura) or nil
  if not settings or settings.clickToAnnounce ~= true then
    return
  end

  local rowKey = string.format("%s:%s", tostring(entry.name or ""), tostring(entry.spellID or 0))
  self.announceLocks = self.announceLocks or {}
  local now = GetTime()
  if settings.antiSpam == true and (self.announceLocks[rowKey] or 0) > now then
    return
  end

  local message
  if entry.remaining > 0.5 then
    message = string.format("%s - %s - ready in %.0fs", entry.name or "Player", entry.label or "Interrupt", entry.remaining)
  else
    message = string.format("%s - %s - READY", entry.name or "Player", entry.label or "Interrupt")
  end

  local channel = settings.announceChannel or "PARTY"
  if channel == "PARTY" and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    channel = "INSTANCE_CHAT"
  end
  local sent = false
  if C_ChatInfo and C_ChatInfo.SendChatMessage then
    if channel == "YELL" or channel == "SAY" or channel == "INSTANCE_CHAT" or (channel == "PARTY" and IsInGroup()) then
      C_ChatInfo.SendChatMessage(message, channel)
      sent = true
    end
  elseif SendChatMessage then
    if channel == "YELL" or channel == "SAY" or channel == "INSTANCE_CHAT" or (channel == "PARTY" and IsInGroup()) then
      SendChatMessage(message, channel)
      sent = true
    end
  end

  if not sent then
    print("|cff66ccffPopAuras|r " .. message)
  end

  if settings.antiSpam == true then
    local lockDuration = entry.remaining > 0.5 and entry.remaining or 5
    self.announceLocks[rowKey] = now + lockDuration
  end
end

function InterruptTrackerRegion:ApplyRowLayout(row, aura, index, width, height)
  local display = aura.display or {}
  local settings = GetTrackerSettings(aura)
  local spacing = math.max(0, GetNumeric(display.spacing, 4) or 4)
  local paddingX = math.max(0, GetNumeric(settings.paddingX, 6) or 6)
  local paddingY = math.max(0, GetNumeric(settings.paddingY, 3) or 3)
  local barBackgroundColor = settings.barBackgroundColor or DEFAULT_BAR_BACKGROUND_COLOR
  local iconShown = display.icon ~= false
  local showBarBackground = settings.showBarBackground ~= false
  local iconSize = iconShown and (
    display.iconMatchBarSize ~= false
      and math.max(14, height - (paddingY * 2))
      or math.max(14, GetNumeric(display.iconSize, height - (paddingY * 2)) or (height - (paddingY * 2)))
  ) or 0
  local leftInset, rightInset = GetBarInsets(display, iconShown, iconSize, paddingX)
  local topOffset = (index - 1) * (height + spacing)
  local statusWidth = math.max(10, width - leftInset - rightInset)
  local timerReserve = display.showTimer ~= false and math.max(48, (display.timerFontSize or 12) * 3.6) or 0
  local textWidth = math.max(10, statusWidth - 12 - timerReserve)

  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -topOffset)
  row:SetSize(width, height)
  row.bg:SetShown(showBarBackground)
  row.bg:SetVertexColor(
    barBackgroundColor.r or DEFAULT_BAR_BACKGROUND_COLOR.r,
    barBackgroundColor.g or DEFAULT_BAR_BACKGROUND_COLOR.g,
    barBackgroundColor.b or DEFAULT_BAR_BACKGROUND_COLOR.b,
    barBackgroundColor.a == nil and DEFAULT_BAR_BACKGROUND_COLOR.a or barBackgroundColor.a
  )
  row:SetBackdropColor(
    barBackgroundColor.r or DEFAULT_BAR_BACKGROUND_COLOR.r,
    barBackgroundColor.g or DEFAULT_BAR_BACKGROUND_COLOR.g,
    barBackgroundColor.b or DEFAULT_BAR_BACKGROUND_COLOR.b,
    showBarBackground and (barBackgroundColor.a == nil and DEFAULT_BAR_BACKGROUND_COLOR.a or barBackgroundColor.a) or 0
  )
  row:SetBackdropBorderColor(0.18, 0.24, 0.34, showBarBackground and 0.95 or 0)
  row.overlay:SetFrameLevel(row:GetFrameLevel() + 15)
  row.clickTarget:SetFrameLevel(row.overlay:GetFrameLevel() + 5)

  row.status:ClearAllPoints()
  row.status:SetPoint("TOPLEFT", row, "TOPLEFT", leftInset, -paddingY)
  row.status:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -rightInset, paddingY)

  if iconShown then
    row.iconHolder:Show()
    row.iconHolder:SetSize(iconSize, iconSize)
    ApplyIconPlacement(row.iconHolder, row, display, paddingX, paddingY)
  else
    row.iconHolder:Hide()
  end

  row.textArea:ClearAllPoints()
  row.textArea:SetPoint("TOPLEFT", row.status, "TOPLEFT", 6, 0)
  row.textArea:SetPoint("BOTTOMRIGHT", row.status, "BOTTOMRIGHT", -(display.showTimer ~= false and timerReserve or 6), 0)

  row.label:SetWidth(textWidth)
  row.timer:SetWidth(timerReserve)

  PositionText(row.label, row.textArea, row.iconHolder, display.nameAnchor or "LEFT", display.nameOffsetX or 6, display.nameOffsetY or 0)
  PositionText(row.timer, row.status, row.iconHolder, display.timerAnchor or "RIGHT", display.timerOffsetX or -6, display.timerOffsetY or 0)
end

function InterruptTrackerRegion:ApplyRowState(row, entry)
  local aura = self.currentAura
  local display = aura and aura.display or {}
  local settings = aura and GetTrackerSettings(aura) or {}
  local barBackgroundColor = settings.barBackgroundColor or DEFAULT_BAR_BACKGROUND_COLOR
  local fillMode = settings.fillMode or "DRAIN"
  local barAlpha = math.max(0, math.min(1, tonumber(settings.barAlpha or 0.88) or 0.88))
  local baseCd = math.max(0.001, tonumber(entry.baseCd or 0) or 0.001)
  local remaining = math.max(0, tonumber(entry.remaining or 0) or 0)
  local red, green, blue = ns.Interrupts:GetClassColor(entry.class)
  local showFailedKick = settings.showFailedKick == true
  local readyText = GetReadyText(aura)
  local readyColor = GetReadyColor(aura)
  local readyBarAlpha = math.max(0, math.min(1, tonumber(settings.readyBarAlpha or 0.40) or 0.40))
  local showReadyText = display.hideReadyTimer ~= true
  local isReady = remaining <= 0.05
  local labelSettings = {
    showPlayerName = display.showName ~= false,
    displayInterruptName = settings.displayInterruptName == true,
  }
  local labelText = BuildRowLabel(entry, labelSettings)

  row._entry = entry
  row.icon:SetTexture(entry.icon or 134400)
  row.label:SetText(labelText)
  row.label:SetShown(labelText ~= "")
  row.timer:SetShown(display.showTimer ~= false)
  row.status:SetMinMaxValues(0, baseCd)
  if isReady then
    row.status:SetValue(baseCd)
  else
    row.status:SetValue(fillMode == "FILL" and math.max(0, baseCd - remaining) or remaining)
  end
  row.status:SetStatusBarColor(red, green, blue, isReady and readyBarAlpha or barAlpha)
  row.statusBg:SetShown(settings.showBarBackground ~= false)
  row.statusBg:SetVertexColor(
    barBackgroundColor.r or DEFAULT_BAR_BACKGROUND_COLOR.r,
    barBackgroundColor.g or DEFAULT_BAR_BACKGROUND_COLOR.g,
    barBackgroundColor.b or DEFAULT_BAR_BACKGROUND_COLOR.b,
    barBackgroundColor.a == nil and DEFAULT_BAR_BACKGROUND_COLOR.a or barBackgroundColor.a
  )

  Fonts.ApplyStyle(row.label, display.nameFontStyle or "FRIZQT_OUTLINE", display.nameFontSize or 12)
  Fonts.ApplyStyle(row.timer, display.timerFontStyle or "FRIZQT_OUTLINE", display.timerFontSize or 12)
  ApplyTextRotation(row.label, display.nameRotation)
  ApplyTextRotation(row.timer, display.timerRotation)
  row.label:SetTextColor(
    (display.nameColor and display.nameColor.r) or 1,
    (display.nameColor and display.nameColor.g) or 1,
    (display.nameColor and display.nameColor.b) or 1,
    (display.nameColor and display.nameColor.a) == nil and 1 or display.nameColor.a
  )

  local timerText = ""
  local timerColor = display.timerColor or { r = 1, g = 1, b = 1, a = 1 }
  if isReady then
    if showReadyText then
      timerText = readyText
    end
    timerColor = readyColor
  elseif showFailedKick and entry.pendingKick == true then
    timerText = ""
  else
    timerText = FormatRemaining(remaining, display.timerDecimals or 0)
  end

  row.timer:SetText(timerText)
  row.timer:SetTextColor(
    timerColor.r or 1,
    timerColor.g or 1,
    timerColor.b or 1,
    timerColor.a == nil and 1 or timerColor.a
  )

  local canMove = aura and BaseRegion:CanMove(aura)
  row.clickTarget:EnableMouse(canMove or settings.clickToAnnounce == true)

  local signature = table.concat({
    tostring(entry.remaining > 0.05),
    tostring(entry.pendingKick == true),
    tostring(entry.kickResult or ""),
  }, ":")
  if row._soundSignature ~= signature then
    if row._soundSignature ~= nil then
      self:PlayRowSound(entry)
    end
    row._soundSignature = signature
  end
end

function InterruptTrackerRegion:RefreshRows()
  local aura = self.currentAura
  local state = self.currentState
  if not aura or not state then
    return
  end

  if not self.isDragging then
    BaseRegion:ApplyAnchor(aura, self.frame)
  end
  BaseRegion:ApplyFrameLayer(aura, self.frame)

  local entries = ns.InterruptTracker:GetEntries(aura)
  local width = GetNumeric(aura.display and aura.display.width, GetNumeric(aura.position and aura.position.width, 240)) or 240
  local rowHeight = GetNumeric(aura.display and aura.display.height, GetNumeric(aura.position and aura.position.height, 34)) or 34
  local spacing = math.max(0, GetNumeric(aura.display and aura.display.spacing, 4) or 4)
  local contentHeight = math.max(rowHeight, (#entries * rowHeight) + math.max(0, #entries - 1) * spacing)
  local showPlaceholder = #entries == 0 and IsSelectedInEditor(aura.id)
  local shouldShow = state.show and (#entries > 0 or showPlaceholder)

  BaseRegion:ApplyCommonAppearance(aura, self.frame, { show = shouldShow, active = state.active == true })

  if not shouldShow then
    self.frame:SetScript("OnUpdate", nil)
    self.background:Hide()
    self.frame:SetBackdropBorderColor(0, 0, 0, 0)
    self.placeholder:Hide()
    for _, row in ipairs(self.rows) do
      row:Hide()
    end
    return
  end

  self.frame:SetSize(width, contentHeight)
  self.background:SetShown(aura.display.showBackground ~= false)
  self.frame:SetBackdropBorderColor(0.20, 0.32, 0.46, aura.display.showBackground ~= false and 0.88 or 0)
  self.background:SetVertexColor(
    (aura.display.backgroundColor and aura.display.backgroundColor.r) or DEFAULT_BACKGROUND_COLOR.r,
    (aura.display.backgroundColor and aura.display.backgroundColor.g) or DEFAULT_BACKGROUND_COLOR.g,
    (aura.display.backgroundColor and aura.display.backgroundColor.b) or DEFAULT_BACKGROUND_COLOR.b,
    (aura.display.backgroundColor and aura.display.backgroundColor.a) == nil and DEFAULT_BACKGROUND_COLOR.a or aura.display.backgroundColor.a
  )
  self.placeholder:SetShown(showPlaceholder)

  for index, entry in ipairs(entries) do
    local row = self:EnsureRow(index)
    self:ApplyRowLayout(row, aura, index, width, rowHeight)
    self:ApplyRowState(row, entry)
    row:Show()
  end

  for index = #entries + 1, #self.rows do
    self.rows[index]:Hide()
  end

  if showPlaceholder then
    self.placeholder:SetText("Awaiting interrupt users")
  end

  self.frame:SetScript("OnUpdate", function(_, elapsed)
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < 0.1 then
      return
    end
    self.elapsed = 0
    self:RefreshRows()
  end)
end

function InterruptTrackerRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state
  self:RefreshRows()
end

function InterruptTrackerRegion:Release()
  if self.frame then
    self.frame:SetScript("OnUpdate", nil)
  end
  BaseRegion.Release(self)
end
