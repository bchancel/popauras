local _, ns = ...

local Frames = ns.util.Frames
local Anchors = ns.util.Anchors
local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts
local SoundPicker = ns.util.SoundPicker

local Panel = {}
ns.panels.DisplayPanel = Panel

local textAnchorValues = {
  "LEFT", "CENTER", "RIGHT", "TOP", "BOTTOM",
  "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
  "ICON",
}

local iconAnchorValues = {
  "LEFT", "CENTER", "RIGHT", "TOP", "BOTTOM",
  "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

local strataValues = {
  "BACKGROUND",
  "LOW",
  "MEDIUM",
  "HIGH",
  "DIALOG",
  "FULLSCREEN",
  "TOOLTIP",
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

local barTextureValues = {
  "FLAT",
  "GLAZE",
  "BLIZZARD",
}

local function GetSelectedTrigger(aura)
  if not aura or type(aura.triggers) ~= "table" or #aura.triggers == 0 then
    return {}
  end
  local index = tonumber(ns.db and ns.db.ui and ns.db.ui.selectedTriggerIndex or 1) or 1
  index = math.max(1, math.min(index, #aura.triggers))
  return aura.triggers[index] or aura.triggers[1] or {}
end

local function GetSoundDropdownValues()
  if ns.Interrupts and ns.Interrupts.GetSoundOptions then
    local values = {}
    for _, entry in ipairs(ns.Interrupts:GetSoundOptions() or {}) do
      local name = entry and entry.name
      if name then
        values[#values + 1] = {
          value = name,
          label = entry.label or name,
          color = entry.color,
          sourceLabel = entry.sourceLabel,
          sourceColor = entry.sourceColor,
        }
      end
    end
    return values
  end
  local values = {
    { value = "None", label = "None" },
  }
  return values
end

local function GetSoundChannelDropdownValues()
  if ns.Interrupts and ns.Interrupts.GetSoundChannelOptions then
    return ns.Interrupts:GetSoundChannelOptions() or {}
  end
  return {
    { value = "Master", label = "Master" },
  }
end

local function ResolveDropdownEntries(values)
  if type(values) == "function" then
    local resolved = values()
    if type(resolved) == "table" then
      return resolved
    end
    return {}
  end
  if type(values) == "table" then
    return values
  end
  return {}
end

local function GetDropdownEntryValueAndLabel(entry)
  if type(entry) == "table" then
    local value = entry.key or entry.value or entry.label
    local label = entry.label or entry.text or tostring(value or "")
    return value, label
  end
  return entry, tostring(entry or "")
end

local function NormalizeBarTextureValue(value)
  if not value or value == "" or value == "DEFAULT" then
    return "FLAT"
  end
  if value == "Interface\\TARGETINGFRAME\\UI-StatusBar" or value == "Interface\\TargetingFrame\\UI-StatusBar" then
    return "FLAT"
  end
  return value
end

local function InitDropdown(dropdown, values)
  dropdown._values = values
  dropdown._onChange = nil
  UIDropDownMenu_Initialize(dropdown, function(self, level)
    for _, entry in ipairs(ResolveDropdownEntries(dropdown._values)) do
      local value, label = GetDropdownEntryValueAndLabel(entry)
      local info = UIDropDownMenu_CreateInfo()
      info.text = label
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dropdown, value)
        UIDropDownMenu_SetText(dropdown, label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end

local function InitDropdownWithCallback(dropdown, values, onChange)
  dropdown._values = values
  dropdown._onChange = onChange
  UIDropDownMenu_Initialize(dropdown, function(self, level)
    for _, entry in ipairs(ResolveDropdownEntries(dropdown._values)) do
      local value, label = GetDropdownEntryValueAndLabel(entry)
      local info = UIDropDownMenu_CreateInfo()
      info.text = label
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dropdown, value)
        UIDropDownMenu_SetText(dropdown, label)
        if onChange then
          onChange(value)
        end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end

local function RefreshDropdown(dropdown)
  if not dropdown then
    return
  end
  if dropdown._onChange then
    InitDropdownWithCallback(dropdown, dropdown._values, dropdown._onChange)
  else
    InitDropdown(dropdown, dropdown._values)
  end
end

local function GetDropdownLabel(dropdown, value)
  for _, entry in ipairs(ResolveDropdownEntries(dropdown and dropdown._values)) do
    local entryValue, label = GetDropdownEntryValueAndLabel(entry)
    if entryValue == value then
      return label
    end
  end
  return tostring(value or "")
end

local function SetDropdown(dropdown, value)
  if value == "LEFT_OUTSIDE" then
    value = "LEFT"
  elseif value == "RIGHT_OUTSIDE" then
    value = "RIGHT"
  end
  UIDropDownMenu_SetSelectedValue(dropdown, value)
  UIDropDownMenu_SetText(dropdown, GetDropdownLabel(dropdown, value))
end

local function UpdateSelectorButtonText(button, dropdown)
  if not button or not dropdown then
    return
  end
  local value = UIDropDownMenu_GetSelectedValue(dropdown) or "None"
  button:SetText(GetDropdownLabel(dropdown, value))
end

local function CreateSection(parent, title, y, height)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  box:SetBackdropColor(0.08, 0.10, 0.15, 0.96)
  box:SetBackdropBorderColor(0.22, 0.28, 0.36, 1)
  box.insetLeft = 16
  box.insetRight = 20
  box:SetPoint("TOPLEFT", box.insetLeft, y)
  box:SetPoint("TOPRIGHT", -box.insetRight, y)
  box:SetHeight(height)

  box.header = CreateFrame("Frame", nil, box, "BackdropTemplate")
  box.header:SetPoint("TOPLEFT", 1, -1)
  box.header:SetPoint("TOPRIGHT", -1, -1)
  box.header:SetHeight(30)
  box.header:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  box.header:SetBackdropColor(0.14, 0.17, 0.23, 1)
  box.header:SetBackdropBorderColor(0.24, 0.31, 0.40, 1)

  box.chevron = box.header:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(box.chevron, 12, "OUTLINE")
  box.chevron:SetPoint("LEFT", 10, 0)
  box.chevron:SetText(">")
  box.chevron:SetTextColor(0.90, 0.93, 1)

  box.title = Frames.CreateLabel(box.header, title, "GameFontNormal")
  box.title:SetPoint("LEFT", box.chevron, "RIGHT", 8, 0)
  box.title:SetTextColor(0.92, 0.95, 1)

  box.bodyTop = box:CreateTexture(nil, "BORDER")
  box.bodyTop:SetTexture("Interface\\Buttons\\WHITE8x8")
  box.bodyTop:SetVertexColor(0.18, 0.24, 0.32, 0.9)
  box.bodyTop:SetPoint("TOPLEFT", box.header, "BOTTOMLEFT", 0, -1)
  box.bodyTop:SetPoint("TOPRIGHT", box.header, "BOTTOMRIGHT", 0, -1)
  box.bodyTop:SetHeight(1)
  box.expandedHeight = height
  box.collapsed = false
  box.bodyWidgets = {}
  return box
end

local function RegisterSectionWidgets(section, ...)
  for index = 1, select("#", ...) do
    local widget = select(index, ...)
    if widget then
      section.bodyWidgets[#section.bodyWidgets + 1] = widget
    end
  end
end

local function SetSectionCollapsed(section, collapsed)
  section.collapsed = collapsed == true
  section.chevron:SetText(section.collapsed and ">" or "v")
  for _, widget in ipairs(section.bodyWidgets or {}) do
    widget:SetShown(not section.collapsed)
  end
  section:SetHeight(section.collapsed and 32 or section.expandedHeight)
end

local function CreateLabeledInput(parent, label, x, y, width)
  local widget = {}
  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall")
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.input = Frames.CreateInput(parent, width or 120, 22)
  widget.input:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", 0, -4)
  return widget
end

local function ConfigureNumericInput(input, maxLetters)
  input:SetMaxLetters(maxLetters or 10)
  input:SetNumeric(false)
end

local function CreateLabeledDropdown(parent, label, x, y, width, values)
  local widget = {}
  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall")
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.dropdown = Frames.CreateDropdown(parent, width or 180)
  widget.dropdown:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", -14, -2)
  InitDropdown(widget.dropdown, values)
  return widget
end

local function PositionLabeledInput(widget, x, y)
  if not widget then
    return
  end
  widget.label:ClearAllPoints()
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.input:ClearAllPoints()
  widget.input:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", 0, -4)
end

local function PositionLabeledDropdown(widget, x, y)
  if not widget then
    return
  end
  widget.label:ClearAllPoints()
  widget.label:SetPoint("TOPLEFT", x, y)
  widget.dropdown:ClearAllPoints()
  widget.dropdown:SetPoint("TOPLEFT", widget.label, "BOTTOMLEFT", -14, -2)
end

local function PositionColorSwatch(widget, x, y)
  if not widget then
    return
  end
  widget.button:ClearAllPoints()
  widget.button:SetPoint("TOPLEFT", x, y)
  widget.label:ClearAllPoints()
  widget.label:SetPoint("LEFT", widget.button, "RIGHT", 8, 0)
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
  widget.button:SetBackdropColor(0.05, 0.06, 0.08, 0.95)

  widget.swatch = widget.button:CreateTexture(nil, "ARTWORK")
  widget.swatch:SetPoint("TOPLEFT", 4, -4)
  widget.swatch:SetPoint("BOTTOMRIGHT", -4, 4)
  widget.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")

  widget.label = Frames.CreateLabel(parent, label, "GameFontNormalSmall")
  widget.label:SetPoint("LEFT", widget.button, "RIGHT", 8, 0)
  widget.valueText = Frames.CreateLabel(parent, "", "GameFontHighlightSmall")
  widget.valueText:Hide()

  return widget
end

local function SetWidgetEnabled(widget, enabled)
  if not widget then
    return
  end

  if widget.SetEnabled then
    widget:SetEnabled(enabled)
  end
  if widget.EnableMouse then
    widget:EnableMouse(enabled)
  end
  if widget.SetAlpha then
    widget:SetAlpha(enabled and 1 or 0.45)
  end
  if widget.Text and widget.Text.SetAlpha then
    widget.Text:SetAlpha(enabled and 1 or 0.55)
  end
end

local function SetControlGroupEnabled(group, enabled)
  if not group then
    return
  end
  for _, widget in ipairs(group) do
    SetWidgetEnabled(widget, enabled)
  end
end

local function SetControlGroupShown(group, shown)
  if not group then
    return
  end
  for _, widget in ipairs(group) do
    if widget and widget.SetShown then
      widget:SetShown(shown == true)
    end
  end
end

local function SetColorSwatch(widget, color)
  color = Colors.Copy(color)
  widget.swatch:SetVertexColor(color.r, color.g, color.b, color.a)
  widget.color = color
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

local function ShowColorPicker(widget, initialColor)
  local starting = Colors.Copy(initialColor)

  local function apply()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local a = GetPickerAlpha()
    SetColorSwatch(widget, { r = r, g = g, b = b, a = a })
  end

  if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
    PrepareColorPicker()
    local info = {
      r = starting.r,
      g = starting.g,
      b = starting.b,
      opacity = starting.a == nil and 1 or starting.a,
      hasOpacity = true,
      swatchFunc = apply,
      opacityFunc = apply,
      cancelFunc = function(previous)
        if type(previous) == "table" then
          local a = previous.opacity or starting.a
          SetColorSwatch(widget, { r = previous.r or starting.r, g = previous.g or starting.g, b = previous.b or starting.b, a = a })
        else
          SetColorSwatch(widget, starting)
        end
      end,
    }
    ColorPickerFrame:SetupColorPickerAndShow(info)
    return
  end

  PrepareColorPicker()
  ColorPickerFrame.func = apply
  ColorPickerFrame.opacityFunc = apply
  ColorPickerFrame.cancelFunc = function(previous)
    if type(previous) == "table" then
      local a = previous.opacity or starting.a
      SetColorSwatch(widget, { r = previous.r or starting.r, g = previous.g or starting.g, b = previous.b or starting.b, a = a })
    else
      SetColorSwatch(widget, starting)
    end
  end
  ColorPickerFrame.hasOpacity = true
  ColorPickerFrame.opacity = starting.a == nil and 1 or starting.a
  ColorPickerFrame:SetColorRGB(starting.r, starting.g, starting.b)
  ColorPickerFrame:Show()
end

local function CreateTwoColumnTextSection(parent, topY, prefix, includeAlternateName)
  local section = {}
  section.showCheck = Frames.CreateCheckbox(parent, "Show " .. prefix)
  section.showCheck:SetPoint("TOPLEFT", 12, topY)

  section.fontWrap = CreateLabeledDropdown(parent, "Font", 12, topY - 32, 180, fontStyleValues)
  section.sizeWrap = CreateLabeledInput(parent, "Size", 240, topY - 32, 54)
  section.rotationWrap = CreateLabeledDropdown(parent, "Rotation", 330, topY - 32, 120, textRotationValues)
  if includeAlternateName then
    section.altNameWrap = CreateLabeledInput(parent, "Alternative Name", 12, topY - 94, 280)
  end

  local anchorY = includeAlternateName and (topY - 156) or (topY - 94)
  section.anchorWrap = CreateLabeledDropdown(parent, "Anchor", 12, anchorY, 180, textAnchorValues)
  section.xWrap = CreateLabeledInput(parent, "Offset X", 240, anchorY, 72)
  section.yWrap = CreateLabeledInput(parent, "Offset Y", 340, anchorY, 72)

  local colorY = includeAlternateName and (topY - 218) or (topY - 156)
  section.colorWrap = CreateColorSwatch(parent, "Text Color", 12, colorY)
  return section
end

local function CommitNumeric(input, fallback)
  local value = tonumber(input:GetText())
  if value == nil then
    input:SetText(string.format("%.2f", fallback or 0))
    return fallback
  end
  input:SetText(string.format("%.2f", value))
  return value
end

local function CommitInteger(input, fallback)
  local value = tonumber(input:GetText())
  if value == nil then
    value = fallback or 0
  end
  value = math.floor(value + 0.5)
  input:SetText(tostring(value))
  return value
end

local function CommitString(input)
  local value = tostring(input:GetText() or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  input:SetText(value)
  return value
end

local function CommitIconOverride(input, aura)
  local value = CommitString(input)
  aura.display.iconOverrideName = ""
  if value == "" or value == "0" then
    aura.display.iconOverrideId = 0
    return
  end

  local numeric = tonumber(value)
  if numeric then
    aura.display.iconOverrideId = math.floor(numeric + 0.5)
    return
  end

  aura.display.iconOverrideId = 0
  aura.display.iconOverrideName = value
end

function Panel:GetSelectedAura()
  return ns.Registry:GetAura(ns.db.ui.selectedAuraId)
end

local function ApplyGroupSizeToChildren(groupAura, width, height)
  local function applyToAura(auraId)
    local childAura = ns.Registry:GetAura(auraId)
    if not childAura then
      return
    end

    childAura.display.width = width
    childAura.display.height = height
    childAura.position.width = width
    childAura.position.height = height

    for _, nestedChildId in ipairs(childAura.children or {}) do
      applyToAura(nestedChildId)
    end
  end

  for _, childId in ipairs(groupAura.children or {}) do
    applyToAura(childId)
  end
end

function Panel:UpdateControlStates()
  if not self.frame then
    return
  end

  local frame = self.frame
  local isGroup = frame.groupSection:IsShown()
  local aura = self:GetSelectedAura()
  local isText = aura and aura.kind == "text"
  local isIconAura = aura and aura.kind == "icon"
  local showIcon = frame.showIconCheck:GetChecked() == true
  local matchBarSize = frame.iconMatchSizeCheck and frame.iconMatchSizeCheck:GetChecked() == true
  local showName = frame.nameControls.showCheck:GetChecked() == true
  local showTimer = frame.timerControls.showCheck:GetChecked() == true
  local showStacks = frame.stacksControls.showCheck:GetChecked() == true
  local showBackground = frame.showBackgroundCheck:GetChecked() == true
  local readyLook = frame.readyLookCheck:GetChecked() == true
  local trigger = GetSelectedTrigger(aura)
  local supportsShowAlways = trigger and (trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "aura")
  local showIconCooldownControls = not isGroup and not isText and isIconAura and frame.iconSection.collapsed ~= true
  local soundEnabled = frame.soundEnabledCheck:GetChecked() == true

  SetControlGroupEnabled({
    frame.barColorWrap.button, frame.barColorWrap.label,
    frame.readyLookCheck,
    frame.glowWhenActiveCheck,
    frame.showAlwaysReadyCheck,
    frame.readyColorWrap.button, frame.readyColorWrap.label,
    frame.barTextureWrap.dropdown, frame.barTextureWrap.label,
  }, not isGroup and not isText)
  SetControlGroupEnabled({ frame.showBackgroundCheck }, true)
  SetControlGroupEnabled({ frame.readyColorWrap.button, frame.readyColorWrap.label }, not isGroup and not isText and readyLook)
  SetControlGroupEnabled({ frame.showAlwaysReadyCheck }, not isGroup and not isText and supportsShowAlways)
  SetControlGroupEnabled({ frame.backgroundColorWrap.button, frame.backgroundColorWrap.label }, showBackground)

  SetControlGroupEnabled({
    frame.reverseCheck,
    frame.iconMatchSizeCheck,
    frame.hideCDMIconCheck,
    frame.altIconIdWrap.input, frame.altIconIdWrap.label,
    frame.iconAnchorWrap.dropdown, frame.iconAnchorWrap.label,
    frame.iconXWrap.input, frame.iconXWrap.label,
    frame.iconYWrap.input, frame.iconYWrap.label,
    frame.iconHint,
  }, not isGroup and not isText)
  SetControlGroupEnabled({ frame.iconSizeWrap.input, frame.iconSizeWrap.label }, showIcon and not isGroup and not isText and not matchBarSize)
  SetControlGroupShown({
    frame.iconEdgeCheck,
    frame.iconFinishFlashCheck,
    frame.iconSwipeColorWrap.button, frame.iconSwipeColorWrap.label, frame.iconSwipeColorWrap.valueText,
  }, showIconCooldownControls)
  SetControlGroupEnabled({
    frame.iconEdgeCheck,
    frame.iconFinishFlashCheck,
    frame.iconSwipeColorWrap.button, frame.iconSwipeColorWrap.label,
  }, not isGroup and not isText and isIconAura)

  SetControlGroupEnabled({
    frame.nameControls.fontWrap.dropdown, frame.nameControls.fontWrap.label,
    frame.nameControls.sizeWrap.input, frame.nameControls.sizeWrap.label,
    frame.nameControls.rotationWrap.dropdown, frame.nameControls.rotationWrap.label,
    frame.nameControls.altNameWrap.input, frame.nameControls.altNameWrap.label,
    frame.nameControls.anchorWrap.dropdown, frame.nameControls.anchorWrap.label,
    frame.nameControls.xWrap.input, frame.nameControls.xWrap.label,
    frame.nameControls.yWrap.input, frame.nameControls.yWrap.label,
    frame.nameControls.colorWrap.button, frame.nameControls.colorWrap.label,
  }, showName and not isGroup)

  SetControlGroupEnabled({
    frame.timerControls.fontWrap.dropdown, frame.timerControls.fontWrap.label,
    frame.timerControls.sizeWrap.input, frame.timerControls.sizeWrap.label,
    frame.timerControls.rotationWrap.dropdown, frame.timerControls.rotationWrap.label,
    frame.timerControls.anchorWrap.dropdown, frame.timerControls.anchorWrap.label,
    frame.timerControls.xWrap.input, frame.timerControls.xWrap.label,
    frame.timerControls.yWrap.input, frame.timerControls.yWrap.label,
    frame.timerControls.colorWrap.button, frame.timerControls.colorWrap.label,
    frame.timerControls.decimalsWrap.dropdown, frame.timerControls.decimalsWrap.label,
    frame.timerControls.hideReadyCheck,
  }, showTimer and not isGroup and not isText)

  SetControlGroupEnabled({
    frame.stacksControls.fontWrap.dropdown, frame.stacksControls.fontWrap.label,
    frame.stacksControls.sizeWrap.input, frame.stacksControls.sizeWrap.label,
    frame.stacksControls.rotationWrap.dropdown, frame.stacksControls.rotationWrap.label,
    frame.stacksControls.anchorWrap.dropdown, frame.stacksControls.anchorWrap.label,
    frame.stacksControls.xWrap.input, frame.stacksControls.xWrap.label,
    frame.stacksControls.yWrap.input, frame.stacksControls.yWrap.label,
    frame.stacksControls.colorWrap.button, frame.stacksControls.colorWrap.label,
  }, showStacks and not isGroup and not isText)

  SetControlGroupEnabled({
    frame.soundFileButton, frame.soundFileWrap.label,
    frame.soundChannelWrap.dropdown, frame.soundChannelWrap.label,
    frame.soundTestButton,
  }, soundEnabled and not isGroup)
  if (not soundEnabled or isGroup) and SoundPicker then
    SoundPicker:HideIfDropdown(frame.soundFileWrap.dropdown)
  end
end

function Panel:ApplyCurrent()
  if self.suppressUpdates then
    return
  end

  local frame = self.frame
  local aura = self:GetSelectedAura()
  if not aura then
    return
  end

  aura.name = ns.Registry:GetUniqueAuraName(frame.nameInputWrap.input:GetText(), aura.id)
  frame.nameInputWrap.input:SetText(aura.name)

  local previousOrientation = aura.display.orientation or "HORIZONTAL"
  local newOrientation = UIDropDownMenu_GetSelectedValue(frame.orientationWrap.dropdown) or previousOrientation
  local widthValue = CommitNumeric(frame.widthWrap.input, aura.display.width or 220)
  local heightValue = CommitNumeric(frame.heightWrap.input, aura.display.height or 32)
  if previousOrientation ~= newOrientation then
    widthValue, heightValue = heightValue, widthValue
    frame.widthWrap.input:SetText(tostring(widthValue))
    frame.heightWrap.input:SetText(tostring(heightValue))
  end

  aura.display.width = widthValue
  aura.display.height = heightValue
  aura.position.width = aura.display.width
  aura.position.height = aura.display.height
  if aura.kind == "group" or aura.kind == "dynamic_group" then
    ApplyGroupSizeToChildren(aura, widthValue, heightValue)
  end
  aura.position.x = CommitNumeric(frame.xWrap.input, aura.position.x or 0)
  aura.position.y = CommitNumeric(frame.yWrap.input, aura.position.y or 0)
  aura.position.relativeTo = UIDropDownMenu_GetSelectedValue(frame.anchorWrap.dropdown) or aura.position.relativeTo or "UIParent"
  aura.position.point = UIDropDownMenu_GetSelectedValue(frame.framePointWrap.dropdown) or aura.position.point or "CENTER"
  aura.position.relativePoint = UIDropDownMenu_GetSelectedValue(frame.parentPointWrap.dropdown) or aura.position.relativePoint or "CENTER"
  aura.display.frameStrata = UIDropDownMenu_GetSelectedValue(frame.strataWrap.dropdown) or aura.display.frameStrata or "MEDIUM"
  aura.display.frameLevel = CommitNumeric(frame.levelWrap.input, aura.display.frameLevel or 1)
  aura.display.orientation = newOrientation
  aura.display.color = Colors.Copy(frame.barColorWrap.color or aura.display.color)
  aura.display.alpha = aura.display.color.a
  aura.display.readyLook = frame.readyLookCheck:GetChecked() == true
  aura.display.glowWhenActive = frame.glowWhenActiveCheck:GetChecked() == true
  local trigger = GetSelectedTrigger(aura)
  if trigger and (trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "aura") then
    trigger.showAlways = frame.showAlwaysReadyCheck:GetChecked() == true
  end
  aura.display.readyColor = Colors.Copy(frame.readyColorWrap.color or aura.display.readyColor or aura.display.color)
  local selectedBarTexture = UIDropDownMenu_GetSelectedValue(frame.barTextureWrap.dropdown) or aura.display.barTexture or "FLAT"
  aura.display.barTexture = NormalizeBarTextureValue(selectedBarTexture)
  aura.display.showBackground = frame.showBackgroundCheck:GetChecked() == true
  aura.display.backgroundColor = Colors.Copy(frame.backgroundColorWrap.color or aura.display.backgroundColor)

  aura.display.spacing = CommitNumeric(frame.groupSpacingWrap.input, aura.display.spacing or 6)
  aura.display.growth = UIDropDownMenu_GetSelectedValue(frame.groupGrowthWrap.dropdown) or aura.display.growth
  aura.display.maintainAuraOrder = frame.groupMaintainOrderCheck:GetChecked() == true

  aura.display.icon = frame.showIconCheck:GetChecked() == true
  aura.display.reverse = frame.reverseCheck:GetChecked() == true
  aura.display.iconMatchBarSize = frame.iconMatchSizeCheck:GetChecked() == true
  aura.display.iconCooldownEdge = frame.iconEdgeCheck:GetChecked() == true
  aura.display.iconCooldownBling = frame.iconFinishFlashCheck:GetChecked() == true
  aura.display.hideCDMIcon = frame.hideCDMIconCheck:GetChecked() == true
  aura.display.iconSwipeColor = Colors.Copy(frame.iconSwipeColorWrap.color or aura.display.iconSwipeColor or { r = 0, g = 0, b = 0, a = 0.60 })
  CommitIconOverride(frame.altIconIdWrap.input, aura)
  aura.display.iconSize = CommitNumeric(frame.iconSizeWrap.input, aura.display.iconSize or 32)
  aura.display.iconAnchor = UIDropDownMenu_GetSelectedValue(frame.iconAnchorWrap.dropdown) or aura.display.iconAnchor
  if aura.display.iconAnchor == "LEFT_OUTSIDE" then
    aura.display.iconAnchor = "LEFT"
  elseif aura.display.iconAnchor == "RIGHT_OUTSIDE" then
    aura.display.iconAnchor = "RIGHT"
  end
  aura.display.iconOffsetX = CommitNumeric(frame.iconXWrap.input, aura.display.iconOffsetX or 0)
  aura.display.iconOffsetY = CommitNumeric(frame.iconYWrap.input, aura.display.iconOffsetY or 0)

  aura.text = aura.text or {}
  aura.text.nameOverride = CommitString(frame.nameControls.altNameWrap.input)

  aura.display.showName = frame.nameControls.showCheck:GetChecked() == true
  aura.display.nameFontStyle = UIDropDownMenu_GetSelectedValue(frame.nameControls.fontWrap.dropdown) or aura.display.nameFontStyle
  aura.display.nameFontSize = CommitInteger(frame.nameControls.sizeWrap.input, aura.display.nameFontSize or 12)
  aura.display.nameRotation = tonumber(UIDropDownMenu_GetSelectedValue(frame.nameControls.rotationWrap.dropdown) or aura.display.nameRotation or 0) or 0
  aura.display.nameAnchor = UIDropDownMenu_GetSelectedValue(frame.nameControls.anchorWrap.dropdown) or aura.display.nameAnchor
  aura.display.nameOffsetX = CommitNumeric(frame.nameControls.xWrap.input, aura.display.nameOffsetX or 0)
  aura.display.nameOffsetY = CommitNumeric(frame.nameControls.yWrap.input, aura.display.nameOffsetY or 0)
  aura.display.nameColor = Colors.Copy(frame.nameControls.colorWrap.color or aura.display.nameColor)

  aura.display.showTimer = frame.timerControls.showCheck:GetChecked() == true
  aura.display.timerFontStyle = UIDropDownMenu_GetSelectedValue(frame.timerControls.fontWrap.dropdown) or aura.display.timerFontStyle
  aura.display.timerFontSize = CommitInteger(frame.timerControls.sizeWrap.input, aura.display.timerFontSize or 12)
  aura.display.timerRotation = tonumber(UIDropDownMenu_GetSelectedValue(frame.timerControls.rotationWrap.dropdown) or aura.display.timerRotation or 0) or 0
  aura.display.timerAnchor = UIDropDownMenu_GetSelectedValue(frame.timerControls.anchorWrap.dropdown) or aura.display.timerAnchor
  aura.display.timerOffsetX = CommitNumeric(frame.timerControls.xWrap.input, aura.display.timerOffsetX or 0)
  aura.display.timerOffsetY = CommitNumeric(frame.timerControls.yWrap.input, aura.display.timerOffsetY or 0)
  aura.display.timerColor = Colors.Copy(frame.timerControls.colorWrap.color or aura.display.timerColor)
  aura.display.timerDecimals = tonumber(UIDropDownMenu_GetSelectedValue(frame.timerControls.decimalsWrap.dropdown) or aura.display.timerDecimals or 1) or 1
  aura.display.hideReadyTimer = frame.timerControls.hideReadyCheck:GetChecked() == true

  aura.display.showStacks = frame.stacksControls.showCheck:GetChecked() == true
  aura.display.stacksFontStyle = UIDropDownMenu_GetSelectedValue(frame.stacksControls.fontWrap.dropdown) or aura.display.stacksFontStyle
  aura.display.stacksFontSize = CommitInteger(frame.stacksControls.sizeWrap.input, aura.display.stacksFontSize or 14)
  aura.display.stacksRotation = tonumber(UIDropDownMenu_GetSelectedValue(frame.stacksControls.rotationWrap.dropdown) or aura.display.stacksRotation or 0) or 0
  aura.display.stacksAnchor = UIDropDownMenu_GetSelectedValue(frame.stacksControls.anchorWrap.dropdown) or aura.display.stacksAnchor
  aura.display.stacksOffsetX = CommitNumeric(frame.stacksControls.xWrap.input, aura.display.stacksOffsetX or 0)
  aura.display.stacksOffsetY = CommitNumeric(frame.stacksControls.yWrap.input, aura.display.stacksOffsetY or 0)
  aura.display.stacksColor = Colors.Copy(frame.stacksControls.colorWrap.color or aura.display.stacksColor)
  aura.display.soundEnabled = frame.soundEnabledCheck:GetChecked() == true
  aura.display.soundFile = UIDropDownMenu_GetSelectedValue(frame.soundFileWrap.dropdown) or aura.display.soundFile or "None"
  aura.display.soundChannel = UIDropDownMenu_GetSelectedValue(frame.soundChannelWrap.dropdown) or aura.display.soundChannel or "Master"

  if aura.kind == "text" then
    aura.display.icon = false
    aura.display.showTimer = false
    aura.display.showStacks = false
    aura.display.reverse = false
    aura.display.nameAnchor = UIDropDownMenu_GetSelectedValue(frame.nameControls.anchorWrap.dropdown) or aura.display.nameAnchor or "CENTER"
  end

  local region = ns.runtime:GetRegionByAuraId(aura.id)
  if region and region.frame then
    BaseRegion:ApplyAnchor(aura, region.frame)
  end

  ns.runtime:RefreshAura(aura.id)
  ns.ui.AuraTree:Refresh()
  self:UpdateControlStates()
end

function Panel:WireLiveInput(input, onApply)
  input:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    onApply()
  end)
  input:SetScript("OnEditFocusLost", function()
    onApply()
  end)
end

function Panel:WireLiveCheckbox(check, onApply)
  check:SetScript("OnClick", function()
    onApply()
  end)
end

function Panel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()
  frame.collapsedSections = frame.collapsedSections or {}

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 0, 0)
  frame.scroll:SetPoint("BOTTOMRIGHT", -28, 0)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(724, 1820)
  frame.scroll:SetScrollChild(frame.content)

  frame.summary = Frames.CreateLabel(frame.content, "", "GameFontHighlight")
  frame.summary:SetPoint("TOPLEFT", 16, -10)
  frame.summary:SetTextColor(0.87, 0.91, 1)

  frame.hint = Frames.CreateLabel(frame.content, "Placement and appearance for the selected aura.", "GameFontDisableSmall")
  frame.hint:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -2)

  frame.canvasSection = CreateSection(frame.content, "Look", -36, 480)
  frame.canvasSection.expandedHeightAura = 480
  frame.canvasSection.expandedHeightGroup = 352
  frame.groupSection = CreateSection(frame.content, "Group Layout", -396, 132)
  frame.iconSection = CreateSection(frame.content, "Icon", -560, 240)
  frame.nameSection = CreateSection(frame.content, "Name Text", -816, 290)
  frame.timerSection = CreateSection(frame.content, "Duration Text", -1122, 260)
  frame.stacksSection = CreateSection(frame.content, "Stacks Text", -1398, 220)
  frame.soundSection = CreateSection(frame.content, "Sound", -1634, 136)

  local function HookSection(section, key)
    section.header:EnableMouse(true)
    section.header:SetScript("OnMouseDown", function()
      frame.collapsedSections[key] = not frame.collapsedSections[key]
      SetSectionCollapsed(section, frame.collapsedSections[key])
      Panel:LayoutSections()
      Panel:UpdateControlStates()
    end)
  end

  HookSection(frame.canvasSection, "canvas")
  HookSection(frame.groupSection, "group")
  HookSection(frame.iconSection, "icon")
  HookSection(frame.nameSection, "name")
  HookSection(frame.timerSection, "timer")
  HookSection(frame.stacksSection, "stacks")
  HookSection(frame.soundSection, "sound")

  frame.nameInputWrap = CreateLabeledInput(frame.canvasSection, "Aura Name", 12, -34, 420)
  frame.widthWrap = CreateLabeledInput(frame.canvasSection, "Width", 12, -88, 60)
  frame.heightWrap = CreateLabeledInput(frame.canvasSection, "Height", 96, -88, 60)
  frame.xWrap = CreateLabeledInput(frame.canvasSection, "Offset X", 180, -88, 84)
  frame.yWrap = CreateLabeledInput(frame.canvasSection, "Offset Y", 280, -88, 84)
  frame.orientationWrap = CreateLabeledDropdown(frame.canvasSection, "Orientation", 380, -88, 160, { "HORIZONTAL", "VERTICAL" })
  frame.framePointWrap = CreateLabeledDropdown(frame.canvasSection, "Frame Point", 240, -150, 170, Anchors.GetPointList)
  frame.parentPointWrap = CreateLabeledDropdown(frame.canvasSection, "Parent Point", 460, -150, 170, Anchors.GetPointList)

  frame.anchorWrap = CreateLabeledDropdown(frame.canvasSection, "Anchor / Parent", 12, -150, 200, Anchors.GetTargetList)
  frame.strataWrap = CreateLabeledDropdown(frame.canvasSection, "Strata", 12, -212, 150, strataValues)
  frame.levelWrap = CreateLabeledInput(frame.canvasSection, "Level", 200, -212, 58)

  frame.barColorWrap = CreateColorSwatch(frame.canvasSection, "Bar Color", 12, -284)
  frame.readyLookCheck = Frames.CreateCheckbox(frame.canvasSection, "Style Ready State")
  frame.readyLookCheck:SetPoint("TOPLEFT", 12, -336)
  frame.glowWhenActiveCheck = Frames.CreateCheckbox(frame.canvasSection, "Glow When Active")
  frame.glowWhenActiveCheck:SetPoint("TOPLEFT", 180, -336)
  frame.showAlwaysReadyCheck = Frames.CreateCheckbox(frame.canvasSection, "Show While Ready")
  frame.showAlwaysReadyCheck:SetPoint("TOPLEFT", 360, -336)
  frame.readyColorWrap = CreateColorSwatch(frame.canvasSection, "Ready Color", 220, -284)
  frame.barTextureWrap = CreateLabeledDropdown(frame.canvasSection, "Bar Texture", 430, -276, 166, barTextureValues)
  frame.showBackgroundCheck = Frames.CreateCheckbox(frame.canvasSection, "Show Background")
  frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -364)
  frame.backgroundColorWrap = CreateColorSwatch(frame.canvasSection, "Background", 220, -364)
  frame.backgroundColorWrap.button:ClearAllPoints()
  frame.backgroundColorWrap.button:SetPoint("TOPLEFT", 220, -364)
  frame.backgroundColorWrap.label:ClearAllPoints()
  frame.backgroundColorWrap.label:SetPoint("LEFT", frame.backgroundColorWrap.button, "RIGHT", 8, 0)
  frame.barColorWrap.button:SetScript("OnClick", function()
    local widget = frame.barColorWrap
    local starting = widget.color or { r = 0.1, g = 0.6, b = 1, a = 1 }
    local function applyAndRefresh()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = GetPickerAlpha()
      SetColorSwatch(widget, { r = r, g = g, b = b, a = a })
      Panel:ApplyCurrent()
    end

    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      PrepareColorPicker()
      ColorPickerFrame:SetupColorPickerAndShow({
        r = starting.r,
        g = starting.g,
        b = starting.b,
        opacity = starting.a == nil and 1 or starting.a,
        hasOpacity = true,
        swatchFunc = applyAndRefresh,
        opacityFunc = applyAndRefresh,
        cancelFunc = function(previous)
          if type(previous) == "table" then
            local a = previous.opacity or starting.a
            SetColorSwatch(widget, { r = previous.r or starting.r, g = previous.g or starting.g, b = previous.b or starting.b, a = a })
          else
            SetColorSwatch(widget, starting)
          end
          Panel:ApplyCurrent()
        end,
      })
    else
      ShowColorPicker(widget, starting)
    end
  end)
  frame.backgroundColorWrap.button:SetScript("OnClick", function()
    local widget = frame.backgroundColorWrap
    local starting = widget.color or { r = 0, g = 0, b = 0, a = 0.45 }
    local function applyAndRefresh()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = GetPickerAlpha()
      SetColorSwatch(widget, { r = r, g = g, b = b, a = a })
      Panel:ApplyCurrent()
    end
    PrepareColorPicker()
    ColorPickerFrame:SetupColorPickerAndShow({
      r = starting.r, g = starting.g, b = starting.b,
      opacity = starting.a == nil and 1 or starting.a,
      hasOpacity = true,
      swatchFunc = applyAndRefresh,
      opacityFunc = applyAndRefresh,
      cancelFunc = function(previous)
        if type(previous) == "table" then
          local a = previous.opacity or starting.a
          SetColorSwatch(widget, { r = previous.r or starting.r, g = previous.g or starting.g, b = previous.b or starting.b, a = a })
        else
          SetColorSwatch(widget, starting)
        end
        Panel:ApplyCurrent()
      end,
    })
  end)
  frame.readyColorWrap.button:SetScript("OnClick", function()
    local widget = frame.readyColorWrap
    local starting = widget.color or { r = 0.16, g = 0.72, b = 0.26, a = 1 }
    local function applyAndRefresh()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = GetPickerAlpha()
      SetColorSwatch(widget, { r = r, g = g, b = b, a = a })
      Panel:ApplyCurrent()
    end
    PrepareColorPicker()
    ColorPickerFrame:SetupColorPickerAndShow({
      r = starting.r, g = starting.g, b = starting.b,
      opacity = starting.a == nil and 1 or starting.a,
      hasOpacity = true,
      swatchFunc = applyAndRefresh,
      opacityFunc = applyAndRefresh,
      cancelFunc = function(previous)
        if type(previous) == "table" then
          local a = previous.opacity or starting.a
          SetColorSwatch(widget, { r = previous.r or starting.r, g = previous.g or starting.g, b = previous.b or starting.b, a = a })
        else
          SetColorSwatch(widget, starting)
        end
        Panel:ApplyCurrent()
      end,
    })
  end)

  frame.groupSpacingWrap = CreateLabeledInput(frame.groupSection, "Spacing / Padding", 12, -34, 100)
  frame.groupGrowthWrap = CreateLabeledDropdown(frame.groupSection, "Grow Direction", 168, -34, 180, { "DOWN", "UP", "RIGHT", "LEFT" })
  frame.groupShowBackgroundCheck = Frames.CreateCheckbox(frame.groupSection, "Show Group Background")
  frame.groupShowBackgroundCheck:SetPoint("TOPLEFT", 12, -66)
  frame.groupBackgroundColorWrap = CreateColorSwatch(frame.groupSection, "Background", 220, -66)
  frame.groupBackgroundColorWrap.button:ClearAllPoints()
  frame.groupBackgroundColorWrap.button:SetPoint("TOPLEFT", 220, -66)
  frame.groupBackgroundColorWrap.label:ClearAllPoints()
  frame.groupBackgroundColorWrap.label:SetPoint("LEFT", frame.groupBackgroundColorWrap.button, "RIGHT", 8, 0)
  frame.groupMaintainOrderCheck = Frames.CreateCheckbox(frame.groupSection, "Maintain Aura Order")
  frame.groupMaintainOrderCheck:SetPoint("TOPLEFT", 386, -34)
  frame.groupHint = Frames.CreateLabel(frame.groupSection, "Groups control child size, spacing, order, and growth.", "GameFontDisableSmall")
  frame.groupHint:SetPoint("TOPLEFT", 12, -94)
  frame.groupHint:SetWidth(780)

  frame.showIconCheck = Frames.CreateCheckbox(frame.iconSection, "Show Icon")
  frame.showIconCheck:SetPoint("TOPLEFT", 12, -34)
  frame.reverseCheck = Frames.CreateCheckbox(frame.iconSection, "Drain / Reverse Fill")
  frame.reverseCheck:SetPoint("TOPLEFT", 150, -34)
  frame.hideCDMIconCheck = Frames.CreateCheckbox(frame.iconSection, "Hide CDM Icon")
  frame.hideCDMIconCheck:SetPoint("TOPLEFT", 330, -34)
  frame.iconMatchSizeCheck = Frames.CreateCheckbox(frame.iconSection, "Match Bar Size")
  frame.iconMatchSizeCheck:SetPoint("TOPLEFT", 12, -64)
  frame.iconEdgeCheck = Frames.CreateCheckbox(frame.iconSection, "Bright Cooldown Edge")
  frame.iconEdgeCheck:SetPoint("TOPLEFT", 180, -64)
  frame.iconFinishFlashCheck = Frames.CreateCheckbox(frame.iconSection, "Finish Flash")
  frame.iconFinishFlashCheck:SetPoint("TOPLEFT", 380, -64)
  frame.iconSizeWrap = CreateLabeledInput(frame.iconSection, "Icon Size", 12, -96, 54)
  frame.iconAnchorWrap = CreateLabeledDropdown(frame.iconSection, "Icon Anchor", 110, -96, 150, iconAnchorValues)
  frame.iconXWrap = CreateLabeledInput(frame.iconSection, "Icon X", 310, -96, 60)
  frame.iconYWrap = CreateLabeledInput(frame.iconSection, "Icon Y", 410, -96, 60)
  frame.altIconIdWrap = CreateLabeledInput(frame.iconSection, "Alternate Icon Name / ID", 12, -158, 280)
  frame.iconSwipeColorWrap = CreateColorSwatch(frame.iconSection, "Cooldown Shade", 360, -158)
  frame.iconHint = Frames.CreateLabel(frame.iconSection, "Alternate icon accepts a spell name, spell ID, or raw texture file ID. Hide CDM Icon only affects mapped tracked-buff icons.", "GameFontDisableSmall")
  frame.iconHint:SetPoint("TOPLEFT", 12, -196)
  frame.iconHint:SetWidth(660)

  frame.soundEnabledCheck = Frames.CreateCheckbox(frame.soundSection, "Play Sound On Activate")
  frame.soundEnabledCheck:SetPoint("TOPLEFT", 12, -34)
  frame.soundFileWrap = CreateLabeledDropdown(frame.soundSection, "Sound", 12, -68, 260, GetSoundDropdownValues)
  frame.soundFileWrap.dropdown:Hide()
  frame.soundFileButton = Frames.CreateSelectorButton(frame.soundSection, 246, 24)
  frame.soundFileButton:SetPoint("TOPLEFT", frame.soundFileWrap.label, "BOTTOMLEFT", 0, -6)
  frame.soundFileButton:SetScript("OnClick", function()
    if not SoundPicker then
      return
    end
    SoundPicker:Toggle(frame.soundFileButton, frame.soundFileWrap.dropdown, GetSoundDropdownValues, {
      title = "Select Aura Sound",
      onChanged = function()
        UpdateSelectorButtonText(frame.soundFileButton, frame.soundFileWrap.dropdown)
        Panel:ApplyCurrent()
      end,
      channelProvider = function()
        return UIDropDownMenu_GetSelectedValue(frame.soundChannelWrap.dropdown) or "Master"
      end,
    })
  end)
  frame.soundChannelWrap = CreateLabeledDropdown(frame.soundSection, "Channel", 296, -68, 150, GetSoundChannelDropdownValues)
  frame.soundTestButton = Frames.CreateButton(frame.soundSection, "Test", 52, 22, function()
    if ns.Interrupts and ns.Interrupts.PlaySound then
      ns.Interrupts:PlaySound(
        UIDropDownMenu_GetSelectedValue(frame.soundFileWrap.dropdown) or "None",
        UIDropDownMenu_GetSelectedValue(frame.soundChannelWrap.dropdown) or "Master"
      )
    end
  end)
  frame.soundTestButton:SetPoint("TOPLEFT", 468, -88)
  Frames.StyleSecondaryButton(frame.soundTestButton)
  frame.soundHint = Frames.CreateLabel(frame.soundSection, "Plays once when the aura becomes visible or active. The picker is scrollable and color-codes sounds by source pack. Use %m in text auras if you want the matched chat message rendered.", "GameFontDisableSmall")
  frame.soundHint:SetPoint("TOPLEFT", 12, -118)
  frame.soundHint:SetWidth(660)

  frame.nameControls = CreateTwoColumnTextSection(frame.nameSection, -34, "Name", true)
  frame.timerControls = CreateTwoColumnTextSection(frame.timerSection, -34, "Duration")
  frame.stacksControls = CreateTwoColumnTextSection(frame.stacksSection, -34, "Stack Count")
  frame.timerControls.decimalsWrap = CreateLabeledDropdown(frame.timerSection, "Decimals", 150, -190, 120, { "0", "1", "2" })
  frame.timerControls.hideReadyCheck = Frames.CreateCheckbox(frame.timerSection, "Hide While Ready")
  frame.timerControls.hideReadyCheck:SetPoint("TOPLEFT", 310, -218)

  RegisterSectionWidgets(frame.canvasSection,
    frame.nameInputWrap.label, frame.nameInputWrap.input,
    frame.widthWrap.label, frame.widthWrap.input,
    frame.heightWrap.label, frame.heightWrap.input,
    frame.xWrap.label, frame.xWrap.input,
    frame.yWrap.label, frame.yWrap.input,
    frame.orientationWrap.label, frame.orientationWrap.dropdown,
    frame.framePointWrap.label, frame.framePointWrap.dropdown,
    frame.parentPointWrap.label, frame.parentPointWrap.dropdown,
    frame.anchorWrap.label, frame.anchorWrap.dropdown,
    frame.strataWrap.label, frame.strataWrap.dropdown,
    frame.levelWrap.label, frame.levelWrap.input,
    frame.barColorWrap.label, frame.barColorWrap.button, frame.barColorWrap.valueText,
    frame.readyLookCheck,
    frame.glowWhenActiveCheck,
    frame.showAlwaysReadyCheck,
    frame.readyColorWrap.label, frame.readyColorWrap.button, frame.readyColorWrap.valueText,
    frame.barTextureWrap.label, frame.barTextureWrap.dropdown,
    frame.showBackgroundCheck,
    frame.backgroundColorWrap.label, frame.backgroundColorWrap.button, frame.backgroundColorWrap.valueText
  )
  RegisterSectionWidgets(frame.groupSection,
    frame.groupSpacingWrap.label, frame.groupSpacingWrap.input,
    frame.groupGrowthWrap.label, frame.groupGrowthWrap.dropdown,
    frame.groupShowBackgroundCheck,
    frame.groupBackgroundColorWrap.label, frame.groupBackgroundColorWrap.button, frame.groupBackgroundColorWrap.valueText,
    frame.groupMaintainOrderCheck,
    frame.groupHint
  )
  RegisterSectionWidgets(frame.iconSection,
    frame.showIconCheck, frame.reverseCheck, frame.hideCDMIconCheck, frame.iconEdgeCheck, frame.iconFinishFlashCheck, frame.iconMatchSizeCheck,
    frame.iconSizeWrap.label, frame.iconSizeWrap.input,
    frame.iconAnchorWrap.label, frame.iconAnchorWrap.dropdown,
    frame.altIconIdWrap.label, frame.altIconIdWrap.input,
    frame.iconXWrap.label, frame.iconXWrap.input,
    frame.iconYWrap.label, frame.iconYWrap.input,
    frame.iconSwipeColorWrap.label, frame.iconSwipeColorWrap.button, frame.iconSwipeColorWrap.valueText,
    frame.iconHint
  )
  RegisterSectionWidgets(frame.nameSection,
    frame.nameControls.showCheck,
    frame.nameControls.fontWrap.label, frame.nameControls.fontWrap.dropdown,
    frame.nameControls.sizeWrap.label, frame.nameControls.sizeWrap.input,
    frame.nameControls.rotationWrap.label, frame.nameControls.rotationWrap.dropdown,
    frame.nameControls.altNameWrap.label, frame.nameControls.altNameWrap.input,
    frame.nameControls.anchorWrap.label, frame.nameControls.anchorWrap.dropdown,
    frame.nameControls.xWrap.label, frame.nameControls.xWrap.input,
    frame.nameControls.yWrap.label, frame.nameControls.yWrap.input,
    frame.nameControls.colorWrap.label, frame.nameControls.colorWrap.button, frame.nameControls.colorWrap.valueText
  )
  RegisterSectionWidgets(frame.timerSection,
    frame.timerControls.showCheck,
    frame.timerControls.fontWrap.label, frame.timerControls.fontWrap.dropdown,
    frame.timerControls.sizeWrap.label, frame.timerControls.sizeWrap.input,
    frame.timerControls.rotationWrap.label, frame.timerControls.rotationWrap.dropdown,
    frame.timerControls.anchorWrap.label, frame.timerControls.anchorWrap.dropdown,
    frame.timerControls.xWrap.label, frame.timerControls.xWrap.input,
    frame.timerControls.yWrap.label, frame.timerControls.yWrap.input,
    frame.timerControls.colorWrap.label, frame.timerControls.colorWrap.button, frame.timerControls.colorWrap.valueText,
    frame.timerControls.decimalsWrap.label, frame.timerControls.decimalsWrap.dropdown,
    frame.timerControls.hideReadyCheck
  )
  RegisterSectionWidgets(frame.stacksSection,
    frame.stacksControls.showCheck,
    frame.stacksControls.fontWrap.label, frame.stacksControls.fontWrap.dropdown,
    frame.stacksControls.sizeWrap.label, frame.stacksControls.sizeWrap.input,
    frame.stacksControls.rotationWrap.label, frame.stacksControls.rotationWrap.dropdown,
    frame.stacksControls.anchorWrap.label, frame.stacksControls.anchorWrap.dropdown,
    frame.stacksControls.xWrap.label, frame.stacksControls.xWrap.input,
    frame.stacksControls.yWrap.label, frame.stacksControls.yWrap.input,
    frame.stacksControls.colorWrap.label, frame.stacksControls.colorWrap.button, frame.stacksControls.colorWrap.valueText
  )
  RegisterSectionWidgets(frame.soundSection,
    frame.soundEnabledCheck,
    frame.soundFileWrap.label, frame.soundFileButton,
    frame.soundChannelWrap.label, frame.soundChannelWrap.dropdown,
    frame.soundTestButton,
    frame.soundHint
  )
  frame.saveButton = Frames.CreateButton(frame.content, "Save", 150, 28, function()
    Panel:ApplyCurrent()
  end)
  frame.saveButton:Hide()

  ConfigureNumericInput(frame.widthWrap.input, 3)
  ConfigureNumericInput(frame.heightWrap.input, 3)
  ConfigureNumericInput(frame.xWrap.input, 10)
  ConfigureNumericInput(frame.yWrap.input, 10)
  ConfigureNumericInput(frame.levelWrap.input, 5)
  ConfigureNumericInput(frame.groupSpacingWrap.input, 3)
  ConfigureNumericInput(frame.iconSizeWrap.input, 3)
  frame.altIconIdWrap.input:SetMaxLetters(64)
  ConfigureNumericInput(frame.iconXWrap.input, 10)
  ConfigureNumericInput(frame.iconYWrap.input, 10)
  frame.nameControls.altNameWrap.input:SetMaxLetters(64)
  ConfigureNumericInput(frame.nameControls.sizeWrap.input, 3)
  ConfigureNumericInput(frame.nameControls.xWrap.input, 10)
  ConfigureNumericInput(frame.nameControls.yWrap.input, 10)
  ConfigureNumericInput(frame.timerControls.sizeWrap.input, 3)
  ConfigureNumericInput(frame.timerControls.xWrap.input, 10)
  ConfigureNumericInput(frame.timerControls.yWrap.input, 10)
  ConfigureNumericInput(frame.stacksControls.sizeWrap.input, 3)
  ConfigureNumericInput(frame.stacksControls.xWrap.input, 10)
  ConfigureNumericInput(frame.stacksControls.yWrap.input, 10)

  frame.sections = {
    frame.canvasSection,
    frame.groupSection,
    frame.iconSection,
    frame.nameSection,
    frame.timerSection,
    frame.stacksSection,
    frame.soundSection,
  }

  self.frame = frame

  self:WireLiveInput(frame.nameInputWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.widthWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.heightWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.xWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.yWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.levelWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.groupSpacingWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.iconSizeWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.altIconIdWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.iconXWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.iconYWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.nameControls.altNameWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.nameControls.sizeWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.nameControls.xWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.nameControls.yWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.timerControls.sizeWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.timerControls.xWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.timerControls.yWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.stacksControls.sizeWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.stacksControls.xWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.stacksControls.yWrap.input, function() Panel:ApplyCurrent() end)

  self:WireLiveCheckbox(frame.showIconCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.reverseCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.iconEdgeCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.iconFinishFlashCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.iconMatchSizeCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.hideCDMIconCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.showBackgroundCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.groupShowBackgroundCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.readyLookCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.glowWhenActiveCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.showAlwaysReadyCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.groupMaintainOrderCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.soundEnabledCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.nameControls.showCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.timerControls.showCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.timerControls.hideReadyCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.stacksControls.showCheck, function() Panel:ApplyCurrent() end)

  InitDropdownWithCallback(frame.strataWrap.dropdown, strataValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.orientationWrap.dropdown, { "HORIZONTAL", "VERTICAL" }, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.framePointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.parentPointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.anchorWrap.dropdown, Anchors.GetTargetList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.barTextureWrap.dropdown, barTextureValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.groupGrowthWrap.dropdown, { "DOWN", "UP", "RIGHT", "LEFT" }, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.iconAnchorWrap.dropdown, iconAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.soundFileWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.soundChannelWrap.dropdown, GetSoundChannelDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.nameControls.fontWrap.dropdown, fontStyleValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.nameControls.rotationWrap.dropdown, textRotationValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.nameControls.anchorWrap.dropdown, textAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.timerControls.fontWrap.dropdown, fontStyleValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.timerControls.rotationWrap.dropdown, textRotationValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.timerControls.anchorWrap.dropdown, textAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.timerControls.decimalsWrap.dropdown, { "0", "1", "2" }, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.stacksControls.fontWrap.dropdown, fontStyleValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.stacksControls.rotationWrap.dropdown, textRotationValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.stacksControls.anchorWrap.dropdown, textAnchorValues, function() Panel:ApplyCurrent() end)

  local function WireColor(widget, defaultColor)
    widget.button:SetScript("OnClick", function()
      local starting = widget.color or defaultColor
      local function applyAndRefresh()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = GetPickerAlpha()
        SetColorSwatch(widget, { r = r, g = g, b = b, a = a })
        Panel:ApplyCurrent()
      end
      PrepareColorPicker()
      ColorPickerFrame:SetupColorPickerAndShow({
        r = starting.r, g = starting.g, b = starting.b,
        opacity = starting.a == nil and 1 or starting.a,
        hasOpacity = true,
        swatchFunc = applyAndRefresh,
        opacityFunc = applyAndRefresh,
        cancelFunc = function(previous)
          if type(previous) == "table" then
            local a = previous.opacity or starting.a
            SetColorSwatch(widget, { r = previous.r or starting.r, g = previous.g or starting.g, b = previous.b or starting.b, a = a })
          else
            SetColorSwatch(widget, starting)
          end
          Panel:ApplyCurrent()
        end,
      })
    end)
  end

  WireColor(frame.nameControls.colorWrap, { r = 1, g = 1, b = 1, a = 1 })
  WireColor(frame.timerControls.colorWrap, { r = 1, g = 1, b = 1, a = 1 })
  WireColor(frame.stacksControls.colorWrap, { r = 1, g = 1, b = 1, a = 1 })
  WireColor(frame.iconSwipeColorWrap, { r = 0, g = 0, b = 0, a = 0.60 })
  WireColor(frame.groupBackgroundColorWrap, { r = 0, g = 0, b = 0, a = 0.45 })

  return frame
end

function Panel:ApplyCanvasLayout(isGroup)
  if not self.frame then
    return
  end

  local frame = self.frame

  PositionLabeledInput(frame.nameInputWrap, 12, -34)

  if isGroup then
    PositionLabeledInput(frame.widthWrap, 12, -88)
    PositionLabeledInput(frame.heightWrap, 98, -88)
    PositionLabeledInput(frame.xWrap, 184, -88)
    PositionLabeledInput(frame.yWrap, 286, -88)

    PositionLabeledDropdown(frame.anchorWrap, 12, -150)
    PositionLabeledDropdown(frame.framePointWrap, 310, -150)

    PositionLabeledDropdown(frame.parentPointWrap, 12, -212)
    PositionLabeledDropdown(frame.strataWrap, 250, -212)
    PositionLabeledInput(frame.levelWrap, 430, -212)

    frame.showBackgroundCheck:ClearAllPoints()
    frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -274)
    PositionColorSwatch(frame.backgroundColorWrap, 180, -274)
    return
  end

  PositionLabeledInput(frame.widthWrap, 12, -88)
  PositionLabeledInput(frame.heightWrap, 96, -88)
  PositionLabeledInput(frame.xWrap, 180, -88)
  PositionLabeledInput(frame.yWrap, 280, -88)
  PositionLabeledDropdown(frame.orientationWrap, 380, -88)

  PositionLabeledDropdown(frame.anchorWrap, 12, -150)
  PositionLabeledDropdown(frame.framePointWrap, 240, -150)
  PositionLabeledDropdown(frame.parentPointWrap, 460, -150)

  PositionLabeledDropdown(frame.strataWrap, 12, -212)
  PositionLabeledInput(frame.levelWrap, 200, -212)

  PositionColorSwatch(frame.barColorWrap, 12, -284)
  PositionColorSwatch(frame.readyColorWrap, 220, -284)
  PositionLabeledDropdown(frame.barTextureWrap, 430, -276)
  frame.readyLookCheck:ClearAllPoints()
  frame.readyLookCheck:SetPoint("TOPLEFT", 12, -336)
  frame.glowWhenActiveCheck:ClearAllPoints()
  frame.glowWhenActiveCheck:SetPoint("TOPLEFT", 180, -336)
  frame.showAlwaysReadyCheck:ClearAllPoints()
  frame.showAlwaysReadyCheck:SetPoint("TOPLEFT", 360, -336)

  frame.showBackgroundCheck:ClearAllPoints()
  frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -364)
  PositionColorSwatch(frame.backgroundColorWrap, 220, -364)
end

function Panel:LayoutSections()
  if not self.frame or not self.frame.sections then
    return
  end

  local y = -36
  for _, section in ipairs(self.frame.sections) do
    if section:IsShown() then
      section:ClearAllPoints()
      section:SetPoint("TOPLEFT", section.insetLeft or 16, y)
      section:SetPoint("TOPRIGHT", -(section.insetRight or 20), y)
      y = y - section:GetHeight() - 10
    end
  end
  local minHeight = self.frame:GetHeight() > 0 and self.frame:GetHeight() or 640
  self.frame.content:SetHeight(math.max(minHeight, math.abs(y) + 40))
end

function Panel:Refresh(aura)
  self.suppressUpdates = true
  local isGroup = aura.kind == "group" or aura.kind == "dynamic_group"
  local isText = aura.kind == "text"
  local isIconAura = aura.kind == "icon"
  local trigger = GetSelectedTrigger(aura)
  local supportsShowAlways = trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "aura"
  local summaryText = aura.kind:gsub("_", " ")
  summaryText = summaryText:gsub("(%a)([%w']*)", function(first, rest)
    return string.upper(first) .. rest
  end)
  self.frame.summary:SetText(summaryText .. " Display")
  if isGroup then
    self.frame.hint:SetText("Dock this group to the screen, CDM, unit frames, or another group, then tune spacing below.")
  elseif isText then
    self.frame.hint:SetText("Text-only alert aura. Use the trigger tab for death filters, sounds, and alert duration.")
  else
    self.frame.hint:SetText("Placement and appearance for the selected aura.")
  end

  self.frame.nameInputWrap.input:SetText(aura.name or "")
  self.frame.widthWrap.input:SetText(tostring(aura.display.width or 220))
  self.frame.heightWrap.input:SetText(tostring(aura.display.height or 32))
  self.frame.xWrap.input:SetText(tostring(aura.position.x or 0))
  self.frame.yWrap.input:SetText(tostring(aura.position.y or 0))
  RefreshDropdown(self.frame.anchorWrap.dropdown)
  RefreshDropdown(self.frame.framePointWrap.dropdown)
  RefreshDropdown(self.frame.parentPointWrap.dropdown)
  RefreshDropdown(self.frame.soundFileWrap.dropdown)
  RefreshDropdown(self.frame.soundChannelWrap.dropdown)
  SetDropdown(self.frame.strataWrap.dropdown, aura.display.frameStrata or "MEDIUM")
  self.frame.levelWrap.input:SetText(tostring(aura.display.frameLevel or 1))
  SetColorSwatch(self.frame.barColorWrap, {
    r = aura.display.color.r or 0,
    g = aura.display.color.g or 0,
    b = aura.display.color.b or 0,
    a = aura.display.color.a == nil and (aura.display.alpha or 1) or aura.display.color.a,
  })
  self.frame.readyLookCheck:SetChecked(aura.display.readyLook == true)
  self.frame.glowWhenActiveCheck:SetChecked(aura.display.glowWhenActive == true)
  self.frame.showAlwaysReadyCheck:SetChecked(trigger.showAlways == true)
  if self.frame.readyLookCheck.Text then
    if trigger.type == "aura" then
      if trigger.auraFilter == "missing" then
        self.frame.readyLookCheck.Text:SetText("Style Present State")
      else
        self.frame.readyLookCheck.Text:SetText("Style Missing State")
      end
    else
      self.frame.readyLookCheck.Text:SetText("Style Ready State")
    end
  end
  if self.frame.showAlwaysReadyCheck.Text then
    if trigger.type == "aura" then
      if trigger.auraFilter == "missing" then
        self.frame.showAlwaysReadyCheck.Text:SetText("Show While Present")
        self.frame.readyColorWrap.label:SetText("Present Color")
      else
        self.frame.showAlwaysReadyCheck.Text:SetText("Show While Missing")
        self.frame.readyColorWrap.label:SetText("Missing Color")
      end
    else
      self.frame.showAlwaysReadyCheck.Text:SetText("Show While Ready")
      self.frame.readyColorWrap.label:SetText("Ready Color")
    end
  else
    self.frame.readyColorWrap.label:SetText("Ready Color")
  end
  SetColorSwatch(self.frame.readyColorWrap, aura.display.readyColor or { r = 0.16, g = 0.72, b = 0.26, a = 1 })
  aura.display.barTexture = NormalizeBarTextureValue(aura.display.barTexture)
  SetDropdown(self.frame.barTextureWrap.dropdown, aura.display.barTexture or "FLAT")
  self.frame.showBackgroundCheck:SetChecked(aura.display.showBackground ~= false)
  SetColorSwatch(self.frame.backgroundColorWrap, aura.display.backgroundColor or { r = 0, g = 0, b = 0, a = 0.45 })

  self.frame.groupSpacingWrap.input:SetText(tostring(aura.display.spacing or 6))
  self.frame.groupMaintainOrderCheck:SetChecked(aura.display.maintainAuraOrder == true)
  self.frame.showIconCheck:SetChecked(aura.display.icon == true)
  self.frame.reverseCheck:SetChecked(aura.display.reverse == true)
  self.frame.iconEdgeCheck:SetChecked(aura.display.iconCooldownEdge == true)
  self.frame.iconFinishFlashCheck:SetChecked(aura.display.iconCooldownBling == true)
  self.frame.iconMatchSizeCheck:SetChecked(aura.display.iconMatchBarSize == true)
  self.frame.hideCDMIconCheck:SetChecked(aura.display.hideCDMIcon == true)
  local iconOverrideText = aura.display.iconOverrideName or ""
  if iconOverrideText == "" then
    local overrideId = tonumber(aura.display.iconOverrideId or 0) or 0
    iconOverrideText = overrideId > 0 and tostring(overrideId) or ""
  end
  self.frame.altIconIdWrap.input:SetText(iconOverrideText)
  self.frame.iconSizeWrap.input:SetText(tostring(aura.display.iconSize or 32))
  self.frame.iconXWrap.input:SetText(tostring(aura.display.iconOffsetX or 0))
  self.frame.iconYWrap.input:SetText(tostring(aura.display.iconOffsetY or 0))
  SetColorSwatch(self.frame.iconSwipeColorWrap, aura.display.iconSwipeColor or { r = 0, g = 0, b = 0, a = 0.60 })
  self.frame.soundEnabledCheck:SetChecked(aura.display.soundEnabled == true)

  SetDropdown(self.frame.orientationWrap.dropdown, aura.display.orientation or "HORIZONTAL")
  SetDropdown(self.frame.anchorWrap.dropdown, aura.position.relativeTo or "UIParent")
  SetDropdown(self.frame.framePointWrap.dropdown, aura.position.point or "CENTER")
  SetDropdown(self.frame.parentPointWrap.dropdown, aura.position.relativePoint or "CENTER")
  SetDropdown(self.frame.groupGrowthWrap.dropdown, aura.display.growth or "DOWN")
  SetDropdown(self.frame.iconAnchorWrap.dropdown, aura.display.iconAnchor or "LEFT")
  SetDropdown(self.frame.soundFileWrap.dropdown, aura.display.soundFile or "None")
  UpdateSelectorButtonText(self.frame.soundFileButton, self.frame.soundFileWrap.dropdown)
  SetDropdown(self.frame.soundChannelWrap.dropdown, aura.display.soundChannel or "Master")
  if SoundPicker then
    SoundPicker:RefreshIfOpen(self.frame.soundFileWrap.dropdown)
  end

  self.frame.nameControls.showCheck:SetChecked(aura.display.showName == true)
  self.frame.nameControls.altNameWrap.input:SetText((aura.text and aura.text.nameOverride) or "")
  self.frame.nameControls.altNameWrap.label:SetText(isText and "Text Template" or "Alternative Name")
  SetDropdown(self.frame.nameControls.fontWrap.dropdown, aura.display.nameFontStyle or "FRIZQT_OUTLINE")
  self.frame.nameControls.sizeWrap.input:SetText(tostring(aura.display.nameFontSize or 12))
  SetDropdown(self.frame.nameControls.rotationWrap.dropdown, tostring(aura.display.nameRotation or 0))
  SetDropdown(self.frame.nameControls.anchorWrap.dropdown, aura.display.nameAnchor or "LEFT")
  self.frame.nameControls.xWrap.input:SetText(tostring(aura.display.nameOffsetX or 0))
  self.frame.nameControls.yWrap.input:SetText(tostring(aura.display.nameOffsetY or 0))
  SetColorSwatch(self.frame.nameControls.colorWrap, aura.display.nameColor or { r = 1, g = 1, b = 1, a = 1 })

  self.frame.timerControls.showCheck:SetChecked(aura.display.showTimer == true)
  SetDropdown(self.frame.timerControls.fontWrap.dropdown, aura.display.timerFontStyle or "FRIZQT_OUTLINE")
  self.frame.timerControls.sizeWrap.input:SetText(tostring(aura.display.timerFontSize or 12))
  SetDropdown(self.frame.timerControls.rotationWrap.dropdown, tostring(aura.display.timerRotation or 0))
  SetDropdown(self.frame.timerControls.anchorWrap.dropdown, aura.display.timerAnchor or "RIGHT")
  self.frame.timerControls.xWrap.input:SetText(tostring(aura.display.timerOffsetX or 0))
  self.frame.timerControls.yWrap.input:SetText(tostring(aura.display.timerOffsetY or 0))
  SetColorSwatch(self.frame.timerControls.colorWrap, aura.display.timerColor or { r = 1, g = 1, b = 1, a = 1 })
  SetDropdown(self.frame.timerControls.decimalsWrap.dropdown, tostring(aura.display.timerDecimals or 1))
  self.frame.timerControls.hideReadyCheck:SetChecked(aura.display.hideReadyTimer == true)

  self.frame.stacksControls.showCheck:SetChecked(aura.display.showStacks == true)
  SetDropdown(self.frame.stacksControls.fontWrap.dropdown, aura.display.stacksFontStyle or "FRIZQT_OUTLINE")
  self.frame.stacksControls.sizeWrap.input:SetText(tostring(aura.display.stacksFontSize or 14))
  SetDropdown(self.frame.stacksControls.rotationWrap.dropdown, tostring(aura.display.stacksRotation or 0))
  SetDropdown(self.frame.stacksControls.anchorWrap.dropdown, aura.display.stacksAnchor or "TOPRIGHT")
  self.frame.stacksControls.xWrap.input:SetText(tostring(aura.display.stacksOffsetX or 0))
  self.frame.stacksControls.yWrap.input:SetText(tostring(aura.display.stacksOffsetY or 0))
  SetColorSwatch(self.frame.stacksControls.colorWrap, aura.display.stacksColor or { r = 1, g = 1, b = 1, a = 1 })

  self.frame.groupSection:SetShown(isGroup)
  self.frame.iconSection:SetShown(not isGroup and not isText)
  self.frame.nameSection:SetShown(not isGroup)
  self.frame.timerSection:SetShown(not isGroup and not isText)
  self.frame.stacksSection:SetShown(not isGroup and not isText)
  self.frame.soundSection:SetShown(not isGroup)
  if isGroup and SoundPicker then
    SoundPicker:HideIfDropdown(self.frame.soundFileWrap.dropdown)
  end

  self.frame.canvasSection.expandedHeight = isGroup and self.frame.canvasSection.expandedHeightGroup or self.frame.canvasSection.expandedHeightAura

  SetSectionCollapsed(self.frame.canvasSection, self.frame.collapsedSections.canvas)
  SetSectionCollapsed(self.frame.groupSection, self.frame.collapsedSections.group)
  SetSectionCollapsed(self.frame.iconSection, self.frame.collapsedSections.icon)
  SetSectionCollapsed(self.frame.nameSection, self.frame.collapsedSections.name)
  SetSectionCollapsed(self.frame.timerSection, self.frame.collapsedSections.timer)
  SetSectionCollapsed(self.frame.stacksSection, self.frame.collapsedSections.stacks)
  SetSectionCollapsed(self.frame.soundSection, self.frame.collapsedSections.sound)

  self.frame.orientationWrap.label:SetShown(not isGroup and not isText)
  self.frame.orientationWrap.dropdown:SetShown(not isGroup and not isText)
  self.frame.strataWrap.label:SetShown(true)
  self.frame.strataWrap.dropdown:SetShown(true)
  self.frame.levelWrap.label:SetShown(true)
  self.frame.levelWrap.input:SetShown(true)
  self.frame.barColorWrap.label:SetShown(not isGroup and not isText)
  self.frame.barColorWrap.button:SetShown(not isGroup and not isText)
  self.frame.barColorWrap.valueText:SetShown(not isGroup and not isText)
  self.frame.readyLookCheck:SetShown(not isGroup and not isText)
  self.frame.glowWhenActiveCheck:SetShown(not isGroup and not isText)
  self.frame.showAlwaysReadyCheck:SetShown(not isGroup and not isText and supportsShowAlways)
  self.frame.readyColorWrap.label:SetShown(not isGroup and not isText)
  self.frame.readyColorWrap.button:SetShown(not isGroup and not isText)
  self.frame.readyColorWrap.valueText:SetShown(not isGroup and not isText)
  self.frame.barTextureWrap.label:SetShown(not isGroup and not isText)
  self.frame.barTextureWrap.dropdown:SetShown(not isGroup and not isText)
  self.frame.showBackgroundCheck:SetShown(true)
  self.frame.backgroundColorWrap.label:SetShown(true)
  self.frame.backgroundColorWrap.button:SetShown(true)
  self.frame.backgroundColorWrap.valueText:SetShown(true)
  self.frame.iconEdgeCheck:SetShown(isIconAura)
  self.frame.iconFinishFlashCheck:SetShown(isIconAura)
  self.frame.iconSwipeColorWrap.label:SetShown(isIconAura)
  self.frame.iconSwipeColorWrap.button:SetShown(isIconAura)
  self.frame.iconSwipeColorWrap.valueText:SetShown(isIconAura)
  self.frame.groupShowBackgroundCheck:SetShown(false)
  self.frame.groupBackgroundColorWrap.label:SetShown(false)
  self.frame.groupBackgroundColorWrap.button:SetShown(false)
  self.frame.groupBackgroundColorWrap.valueText:SetShown(false)

  self:ApplyCanvasLayout(isGroup)
  self:LayoutSections()
  self:UpdateControlStates()
  self.suppressUpdates = false
end
