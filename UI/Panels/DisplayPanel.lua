local _, ns = ...

local Frames = ns.util.Frames
local Anchors = ns.util.Anchors
local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local Fonts = ns.util.Fonts
local SoundPicker = ns.util.SoundPicker
local Spells = ns.util.Spells
local Theme = ns.util.Theme

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

local raidFrameAnchorValues = {
  { value = "LEFT", label = "Left" },
  { value = "LEFT_OUTSIDE", label = "Left Outside" },
  { value = "CENTER", label = "Center" },
  { value = "RIGHT", label = "Right" },
  { value = "RIGHT_OUTSIDE", label = "Right Outside" },
  { value = "TOP", label = "Top" },
  { value = "BOTTOM", label = "Bottom" },
  { value = "TOPLEFT", label = "Top Left" },
  { value = "TOPRIGHT", label = "Top Right" },
  { value = "BOTTOMLEFT", label = "Bottom Left" },
  { value = "BOTTOMRIGHT", label = "Bottom Right" },
}

local raidFrameGrowthValues = {
  { value = "AUTO", label = "Auto" },
  { value = "RIGHT", label = "Right" },
  { value = "LEFT", label = "Left" },
  { value = "DOWN", label = "Down" },
  { value = "UP", label = "Up" },
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

local activeGlowStyleValues = {
  { value = "NONE", label = "None" },
  { value = "INNER_GLOW", label = "Inner Glow" },
  { value = "OUTER_GLOW", label = "Outer Glow" },
  { value = "ACTIVE_DURATION", label = "Active Duration" },
}

local function GetSelectedTrigger(aura)
  if not aura or type(aura.triggers) ~= "table" or #aura.triggers == 0 then
    return {}
  end
  local index = tonumber(ns.db and ns.db.ui and ns.db.ui.selectedTriggerIndex or 1) or 1
  index = math.max(1, math.min(index, #aura.triggers))
  return aura.triggers[index] or aura.triggers[1] or {}
end

local function IsNameplateAura(aura)
  local trigger = GetSelectedTrigger(aura)
  return aura and aura.kind == "icon"
    and trigger.type == "aura"
    and trigger.unit == "nameplate"
end

local function UsesDualTrinketSounds(aura)
  if not aura or type(aura.triggers) ~= "table" then
    return false
  end
  for _, trigger in ipairs(aura.triggers) do
    if trigger.enabled ~= false and trigger.type == "trinket_cooldown"
      and trigger.trinketTop ~= false and trigger.trinketBottom ~= false then
      return true
    end
  end
  return false
end

local function HideAllSoundPickers(frame)
  if not SoundPicker or not frame then
    return
  end
  SoundPicker:HideIfDropdown(frame.soundFileWrap and frame.soundFileWrap.dropdown)
  SoundPicker:HideIfDropdown(frame.trinketTopSoundFileWrap and frame.trinketTopSoundFileWrap.dropdown)
  SoundPicker:HideIfDropdown(frame.trinketBottomSoundFileWrap and frame.trinketBottomSoundFileWrap.dropdown)
end

local function GetDefaultLayoutSpacing(aura)
  if aura and aura.kind == "aura_bar_list" then
    return 0
  end
  return 6
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

local function DropdownHasValue(dropdown, value)
  for _, entry in ipairs(ResolveDropdownEntries(dropdown and dropdown._values)) do
    local entryValue = GetDropdownEntryValueAndLabel(entry)
    if entryValue == value then
      return true
    end
  end
  return false
end

local function SetDropdown(dropdown, value)
  if value == "LEFT_OUTSIDE" and not DropdownHasValue(dropdown, value) then
    value = "LEFT"
  elseif value == "RIGHT_OUTSIDE" and not DropdownHasValue(dropdown, value) then
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
  Theme.StyleSurface(box, "transparent", "transparent")
  box.insetLeft = 0
  box.insetRight = 0
  box:SetPoint("TOPLEFT", box.insetLeft, y)
  box:SetPoint("TOPRIGHT", -box.insetRight, y)
  box:SetHeight(height)

  box.header = CreateFrame("Frame", nil, box, "BackdropTemplate")
  box.header:SetPoint("TOPLEFT", 1, -1)
  box.header:SetPoint("TOPRIGHT", -1, -1)
  box.header:SetHeight(30)
  Theme.StyleSurface(box.header, "surfaceRaised", "border")
  box.header:Hide()

  box.chevron = box.header:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(box.chevron, 12, "OUTLINE")
  box.chevron:SetPoint("LEFT", 10, 0)
  box.chevron:SetText("")
  box.chevron:Hide()
  Theme.SetText(box.chevron, "textAccent")

  box.title = Frames.CreateLabel(box.header, title, "GameFontNormal")
  box.title:SetPoint("LEFT", 14, 0)
  Theme.SetText(box.title, "text")

  box.bodyTop = box:CreateTexture(nil, "BORDER")
  box.bodyTop:SetTexture("Interface\\Buttons\\WHITE8x8")
  Theme.SetTexture(box.bodyTop, "borderStrong")
  box.bodyTop:SetPoint("TOPLEFT", box.header, "BOTTOMLEFT", 0, -1)
  box.bodyTop:SetPoint("TOPRIGHT", box.header, "BOTTOMRIGHT", 0, -1)
  box.bodyTop:SetHeight(1)
  box.bodyTop:Hide()
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
  Theme.SetBackdrop(widget.button, "control", "border")

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

local function CommitBlizzardSpellAlertOverride(input, aura)
  local value = CommitString(input)
  local numericValue = tonumber(value)
  aura.display.blizzardSpellAlertSpellId = 0
  aura.display.blizzardSpellAlertSpellName = ""

  if value == "" or value == "0" then
    return nil, nil
  end

  local spellId, resolvedName, error = 0, value, nil
  if Spells and Spells.ResolveSpellReference then
    spellId, resolvedName, error = Spells:ResolveSpellReference(value)
  end
  if spellId and spellId > 0 then
    aura.display.blizzardSpellAlertSpellId = spellId
    if numericValue then
      local liveName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId) or nil
      aura.display.blizzardSpellAlertSpellName = liveName or ""
    else
      aura.display.blizzardSpellAlertSpellName = resolvedName or value
    end
    return spellId, nil
  end

  aura.display.blizzardSpellAlertSpellName = value
  return 0, error or "Spell name not found in your spellbook."
end

local function GetBlizzardSpellAlertOverrideText(aura)
  local display = aura and aura.display or {}
  local spellId = tonumber(display.blizzardSpellAlertSpellId or 0) or 0
  local configuredName = tostring(display.blizzardSpellAlertSpellName or "")
  if spellId > 0 then
    local syntheticName = "Spell " .. tostring(spellId)
    if configuredName ~= "" and configuredName ~= syntheticName then
      return configuredName
    end
    return tostring(spellId)
  end

  if configuredName ~= "" then
    return configuredName
  end

  return ""
end

local function GetBlizzardSpellAlertHint(aura)
  local display = aura and aura.display or {}
  local spellId = tonumber(display.blizzardSpellAlertSpellId or 0) or 0
  local spellName = tostring(display.blizzardSpellAlertSpellName or "")
  if spellId > 0 then
    local liveName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId) or nil
    local label = spellName ~= "" and spellName or liveName or ("Spell ID " .. tostring(spellId))
    return string.format(
      "|cff88ff88Suppressing Blizzard spell alert:|r %s (%d)\n|cffaaaaaaThis override applies from load rules even if the aura itself never shows. Use a Simple trigger set to Never if you want a controller-only aura.|r",
      label,
      spellId
    )
  end

  if spellName ~= "" then
    return string.format(
      "|cffff8888Spell alert target unresolved:|r %s\n|cffaaaaaaEnter a spell name from your spellbook or a numeric spell ID. If this proc also exists as a player buff, trigger it once while the editor is open and PopAuras can learn the spell ID from your current aura. Use a Simple trigger set to Never if you want this aura to stay hidden and act only as a controller.|r",
      spellName
    )
  end

  return "|cffaaaaaaSelect a spell name or spell ID to suppress that Blizzard spell alert while this aura is loaded. This override applies from load rules even if the aura itself never shows. Use a Simple trigger set to Never if you want a hidden controller-only aura.|r"
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
  local aura = self:GetSelectedAura()
  local kind = aura and aura.kind or ""
  local isGroup = kind == "group" or kind == "dynamic_group"
  local isText = aura and aura.kind == "text"
  local isIconAura = aura and aura.kind == "icon"
  local isAuraBarList = aura and aura.kind == "aura_bar_list"
  local isNameplateAura = IsNameplateAura(aura)
  local showIcon = frame.showIconCheck:GetChecked() == true
  local matchBarSize = frame.iconMatchSizeCheck and frame.iconMatchSizeCheck:GetChecked() == true
  local showName = frame.nameControls.showCheck:GetChecked() == true
  local showTimer = frame.timerControls.showCheck:GetChecked() == true
  local showStacks = frame.stacksControls.showCheck:GetChecked() == true
  local showBackground = frame.showBackgroundCheck:GetChecked() == true
  local readyLook = frame.readyLookCheck:GetChecked() == true
  local trigger = GetSelectedTrigger(aura)
  local supportsNoStacksColor = trigger and trigger.type == "spell_cooldown" and kind == "bar"
  local supportsActiveGlowStyle = trigger and trigger.type == "spell_cooldown" and kind == "bar"
  local supportsShowAlways = trigger and (trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "trinket_cooldown" or trigger.type == "aura")
  local showIconCooldownControls = not isGroup and not isText and isIconAura and frame.iconSection.collapsed ~= true
  local showRaidFrameSection = not isGroup and not isText and isIconAura and frame.raidFrameSection:IsShown()
  local showRaidFrameControls = showRaidFrameSection and frame.showOnRaidFramesCheck:GetChecked() == true and frame.raidFrameSection.collapsed ~= true
  local soundEnabled = frame.soundEnabledCheck:GetChecked() == true
  local dualTrinketSounds = UsesDualTrinketSounds(aura)
  local showSoundBody = not isGroup and not isAuraBarList and frame.soundSection.collapsed ~= true
  local blizzardSpellAlertEnabled = frame.hideBlizzardSpellAlertCheck and frame.hideBlizzardSpellAlertCheck:GetChecked() == true

  SetControlGroupEnabled({
    frame.barColorWrap.button, frame.barColorWrap.label,
    frame.readyLookCheck,
    frame.showAlwaysReadyCheck,
    frame.readyColorWrap.button, frame.readyColorWrap.label,
    frame.barTextureWrap.dropdown, frame.barTextureWrap.label,
  }, not isGroup and not isText)
  SetControlGroupEnabled({ frame.glowWhenActiveCheck }, not isGroup and not isText and not isAuraBarList and not supportsActiveGlowStyle)
  SetControlGroupEnabled({ frame.activeGlowStyleWrap.label, frame.activeGlowStyleWrap.dropdown }, supportsActiveGlowStyle)
  SetControlGroupEnabled({ frame.showBackgroundCheck }, true)
  SetControlGroupEnabled({ frame.readyColorWrap.button, frame.readyColorWrap.label }, not isGroup and not isText and readyLook)
  SetControlGroupEnabled({ frame.noStacksBarColorCheck }, supportsNoStacksColor)
  SetControlGroupEnabled({ frame.noStacksBarColorWrap.button, frame.noStacksBarColorWrap.label },
    supportsNoStacksColor and frame.noStacksBarColorCheck:GetChecked() == true)
  SetControlGroupEnabled({ frame.showAlwaysReadyCheck }, not isGroup and not isText and supportsShowAlways)
  SetControlGroupEnabled({ frame.backgroundColorWrap.button, frame.backgroundColorWrap.label }, showBackground)
  SetControlGroupEnabled({ frame.backgroundGammaWrap.input, frame.backgroundGammaWrap.label }, showBackground and isAuraBarList)
  SetControlGroupEnabled({ frame.permanentAlphaWrap.input, frame.permanentAlphaWrap.label }, isAuraBarList)
  SetControlGroupEnabled({ frame.auraListSwipeCheck }, isAuraBarList)
  SetControlGroupEnabled({ frame.reverseCheck }, not isGroup and not isText)

  SetControlGroupEnabled({
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

  SetControlGroupEnabled({ frame.showOnRaidFramesCheck }, showRaidFrameSection)
  SetControlGroupEnabled({
    frame.raidFrameGlowCheck,
    frame.raidFrameDurationCheck,
    frame.raidFrameStacksCheck,
    frame.raidFrameSizeWrap.input, frame.raidFrameSizeWrap.label,
    frame.raidFrameAnchorWrap.dropdown, frame.raidFrameAnchorWrap.label,
    frame.raidFrameGrowthWrap.dropdown, frame.raidFrameGrowthWrap.label,
    frame.raidFrameXWrap.input, frame.raidFrameXWrap.label,
    frame.raidFrameYWrap.input, frame.raidFrameYWrap.label,
    frame.raidFrameHint,
  }, showRaidFrameControls)

  SetControlGroupEnabled({
    frame.nameControls.fontWrap.dropdown, frame.nameControls.fontWrap.label,
    frame.nameControls.sizeWrap.input, frame.nameControls.sizeWrap.label,
    frame.nameControls.rotationWrap.dropdown, frame.nameControls.rotationWrap.label,
    frame.nameControls.anchorWrap.dropdown, frame.nameControls.anchorWrap.label,
    frame.nameControls.xWrap.input, frame.nameControls.xWrap.label,
    frame.nameControls.yWrap.input, frame.nameControls.yWrap.label,
    frame.nameControls.colorWrap.button, frame.nameControls.colorWrap.label,
  }, showName and not isGroup)
  SetControlGroupShown({
    frame.nameControls.altNameWrap.input, frame.nameControls.altNameWrap.label,
  }, not isAuraBarList and not isNameplateAura)
  SetControlGroupEnabled({
    frame.nameControls.altNameWrap.input, frame.nameControls.altNameWrap.label,
  }, showName and not isGroup and not isAuraBarList and not isNameplateAura)

  SetControlGroupEnabled({
    frame.timerControls.fontWrap.dropdown, frame.timerControls.fontWrap.label,
    frame.timerControls.sizeWrap.input, frame.timerControls.sizeWrap.label,
    frame.timerControls.rotationWrap.dropdown, frame.timerControls.rotationWrap.label,
    frame.timerControls.anchorWrap.dropdown, frame.timerControls.anchorWrap.label,
    frame.timerControls.xWrap.input, frame.timerControls.xWrap.label,
    frame.timerControls.yWrap.input, frame.timerControls.yWrap.label,
    frame.timerControls.colorWrap.button, frame.timerControls.colorWrap.label,
    frame.timerControls.decimalsWrap.dropdown, frame.timerControls.decimalsWrap.label,
  }, showTimer and not isGroup and not isText)
  SetControlGroupEnabled({ frame.timerControls.hideReadyCheck },
    showTimer and not isGroup and not isText and not isAuraBarList and not isNameplateAura)

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
    frame.soundReadyCheck,
    frame.soundFileButton, frame.soundFileWrap.label,
    frame.trinketTopSoundFileButton, frame.trinketTopSoundFileWrap.label,
    frame.trinketBottomSoundFileButton, frame.trinketBottomSoundFileWrap.label,
    frame.soundChannelWrap.dropdown, frame.soundChannelWrap.label,
  }, soundEnabled and not isGroup and not isAuraBarList)
  SetControlGroupShown({
    frame.soundFileButton, frame.soundFileWrap.label,
  }, showSoundBody and not dualTrinketSounds)
  SetControlGroupShown({
    frame.trinketTopSoundFileButton, frame.trinketTopSoundFileWrap.label,
    frame.trinketBottomSoundFileButton, frame.trinketBottomSoundFileWrap.label,
  }, showSoundBody and dualTrinketSounds)
  SetControlGroupEnabled({
    frame.blizzardSpellAlertWrap.input,
    frame.blizzardSpellAlertWrap.label,
    frame.blizzardSpellAlertHint,
  }, blizzardSpellAlertEnabled and not isGroup)
  if not soundEnabled or isGroup or isAuraBarList then
    HideAllSoundPickers(frame)
  elseif dualTrinketSounds and SoundPicker then
    SoundPicker:HideIfDropdown(frame.soundFileWrap.dropdown)
  elseif SoundPicker then
    SoundPicker:HideIfDropdown(frame.trinketTopSoundFileWrap.dropdown)
    SoundPicker:HideIfDropdown(frame.trinketBottomSoundFileWrap.dropdown)
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
  local isAuraBarList = aura.kind == "aura_bar_list"
  local isNameplateAura = IsNameplateAura(aura)

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
  if isNameplateAura then
    Anchors.ApplyNameplateAnchor(
      aura.position,
      UIDropDownMenu_GetSelectedValue(frame.nameplateAnchorWrap.dropdown)
        or Anchors.GetNameplateAnchor(aura.position)
    )
  else
    aura.position.relativeTo = UIDropDownMenu_GetSelectedValue(frame.anchorWrap.dropdown) or aura.position.relativeTo or "UIParent"
    aura.position.point = UIDropDownMenu_GetSelectedValue(frame.framePointWrap.dropdown) or aura.position.point or "CENTER"
    aura.position.relativePoint = UIDropDownMenu_GetSelectedValue(frame.parentPointWrap.dropdown) or aura.position.relativePoint or "CENTER"
  end
  aura.display.frameStrata = UIDropDownMenu_GetSelectedValue(frame.strataWrap.dropdown) or aura.display.frameStrata or "MEDIUM"
  aura.display.frameLevel = CommitNumeric(frame.levelWrap.input, aura.display.frameLevel or 1)
  aura.display.orientation = newOrientation
  aura.display.color = Colors.Copy(frame.barColorWrap.color or aura.display.color)
  aura.display.alpha = aura.display.color.a
  aura.display.noStacksBarColorEnabled = frame.noStacksBarColorCheck:GetChecked() == true
  aura.display.noStacksBarColor = Colors.Copy(frame.noStacksBarColorWrap.color
    or aura.display.noStacksBarColor or { r = 0.86, g = 0.18, b = 0.18, a = 1 })
  local trigger = GetSelectedTrigger(aura)
  aura.display.readyLook = frame.readyLookCheck:GetChecked() == true
  if trigger.type == "spell_cooldown" and aura.kind == "bar" then
    local style = UIDropDownMenu_GetSelectedValue(frame.activeGlowStyleWrap.dropdown) or aura.display.activeGlowStyle or "NONE"
    aura.display.activeGlowStyle = style
    aura.display.glowWhenActive = style ~= "NONE"
  else
    aura.display.glowWhenActive = frame.glowWhenActiveCheck:GetChecked() == true
  end
  if trigger and (trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "trinket_cooldown" or trigger.type == "aura") then
    trigger.showAlways = frame.showAlwaysReadyCheck:GetChecked() == true
  end
  aura.display.readyColor = Colors.Copy(frame.readyColorWrap.color or aura.display.readyColor or aura.display.color)
  local selectedBarTexture = UIDropDownMenu_GetSelectedValue(frame.barTextureWrap.dropdown) or aura.display.barTexture or "FLAT"
  aura.display.barTexture = NormalizeBarTextureValue(selectedBarTexture)
  aura.display.showBackground = frame.showBackgroundCheck:GetChecked() == true
  aura.display.backgroundColor = Colors.Copy(frame.backgroundColorWrap.color or aura.display.backgroundColor)
  aura.display.backgroundGamma = CommitNumeric(frame.backgroundGammaWrap.input, aura.display.backgroundGamma or 1)
  aura.display.permanentAlpha = math.max(0, math.min(1, CommitNumeric(frame.permanentAlphaWrap.input, aura.display.permanentAlpha or 0.25)))
  frame.permanentAlphaWrap.input:SetText(string.format("%.2f", aura.display.permanentAlpha))
  if isAuraBarList then
    aura.display.swipe = frame.auraListSwipeCheck:GetChecked() == true
  end

  aura.display.spacing = CommitNumeric(frame.groupSpacingWrap.input, aura.display.spacing or GetDefaultLayoutSpacing(aura))
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
  aura.display.showOnRaidFrames = frame.showOnRaidFramesCheck:GetChecked() == true
  aura.display.raidFrameIconSize = CommitInteger(frame.raidFrameSizeWrap.input, aura.display.raidFrameIconSize or 18)
  aura.display.raidFrameAnchor = UIDropDownMenu_GetSelectedValue(frame.raidFrameAnchorWrap.dropdown) or aura.display.raidFrameAnchor or "BOTTOM"
  aura.display.raidFrameGrowth = UIDropDownMenu_GetSelectedValue(frame.raidFrameGrowthWrap.dropdown) or aura.display.raidFrameGrowth or "AUTO"
  aura.display.raidFrameOffsetX = CommitNumeric(frame.raidFrameXWrap.input, aura.display.raidFrameOffsetX or 0)
  aura.display.raidFrameOffsetY = CommitNumeric(frame.raidFrameYWrap.input, aura.display.raidFrameOffsetY or 11)
  aura.display.raidFrameShowGlow = frame.raidFrameGlowCheck:GetChecked() == true
  aura.display.raidFrameShowDuration = frame.raidFrameDurationCheck:GetChecked() == true
  aura.display.raidFrameShowStacks = frame.raidFrameStacksCheck:GetChecked() == true

  aura.text = aura.text or {}
  aura.text.nameOverride = isAuraBarList and "" or CommitString(frame.nameControls.altNameWrap.input)

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
  aura.display.soundMode = frame.soundReadyCheck:GetChecked() and "ready" or "activate"
  aura.display.soundFile = UIDropDownMenu_GetSelectedValue(frame.soundFileWrap.dropdown) or aura.display.soundFile or "None"
  aura.display.trinketTopSoundFile = UIDropDownMenu_GetSelectedValue(frame.trinketTopSoundFileWrap.dropdown) or aura.display.trinketTopSoundFile or "None"
  aura.display.trinketBottomSoundFile = UIDropDownMenu_GetSelectedValue(frame.trinketBottomSoundFileWrap.dropdown) or aura.display.trinketBottomSoundFile or "None"
  aura.display.soundChannel = UIDropDownMenu_GetSelectedValue(frame.soundChannelWrap.dropdown) or aura.display.soundChannel or "Master"
  aura.display.hideBlizzardSpellAlert = frame.hideBlizzardSpellAlertCheck:GetChecked() == true
  CommitBlizzardSpellAlertOverride(frame.blizzardSpellAlertWrap.input, aura)

  if aura.kind == "text" then
    aura.display.icon = false
    aura.display.showTimer = false
    aura.display.showStacks = false
    aura.display.reverse = false
    aura.display.nameAnchor = UIDropDownMenu_GetSelectedValue(frame.nameControls.anchorWrap.dropdown) or aura.display.nameAnchor or "CENTER"
  elseif aura.kind == "aura_bar_list" then
    aura.display.glowWhenActive = false
    aura.display.hideReadyTimer = false
    aura.display.iconOverrideId = 0
    aura.display.iconOverrideName = ""
    aura.display.hideCDMIcon = false
    aura.display.iconCooldownEdge = false
    aura.display.iconCooldownBling = false
    aura.display.soundEnabled = false
    aura.text.nameOverride = ""
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
  Theme.StyleScrollFrame(frame.scroll)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(724, 1820)
  frame.scroll:SetScrollChild(frame.content)
  frame:SetScript("OnSizeChanged", function(selfFrame, width)
    frame.content:SetWidth(math.max(724, (tonumber(width) or selfFrame:GetWidth() or 0) - 28))
    if Panel.frame == frame and frame.sectionEntries then
      Panel:LayoutSectionTabs()
      Panel:LayoutSections()
    end
  end)

  frame.summary = Frames.CreateLabel(frame.content, "", "GameFontHighlight")
  frame.summary:SetPoint("TOPLEFT", 16, -10)
  frame.summary:SetTextColor(0.87, 0.91, 1)
  frame.summary:Hide()

  frame.hint = Frames.CreateLabel(frame.content, "Placement and appearance for the selected aura.", "GameFontDisableSmall")
  frame.hint:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -2)
  frame.hint:Hide()

  frame.canvasSection = CreateSection(frame.content, "Look", -36, 480)
  frame.canvasSection.expandedHeightAura = 520
  frame.canvasSection.expandedHeightGroup = 352
  frame.canvasSection.expandedHeightNameplate = 270
  frame.groupSection = CreateSection(frame.content, "Group Layout", -396, 132)
  frame.iconSection = CreateSection(frame.content, "Icon", -560, 270)
  frame.raidFrameSection = CreateSection(frame.content, "Raid Frames", -846, 236)
  frame.nameSection = CreateSection(frame.content, "Name Text", -1050, 290)
  frame.timerSection = CreateSection(frame.content, "Duration Text", -1356, 260)
  frame.stacksSection = CreateSection(frame.content, "Stacks Text", -1632, 220)
  frame.soundSection = CreateSection(frame.content, "Sound", -1868, 164)
  frame.blizzardSection = CreateSection(frame.content, "Blizzard UI", -2048, 176)

  frame.sectionEntries = {
    { key = "canvas", label = "Look", section = frame.canvasSection },
    { key = "group", label = "Layout", section = frame.groupSection },
    { key = "icon", label = "Icon", section = frame.iconSection },
    { key = "raidFrames", label = "Raid", section = frame.raidFrameSection },
    { key = "name", label = "Name", section = frame.nameSection },
    { key = "timer", label = "Duration", section = frame.timerSection },
    { key = "stacks", label = "Stacks", section = frame.stacksSection },
    { key = "sound", label = "Sound", section = frame.soundSection },
    { key = "blizzard", label = "Blizzard", section = frame.blizzardSection },
  }
  frame.sectionTabs = {}
  for _, entry in ipairs(frame.sectionEntries) do
    entry.section._popAurasAvailable = true
    entry.section._popAurasSectionKey = entry.key
    entry.section.header:EnableMouse(false)
    local sectionKey = entry.key
    local tab = Frames.CreateButton(frame.content, entry.label, 80, 32, function()
      Panel:SetActiveSection(sectionKey)
      Panel:UpdateControlStates()
    end)
    Fonts.Apply(tab:GetFontString(), 11, "")
    Theme.StyleTab(tab, false)
    frame.sectionTabs[entry.key] = tab
  end

  frame.nameInputWrap = CreateLabeledInput(frame.canvasSection, "Aura Name", 12, -34, 420)
  frame.widthWrap = CreateLabeledInput(frame.canvasSection, "Width", 12, -88, 60)
  frame.heightWrap = CreateLabeledInput(frame.canvasSection, "Height", 96, -88, 60)
  frame.xWrap = CreateLabeledInput(frame.canvasSection, "Offset X", 180, -88, 84)
  frame.yWrap = CreateLabeledInput(frame.canvasSection, "Offset Y", 280, -88, 84)
  frame.orientationWrap = CreateLabeledDropdown(frame.canvasSection, "Orientation", 380, -88, 160, { "HORIZONTAL", "VERTICAL" })
  frame.framePointWrap = CreateLabeledDropdown(frame.canvasSection, "Frame Point", 240, -150, 170, Anchors.GetPointList)
  frame.parentPointWrap = CreateLabeledDropdown(frame.canvasSection, "Parent Point", 460, -150, 170, Anchors.GetPointList)

  frame.anchorWrap = CreateLabeledDropdown(frame.canvasSection, "Anchor / Parent", 12, -150, 200, Anchors.GetTargetList)
  frame.nameplateAnchorWrap = CreateLabeledDropdown(
    frame.canvasSection, "Nameplate Anchor", 380, -88, 180, Anchors.GetNameplateAnchorList)
  frame.strataWrap = CreateLabeledDropdown(frame.canvasSection, "Strata", 12, -212, 150, strataValues)
  frame.levelWrap = CreateLabeledInput(frame.canvasSection, "Level", 200, -212, 58)

  frame.barColorWrap = CreateColorSwatch(frame.canvasSection, "Bar Color", 12, -284)
  frame.readyLookCheck = Frames.CreateCheckbox(frame.canvasSection, "Style Ready State")
  frame.readyLookCheck:SetPoint("TOPLEFT", 12, -336)
  frame.glowWhenActiveCheck = Frames.CreateCheckbox(frame.canvasSection, "Glow When Active")
  frame.glowWhenActiveCheck:SetPoint("TOPLEFT", 180, -336)
  frame.activeGlowStyleWrap = CreateLabeledDropdown(frame.canvasSection, "Glow When Active", 180, -324, 155, activeGlowStyleValues)
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
  frame.backgroundGammaWrap = CreateLabeledInput(frame.canvasSection, "Background Gamma", 430, -364, 70)
  frame.permanentAlphaWrap = CreateLabeledInput(frame.canvasSection, "Permanent Aura Alpha", 540, -364, 70)
  frame.auraListSwipeCheck = Frames.CreateCheckbox(
    frame.canvasSection, "Show Cooldown Swipe")
  frame.auraListSwipeCheck:SetPoint("TOPLEFT", 12, -412)
  frame.noStacksBarColorCheck = Frames.CreateCheckbox(frame.canvasSection, "No Stacks Bar Color")
  frame.noStacksBarColorCheck:SetPoint("TOPLEFT", 12, -412)
  frame.noStacksBarColorWrap = CreateColorSwatch(frame.canvasSection, "Color", 220, -404)
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
  frame.reverseCheck = Frames.CreateCheckbox(frame.canvasSection, "Drain / Reverse Fill")
  frame.reverseCheck:SetPoint("TOPLEFT", 540, -336)
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

  frame.showOnRaidFramesCheck = Frames.CreateCheckbox(frame.raidFrameSection, "Show on Raid Frames")
  frame.showOnRaidFramesCheck:SetPoint("TOPLEFT", 12, -34)
  frame.raidFrameGlowCheck = Frames.CreateCheckbox(frame.raidFrameSection, "Glow")
  frame.raidFrameGlowCheck:SetPoint("TOPLEFT", 200, -34)
  frame.raidFrameDurationCheck = Frames.CreateCheckbox(frame.raidFrameSection, "Duration")
  frame.raidFrameDurationCheck:SetPoint("TOPLEFT", 284, -34)
  frame.raidFrameStacksCheck = Frames.CreateCheckbox(frame.raidFrameSection, "Stacks")
  frame.raidFrameStacksCheck:SetPoint("TOPLEFT", 392, -34)
  frame.raidFrameSizeWrap = CreateLabeledInput(frame.raidFrameSection, "Icon Size", 12, -86, 54)
  frame.raidFrameAnchorWrap = CreateLabeledDropdown(frame.raidFrameSection, "Anchor", 110, -86, 170, raidFrameAnchorValues)
  frame.raidFrameGrowthWrap = CreateLabeledDropdown(frame.raidFrameSection, "Grow", 320, -86, 140, raidFrameGrowthValues)
  frame.raidFrameXWrap = CreateLabeledInput(frame.raidFrameSection, "Offset X", 12, -148, 60)
  frame.raidFrameYWrap = CreateLabeledInput(frame.raidFrameSection, "Offset Y", 112, -148, 60)
  frame.raidFrameHint = Frames.CreateLabel(frame.raidFrameSection, "Places compact aura icons on detected party or raid unit frames without rebuilding them every refresh. Anchor and offsets are applied per unit frame.", "GameFontDisableSmall")
  frame.raidFrameHint:SetPoint("TOPLEFT", 12, -204)
  frame.raidFrameHint:SetWidth(660)

  frame.soundEnabledCheck = Frames.CreateCheckbox(frame.soundSection, "Play Aura Sound")
  frame.soundEnabledCheck:SetPoint("TOPLEFT", 12, -34)
  frame.soundReadyCheck = Frames.CreateCheckbox(frame.soundSection, "Play On Ready")
  frame.soundReadyCheck:SetPoint("LEFT", frame.soundEnabledCheck.Text, "RIGHT", 28, 0)
  frame.soundFileWrap = CreateLabeledDropdown(frame.soundSection, "Sound", 12, -68, 460, GetSoundDropdownValues)
  frame.soundFileWrap.dropdown:Hide()
  frame.soundFileButton = Frames.CreateSelectorButton(frame.soundSection, 446, 24)
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
  frame.trinketTopSoundFileWrap = CreateLabeledDropdown(frame.soundSection, "Trinket 1 (Top)", 12, -68, 460, GetSoundDropdownValues)
  frame.trinketTopSoundFileWrap.dropdown:Hide()
  frame.trinketTopSoundFileButton = Frames.CreateSelectorButton(frame.soundSection, 446, 24)
  frame.trinketTopSoundFileButton:SetPoint("TOPLEFT", frame.trinketTopSoundFileWrap.label, "BOTTOMLEFT", 0, -6)
  frame.trinketTopSoundFileButton:SetScript("OnClick", function()
    if not SoundPicker then
      return
    end
    SoundPicker:Toggle(frame.trinketTopSoundFileButton, frame.trinketTopSoundFileWrap.dropdown, GetSoundDropdownValues, {
      title = "Select Trinket 1 Sound",
      onChanged = function()
        UpdateSelectorButtonText(frame.trinketTopSoundFileButton, frame.trinketTopSoundFileWrap.dropdown)
        Panel:ApplyCurrent()
      end,
      channelProvider = function()
        return UIDropDownMenu_GetSelectedValue(frame.soundChannelWrap.dropdown) or "Master"
      end,
    })
  end)
  frame.trinketBottomSoundFileWrap = CreateLabeledDropdown(frame.soundSection, "Trinket 2 (Bottom)", 12, -130, 460, GetSoundDropdownValues)
  frame.trinketBottomSoundFileWrap.dropdown:Hide()
  frame.trinketBottomSoundFileButton = Frames.CreateSelectorButton(frame.soundSection, 446, 24)
  frame.trinketBottomSoundFileButton:SetPoint("TOPLEFT", frame.trinketBottomSoundFileWrap.label, "BOTTOMLEFT", 0, -6)
  frame.trinketBottomSoundFileButton:SetScript("OnClick", function()
    if not SoundPicker then
      return
    end
    SoundPicker:Toggle(frame.trinketBottomSoundFileButton, frame.trinketBottomSoundFileWrap.dropdown, GetSoundDropdownValues, {
      title = "Select Trinket 2 Sound",
      onChanged = function()
        UpdateSelectorButtonText(frame.trinketBottomSoundFileButton, frame.trinketBottomSoundFileWrap.dropdown)
        Panel:ApplyCurrent()
      end,
      channelProvider = function()
        return UIDropDownMenu_GetSelectedValue(frame.soundChannelWrap.dropdown) or "Master"
      end,
    })
  end)
  frame.soundChannelWrap = CreateLabeledDropdown(frame.soundSection, "Channel", 488, -68, 150, GetSoundChannelDropdownValues)
  frame.soundHint = Frames.CreateLabel(frame.soundSection, "Choose whether the sound plays when the aura activates or when it becomes ready/off cooldown. The picker is scrollable and color-codes sounds by source pack. Use %m in text auras if you want the matched chat message rendered.", "GameFontDisableSmall")
  frame.soundHint:SetPoint("TOPLEFT", 12, -146)
  frame.soundHint:SetWidth(720)

  frame.hideBlizzardSpellAlertCheck = Frames.CreateCheckbox(frame.blizzardSection, "Hide Blizzard Spell Alert")
  frame.hideBlizzardSpellAlertCheck:SetPoint("TOPLEFT", 12, -34)
  frame.blizzardSpellAlertWrap = CreateLabeledInput(frame.blizzardSection, "Spell Name or ID", 12, -70, 280)
  frame.blizzardSpellAlertHint = Frames.CreateLabel(frame.blizzardSection, "", "GameFontDisableSmall")
  frame.blizzardSpellAlertHint:SetPoint("TOPLEFT", 12, -132)
  frame.blizzardSpellAlertHint:SetWidth(700)
  frame.blizzardSpellAlertHint:SetJustifyH("LEFT")

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
    frame.nameplateAnchorWrap.label, frame.nameplateAnchorWrap.dropdown,
    frame.strataWrap.label, frame.strataWrap.dropdown,
    frame.levelWrap.label, frame.levelWrap.input,
    frame.barColorWrap.label, frame.barColorWrap.button, frame.barColorWrap.valueText,
    frame.noStacksBarColorCheck,
    frame.noStacksBarColorWrap.label, frame.noStacksBarColorWrap.button, frame.noStacksBarColorWrap.valueText,
    frame.readyLookCheck,
    frame.glowWhenActiveCheck,
    frame.activeGlowStyleWrap.label, frame.activeGlowStyleWrap.dropdown,
    frame.showAlwaysReadyCheck,
    frame.reverseCheck,
    frame.readyColorWrap.label, frame.readyColorWrap.button, frame.readyColorWrap.valueText,
    frame.barTextureWrap.label, frame.barTextureWrap.dropdown,
    frame.showBackgroundCheck,
    frame.backgroundColorWrap.label, frame.backgroundColorWrap.button, frame.backgroundColorWrap.valueText,
    frame.backgroundGammaWrap.label, frame.backgroundGammaWrap.input,
    frame.permanentAlphaWrap.label, frame.permanentAlphaWrap.input,
    frame.auraListSwipeCheck
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
    frame.showIconCheck, frame.hideCDMIconCheck, frame.iconEdgeCheck, frame.iconFinishFlashCheck, frame.iconMatchSizeCheck,
    frame.iconSizeWrap.label, frame.iconSizeWrap.input,
    frame.iconAnchorWrap.label, frame.iconAnchorWrap.dropdown,
    frame.altIconIdWrap.label, frame.altIconIdWrap.input,
    frame.iconXWrap.label, frame.iconXWrap.input,
    frame.iconYWrap.label, frame.iconYWrap.input,
    frame.iconSwipeColorWrap.label, frame.iconSwipeColorWrap.button, frame.iconSwipeColorWrap.valueText,
    frame.iconHint
  )
  RegisterSectionWidgets(frame.raidFrameSection,
    frame.showOnRaidFramesCheck,
    frame.raidFrameGlowCheck,
    frame.raidFrameDurationCheck,
    frame.raidFrameStacksCheck,
    frame.raidFrameSizeWrap.label, frame.raidFrameSizeWrap.input,
    frame.raidFrameAnchorWrap.label, frame.raidFrameAnchorWrap.dropdown,
    frame.raidFrameGrowthWrap.label, frame.raidFrameGrowthWrap.dropdown,
    frame.raidFrameXWrap.label, frame.raidFrameXWrap.input,
    frame.raidFrameYWrap.label, frame.raidFrameYWrap.input,
    frame.raidFrameHint
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
    frame.soundReadyCheck,
    frame.soundFileWrap.label, frame.soundFileButton,
    frame.trinketTopSoundFileWrap.label, frame.trinketTopSoundFileButton,
    frame.trinketBottomSoundFileWrap.label, frame.trinketBottomSoundFileButton,
    frame.soundChannelWrap.label, frame.soundChannelWrap.dropdown,
    frame.soundHint
  )
  RegisterSectionWidgets(frame.blizzardSection,
    frame.hideBlizzardSpellAlertCheck,
    frame.blizzardSpellAlertWrap.label, frame.blizzardSpellAlertWrap.input,
    frame.blizzardSpellAlertHint
  )
  frame.saveButton = Frames.CreateButton(frame.content, "Save", 150, 28, function()
    Panel:ApplyCurrent()
  end)
  Frames.StylePrimaryButton(frame.saveButton)
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
  ConfigureNumericInput(frame.raidFrameSizeWrap.input, 3)
  ConfigureNumericInput(frame.raidFrameXWrap.input, 10)
  ConfigureNumericInput(frame.raidFrameYWrap.input, 10)
  ConfigureNumericInput(frame.backgroundGammaWrap.input, 5)
  ConfigureNumericInput(frame.permanentAlphaWrap.input, 5)
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
    frame.raidFrameSection,
    frame.nameSection,
    frame.timerSection,
    frame.stacksSection,
    frame.soundSection,
    frame.blizzardSection,
  }

  self.frame = frame

  self:WireLiveInput(frame.nameInputWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.widthWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.heightWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.xWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.yWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.levelWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.backgroundGammaWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.permanentAlphaWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.blizzardSpellAlertWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.groupSpacingWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.iconSizeWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.altIconIdWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.iconXWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.iconYWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.raidFrameSizeWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.raidFrameXWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.raidFrameYWrap.input, function() Panel:ApplyCurrent() end)
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
  self:WireLiveCheckbox(frame.hideBlizzardSpellAlertCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.showOnRaidFramesCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.raidFrameGlowCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.raidFrameDurationCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.raidFrameStacksCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.showBackgroundCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.auraListSwipeCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.groupShowBackgroundCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.readyLookCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.noStacksBarColorCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.glowWhenActiveCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.showAlwaysReadyCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.groupMaintainOrderCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.soundEnabledCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.soundReadyCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.nameControls.showCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.timerControls.showCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.timerControls.hideReadyCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.stacksControls.showCheck, function() Panel:ApplyCurrent() end)

  InitDropdownWithCallback(frame.strataWrap.dropdown, strataValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.orientationWrap.dropdown, { "HORIZONTAL", "VERTICAL" }, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.framePointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.parentPointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.anchorWrap.dropdown, Anchors.GetTargetList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.nameplateAnchorWrap.dropdown, Anchors.GetNameplateAnchorList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.barTextureWrap.dropdown, barTextureValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.activeGlowStyleWrap.dropdown, activeGlowStyleValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.groupGrowthWrap.dropdown, { "DOWN", "UP", "RIGHT", "LEFT" }, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.iconAnchorWrap.dropdown, iconAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.raidFrameAnchorWrap.dropdown, raidFrameAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.raidFrameGrowthWrap.dropdown, raidFrameGrowthValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.soundFileWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.trinketTopSoundFileWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.trinketBottomSoundFileWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
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
  WireColor(frame.noStacksBarColorWrap, { r = 0.86, g = 0.18, b = 0.18, a = 1 })

  return frame
end

function Panel:ApplyCanvasLayout(isGroup, isNameplateAura)
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
    frame.backgroundGammaWrap.label:Hide()
    frame.backgroundGammaWrap.input:Hide()
    frame.permanentAlphaWrap.label:Hide()
    frame.permanentAlphaWrap.input:Hide()
    return
  end

  if isNameplateAura then
    PositionLabeledInput(frame.widthWrap, 12, -88)
    PositionLabeledInput(frame.heightWrap, 96, -88)
    PositionLabeledInput(frame.xWrap, 180, -88)
    PositionLabeledInput(frame.yWrap, 280, -88)
    PositionLabeledDropdown(frame.nameplateAnchorWrap, 380, -88)

    PositionLabeledDropdown(frame.strataWrap, 12, -150)
    PositionLabeledInput(frame.levelWrap, 200, -150)

    frame.showBackgroundCheck:ClearAllPoints()
    frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -212)
    PositionColorSwatch(frame.backgroundColorWrap, 220, -212)
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
  PositionLabeledDropdown(frame.activeGlowStyleWrap, 180, -324)
  frame.showAlwaysReadyCheck:ClearAllPoints()
  frame.showAlwaysReadyCheck:SetPoint("TOPLEFT", 360, -336)
  frame.reverseCheck:ClearAllPoints()
  frame.reverseCheck:SetPoint("TOPLEFT", 540, -336)

  frame.showBackgroundCheck:ClearAllPoints()
  frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -364)
  PositionColorSwatch(frame.backgroundColorWrap, 220, -364)
  PositionLabeledInput(frame.backgroundGammaWrap, 430, -364)
  PositionLabeledInput(frame.permanentAlphaWrap, 540, -364)
  frame.auraListSwipeCheck:ClearAllPoints()
  frame.auraListSwipeCheck:SetPoint("TOPLEFT", 12, -412)
  frame.noStacksBarColorCheck:ClearAllPoints()
  frame.noStacksBarColorCheck:SetPoint("TOPLEFT", 12, -412)
  PositionColorSwatch(frame.noStacksBarColorWrap, 220, -404)
end

function Panel:ApplyIconLayout(isNameplateAura)
  local frame = self.frame
  if not frame then
    return
  end

  if isNameplateAura then
    frame.iconSection.expandedHeight = 180
    frame.iconSection:SetHeight(frame.iconSection.expandedHeight)
    frame.showIconCheck:ClearAllPoints()
    frame.showIconCheck:SetPoint("TOPLEFT", 12, -34)
    frame.iconEdgeCheck:ClearAllPoints()
    frame.iconEdgeCheck:SetPoint("TOPLEFT", 180, -34)
    frame.iconFinishFlashCheck:ClearAllPoints()
    frame.iconFinishFlashCheck:SetPoint("TOPLEFT", 380, -34)
    PositionColorSwatch(frame.iconSwipeColorWrap, 12, -78)
    frame.iconHint:ClearAllPoints()
    frame.iconHint:SetPoint("TOPLEFT", 12, -126)
    return
  end

  frame.iconSection.expandedHeight = 270
  frame.iconSection:SetHeight(frame.iconSection.expandedHeight)
  frame.showIconCheck:ClearAllPoints()
  frame.showIconCheck:SetPoint("TOPLEFT", 12, -34)
  frame.iconEdgeCheck:ClearAllPoints()
  frame.iconEdgeCheck:SetPoint("TOPLEFT", 180, -64)
  frame.iconFinishFlashCheck:ClearAllPoints()
  frame.iconFinishFlashCheck:SetPoint("TOPLEFT", 380, -64)
  PositionColorSwatch(frame.iconSwipeColorWrap, 360, -158)
  frame.iconHint:ClearAllPoints()
  frame.iconHint:SetPoint("TOPLEFT", 12, -196)
end

function Panel:LayoutSectionTabs()
  if not self.frame or not self.frame.sectionEntries then
    return
  end

  local visibleEntries = {}
  for _, entry in ipairs(self.frame.sectionEntries) do
    if entry.section._popAurasAvailable ~= false then
      visibleEntries[#visibleEntries + 1] = entry
    end
  end

  local contentWidth = math.max(1, self.frame.content:GetWidth() or 724)
  local tabWidth = math.max(68, math.floor(contentWidth / math.max(1, #visibleEntries)))
  local previous
  for _, entry in ipairs(self.frame.sectionEntries) do
    local tab = self.frame.sectionTabs[entry.key]
    local available = entry.section._popAurasAvailable ~= false
    tab:SetShown(available)
    if available then
      tab:ClearAllPoints()
      tab:SetSize(tabWidth, 32)
      if previous then
        tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", 0, 0)
      else
        tab:SetPoint("TOPLEFT", 0, -2)
      end
      previous = tab
    end
  end
end

function Panel:SetActiveSection(key)
  if not self.frame or not self.frame.sectionEntries then
    return
  end

  local activeEntry
  for _, entry in ipairs(self.frame.sectionEntries) do
    if entry.key == key and entry.section._popAurasAvailable ~= false then
      activeEntry = entry
      break
    end
  end
  if not activeEntry then
    for _, entry in ipairs(self.frame.sectionEntries) do
      if entry.section._popAurasAvailable ~= false then
        activeEntry = entry
        break
      end
    end
  end
  if not activeEntry then
    return
  end

  local changed = self.frame.activeSectionKey ~= activeEntry.key
  self.frame.activeSectionKey = activeEntry.key
  for _, entry in ipairs(self.frame.sectionEntries) do
    local isActive = entry == activeEntry
    entry.section.collapsed = not isActive
    entry.section:SetShown(isActive)
    Theme.StyleTab(self.frame.sectionTabs[entry.key], isActive)
  end

  self:LayoutSectionTabs()
  self:LayoutSections()
  if changed and self.frame.scroll then
    self.frame.scroll:SetVerticalScroll(0)
  end
end

function Panel:LayoutSections()
  if not self.frame or not self.frame.sections then
    return
  end

  local y = -10
  for _, section in ipairs(self.frame.sections) do
    if section:IsShown() then
      section:ClearAllPoints()
      section:SetPoint("TOPLEFT", section.insetLeft or 0, y)
      section:SetPoint("TOPRIGHT", -(section.insetRight or 0), y)
      y = y - section:GetHeight() - 10
    end
  end
  local minHeight = self.frame:GetHeight() > 0 and self.frame:GetHeight() or 640
  self.frame.content:SetHeight(math.max(minHeight, math.abs(y) + 28))
end

function Panel:Refresh(aura)
  self.suppressUpdates = true
  local isGroup = aura.kind == "group" or aura.kind == "dynamic_group"
  local isText = aura.kind == "text"
  local isIconAura = aura.kind == "icon"
  local isAuraBarList = aura.kind == "aura_bar_list"
  local trigger = GetSelectedTrigger(aura)
  local isNameplateAura = isIconAura and trigger.type == "aura" and trigger.unit == "nameplate"
  local usesLayoutSection = isGroup or isAuraBarList or isNameplateAura
  local supportsShowAlways = not isNameplateAura and (
    trigger.type == "spell_cooldown" or trigger.type == "item_cooldown"
      or trigger.type == "trinket_cooldown" or trigger.type == "aura")

  self.frame.nameInputWrap.input:SetText(aura.name or "")
  self.frame.widthWrap.input:SetText(tostring(aura.display.width or 220))
  self.frame.heightWrap.input:SetText(tostring(aura.display.height or 32))
  self.frame.xWrap.input:SetText(tostring(aura.position.x or 0))
  self.frame.yWrap.input:SetText(tostring(aura.position.y or 0))
  RefreshDropdown(self.frame.anchorWrap.dropdown)
  RefreshDropdown(self.frame.framePointWrap.dropdown)
  RefreshDropdown(self.frame.parentPointWrap.dropdown)
  RefreshDropdown(self.frame.nameplateAnchorWrap.dropdown)
  RefreshDropdown(self.frame.soundFileWrap.dropdown)
  RefreshDropdown(self.frame.trinketTopSoundFileWrap.dropdown)
  RefreshDropdown(self.frame.trinketBottomSoundFileWrap.dropdown)
  RefreshDropdown(self.frame.soundChannelWrap.dropdown)
  SetDropdown(self.frame.strataWrap.dropdown, aura.display.frameStrata or "MEDIUM")
  self.frame.levelWrap.input:SetText(tostring(aura.display.frameLevel or 1))
  SetColorSwatch(self.frame.barColorWrap, {
    r = aura.display.color.r or 0,
    g = aura.display.color.g or 0,
    b = aura.display.color.b or 0,
    a = aura.display.color.a == nil and (aura.display.alpha or 1) or aura.display.color.a,
  })
  self.frame.noStacksBarColorCheck:SetChecked(aura.display.noStacksBarColorEnabled == true)
  SetColorSwatch(self.frame.noStacksBarColorWrap,
    aura.display.noStacksBarColor or { r = 0.86, g = 0.18, b = 0.18, a = 1 })
  self.frame.readyLookCheck:SetChecked(aura.display.readyLook == true)
  self.frame.glowWhenActiveCheck:SetChecked(aura.display.glowWhenActive == true)
  SetDropdown(self.frame.activeGlowStyleWrap.dropdown, aura.display.activeGlowStyle or "NONE")
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
  self.frame.backgroundGammaWrap.input:SetText(tostring(aura.display.backgroundGamma or 1))
  self.frame.permanentAlphaWrap.input:SetText(string.format("%.2f", tonumber(aura.display.permanentAlpha or 0.25) or 0.25))
  self.frame.auraListSwipeCheck:SetChecked(aura.display.swipe == true)

  self.frame.groupSpacingWrap.input:SetText(tostring(aura.display.spacing or GetDefaultLayoutSpacing(aura)))
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
  self.frame.showOnRaidFramesCheck:SetChecked(aura.display.showOnRaidFrames == true)
  self.frame.raidFrameGlowCheck:SetChecked(aura.display.raidFrameShowGlow == true)
  self.frame.raidFrameDurationCheck:SetChecked(aura.display.raidFrameShowDuration == true)
  self.frame.raidFrameStacksCheck:SetChecked(aura.display.raidFrameShowStacks == true)
  self.frame.raidFrameSizeWrap.input:SetText(tostring(aura.display.raidFrameIconSize or 18))
  self.frame.raidFrameXWrap.input:SetText(tostring(aura.display.raidFrameOffsetX or 0))
  self.frame.raidFrameYWrap.input:SetText(tostring(aura.display.raidFrameOffsetY or 11))
  self.frame.soundEnabledCheck:SetChecked(aura.display.soundEnabled == true)
  self.frame.hideBlizzardSpellAlertCheck:SetChecked(aura.display.hideBlizzardSpellAlert == true)
  self.frame.blizzardSpellAlertWrap.input:SetText(GetBlizzardSpellAlertOverrideText(aura))
  self.frame.blizzardSpellAlertHint:SetText(GetBlizzardSpellAlertHint(aura))

  SetDropdown(self.frame.orientationWrap.dropdown, aura.display.orientation or "HORIZONTAL")
  SetDropdown(self.frame.anchorWrap.dropdown, aura.position.relativeTo or "UIParent")
  SetDropdown(self.frame.framePointWrap.dropdown, aura.position.point or "CENTER")
  SetDropdown(self.frame.parentPointWrap.dropdown, aura.position.relativePoint or "CENTER")
  SetDropdown(self.frame.nameplateAnchorWrap.dropdown, Anchors.GetNameplateAnchor(aura.position))
  SetDropdown(self.frame.groupGrowthWrap.dropdown, aura.display.growth or "DOWN")
  SetDropdown(self.frame.iconAnchorWrap.dropdown, aura.display.iconAnchor or "LEFT")
  SetDropdown(self.frame.raidFrameAnchorWrap.dropdown, aura.display.raidFrameAnchor or "BOTTOM")
  SetDropdown(self.frame.raidFrameGrowthWrap.dropdown, aura.display.raidFrameGrowth or "AUTO")
  self.frame.soundReadyCheck:SetChecked(aura.display.soundMode == "ready")
  SetDropdown(self.frame.soundFileWrap.dropdown, aura.display.soundFile or "None")
  UpdateSelectorButtonText(self.frame.soundFileButton, self.frame.soundFileWrap.dropdown)
  SetDropdown(self.frame.trinketTopSoundFileWrap.dropdown, aura.display.trinketTopSoundFile or "None")
  UpdateSelectorButtonText(self.frame.trinketTopSoundFileButton, self.frame.trinketTopSoundFileWrap.dropdown)
  SetDropdown(self.frame.trinketBottomSoundFileWrap.dropdown, aura.display.trinketBottomSoundFile or "None")
  UpdateSelectorButtonText(self.frame.trinketBottomSoundFileButton, self.frame.trinketBottomSoundFileWrap.dropdown)
  SetDropdown(self.frame.soundChannelWrap.dropdown, aura.display.soundChannel or "Master")
  if SoundPicker then
    SoundPicker:RefreshIfOpen(self.frame.soundFileWrap.dropdown)
    SoundPicker:RefreshIfOpen(self.frame.trinketTopSoundFileWrap.dropdown)
    SoundPicker:RefreshIfOpen(self.frame.trinketBottomSoundFileWrap.dropdown)
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
  self.frame.timerControls.hideReadyCheck:SetShown(not isAuraBarList and not isNameplateAura)

  self.frame.stacksControls.showCheck:SetChecked(aura.display.showStacks == true)
  SetDropdown(self.frame.stacksControls.fontWrap.dropdown, aura.display.stacksFontStyle or "FRIZQT_OUTLINE")
  self.frame.stacksControls.sizeWrap.input:SetText(tostring(aura.display.stacksFontSize or 14))
  SetDropdown(self.frame.stacksControls.rotationWrap.dropdown, tostring(aura.display.stacksRotation or 0))
  SetDropdown(self.frame.stacksControls.anchorWrap.dropdown, aura.display.stacksAnchor or "TOPRIGHT")
  self.frame.stacksControls.xWrap.input:SetText(tostring(aura.display.stacksOffsetX or 0))
  self.frame.stacksControls.yWrap.input:SetText(tostring(aura.display.stacksOffsetY or 0))
  SetColorSwatch(self.frame.stacksControls.colorWrap, aura.display.stacksColor or { r = 1, g = 1, b = 1, a = 1 })

  self.frame.canvasSection._popAurasAvailable = true
  self.frame.groupSection._popAurasAvailable = usesLayoutSection
  self.frame.iconSection._popAurasAvailable = not isGroup and not isText
  self.frame.raidFrameSection._popAurasAvailable = false
  self.frame.nameSection._popAurasAvailable = not isGroup
  self.frame.timerSection._popAurasAvailable = not isGroup and not isText
  self.frame.stacksSection._popAurasAvailable = not isGroup and not isText
  self.frame.soundSection._popAurasAvailable = not isGroup
    and not isAuraBarList
    and not isNameplateAura
    and trigger.type ~= "death_alert"
  self.frame.blizzardSection._popAurasAvailable = not isGroup and not isNameplateAura
  if isGroup or isAuraBarList or isNameplateAura then
    HideAllSoundPickers(self.frame)
  end

  self.frame.canvasSection.expandedHeight = isGroup
      and self.frame.canvasSection.expandedHeightGroup
      or isNameplateAura
        and self.frame.canvasSection.expandedHeightNameplate
        or self.frame.canvasSection.expandedHeightAura
  self.frame.canvasSection:SetHeight(self.frame.canvasSection.expandedHeight)
  local dualTrinketSounds = UsesDualTrinketSounds(aura)
  self.frame.soundSection.expandedHeight = dualTrinketSounds and 226 or 164
  self.frame.soundHint:ClearAllPoints()
  self.frame.soundHint:SetPoint("TOPLEFT", 12, dualTrinketSounds and -208 or -146)
  self:ApplyIconLayout(isNameplateAura)

  self.frame.orientationWrap.label:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.orientationWrap.dropdown:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.anchorWrap.label:SetShown(not isNameplateAura)
  self.frame.anchorWrap.dropdown:SetShown(not isNameplateAura)
  self.frame.framePointWrap.label:SetShown(not isNameplateAura)
  self.frame.framePointWrap.dropdown:SetShown(not isNameplateAura)
  self.frame.parentPointWrap.label:SetShown(not isNameplateAura)
  self.frame.parentPointWrap.dropdown:SetShown(not isNameplateAura)
  self.frame.nameplateAnchorWrap.label:SetShown(isNameplateAura)
  self.frame.nameplateAnchorWrap.dropdown:SetShown(isNameplateAura)
  self.frame.strataWrap.label:SetShown(true)
  self.frame.strataWrap.dropdown:SetShown(true)
  self.frame.levelWrap.label:SetShown(true)
  self.frame.levelWrap.input:SetShown(true)
  self.frame.barColorWrap.label:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.barColorWrap.button:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.barColorWrap.valueText:SetShown(not isGroup and not isText and not isNameplateAura)
  local showNoStacksColor = trigger.type == "spell_cooldown" and aura.kind == "bar"
  self.frame.noStacksBarColorCheck:SetShown(showNoStacksColor)
  self.frame.noStacksBarColorWrap.label:SetShown(showNoStacksColor)
  self.frame.noStacksBarColorWrap.button:SetShown(showNoStacksColor)
  self.frame.noStacksBarColorWrap.valueText:SetShown(showNoStacksColor)
  self.frame.readyLookCheck:SetShown(not isGroup and not isText and not isNameplateAura)
  local showActiveGlowStyle = trigger.type == "spell_cooldown" and aura.kind == "bar"
  self.frame.glowWhenActiveCheck:SetShown(not isGroup and not isText and not isAuraBarList
    and not isNameplateAura and not showActiveGlowStyle)
  self.frame.activeGlowStyleWrap.label:SetShown(showActiveGlowStyle)
  self.frame.activeGlowStyleWrap.dropdown:SetShown(showActiveGlowStyle)
  self.frame.showAlwaysReadyCheck:SetShown(not isGroup and not isText and supportsShowAlways)
  self.frame.reverseCheck:SetShown(not isGroup and not isText)
  self.frame.readyColorWrap.label:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.readyColorWrap.button:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.readyColorWrap.valueText:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.barTextureWrap.label:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.barTextureWrap.dropdown:SetShown(not isGroup and not isText and not isNameplateAura)
  self.frame.showBackgroundCheck:SetShown(true)
  self.frame.backgroundColorWrap.label:SetShown(true)
  self.frame.backgroundColorWrap.button:SetShown(true)
  self.frame.backgroundColorWrap.valueText:SetShown(true)
  self.frame.backgroundGammaWrap.label:SetShown(isAuraBarList)
  self.frame.backgroundGammaWrap.input:SetShown(isAuraBarList)
  self.frame.permanentAlphaWrap.label:SetShown(isAuraBarList)
  self.frame.permanentAlphaWrap.input:SetShown(isAuraBarList)
  self.frame.auraListSwipeCheck:SetShown(isAuraBarList)
  self.frame.nameControls.altNameWrap.label:SetShown(not isAuraBarList and not isNameplateAura)
  self.frame.nameControls.altNameWrap.input:SetShown(not isAuraBarList and not isNameplateAura)
  self.frame.iconEdgeCheck:SetShown(isIconAura)
  self.frame.iconFinishFlashCheck:SetShown(isIconAura)
  self.frame.iconSwipeColorWrap.label:SetShown(isIconAura)
  self.frame.iconSwipeColorWrap.button:SetShown(isIconAura)
  self.frame.iconSwipeColorWrap.valueText:SetShown(isIconAura)
  self.frame.iconMatchSizeCheck:SetShown(not isIconAura)
  self.frame.hideCDMIconCheck:SetShown(not isAuraBarList and not isGroup and not isText and not isNameplateAura)
  self.frame.altIconIdWrap.label:SetShown(not isAuraBarList and not isGroup and not isText and not isNameplateAura)
  self.frame.altIconIdWrap.input:SetShown(not isAuraBarList and not isGroup and not isText and not isNameplateAura)
  self.frame.iconSizeWrap.label:SetShown(not isNameplateAura)
  self.frame.iconSizeWrap.input:SetShown(not isNameplateAura)
  self.frame.iconAnchorWrap.label:SetShown(not isNameplateAura)
  self.frame.iconAnchorWrap.dropdown:SetShown(not isNameplateAura)
  self.frame.iconXWrap.label:SetShown(not isNameplateAura)
  self.frame.iconXWrap.input:SetShown(not isNameplateAura)
  self.frame.iconYWrap.label:SetShown(not isNameplateAura)
  self.frame.iconYWrap.input:SetShown(not isNameplateAura)
  self.frame.iconHint:SetShown(not isAuraBarList and not isGroup and not isText)
  if isNameplateAura then
    self.frame.iconHint:SetText(
      "Each native slot uses Width and Height from Look. Cooldown shading and finish effects remain configurable here.")
  else
    self.frame.iconHint:SetText(
      "Alternate icon accepts a spell name, spell ID, or raw texture file ID. Hide CDM Icon only affects mapped tracked-buff icons.")
  end
  if self.frame.showIconCheck.Text then
    self.frame.showIconCheck.Text:SetText(isIconAura and "Show Aura Icon" or (isAuraBarList and "Show Row Icons" or "Show Icon"))
  end
  local triggerUnit = trigger.unit or "player"
  local showRaidFramesOption = isIconAura and triggerUnit == "group"
  self.frame.raidFrameSection._popAurasAvailable = showRaidFramesOption
  self.frame.groupShowBackgroundCheck:SetShown(false)
  self.frame.groupBackgroundColorWrap.label:SetShown(false)
  self.frame.groupBackgroundColorWrap.button:SetShown(false)
  self.frame.groupBackgroundColorWrap.valueText:SetShown(false)
  self.frame.groupMaintainOrderCheck:SetShown(isGroup)
  self.frame.groupSection.title:SetText(isAuraBarList and "List Layout"
    or isNameplateAura and "Nameplate Icon Layout" or "Group Layout")
  if isAuraBarList then
    self.frame.groupHint:SetText("Control the spacing and growth direction for the buff/debuff bar list.")
  elseif isNameplateAura then
    self.frame.groupHint:SetText("Control spacing and growth for matching native buff icons on each hostile NPC nameplate.")
  else
    self.frame.groupHint:SetText("Groups control child size, spacing, order, and growth.")
  end
  self.frame.iconSection.title:SetText(isAuraBarList and "Row Icon" or "Icon")
  self.frame.blizzardSection.title:SetText("Blizzard UI")

  self:ApplyCanvasLayout(isGroup, isNameplateAura)
  self:SetActiveSection(self.frame.activeSectionKey or "canvas")
  self:UpdateControlStates()
  self.suppressUpdates = false
end
