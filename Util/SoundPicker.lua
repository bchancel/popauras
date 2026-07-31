local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

local SoundPicker = {}
ns.util.SoundPicker = SoundPicker

local function ResolveEntries(valuesProvider)
  if type(valuesProvider) == "function" then
    local values = valuesProvider()
    return type(values) == "table" and values or {}
  end
  return type(valuesProvider) == "table" and valuesProvider or {}
end

local function GetOptionLabel(option)
  if type(option) ~= "table" then
    return tostring(option or "")
  end
  return option.label or option.text or tostring(option.value or "")
end

local function GetOptionValue(option)
  if type(option) ~= "table" then
    return option
  end
  return option.value or option.key or option.label
end

local function GetOptionSourceLabel(option)
  if type(option) ~= "table" then
    return ""
  end
  return tostring(option.sourceLabel or "")
end

local function GetOptionColor(option)
  if type(option) ~= "table" then
    return nil
  end
  return option.color or option.sourceColor
end

local function GetPreviewChannel(channelProvider)
  if type(channelProvider) == "function" then
    return channelProvider() or "Master"
  end
  if type(channelProvider) == "string" and channelProvider ~= "" then
    return channelProvider
  end
  return "Master"
end

local function PlayOption(option, channelProvider)
  local value = GetOptionValue(option)
  if not value or value == "" or value == "None" then
    return
  end
  if ns.Interrupts and ns.Interrupts.PlaySound then
    ns.Interrupts:PlaySound(value, GetPreviewChannel(channelProvider))
  end
end

function SoundPicker:EnsureFrame()
  if self.frame then
    return self.frame
  end

  local frame = CreateFrame("Frame", "PopAurasSharedSoundPicker", UIParent, "BackdropTemplate")
  frame:SetSize(430, 336)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  Theme.StyleSurface(frame, "canvasAlt", "borderStrong")
  frame.rows = {}

  frame.title = Frames.CreateLabel(frame, "Select Sound", "GameFontNormal")
  frame.title:SetPoint("TOPLEFT", 12, -10)
  Theme.SetText(frame.title, "text")

  frame.subtitle = Frames.CreateLabel(frame, "Click a sound to select it. Click the speaker to preview it.", "GameFontDisableSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
  Theme.SetText(frame.subtitle, "textMuted")

  frame.closeButton = Frames.CreateButton(frame, "X", 22, 20, function()
    frame:Hide()
  end)
  frame.closeButton:SetPoint("TOPRIGHT", -8, -8)
  Frames.StyleSecondaryButton(frame.closeButton)

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 12, -52)
  frame.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  Theme.StyleScrollFrame(frame.scroll)
  frame.scroll:EnableMouseWheel(true)
  frame.scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
    local current = selfScroll:GetVerticalScroll() or 0
    local maxValue = selfScroll:GetVerticalScrollRange() or 0
    selfScroll:SetVerticalScroll(math.max(0, math.min(maxValue, current - (delta * 28))))
  end)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(380, 1)
  frame.scroll:SetScrollChild(frame.content)

  if UISpecialFrames then
    local exists = false
    for _, name in ipairs(UISpecialFrames) do
      if name == frame:GetName() then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(UISpecialFrames, frame:GetName())
    end
  end

  self.frame = frame
  return frame
end

function SoundPicker:ApplyRowVisual(row)
  if row.isSelected then
    Theme.StyleSurface(row, "accentSoft", "borderFocus")
    Theme.SetTexture(row.accent, "accentBright")
    row.accent:Show()
    return
  end

  local border = Theme.GetColor("border")
  row:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
  row.accent:Hide()
  if row.isHovered then
    local hover = Theme.GetColor("surfaceHover")
    row:SetBackdropColor(hover[1], hover[2], hover[3], hover[4])
  else
    local surface = Theme.GetColor("surface")
    row:SetBackdropColor(surface[1], surface[2], surface[3], surface[4])
  end
end

function SoundPicker:CreateRow(parent)
  local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
  row:SetSize(372, 24)
  row:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  row:SetBackdropBorderColor(0.19, 0.24, 0.33, 1)

  row.accent = row:CreateTexture(nil, "ARTWORK")
  row.accent:SetPoint("TOPLEFT", 0, 0)
  row.accent:SetPoint("BOTTOMLEFT", 0, 0)
  row.accent:SetWidth(3)
  row.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
  row.accent:Hide()

  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.label:SetPoint("LEFT", 10, 0)
  row.label:SetPoint("RIGHT", -112, 0)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)

  row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.source:SetPoint("RIGHT", -34, 0)
  row.source:SetJustifyH("RIGHT")
  row.source:SetWordWrap(false)

  row.previewButton = CreateFrame("Button", nil, row)
  row.previewButton:SetSize(16, 16)
  row.previewButton:SetPoint("RIGHT", -10, 0)
  row.previewIcon = row.previewButton:CreateTexture(nil, "ARTWORK")
  row.previewIcon:SetAllPoints()
  row.previewIcon:SetTexture(130979)
  row.previewIcon:SetVertexColor(0.82, 0.82, 0.82)

  row:SetScript("OnEnter", function(selfRow)
    selfRow.isHovered = true
    SoundPicker:ApplyRowVisual(selfRow)
  end)
  row:SetScript("OnLeave", function(selfRow)
    selfRow.isHovered = false
    SoundPicker:ApplyRowVisual(selfRow)
  end)
  row:SetScript("OnClick", function(selfRow)
    local picker = SoundPicker.frame
    if not picker or not picker.dropdown or not selfRow.option then
      return
    end
    local value = GetOptionValue(selfRow.option)
    local label = GetOptionLabel(selfRow.option)
    UIDropDownMenu_SetSelectedValue(picker.dropdown, value)
    UIDropDownMenu_SetText(picker.dropdown, label)
    if picker.onChanged then
      picker.onChanged(value, selfRow.option)
    end
    picker:Hide()
  end)

  row.previewButton:SetScript("OnEnter", function()
    row.previewIcon:SetVertexColor(1, 1, 1)
  end)
  row.previewButton:SetScript("OnLeave", function()
    row.previewIcon:SetVertexColor(0.82, 0.82, 0.82)
  end)
  row.previewButton:SetScript("OnClick", function(selfButton)
    local option = selfButton:GetParent().option
    PlayOption(option, SoundPicker.frame and SoundPicker.frame.channelProvider or nil)
  end)

  return row
end

function SoundPicker:Refresh()
  local frame = self.frame
  if not frame or not frame.valuesProvider then
    return
  end

  local options = ResolveEntries(frame.valuesProvider)
  local currentValue = frame.dropdown and UIDropDownMenu_GetSelectedValue(frame.dropdown) or nil
  local rowHeight = 24
  local selectedIndex = nil

  for index, option in ipairs(options) do
    local row = frame.rows[index]
    if not row then
      row = self:CreateRow(frame.content)
      frame.rows[index] = row
    end

    local label = GetOptionLabel(option)
    local color = GetOptionColor(option)
    local sourceLabel = GetOptionSourceLabel(option)

    row.option = option
    row.isSelected = GetOptionValue(option) == currentValue
    row.isHovered = false
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight))
    row.label:SetText(label)
    if color then
      row.label:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
      row.source:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
    else
      row.label:SetTextColor(1, 1, 1)
      row.source:SetTextColor(0.72, 0.76, 0.82)
    end
    row.source:SetText(sourceLabel)
    row.previewButton:SetShown(GetOptionValue(option) ~= nil and GetOptionValue(option) ~= "" and GetOptionValue(option) ~= "None")
    self:ApplyRowVisual(row)
    row:Show()

    if row.isSelected then
      selectedIndex = index
    end
  end

  for index = #options + 1, #frame.rows do
    frame.rows[index]:Hide()
    frame.rows[index].option = nil
  end

  frame.content:SetHeight(math.max(1, #options * rowHeight))
  frame.scroll:SetVerticalScroll(0)

  if selectedIndex then
    local viewHeight = frame.scroll:GetHeight() or 0
    local target = ((selectedIndex - 1) * rowHeight) - math.max(0, math.floor((viewHeight - rowHeight) / 2))
    local maxValue = frame.scroll:GetVerticalScrollRange() or 0
    frame.scroll:SetVerticalScroll(math.max(0, math.min(maxValue, target)))
  end
end

function SoundPicker:IsShown()
  return self.frame and self.frame:IsShown() or false
end

function SoundPicker:IsActiveDropdown(dropdown)
  return self.frame and self.frame.dropdown == dropdown or false
end

function SoundPicker:Hide()
  if self.frame then
    self.frame:Hide()
  end
end

function SoundPicker:HideIfDropdown(dropdown)
  if self:IsActiveDropdown(dropdown) then
    self:Hide()
  end
end

function SoundPicker:RefreshIfOpen(dropdown)
  if not self:IsShown() then
    return
  end
  if dropdown and not self:IsActiveDropdown(dropdown) then
    return
  end
  self:Refresh()
end

function SoundPicker:Toggle(anchor, dropdown, valuesProvider, options)
  local frame = self:EnsureFrame()
  options = options or {}

  if frame:IsShown() and frame.dropdown == dropdown then
    frame:Hide()
    return
  end

  frame.dropdown = dropdown
  frame.valuesProvider = valuesProvider
  frame.onChanged = options.onChanged
  frame.channelProvider = options.channelProvider
  frame.title:SetText(options.title or "Select Sound")

  frame:ClearAllPoints()
  local anchorBottom = anchor and anchor.GetBottom and anchor:GetBottom() or nil
  if type(anchorBottom) == "number" and anchorBottom < 360 then
    frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
  else
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  end
  frame:Show()
  self:Refresh()
end
