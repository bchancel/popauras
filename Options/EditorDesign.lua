local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme
local Layout = Theme.layout

function Frames.CreateSectionCard(parent, title, y, height, options)
  options = type(options) == "table" and options or {}
  local showHeader = options.showHeader == true
  local showRows = options.showRows == true
  local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Theme.StyleSurface(
    section,
    options.background or (showHeader and "surface" or "transparent"),
    options.border or (showHeader and "border" or "transparent")
  )
  section.insetLeft = options.insetLeft or 0
  section.insetRight = options.insetRight or 0
  section:SetPoint("TOPLEFT", section.insetLeft, y)
  section:SetPoint("TOPRIGHT", -section.insetRight, y)
  Theme.PixelSetHeight(section, height)

  section.header = CreateFrame("Frame", nil, section, "BackdropTemplate")
  section.header:SetPoint("TOPLEFT", 1, -1)
  section.header:SetPoint("TOPRIGHT", -1, -1)
  Theme.PixelSetHeight(section.header, options.headerHeight or Layout.sectionHeaderHeight)
  Theme.StyleSurface(section.header, "canvasAlt", "borderStrong")
  section.header:SetShown(showHeader)

  if options.chevron then
    section.chevron = section.header:CreateFontString(nil, "OVERLAY")
    Theme.ApplyTypography(section.chevron, "control", "OUTLINE")
    section.chevron:SetPoint("LEFT", 10, 0)
    section.chevron:SetText("")
    section.chevron:Hide()
    Theme.SetText(section.chevron, "textAccent")
  end

  section.title = Frames.CreateLabel(section.header, title, "GameFontNormal", "control")
  section.title:SetPoint("LEFT", options.titleInset or 10, 0)
  section.title:SetText(string.upper(title or ""))
  Theme.SetText(section.title, "groupAccent")

  if options.bodyDivider then
    section.bodyTop = section:CreateTexture(nil, "BORDER")
    section.bodyTop:SetTexture("Interface\\Buttons\\WHITE8x8")
    Theme.SetTexture(section.bodyTop, "borderStrong")
    section.bodyTop:SetPoint("TOPLEFT", section.header, "BOTTOMLEFT", 0, -1)
    section.bodyTop:SetPoint("TOPRIGHT", section.header, "BOTTOMRIGHT", 0, -1)
    Theme.PixelSetHeight(section.bodyTop, Layout.pixel)
    section.bodyTop:SetShown(showHeader and options.hideDivider ~= true)
  end

  section.rowBands = {}
  local headerHeight = options.headerHeight or Layout.sectionHeaderHeight
  local bodyOffset = showHeader and (headerHeight + 2) or 1
  for index = 1, showRows and 16 or 0 do
    local band = section:CreateTexture(nil, "BACKGROUND", nil, -4)
    band:SetTexture("Interface\\Buttons\\WHITE8x8")
    band:SetPoint("TOPLEFT", 1, -(bodyOffset + ((index - 1) * 52)))
    band:SetPoint("TOPRIGHT", -1, -(bodyOffset + ((index - 1) * 52)))
    band:SetHeight(51)
    Theme.SetTexture(band, index % 2 == 0 and "rowEven" or "rowOdd")
    section.rowBands[index] = band
  end

  local function UpdateRowBands(selfSection)
    if selfSection._popAurasUseGridCells then
      for _, band in ipairs(selfSection.rowBands) do
        band:Hide()
      end
      return
    end
    local usable = math.max(0, (selfSection:GetHeight() or 0) - bodyOffset)
    for index, band in ipairs(selfSection.rowBands) do
      band:SetShown(((index - 1) * 52) < usable)
    end
  end
  section:HookScript("OnSizeChanged", UpdateRowBands)
  UpdateRowBands(section)

  section.expandedHeight = height
  section.collapsed = false
  section.bodyWidgets = {}
  return section
end

function Frames.ApplyPanelCanvas(content)
  if not content or content._popAurasCanvasApplied then return end
  content._popAurasCanvasApplied = true
  content._popAurasCanvas = content:CreateTexture(nil, "BACKGROUND", nil, -8)
  content._popAurasCanvas:SetAllPoints()
  content._popAurasCanvas:SetTexture("Interface\\Buttons\\WHITE8x8")
  Theme.SetTexture(content._popAurasCanvas, "canvas")
end

function Frames.CreateSettingsRow(parent, y, height, even)
  local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  row:SetPoint("TOPLEFT", 0, y)
  row:SetPoint("TOPRIGHT", 0, y)
  Theme.PixelSetHeight(row, height or 52)
  Theme.StyleSurface(row, even and "rowEven" or "rowOdd", "transparent")
  return row
end

function Frames.RegisterSectionWidgets(section, ...)
  section.bodyWidgets = section.bodyWidgets or {}
  for index = 1, select("#", ...) do
    local widget = select(index, ...)
    if widget then section.bodyWidgets[#section.bodyWidgets + 1] = widget end
  end
end

function Frames.CreateLabeledInput(parent, label, x, y, width)
  local widget = {}
  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall", "caption")
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.input = Frames.CreateInput(parent, width or Layout.standardInputWidth, Layout.controlHeight)
  widget.input:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", 0, -Layout.fieldGap)
  Theme.SetText(widget.label, "textSecondary")
  return widget
end

function Frames.PositionLabeledInput(widget, x, y)
  if not widget then return end
  widget.label:ClearAllPoints()
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.input:ClearAllPoints()
  widget.input:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", 0, -Layout.fieldGap)
end

function Frames.CreateLabeledDropdown(parent, label, x, y, width, initializer)
  local widget = {}
  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall", "caption")
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.dropdown = Frames.CreateDropdown(parent, width or Layout.standardDropdownWidth, initializer)
  widget.dropdown:SetPoint(
    "TOPLEFT",
    widget.label,
    "BOTTOMLEFT",
    Layout.dropdownLabelOffsetX,
    Layout.dropdownLabelOffsetY
  )
  Theme.SetText(widget.label, "textSecondary")
  return widget
end

function Frames.PositionLabeledDropdown(widget, x, y)
  if not widget then return end
  widget.label:ClearAllPoints()
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.dropdown:ClearAllPoints()
  widget.dropdown:SetPoint(
    "TOPLEFT",
    widget.label,
    "BOTTOMLEFT",
    Layout.dropdownLabelOffsetX,
    Layout.dropdownLabelOffsetY
  )
end

function Frames.CreateColorSwatch(parent, label, x, y)
  local widget = {}
  widget.button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  Theme.PixelSetSize(widget.button, 28, 28)
  widget.button:SetPoint("TOPLEFT", x, y)
  Theme.SetBackdrop(widget.button, "control", "border")
  widget.swatch = widget.button:CreateTexture(nil, "ARTWORK")
  widget.swatch:SetPoint("TOPLEFT", 4, -4)
  widget.swatch:SetPoint("BOTTOMRIGHT", -4, 4)
  widget.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall", "caption")
  widget.label:SetPoint("LEFT", widget.button, "RIGHT", 8, 0)
  widget.valueText = Frames.CreateLabel(parent, "", "GameFontHighlightSmall", "caption")
  widget.valueText:Hide()
  widget.color = { r = 1, g = 1, b = 1, a = 1 }
  return widget
end

function Frames.PositionColorSwatch(widget, x, y)
  if not widget then return end
  widget.button:ClearAllPoints()
  widget.button:SetPoint("TOPLEFT", x, y)
  widget.label:ClearAllPoints()
  widget.label:SetPoint("LEFT", widget.button, "RIGHT", 8, 0)
end

function Frames.CreateFieldRow(parent, y, fields)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", 0, y)
  row:SetPoint("TOPRIGHT", 0, y)
  Theme.PixelSetHeight(row, Layout.rowHeight)
  row.fields = fields or {}
  return row
end

function Frames.CreateTwoColumnRow(parent, y, left, right)
  return Frames.CreateFieldRow(parent, y, { left = left, right = right })
end
local activeSettingsPopover

function Frames.CreateCompactSlider(parent, minimum, maximum, step)
  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(minimum or 0, maximum or 100)
  slider:SetValueStep(step or 1)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetSize(150, 22)
  slider:EnableMouse(true)

  slider.track = slider:CreateTexture(nil, "BACKGROUND")
  slider.track:SetTexture("Interface\\Buttons\\WHITE8x8")
  slider.track:SetPoint("LEFT", 0, 0)
  slider.track:SetPoint("RIGHT", 0, 0)
  slider.track:SetHeight(4)
  Theme.SetTexture(slider.track, "border")

  slider.fill = slider:CreateTexture(nil, "ARTWORK")
  slider.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
  slider.fill:SetPoint("LEFT", slider.track, "LEFT", 0, 0)
  slider.fill:SetHeight(4)
  Theme.SetTexture(slider.fill, "navigation")

  slider.thumb = slider:CreateTexture(nil, "OVERLAY")
  slider.thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
  slider.thumb:SetSize(10, 18)
  Theme.SetTexture(slider.thumb, "accentBright")
  slider:SetThumbTexture(slider.thumb)

  slider:HookScript("OnValueChanged", function(self)
    self.fill:ClearAllPoints()
    self.fill:SetPoint("LEFT", self.track, "LEFT", 0, 0)
    self.fill:SetPoint("RIGHT", self.thumb, "CENTER", 0, 0)
  end)
  return slider
end

local function ResolveOptionEntries(values)
  values = type(values) == "function" and values() or values
  local entries = {}
  if type(values) ~= "table" then return entries end
  for _, entry in ipairs(values) do
    if type(entry) == "table" then
      entries[#entries + 1] = {
        value = entry.value ~= nil and entry.value or entry.key,
        label = entry.label or entry.text or tostring(entry.value or entry.key or ""),
      }
    else
      entries[#entries + 1] = { value = entry, label = tostring(entry) }
    end
  end
  return entries
end

local function FindOptionLabel(values, value)
  for _, entry in ipairs(ResolveOptionEntries(values)) do
    if entry.value == value then return entry.label end
  end
  return tostring(value or "")
end

function Frames.CreateGearButton(parent, tooltip)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  Theme.PixelSetSize(button, 28, 28)
  Theme.StyleButton(button, "ghost")
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("CENTER")
  button.icon:SetSize(18, 18)
  button.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  Theme.SetTexture(button.icon, "textSecondary")
  button.icon:SetDesaturated(true)
  button:SetScript("OnEnter", function(self)
    if not tooltip or tooltip == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tooltip)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return button
end

function Frames.CreateSettingsPopover(options)
  options = type(options) == "table" and options or {}
  local rows = options.rows or {}
  local width = options.width or 320
  local rowHeight = options.rowHeight or 42
  local titleHeight = 34
  local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  popup:SetSize(width, titleHeight + (#rows * rowHeight) + 12)
  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:SetFrameLevel(500)
  popup:SetClampedToScreen(true)
  popup:EnableMouse(true)
  popup:Hide()
  Theme.StyleSurface(popup, "canvasAlt", "borderStrong")

  popup.title = Frames.CreateLabel(popup, options.title or "Settings", "GameFontNormal", "controlEmphasis")
  popup.title:SetPoint("TOPLEFT", 12, -10)
  Theme.SetText(popup.title, "text")

  popup.close = Frames.CreateButton(popup, "x", 22, 20, function() popup:Hide() end)
  popup.close:SetPoint("TOPRIGHT", -7, -7)
  Theme.StyleButton(popup.close, "ghost")

  popup.widgets = {}
  for index, row in ipairs(rows) do
    local y = -(titleHeight + ((index - 1) * rowHeight))
    local band = Frames.CreateSettingsRow(popup, y, rowHeight, index % 2 == 0)
    local label = Frames.CreateLabel(band, row.label or "", "GameFontNormalSmall", "controlSmall")
    label:SetPoint("LEFT", 12, 0)
    label:SetWidth(math.max(80, width - 196))
    Theme.SetText(label, "textSecondary")
    local widget = { definition = row, band = band, label = label }

    if row.type == "dropdown" then
      local dropdown = Frames.CreateDropdown(band, row.width or 150)
      dropdown:SetPoint("RIGHT", band, "RIGHT", -2, 0)
      UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, entry in ipairs(ResolveOptionEntries(row.values)) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = entry.label
          info.value = entry.value
          info.func = function()
            if row.set then row.set(entry.value) end
            Frames.SetDropdownValue(dropdown, entry.value, entry.label)
            if options.onChanged then options.onChanged() end
            popup:Refresh()
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      widget.control = dropdown
    elseif row.type == "toggle" then
      local toggle = Frames.CreateToggle(band)
      toggle:SetPoint("RIGHT", band, "RIGHT", -12, 0)
      toggle:SetScript("OnClick", function(self)
        if row.set then row.set(self:GetChecked() == true) end
        if options.onChanged then options.onChanged() end
        popup:Refresh()
      end)
      widget.control = toggle
    elseif row.type == "color" then
      local swatch = Frames.CreateColorSwatch(band, "", width - 52, -7)
      swatch.label:Hide()
      swatch.button:SetScript("OnClick", function()
        local starting = row.get and row.get() or { r = 1, g = 1, b = 1, a = 1 }
        local function ApplyColor()
          local r, g, b = ColorPickerFrame:GetColorRGB()
          local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or starting.a or 1
          if row.set then row.set(r, g, b, a) end
          if options.onChanged then options.onChanged() end
          popup:Refresh()
        end
        ColorPickerFrame:SetupColorPickerAndShow({
          r = starting.r or 1,
          g = starting.g or 1,
          b = starting.b or 1,
          opacity = starting.a == nil and 1 or starting.a,
          hasOpacity = true,
          swatchFunc = ApplyColor,
          opacityFunc = ApplyColor,
          cancelFunc = function(previous)
            if type(previous) == "table" and row.set then
              row.set(previous.r or starting.r, previous.g or starting.g, previous.b or starting.b,
                previous.opacity or starting.a or 1)
              if options.onChanged then options.onChanged() end
              popup:Refresh()
            end
          end,
        })
      end)
      widget.control = swatch.button
      widget.swatch = swatch
    else
      local input = Frames.CreateInput(band, row.width or 112, 26)
      input:SetPoint("RIGHT", band, "RIGHT", -12, 0)
      local committing = false
      local function Commit()
        if committing then return end
        committing = true
        input:ClearFocus()
        if row.set then row.set(input:GetText()) end
        if options.onChanged then options.onChanged() end
        committing = false
        popup:Refresh()
      end
      input:SetScript("OnEnterPressed", Commit)
      input:SetScript("OnEditFocusLost", Commit)
      input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Refresh()
      end)
      widget.control = input
    end
    popup.widgets[#popup.widgets + 1] = widget
  end

  function popup:Refresh()
    for _, widget in ipairs(self.widgets) do
      local row = widget.definition
      local disabled = type(row.disabled) == "function" and row.disabled() or row.disabled == true
      widget.band:SetAlpha(disabled and 0.42 or 1)
      if widget.control and widget.control.EnableMouse then widget.control:EnableMouse(not disabled) end
      if row.type == "dropdown" then
        local value = row.get and row.get() or nil
        Frames.SetDropdownValue(widget.control, value, FindOptionLabel(row.values, value))
      elseif row.type == "toggle" then
        widget.control:SetChecked(row.get and row.get() == true or false)
        Theme.UpdateToggle(widget.control)
      elseif row.type == "color" then
        local color = row.get and row.get() or { r = 1, g = 1, b = 1, a = 1 }
        widget.swatch.color = color
        widget.swatch.swatch:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
      elseif not widget.control:HasFocus() then
        widget.control:SetText(tostring(row.get and row.get() or ""))
      end
    end
  end

  local mouseWasDown = false
  popup:SetScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
    self.anchor = nil
    if activeSettingsPopover == self then activeSettingsPopover = nil end
  end)

  function popup:ShowFor(anchor)
    if activeSettingsPopover and activeSettingsPopover ~= self then activeSettingsPopover:Hide() end
    if self:IsShown() and self.anchor == anchor then self:Hide(); return end
    activeSettingsPopover = self
    self.anchor = anchor
    self:Refresh()
    self:ClearAllPoints()
    self:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6)
    self:SetAlpha(0)
    self:Show()
    local elapsed = 0
    mouseWasDown = IsMouseButtonDown("LeftButton")
    self:SetScript("OnUpdate", function(frame, delta)
      elapsed = elapsed + (delta or 0)
      local progress = math.min(elapsed / 0.15, 1)
      frame:SetAlpha(progress)
      frame:ClearAllPoints()
      frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6 + (8 * (1 - progress)))
      if progress >= 1 then
        local mouseDown = IsMouseButtonDown("LeftButton")
        if mouseDown and not mouseWasDown and not frame:IsMouseOver() and not anchor:IsMouseOver() then
          frame:Hide()
          return
        end
        mouseWasDown = mouseDown
      end
    end)
    self:Raise()
  end

  return popup
end
