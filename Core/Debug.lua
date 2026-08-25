local _, ns = ...

local Debug = {}
ns.Debug = Debug
local Fonts = ns.util.Fonts

Debug.entries = {}
Debug.maxEntries = 100
Debug.copyMode = false
Debug.lastLine = nil

local function TrimEntries(self)
  while #self.entries > self.maxEntries do
    table.remove(self.entries, 1)
  end
end

local function FormatState(state)
  if not state then
    return "state=nil"
  end
  return string.format(
    "show=%s active=%s name=%s stacks=%s stackMode=%s dur=%.2f exp=%.2f src=%s unit=%s spellId=%s",
    tostring(state.show),
    tostring(state.active),
    tostring(state.name or ""),
    tostring(state.stacks or 0),
    state.hasStackDisplayValue == true and "widget" or "safe",
    tonumber(state.duration or 0) or 0,
    tonumber(state.expirationTime or 0) or 0,
    tostring(state.source or ""),
    tostring(state.unit or ""),
    tostring(state.spellId or "")
  )
end

function Debug:RefreshWindow()
  if not self.frame or not self.frame:IsShown() then
    return
  end
  if self.copyMode then
    return
  end
  self.frame.editBox:SetText(table.concat(self.entries, "\n"))
  self.frame.scroll:SetVerticalScroll(self.frame.editBox:GetHeight())
end

function Debug:Log(source, message)
  local line = string.format("[%s] %s: %s", date("%H:%M:%S"), source or "Debug", message or "")
  if line == self.lastLine then
    return
  end
  self.lastLine = line
  self.entries[#self.entries + 1] = line
  TrimEntries(self)
  self:RefreshWindow()
end

function Debug:Clear()
  wipe(self.entries)
  self.copyMode = false
  self.lastLine = nil
  self:RefreshWindow()
end

function Debug:CopyAll()
  if not self.frame then
    return false
  end
  if self.frame.minimized == true then
    self:SetWindowMinimized(false)
  end
  self.copyMode = true
  local text = table.concat(self.entries, "\n")
  self.frame.editBox:SetText(text)
  self.frame.editBox:SetFocus()
  self.frame.editBox:HighlightText()
  self.frame.copyHint:SetText("The complete text is selected. Press Ctrl+C to copy it, then Escape to close copy mode.")
  self.frame.copyHint:Show()
  return true
end

function Debug:ShowSnapshot(title, lines, autoCopy)
  lines = type(lines) == "table" and lines or {}
  wipe(self.entries)
  self.copyMode = false
  self.lastLine = nil

  for _, line in ipairs(lines) do
    if line and line ~= "" then
      self.entries[#self.entries + 1] = tostring(line)
    end
  end
  TrimEntries(self)

  local frame = self:CreateWindow()
  if frame.title then
    frame.title:SetText(title and title ~= "" and title or "PopAuras Debug")
  end
  if frame.minimized == true then
    self:SetWindowMinimized(false)
  end
  frame:Show()
  self:RefreshWindow()

  if autoCopy then
    self:CopyAll()
  end
end

function Debug:ResumeLive()
  self.copyMode = false
  if self.frame and self.frame.copyHint then
    self.frame.copyHint:Hide()
  end
  self:RefreshWindow()
end

function Debug:ApplyWindowState()
  local frame = self.frame
  if not frame then
    return
  end

  if frame.minimized == true then
    if frame.editBox and frame.editBox.ClearFocus then
      frame.editBox:ClearFocus()
    end
    frame:SetWidth(frame.collapsedWidth or 112)
    frame.title:Hide()
    frame.scroll:Hide()
    frame.copy:Hide()
    frame.clear:Hide()
    frame.copyHint:Hide()
    frame:SetHeight(frame.collapsedHeight or 30)
    frame.minimize:SetText("+")
  else
    frame:SetWidth(frame.expandedWidth or 440)
    frame:SetHeight(frame.expandedHeight or 240)
    frame.title:Show()
    frame.scroll:Show()
    frame.copy:Show()
    frame.clear:Show()
    if self.copyMode then
      frame.copyHint:Show()
    else
      frame.copyHint:Hide()
    end
    frame.minimize:SetText("-")
  end
end

function Debug:SetWindowMinimized(minimized)
  local frame = self:CreateWindow()
  frame.minimized = minimized == true
  self:ApplyWindowState()
  if frame:IsShown() and frame.minimized ~= true then
    self:RefreshWindow()
  end
end

function Debug:ToggleMinimized()
  local frame = self:CreateWindow()
  self:SetWindowMinimized(frame.minimized ~= true)
end

function Debug:CreateWindow()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "PopAurasDebugWindow", UIParent, "BackdropTemplate")
  frame.expandedWidth = 440
  frame.expandedHeight = 240
  frame.collapsedWidth = 112
  frame.collapsedHeight = 30
  frame.minimized = false
  frame:SetSize(frame.expandedWidth, frame.expandedHeight)
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -194)
  frame:SetFrameStrata("TOOLTIP")
  frame:SetFrameLevel(2000)
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  frame:SetBackdropBorderColor(0.18, 0.25, 0.36, 1)
  frame:SetScript("OnShow", function(self)
    self:Raise()
  end)
  frame:Hide()

  frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.header:SetPoint("TOPLEFT", 1, -1)
  frame.header:SetPoint("TOPRIGHT", -1, -1)
  frame.header:SetHeight(28)
  frame.header:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
  })
  frame.header:SetBackdropColor(0.10, 0.14, 0.20, 0.98)
  frame.header:EnableMouse(true)
  frame.header:RegisterForDrag("LeftButton")
  frame.header:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  frame.header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
  end)

  frame.title = frame.header:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.title, 14, "OUTLINE")
  frame.title:SetPoint("LEFT", 10, 0)
  frame.title:SetPoint("RIGHT", -190, 0)
  frame.title:SetJustifyH("LEFT")
  frame.title:SetText("PopAuras Debug")

  frame.close = ns.util.Frames.CreateButton(frame.header, "x", 24, 20, function()
    frame:Hide()
  end)
  frame.close:SetPoint("RIGHT", frame.header, "RIGHT", -6, 0)

  frame.minimize = ns.util.Frames.CreateButton(frame.header, "-", 24, 20, function()
    Debug:ToggleMinimized()
  end)
  frame.minimize:SetPoint("RIGHT", frame.close, "LEFT", -6, 0)

  frame.clear = ns.util.Frames.CreateButton(frame.header, "Clear", 58, 20, function()
    Debug:Clear()
  end)
  frame.clear:SetPoint("RIGHT", frame.minimize, "LEFT", -6, 0)

  frame.copy = ns.util.Frames.CreateButton(frame.header, "Select", 58, 20, function()
    Debug:CopyAll()
  end)
  frame.copy:SetPoint("RIGHT", frame.clear, "LEFT", -6, 0)

  frame.copyHint = frame:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.copyHint, 10, "")
  frame.copyHint:SetPoint("TOPLEFT", 12, -36)
  frame.copyHint:SetPoint("TOPRIGHT", -12, -36)
  frame.copyHint:SetText("The complete text is selected. Press Ctrl+C to copy it, then Escape to close copy mode.")
  frame.copyHint:SetTextColor(0.80, 0.92, 1)
  frame.copyHint:Hide()

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 12, -54)
  frame.scroll:SetPoint("BOTTOMRIGHT", -30, 12)

  frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
  frame.editBox:SetMultiLine(true)
  frame.editBox:SetAutoFocus(false)
  frame.editBox:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
  frame.editBox:SetWidth(370)
  frame.editBox:SetTextInsets(4, 4, 4, 4)
  frame.editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    Debug:ResumeLive()
  end)
  frame.editBox:SetScript("OnEditFocusLost", function()
    if Debug.copyMode then
      Debug:ResumeLive()
    end
  end)
  frame.scroll:SetScrollChild(frame.editBox)

  self.frame = frame
  self:ApplyWindowState()
  self:RefreshWindow()
  return frame
end

function Debug:ToggleWindow()
  local frame = self:CreateWindow()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    self:RefreshWindow()
  end
end

function Debug:LogTrigger(aura, trigger, state, extra)
  if not trigger or trigger.debug ~= true then
    return
  end
  local auraName = aura and aura.name or "Unknown Aura"
  local triggerType = trigger.type or "unknown"
  local message = string.format("%s [%s] %s", auraName, triggerType, FormatState(state))
  if extra and extra ~= "" then
    message = message .. " | " .. extra
  end
  self:Log("Trigger", message)
end
