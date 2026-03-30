local _, ns = ...

local Debug = {}
ns.Debug = Debug

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
    return
  end
  self.copyMode = true
  local text = table.concat(self.entries, "\n")
  self.frame.editBox:SetText(text)
  self.frame.editBox:SetFocus()
  self.frame.editBox:HighlightText()
  self.frame.copyHint:Show()
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

function Debug:CreateWindow()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "PopAurasDebugWindow", UIParent, "BackdropTemplate")
  frame:SetSize(700, 420)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("TOOLTIP")
  frame:SetFrameLevel(2000)
  frame:SetToplevel(true)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  frame:SetBackdropBorderColor(0.18, 0.25, 0.36, 1)
  ns.util.Frames.MakeMovable(frame)
  frame:SetScript("OnShow", function(self)
    self:Raise()
  end)
  frame:Hide()

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", 12, -10)
  frame.title:SetText("PopAuras Debug")

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", 0, 0)

  frame.clear = ns.util.Frames.CreateButton(frame, "Clear", 90, 24, function()
    Debug:Clear()
  end)
  frame.clear:SetPoint("TOPRIGHT", -36, -8)

  frame.copy = ns.util.Frames.CreateButton(frame, "Copy Log", 90, 24, function()
    Debug:CopyAll()
  end)
  frame.copy:SetPoint("RIGHT", frame.clear, "LEFT", -8, 0)

  frame.copyHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.copyHint:SetPoint("TOPLEFT", 12, -34)
  frame.copyHint:SetText("Copy mode: text is frozen and highlighted. Press Escape to resume live updates.")
  frame.copyHint:SetTextColor(0.80, 0.92, 1)
  frame.copyHint:Hide()

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 12, -54)
  frame.scroll:SetPoint("BOTTOMRIGHT", -30, 12)

  frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
  frame.editBox:SetMultiLine(true)
  frame.editBox:SetAutoFocus(false)
  frame.editBox:SetFontObject(ChatFontNormal)
  frame.editBox:SetWidth(630)
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
