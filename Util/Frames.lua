local _, ns = ...

local Frames = {}
ns.util.Frames = Frames

local Theme = ns.util.Theme
local Layout = Theme.layout

local function GetTemplateTypographyRole(template)
  template = tostring(template or "")
  if template:find("Large", 1, true) then return "sectionTitle" end
  if template:find("Small", 1, true) then return "caption" end
  if template:find("Highlight", 1, true) then return "body" end
  if template:find("Disable", 1, true) then return "bodySmall" end
  return "control"
end

function Frames.SetExplicitBounds(region, owner, width, height)
  if not region or not owner then return end
  width = tonumber(width)
  height = tonumber(height)
  if not width or width <= 0 or not height or height <= 0 then return end
  region:ClearAllPoints()
  region:SetPoint("CENTER", owner, "CENTER", 0, 0)
  region:SetSize(width, height)
end

local function ConfigureSingleLine(fontString)
  if not fontString then return end
  if fontString.SetWordWrap then fontString:SetWordWrap(false) end
  if fontString.SetNonSpaceWrap then fontString:SetNonSpaceWrap(false) end
  if fontString.SetMaxLines then fontString:SetMaxLines(1) end
end

function Frames.ConfigureBarTextBounds(nameText, timerText, owner, display, width, orientation)
  display = display or {}
  ConfigureSingleLine(nameText)
  ConfigureSingleLine(timerText)

  if nameText then nameText:SetWidth(0) end
  if timerText then timerText:SetWidth(0) end
  if orientation ~= "HORIZONTAL"
    or display.showName ~= true
    or display.showTimer ~= true
    or (display.nameAnchor or "CENTER") ~= "LEFT"
    or (display.timerAnchor or "CENTER") ~= "RIGHT" then
    return
  end

  local timerWidth = math.max(34, (tonumber(display.timerFontSize or 12) or 12) * 4)
  local nameInset = math.max(0, tonumber(display.nameOffsetX or 0) or 0)
  local timerInset = math.abs(tonumber(display.timerOffsetX or 0) or 0)
  nameText:ClearAllPoints()
  nameText:SetPoint("LEFT", owner, "LEFT", nameInset, tonumber(display.nameOffsetY or 0) or 0)
  nameText:SetPoint("RIGHT", owner, "RIGHT", -(timerInset + timerWidth + 4), tonumber(display.nameOffsetY or 0) or 0)
  nameText:SetJustifyH("LEFT")
  timerText:ClearAllPoints()
  timerText:SetPoint("RIGHT", owner, "RIGHT", tonumber(display.timerOffsetX or 0) or 0, tonumber(display.timerOffsetY or 0) or 0)
  timerText:SetWidth(timerWidth)
  timerText:SetJustifyH("RIGHT")
end

function Frames.MakeMovable(frame, onStop)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then
      return
    end
    if not (ns.ui and ns.ui.MainWindow and ns.ui.MainWindow.IsOpen and ns.ui.MainWindow:IsOpen()) then
      return
    end
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if onStop then
      onStop(self)
    end
  end)
end

function Frames.CreateLabel(parent, text, template, typographyRole)
  template = template or "GameFontNormal"
  local label = parent:CreateFontString(nil, "OVERLAY", template)
  label:SetJustifyH("LEFT")
  label:SetText(text or "")
  Theme.ApplyTypography(label, typographyRole or GetTemplateTypographyRole(template))
  if template:find("Disable", 1, true) then
    Theme.SetText(label, "textMuted")
  elseif template:find("Highlight", 1, true) then
    Theme.SetText(label, "textSecondary")
  else
    Theme.SetText(label, "text")
  end
  return label
end

function Frames.CreateButton(parent, text, width, height, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  Theme.PixelSetSize(button, width or 120, height or Layout.controlHeight)
  button.Text = button:CreateFontString(nil, "OVERLAY")
  button.Text:SetPoint("CENTER")
  Theme.ApplyTypography(button.Text, "control")
  button.Text:SetJustifyH("CENTER")
  button.Text:SetJustifyV("MIDDLE")
  function button:SetText(value)
    self.Text:SetText(value or "")
  end
  function button:GetFontString()
    return self.Text
  end
  button:SetText(text or "Button")
  if onClick then
    button:SetScript("OnClick", onClick)
  end
  Theme.StyleButton(button, "secondary")
  return button
end

function Frames.StyleSecondaryButton(button)
  if not button then
    return
  end
  Theme.StyleButton(button, "secondary")
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Theme.ApplyTypography(fontString, "control")
    end
  end
end

function Frames.StylePrimaryButton(button)
  if not button then
    return
  end
  Theme.StyleButton(button, "primary")
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Theme.ApplyTypography(fontString, "sectionTitle")
    end
  end
end

function Frames.StyleSuccessButton(button)
  if not button then
    return
  end
  Theme.StyleButton(button, "success")
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Theme.ApplyTypography(fontString, "controlEmphasis")
    end
  end
end

function Frames.StyleDangerButton(button)
  if not button then
    return
  end
  Theme.StyleButton(button, "danger")
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Theme.ApplyTypography(fontString, "controlEmphasis")
    end
  end
end

local function AddSpecialFrame(frameName)
  if not UISpecialFrames or not frameName then
    return
  end
  for _, existingName in ipairs(UISpecialFrames) do
    if existingName == frameName then
      return
    end
  end
  UISpecialFrames[#UISpecialFrames + 1] = frameName
end

function Frames.GetConfirmationDialog()
  if Frames.confirmationOverlay then
    return Frames.confirmationOverlay
  end

  local overlay = CreateFrame("Frame", "PopAurasConfirmationOverlay", UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  overlay:SetFrameLevel(900)
  overlay:EnableMouse(true)
  overlay:Hide()

  overlay.dim = overlay:CreateTexture(nil, "BACKGROUND")
  overlay.dim:SetAllPoints()
  overlay.dim:SetTexture("Interface\\Buttons\\WHITE8x8")
  overlay.dim:SetVertexColor(0, 0, 0, 0.45)

  local dialog = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
  dialog:SetSize(470, 220)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  Theme.StyleSurface(dialog, "canvasAlt", "borderStrong")
  dialog:SetFrameLevel(overlay:GetFrameLevel() + 10)

  dialog.accent = Theme.CreateAccentLine(dialog, 2, "accent")
  dialog.accent:SetPoint("TOPLEFT", 1, -1)
  dialog.accent:SetPoint("TOPRIGHT", -1, -1)

  dialog.title = Frames.CreateLabel(dialog, "Confirm", "GameFontNormalLarge")
  dialog.title:SetPoint("TOPLEFT", 20, -20)
  dialog.title:SetPoint("TOPRIGHT", -20, -20)
  dialog.title:SetJustifyH("CENTER")
  Theme.SetText(dialog.title, "text")

  dialog.message = Frames.CreateLabel(dialog, "", "GameFontHighlight")
  dialog.message:SetPoint("TOPLEFT", 24, -62)
  dialog.message:SetPoint("TOPRIGHT", -24, -62)
  dialog.message:SetHeight(82)
  dialog.message:SetJustifyH("CENTER")
  dialog.message:SetJustifyV("MIDDLE")
  dialog.message:SetWordWrap(true)
  Theme.SetText(dialog.message, "textSecondary")

  dialog.cancelButton = Frames.CreateButton(dialog, "No", 132, 30, function()
    overlay:Hide()
  end)
  dialog.cancelButton:SetPoint("BOTTOMLEFT", 88, 20)

  dialog.acceptButton = Frames.CreateButton(dialog, "Yes", 132, 30, function()
    local onAccept = overlay.onAccept
    overlay.onAccept = nil
    overlay:Hide()
    if onAccept then
      onAccept()
    end
  end)
  dialog.acceptButton:SetPoint("BOTTOMRIGHT", -88, 20)

  overlay:SetScript("OnHide", function(selfOverlay)
    selfOverlay.onAccept = nil
  end)
  overlay.dialog = dialog
  AddSpecialFrame(overlay:GetName())
  Frames.confirmationOverlay = overlay
  return overlay
end

function Frames.ShowConfirmation(options)
  options = type(options) == "table" and options or {}
  local overlay = Frames.GetConfirmationDialog()
  local dialog = overlay.dialog
  dialog.title:SetText(options.title or "Confirm")
  dialog.message:SetText(options.message or "Are you sure?")
  dialog.acceptButton:SetText(options.acceptText or "Yes")
  dialog.cancelButton:SetText(options.cancelText or "No")

  if options.acceptStyle == "danger" then
    Frames.StyleDangerButton(dialog.acceptButton)
  else
    Frames.StyleSuccessButton(dialog.acceptButton)
  end
  if options.cancelStyle == "danger" then
    Frames.StyleDangerButton(dialog.cancelButton)
  else
    Frames.StyleSecondaryButton(dialog.cancelButton)
  end

  overlay.onAccept = options.onAccept
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  overlay:Show()
  overlay:Raise()
  dialog:Raise()
  return overlay
end

function Frames.CreateInput(parent, width, height)
  local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  input:SetAutoFocus(false)
  Theme.PixelSetSize(input, width or Layout.standardInputWidth, height or Layout.controlHeight)
  input:SetTextInsets(6, 6, 0, 0)
  Theme.ApplyTypography(input, "control")
  Theme.StyleEditBox(input)
  return input
end

function Frames.CreateCheckbox(parent, labelText)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  local text = check.Text
  if not text then
    local name = check:GetName()
    if name then
      text = _G[name .. "Text"]
    end
  end
  if text then
    text:SetText(labelText or "")
    check.Text = text
  else
    text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", check, "RIGHT", 2, 1)
    text:SetText(labelText or "")
    check.Text = text
  end
  Theme.ApplyTypography(text, "control")
  Theme.StyleCheckbox(check)
  return check
end

function Frames.CreateToggle(parent)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  Theme.PixelSetSize(check, 42, Layout.controlHeight)
  if check.Text then
    check.Text:SetText("")
    check.Text:Hide()
  end
  Theme.StyleToggle(check)
  return check
end

function Frames.CreateLabeledToggle(parent, labelText)
  local check = Frames.CreateToggle(parent)
  local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("LEFT", check, "RIGHT", 8, 0)
  text:SetText(labelText or "")
  Theme.ApplyTypography(text, "control")
  Theme.SetText(text, "textSecondary")
  check.Text = text
  return check
end

function Frames.CreateSectionHeader(parent, titleText, width)
  local header = CreateFrame("Frame", nil, parent)
  Theme.PixelSetSize(header, width or 700, Layout.controlHeight)

  header.title = header:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(header.title, "controlSmall")
  header.title:SetPoint("LEFT", 0, 0)
  header.title:SetText(string.upper(titleText or ""))
  Theme.SetText(header.title, "groupAccent")

  header.divider = Theme.CreateAccentLine(header, 1, "border")
  header.divider:SetPoint("LEFT", header.title, "RIGHT", 12, 0)
  header.divider:SetPoint("RIGHT", header, "RIGHT", 0, 0)
  return header
end

function Frames.CreateDropdown(parent, width, initializer)
  local frame = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(frame, width or Layout.standardDropdownWidth)
  UIDropDownMenu_Initialize(frame, initializer)
  Theme.StyleDropdown(frame)
  if frame.Text then Theme.ApplyTypography(frame.Text, "control") end
  return frame
end

function Frames.CreateScrollPanel(parent, options)
  options = type(options) == "table" and options or {}

  local host = CreateFrame("Frame", nil, parent)
  host:SetAllPoints()

  local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", options.leftInset or 0, -(options.topInset or 0))
  scroll:SetPoint("BOTTOMRIGHT", -(options.rightInset or Layout.scrollBarInset), options.bottomInset or 0)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
    local current = selfScroll:GetVerticalScroll() or 0
    local maximum = selfScroll:GetVerticalScrollRange() or 0
    selfScroll:SetVerticalScroll(math.max(0, math.min(maximum, current - (delta * (options.wheelStep or Layout.wheelStep)))))
  end)
  Theme.StyleScrollFrame(scroll)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(options.contentWidth or Layout.standardContentWidth, options.contentHeight or Layout.standardContentWidth)
  scroll:SetScrollChild(content)
  if Frames.ApplyPanelCanvas then Frames.ApplyPanelCanvas(content) end

  local function UpdateContentSize(_, width, height)
    width = tonumber(width) or host:GetWidth() or 0
    height = tonumber(height) or host:GetHeight() or 0
    local availableWidth = math.max(options.minimumContentWidth or 1, width - (options.rightInset or Layout.scrollBarInset))
    content:SetWidth(availableWidth)
    if options.fillHeight then
      content:SetHeight(math.max(options.contentHeight or 1, height))
    end
  end
  host:SetScript("OnSizeChanged", UpdateContentSize)
  UpdateContentSize(host, host:GetWidth(), host:GetHeight())

  host.scroll = scroll
  host.content = content
  return host, scroll, content
end

function Frames.CreateSelectorButton(parent, width, height)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  Theme.PixelSetSize(button, width or Layout.standardDropdownWidth, height or Layout.rowHeight)

  button.Text = button:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(button.Text, "control", "OUTLINE")
  button.Text:SetPoint("LEFT", 10, 0)
  button.Text:SetPoint("RIGHT", -24, 0)
  button.Text:SetJustifyH("LEFT")
  Theme.SetText(button.Text, "text")

  button.Arrow = button:CreateTexture(nil, "ARTWORK")
  button.Arrow:SetSize(12, 12)
  button.Arrow:SetPoint("RIGHT", -7, 0)
  button.Arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  Theme.SetTexture(button.Arrow, "textAccent")

  function button:SetText(value)
    self.Text:SetText(value or "")
  end

  function button:GetFontString()
    return self.Text
  end

  Theme.StyleButton(button, "secondary")
  return button
end

function Frames.SetDropdownValue(dropdown, value, label)
  UIDropDownMenu_SetSelectedValue(dropdown, value)
  UIDropDownMenu_SetText(dropdown, label or tostring(value or ""))
end

function Frames.ApplyTitle(fontString)
  Theme.ApplyTypography(fontString, "panelTitle")
end
