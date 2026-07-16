local _, ns = ...

local Frames = {}
ns.util.Frames = Frames

local Fonts = ns.util.Fonts

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

function Frames.CreateLabel(parent, text, template)
  local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
  label:SetJustifyH("LEFT")
  label:SetText(text or "")
  return label
end

function Frames.CreateButton(parent, text, width, height, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width or 120, height or 22)
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  button.Text = button:CreateFontString(nil, "OVERLAY")
  button.Text:SetPoint("CENTER")
  Fonts.Apply(button.Text, 12, "OUTLINE")
  button.Text:SetTextColor(1, 0.88, 0.15)
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
  return button
end

function Frames.StyleSecondaryButton(button)
  if not button then
    return
  end
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  button:SetBackdropColor(0.10, 0.13, 0.18, 0.95)
  button:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Fonts.Apply(fontString, 12, "OUTLINE")
      fontString:SetTextColor(1, 0.88, 0.15)
    end
  end
end

function Frames.StylePrimaryButton(button)
  if not button then
    return
  end
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  button:SetBackdropColor(0.06, 0.38, 0.75, 0.95)
  button:SetBackdropBorderColor(0.20, 0.60, 1.0, 1)
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Fonts.Apply(fontString, 16, "OUTLINE")
      fontString:SetTextColor(1, 1, 1)
    end
  end
end

function Frames.StyleSuccessButton(button)
  if not button then
    return
  end
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  button:SetBackdropColor(0.07, 0.38, 0.16, 0.98)
  button:SetBackdropBorderColor(0.18, 0.72, 0.34, 1)
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Fonts.Apply(fontString, 14, "OUTLINE")
      fontString:SetTextColor(1, 1, 1)
    end
  end
end

function Frames.StyleDangerButton(button)
  if not button then
    return
  end
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  button:SetBackdropColor(0.48, 0.07, 0.09, 0.98)
  button:SetBackdropBorderColor(0.86, 0.18, 0.22, 1)
  if button.GetFontString then
    local fontString = button:GetFontString()
    if fontString then
      Fonts.Apply(fontString, 14, "OUTLINE")
      fontString:SetTextColor(1, 1, 1)
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
  dialog:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  dialog:SetBackdropColor(0.07, 0.09, 0.14, 0.99)
  dialog:SetBackdropBorderColor(0.30, 0.38, 0.50, 1)
  dialog:SetFrameLevel(overlay:GetFrameLevel() + 10)

  dialog.title = Frames.CreateLabel(dialog, "Confirm", "GameFontNormalLarge")
  dialog.title:SetPoint("TOPLEFT", 20, -20)
  dialog.title:SetPoint("TOPRIGHT", -20, -20)
  dialog.title:SetJustifyH("CENTER")
  dialog.title:SetTextColor(0.94, 0.96, 1)

  dialog.message = Frames.CreateLabel(dialog, "", "GameFontHighlight")
  dialog.message:SetPoint("TOPLEFT", 24, -62)
  dialog.message:SetPoint("TOPRIGHT", -24, -62)
  dialog.message:SetHeight(82)
  dialog.message:SetJustifyH("CENTER")
  dialog.message:SetJustifyV("MIDDLE")
  dialog.message:SetWordWrap(true)
  dialog.message:SetTextColor(0.86, 0.90, 0.96)

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
  input:SetSize(width or 120, height or 20)
  input:SetTextInsets(6, 6, 0, 0)
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
  else
    text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", check, "RIGHT", 2, 1)
    text:SetText(labelText or "")
    check.Text = text
  end
  return check
end

function Frames.CreateDropdown(parent, width, initializer)
  local frame = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(frame, width or 140)
  UIDropDownMenu_Initialize(frame, initializer)
  return frame
end

function Frames.CreateSelectorButton(parent, width, height)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width or 180, height or 24)
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  button:SetBackdropColor(0.08, 0.10, 0.15, 0.98)
  button:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)

  button.Text = button:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(button.Text, 12, "OUTLINE")
  button.Text:SetPoint("LEFT", 10, 0)
  button.Text:SetPoint("RIGHT", -24, 0)
  button.Text:SetJustifyH("LEFT")
  button.Text:SetTextColor(0.95, 0.96, 1)

  button.Arrow = button:CreateTexture(nil, "ARTWORK")
  button.Arrow:SetSize(12, 12)
  button.Arrow:SetPoint("RIGHT", -7, 0)
  button.Arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  button.Arrow:SetVertexColor(1, 0.88, 0.15)

  button:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.10, 0.13, 0.18, 0.98)
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.08, 0.10, 0.15, 0.98)
  end)

  function button:SetText(value)
    self.Text:SetText(value or "")
  end

  function button:GetFontString()
    return self.Text
  end

  return button
end

function Frames.SetDropdownValue(dropdown, value, label)
  UIDropDownMenu_SetSelectedValue(dropdown, value)
  UIDropDownMenu_SetText(dropdown, label or tostring(value or ""))
end

function Frames.ApplyTitle(fontString)
  Fonts.Apply(fontString, 18, "OUTLINE")
end
