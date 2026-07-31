local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts
local Anchors = ns.util.Anchors
local Colors = ns.util.Colors
local Theme = ns.util.Theme

local Panel = {}
ns.panels.InterruptTrackerDisplayPanel = Panel

local fillModeValues = {
  { value = "DRAIN", label = "Drain" },
  { value = "FILL", label = "Fill" },
}

local sortOrderValues = {
  { value = "NONE", label = "Party Order" },
  { value = "CD_ASC", label = "CD Ascending" },
  { value = "CD_DESC", label = "CD Descending" },
}

local channelValues = {
  { value = "PARTY", label = "Party" },
  { value = "SAY", label = "Say" },
  { value = "YELL", label = "Yell" },
}

local textAnchorValues = {
  "LEFT", "CENTER", "RIGHT", "TOP", "BOTTOM",
  "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
  "ICON",
}

local iconAnchorValues = {
  "LEFT", "CENTER", "RIGHT", "TOP", "BOTTOM",
  "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

local fontStyleValues = {
  "FRIZQT",
  "FRIZQT_OUTLINE",
  "FRIZQT_THICK",
  "MORPHEUS",
  "SKURRI",
}

local textRotationValues = {
  "0",
  "90",
  "180",
  "270",
}

local function GetSelectedAura()
  local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
  if not aura or aura.kind ~= "interrupt_tracker" then
    return nil
  end
  ns.Interrupts:EnsureAuraDefaults(aura)
  return aura
end

local function CreateSection(parent, title, y, height)
  local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Theme.StyleSurface(section, "surface", "border")
  section:SetPoint("TOPLEFT", 16, y)
  section:SetSize(840, height)

  section.header = CreateFrame("Frame", nil, section, "BackdropTemplate")
  section.header:SetPoint("TOPLEFT", 1, -1)
  section.header:SetPoint("TOPRIGHT", -1, -1)
  section.header:SetHeight(28)
  Theme.StyleSurface(section.header, "surfaceRaised", "border")

  section.title = Frames.CreateLabel(section.header, title, "GameFontNormal")
  section.title:SetPoint("LEFT", 10, 0)
  Theme.SetText(section.title, "text")
  return section
end

local function CreateLabeledInput(parent, label, x, y, width)
  local widget = {}
  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall")
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.input = Frames.CreateInput(parent, width or 120, 22)
  widget.input:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", 0, -4)
  return widget
end

local function CreateLabeledDropdown(parent, label, x, y, width)
  local widget = {}
  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall")
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.dropdown = Frames.CreateDropdown(parent, width or 160)
  widget.dropdown:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", -14, -2)
  return widget
end

local function CreateColorSwatch(parent, label, x, y)
  local widget = {}
  widget.button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  widget.button:SetSize(28, 28)
  widget.button:SetPoint("TOPLEFT", x, y)
  widget.button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
  })
  Theme.SetBackdrop(widget.button, "control", "border")

  widget.swatch = widget.button:CreateTexture(nil, "ARTWORK")
  widget.swatch:SetPoint("TOPLEFT", 4, -4)
  widget.swatch:SetPoint("BOTTOMRIGHT", -4, 4)
  widget.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")

  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall")
  widget.label:SetPoint("LEFT", widget.button, "RIGHT", 8, 0)
  widget.color = { r = 1, g = 1, b = 1, a = 1 }
  return widget
end

local function SetColorSwatch(widget, color)
  widget.color = Colors.Copy(color)
  widget.swatch:SetVertexColor(
    widget.color.r or 1,
    widget.color.g or 1,
    widget.color.b or 1,
    widget.color.a == nil and 1 or widget.color.a
  )
end

local function GetPickerAlpha()
  if ColorPickerFrame and ColorPickerFrame.GetColorAlpha then
    local alpha = ColorPickerFrame:GetColorAlpha()
    if type(alpha) == "number" then
      return alpha
    end
  end
  if OpacitySliderFrame and OpacitySliderFrame.GetValue then
    local opacity = OpacitySliderFrame:GetValue()
    if type(opacity) == "number" then
      return 1 - opacity
    end
  end
  return 1
end

local function PrepareColorPicker()
  if not ColorPickerFrame then
    return
  end
  if ColorPickerFrame.SetFrameStrata then
    ColorPickerFrame:SetFrameStrata("TOOLTIP")
  end
  if ColorPickerFrame.SetFrameLevel then
    ColorPickerFrame:SetFrameLevel(200)
  end
end

local function WireColor(widget, onChanged)
  if not widget or not widget.button then
    return
  end

  widget.button:SetScript("OnClick", function()
    if not ColorPickerFrame then
      return
    end

    local starting = Colors.Copy(widget.color)
    local function apply()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = GetPickerAlpha()
      SetColorSwatch(widget, { r = r, g = g, b = b, a = a })
      if onChanged then
        onChanged()
      end
    end

    PrepareColorPicker()
    if ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        r = starting.r,
        g = starting.g,
        b = starting.b,
        opacity = starting.a == nil and 1 or starting.a,
        hasOpacity = true,
        swatchFunc = apply,
        opacityFunc = apply,
        cancelFunc = function(previous)
          if type(previous) == "table" then
            SetColorSwatch(widget, {
              r = previous.r or starting.r,
              g = previous.g or starting.g,
              b = previous.b or starting.b,
              a = previous.opacity or starting.a,
            })
          else
            SetColorSwatch(widget, starting)
          end
          if onChanged then
            onChanged()
          end
        end,
      })
      return
    end

    ColorPickerFrame.func = apply
    ColorPickerFrame.opacityFunc = apply
    ColorPickerFrame.cancelFunc = function(previous)
      if type(previous) == "table" then
        SetColorSwatch(widget, {
          r = previous.r or starting.r,
          g = previous.g or starting.g,
          b = previous.b or starting.b,
          a = previous.opacity or starting.a,
        })
      else
        SetColorSwatch(widget, starting)
      end
      if onChanged then
        onChanged()
      end
    end
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = starting.a == nil and 1 or starting.a
    ColorPickerFrame:SetColorRGB(starting.r, starting.g, starting.b)
    ColorPickerFrame:Show()
  end)
end

local function ResolveDropdownEntries(entries)
  if type(entries) == "function" then
    local resolved = entries()
    if type(resolved) == "table" then
      return resolved
    end
    return {}
  end
  return type(entries) == "table" and entries or {}
end

local function EntryValueAndLabel(entry)
  if type(entry) == "table" then
    local value = entry.value or entry.key or entry.name or entry.label
    local label = entry.label or entry.text or entry.name or tostring(value or "")
    return value, label
  end
  return entry, tostring(entry or "")
end

local function InitDropdown(dropdown, entries, onChanged)
  dropdown._entries = entries
  UIDropDownMenu_Initialize(dropdown, function(_, level)
    for _, entry in ipairs(ResolveDropdownEntries(entries)) do
      local value, label = EntryValueAndLabel(entry)
      local info = UIDropDownMenu_CreateInfo()
      info.text = label
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dropdown, value)
        UIDropDownMenu_SetText(dropdown, label)
        if onChanged then
          onChanged(value)
        end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end

local function SetDropdown(dropdown, value)
  UIDropDownMenu_SetSelectedValue(dropdown, value)
  for _, entry in ipairs(ResolveDropdownEntries(dropdown._entries)) do
    local entryValue, label = EntryValueAndLabel(entry)
    if entryValue == value then
      UIDropDownMenu_SetText(dropdown, label)
      return
    end
  end
  UIDropDownMenu_SetText(dropdown, tostring(value or ""))
end

local function EnsureNumeric(input, fallback)
  local value = tonumber(input:GetText())
  if value == nil then
    value = fallback or 0
  end
  input:SetText(tostring(value))
  return value
end

local function EnsureInteger(input, fallback)
  local value = tonumber(input:GetText())
  if value == nil then
    value = fallback or 0
  end
  value = math.floor(value + 0.5)
  input:SetText(tostring(value))
  return value
end

local function EnsureAlpha(input, fallback)
  local value = tonumber(input:GetText())
  if value == nil then
    value = fallback or 0.40
  end
  value = math.max(0, math.min(1, value))
  input:SetText(string.format("%.2f", value))
  return value
end

function Panel:WireInput(input)
  input:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    Panel:ApplyCurrent()
  end)
  input:SetScript("OnEditFocusLost", function()
    Panel:ApplyCurrent()
  end)
end

local function CreateTextControlSection(section, showLabel)
  local controls = {}
  controls.showCheck = Frames.CreateCheckbox(section, showLabel)
  controls.showCheck:SetPoint("TOPLEFT", 12, -38)
  controls.fontWrap = CreateLabeledDropdown(section, "Font", 12, -74, 180)
  controls.sizeWrap = CreateLabeledInput(section, "Size", 220, -74, 56)
  controls.rotationWrap = CreateLabeledDropdown(section, "Rotation", 304, -74, 120)
  controls.anchorWrap = CreateLabeledDropdown(section, "Anchor", 452, -74, 170)
  controls.xWrap = CreateLabeledInput(section, "Offset X", 12, -136, 72)
  controls.yWrap = CreateLabeledInput(section, "Offset Y", 108, -136, 72)
  controls.colorWrap = CreateColorSwatch(section, "Text Color", 220, -138)
  return controls
end

local function ApplyFilterSelection(meta, disabledSpells)
  for _, spellID in ipairs(meta.ids) do
    if disabledSpells[spellID] == true then
      return false
    end
  end
  return true
end

function Panel:ApplyCurrent()
  if self.suppressUpdates then
    return
  end

  local aura = GetSelectedAura()
  if not aura then
    return
  end

  local frame = self.frame
  local interrupt = ns.Interrupts:EnsureAuraDefaults(aura)
  aura.display = aura.display or {}
  aura.position = aura.position or {}

  aura.name = ns.Registry:GetUniqueAuraName(frame.nameWrap.input:GetText(), aura.id)
  frame.nameWrap.input:SetText(aura.name)

  aura.display.width = EnsureNumeric(frame.widthWrap.input, aura.display.width or 240)
  aura.display.height = EnsureNumeric(frame.heightWrap.input, aura.display.height or 34)
  aura.position.width = aura.display.width
  aura.position.height = aura.display.height
  aura.position.x = EnsureNumeric(frame.xWrap.input, aura.position.x or 0)
  aura.position.y = EnsureNumeric(frame.yWrap.input, aura.position.y or 0)
  aura.position.relativeTo = UIDropDownMenu_GetSelectedValue(frame.anchorWrap.dropdown) or aura.position.relativeTo or "UIParent"
  aura.position.point = UIDropDownMenu_GetSelectedValue(frame.framePointWrap.dropdown) or aura.position.point or "CENTER"
  aura.position.relativePoint = UIDropDownMenu_GetSelectedValue(frame.parentPointWrap.dropdown) or aura.position.relativePoint or "CENTER"

  aura.display.showBackground = frame.showBackgroundCheck:GetChecked() == true
  aura.display.backgroundColor = Colors.Copy(frame.groupBackgroundColorWrap.color or aura.display.backgroundColor)
  aura.display.spacing = EnsureNumeric(frame.spacingWrap.input, aura.display.spacing or 4)
  interrupt.paddingX = EnsureNumeric(frame.paddingXWrap.input, interrupt.paddingX or 6)
  interrupt.paddingY = EnsureNumeric(frame.paddingYWrap.input, interrupt.paddingY or 3)
  interrupt.barAlpha = EnsureAlpha(frame.barAlphaWrap.input, interrupt.barAlpha or 0.88)
  interrupt.showBarBackground = frame.showBarBackgroundCheck:GetChecked() == true
  interrupt.barBackgroundColor = Colors.Copy(frame.barBackgroundColorWrap.color or interrupt.barBackgroundColor)
  interrupt.readyBarAlpha = EnsureAlpha(frame.readyBarAlphaWrap.input, interrupt.readyBarAlpha or 0.40)
  interrupt.fillMode = UIDropDownMenu_GetSelectedValue(frame.fillModeWrap.dropdown) or interrupt.fillMode or "DRAIN"
  interrupt.sortOrder = UIDropDownMenu_GetSelectedValue(frame.sortOrderWrap.dropdown) or interrupt.sortOrder or "NONE"
  interrupt.showFailedKick = frame.failedKickCheck:GetChecked() == true

  aura.display.icon = frame.showIconCheck:GetChecked() == true
  aura.display.iconMatchBarSize = frame.iconMatchSizeCheck:GetChecked() == true
  aura.display.iconSize = EnsureInteger(frame.iconSizeWrap.input, aura.display.iconSize or aura.display.height or 34)
  aura.display.iconAnchor = UIDropDownMenu_GetSelectedValue(frame.iconAnchorWrap.dropdown) or aura.display.iconAnchor or "LEFT"
  aura.display.iconOffsetX = EnsureNumeric(frame.iconXWrap.input, aura.display.iconOffsetX or 0)
  aura.display.iconOffsetY = EnsureNumeric(frame.iconYWrap.input, aura.display.iconOffsetY or 0)

  aura.display.showName = frame.nameControls.showCheck:GetChecked() == true
  aura.display.nameFontStyle = UIDropDownMenu_GetSelectedValue(frame.nameControls.fontWrap.dropdown) or aura.display.nameFontStyle or "FRIZQT_OUTLINE"
  aura.display.nameFontSize = EnsureInteger(frame.nameControls.sizeWrap.input, aura.display.nameFontSize or 12)
  aura.display.nameRotation = tonumber(UIDropDownMenu_GetSelectedValue(frame.nameControls.rotationWrap.dropdown) or aura.display.nameRotation or 0) or 0
  aura.display.nameAnchor = UIDropDownMenu_GetSelectedValue(frame.nameControls.anchorWrap.dropdown) or aura.display.nameAnchor or "LEFT"
  aura.display.nameOffsetX = EnsureNumeric(frame.nameControls.xWrap.input, aura.display.nameOffsetX or 6)
  aura.display.nameOffsetY = EnsureNumeric(frame.nameControls.yWrap.input, aura.display.nameOffsetY or 0)
  aura.display.nameColor = Colors.Copy(frame.nameControls.colorWrap.color or aura.display.nameColor)
  interrupt.displayInterruptName = frame.displayInterruptNameCheck:GetChecked() == true

  aura.display.showTimer = frame.timerControls.showCheck:GetChecked() == true
  aura.display.timerFontStyle = UIDropDownMenu_GetSelectedValue(frame.timerControls.fontWrap.dropdown) or aura.display.timerFontStyle or "FRIZQT_OUTLINE"
  aura.display.timerFontSize = EnsureInteger(frame.timerControls.sizeWrap.input, aura.display.timerFontSize or 12)
  aura.display.timerRotation = tonumber(UIDropDownMenu_GetSelectedValue(frame.timerControls.rotationWrap.dropdown) or aura.display.timerRotation or 0) or 0
  aura.display.timerAnchor = UIDropDownMenu_GetSelectedValue(frame.timerControls.anchorWrap.dropdown) or aura.display.timerAnchor or "RIGHT"
  aura.display.timerOffsetX = EnsureNumeric(frame.timerControls.xWrap.input, aura.display.timerOffsetX or -6)
  aura.display.timerOffsetY = EnsureNumeric(frame.timerControls.yWrap.input, aura.display.timerOffsetY or 0)
  aura.display.timerColor = Colors.Copy(frame.timerControls.colorWrap.color or aura.display.timerColor)
  aura.display.timerDecimals = tonumber(UIDropDownMenu_GetSelectedValue(frame.timerDecimalsWrap.dropdown) or aura.display.timerDecimals or 0) or 0
  aura.display.hideReadyTimer = frame.hideReadyCheck:GetChecked() == true

  interrupt.clickToAnnounce = frame.clickAnnounceCheck:GetChecked() == true
  interrupt.announceChannel = UIDropDownMenu_GetSelectedValue(frame.channelWrap.dropdown) or interrupt.announceChannel or "PARTY"
  interrupt.antiSpam = frame.antiSpamCheck:GetChecked() == true

  interrupt.soundEnabled = frame.soundEnabledCheck:GetChecked() == true
  interrupt.soundOwnKickOnly = frame.soundOwnOnlyCheck:GetChecked() == true
  interrupt.soundKickSuccess = UIDropDownMenu_GetSelectedValue(frame.soundSuccessWrap.dropdown) or interrupt.soundKickSuccess or "None"
  interrupt.soundKickFailed = UIDropDownMenu_GetSelectedValue(frame.soundFailedWrap.dropdown) or interrupt.soundKickFailed or "None"

  interrupt.disabledSpells = {}
  for _, meta in ipairs(frame.filterControls or {}) do
    if meta.check:GetChecked() ~= true then
      for _, spellID in ipairs(meta.ids) do
        interrupt.disabledSpells[spellID] = true
      end
    end
  end

  ns.runtime:RefreshAura(aura.id)
  local region = ns.runtime and ns.runtime.GetRegionByAuraId and ns.runtime:GetRegionByAuraId(aura.id) or nil
  if region and region.frame then
    ns.renderers.BaseRegion:ApplyAnchor(aura, region.frame)
    if region.RefreshRows then
      region:RefreshRows()
    end
  end
  ns.ui.MainWindow:Refresh()
end

function Panel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 0, 0)
  frame.scroll:SetPoint("BOTTOMRIGHT", -28, 0)
  Theme.StyleScrollFrame(frame.scroll)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(880, 1900)
  frame.scroll:SetScrollChild(frame.content)

  frame.summary = Frames.CreateLabel(frame.content, "Interrupt Tracker Display", "GameFontHighlight")
  frame.summary:SetPoint("TOPLEFT", 16, -10)
  frame.summary:SetTextColor(0.87, 0.91, 1)

  frame.hint = Frames.CreateLabel(frame.content, "Track party interrupt cooldowns with BliZzi-compatible addon messaging and a compact spell filter list.", "GameFontDisableSmall")
  frame.hint:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -2)
  frame.hint:SetWidth(820)
  frame.hint:SetJustifyH("LEFT")

  frame.credit = Frames.CreateLabel(
    frame.content,
    "Based on and compatible with |cff66ccffBliZzi Interrupt Tracker|r: |cff66ccffhttps://www.curseforge.com/wow/addons/blizzi-interrupt-tracker|r",
    "GameFontHighlightSmall"
  )
  frame.credit:SetPoint("TOPLEFT", frame.hint, "BOTTOMLEFT", 0, -6)
  frame.credit:SetWidth(820)
  frame.credit:SetJustifyH("LEFT")
  frame.credit:SetTextColor(0.78, 0.84, 0.94)

  frame.lookSection = CreateSection(frame.content, "Look", -70, 300)
  frame.iconSection = CreateSection(frame.content, "Icon", -382, 160)
  frame.nameSection = CreateSection(frame.content, "Name Text", -554, 194)
  frame.durationSection = CreateSection(frame.content, "Duration Text", -760, 224)
  frame.announceSection = CreateSection(frame.content, "Click Announce", -996, 132)
  frame.soundSection = CreateSection(frame.content, "Sounds", -1140, 162)
  frame.filtersSection = CreateSection(frame.content, "Interrupt Filters", -1314, 540)

  frame.nameWrap = CreateLabeledInput(frame.lookSection, "Aura Name", 12, -36, 260)
  frame.widthWrap = CreateLabeledInput(frame.lookSection, "Width", 292, -36, 70)
  frame.heightWrap = CreateLabeledInput(frame.lookSection, "Height", 382, -36, 70)
  frame.xWrap = CreateLabeledInput(frame.lookSection, "Offset X", 472, -36, 80)
  frame.yWrap = CreateLabeledInput(frame.lookSection, "Offset Y", 572, -36, 80)
  frame.anchorWrap = CreateLabeledDropdown(frame.lookSection, "Anchor / Parent", 12, -96, 260)
  frame.framePointWrap = CreateLabeledDropdown(frame.lookSection, "Frame Point", 300, -96, 130)
  frame.parentPointWrap = CreateLabeledDropdown(frame.lookSection, "Parent Point", 458, -96, 130)
  frame.showBackgroundCheck = Frames.CreateCheckbox(frame.lookSection, "Show Background")
  frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -156)
  frame.groupBackgroundColorWrap = CreateColorSwatch(frame.lookSection, "Group BG", 182, -158)
  frame.showBarBackgroundCheck = Frames.CreateCheckbox(frame.lookSection, "Show Bar Background")
  frame.showBarBackgroundCheck:SetPoint("TOPLEFT", 352, -156)
  frame.barBackgroundColorWrap = CreateColorSwatch(frame.lookSection, "Bar BG", 580, -158)
  frame.spacingWrap = CreateLabeledInput(frame.lookSection, "Spacing", 12, -214, 64)
  frame.paddingXWrap = CreateLabeledInput(frame.lookSection, "Padding X", 96, -214, 64)
  frame.paddingYWrap = CreateLabeledInput(frame.lookSection, "Padding Y", 180, -214, 64)
  frame.barAlphaWrap = CreateLabeledInput(frame.lookSection, "Bar Alpha", 272, -214, 72)
  frame.readyBarAlphaWrap = CreateLabeledInput(frame.lookSection, "Ready Alpha", 368, -214, 72)
  frame.fillModeWrap = CreateLabeledDropdown(frame.lookSection, "Bar Fill Direction", 12, -246, 150)
  frame.sortOrderWrap = CreateLabeledDropdown(frame.lookSection, "Sort Order", 188, -246, 170)
  frame.failedKickCheck = Frames.CreateCheckbox(frame.lookSection, "Failed Kick Detection")
  frame.failedKickCheck:SetPoint("TOPLEFT", 388, -250)

  frame.showIconCheck = Frames.CreateCheckbox(frame.iconSection, "Show Icon")
  frame.showIconCheck:SetPoint("TOPLEFT", 12, -38)
  frame.iconMatchSizeCheck = Frames.CreateCheckbox(frame.iconSection, "Match Bar Size")
  frame.iconMatchSizeCheck:SetPoint("TOPLEFT", 154, -38)
  frame.iconSizeWrap = CreateLabeledInput(frame.iconSection, "Icon Size", 12, -74, 56)
  frame.iconAnchorWrap = CreateLabeledDropdown(frame.iconSection, "Icon Anchor", 96, -74, 170)
  frame.iconXWrap = CreateLabeledInput(frame.iconSection, "Offset X", 292, -74, 72)
  frame.iconYWrap = CreateLabeledInput(frame.iconSection, "Offset Y", 388, -74, 72)
  frame.iconHint = Frames.CreateLabel(frame.iconSection, "Uses each interrupt spell's real icon. Match Bar Size keeps the icon synced to the row height.", "GameFontDisableSmall")
  frame.iconHint:SetPoint("TOPLEFT", 12, -134)
  frame.iconHint:SetWidth(780)
  frame.iconHint:SetJustifyH("LEFT")

  frame.nameControls = CreateTextControlSection(frame.nameSection, "Show Player Name")
  frame.displayInterruptNameCheck = Frames.CreateCheckbox(frame.nameSection, "Display Interrupt Name")
  frame.displayInterruptNameCheck:SetPoint("TOPLEFT", 180, -38)
  frame.nameHint = Frames.CreateLabel(frame.nameSection, "Mix player and interrupt names however you want: player only, spell only, both, or neither.", "GameFontDisableSmall")
  frame.nameHint:SetPoint("TOPLEFT", 12, -174)
  frame.nameHint:SetWidth(780)
  frame.nameHint:SetJustifyH("LEFT")

  frame.timerControls = CreateTextControlSection(frame.durationSection, "Show Duration / Ready Text")
  frame.hideReadyCheck = Frames.CreateCheckbox(frame.durationSection, "Hide While Ready")
  frame.hideReadyCheck:SetPoint("TOPLEFT", 180, -38)
  frame.timerDecimalsWrap = CreateLabeledDropdown(frame.durationSection, "Decimals", 360, -34, 120)
  frame.durationHint = Frames.CreateLabel(frame.durationSection, "READY text uses the same duration style and color controls as the cooldown timer.", "GameFontDisableSmall")
  frame.durationHint:SetPoint("TOPLEFT", 12, -204)
  frame.durationHint:SetWidth(780)
  frame.durationHint:SetJustifyH("LEFT")

  frame.clickAnnounceCheck = Frames.CreateCheckbox(frame.announceSection, "Click on bar/icon to prepare interrupt status")
  frame.clickAnnounceCheck:SetPoint("TOPLEFT", 12, -38)
  frame.channelWrap = CreateLabeledDropdown(frame.announceSection, "Announce Channel", 12, -74, 160)
  frame.antiSpamCheck = Frames.CreateCheckbox(frame.announceSection, "Prevent duplicate announces")
  frame.antiSpamCheck:SetPoint("TOPLEFT", 220, -100)

  frame.soundEnabledCheck = Frames.CreateCheckbox(frame.soundSection, "Enable Sounds")
  frame.soundEnabledCheck:SetPoint("TOPLEFT", 12, -38)
  frame.soundOwnOnlyCheck = Frames.CreateCheckbox(frame.soundSection, "Only play sounds for your own kicks")
  frame.soundOwnOnlyCheck:SetPoint("TOPLEFT", 220, -38)
  frame.soundSuccessWrap = CreateLabeledDropdown(frame.soundSection, "Successful Interrupt Sound", 12, -86, 230)
  frame.soundFailedWrap = CreateLabeledDropdown(frame.soundSection, "Failed Interrupt Sound", 272, -86, 230)

  frame.filterControls = {}
  frame.filterLabels = {}
  local filterY = -38
  for _, group in ipairs(ns.Interrupts.FILTERS) do
    local label = Frames.CreateLabel(frame.filtersSection, group.name .. ":", "GameFontNormal")
    label:SetPoint("TOPLEFT", 12, filterY)
    label:SetTextColor(0.92, 0.95, 1)
    frame.filterLabels[#frame.filterLabels + 1] = label

    local anchorX = 170
    for _, spellInfo in ipairs(group.spells) do
      local check = Frames.CreateCheckbox(frame.filtersSection, spellInfo.label)
      check:SetPoint("TOPLEFT", anchorX, filterY + 2)
      frame.filterControls[#frame.filterControls + 1] = {
        ids = type(spellInfo.ids) == "table" and spellInfo.ids or { spellInfo.id },
        check = check,
      }
      anchorX = anchorX + 186
    end
    filterY = filterY - 36
  end

  self.frame = frame

  InitDropdown(frame.anchorWrap.dropdown, Anchors.GetTargetList, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.framePointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.parentPointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.fillModeWrap.dropdown, fillModeValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.sortOrderWrap.dropdown, sortOrderValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.iconAnchorWrap.dropdown, iconAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.nameControls.fontWrap.dropdown, fontStyleValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.nameControls.rotationWrap.dropdown, textRotationValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.nameControls.anchorWrap.dropdown, textAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.timerControls.fontWrap.dropdown, fontStyleValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.timerControls.rotationWrap.dropdown, textRotationValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.timerControls.anchorWrap.dropdown, textAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.timerDecimalsWrap.dropdown, { "0", "1", "2" }, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.channelWrap.dropdown, channelValues, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.soundSuccessWrap.dropdown, function() return ns.Interrupts:GetSoundOptions() end, function() Panel:ApplyCurrent() end)
  InitDropdown(frame.soundFailedWrap.dropdown, function() return ns.Interrupts:GetSoundOptions() end, function() Panel:ApplyCurrent() end)

  local wiredInputs = {
    frame.nameWrap.input,
    frame.widthWrap.input,
    frame.heightWrap.input,
    frame.xWrap.input,
    frame.yWrap.input,
    frame.spacingWrap.input,
    frame.paddingXWrap.input,
    frame.paddingYWrap.input,
    frame.barAlphaWrap.input,
    frame.readyBarAlphaWrap.input,
    frame.iconSizeWrap.input,
    frame.iconXWrap.input,
    frame.iconYWrap.input,
    frame.nameControls.sizeWrap.input,
    frame.nameControls.xWrap.input,
    frame.nameControls.yWrap.input,
    frame.timerControls.sizeWrap.input,
    frame.timerControls.xWrap.input,
    frame.timerControls.yWrap.input,
  }
  for _, input in ipairs(wiredInputs) do
    self:WireInput(input)
  end

  local wiredChecks = {
    frame.showBackgroundCheck,
    frame.showBarBackgroundCheck,
    frame.failedKickCheck,
    frame.showIconCheck,
    frame.iconMatchSizeCheck,
    frame.nameControls.showCheck,
    frame.displayInterruptNameCheck,
    frame.timerControls.showCheck,
    frame.hideReadyCheck,
    frame.clickAnnounceCheck,
    frame.antiSpamCheck,
    frame.soundEnabledCheck,
    frame.soundOwnOnlyCheck,
  }
  for _, check in ipairs(wiredChecks) do
    check:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  end

  for _, meta in ipairs(frame.filterControls) do
    meta.check:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  end

  WireColor(frame.nameControls.colorWrap, function() Panel:ApplyCurrent() end)
  WireColor(frame.timerControls.colorWrap, function() Panel:ApplyCurrent() end)
  WireColor(frame.groupBackgroundColorWrap, function() Panel:ApplyCurrent() end)
  WireColor(frame.barBackgroundColorWrap, function() Panel:ApplyCurrent() end)

  return frame
end

function Panel:Refresh(aura)
  if not self.frame or not aura or aura.kind ~= "interrupt_tracker" then
    return
  end

  self.suppressUpdates = true
  local interrupt = ns.Interrupts:EnsureAuraDefaults(aura)

  self.frame.summary:SetText("Interrupt Tracker Display")
  self.frame.nameWrap.input:SetText(aura.name or "")
  self.frame.widthWrap.input:SetText(tostring(aura.display.width or 240))
  self.frame.heightWrap.input:SetText(tostring(aura.display.height or 34))
  self.frame.xWrap.input:SetText(tostring(aura.position.x or 0))
  self.frame.yWrap.input:SetText(tostring(aura.position.y or 0))
  SetDropdown(self.frame.anchorWrap.dropdown, aura.position.relativeTo or "UIParent")
  SetDropdown(self.frame.framePointWrap.dropdown, aura.position.point or "CENTER")
  SetDropdown(self.frame.parentPointWrap.dropdown, aura.position.relativePoint or "CENTER")
  self.frame.showBackgroundCheck:SetChecked(aura.display.showBackground ~= false)
  SetColorSwatch(self.frame.groupBackgroundColorWrap, aura.display.backgroundColor or { r = 0, g = 0, b = 0, a = 0.45 })
  self.frame.showBarBackgroundCheck:SetChecked(interrupt.showBarBackground ~= false)
  SetColorSwatch(self.frame.barBackgroundColorWrap, interrupt.barBackgroundColor or { r = 0.09, g = 0.11, b = 0.16, a = 0.94 })
  self.frame.spacingWrap.input:SetText(tostring(aura.display.spacing or 4))
  self.frame.paddingXWrap.input:SetText(tostring(interrupt.paddingX or 6))
  self.frame.paddingYWrap.input:SetText(tostring(interrupt.paddingY or 3))
  self.frame.barAlphaWrap.input:SetText(string.format("%.2f", interrupt.barAlpha or 0.88))
  self.frame.readyBarAlphaWrap.input:SetText(string.format("%.2f", interrupt.readyBarAlpha or 0.40))
  SetDropdown(self.frame.fillModeWrap.dropdown, interrupt.fillMode or "DRAIN")
  SetDropdown(self.frame.sortOrderWrap.dropdown, interrupt.sortOrder or "NONE")
  self.frame.failedKickCheck:SetChecked(interrupt.showFailedKick ~= false)

  self.frame.showIconCheck:SetChecked(aura.display.icon ~= false)
  self.frame.iconMatchSizeCheck:SetChecked(aura.display.iconMatchBarSize ~= false)
  self.frame.iconSizeWrap.input:SetText(tostring(aura.display.iconSize or aura.display.height or 34))
  SetDropdown(self.frame.iconAnchorWrap.dropdown, aura.display.iconAnchor or "LEFT")
  self.frame.iconXWrap.input:SetText(tostring(aura.display.iconOffsetX or 0))
  self.frame.iconYWrap.input:SetText(tostring(aura.display.iconOffsetY or 0))

  self.frame.nameControls.showCheck:SetChecked(aura.display.showName ~= false)
  SetDropdown(self.frame.nameControls.fontWrap.dropdown, aura.display.nameFontStyle or "FRIZQT_OUTLINE")
  self.frame.nameControls.sizeWrap.input:SetText(tostring(aura.display.nameFontSize or 12))
  SetDropdown(self.frame.nameControls.rotationWrap.dropdown, tostring(aura.display.nameRotation or 0))
  SetDropdown(self.frame.nameControls.anchorWrap.dropdown, aura.display.nameAnchor or "LEFT")
  self.frame.nameControls.xWrap.input:SetText(tostring(aura.display.nameOffsetX or 6))
  self.frame.nameControls.yWrap.input:SetText(tostring(aura.display.nameOffsetY or 0))
  SetColorSwatch(self.frame.nameControls.colorWrap, aura.display.nameColor or { r = 1, g = 1, b = 1, a = 1 })
  self.frame.displayInterruptNameCheck:SetChecked(interrupt.displayInterruptName ~= false)

  self.frame.timerControls.showCheck:SetChecked(aura.display.showTimer ~= false)
  SetDropdown(self.frame.timerControls.fontWrap.dropdown, aura.display.timerFontStyle or "FRIZQT_OUTLINE")
  self.frame.timerControls.sizeWrap.input:SetText(tostring(aura.display.timerFontSize or 12))
  SetDropdown(self.frame.timerControls.rotationWrap.dropdown, tostring(aura.display.timerRotation or 0))
  SetDropdown(self.frame.timerControls.anchorWrap.dropdown, aura.display.timerAnchor or "RIGHT")
  self.frame.timerControls.xWrap.input:SetText(tostring(aura.display.timerOffsetX or -6))
  self.frame.timerControls.yWrap.input:SetText(tostring(aura.display.timerOffsetY or 0))
  SetColorSwatch(self.frame.timerControls.colorWrap, aura.display.timerColor or { r = 1, g = 1, b = 1, a = 1 })
  SetDropdown(self.frame.timerDecimalsWrap.dropdown, tostring(aura.display.timerDecimals or 0))
  self.frame.hideReadyCheck:SetChecked(aura.display.hideReadyTimer == true)

  self.frame.clickAnnounceCheck:SetChecked(interrupt.clickToAnnounce ~= false)
  SetDropdown(self.frame.channelWrap.dropdown, interrupt.announceChannel or "PARTY")
  self.frame.antiSpamCheck:SetChecked(interrupt.antiSpam ~= false)

  self.frame.soundEnabledCheck:SetChecked(interrupt.soundEnabled == true)
  self.frame.soundOwnOnlyCheck:SetChecked(interrupt.soundOwnKickOnly ~= false)
  SetDropdown(self.frame.soundSuccessWrap.dropdown, interrupt.soundKickSuccess or "None")
  SetDropdown(self.frame.soundFailedWrap.dropdown, interrupt.soundKickFailed or "None")

  for _, meta in ipairs(self.frame.filterControls or {}) do
    meta.check:SetChecked(ApplyFilterSelection(meta, interrupt.disabledSpells))
  end

  self.suppressUpdates = false
end
