local _, ns = ...

local Theme = {}
ns.util.Theme = Theme

local Fonts = ns.util.Fonts
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"

Theme.backdrop = {
  bgFile = WHITE_TEXTURE,
  edgeFile = WHITE_TEXTURE,
  edgeSize = 1,
}

Theme.colors = {
  transparent = { 0.000, 0.000, 0.000, 0.00 },
  canvas = { 0.035, 0.064, 0.084, 0.99 },
  canvasAlt = { 0.047, 0.086, 0.112, 0.99 },
  control = { 0.018, 0.038, 0.054, 1.00 },
  surface = { 0.064, 0.116, 0.150, 0.98 },
  surfaceRaised = { 0.082, 0.150, 0.190, 0.99 },
  surfaceHover = { 0.070, 0.190, 0.245, 1.00 },
  surfacePressed = { 0.035, 0.230, 0.340, 1.00 },
  accentSoft = { 0.025, 0.210, 0.315, 0.96 },
  accent = { 0.035, 0.610, 0.875, 1.00 },
  accentBright = { 0.210, 0.790, 1.000, 1.00 },
  border = { 0.140, 0.240, 0.300, 1.00 },
  borderStrong = { 0.120, 0.360, 0.460, 1.00 },
  borderFocus = { 0.075, 0.610, 0.830, 1.00 },
  text = { 0.925, 0.955, 0.975, 1.00 },
  textSecondary = { 0.725, 0.790, 0.835, 1.00 },
  textMuted = { 0.500, 0.590, 0.660, 1.00 },
  textAccent = { 0.250, 0.740, 0.950, 1.00 },
  groupAccent = { 0.340, 0.860, 0.560, 1.00 },
  success = { 0.025, 0.360, 0.310, 1.00 },
  successBorder = { 0.070, 0.760, 0.640, 1.00 },
  danger = { 0.310, 0.055, 0.070, 0.92 },
  dangerBorder = { 0.760, 0.180, 0.200, 1.00 },
}

local buttonStyles = {
  secondary = {
    normal = { "surfaceRaised", "border" },
    hover = { "surfaceHover", "borderFocus" },
    pressed = { "surfacePressed", "borderFocus" },
    text = "textSecondary",
    hoverText = "text",
  },
  primary = {
    normal = { "accentSoft", "accent" },
    hover = { "surfacePressed", "accentBright" },
    pressed = { "surfaceHover", "accentBright" },
    text = "text",
    hoverText = "text",
  },
  success = {
    normal = { "success", "successBorder" },
    hover = { "success", "text" },
    pressed = { "surfaceHover", "successBorder" },
    text = "text",
    hoverText = "text",
  },
  danger = {
    normal = { "danger", "dangerBorder" },
    hover = { "danger", "text" },
    pressed = { "surfaceHover", "dangerBorder" },
    text = "text",
    hoverText = "text",
  },
  ghost = {
    normal = { "transparent", "transparent" },
    hover = { "surfaceHover", "borderStrong" },
    pressed = { "surfacePressed", "borderFocus" },
    text = "textMuted",
    hoverText = "text",
  },
  ghostDanger = {
    normal = { "transparent", "transparent" },
    hover = { "danger", "dangerBorder" },
    pressed = { "surfacePressed", "dangerBorder" },
    text = "dangerBorder",
    hoverText = "text",
  },
  tab = {
    normal = { "transparent", "transparent" },
    hover = { "surface", "transparent" },
    pressed = { "surfaceHover", "transparent" },
    active = { "transparent", "transparent" },
    text = "textMuted",
    hoverText = "text",
    activeText = "accentBright",
  },
}

local function ResolveColor(color)
  if type(color) == "string" then
    return Theme.colors[color] or Theme.colors.text
  end
  if type(color) == "table" then
    return color
  end
  return Theme.colors.text
end

local function SetRegionColor(region, method, color)
  if not region or type(region[method]) ~= "function" then
    return
  end
  local value = ResolveColor(color)
  region[method](region, value[1], value[2], value[3], value[4] == nil and 1 or value[4])
end

local function HideRegion(region)
  if region and region.SetAlpha then
    region:SetAlpha(0)
  end
end

local function HideButtonStateTexture(button, fieldName, getterName)
  if not button then
    return
  end

  local texture = button[fieldName]
  local getter = button[getterName]
  if not texture and type(getter) == "function" then
    texture = getter(button)
  end
  HideRegion(texture)
end

local function HideTextureRegions(frame)
  if not frame or not frame.GetRegions then
    return
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      HideRegion(region)
    end
  end
end

function Theme.GetColor(color)
  return ResolveColor(color)
end

function Theme.SetText(fontString, color)
  SetRegionColor(fontString, "SetTextColor", color)
end

function Theme.SetTexture(texture, color)
  SetRegionColor(texture, "SetVertexColor", color)
end

function Theme.SetBackdrop(frame, background, border)
  if not frame or not frame.SetBackdrop then
    return
  end
  frame:SetBackdrop(Theme.backdrop)
  SetRegionColor(frame, "SetBackdropColor", background or "surface")
  SetRegionColor(frame, "SetBackdropBorderColor", border or "border")
end

function Theme.StyleSurface(frame, background, border)
  Theme.SetBackdrop(frame, background or "surface", border or "border")
end

function Theme.CreateAccentLine(parent, height, color)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetTexture(WHITE_TEXTURE)
  line:SetHeight(height or 2)
  Theme.SetTexture(line, color or "accent")
  return line
end

local function EnsureFlatBox(owner, insets)
  if owner._popAurasFlatBox then
    return owner._popAurasFlatBox
  end

  insets = insets or {}
  local left = insets.left or 0
  local right = insets.right or 0
  local top = insets.top or 0
  local bottom = insets.bottom or 0
  local box = {}

  box.background = owner:CreateTexture(nil, "BACKGROUND", nil, -7)
  box.background:SetTexture(WHITE_TEXTURE)
  box.background:SetPoint("TOPLEFT", owner, "TOPLEFT", left, -top)
  box.background:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -right, bottom)

  box.top = owner:CreateTexture(nil, "BORDER")
  box.top:SetTexture(WHITE_TEXTURE)
  box.top:SetPoint("TOPLEFT", box.background, "TOPLEFT", 0, 0)
  box.top:SetPoint("TOPRIGHT", box.background, "TOPRIGHT", 0, 0)
  box.top:SetHeight(1)

  box.bottom = owner:CreateTexture(nil, "BORDER")
  box.bottom:SetTexture(WHITE_TEXTURE)
  box.bottom:SetPoint("BOTTOMLEFT", box.background, "BOTTOMLEFT", 0, 0)
  box.bottom:SetPoint("BOTTOMRIGHT", box.background, "BOTTOMRIGHT", 0, 0)
  box.bottom:SetHeight(1)

  box.left = owner:CreateTexture(nil, "BORDER")
  box.left:SetTexture(WHITE_TEXTURE)
  box.left:SetPoint("TOPLEFT", box.background, "TOPLEFT", 0, 0)
  box.left:SetPoint("BOTTOMLEFT", box.background, "BOTTOMLEFT", 0, 0)
  box.left:SetWidth(1)

  box.right = owner:CreateTexture(nil, "BORDER")
  box.right:SetTexture(WHITE_TEXTURE)
  box.right:SetPoint("TOPRIGHT", box.background, "TOPRIGHT", 0, 0)
  box.right:SetPoint("BOTTOMRIGHT", box.background, "BOTTOMRIGHT", 0, 0)
  box.right:SetWidth(1)

  owner._popAurasFlatBox = box
  return box
end

local function SetFlatBoxColors(owner, background, border)
  local box = owner and owner._popAurasFlatBox
  if not box then
    return
  end
  Theme.SetTexture(box.background, background)
  Theme.SetTexture(box.top, border)
  Theme.SetTexture(box.bottom, border)
  Theme.SetTexture(box.left, border)
  Theme.SetTexture(box.right, border)
end

function Theme.ApplyButtonState(button, state)
  if not button then
    return
  end

  local style = buttonStyles[button._popAurasButtonStyle or "secondary"] or buttonStyles.secondary
  local stateStyle
  if button._popAurasTabActive and style.active then
    stateStyle = style.active
  else
    stateStyle = style[state or "normal"] or style.normal
  end

  Theme.SetBackdrop(button, stateStyle[1], stateStyle[2])
  local fontString = button.GetFontString and button:GetFontString() or button.Text
  if button._popAurasTabActive and style.activeText then
    Theme.SetText(fontString, style.activeText)
  elseif state == "hover" or state == "pressed" then
    Theme.SetText(fontString, style.hoverText or style.text)
  else
    Theme.SetText(fontString, style.text)
  end

  if button._popAurasActiveLine then
    button._popAurasActiveLine:SetShown(button._popAurasTabActive == true)
  end
end

function Theme.StyleButton(button, styleKey)
  if not button then
    return
  end
  button._popAurasButtonStyle = styleKey or "secondary"
  Theme.ApplyButtonState(button, "normal")

  if not button._popAurasButtonHooks then
    button._popAurasButtonHooks = true
    button:HookScript("OnEnter", function(self)
      Theme.ApplyButtonState(self, "hover")
    end)
    button:HookScript("OnLeave", function(self)
      Theme.ApplyButtonState(self, "normal")
    end)
    button:HookScript("OnMouseDown", function(self)
      Theme.ApplyButtonState(self, "pressed")
    end)
    button:HookScript("OnMouseUp", function(self)
      Theme.ApplyButtonState(self, self:IsMouseOver() and "hover" or "normal")
    end)
  end
end

function Theme.StyleTab(button, active)
  if not button then
    return
  end
  button._popAurasTabActive = active == true
  if not button._popAurasActiveLine then
    button._popAurasActiveLine = Theme.CreateAccentLine(button, 2, "accentBright")
    button._popAurasActiveLine:SetPoint("BOTTOMLEFT", 0, 0)
    button._popAurasActiveLine:SetPoint("BOTTOMRIGHT", 0, 0)
  end
  Theme.StyleButton(button, "tab")
end

function Theme.StyleEditBox(input)
  if not input then
    return
  end

  HideTextureRegions(input)
  EnsureFlatBox(input, { left = 0, right = 0, top = 1, bottom = 1 })
  SetFlatBoxColors(input, "control", "border")
  Theme.SetText(input, "text")

  if not input._popAurasEditHooks then
    input._popAurasEditHooks = true
    input:HookScript("OnEditFocusGained", function(self)
      SetFlatBoxColors(self, "surface", "borderFocus")
    end)
    input:HookScript("OnEditFocusLost", function(self)
      SetFlatBoxColors(self, "control", "border")
    end)
  end
end

function Theme.StyleCheckbox(check)
  if not check then
    return
  end

  check:SetNormalTexture(WHITE_TEXTURE)
  check:SetPushedTexture(WHITE_TEXTURE)
  check:SetHighlightTexture(WHITE_TEXTURE, "ADD")
  check:SetCheckedTexture(WHITE_TEXTURE)
  check:SetDisabledCheckedTexture(WHITE_TEXTURE)

  local normal = check:GetNormalTexture()
  normal:ClearAllPoints()
  normal:SetPoint("CENTER")
  normal:SetSize(18, 18)
  Theme.SetTexture(normal, "surfaceRaised")

  local pushed = check:GetPushedTexture()
  pushed:ClearAllPoints()
  pushed:SetPoint("CENTER")
  pushed:SetSize(18, 18)
  Theme.SetTexture(pushed, "surfacePressed")

  local highlight = check:GetHighlightTexture()
  highlight:ClearAllPoints()
  highlight:SetPoint("CENTER")
  highlight:SetSize(18, 18)
  local highlightColor = Theme.GetColor("accent")
  highlight:SetVertexColor(highlightColor[1], highlightColor[2], highlightColor[3], 0.24)

  local checked = check:GetCheckedTexture()
  checked:ClearAllPoints()
  checked:SetPoint("CENTER")
  checked:SetSize(10, 10)
  Theme.SetTexture(checked, "accentBright")

  local disabledChecked = check:GetDisabledCheckedTexture()
  disabledChecked:ClearAllPoints()
  disabledChecked:SetPoint("CENTER")
  disabledChecked:SetSize(10, 10)
  Theme.SetTexture(disabledChecked, "textMuted")

  Theme.SetText(check.Text, "textSecondary")
end

local function PositionToggleKnob(check, offsetX)
  check._popAurasToggleKnob:ClearAllPoints()
  check._popAurasToggleKnob:SetPoint("CENTER", check, "CENTER", offsetX, 0)
  check._popAurasToggleX = offsetX
end

function Theme.UpdateToggle(check, animate)
  if not check or not check._popAurasToggleKnob then
    return
  end

  local checked = check:GetChecked() and true or false
  local targetX = checked and 10 or -10
  SetFlatBoxColors(check, checked and "accentSoft" or "surfaceRaised", checked and "accent" or "border")
  Theme.SetTexture(check._popAurasToggleKnob, checked and "accentBright" or "textSecondary")

  local currentX = tonumber(check._popAurasToggleX)
  if animate and currentX and math.abs(targetX - currentX) > 0.1 then
    local startX = currentX
    local elapsedTotal = 0
    check:SetScript("OnUpdate", function(self, elapsed)
      elapsedTotal = elapsedTotal + (tonumber(elapsed) or 0)
      local progress = math.min(1, elapsedTotal / 0.12)
      local eased = 1 - ((1 - progress) * (1 - progress))
      PositionToggleKnob(self, startX + ((targetX - startX) * eased))
      if progress >= 1 then
        self:SetScript("OnUpdate", nil)
      end
    end)
  else
    check:SetScript("OnUpdate", nil)
    PositionToggleKnob(check, targetX)
  end
end

function Theme.StyleToggle(check)
  if not check then
    return
  end

  HideTextureRegions(check)
  EnsureFlatBox(check)
  if not check._popAurasToggleKnob then
    check._popAurasToggleKnob = check:CreateTexture(nil, "OVERLAY")
    check._popAurasToggleKnob:SetTexture(WHITE_TEXTURE)
    check._popAurasToggleKnob:SetSize(14, 14)
  end

  if not check._popAurasToggleHooks then
    check._popAurasToggleHooks = true
    check:HookScript("OnClick", function(self)
      Theme.UpdateToggle(self, true)
    end)
    check:HookScript("OnShow", function(self)
      Theme.UpdateToggle(self)
    end)
    check:HookScript("OnEnter", function(self)
      local checked = self:GetChecked() and true or false
      SetFlatBoxColors(self, checked and "accentSoft" or "surfaceHover", checked and "accentBright" or "borderFocus")
    end)
    check:HookScript("OnLeave", function(self)
      Theme.UpdateToggle(self)
    end)
  end

  Theme.UpdateToggle(check)
end

local function ApplyDropdownState(dropdown, hovered)
  if dropdown._popAurasDropdownStyle == "success" then
    SetFlatBoxColors(dropdown, "success", hovered and "text" or "successBorder")
    Theme.SetText(dropdown.Text, "text")
    Theme.SetText(dropdown._popAurasArrow, hovered and "text" or "successBorder")
  else
    SetFlatBoxColors(dropdown, hovered and "surfaceRaised" or "control", hovered and "borderFocus" or "border")
    Theme.SetText(dropdown.Text, hovered and "text" or "textSecondary")
    Theme.SetText(dropdown._popAurasArrow, hovered and "accentBright" or "textAccent")
  end
end

local function GetNamedDropdownRegion(button, suffix, fieldName)
  if not button then
    return nil
  end
  if fieldName and button[fieldName] then
    return button[fieldName]
  end
  local name = button.GetName and button:GetName() or nil
  return name and _G[name .. suffix] or nil
end

local function StyleDropdownMenuButton(button)
  if not button then
    return
  end

  local fontString = button.GetFontString and button:GetFontString()
    or button.NormalText
    or GetNamedDropdownRegion(button, "NormalText")
  if fontString then
    Fonts.Apply(fontString, 12, "")
    Theme.SetText(fontString, "text")
  end

  local highlight = GetNamedDropdownRegion(button, "Highlight", "Highlight")
  if highlight then
    highlight:SetTexture(WHITE_TEXTURE)
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 3, 0)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 0)
    local hover = Theme.GetColor("surfaceHover")
    highlight:SetVertexColor(hover[1], hover[2], hover[3], 0.92)
  end

  local check = GetNamedDropdownRegion(button, "Check", "Check")
  if check then
    check:SetTexture(WHITE_TEXTURE)
    check:ClearAllPoints()
    check:SetPoint("LEFT", button, "LEFT", 4, 0)
    check:SetSize(3, 14)
    Theme.SetTexture(check, "accentBright")
  end
  HideRegion(GetNamedDropdownRegion(button, "UnCheck", "UnCheck"))

  local arrow = GetNamedDropdownRegion(button, "ExpandArrow", "Arrow")
  if arrow then
    Theme.SetTexture(arrow, "textAccent")
  end

  if not button._popAurasMenuDivider then
    button._popAurasMenuDivider = button:CreateTexture(nil, "BORDER")
    button._popAurasMenuDivider:SetTexture(WHITE_TEXTURE)
    button._popAurasMenuDivider:SetPoint("BOTTOMLEFT", 4, 0)
    button._popAurasMenuDivider:SetPoint("BOTTOMRIGHT", -4, 0)
    button._popAurasMenuDivider:SetHeight(1)
  end
  Theme.SetTexture(button._popAurasMenuDivider, "border")
end

local function StyleDropdownMenuLevel(level)
  local list = _G["DropDownList" .. tostring(level)]
  if not list or not list:IsShown() then
    return
  end

  local name = list.GetName and list:GetName() or nil
  if not list._popAurasMenuStyled then
    list._popAurasMenuStyled = true
    HideTextureRegions(list)
    if name then
      HideRegion(_G[name .. "Backdrop"])
      HideRegion(_G[name .. "MenuBackdrop"])
    end
    HideRegion(list.Backdrop)
    HideRegion(list.MenuBackdrop)
    HideRegion(list.NineSlice)
    EnsureFlatBox(list, { left = 7, right = 7, top = 7, bottom = 7 })
  end
  SetFlatBoxColors(list, "canvasAlt", "borderStrong")

  local buttonCount = math.max(tonumber(list.numButtons) or 0, tonumber(UIDROPDOWNMENU_MAXBUTTONS) or 32)
  for index = 1, buttonCount do
    local button = name and _G[name .. "Button" .. index] or nil
    if button and button:IsShown() then
      StyleDropdownMenuButton(button)
    end
  end
end

function Theme.StyleVisibleDropdownMenus()
  for level = 1, 3 do
    StyleDropdownMenuLevel(level)
  end
end

function Theme.InstallDropdownMenuSkin()
  if Theme._dropdownMenuSkinInstalled or type(hooksecurefunc) ~= "function" or type(ToggleDropDownMenu) ~= "function" then
    return
  end
  Theme._dropdownMenuSkinInstalled = true
  hooksecurefunc("ToggleDropDownMenu", function()
    Theme.StyleVisibleDropdownMenus()
    if C_Timer and C_Timer.After then
      C_Timer.After(0, Theme.StyleVisibleDropdownMenus)
    end
  end)
end

function Theme.StyleDropdown(dropdown, styleKey)
  if not dropdown then
    return
  end
  if styleKey then
    dropdown._popAurasDropdownStyle = styleKey
  end
  Theme.InstallDropdownMenuSkin()

  if not dropdown._popAurasFlatBox then
    HideTextureRegions(dropdown)
    EnsureFlatBox(dropdown, { left = 16, right = 16, top = 5, bottom = 7 })
  end

  local button = dropdown.Button
  if button then
    HideButtonStateTexture(button, "NormalTexture", "GetNormalTexture")
    HideButtonStateTexture(button, "PushedTexture", "GetPushedTexture")
    HideButtonStateTexture(button, "DisabledTexture", "GetDisabledTexture")
    HideButtonStateTexture(button, "HighlightTexture", "GetHighlightTexture")
  end

  if not dropdown._popAurasArrow then
    dropdown._popAurasArrow = dropdown:CreateFontString(nil, "OVERLAY")
    Fonts.Apply(dropdown._popAurasArrow, 11, "")
    dropdown._popAurasArrow:SetPoint("RIGHT", dropdown, "RIGHT", -23, 1)
    dropdown._popAurasArrow:SetText("v")
  end

  ApplyDropdownState(dropdown, false)
  if button and not dropdown._popAurasDropdownHooks then
    dropdown._popAurasDropdownHooks = true
    button:HookScript("OnEnter", function()
      ApplyDropdownState(dropdown, true)
    end)
    button:HookScript("OnLeave", function()
      ApplyDropdownState(dropdown, false)
    end)
  end
end

local function StyleScrollButton(button, label)
  if not button then
    return
  end

  button:SetNormalTexture(WHITE_TEXTURE)
  button:SetPushedTexture(WHITE_TEXTURE)
  button:SetHighlightTexture(WHITE_TEXTURE, "ADD")

  Theme.SetTexture(button:GetNormalTexture(), "surfaceRaised")
  Theme.SetTexture(button:GetPushedTexture(), "surfacePressed")
  local highlight = button:GetHighlightTexture()
  local accent = Theme.GetColor("accent")
  highlight:SetVertexColor(accent[1], accent[2], accent[3], 0.28)

  if not button._popAurasScrollLabel then
    button._popAurasScrollLabel = button:CreateFontString(nil, "OVERLAY")
    Fonts.Apply(button._popAurasScrollLabel, 10, "")
    button._popAurasScrollLabel:SetPoint("CENTER", 0, 0)
    button._popAurasScrollLabel:SetText(label)
    Theme.SetText(button._popAurasScrollLabel, "textAccent")
  end
end

function Theme.StyleScrollFrame(scrollFrame)
  if not scrollFrame then
    return
  end

  local scrollBar = scrollFrame.ScrollBar
  if not scrollBar and scrollFrame.GetChildren then
    for _, child in ipairs({ scrollFrame:GetChildren() }) do
      if child and child.GetThumbTexture then
        scrollBar = child
        break
      end
    end
  end
  if not scrollBar then
    return
  end

  if scrollBar.Background then
    scrollBar.Background:SetTexture(WHITE_TEXTURE)
    Theme.SetTexture(scrollBar.Background, "canvas")
  end

  local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture() or scrollBar.ThumbTexture
  if thumb then
    thumb:SetTexture(WHITE_TEXTURE)
    thumb:SetWidth(6)
    Theme.SetTexture(thumb, "accent")
  end

  StyleScrollButton(scrollBar.ScrollUpButton or scrollBar.UpButton, "^")
  StyleScrollButton(scrollBar.ScrollDownButton or scrollBar.DownButton, "v")
end
