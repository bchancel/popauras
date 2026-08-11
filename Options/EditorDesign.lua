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
