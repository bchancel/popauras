local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

local TexturePicker = {}
ns.util.TexturePicker = TexturePicker

local function ResolveEntries(valuesProvider)
  if type(valuesProvider) == "function" then
    local values = valuesProvider()
    return type(values) == "table" and values or {}
  end
  return type(valuesProvider) == "table" and valuesProvider or {}
end

local function EntryValue(entry)
  return type(entry) == "table" and (entry.value or entry.key or entry.label) or entry
end

local function EntryLabel(entry)
  return type(entry) == "table" and (entry.label or entry.text or tostring(EntryValue(entry) or ""))
    or tostring(entry or "")
end

local function EntryPath(entry)
  if type(entry) == "table" and type(entry.path) == "string" then return entry.path end
  return ns.util.Media:ResolveStatusBarTexture(EntryValue(entry))
end

local function EntrySource(entry)
  return type(entry) == "table" and tostring(entry.sourceLabel or "") or ""
end

function TexturePicker:EnsureFrame()
  if self.frame then return self.frame end

  local frame = CreateFrame("Frame", "PopAurasSharedTexturePicker", UIParent, "BackdropTemplate")
  frame:SetSize(520, 440)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  Theme.StyleSurface(frame, "canvasAlt", "borderStrong")
  frame.rows = {}

  frame.title = Frames.CreateLabel(frame, "Select Bar Texture", "GameFontNormal", "sectionTitle")
  frame.title:SetPoint("TOPLEFT", 18, -14)
  Theme.SetText(frame.title, "text")

  frame.subtitle = Frames.CreateLabel(
    frame,
    "PopAuras and installed media textures",
    "GameFontDisableSmall",
    "bodySmall"
  )
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
  Theme.SetText(frame.subtitle, "textMuted")

  frame.closeButton = Frames.CreateButton(frame, "X", 28, 26, function() frame:Hide() end)
  frame.closeButton:SetPoint("TOPRIGHT", -12, -12)
  Frames.StyleSecondaryButton(frame.closeButton)

  frame.search = Frames.CreateInput(frame, 222, 28)
  frame.search:SetPoint("TOPRIGHT", frame.closeButton, "BOTTOMRIGHT", 0, -10)
  frame.search:SetAutoFocus(false)
  frame.search:SetMaxLetters(80)
  frame.searchHint = Frames.CreateLabel(frame.search, "Search textures...", "GameFontDisableSmall", "bodySmall")
  frame.searchHint:SetPoint("LEFT", 10, 0)
  Theme.SetText(frame.searchHint, "textMuted")
  frame.search:SetScript("OnTextChanged", function(input)
    frame.searchHint:SetShown(input:GetText() == "")
    TexturePicker:Refresh()
  end)
  frame.search:SetScript("OnEscapePressed", function(input)
    if input:GetText() ~= "" then input:SetText("") else frame:Hide() end
  end)

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 14, -86)
  frame.scroll:SetPoint("BOTTOMRIGHT", -32, 14)
  frame.scroll:EnableMouseWheel(true)
  frame.scroll:SetScript("OnMouseWheel", function(scroll, delta)
    local current = scroll:GetVerticalScroll() or 0
    local maximum = scroll:GetVerticalScrollRange() or 0
    scroll:SetVerticalScroll(math.max(0, math.min(maximum, current - (delta * 42))))
  end)
  Theme.StyleScrollFrame(frame.scroll)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(468, 1)
  frame.scroll:SetScrollChild(frame.content)

  if UISpecialFrames then table.insert(UISpecialFrames, frame:GetName()) end
  self.frame = frame
  return frame
end

function TexturePicker:ApplyRowVisual(row)
  if row.isSelected then
    Theme.StyleSurface(row, "accentSoft", "borderFocus")
    row.accent:Show()
  elseif row.isHovered then
    Theme.StyleSurface(row, "surfaceHover", "borderStrong")
    row.accent:Hide()
  else
    Theme.StyleSurface(row, row.isEven and "rowEven" or "rowOdd", "border")
    row.accent:Hide()
  end
end

function TexturePicker:CreateRow(parent)
  local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
  row:SetSize(458, 42)

  row.accent = row:CreateTexture(nil, "ARTWORK")
  row.accent:SetPoint("TOPLEFT", 0, 0)
  row.accent:SetPoint("BOTTOMLEFT", 0, 0)
  row.accent:SetWidth(3)
  row.accent:SetColorTexture(0.10, 0.90, 0.72, 1)

  row.previewBackground = row:CreateTexture(nil, "BACKGROUND")
  row.previewBackground:SetPoint("LEFT", 12, 0)
  row.previewBackground:SetSize(156, 20)
  row.previewBackground:SetColorTexture(0.04, 0.05, 0.06, 1)
  row.preview = row:CreateTexture(nil, "ARTWORK")
  row.preview:SetAllPoints(row.previewBackground)

  row.label = Frames.CreateLabel(row, "", "GameFontHighlight", "control")
  row.label:SetPoint("LEFT", row.previewBackground, "RIGHT", 14, 6)
  row.label:SetPoint("RIGHT", -12, 6)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  Theme.SetText(row.label, "text")

  row.source = Frames.CreateLabel(row, "", "GameFontDisableSmall", "caption")
  row.source:SetPoint("LEFT", row.previewBackground, "RIGHT", 14, -10)
  row.source:SetPoint("RIGHT", -12, -10)
  row.source:SetJustifyH("LEFT")
  Theme.SetText(row.source, "textMuted")

  row:SetScript("OnEnter", function(selfRow)
    selfRow.isHovered = true
    TexturePicker:ApplyRowVisual(selfRow)
  end)
  row:SetScript("OnLeave", function(selfRow)
    selfRow.isHovered = false
    TexturePicker:ApplyRowVisual(selfRow)
  end)
  row:SetScript("OnClick", function(selfRow)
    local picker = TexturePicker.frame
    if not picker or not picker.dropdown or not selfRow.entry then return end
    local value, label = EntryValue(selfRow.entry), EntryLabel(selfRow.entry)
    UIDropDownMenu_SetSelectedValue(picker.dropdown, value)
    UIDropDownMenu_SetText(picker.dropdown, label)
    if picker.onChanged then picker.onChanged(value, selfRow.entry) end
    picker:Hide()
  end)
  return row
end

function TexturePicker:Refresh()
  local frame = self.frame
  if not frame or not frame.valuesProvider then return end

  local query = string.lower((frame.search and frame.search:GetText()) or "")
  local visible = {}
  for _, entry in ipairs(ResolveEntries(frame.valuesProvider)) do
    local searchable = string.lower(EntryLabel(entry) .. " " .. EntrySource(entry))
    if query == "" or searchable:find(query, 1, true) then
      visible[#visible + 1] = entry
    end
  end

  local current = frame.dropdown and UIDropDownMenu_GetSelectedValue(frame.dropdown) or nil
  local rowHeight = 44
  for index, entry in ipairs(visible) do
    local row = frame.rows[index]
    if not row then
      row = self:CreateRow(frame.content)
      frame.rows[index] = row
    end
    row.entry = entry
    row.isSelected = EntryValue(entry) == current
    row.isHovered = false
    row.isEven = index % 2 == 0
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight))
    row.preview:SetTexture(EntryPath(entry))
    row.preview:SetVertexColor(1, 1, 1, 1)
    row.label:SetText(EntryLabel(entry))
    row.source:SetText(EntrySource(entry))
    self:ApplyRowVisual(row)
    row:Show()
  end
  for index = #visible + 1, #frame.rows do
    frame.rows[index]:Hide()
    frame.rows[index].entry = nil
  end
  frame.content:SetHeight(math.max(1, #visible * rowHeight))
  frame.scroll:SetVerticalScroll(0)
end

function TexturePicker:IsShown()
  return self.frame and self.frame:IsShown() or false
end

function TexturePicker:Hide()
  if self.frame then self.frame:Hide() end
end

function TexturePicker:HideIfDropdown(dropdown)
  if self.frame and self.frame.dropdown == dropdown then self.frame:Hide() end
end

function TexturePicker:RefreshIfOpen(dropdown)
  if self:IsShown() and (not dropdown or self.frame.dropdown == dropdown) then self:Refresh() end
end

function TexturePicker:Toggle(anchor, dropdown, valuesProvider, options)
  local frame = self:EnsureFrame()
  options = options or {}
  if frame:IsShown() and frame.dropdown == dropdown then frame:Hide() return end

  frame.dropdown = dropdown
  frame.valuesProvider = valuesProvider
  frame.onChanged = options.onChanged
  frame.title:SetText(options.title or "Select Bar Texture")
  frame.search:SetText("")
  frame:ClearAllPoints()
  local anchorBottom = anchor and anchor.GetBottom and anchor:GetBottom() or nil
  if type(anchorBottom) == "number" and anchorBottom < 460 then
    frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 8)
  else
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  end
  self:Refresh()
  frame:Show()
end
