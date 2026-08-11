local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

local ExportWindow = {}
ns.ui.ExportWindow = ExportWindow

local function UpdateTextHeight(frame)
  local text = frame.editBox:GetText()
  frame.measure:SetWidth(math.max(32, (frame.editBox:GetWidth() or 646) - 16))
  frame.measure:SetText(text ~= "" and text or " ")
  frame.editBox:SetHeight(math.max(214, math.ceil((frame.measure:GetStringHeight() or 0) + 24)))
end

function ExportWindow:Create()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "PopAurasExportWindow", UIParent, "BackdropTemplate")
  frame:SetSize(720, 390)
  frame:SetPoint("CENTER", UIParent, "CENTER", 40, 0)
  frame:SetFrameStrata("TOOLTIP")
  frame:SetFrameLevel(2100)
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  Theme.StyleSurface(frame, "canvasAlt", "borderStrong")
  frame:Hide()

  frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.header:SetPoint("TOPLEFT", 1, -1)
  frame.header:SetPoint("TOPRIGHT", -1, -1)
  frame.header:SetHeight(44)
  frame.header:EnableMouse(true)
  frame.header:RegisterForDrag("LeftButton")
  Theme.StyleSurface(frame.header, "surfaceRaised", "border")
  frame.header:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  frame.header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
  end)

  frame.title = frame.header:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.title, "sectionTitle")
  frame.title:SetPoint("LEFT", 16, 0)
  frame.title:SetText("Export All Auras")
  Theme.SetText(frame.title, "text")

  frame.closeButton = Frames.CreateButton(frame.header, "x", 28, 26, function()
    frame:Hide()
  end)
  frame.closeButton:SetPoint("RIGHT", -9, 0)
  Theme.StyleButton(frame.closeButton, "ghost")
  Theme.ApplyTypography(frame.closeButton:GetFontString(), "controlEmphasis")

  frame.instructions = Frames.CreateLabel(
    frame,
    "The complete PopAuras collection is selected below. Press Ctrl+C to copy it.",
    "GameFontHighlight"
  )
  frame.instructions:SetPoint("TOPLEFT", 18, -60)
  Theme.SetText(frame.instructions, "textSecondary")

  frame.summary = Frames.CreateLabel(frame, "", "GameFontDisableSmall")
  frame.summary:SetPoint("TOPLEFT", frame.instructions, "BOTTOMLEFT", 0, -4)
  Theme.SetText(frame.summary, "textMuted")

  frame.boxHolder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.boxHolder:SetPoint("TOPLEFT", 18, -104)
  frame.boxHolder:SetPoint("BOTTOMRIGHT", -18, 58)
  Theme.StyleSurface(frame.boxHolder, "control", "border")

  frame.scroll = CreateFrame("ScrollFrame", nil, frame.boxHolder, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 8, -8)
  frame.scroll:SetPoint("BOTTOMRIGHT", -30, 8)
  Theme.StyleScrollFrame(frame.scroll)

  frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
  frame.editBox:SetMultiLine(true)
  frame.editBox:SetAutoFocus(false)
  frame.editBox:EnableMouse(true)
  frame.editBox:EnableKeyboard(true)
  frame.editBox:SetMaxLetters(0)
  frame.editBox:SetWidth(646)
  frame.editBox:SetHeight(214)
  frame.editBox:SetFontObject(ChatFontNormal)
  frame.editBox:SetTextInsets(8, 8, 8, 8)
  frame.editBox:SetJustifyH("LEFT")
  frame.editBox:SetJustifyV("TOP")
  frame.editBox:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  frame.editBox:SetScript("OnTextChanged", function()
    UpdateTextHeight(frame)
  end)
  frame.scroll:SetScrollChild(frame.editBox)

  frame.measure = frame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
  frame.measure:SetWidth(630)
  frame.measure:SetJustifyH("LEFT")
  frame.measure:SetJustifyV("TOP")
  frame.measure:Hide()

  frame.copyHint = Frames.CreateLabel(frame, "Ctrl+C copies the selected export string.", "GameFontDisableSmall")
  frame.copyHint:SetPoint("BOTTOMLEFT", 18, 20)
  Theme.SetText(frame.copyHint, "textMuted")

  frame.selectButton = Frames.CreateButton(frame, "Select All", 104, 28, function()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
  end)
  frame.selectButton:SetPoint("BOTTOMRIGHT", -18, 14)
  Frames.StylePrimaryButton(frame.selectButton)

  frame:SetScript("OnShow", function(selfFrame)
    selfFrame:Raise()
  end)
  frame:SetScript("OnHide", function()
    frame.editBox:ClearFocus()
  end)

  self.frame = frame
  return frame
end

function ExportWindow:ShowAll()
  local encoded, payload = ns.Export:Encode()
  local frame = self:Create()
  local count = payload and payload.order and #payload.order or 0
  frame.summary:SetText(string.format("%d aura%s included in this export.", count, count == 1 and "" or "s"))
  frame.editBox:SetText(encoded or "")
  UpdateTextHeight(frame)
  frame.scroll:SetVerticalScroll(0)
  frame:Show()
  frame.editBox:SetFocus()
  frame.editBox:HighlightText()
end
