local _, ns = ...

local Frames = ns.util.Frames
local Anchors = ns.util.Anchors
local BaseRegion = ns.renderers.BaseRegion
local Colors = ns.util.Colors
local SoundPicker = ns.util.SoundPicker
local TexturePicker = ns.util.TexturePicker
local Spells = ns.util.Spells
local Theme = ns.util.Theme
local Media = ns.util.Media

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

local function GetBarTextureValues()
  return Media and Media:GetStatusBarTextureOptions(true) or {
    { value = "FLAT", label = "Flat" },
    { value = "GLAZE", label = "Glaze" },
    { value = "BLIZZARD", label = "Blizzard" },
  }
end

local activeGlowStyleValues = {
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
  SoundPicker:HideIfDropdown(frame.deathTankSoundWrap and frame.deathTankSoundWrap.dropdown)
  SoundPicker:HideIfDropdown(frame.deathHealerSoundWrap and frame.deathHealerSoundWrap.dropdown)
  SoundPicker:HideIfDropdown(frame.deathDPSSoundWrap and frame.deathDPSSoundWrap.dropdown)
  if TexturePicker then
    TexturePicker:HideIfDropdown(frame.barTextureWrap and frame.barTextureWrap.dropdown)
  end
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
  return Frames.CreateSectionCard(parent, title, y, height, {
    showHeader = true,
    showRows = true,
    chevron = true,
    bodyDivider = true,
    titleInset = 14,
  })
end

local function RegisterSectionWidgets(section, ...)
  Frames.RegisterSectionWidgets(section, ...)
end

local function CreateLabeledInput(parent, label, x, y, width)
  return Frames.CreateLabeledInput(parent, label, x, y, width)
end

local function ConfigureNumericInput(input, maxLetters)
  input:SetMaxLetters(maxLetters or 10)
  input:SetNumeric(false)
end

local function CreateLabeledDropdown(parent, label, x, y, width, values)
  local widget = Frames.CreateLabeledDropdown(parent, label, x, y, width)
  InitDropdown(widget.dropdown, values)
  return widget
end

local function PositionLabeledInput(widget, x, y)
  if not widget then
    return
  end
  Frames.PositionLabeledInput(widget, x, y)
end

local function PositionLabeledDropdown(widget, x, y)
  if not widget then
    return
  end
  Frames.PositionLabeledDropdown(widget, x, y)
end

local function PositionColorSwatch(widget, x, y)
  if not widget then
    return
  end
  Frames.PositionColorSwatch(widget, x, y)
end

local function HideDeathSoundPickers(frame)
  if not SoundPicker or not frame then
    return
  end
  SoundPicker:HideIfDropdown(frame.deathTankSoundWrap and frame.deathTankSoundWrap.dropdown)
  SoundPicker:HideIfDropdown(frame.deathHealerSoundWrap and frame.deathHealerSoundWrap.dropdown)
  SoundPicker:HideIfDropdown(frame.deathDPSSoundWrap and frame.deathDPSSoundWrap.dropdown)
end

local function SetParentIfPossible(widget, parent)
  if widget and widget.SetParent then
    widget:SetParent(parent)
  end
end

local function SetIconAppearanceParent(frame, parent)
  SetParentIfPossible(frame.showIconCheck, parent)
  SetParentIfPossible(frame.hideCDMIconCheck, parent)
  SetParentIfPossible(frame.iconEdgeCheck, parent)
  SetParentIfPossible(frame.iconFinishFlashCheck, parent)
  SetParentIfPossible(frame.altIconIdWrap.label, parent)
  SetParentIfPossible(frame.altIconIdWrap.input, parent)
  SetParentIfPossible(frame.iconSwipeColorWrap.label, parent)
  SetParentIfPossible(frame.iconSwipeColorWrap.button, parent)
  SetParentIfPossible(frame.iconSwipeColorWrap.valueText, parent)
  SetParentIfPossible(frame.iconHint, parent)
end

local function CreateColorSwatch(parent, label, x, y)
  return Frames.CreateColorSwatch(parent, label, x, y)
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
  section.showCheck = Frames.CreateLabeledToggle(parent, "Show " .. prefix)
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

local function NormalizeDeathAlertCap(value)
  value = tonumber(value)
  if value == nil then
    return 7
  end
  return math.max(0, math.min(20, math.floor(value)))
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
      "|cff88ff88Suppressing Blizzard spell alert:|r %s (%d)\n|cffaaaaaaThis override applies from load rules even if the aura itself never shows. Use a Basic State trigger set to Never if you want a controller-only aura.|r",
      label,
      spellId
    )
  end

  if spellName ~= "" then
    return string.format(
      "|cffff8888Spell alert target unresolved:|r %s\n|cffaaaaaaEnter a spell name from your spellbook or a numeric spell ID. If this proc also exists as a player buff, trigger it once while the editor is open and PopAuras can learn the spell ID from your current aura. Use a Basic State trigger set to Never if you want this aura to stay hidden and act only as a controller.|r",
      spellName
    )
  end

  return "|cffaaaaaaSelect a spell name or spell ID to suppress that Blizzard spell alert while this aura is loaded. This override applies from load rules even if the aura itself never shows. Use a Basic State trigger set to Never if you want a hidden controller-only aura.|r"
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
  local readyStateEnabled = frame.showAlwaysReadyCheck:GetChecked() == true
  local trigger = GetSelectedTrigger(aura)
  local isDeathAlert = trigger and trigger.type == "death_alert"
  local supportsNoStacksColor = trigger and trigger.type == "spell_cooldown" and kind == "bar"
  local supportsActiveGlowStyle = trigger and trigger.type == "spell_cooldown" and kind == "bar"
  local supportsDisplayActiveGlow = trigger
    and not isGroup and not isText and not isAuraBarList and not isNameplateAura
  local activeGlowEnabled = frame.glowWhenActiveCheck:GetChecked() == true
  local selectedActiveGlowStyle = UIDropDownMenu_GetSelectedValue(frame.activeGlowStyleWrap.dropdown) or "INNER_GLOW"
  local showActiveGlowColor = supportsActiveGlowStyle and activeGlowEnabled
    and selectedActiveGlowStyle ~= "ACTIVE_DURATION"
  local supportsChargeCooldown = trigger and trigger.type == "spell_cooldown" and not isGroup and not isText
  local supportsShowAlways = trigger and (trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "trinket_cooldown" or trigger.type == "aura")
  local supportsReadyText = trigger and (trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "trinket_cooldown")
  local showIconCooldownControls = not isGroup and not isText and isIconAura
  local showRaidFrameSection = not isGroup and not isText and isIconAura and frame.raidFrameSection:IsShown()
  local showRaidFrameControls = showRaidFrameSection and frame.showOnRaidFramesCheck:GetChecked() == true and frame.raidFrameSection.collapsed ~= true
  local soundEnabled = frame.soundEnabledCheck:GetChecked() == true
  local dualTrinketSounds = UsesDualTrinketSounds(aura)
  local showSoundBody = not isGroup and not isAuraBarList and frame.soundSection.collapsed ~= true
  local blizzardSpellAlertEnabled = frame.hideBlizzardSpellAlertCheck and frame.hideBlizzardSpellAlertCheck:GetChecked() == true

  SetControlGroupEnabled({
    frame.barColorWrap.button, frame.barColorWrap.label,
    frame.showAlwaysReadyCheck,
    frame.readyColorWrap.button, frame.readyColorWrap.label,
    frame.barTextureWrap.dropdown, frame.barTextureWrap.label,
  }, not isGroup and not isText)
  SetControlGroupShown({ frame.glowWhenActiveCheck }, supportsDisplayActiveGlow)
  SetControlGroupEnabled({ frame.glowWhenActiveCheck }, supportsDisplayActiveGlow)
  SetControlGroupShown({ frame.activeGlowStyleWrap.label, frame.activeGlowStyleWrap.dropdown },
    supportsActiveGlowStyle and activeGlowEnabled)
  SetControlGroupEnabled({ frame.activeGlowStyleWrap.label, frame.activeGlowStyleWrap.dropdown },
    supportsActiveGlowStyle and activeGlowEnabled)
  SetControlGroupShown({
    frame.activeGlowColorWrap.label, frame.activeGlowColorWrap.button, frame.activeGlowColorWrap.valueText,
  }, showActiveGlowColor)
  SetControlGroupEnabled({ frame.activeGlowColorWrap.label, frame.activeGlowColorWrap.button }, showActiveGlowColor)
  SetControlGroupEnabled({ frame.showBackgroundCheck }, true)
  SetControlGroupEnabled({ frame.readyColorWrap.button, frame.readyColorWrap.label },
    not isGroup and not isText and readyStateEnabled)
  SetControlGroupEnabled({ frame.noStacksBarColorCheck }, supportsNoStacksColor)
  SetControlGroupEnabled({ frame.noStacksBarColorWrap.button, frame.noStacksBarColorWrap.label },
    supportsNoStacksColor and frame.noStacksBarColorCheck:GetChecked() == true)
  SetControlGroupEnabled({ frame.chargeCooldownCheck }, supportsChargeCooldown)
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
  SetControlGroupEnabled({ frame.showReadyTextCheck },
    showTimer and readyStateEnabled and supportsReadyText and not isGroup and not isText and not isNameplateAura)

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
  }, soundEnabled and not isGroup and not isAuraBarList and not isDeathAlert)
  SetControlGroupShown({
    frame.soundFileButton, frame.soundFileWrap.label,
  }, showSoundBody and not isDeathAlert and not dualTrinketSounds)
  SetControlGroupShown({
    frame.trinketTopSoundFileButton, frame.trinketTopSoundFileWrap.label,
    frame.trinketBottomSoundFileButton, frame.trinketBottomSoundFileWrap.label,
  }, showSoundBody and not isDeathAlert and dualTrinketSounds)
  SetControlGroupEnabled({
    frame.deathTankSoundButton, frame.deathTankSoundWrap.label,
    frame.deathHealerSoundButton, frame.deathHealerSoundWrap.label,
    frame.deathDPSSoundButton, frame.deathDPSSoundWrap.label,
  }, showSoundBody and isDeathAlert and soundEnabled)
  SetControlGroupEnabled({
    frame.blizzardSpellAlertWrap.input,
    frame.blizzardSpellAlertWrap.label,
    frame.blizzardSpellAlertHint,
  }, blizzardSpellAlertEnabled and not isGroup)

  -- Feature toggles are the only controls left visible while their feature is
  -- off. This keeps each submenu useful without presenting inactive fields.
  SetControlGroupShown({
    frame.backgroundColorWrap.button, frame.backgroundColorWrap.label, frame.backgroundColorWrap.valueText,
  }, showBackground and (not isIconAura or isNameplateAura))
  SetControlGroupShown({
    frame.backgroundGammaWrap.input, frame.backgroundGammaWrap.label,
  }, showBackground and isAuraBarList)
  SetControlGroupShown({
    frame.noStacksBarColorWrap.button, frame.noStacksBarColorWrap.label, frame.noStacksBarColorWrap.valueText,
  }, supportsNoStacksColor and frame.noStacksBarColorCheck:GetChecked() == true)
  SetControlGroupShown({
    frame.readyColorWrap.button, frame.readyColorWrap.label, frame.readyColorWrap.valueText,
  }, readyStateEnabled and supportsShowAlways and not isGroup and not isText and not isNameplateAura)

  SetControlGroupShown({ frame.iconMatchSizeCheck }, showIcon and not isIconAura)
  SetControlGroupShown({
    frame.iconEdgeCheck, frame.iconFinishFlashCheck,
    frame.iconSwipeColorWrap.button, frame.iconSwipeColorWrap.label, frame.iconSwipeColorWrap.valueText,
  }, showIcon and isIconAura)
  SetControlGroupShown({
    frame.altIconIdWrap.input, frame.altIconIdWrap.label,
  }, showIcon and not isAuraBarList and not isGroup and not isText and not isNameplateAura)
  SetControlGroupShown({
    frame.iconSizeWrap.input, frame.iconSizeWrap.label,
    frame.iconAnchorWrap.dropdown, frame.iconAnchorWrap.label,
    frame.iconXWrap.input, frame.iconXWrap.label,
    frame.iconYWrap.input, frame.iconYWrap.label,
  }, showIcon and not isIconAura and not isNameplateAura)
  SetControlGroupShown({ frame.iconHint }, showIcon and not isAuraBarList and not isGroup and not isText)

  SetControlGroupShown({
    frame.nameControls.fontWrap.dropdown, frame.nameControls.fontWrap.label,
    frame.nameControls.sizeWrap.input, frame.nameControls.sizeWrap.label,
    frame.nameControls.rotationWrap.dropdown, frame.nameControls.rotationWrap.label,
    frame.nameControls.anchorWrap.dropdown, frame.nameControls.anchorWrap.label,
    frame.nameControls.xWrap.input, frame.nameControls.xWrap.label,
    frame.nameControls.yWrap.input, frame.nameControls.yWrap.label,
    frame.nameControls.colorWrap.button, frame.nameControls.colorWrap.label, frame.nameControls.colorWrap.valueText,
  }, showName and not isGroup)
  SetControlGroupShown({
    frame.nameControls.altNameWrap.input, frame.nameControls.altNameWrap.label,
  }, showName and not isAuraBarList and not isNameplateAura)

  SetControlGroupShown({
    frame.timerControls.fontWrap.dropdown, frame.timerControls.fontWrap.label,
    frame.timerControls.sizeWrap.input, frame.timerControls.sizeWrap.label,
    frame.timerControls.rotationWrap.dropdown, frame.timerControls.rotationWrap.label,
    frame.timerControls.anchorWrap.dropdown, frame.timerControls.anchorWrap.label,
    frame.timerControls.xWrap.input, frame.timerControls.xWrap.label,
    frame.timerControls.yWrap.input, frame.timerControls.yWrap.label,
    frame.timerControls.colorWrap.button, frame.timerControls.colorWrap.label, frame.timerControls.colorWrap.valueText,
    frame.timerControls.decimalsWrap.dropdown, frame.timerControls.decimalsWrap.label,
  }, showTimer and not isGroup and not isText)
  SetControlGroupShown({ frame.showReadyTextCheck },
    showTimer and readyStateEnabled and supportsReadyText and not isGroup and not isText and not isNameplateAura)

  SetControlGroupShown({
    frame.stacksControls.fontWrap.dropdown, frame.stacksControls.fontWrap.label,
    frame.stacksControls.sizeWrap.input, frame.stacksControls.sizeWrap.label,
    frame.stacksControls.rotationWrap.dropdown, frame.stacksControls.rotationWrap.label,
    frame.stacksControls.anchorWrap.dropdown, frame.stacksControls.anchorWrap.label,
    frame.stacksControls.xWrap.input, frame.stacksControls.xWrap.label,
    frame.stacksControls.yWrap.input, frame.stacksControls.yWrap.label,
    frame.stacksControls.colorWrap.button, frame.stacksControls.colorWrap.label, frame.stacksControls.colorWrap.valueText,
  }, showStacks and not isGroup and not isText)

  SetControlGroupShown({
    frame.soundReadyCheck,
    frame.soundChannelWrap.dropdown, frame.soundChannelWrap.label,
  }, showSoundBody and soundEnabled and not isDeathAlert)
  SetControlGroupShown({ frame.soundHint }, showSoundBody and soundEnabled)
  SetControlGroupShown({
    frame.soundFileButton, frame.soundFileWrap.label,
  }, showSoundBody and soundEnabled and not isDeathAlert and not dualTrinketSounds)
  SetControlGroupShown({
    frame.trinketTopSoundFileButton, frame.trinketTopSoundFileWrap.label,
    frame.trinketBottomSoundFileButton, frame.trinketBottomSoundFileWrap.label,
  }, showSoundBody and soundEnabled and not isDeathAlert and dualTrinketSounds)
  SetControlGroupShown({
    frame.deathTankSoundButton, frame.deathTankSoundWrap.label,
    frame.deathHealerSoundButton, frame.deathHealerSoundWrap.label,
    frame.deathDPSSoundButton, frame.deathDPSSoundWrap.label,
  }, showSoundBody and soundEnabled and isDeathAlert)
  SetControlGroupShown({
    frame.blizzardSpellAlertWrap.input, frame.blizzardSpellAlertWrap.label, frame.blizzardSpellAlertHint,
  }, blizzardSpellAlertEnabled and not isGroup)

  local showRaidFrameBody = showRaidFrameControls
  SetControlGroupShown({
    frame.raidFrameGlowCheck, frame.raidFrameDurationCheck, frame.raidFrameStacksCheck,
    frame.raidFrameSizeWrap.input, frame.raidFrameSizeWrap.label,
    frame.raidFrameAnchorWrap.dropdown, frame.raidFrameAnchorWrap.label,
    frame.raidFrameGrowthWrap.dropdown, frame.raidFrameGrowthWrap.label,
    frame.raidFrameXWrap.input, frame.raidFrameXWrap.label,
    frame.raidFrameYWrap.input, frame.raidFrameYWrap.label,
    frame.raidFrameHint,
  }, showRaidFrameBody)

  if frame.reverseCheck.Text then
    if isIconAura then
      frame.reverseCheck.Text:SetText("Fill Cooldown Swipe")
    else
      frame.reverseCheck.Text:SetText(frame.reverseCheck:GetChecked() and "Fill" or "Drain")
    end
  end

  if not isIconAura then
    frame.iconSection:SetHeight(showIcon and 270 or 70)
  end
  frame.nameSection:SetHeight(showName and 290 or 70)
  frame.timerSection:SetHeight(showTimer and 260 or 70)
  frame.stacksSection:SetHeight(showStacks and 220 or 70)
  frame.soundSection:SetHeight(soundEnabled and (dualTrinketSounds and 226 or 164) or 70)
  frame.blizzardSection:SetHeight(blizzardSpellAlertEnabled and 176 or 70)
  frame.raidFrameSection:SetHeight(showRaidFrameBody and 236 or 70)
  self:LayoutSections()

  if not soundEnabled or isGroup or isAuraBarList then
    HideAllSoundPickers(frame)
  elseif isDeathAlert and SoundPicker then
    SoundPicker:HideIfDropdown(frame.soundFileWrap.dropdown)
    SoundPicker:HideIfDropdown(frame.trinketTopSoundFileWrap.dropdown)
    SoundPicker:HideIfDropdown(frame.trinketBottomSoundFileWrap.dropdown)
  elseif dualTrinketSounds and SoundPicker then
    HideDeathSoundPickers(frame)
    SoundPicker:HideIfDropdown(frame.soundFileWrap.dropdown)
  elseif SoundPicker then
    HideDeathSoundPickers(frame)
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
  local previousGlowWhenActive = aura.display.glowWhenActive == true
  local previousActiveGlowStyle = aura.display.activeGlowStyle or "NONE"
  local previousSoundEnabled = aura.display.soundEnabled == true
  local previousShowOnRaidFrames = aura.display.showOnRaidFrames == true

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
  if frame.widthSlider and frame.heightSlider then
    frame._popAurasSyncingSliders = true
    frame.widthSlider:SetValue(math.max(20, math.min(1000, widthValue)))
    frame.heightSlider:SetValue(math.max(4, math.min(300, heightValue)))
    frame._popAurasSyncingSliders = false
  end
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
  if trigger.type == "death_alert" then
    trigger.alertDuration = math.max(0.1,
      CommitNumeric(frame.deathDurationWrap.input, trigger.alertDuration or 2))
    trigger.maxAlertsPerCombat = NormalizeDeathAlertCap(
      CommitInteger(frame.deathMaxAlertsWrap.input, trigger.maxAlertsPerCombat or 7))
    frame.deathDurationWrap.input:SetText(string.format("%.2f", trigger.alertDuration))
    frame.deathMaxAlertsWrap.input:SetText(tostring(trigger.maxAlertsPerCombat))
    trigger.showTank = frame.deathTankCheck:GetChecked() == true
    trigger.showHealer = frame.deathHealerCheck:GetChecked() == true
    trigger.showDPS = frame.deathDPSCheck:GetChecked() == true
  end
  if isNameplateAura then
    local maxAuras = CommitInteger(frame.nameplateMaxAurasWrap.input, trigger.nameplateMaxAuras or 3)
    trigger.nameplateMaxAuras = math.max(1, math.min(maxAuras, 8))
    frame.nameplateMaxAurasWrap.input:SetText(tostring(trigger.nameplateMaxAuras))
  end
  if trigger.type == "spell_cooldown" then
    trigger.showChargeCooldown = frame.chargeCooldownCheck:GetChecked() == true
  end
  local readyStateEnabled = frame.showAlwaysReadyCheck:GetChecked() == true
  aura.display.readyLook = readyStateEnabled
  local activeGlowEnabled = frame.glowWhenActiveCheck:GetChecked() == true
  if trigger.type == "spell_cooldown" and aura.kind == "bar" then
    local style = UIDropDownMenu_GetSelectedValue(frame.activeGlowStyleWrap.dropdown)
      or aura.display.activeGlowStyle or "INNER_GLOW"
    if style == "NONE" then style = "INNER_GLOW" end
    aura.display.activeGlowStyle = activeGlowEnabled and style or "NONE"
    aura.display.glowWhenActive = activeGlowEnabled
  else
    aura.display.glowWhenActive = activeGlowEnabled
  end
  aura.display.activeGlowColor = Colors.Copy(
    frame.activeGlowColorWrap.color or aura.display.activeGlowColor
      or { r = 1.00, g = 0.82, b = 0.08, a = 1 })
  if trigger and (trigger.type == "spell_cooldown" or trigger.type == "item_cooldown" or trigger.type == "trinket_cooldown" or trigger.type == "aura") then
    trigger.showAlways = readyStateEnabled
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
  aura.display.hideReadyTimer = frame.showReadyTextCheck:GetChecked() ~= true

  aura.display.showStacks = frame.stacksControls.showCheck:GetChecked() == true
  aura.display.stacksFontStyle = UIDropDownMenu_GetSelectedValue(frame.stacksControls.fontWrap.dropdown) or aura.display.stacksFontStyle
  aura.display.stacksFontSize = CommitInteger(frame.stacksControls.sizeWrap.input, aura.display.stacksFontSize or 14)
  aura.display.stacksRotation = tonumber(UIDropDownMenu_GetSelectedValue(frame.stacksControls.rotationWrap.dropdown) or aura.display.stacksRotation or 0) or 0
  aura.display.stacksAnchor = UIDropDownMenu_GetSelectedValue(frame.stacksControls.anchorWrap.dropdown) or aura.display.stacksAnchor
  aura.display.stacksOffsetX = CommitNumeric(frame.stacksControls.xWrap.input, aura.display.stacksOffsetX or 0)
  aura.display.stacksOffsetY = CommitNumeric(frame.stacksControls.yWrap.input, aura.display.stacksOffsetY or 0)
  aura.display.stacksColor = Colors.Copy(frame.stacksControls.colorWrap.color or aura.display.stacksColor)
  if trigger.type == "death_alert" then
    trigger.deathSoundEnabled = frame.soundEnabledCheck:GetChecked() == true
    trigger.soundTank = UIDropDownMenu_GetSelectedValue(frame.deathTankSoundWrap.dropdown)
      or trigger.soundTank or "None"
    trigger.soundHealer = UIDropDownMenu_GetSelectedValue(frame.deathHealerSoundWrap.dropdown)
      or trigger.soundHealer or "None"
    trigger.soundDPS = UIDropDownMenu_GetSelectedValue(frame.deathDPSSoundWrap.dropdown)
      or trigger.soundDPS or "None"
  else
    aura.display.soundEnabled = frame.soundEnabledCheck:GetChecked() == true
  end
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

  if ns.FeatureInventory and ns.FeatureInventory.ScheduleRebuild then
    ns.FeatureInventory:ScheduleRebuild()
  end
  if previousGlowWhenActive ~= (aura.display.glowWhenActive == true)
      or previousActiveGlowStyle ~= (aura.display.activeGlowStyle or "NONE") then
    -- SpellCooldownProvider keeps a deliberately small UNIT_AURA index for
    -- active-glow bars. Rebuild it immediately when the editor changes opt-in
    -- state so the next player aura update cannot use a stale list.
    if ns.TriggerBase and ns.TriggerBase.InvalidateProviderCaches then
      ns.TriggerBase:InvalidateProviderCaches("spell_cooldown")
    end
  end
  if previousSoundEnabled ~= (aura.display.soundEnabled == true)
      or previousShowOnRaidFrames ~= (aura.display.showOnRaidFrames == true) then
    if ns.TriggerBase and ns.TriggerBase.InvalidateProviderCaches then
      ns.TriggerBase:InvalidateProviderCaches("aura")
    end
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
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if aura then
      Panel:Refresh(aura)
    end
  end)
end

local function GetEditedAura()
  return ns.Registry:GetAura(ns.db.ui.selectedAuraId)
end

local function SetLabeledInputShown(widget, shown)
  if not widget then return end
  widget.label:SetShown(shown)
  widget.input:SetShown(shown)
end

local function SetLabeledDropdownShown(widget, shown)
  if not widget then return end
  widget.label:SetShown(shown)
  widget.dropdown:SetShown(shown)
end

local function SetColorWidgetShown(widget, shown)
  if not widget then return end
  widget.label:SetShown(shown)
  widget.button:SetShown(shown)
  widget.valueText:SetShown(false)
end

local function CreateDisplayGearControls(frame)
  local function Apply()
    Panel:ApplyCurrent()
  end

  frame.anchorGear = Frames.CreateGearButton(frame.canvasSection, "Attachment points and offsets")
  frame.anchorPopover = Frames.CreateSettingsPopover({
    title = "Anchor Details",
    width = 330,
    onChanged = Apply,
    rows = {
      {
        type = "dropdown", label = "Frame Point", values = Anchors.GetPointList,
        get = function()
          local aura = GetEditedAura()
          return aura and aura.position and aura.position.point or "CENTER"
        end,
        set = function(value) SetDropdown(frame.framePointWrap.dropdown, value) end,
      },
      {
        type = "dropdown", label = "Parent Point", values = Anchors.GetPointList,
        get = function()
          local aura = GetEditedAura()
          return aura and aura.position and aura.position.relativePoint or "CENTER"
        end,
        set = function(value) SetDropdown(frame.parentPointWrap.dropdown, value) end,
      },
      {
        type = "input", label = "Offset X",
        get = function()
          local aura = GetEditedAura()
          return aura and aura.position and aura.position.x or 0
        end,
        set = function(value) frame.xWrap.input:SetText(tostring(value or 0)) end,
      },
      {
        type = "input", label = "Offset Y",
        get = function()
          local aura = GetEditedAura()
          return aura and aura.position and aura.position.y or 0
        end,
        set = function(value) frame.yWrap.input:SetText(tostring(value or 0)) end,
      },
    },
  })
  frame.anchorGear:SetScript("OnClick", function() frame.anchorPopover:ShowFor(frame.anchorGear) end)

  frame.layerGear = Frames.CreateGearButton(frame.canvasSection, "Adjust the frame level within this strata")
  frame.layerPopover = Frames.CreateSettingsPopover({
    title = "Layer Details",
    width = 300,
    onChanged = Apply,
    rows = {
      {
        type = "input", label = "Frame Level",
        get = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.frameLevel or 1
        end,
        set = function(value) frame.levelWrap.input:SetText(tostring(value or 1)) end,
      },
    },
  })
  frame.layerGear:SetScript("OnClick", function() frame.layerPopover:ShowFor(frame.layerGear) end)

  frame.glowGear = Frames.CreateGearButton(frame.canvasSection, "Choose the active glow type and color")
  frame.glowPopover = Frames.CreateSettingsPopover({
    title = "Active Glow",
    width = 320,
    onChanged = Apply,
    rows = {
      {
        type = "dropdown", label = "Glow Type", values = activeGlowStyleValues,
        get = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.activeGlowStyle or "INNER_GLOW"
        end,
        set = function(value) SetDropdown(frame.activeGlowStyleWrap.dropdown, value) end,
      },
      {
        type = "color", label = "Glow Color",
        disabled = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.activeGlowStyle == "ACTIVE_DURATION"
        end,
        get = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.activeGlowColor
            or { r = 1.00, g = 0.82, b = 0.08, a = 1 }
        end,
        set = function(r, g, b, a)
          SetColorSwatch(frame.activeGlowColorWrap, { r = r, g = g, b = b, a = a })
        end,
      },
    },
  })
  frame.glowGear:SetScript("OnClick", function() frame.glowPopover:ShowFor(frame.glowGear) end)

  frame.readyGear = Frames.CreateGearButton(frame.canvasSection, "Configure the ready appearance")
  frame.readyPopover = Frames.CreateSettingsPopover({
    title = "Ready Appearance", width = 320, onChanged = Apply,
    rows = {
      {
        type = "color", label = "Ready Color",
        get = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.readyColor
            or { r = 0.16, g = 0.72, b = 0.26, a = 1 }
        end,
        set = function(r, g, b, a)
          SetColorSwatch(frame.readyColorWrap, { r = r, g = g, b = b, a = a })
        end,
      },
      {
        type = "toggle", label = "Show Ready Text",
        get = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.hideReadyTimer ~= true
        end,
        set = function(value) frame.showReadyTextCheck:SetChecked(value == true) end,
      },
    },
  })
  frame.readyGear:SetScript("OnClick", function() frame.readyPopover:ShowFor(frame.readyGear) end)

  frame.backgroundGear = Frames.CreateGearButton(frame.canvasSection, "Choose the background color")
  frame.backgroundPopover = Frames.CreateSettingsPopover({
    title = "Background", width = 320, onChanged = Apply,
    rows = {
      {
        type = "color", label = "Background Color",
        get = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.backgroundColor
            or { r = 0, g = 0, b = 0, a = 0.45 }
        end,
        set = function(r, g, b, a)
          SetColorSwatch(frame.backgroundColorWrap, { r = r, g = g, b = b, a = a })
        end,
      },
    },
  })
  frame.backgroundGear:SetScript("OnClick", function() frame.backgroundPopover:ShowFor(frame.backgroundGear) end)

  frame.noStacksGear = Frames.CreateGearButton(frame.canvasSection, "Choose the out-of-stacks color")
  frame.noStacksPopover = Frames.CreateSettingsPopover({
    title = "Out-of-Stacks", width = 320, onChanged = Apply,
    rows = {
      {
        type = "color", label = "Bar Color",
        get = function()
          local aura = GetEditedAura()
          return aura and aura.display and aura.display.noStacksBarColor
            or { r = 0.86, g = 0.18, b = 0.18, a = 1 }
        end,
        set = function(r, g, b, a)
          SetColorSwatch(frame.noStacksBarColorWrap, { r = r, g = g, b = b, a = a })
        end,
      },
    },
  })
  frame.noStacksGear:SetScript("OnClick", function() frame.noStacksPopover:ShowFor(frame.noStacksGear) end)

  local function CreateTextGear(section, controls, prefix, title, includeAlternateName, includeDecimals)
    local gear = Frames.CreateGearButton(section, "Configure " .. string.lower(title))
    local rows = {}
    if includeAlternateName then
      rows[#rows + 1] = {
        type = "input", label = "Alternative Name", width = 160,
        get = function()
          local aura = GetEditedAura()
          return aura and aura.text and aura.text.nameOverride or ""
        end,
        set = function(value) controls.altNameWrap.input:SetText(tostring(value or "")) end,
      }
    end
    rows[#rows + 1] = {
      type = "dropdown", label = "Font", values = fontStyleValues,
      get = function()
        local aura = GetEditedAura()
        return aura and aura.display and aura.display[prefix .. "FontStyle"] or "FRIZQT"
      end,
      set = function(value) SetDropdown(controls.fontWrap.dropdown, value) end,
    }
    rows[#rows + 1] = {
      type = "input", label = "Font Size",
      get = function()
        local aura = GetEditedAura()
        return aura and aura.display and aura.display[prefix .. "FontSize"] or 12
      end,
      set = function(value) controls.sizeWrap.input:SetText(tostring(value or 12)) end,
    }
    rows[#rows + 1] = {
      type = "dropdown", label = "Anchor", values = textAnchorValues,
      get = function()
        local aura = GetEditedAura()
        return aura and aura.display and aura.display[prefix .. "Anchor"] or "CENTER"
      end,
      set = function(value) SetDropdown(controls.anchorWrap.dropdown, value) end,
    }
    rows[#rows + 1] = {
      type = "dropdown", label = "Rotation", values = textRotationValues,
      get = function()
        local aura = GetEditedAura()
        return tostring(aura and aura.display and aura.display[prefix .. "Rotation"] or 0)
      end,
      set = function(value) SetDropdown(controls.rotationWrap.dropdown, tostring(value or 0)) end,
    }
    rows[#rows + 1] = {
      type = "input", label = "Offset X",
      get = function()
        local aura = GetEditedAura()
        return aura and aura.display and aura.display[prefix .. "OffsetX"] or 0
      end,
      set = function(value) controls.xWrap.input:SetText(tostring(value or 0)) end,
    }
    rows[#rows + 1] = {
      type = "input", label = "Offset Y",
      get = function()
        local aura = GetEditedAura()
        return aura and aura.display and aura.display[prefix .. "OffsetY"] or 0
      end,
      set = function(value) controls.yWrap.input:SetText(tostring(value or 0)) end,
    }
    if includeDecimals then
      rows[#rows + 1] = {
        type = "dropdown", label = "Decimals", values = { "0", "1", "2" },
        get = function()
          local aura = GetEditedAura()
          return tostring(aura and aura.display and aura.display.timerDecimals or 1)
        end,
        set = function(value) SetDropdown(controls.decimalsWrap.dropdown, tostring(value or 1)) end,
      }
    end
    rows[#rows + 1] = {
      type = "color", label = "Text Color",
      get = function()
        local aura = GetEditedAura()
        return aura and aura.display and aura.display[prefix .. "Color"]
          or { r = 1, g = 1, b = 1, a = 1 }
      end,
      set = function(r, g, b, a)
        SetColorSwatch(controls.colorWrap, { r = r, g = g, b = b, a = a })
      end,
    }
    local popover = Frames.CreateSettingsPopover({
      title = title,
      width = 340,
      rows = rows,
      onChanged = Apply,
    })
    gear:SetScript("OnClick", function() popover:ShowFor(gear) end)
    return gear, popover
  end

  frame.nameGear, frame.namePopover = CreateTextGear(
    frame.nameSection, frame.nameControls, "name", "Name Text", true, false)
  frame.timerGear, frame.timerPopover = CreateTextGear(
    frame.timerSection, frame.timerControls, "timer", "Duration Text", false, true)
  frame.stacksGear, frame.stacksPopover = CreateTextGear(
    frame.stacksSection, frame.stacksControls, "stacks", "Stacks Text", false, false)

  frame:HookScript("OnHide", function()
    for _, popup in ipairs({
      frame.anchorPopover, frame.layerPopover, frame.glowPopover,
      frame.readyPopover, frame.backgroundPopover, frame.noStacksPopover,
      frame.namePopover, frame.timerPopover, frame.stacksPopover,
    }) do
      if popup and popup:IsShown() then popup:Hide() end
    end
  end)
end

local function GetGridEntryTarget(entry)
  if entry.target then return entry.target end
  if entry.kind == "range" then return entry.slider end
  if entry.kind == "input" then return entry.widget and entry.widget.input end
  if entry.kind == "dropdown" or entry.kind == "dropdownGear" then
    return entry.widget and entry.widget.dropdown
  end
  if entry.kind == "color" then return entry.widget and entry.widget.button end
  if entry.kind == "selector" then return entry.control end
  return entry.control
end

local function GetGridEntryLabel(entry)
  if entry.label then return entry.label end
  if entry.widget and entry.widget.label then return entry.widget.label end
  return entry.control and entry.control.Text or nil
end

local function ApplyTwoColumnSettingsGrid(section, entries, hint)
  if not section then return 0 end
  local visible = {}
  for _, entry in ipairs(entries or {}) do
    local target = GetGridEntryTarget(entry)
    if target and target:IsShown() then
      visible[#visible + 1] = entry
    end
  end

  local parentWidth = section:GetParent() and section:GetParent():GetWidth() or 764
  local sectionWidth = math.max(720, (tonumber(parentWidth) or 764) - 44)
  local contentInset = 4
  local cellGap = 2
  local cellWidth = math.floor((sectionWidth - (contentInset * 2) - cellGap) / 2)
  local headerHeight = 34
  local rowHeight = 50

  section.insetLeft = 22
  section.insetRight = 22
  Theme.StyleSurface(section, "transparent", "transparent")
  section._popAurasUseGridCells = true
  Theme.StyleSurface(section.header, "transparent", "transparent")
  section.header:SetHeight(30)
  section.title:ClearAllPoints()
  section.title:SetPoint("LEFT", section.header, "LEFT", 4, 0)
  Theme.ApplyTypography(section.title, "controlSmall")
  Theme.SetText(section.title, "navigation")
  if section.bodyTop then
    section.bodyTop:Show()
    Theme.SetTexture(section.bodyTop, "border")
  end
  for _, band in ipairs(section.rowBands or {}) do band:Hide() end
  if section.settingsGridDivider then section.settingsGridDivider:Hide() end

  section.settingsGridCells = section.settingsGridCells or {}
  local function GetCell(index, row, column)
    local cell = section.settingsGridCells[index]
    if not cell then
      cell = section:CreateTexture(nil, "BACKGROUND", nil, -2)
      cell:SetTexture("Interface\\Buttons\\WHITE8x8")
      Theme.SetTexture(cell, "canvasAlt")
      section.settingsGridCells[index] = cell
    end
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", section, "TOPLEFT",
      contentInset + (column * (cellWidth + cellGap)),
      -headerHeight - (row * rowHeight))
    cell:SetSize(cellWidth, 48)
    cell:Show()
    return cell
  end

  local function PlaceLabel(label, cell, controlWidth)
    if not label then return end
    label:ClearAllPoints()
    label:SetPoint("LEFT", cell, "LEFT", 14, 0)
    label:SetWidth(math.max(100, cellWidth - controlWidth - 48))
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    Theme.ApplyTypography(label, "control")
    Theme.SetText(label, "text")
  end

  for index, entry in ipairs(visible) do
    local row = math.floor((index - 1) / 2)
    local column = (index - 1) % 2
    local cell = GetCell(index, row, column)
    local label = GetGridEntryLabel(entry)
    local hasGear = entry.gear and entry.gear:IsShown()
    local gearWidth = hasGear and 34 or 0

    if entry.kind == "range" then
      PlaceLabel(label, cell, 232)
      entry.widget.input:ClearAllPoints()
      entry.widget.input:SetWidth(54)
      entry.widget.input:SetPoint("RIGHT", cell, "RIGHT", -14, 0)
      entry.slider:ClearAllPoints()
      entry.slider:SetWidth(150)
      entry.slider:SetPoint("RIGHT", entry.widget.input, "LEFT", -12, 0)
    elseif entry.kind == "input" then
      local width = math.min(entry.width or 90, 190)
      PlaceLabel(label, cell, width)
      entry.widget.input:ClearAllPoints()
      entry.widget.input:SetWidth(width)
      entry.widget.input:SetPoint("RIGHT", cell, "RIGHT", -14, 0)
    elseif entry.kind == "dropdown" or entry.kind == "dropdownGear" then
      local width = hasGear and 150 or 170
      PlaceLabel(label, cell, width + gearWidth)
      UIDropDownMenu_SetWidth(entry.widget.dropdown, width)
      entry.widget.dropdown:ClearAllPoints()
      entry.widget.dropdown:SetPoint("RIGHT", cell, "RIGHT", -2 - gearWidth, 0)
      if hasGear then
        entry.gear:ClearAllPoints()
        entry.gear:SetPoint("RIGHT", cell, "RIGHT", -10, 0)
      end
    elseif entry.kind == "color" then
      PlaceLabel(label, cell, 40)
      entry.widget.button:ClearAllPoints()
      entry.widget.button:SetPoint("RIGHT", cell, "RIGHT", -14, 0)
      if entry.widget.valueText then entry.widget.valueText:Hide() end
    elseif entry.kind == "selector" then
      local width = math.min(entry.width or 170, 190)
      PlaceLabel(label, cell, width)
      entry.control:ClearAllPoints()
      entry.control:SetWidth(width)
      entry.control:SetPoint("RIGHT", cell, "RIGHT", -14, 0)
    else
      local control = entry.control
      PlaceLabel(label, cell, hasGear and 78 or 48)
      control:ClearAllPoints()
      control:SetPoint("RIGHT", cell, "RIGHT", -14 - gearWidth, 0)
      if hasGear then
        entry.gear:ClearAllPoints()
        entry.gear:SetPoint("RIGHT", cell, "RIGHT", -10, 0)
      end
    end
  end

  for index = #visible + 1, #section.settingsGridCells do
    section.settingsGridCells[index]:Hide()
  end

  local rows = math.max(1, math.ceil(#visible / 2))
  local hintHeight = hint and hint:IsShown() and 34 or 0
  local height = headerHeight + (rows * rowHeight) + hintHeight
  section:SetHeight(height)
  section.expandedHeight = height

  if hint and hint:IsShown() then
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", section, "TOPLEFT", 14,
      -(headerHeight + (rows * rowHeight) + 6))
    hint:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14,
      -(headerHeight + (rows * rowHeight) + 6))
    hint:SetJustifyH("LEFT")
  end
  return rows
end
local function ApplyDisplayTwoColumnGrids(frame, aura, isGroup, isNameplateAura)
  local isIconAura = aura.kind == "icon"
  local trigger = GetSelectedTrigger(aura)
  frame.deathRolesLabel:Hide()

  local canvasEntries = {
    { kind = "input", widget = frame.nameInputWrap, width = 260 },
    { kind = "range", widget = frame.widthWrap, slider = frame.widthSlider },
    { kind = "range", widget = frame.heightWrap, slider = frame.heightSlider },
    { kind = "dropdown", widget = frame.orientationWrap, width = 220 },
    { kind = "dropdown", widget = frame.nameplateAnchorWrap, width = 220 },
    { kind = "dropdownGear", widget = frame.anchorWrap, gear = frame.anchorGear, width = 230 },
    { kind = "dropdownGear", widget = frame.strataWrap, gear = frame.layerGear, width = 190 },
    { kind = "input", widget = frame.deathDurationWrap, width = 120 },
    { kind = "input", widget = frame.deathMaxAlertsWrap, width = 120 },
    { kind = "toggle", control = frame.deathTankCheck },
    { kind = "toggle", control = frame.deathHealerCheck },
    { kind = "toggle", control = frame.deathDPSCheck },
    { kind = "color", widget = frame.barColorWrap },
    { kind = "dropdown", widget = frame.barTextureWrap, width = 240 },
    { kind = "toggle", control = frame.showAlwaysReadyCheck, gear = frame.readyGear },
    { kind = "toggle", control = frame.glowWhenActiveCheck, gear = frame.glowGear },
    { kind = "toggle", control = frame.reverseCheck },
    { kind = "toggle", control = frame.showBackgroundCheck, gear = frame.backgroundGear },
    { kind = "input", widget = frame.backgroundGammaWrap, width = 110 },
    { kind = "input", widget = frame.permanentAlphaWrap, width = 110 },
    { kind = "toggle", control = frame.auraListSwipeCheck },
    { kind = "toggle", control = frame.noStacksBarColorCheck, gear = frame.noStacksGear },
    { kind = "toggle", control = frame.chargeCooldownCheck },
  }

  if isIconAura then
    canvasEntries[#canvasEntries + 1] = { kind = "toggle", control = frame.showIconCheck }
    canvasEntries[#canvasEntries + 1] = { kind = "toggle", control = frame.hideCDMIconCheck }
    canvasEntries[#canvasEntries + 1] = { kind = "input", widget = frame.altIconIdWrap, width = 220 }
    canvasEntries[#canvasEntries + 1] = { kind = "toggle", control = frame.iconEdgeCheck }
    canvasEntries[#canvasEntries + 1] = { kind = "toggle", control = frame.iconFinishFlashCheck }
    canvasEntries[#canvasEntries + 1] = { kind = "color", widget = frame.iconSwipeColorWrap }
  end

  local canvasHint = trigger.type == "death_alert" and frame.deathAlertHint
    or isIconAura and frame.iconHint or nil
  ApplyTwoColumnSettingsGrid(frame.canvasSection, canvasEntries, canvasHint)

  ApplyTwoColumnSettingsGrid(frame.groupSection, {
    { kind = "input", widget = frame.groupSpacingWrap, width = 110 },
    { kind = "dropdown", widget = frame.groupGrowthWrap, width = 210 },
    { kind = "toggle", control = frame.groupMaintainOrderCheck },
  }, frame.groupHint)

  if not isIconAura then
    ApplyTwoColumnSettingsGrid(frame.iconSection, {
      { kind = "toggle", control = frame.showIconCheck },
      { kind = "toggle", control = frame.hideCDMIconCheck },
      { kind = "toggle", control = frame.iconMatchSizeCheck },
      { kind = "toggle", control = frame.iconEdgeCheck },
      { kind = "toggle", control = frame.iconFinishFlashCheck },
      { kind = "input", widget = frame.iconSizeWrap, width = 100 },
      { kind = "dropdown", widget = frame.iconAnchorWrap, width = 190 },
      { kind = "input", widget = frame.iconXWrap, width = 100 },
      { kind = "input", widget = frame.iconYWrap, width = 100 },
      { kind = "input", widget = frame.altIconIdWrap, width = 220 },
      { kind = "color", widget = frame.iconSwipeColorWrap },
    }, frame.iconHint)
  end

  ApplyTwoColumnSettingsGrid(frame.raidFrameSection, {
    { kind = "toggle", control = frame.showOnRaidFramesCheck },
    { kind = "toggle", control = frame.raidFrameGlowCheck },
    { kind = "toggle", control = frame.raidFrameDurationCheck },
    { kind = "toggle", control = frame.raidFrameStacksCheck },
    { kind = "input", widget = frame.raidFrameSizeWrap, width = 100 },
    { kind = "dropdown", widget = frame.raidFrameAnchorWrap, width = 210 },
    { kind = "dropdown", widget = frame.raidFrameGrowthWrap, width = 190 },
    { kind = "input", widget = frame.raidFrameXWrap, width = 100 },
    { kind = "input", widget = frame.raidFrameYWrap, width = 100 },
  }, frame.raidFrameHint)

  ApplyTwoColumnSettingsGrid(frame.nameSection, {
    { kind = "toggle", control = frame.nameControls.showCheck },
    { kind = "input", widget = frame.nameControls.altNameWrap, width = 170 },
    { kind = "dropdown", widget = frame.nameControls.fontWrap },
    { kind = "input", widget = frame.nameControls.sizeWrap },
    { kind = "dropdown", widget = frame.nameControls.anchorWrap },
    { kind = "dropdown", widget = frame.nameControls.rotationWrap },
    { kind = "input", widget = frame.nameControls.xWrap },
    { kind = "input", widget = frame.nameControls.yWrap },
    { kind = "color", widget = frame.nameControls.colorWrap },
  })
  ApplyTwoColumnSettingsGrid(frame.timerSection, {
    { kind = "toggle", control = frame.timerControls.showCheck },
    { kind = "dropdown", widget = frame.timerControls.fontWrap },
    { kind = "input", widget = frame.timerControls.sizeWrap },
    { kind = "dropdown", widget = frame.timerControls.anchorWrap },
    { kind = "dropdown", widget = frame.timerControls.rotationWrap },
    { kind = "input", widget = frame.timerControls.xWrap },
    { kind = "input", widget = frame.timerControls.yWrap },
    { kind = "dropdown", widget = frame.timerControls.decimalsWrap },
    { kind = "color", widget = frame.timerControls.colorWrap },
  })
  ApplyTwoColumnSettingsGrid(frame.stacksSection, {
    { kind = "toggle", control = frame.stacksControls.showCheck },
    { kind = "dropdown", widget = frame.stacksControls.fontWrap },
    { kind = "input", widget = frame.stacksControls.sizeWrap },
    { kind = "dropdown", widget = frame.stacksControls.anchorWrap },
    { kind = "dropdown", widget = frame.stacksControls.rotationWrap },
    { kind = "input", widget = frame.stacksControls.xWrap },
    { kind = "input", widget = frame.stacksControls.yWrap },
    { kind = "color", widget = frame.stacksControls.colorWrap },
  })

  ApplyTwoColumnSettingsGrid(frame.soundSection, {
    { kind = "toggle", control = frame.soundEnabledCheck },
    { kind = "toggle", control = frame.soundReadyCheck },
    { kind = "selector", label = frame.soundFileWrap.label, control = frame.soundFileButton, width = 260 },
    { kind = "selector", label = frame.trinketTopSoundFileWrap.label, control = frame.trinketTopSoundFileButton, width = 240 },
    { kind = "selector", label = frame.trinketBottomSoundFileWrap.label, control = frame.trinketBottomSoundFileButton, width = 240 },
    { kind = "dropdown", widget = frame.soundChannelWrap, width = 190 },
    { kind = "selector", label = frame.deathTankSoundWrap.label, control = frame.deathTankSoundButton, width = 210 },
    { kind = "selector", label = frame.deathHealerSoundWrap.label, control = frame.deathHealerSoundButton, width = 210 },
    { kind = "selector", label = frame.deathDPSSoundWrap.label, control = frame.deathDPSSoundButton, width = 210 },
  }, frame.soundHint)

  ApplyTwoColumnSettingsGrid(frame.blizzardSection, {
    { kind = "toggle", control = frame.hideBlizzardSpellAlertCheck },
    { kind = "input", widget = frame.blizzardSpellAlertWrap, width = 230 },
  }, frame.blizzardSpellAlertHint)
end

local function ApplyCompactDisplayLayout(frame, aura, isGroup, isNameplateAura)
  if not frame or not aura then return end

  local useAnchorGear = not isNameplateAura
  frame.anchorGear:ClearAllPoints()
  frame.anchorGear:SetPoint("LEFT", frame.anchorWrap.dropdown, "RIGHT", -8, 0)
  frame.anchorGear:SetShown(useAnchorGear)
  if useAnchorGear then
    SetLabeledDropdownShown(frame.framePointWrap, false)
    SetLabeledDropdownShown(frame.parentPointWrap, false)
    SetLabeledInputShown(frame.xWrap, false)
    SetLabeledInputShown(frame.yWrap, false)
  end

  frame.layerGear:ClearAllPoints()
  frame.layerGear:SetPoint("LEFT", frame.strataWrap.dropdown, "RIGHT", -8, 0)
  frame.layerGear:Show()
  SetLabeledInputShown(frame.levelWrap, false)

  local trigger = GetSelectedTrigger(aura)
  local showGlowGear = trigger.type == "spell_cooldown"
    and aura.kind == "bar"
    and frame.glowWhenActiveCheck:IsShown()
    and frame.glowWhenActiveCheck:GetChecked() == true
  frame.glowGear:SetShown(showGlowGear)
  SetLabeledDropdownShown(frame.activeGlowStyleWrap, false)
  SetColorWidgetShown(frame.activeGlowColorWrap, false)

  local showReadyGear = frame.showAlwaysReadyCheck:IsShown()
    and frame.showAlwaysReadyCheck:GetChecked() == true
  frame.readyGear:SetShown(showReadyGear)
  SetColorWidgetShown(frame.readyColorWrap, false)
  frame.showReadyTextCheck:Hide()

  local showBackgroundGear = frame.showBackgroundCheck:IsShown()
    and frame.showBackgroundCheck:GetChecked() == true
  frame.backgroundGear:SetShown(showBackgroundGear)
  SetColorWidgetShown(frame.backgroundColorWrap, false)

  local showNoStacksGear = frame.noStacksBarColorCheck:IsShown()
    and frame.noStacksBarColorCheck:GetChecked() == true
  frame.noStacksGear:SetShown(showNoStacksGear)
  SetColorWidgetShown(frame.noStacksBarColorWrap, false)

  frame.nameGear:Hide()
  frame.timerGear:Hide()
  frame.stacksGear:Hide()
  ApplyDisplayTwoColumnGrids(frame, aura, isGroup, isNameplateAura)
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
  Frames.ApplyPanelCanvas(frame.content)
  frame:SetScript("OnSizeChanged", function(selfFrame, width)
    frame.content:SetWidth(math.max(724, (tonumber(width) or selfFrame:GetWidth() or 0) - 28))
    if Panel.frame == frame and frame.sectionEntries then
      Panel:LayoutSectionTabs()
      local selectedAura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
      if selectedAura then
        local selectedTrigger = GetSelectedTrigger(selectedAura)
        ApplyDisplayTwoColumnGrids(frame, selectedAura,
          selectedAura.kind == "group" or selectedAura.kind == "dynamic_group",
          selectedAura.kind == "icon" and selectedTrigger.type == "aura" and selectedTrigger.unit == "nameplate")
      end
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
  frame.canvasSection.expandedHeightAura = 590
  frame.canvasSection.expandedHeightGroup = 352
  frame.canvasSection.expandedHeightNameplate = 430
  frame.canvasSection.expandedHeightDeathAlert = 430
  frame.groupSection = CreateSection(frame.content, "Group Layout", -396, 132)
  frame.iconSection = CreateSection(frame.content, "Icon", -560, 270)
  frame.raidFrameSection = CreateSection(frame.content, "Raid Frames", -846, 236)
  frame.nameSection = CreateSection(frame.content, "Name Text", -1050, 290)
  frame.timerSection = CreateSection(frame.content, "Duration Text", -1356, 260)
  frame.stacksSection = CreateSection(frame.content, "Stacks Text", -1632, 220)
  frame.soundSection = CreateSection(frame.content, "Sounds", -1868, 164)
  frame.blizzardSection = CreateSection(frame.content, "Blizzard UI", -2048, 176)

  frame.sectionEntries = {
    { key = "canvas", label = "Look", section = frame.canvasSection },
    { key = "group", label = "Layout", section = frame.groupSection },
    { key = "icon", label = "Icon", section = frame.iconSection },
    { key = "raidFrames", label = "Raid", section = frame.raidFrameSection },
    { key = "name", label = "Name", section = frame.nameSection },
    { key = "timer", label = "Duration", section = frame.timerSection },
    { key = "stacks", label = "Stacks", section = frame.stacksSection },
    { key = "sound", label = "Sounds", section = frame.soundSection },
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
    Theme.ApplyTypography(tab:GetFontString(), "controlSmall")
    Theme.StyleTab(tab, false)
    frame.sectionTabs[entry.key] = tab
  end

  frame.nameInputWrap = CreateLabeledInput(frame.canvasSection, "Aura Name", 12, -34, 420)
  frame.widthWrap = CreateLabeledInput(frame.canvasSection, "Width", 12, -88, 60)
  frame.heightWrap = CreateLabeledInput(frame.canvasSection, "Height", 96, -88, 60)
  frame.widthSlider = Frames.CreateCompactSlider(frame.canvasSection, 20, 1000, 1)
  frame.heightSlider = Frames.CreateCompactSlider(frame.canvasSection, 4, 300, 1)
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
  frame.deathDurationWrap = CreateLabeledInput(frame.canvasSection, "Alert Duration (seconds)", 12, -274, 120)
  frame.deathMaxAlertsWrap = CreateLabeledInput(frame.canvasSection, "Max Alerts / Combat", 180, -274, 120)
  frame.deathRolesLabel = Frames.CreateLabel(frame.canvasSection, "Show Roles", "GameFontNormalSmall", "caption")
  frame.deathRolesLabel:SetPoint("TOPLEFT", 380, -274)
  frame.deathTankCheck = Frames.CreateCheckbox(frame.canvasSection, "Tanks")
  frame.deathTankCheck:SetPoint("TOPLEFT", 380, -296)
  frame.deathHealerCheck = Frames.CreateCheckbox(frame.canvasSection, "Healers")
  frame.deathHealerCheck:SetPoint("TOPLEFT", 490, -296)
  frame.deathDPSCheck = Frames.CreateCheckbox(frame.canvasSection, "DPS")
  frame.deathDPSCheck:SetPoint("TOPLEFT", 610, -296)
  frame.deathAlertHint = Frames.CreateLabel(
    frame.canvasSection,
    "Max Alerts accepts 0 for unlimited alerts during a combat window.",
    "GameFontDisableSmall")
  frame.deathAlertHint:SetPoint("TOPLEFT", 12, -330)
  frame.deathAlertHint:SetWidth(660)

  frame.barColorWrap = CreateColorSwatch(frame.canvasSection, "Bar Color", 12, -284)
  frame.glowWhenActiveCheck = Frames.CreateLabeledToggle(frame.canvasSection, "Glow When Active")
  frame.glowWhenActiveCheck:SetPoint("TOPLEFT", 12, -372)
  frame.activeGlowStyleWrap = CreateLabeledDropdown(frame.canvasSection, "Glow Type", 220, -364, 155, activeGlowStyleValues)
  frame.activeGlowColorWrap = CreateColorSwatch(frame.canvasSection, "Glow Color", 430, -372)
  frame.showAlwaysReadyCheck = Frames.CreateLabeledToggle(frame.canvasSection, "Show While Ready")
  frame.showAlwaysReadyCheck:SetPoint("TOPLEFT", 12, -336)
  frame.readyColorWrap = CreateColorSwatch(frame.canvasSection, "Ready Color", 220, -336)
  frame.showReadyTextCheck = Frames.CreateCheckbox(frame.canvasSection, "Show Ready Text")
  frame.showReadyTextCheck:SetPoint("TOPLEFT", 430, -344)
  frame.barTextureWrap = CreateLabeledDropdown(frame.canvasSection, "Bar Texture", 430, -276, 166, GetBarTextureValues)
  frame.showBackgroundCheck = Frames.CreateLabeledToggle(frame.canvasSection, "Show Background")
  frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -444)
  frame.backgroundColorWrap = CreateColorSwatch(frame.canvasSection, "Background", 220, -444)
  frame.backgroundColorWrap.button:ClearAllPoints()
  frame.backgroundColorWrap.button:SetPoint("TOPLEFT", 220, -444)
  frame.backgroundColorWrap.label:ClearAllPoints()
  frame.backgroundColorWrap.label:SetPoint("LEFT", frame.backgroundColorWrap.button, "RIGHT", 8, 0)
  frame.backgroundGammaWrap = CreateLabeledInput(frame.canvasSection, "Background Gamma", 430, -444, 70)
  frame.permanentAlphaWrap = CreateLabeledInput(frame.canvasSection, "Permanent Aura Alpha", 540, -444, 70)
  frame.auraListSwipeCheck = Frames.CreateCheckbox(
    frame.canvasSection, "Show Cooldown Swipe")
  frame.auraListSwipeCheck:SetPoint("TOPLEFT", 12, -480)
  frame.noStacksBarColorCheck = Frames.CreateLabeledToggle(frame.canvasSection, "Out-of-Stacks Color")
  frame.noStacksBarColorCheck:SetPoint("TOPLEFT", 12, -480)
  frame.noStacksBarColorWrap = CreateColorSwatch(frame.canvasSection, "Color", 220, -472)
  frame.chargeCooldownCheck = Frames.CreateLabeledToggle(
    frame.canvasSection, "Show cooldown while charges remain")
  frame.chargeCooldownCheck:SetPoint("TOPLEFT", 12, -516)
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
  frame.groupMaintainOrderCheck = Frames.CreateCheckbox(frame.groupSection, "Use Configured Aura Order")
  frame.groupMaintainOrderCheck:SetPoint("TOPLEFT", 386, -34)
  frame.groupHint = Frames.CreateLabel(frame.groupSection, "Groups control child size, spacing, order, and growth.", "GameFontDisableSmall")
  frame.groupHint:SetPoint("TOPLEFT", 12, -94)
  frame.groupHint:SetWidth(780)

  frame.showIconCheck = Frames.CreateLabeledToggle(frame.iconSection, "Show Icon")
  frame.showIconCheck:SetPoint("TOPLEFT", 12, -34)
  frame.reverseCheck = Frames.CreateLabeledToggle(frame.canvasSection, "Drain")
  frame.reverseCheck:SetPoint("TOPLEFT", 12, -408)
  frame.hideCDMIconCheck = Frames.CreateLabeledToggle(frame.iconSection, "Hide CDM Icon")
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

  frame.showOnRaidFramesCheck = Frames.CreateLabeledToggle(frame.raidFrameSection, "Show on Raid Frames")
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

  frame.soundEnabledCheck = Frames.CreateLabeledToggle(frame.soundSection, "Play Aura Sound")
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
  local function CreateDeathRoleSoundSelector(label, x, title)
    local wrap = CreateLabeledDropdown(frame.soundSection, label, x, -68, 196, GetSoundDropdownValues)
    wrap.dropdown:Hide()
    local button = Frames.CreateSelectorButton(frame.soundSection, 196, 24)
    button:SetPoint("TOPLEFT", wrap.label, "BOTTOMLEFT", 0, -6)
    button:SetScript("OnClick", function()
      if not SoundPicker then
        return
      end
      SoundPicker:Toggle(button, wrap.dropdown, GetSoundDropdownValues, {
        title = title,
        onChanged = function()
          UpdateSelectorButtonText(button, wrap.dropdown)
          Panel:ApplyCurrent()
        end,
      })
    end)
    return wrap, button
  end
  frame.deathTankSoundWrap, frame.deathTankSoundButton = CreateDeathRoleSoundSelector(
    "Tank", 12, "Select Tank Death Sound")
  frame.deathHealerSoundWrap, frame.deathHealerSoundButton = CreateDeathRoleSoundSelector(
    "Healer", 244, "Select Healer Death Sound")
  frame.deathDPSSoundWrap, frame.deathDPSSoundButton = CreateDeathRoleSoundSelector(
    "DPS", 476, "Select DPS Death Sound")
  frame.soundHint = Frames.CreateLabel(frame.soundSection, "Choose whether the sound plays when the aura activates or when it becomes ready/off cooldown. The picker is scrollable and color-codes sounds by source pack. Use %m in text auras if you want the matched chat message rendered.", "GameFontDisableSmall")
  frame.soundHint:SetPoint("TOPLEFT", 12, -146)
  frame.soundHint:SetWidth(720)

  frame.hideBlizzardSpellAlertCheck = Frames.CreateLabeledToggle(frame.blizzardSection, "Hide Blizzard Spell Alert")
  frame.hideBlizzardSpellAlertCheck:SetPoint("TOPLEFT", 12, -34)
  frame.blizzardSpellAlertWrap = CreateLabeledInput(frame.blizzardSection, "Spell Name or ID", 12, -70, 280)
  frame.blizzardSpellAlertHint = Frames.CreateLabel(frame.blizzardSection, "", "GameFontDisableSmall")
  frame.blizzardSpellAlertHint:SetPoint("TOPLEFT", 12, -132)
  frame.blizzardSpellAlertHint:SetWidth(700)
  frame.blizzardSpellAlertHint:SetJustifyH("LEFT")

  frame.nameControls = CreateTwoColumnTextSection(frame.nameSection, -34, "Name", true)
  frame.timerControls = CreateTwoColumnTextSection(frame.timerSection, -34, "Duration")
  frame.stacksControls = CreateTwoColumnTextSection(frame.stacksSection, -34, "Stack Count")
  frame.nameplateMaxAurasWrap = CreateLabeledInput(frame.canvasSection, "Maximum Icons per Nameplate", 310, -150, 72)
  frame.timerControls.decimalsWrap = CreateLabeledDropdown(frame.timerSection, "Decimals", 150, -190, 120, { "0", "1", "2" })
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
    frame.nameplateMaxAurasWrap.label, frame.nameplateMaxAurasWrap.input,
    frame.strataWrap.label, frame.strataWrap.dropdown,
    frame.levelWrap.label, frame.levelWrap.input,
    frame.deathDurationWrap.label, frame.deathDurationWrap.input,
    frame.deathMaxAlertsWrap.label, frame.deathMaxAlertsWrap.input,
    frame.deathRolesLabel,
    frame.deathTankCheck, frame.deathHealerCheck, frame.deathDPSCheck,
    frame.deathAlertHint,
    frame.barColorWrap.label, frame.barColorWrap.button, frame.barColorWrap.valueText,
    frame.noStacksBarColorCheck,
    frame.noStacksBarColorWrap.label, frame.noStacksBarColorWrap.button, frame.noStacksBarColorWrap.valueText,
    frame.chargeCooldownCheck,
    frame.glowWhenActiveCheck,
    frame.activeGlowStyleWrap.label, frame.activeGlowStyleWrap.dropdown,
    frame.activeGlowColorWrap.label, frame.activeGlowColorWrap.button, frame.activeGlowColorWrap.valueText,
    frame.showAlwaysReadyCheck,
    frame.showReadyTextCheck,
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
    frame.timerControls.decimalsWrap.label, frame.timerControls.decimalsWrap.dropdown
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
    frame.deathTankSoundWrap.label, frame.deathTankSoundButton,
    frame.deathHealerSoundWrap.label, frame.deathHealerSoundButton,
    frame.deathDPSSoundWrap.label, frame.deathDPSSoundButton,
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

  ConfigureNumericInput(frame.widthWrap.input, 4)
  ConfigureNumericInput(frame.heightWrap.input, 3)
  ConfigureNumericInput(frame.xWrap.input, 10)
  ConfigureNumericInput(frame.yWrap.input, 10)
  ConfigureNumericInput(frame.levelWrap.input, 5)
  ConfigureNumericInput(frame.deathDurationWrap.input, 6)
  ConfigureNumericInput(frame.deathMaxAlertsWrap.input, 2)
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
  ConfigureNumericInput(frame.nameplateMaxAurasWrap.input, 1)
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
  CreateDisplayGearControls(frame)

  self:WireLiveInput(frame.nameInputWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.widthWrap.input, function()
    Panel:ApplyCurrent()
    frame._popAurasSyncingSliders = true
    frame.widthSlider:SetValue(tonumber(frame.widthWrap.input:GetText()) or 220)
    frame._popAurasSyncingSliders = false
  end)
  self:WireLiveInput(frame.heightWrap.input, function()
    Panel:ApplyCurrent()
    frame._popAurasSyncingSliders = true
    frame.heightSlider:SetValue(tonumber(frame.heightWrap.input:GetText()) or 32)
    frame._popAurasSyncingSliders = false
  end)
  frame.widthSlider:SetScript("OnValueChanged", function(_, value)
    if frame._popAurasSyncingSliders or Panel.suppressUpdates then return end
    frame.widthWrap.input:SetText(tostring(math.floor((value or 20) + 0.5)))
    Panel:ApplyCurrent()
  end)
  frame.heightSlider:SetScript("OnValueChanged", function(_, value)
    if frame._popAurasSyncingSliders or Panel.suppressUpdates then return end
    frame.heightWrap.input:SetText(tostring(math.floor((value or 4) + 0.5)))
    Panel:ApplyCurrent()
  end)
  self:WireLiveInput(frame.xWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.yWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.levelWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.deathDurationWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.deathMaxAlertsWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.backgroundGammaWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.permanentAlphaWrap.input, function() Panel:ApplyCurrent() end)
  self:WireLiveInput(frame.nameplateMaxAurasWrap.input, function() Panel:ApplyCurrent() end)
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
  self:WireLiveCheckbox(frame.noStacksBarColorCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.chargeCooldownCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.glowWhenActiveCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.showAlwaysReadyCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.groupMaintainOrderCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.soundEnabledCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.soundReadyCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.deathTankCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.deathHealerCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.deathDPSCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.nameControls.showCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.timerControls.showCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.showReadyTextCheck, function() Panel:ApplyCurrent() end)
  self:WireLiveCheckbox(frame.stacksControls.showCheck, function() Panel:ApplyCurrent() end)

  InitDropdownWithCallback(frame.strataWrap.dropdown, strataValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.orientationWrap.dropdown, { "HORIZONTAL", "VERTICAL" }, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.framePointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.parentPointWrap.dropdown, Anchors.GetPointList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.anchorWrap.dropdown, Anchors.GetTargetList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.nameplateAnchorWrap.dropdown, Anchors.GetNameplateAnchorList, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.barTextureWrap.dropdown, GetBarTextureValues, function() Panel:ApplyCurrent() end)
  if frame.barTextureWrap.dropdown.Button and TexturePicker then
    -- UIDropDownMenuTemplate opens its stock menu on mouse-down. Keep the
    -- dropdown only as the saved-value/display adapter and put one release-
    -- only hit target above it so Bar Texture has a single menu authority.
    frame.barTextureWrap.dropdown.Button:EnableMouse(false)
    frame.barTexturePickerHitBox = CreateFrame("Button", nil, frame.barTextureWrap.dropdown)
    frame.barTexturePickerHitBox:SetAllPoints(frame.barTextureWrap.dropdown)
    frame.barTexturePickerHitBox:SetFrameLevel(frame.barTextureWrap.dropdown:GetFrameLevel() + 20)
    frame.barTexturePickerHitBox:RegisterForClicks("LeftButtonUp")
    frame.barTexturePickerHitBox:SetScript("OnClick", function()
      TexturePicker:Toggle(frame.barTextureWrap.dropdown, frame.barTextureWrap.dropdown, GetBarTextureValues, {
        title = "Select Bar Texture",
        onChanged = function() Panel:ApplyCurrent() end,
      })
    end)
  end
  InitDropdownWithCallback(frame.activeGlowStyleWrap.dropdown, activeGlowStyleValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.groupGrowthWrap.dropdown, { "DOWN", "UP", "RIGHT", "LEFT" }, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.iconAnchorWrap.dropdown, iconAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.raidFrameAnchorWrap.dropdown, raidFrameAnchorValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.raidFrameGrowthWrap.dropdown, raidFrameGrowthValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.soundFileWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.trinketTopSoundFileWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.trinketBottomSoundFileWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.deathTankSoundWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.deathHealerSoundWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
  InitDropdownWithCallback(frame.deathDPSSoundWrap.dropdown, GetSoundDropdownValues, function() Panel:ApplyCurrent() end)
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
  WireColor(frame.activeGlowColorWrap, { r = 1.00, g = 0.82, b = 0.08, a = 1 })

  return frame
end

function Panel:ApplyCanvasLayout(isGroup, isNameplateAura, isIconAura, isDeathAlert)
  if not self.frame then
    return
  end

  local frame = self.frame

  SetIconAppearanceParent(frame, isIconAura and frame.canvasSection or frame.iconSection)

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

    frame.showIconCheck:ClearAllPoints()
    frame.showIconCheck:SetPoint("TOPLEFT", 12, -274)
    frame.reverseCheck:ClearAllPoints()
    frame.reverseCheck:SetPoint("TOPLEFT", 180, -274)
    frame.iconEdgeCheck:ClearAllPoints()
    frame.iconEdgeCheck:SetPoint("TOPLEFT", 12, -326)
    frame.iconFinishFlashCheck:ClearAllPoints()
    frame.iconFinishFlashCheck:SetPoint("TOPLEFT", 220, -326)
    PositionColorSwatch(frame.iconSwipeColorWrap, 410, -326)
    frame.iconHint:ClearAllPoints()
    frame.iconHint:SetPoint("TOPLEFT", 12, -374)
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

  if isDeathAlert then
    PositionLabeledInput(frame.deathDurationWrap, 12, -274)
    PositionLabeledInput(frame.deathMaxAlertsWrap, 180, -274)
    frame.deathRolesLabel:ClearAllPoints()
    frame.deathRolesLabel:SetPoint("TOPLEFT", 380, -274)
    frame.deathTankCheck:ClearAllPoints()
    frame.deathTankCheck:SetPoint("TOPLEFT", 380, -296)
    frame.deathHealerCheck:ClearAllPoints()
    frame.deathHealerCheck:SetPoint("TOPLEFT", 490, -296)
    frame.deathDPSCheck:ClearAllPoints()
    frame.deathDPSCheck:SetPoint("TOPLEFT", 610, -296)
    frame.deathAlertHint:ClearAllPoints()
    frame.deathAlertHint:SetPoint("TOPLEFT", 12, -330)
    frame.showBackgroundCheck:ClearAllPoints()
    frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -370)
    PositionColorSwatch(frame.backgroundColorWrap, 220, -370)
    return
  end

  if isIconAura then
    frame.showIconCheck:ClearAllPoints()
    frame.showIconCheck:SetPoint("TOPLEFT", 12, -274)
    frame.hideCDMIconCheck:ClearAllPoints()
    frame.hideCDMIconCheck:SetPoint("TOPLEFT", 190, -274)
    PositionLabeledInput(frame.altIconIdWrap, 390, -266)

    frame.reverseCheck:ClearAllPoints()
    frame.reverseCheck:SetPoint("TOPLEFT", 12, -330)
    frame.iconEdgeCheck:ClearAllPoints()
    frame.iconEdgeCheck:SetPoint("TOPLEFT", 220, -330)
    frame.iconFinishFlashCheck:ClearAllPoints()
    frame.iconFinishFlashCheck:SetPoint("TOPLEFT", 410, -330)
    PositionColorSwatch(frame.iconSwipeColorWrap, 560, -330)

    PositionColorSwatch(frame.readyColorWrap, 220, -382)
    frame.showReadyTextCheck:ClearAllPoints()
    frame.showReadyTextCheck:SetPoint("TOPLEFT", 430, -390)
    frame.showAlwaysReadyCheck:ClearAllPoints()
    frame.showAlwaysReadyCheck:SetPoint("TOPLEFT", 12, -382)
    frame.glowWhenActiveCheck:ClearAllPoints()
    frame.glowWhenActiveCheck:SetPoint("TOPLEFT", 12, -430)
    PositionLabeledDropdown(frame.activeGlowStyleWrap, 220, -422)
    PositionColorSwatch(frame.activeGlowColorWrap, 430, -430)
    frame.chargeCooldownCheck:ClearAllPoints()
    frame.chargeCooldownCheck:SetPoint("TOPLEFT", 12, -478)
    frame.iconHint:ClearAllPoints()
    frame.iconHint:SetPoint("TOPLEFT", 12, -526)
    return
  end

  PositionColorSwatch(frame.barColorWrap, 12, -284)
  PositionLabeledDropdown(frame.barTextureWrap, 430, -276)
  PositionColorSwatch(frame.readyColorWrap, 220, -336)
  frame.showReadyTextCheck:ClearAllPoints()
  frame.showReadyTextCheck:SetPoint("TOPLEFT", 430, -344)
  frame.glowWhenActiveCheck:ClearAllPoints()
  frame.glowWhenActiveCheck:SetPoint("TOPLEFT", 12, -372)
  PositionLabeledDropdown(frame.activeGlowStyleWrap, 220, -364)
  PositionColorSwatch(frame.activeGlowColorWrap, 430, -372)
  frame.showAlwaysReadyCheck:ClearAllPoints()
  frame.showAlwaysReadyCheck:SetPoint("TOPLEFT", 12, -336)
  frame.reverseCheck:ClearAllPoints()
  frame.reverseCheck:SetPoint("TOPLEFT", 12, -408)

  frame.showBackgroundCheck:ClearAllPoints()
  frame.showBackgroundCheck:SetPoint("TOPLEFT", 12, -444)
  PositionColorSwatch(frame.backgroundColorWrap, 220, -444)
  PositionLabeledInput(frame.backgroundGammaWrap, 430, -444)
  PositionLabeledInput(frame.permanentAlphaWrap, 540, -444)
  frame.auraListSwipeCheck:ClearAllPoints()
  frame.auraListSwipeCheck:SetPoint("TOPLEFT", 12, -480)
  frame.noStacksBarColorCheck:ClearAllPoints()
  frame.noStacksBarColorCheck:SetPoint("TOPLEFT", 12, -480)
  PositionColorSwatch(frame.noStacksBarColorWrap, 220, -472)
  frame.chargeCooldownCheck:ClearAllPoints()
  frame.chargeCooldownCheck:SetPoint("TOPLEFT", 12, -516)
end

function Panel:ApplyIconLayout(isIconAura)
  local frame = self.frame
  if not frame then
    return
  end

  if isIconAura then
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
      tab:SetSize(tabWidth, Theme.layout.secondaryTabHeight)
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

  self.frame.activeSectionKey = key or "canvas"
  for _, entry in ipairs(self.frame.sectionEntries) do
    local isEmbeddedLayout = self.frame.embedLayoutInLook == true
      and entry.key == "group"
    local isAvailable = entry.section._popAurasAvailable ~= false or isEmbeddedLayout
    entry.section.collapsed = false
    entry.section:SetShown(isAvailable)
    entry.section.header:SetShown(isAvailable)
    if entry.section.bodyTop then entry.section.bodyTop:SetShown(isAvailable) end
    local tab = self.frame.sectionTabs[entry.key]
    if tab then tab:Hide() end
  end

  self:LayoutSections()
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
      y = y - section:GetHeight() - 22
    end
  end
  local minHeight = self.frame:GetHeight() > 0 and self.frame:GetHeight() or 640
  self.frame.content:SetHeight(math.max(minHeight, math.abs(y) + 28))
end

function Panel:Refresh(aura)
  self.suppressUpdates = true
  local isGroup = aura.kind == "group" or aura.kind == "dynamic_group"
  local isDynamicGroup = aura.kind == "dynamic_group"
  local isText = aura.kind == "text"
  local isIconAura = aura.kind == "icon"
  local isAuraBarList = aura.kind == "aura_bar_list"
  local trigger = GetSelectedTrigger(aura)
  local isDeathAlert = trigger.type == "death_alert"
  local isNameplateAura = isIconAura and trigger.type == "aura" and trigger.unit == "nameplate"
  local usesLayoutSection = isGroup or isAuraBarList or isNameplateAura
  local supportsShowAlways = not isNameplateAura and (
    trigger.type == "spell_cooldown" or trigger.type == "item_cooldown"
      or trigger.type == "trinket_cooldown" or trigger.type == "aura")
  local supportsReadyText = trigger.type == "spell_cooldown" or trigger.type == "item_cooldown"
    or trigger.type == "trinket_cooldown"

  self.frame.nameInputWrap.input:SetText(aura.name or "")
  self.frame.widthWrap.input:SetText(tostring(aura.display.width or 220))
  self.frame._popAurasSyncingSliders = true
  self.frame.widthSlider:SetValue(math.max(20, math.min(1000, aura.display.width or 220)))
  self.frame.heightSlider:SetValue(math.max(4, math.min(300, aura.display.height or 32)))
  self.frame._popAurasSyncingSliders = false
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
  RefreshDropdown(self.frame.deathTankSoundWrap.dropdown)
  RefreshDropdown(self.frame.deathHealerSoundWrap.dropdown)
  RefreshDropdown(self.frame.deathDPSSoundWrap.dropdown)
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
  self.frame.chargeCooldownCheck:SetChecked(trigger.showChargeCooldown ~= false)
  local savedActiveGlowStyle = aura.display.activeGlowStyle or "NONE"
  local activeGlowEnabled = aura.display.glowWhenActive == true or savedActiveGlowStyle ~= "NONE"
  self.frame.glowWhenActiveCheck:SetChecked(activeGlowEnabled)
  if self.frame.glowWhenActiveCheck.Text then
    self.frame.glowWhenActiveCheck.Text:SetText(
      trigger.type == "trinket_cooldown" and "Glow While Trinket Buff Active" or "Glow When Active")
  end
  SetDropdown(self.frame.activeGlowStyleWrap.dropdown,
    savedActiveGlowStyle ~= "NONE" and savedActiveGlowStyle or "INNER_GLOW")
  SetColorSwatch(self.frame.activeGlowColorWrap,
    aura.display.activeGlowColor or { r = 1.00, g = 0.82, b = 0.08, a = 1 })
  self.frame.showAlwaysReadyCheck:SetChecked(
    trigger.showAlways == true or aura.display.readyLook == true)
  if self.frame.showAlwaysReadyCheck.Text then
    if trigger.type == "aura" then
      if trigger.auraFilter == "missing" then
        self.frame.showAlwaysReadyCheck.Text:SetText("Show While Present")
        self.frame.readyColorWrap.label:SetText("Present Color")
      else
        self.frame.showAlwaysReadyCheck.Text:SetText("Show While Missing")
        self.frame.readyColorWrap.label:SetText("Missing Color")
      end
    elseif trigger.cooldownMatch == "ready" then
      self.frame.showAlwaysReadyCheck.Text:SetText("Use Ready Appearance")
      self.frame.readyColorWrap.label:SetText("Ready Color")
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
  if TexturePicker then TexturePicker:RefreshIfOpen(self.frame.barTextureWrap.dropdown) end
  self.frame.showBackgroundCheck:SetChecked(aura.display.showBackground ~= false)
  SetColorSwatch(self.frame.backgroundColorWrap, aura.display.backgroundColor or { r = 0, g = 0, b = 0, a = 0.45 })
  self.frame.backgroundGammaWrap.input:SetText(tostring(aura.display.backgroundGamma or 1))
  self.frame.permanentAlphaWrap.input:SetText(string.format("%.2f", tonumber(aura.display.permanentAlpha or 0.25) or 0.25))
  self.frame.nameplateMaxAurasWrap.input:SetText(
    isNameplateAura and tostring(trigger.nameplateMaxAuras or 3) or "")
  self.frame.deathDurationWrap.input:SetText(isDeathAlert and tostring(trigger.alertDuration or 2) or "")
  self.frame.deathMaxAlertsWrap.input:SetText(
    isDeathAlert and tostring(NormalizeDeathAlertCap(trigger.maxAlertsPerCombat)) or "")
  self.frame.deathTankCheck:SetChecked(trigger.showTank ~= false)
  self.frame.deathHealerCheck:SetChecked(trigger.showHealer ~= false)
  self.frame.deathDPSCheck:SetChecked(trigger.showDPS ~= false)
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
  if isDeathAlert then
    self.frame.soundEnabledCheck:SetChecked(trigger.deathSoundEnabled == true)
  else
    self.frame.soundEnabledCheck:SetChecked(aura.display.soundEnabled == true)
  end
  if self.frame.soundEnabledCheck.Text then
    self.frame.soundEnabledCheck.Text:SetText(isDeathAlert and "Enable Sounds" or "Play Aura Sound")
  end
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
  SetDropdown(self.frame.deathTankSoundWrap.dropdown, trigger.soundTank or "None")
  UpdateSelectorButtonText(self.frame.deathTankSoundButton, self.frame.deathTankSoundWrap.dropdown)
  SetDropdown(self.frame.deathHealerSoundWrap.dropdown, trigger.soundHealer or "None")
  UpdateSelectorButtonText(self.frame.deathHealerSoundButton, self.frame.deathHealerSoundWrap.dropdown)
  SetDropdown(self.frame.deathDPSSoundWrap.dropdown, trigger.soundDPS or "None")
  UpdateSelectorButtonText(self.frame.deathDPSSoundButton, self.frame.deathDPSSoundWrap.dropdown)
  SetDropdown(self.frame.soundChannelWrap.dropdown, aura.display.soundChannel or "Master")
  if SoundPicker then
    SoundPicker:RefreshIfOpen(self.frame.soundFileWrap.dropdown)
    SoundPicker:RefreshIfOpen(self.frame.trinketTopSoundFileWrap.dropdown)
    SoundPicker:RefreshIfOpen(self.frame.trinketBottomSoundFileWrap.dropdown)
    SoundPicker:RefreshIfOpen(self.frame.deathTankSoundWrap.dropdown)
    SoundPicker:RefreshIfOpen(self.frame.deathHealerSoundWrap.dropdown)
    SoundPicker:RefreshIfOpen(self.frame.deathDPSSoundWrap.dropdown)
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
  self.frame.showReadyTextCheck:SetChecked(aura.display.hideReadyTimer ~= true)
  self.frame.showReadyTextCheck:SetShown(supportsReadyText and not isAuraBarList and not isNameplateAura)

  self.frame.stacksControls.showCheck:SetChecked(aura.display.showStacks == true)
  SetDropdown(self.frame.stacksControls.fontWrap.dropdown, aura.display.stacksFontStyle or "FRIZQT_OUTLINE")
  self.frame.stacksControls.sizeWrap.input:SetText(tostring(aura.display.stacksFontSize or 14))
  SetDropdown(self.frame.stacksControls.rotationWrap.dropdown, tostring(aura.display.stacksRotation or 0))
  SetDropdown(self.frame.stacksControls.anchorWrap.dropdown, aura.display.stacksAnchor or "TOPRIGHT")
  self.frame.stacksControls.xWrap.input:SetText(tostring(aura.display.stacksOffsetX or 0))
  self.frame.stacksControls.yWrap.input:SetText(tostring(aura.display.stacksOffsetY or 0))
  SetColorSwatch(self.frame.stacksControls.colorWrap, aura.display.stacksColor or { r = 1, g = 1, b = 1, a = 1 })

  self.frame.canvasSection._popAurasAvailable = true
  self.frame.embedLayoutInLook = isAuraBarList
  self.frame.groupSection._popAurasAvailable = usesLayoutSection and not isAuraBarList
  self.frame.iconSection._popAurasAvailable = not isGroup and not isText and not isIconAura
  self.frame.raidFrameSection._popAurasAvailable = false
  self.frame.nameSection._popAurasAvailable = not isGroup
  self.frame.timerSection._popAurasAvailable = not isGroup and not isText
  self.frame.stacksSection._popAurasAvailable = not isGroup and not isText
  self.frame.soundSection._popAurasAvailable = not isGroup
    and not isAuraBarList
    and not isNameplateAura
  self.frame.blizzardSection._popAurasAvailable = not isGroup and not isNameplateAura
  if isGroup or isAuraBarList or isNameplateAura then
    HideAllSoundPickers(self.frame)
  end

  self.frame.canvasSection.expandedHeight = isGroup
      and self.frame.canvasSection.expandedHeightGroup
      or isNameplateAura
        and self.frame.canvasSection.expandedHeightNameplate
        or isDeathAlert
          and self.frame.canvasSection.expandedHeightDeathAlert
          or self.frame.canvasSection.expandedHeightAura
  self.frame.canvasSection:SetHeight(self.frame.canvasSection.expandedHeight)
  local dualTrinketSounds = UsesDualTrinketSounds(aura)
  self.frame.soundSection.expandedHeight = dualTrinketSounds and 226 or 164
  self.frame.soundHint:ClearAllPoints()
  self.frame.soundHint:SetPoint("TOPLEFT", 12, isDeathAlert and -130 or dualTrinketSounds and -208 or -146)
  self.frame.soundHint:SetText(isDeathAlert
    and "Choose a distinct alert sound for each enabled group role."
    or "Choose whether the sound plays when the aura activates or when it becomes ready/off cooldown. The picker is scrollable and color-codes sounds by source pack. Use %m in text auras if you want the matched chat message rendered.")
  self:ApplyIconLayout(isIconAura)

  self.frame.orientationWrap.label:SetShown(not isGroup and not isText and not isIconAura and not isNameplateAura)
  self.frame.orientationWrap.dropdown:SetShown(not isGroup and not isText and not isIconAura and not isNameplateAura)
  self.frame.anchorWrap.label:SetShown(not isNameplateAura)
  self.frame.anchorWrap.dropdown:SetShown(not isNameplateAura)
  self.frame.framePointWrap.label:SetShown(not isNameplateAura)
  self.frame.framePointWrap.dropdown:SetShown(not isNameplateAura)
  self.frame.parentPointWrap.label:SetShown(not isNameplateAura)
  self.frame.parentPointWrap.dropdown:SetShown(not isNameplateAura)
  self.frame.nameplateAnchorWrap.label:SetShown(isNameplateAura)
  self.frame.nameplateAnchorWrap.dropdown:SetShown(isNameplateAura)
  self.frame.nameplateMaxAurasWrap.label:SetShown(isNameplateAura)
  self.frame.nameplateMaxAurasWrap.input:SetShown(isNameplateAura)
  self.frame.strataWrap.label:SetShown(true)
  self.frame.strataWrap.dropdown:SetShown(true)
  self.frame.levelWrap.label:SetShown(true)
  self.frame.levelWrap.input:SetShown(true)
  SetControlGroupShown({
    self.frame.deathDurationWrap.label, self.frame.deathDurationWrap.input,
    self.frame.deathMaxAlertsWrap.label, self.frame.deathMaxAlertsWrap.input,
    self.frame.deathRolesLabel,
    self.frame.deathTankCheck, self.frame.deathHealerCheck, self.frame.deathDPSCheck,
    self.frame.deathAlertHint,
  }, isDeathAlert)
  self.frame.barColorWrap.label:SetShown(not isGroup and not isText and not isIconAura and not isNameplateAura)
  self.frame.barColorWrap.button:SetShown(not isGroup and not isText and not isIconAura and not isNameplateAura)
  self.frame.barColorWrap.valueText:SetShown(not isGroup and not isText and not isIconAura and not isNameplateAura)
  local showNoStacksColor = trigger.type == "spell_cooldown" and aura.kind == "bar"
  self.frame.noStacksBarColorCheck:SetShown(showNoStacksColor)
  self.frame.noStacksBarColorWrap.label:SetShown(showNoStacksColor)
  self.frame.noStacksBarColorWrap.button:SetShown(showNoStacksColor)
  self.frame.noStacksBarColorWrap.valueText:SetShown(showNoStacksColor)
  self.frame.chargeCooldownCheck:SetShown(
    trigger.type == "spell_cooldown" and not isGroup and not isText and not isNameplateAura)
  local showActiveGlowStyle = trigger.type == "spell_cooldown" and aura.kind == "bar"
  local activeGlowEnabled = self.frame.glowWhenActiveCheck:GetChecked() == true
  local selectedActiveGlowStyle = UIDropDownMenu_GetSelectedValue(self.frame.activeGlowStyleWrap.dropdown)
    or "INNER_GLOW"
  self.frame.glowWhenActiveCheck:SetShown(
    not isGroup and not isText and not isAuraBarList and not isNameplateAura)
  self.frame.activeGlowStyleWrap.label:SetShown(showActiveGlowStyle and activeGlowEnabled)
  self.frame.activeGlowStyleWrap.dropdown:SetShown(showActiveGlowStyle and activeGlowEnabled)
  local showActiveGlowColor = showActiveGlowStyle and activeGlowEnabled
    and selectedActiveGlowStyle ~= "ACTIVE_DURATION"
  self.frame.activeGlowColorWrap.label:SetShown(showActiveGlowColor)
  self.frame.activeGlowColorWrap.button:SetShown(showActiveGlowColor)
  self.frame.activeGlowColorWrap.valueText:SetShown(showActiveGlowColor)
  self.frame.showAlwaysReadyCheck:SetShown(not isGroup and not isText and supportsShowAlways)
  self.frame.reverseCheck:SetShown(not isGroup and not isText)
  local showReadyStateOptions = self.frame.showAlwaysReadyCheck:GetChecked() == true
    and supportsShowAlways and not isGroup and not isText and not isNameplateAura
  self.frame.readyColorWrap.label:SetShown(showReadyStateOptions)
  self.frame.readyColorWrap.button:SetShown(showReadyStateOptions)
  self.frame.readyColorWrap.valueText:SetShown(showReadyStateOptions)
  self.frame.showReadyTextCheck:SetShown(showReadyStateOptions and supportsReadyText
    and aura.display.showTimer == true)
  self.frame.barTextureWrap.label:SetShown(not isGroup and not isText and not isIconAura and not isNameplateAura)
  self.frame.barTextureWrap.dropdown:SetShown(not isGroup and not isText and not isIconAura and not isNameplateAura)
  local showBackgroundControls = not isIconAura or isNameplateAura
  self.frame.showBackgroundCheck:SetShown(showBackgroundControls)
  self.frame.backgroundColorWrap.label:SetShown(showBackgroundControls)
  self.frame.backgroundColorWrap.button:SetShown(showBackgroundControls)
  self.frame.backgroundColorWrap.valueText:SetShown(showBackgroundControls)
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
  self.frame.iconSizeWrap.label:SetShown(not isIconAura and not isNameplateAura)
  self.frame.iconSizeWrap.input:SetShown(not isIconAura and not isNameplateAura)
  self.frame.iconAnchorWrap.label:SetShown(not isIconAura and not isNameplateAura)
  self.frame.iconAnchorWrap.dropdown:SetShown(not isIconAura and not isNameplateAura)
  self.frame.iconXWrap.label:SetShown(not isIconAura and not isNameplateAura)
  self.frame.iconXWrap.input:SetShown(not isIconAura and not isNameplateAura)
  self.frame.iconYWrap.label:SetShown(not isIconAura and not isNameplateAura)
  self.frame.iconYWrap.input:SetShown(not isIconAura and not isNameplateAura)
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
  self.frame.groupMaintainOrderCheck:SetShown(isDynamicGroup)
  self.frame.groupSection.title:SetText(isAuraBarList and "List Layout"
    or isNameplateAura and "Nameplate Icon Layout" or "Group Layout")
  self.frame.groupSection.header:Show()
  self.frame.groupSection.bodyTop:Show()
  if isAuraBarList then
    Theme.StyleSurface(self.frame.groupSection.header, "transparent", "transparent")
    self.frame.groupSection.title:SetText("LAYOUT")
    Theme.SetText(self.frame.groupSection.title, "groupAccent")
    Theme.SetTexture(self.frame.groupSection.bodyTop, "border")
    self.frame.groupSection:SetHeight(162)
  else
    Theme.SetText(self.frame.groupSection.title, "text")
    self.frame.groupSection:SetHeight(132)
  end
  if isAuraBarList then
    self.frame.groupHint:SetText("Control the spacing and growth direction for the buff/debuff bar list.")
  elseif isNameplateAura then
    self.frame.groupHint:SetText("Control spacing and growth for matching native buff icons on each hostile NPC nameplate.")
  else
    self.frame.groupHint:SetText(isDynamicGroup
      and "Dynamic Groups remove hidden children from the layout. Configured order keeps the first visible child at the top."
      or "Groups reserve a fixed slot for every child, so hidden children do not move the remaining auras.")
  end
  self.frame.iconSection.title:SetText(isAuraBarList and "Row Icon" or "Icon")
  self.frame.blizzardSection.title:SetText("Blizzard UI")

  for _, toggle in ipairs({
    self.frame.showBackgroundCheck,
    self.frame.glowWhenActiveCheck,
    self.frame.noStacksBarColorCheck,
    self.frame.chargeCooldownCheck,
    self.frame.reverseCheck,
    self.frame.showAlwaysReadyCheck,
    self.frame.showIconCheck,
    self.frame.hideCDMIconCheck,
    self.frame.showOnRaidFramesCheck,
    self.frame.nameControls.showCheck,
    self.frame.timerControls.showCheck,
    self.frame.stacksControls.showCheck,
    self.frame.soundEnabledCheck,
    self.frame.hideBlizzardSpellAlertCheck,
  }) do
    Theme.UpdateToggle(toggle)
  end

  self:ApplyCanvasLayout(isGroup, isNameplateAura, isIconAura, trigger.type == "death_alert")
  self:UpdateControlStates()
  ApplyCompactDisplayLayout(self.frame, aura, isGroup, isNameplateAura)
  self:SetActiveSection(self.frame.activeSectionKey or "canvas")
  self.suppressUpdates = false
end
