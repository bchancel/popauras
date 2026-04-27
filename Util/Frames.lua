local _, ns = ...

local Frames = {}
ns.util.Frames = Frames

local Fonts = ns.util.Fonts

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
