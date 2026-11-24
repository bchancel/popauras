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

-- One accent family (EllesmereUI-style teal) over hue-biased dark neutrals.
-- `navigation` is the quiet uppercase section-title colour, not a second accent.
Theme.colors = {
  transparent = { 0.000, 0.000, 0.000, 0.00 },
  canvas = { 0.050, 0.068, 0.085, 0.99 },
  canvasAlt = { 0.039, 0.053, 0.068, 0.99 },
  control = { 0.075, 0.108, 0.135, 0.95 },
  surface = { 0.068, 0.090, 0.110, 0.98 },
  surfaceRaised = { 0.088, 0.115, 0.138, 0.99 },
  surfaceHover = { 0.105, 0.140, 0.165, 1.00 },
  surfacePressed = { 0.045, 0.210, 0.170, 1.00 },
  rowOdd = { 0.060, 0.080, 0.098, 0.96 },
  rowEven = { 0.074, 0.097, 0.117, 0.96 },
  accentSoft = { 0.028, 0.200, 0.155, 0.96 },
  accent = { 0.047, 0.824, 0.616, 1.00 },
  accentBright = { 0.330, 0.930, 0.760, 1.00 },
  border = { 0.150, 0.185, 0.210, 1.00 },
  borderStrong = { 0.205, 0.250, 0.280, 1.00 },
  borderFocus = { 0.047, 0.700, 0.525, 1.00 },
  text = { 0.950, 0.960, 0.970, 1.00 },
  textSecondary = { 0.760, 0.790, 0.810, 1.00 },
  textMuted = { 0.520, 0.560, 0.590, 1.00 },
  textAccent = { 0.180, 0.860, 0.660, 1.00 },
  groupAccent = { 0.180, 0.860, 0.660, 1.00 },
  navigation = { 0.560, 0.600, 0.630, 1.00 },
  success = { 0.028, 0.200, 0.155, 1.00 },
  successBorder = { 0.047, 0.824, 0.616, 1.00 },
  danger = { 0.310, 0.055, 0.070, 0.92 },
  dangerBorder = { 0.880, 0.345, 0.370, 1.00 },
  toggleTrackOff = { 0.180, 0.215, 0.240, 1.00 },
  toggleKnobOff = { 0.620, 0.650, 0.670, 1.00 },
  toggleKnobOn = { 1.000, 1.000, 1.000, 1.00 },
}

Theme.primaryFont = "Fonts\\ARIALN.TTF"

-- Editor-only glyph/shape textures ship with PopAuras_Options (the editor is
-- the only consumer of these Theme widgets).
Theme.SHAPE_PATH = "Interface\\AddOns\\PopAuras_Options\\Media\\Icons\\"
local PILL_TEXTURE = Theme.SHAPE_PATH .. "UiPill"
local KNOB_TEXTURE = Theme.SHAPE_PATH .. "UiKnob"
local CHEVRON_TEXTURE = Theme.SHAPE_PATH .. "UiChevron"

-- When EllesmereUI is installed, the editor borrows its Expressway face so the
-- two configuration windows read as one family. Probed once; falls back to
-- Arial Narrow if the file cannot be loaded.
local ELLESMERE_EDITOR_FONT = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF"

function Theme.GetEditorFont()
  if Theme._editorFont == nil then
    Theme._editorFont = false
    local Media = ns.util.Media
    if Media and Media.IsEllesmereAvailable and Media:IsEllesmereAvailable() and UIParent then
      local probe = UIParent:CreateFontString(nil, "OVERLAY")
      local ok, loaded = pcall(probe.SetFont, probe, ELLESMERE_EDITOR_FONT, 12, "")
      if ok and loaded then
        Theme._editorFont = ELLESMERE_EDITOR_FONT
      end
      probe:Hide()
    end
  end
  return Theme._editorFont or Theme.primaryFont
end

Theme.typography = {
  micro = { size = 9, outline = "" },
  caption = { size = 11, outline = "" },
  bodySmall = { size = 12, outline = "" },
  body = { size = 13, outline = "" },
  controlSmall = { size = 12, outline = "" },
  control = { size = 13, outline = "" },
  controlEmphasis = { size = 14, outline = "" },
  cardTitle = { size = 14, outline = "OUTLINE" },
  sectionTitle = { size = 17, outline = "" },
  panelTitle = { size = 24, outline = "" },
  windowTitle = { size = 22, outline = "" },
  brand = { size = 14, outline = "" },
  glyphSmall = { size = 13, outline = "OUTLINE" },
  glyph = { size = 15, outline = "OUTLINE" },
  glyphLarge = { size = 22, outline = "OUTLINE" },
  illustration = { size = 32, outline = "OUTLINE" },
  hero = { size = 36, outline = "OUTLINE" },
  mono = { size = 11, outline = "", file = "Fonts\\ARIALN.TTF" },
}

Theme.layout = {
  pixel = 1,
  panelPadding = 28,
  panelGap = 14,
  sectionGap = 12,
  sectionHeaderHeight = 30,
  compactSectionHeaderHeight = 28,
  rowHeight = 46,
  controlHeight = 28,
  fieldGap = 4,
  columnGap = 28,
  contentInset = 12,
  dropdownLabelOffsetX = -14,
  dropdownLabelOffsetY = -2,
  standardInputWidth = 120,
  standardDropdownWidth = 180,
  standardContentWidth = 720,
  scrollBarInset = 26,
  wheelStep = 42,
  sidebarWidth = 340,
  toolbarHeight = 52,
  primaryTabHeight = 38,
  secondaryTabHeight = 32,
  auraRowHeight = 40,
  auraRowStep = 46,
}

function Theme.ApplyTypography(fontString, role, outlineOverride)
  if not fontString then
    return
  end
  local definition = Theme.typography[role or "body"] or Theme.typography.body
  Fonts.Apply(
    fontString,
    definition.size,
    outlineOverride == nil and definition.outline or outlineOverride,
    definition.file or Theme.GetEditorFont()
  )
end

-- For previews that must mirror an aura's own configured font size instead of
-- an editor typography role. Keeps every editor font call routed via Theme.
function Theme.ApplyFontSize(fontString, size, outline)
  if not fontString then
    return
  end
  local resolved = math.max(6, math.floor((tonumber(size) or 12) + 0.5))
  Fonts.Apply(fontString, resolved, outline or "", Theme.primaryFont)
end

function Theme.PixelSetPoint(region, point, relativeTo, relativePoint, x, y)
  if PixelUtil and PixelUtil.SetPoint then
    PixelUtil.SetPoint(region, point, relativeTo, relativePoint, x or 0, y or 0)
  else
    region:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
  end
end

function Theme.PixelSetSize(region, width, height)
  if PixelUtil and PixelUtil.SetSize then
    PixelUtil.SetSize(region, width, height)
  else
    region:SetSize(width, height)
  end
end

function Theme.PixelSetHeight(region, height)
  if PixelUtil and PixelUtil.SetHeight then
    PixelUtil.SetHeight(region, height)
  else
    region:SetHeight(height)
  end
end

function Theme.PixelSetWidth(region, width)
  if PixelUtil and PixelUtil.SetWidth then
    PixelUtil.SetWidth(region, width)
  else
    region:SetWidth(width)
  end
end

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
  Theme.PixelSetHeight(line, height or 2)
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

-- Pill switch: a rounded 38x20 track (accent when on, dim when off) with a
-- round 14px knob that slides between the ends. The track is drawn centred in
-- whatever hit area the caller sized, so existing layouts keep their spacing.
local TOGGLE_TRACK_W, TOGGLE_TRACK_H, TOGGLE_KNOB = 38, 20, 14
local TOGGLE_KNOB_X = (TOGGLE_TRACK_W - TOGGLE_KNOB) / 2 - 3

local function PositionToggleKnob(check, offsetX)
  check._popAurasToggleKnob:ClearAllPoints()
  check._popAurasToggleKnob:SetPoint("CENTER", check._popAurasToggleTrack, "CENTER", offsetX, 0)
  check._popAurasToggleX = offsetX
end

local function ApplyToggleColors(check, hovered)
  local checked = check:GetChecked() and true or false
  local enabled = not check.IsEnabled or check:IsEnabled()
  local track = check._popAurasToggleTrack
  if checked then
    local accent = Theme.GetColor(hovered and "accentBright" or "accent")
    track:SetVertexColor(accent[1], accent[2], accent[3], 0.90)
  else
    local off = Theme.GetColor(hovered and "borderStrong" or "toggleTrackOff")
    track:SetVertexColor(off[1], off[2], off[3], 1)
  end
  Theme.SetTexture(check._popAurasToggleKnob, checked and "toggleKnobOn" or "toggleKnobOff")
  track:SetAlpha(enabled and 1 or 0.4)
  check._popAurasToggleKnob:SetAlpha(enabled and 1 or 0.4)
end

function Theme.UpdateToggle(check, animate)
  if not check or not check._popAurasToggleKnob then
    return
  end

  local checked = check:GetChecked() and true or false
  local targetX = checked and TOGGLE_KNOB_X or -TOGGLE_KNOB_X
  ApplyToggleColors(check, check._popAurasToggleHovered == true)

  local currentX = tonumber(check._popAurasToggleX)
  if animate and currentX and math.abs(targetX - currentX) > 0.1 then
    local startX = currentX
    local elapsedTotal = 0
    check:SetScript("OnUpdate", function(self, elapsed)
      elapsedTotal = elapsedTotal + (tonumber(elapsed) or 0)
      local progress = math.min(1, elapsedTotal / 0.09)
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
  if not check._popAurasToggleTrack then
    check._popAurasToggleTrack = check:CreateTexture(nil, "ARTWORK", nil, 1)
    check._popAurasToggleTrack:SetTexture(PILL_TEXTURE)
    check._popAurasToggleTrack:SetSize(TOGGLE_TRACK_W, TOGGLE_TRACK_H)
    check._popAurasToggleTrack:SetPoint("CENTER")
  end
  if not check._popAurasToggleKnob then
    check._popAurasToggleKnob = check:CreateTexture(nil, "OVERLAY")
    check._popAurasToggleKnob:SetTexture(KNOB_TEXTURE)
    check._popAurasToggleKnob:SetSize(TOGGLE_KNOB, TOGGLE_KNOB)
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
      self._popAurasToggleHovered = true
      ApplyToggleColors(self, true)
    end)
    check:HookScript("OnLeave", function(self)
      self._popAurasToggleHovered = false
      ApplyToggleColors(self, false)
    end)
    -- Panels often call SetChecked/Enable/Disable directly while refreshing;
    -- keep the switch visual in step without every caller remembering to.
    if type(hooksecurefunc) == "function" then
      hooksecurefunc(check, "SetChecked", function(self) Theme.UpdateToggle(self) end)
      hooksecurefunc(check, "SetEnabled", function(self) ApplyToggleColors(self, false) end)
      hooksecurefunc(check, "Enable", function(self) ApplyToggleColors(self, false) end)
      hooksecurefunc(check, "Disable", function(self) ApplyToggleColors(self, false) end)
    end
  end

  Theme.UpdateToggle(check)
end

local function ApplyDropdownState(dropdown, hovered)
  if dropdown._popAurasDropdownStyle == "success" then
    SetFlatBoxColors(dropdown, "success", hovered and "text" or "successBorder")
    Theme.SetText(dropdown.Text, "text")
    Theme.SetTexture(dropdown._popAurasArrow, hovered and "text" or "successBorder")
  else
    SetFlatBoxColors(dropdown, hovered and "surfaceRaised" or "control", hovered and "borderFocus" or "border")
    Theme.SetText(dropdown.Text, hovered and "text" or "textSecondary")
    Theme.SetTexture(dropdown._popAurasArrow, hovered and "text" or "textMuted")
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
    dropdown._popAurasArrow = dropdown:CreateTexture(nil, "OVERLAY")
    dropdown._popAurasArrow:SetTexture(CHEVRON_TEXTURE)
    dropdown._popAurasArrow:SetSize(12, 12)
    dropdown._popAurasArrow:SetPoint("RIGHT", dropdown, "RIGHT", -24, 1)
  end

  if dropdown.Text then
    dropdown.Text:ClearAllPoints()
    dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", 20, 1)
    dropdown.Text:SetPoint("RIGHT", dropdown, "RIGHT", -38, 1)
    dropdown.Text:SetJustifyH("LEFT")
    dropdown.Text:SetWordWrap(false)
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

  -- EllesmereUI-style scrollbars have no step arrows: wheel and thumb only.
  HideTextureRegions(button)
  HideButtonStateTexture(button, "NormalTexture", "GetNormalTexture")
  HideButtonStateTexture(button, "PushedTexture", "GetPushedTexture")
  HideButtonStateTexture(button, "DisabledTexture", "GetDisabledTexture")
  HideButtonStateTexture(button, "HighlightTexture", "GetHighlightTexture")
  if button._popAurasScrollLabel then
    button._popAurasScrollLabel:Hide()
  end
  button:SetSize(8, 1)
  button:SetAlpha(0)
  button:EnableMouse(false)
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

  scrollBar:SetWidth(8)
  HideRegion(scrollBar.Track)

  if not scrollBar._popAurasTrack then
    scrollBar._popAurasTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
    scrollBar._popAurasTrack:SetTexture(WHITE_TEXTURE)
    scrollBar._popAurasTrack:SetPoint("TOP", 0, -2)
    scrollBar._popAurasTrack:SetPoint("BOTTOM", 0, 2)
    scrollBar._popAurasTrack:SetWidth(2)
  end
  Theme.SetTexture(scrollBar._popAurasTrack, "border")

  if scrollBar.Background then
    HideRegion(scrollBar.Background)
  end

  local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture() or scrollBar.ThumbTexture
  if thumb then
    thumb:SetTexture(WHITE_TEXTURE)
    thumb:SetWidth(4)
    Theme.SetTexture(thumb, "textMuted")
  end

  local upButton = scrollBar.ScrollUpButton or scrollBar.UpButton
  local downButton = scrollBar.ScrollDownButton or scrollBar.DownButton
  if (not upButton or not downButton) and scrollBar.GetChildren then
    local buttons = {}
    for _, child in ipairs({ scrollBar:GetChildren() }) do
      if child and child.GetObjectType and child:GetObjectType() == "Button" then
        buttons[#buttons + 1] = child
      end
    end
    if #buttons >= 2 then
      table.sort(buttons, function(left, right)
        return (left:GetTop() or 0) > (right:GetTop() or 0)
      end)
      upButton = upButton or buttons[1]
      downButton = downButton or buttons[#buttons]
    end
  end
  StyleScrollButton(upButton, "^")
  StyleScrollButton(downButton, "v")
end
