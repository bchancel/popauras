local _, ns = ...

local Frames = ns.util.Frames

local triggerTypes = {
  simple = "Simple",
  aura = "Aura",
  spell_cooldown = "Spell Cooldown",
  item_cooldown = "Item Cooldown",
  cast = "Cast / Channel",
  timer = "Internal Timer",
  death_alert = "Death Alert",
}

local Panel = {}
ns.panels.TriggerPanel = Panel

local auraTypeValues = {
  { value = "buff", label = "Buff" },
  { value = "debuff", label = "Debuff" },
}

local auraFilterValues = {
  { value = "present", label = "When Present" },
  { value = "missing", label = "When Missing" },
}

local auraUnitValues = {
  { value = "player", label = "Player" },
  { value = "target", label = "Target" },
  { value = "group", label = "Party / Raid" },
  { value = "nameplate", label = "Nameplate" },
}

local function GetSoundDropdownValues()
  local values = {
    { value = "None", label = "None" },
  }
  if ns.Interrupts and ns.Interrupts.GetSoundOptions then
    for _, entry in ipairs(ns.Interrupts:GetSoundOptions() or {}) do
      local name = entry and entry.name
      if name and name ~= "None" then
        values[#values + 1] = { value = name, label = entry.label or name }
      end
    end
  end
  return values
end

local function GetDropdownOptionLabel(value, valuesProvider)
  local label = tostring(value or "")
  for _, option in ipairs(valuesProvider()) do
    if option.value == value then
      return option.label
    end
  end
  return label
end

local function InitDropdownValues(dropdown, valuesProvider, onChanged)
  UIDropDownMenu_Initialize(dropdown, function(self, level)
    for _, option in ipairs(valuesProvider()) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dropdown, option.value)
        UIDropDownMenu_SetText(dropdown, option.label)
        if onChanged then
          onChanged(option.value)
        end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end

local function SetDropdownValue(dropdown, value, valuesProvider)
  UIDropDownMenu_SetSelectedValue(dropdown, value)
  local label = tostring(value or "")
  for _, option in ipairs(valuesProvider()) do
    if option.value == value then
      label = option.label
      break
    end
  end
  UIDropDownMenu_SetText(dropdown, label)
end

local function GetSelectedDropdownValue(dropdown, fallback)
  return UIDropDownMenu_GetSelectedValue(dropdown) or fallback
end

local function PlayPreviewSound(dropdown)
  local soundName = GetSelectedDropdownValue(dropdown, "None")
  if ns.Interrupts and ns.Interrupts.PlaySound then
    ns.Interrupts:PlaySound(soundName)
  end
end

local function UpdateSoundPreviewButton(button, dropdown)
  if not button then
    return
  end

  local soundName = GetSelectedDropdownValue(dropdown, "None")
  local enabled = soundName ~= nil and soundName ~= "" and soundName ~= "None"
  button:SetAlpha(enabled and 1 or 0.45)
  button.isEnabled = enabled
end

local function SetSoundPreviewTooltip(button, title)
  if not button then
    return
  end

  button:SetScript("OnEnter", function(selfButton)
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "Preview Sound")
    GameTooltip:AddLine("Play the currently selected sound.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end

local function EnsureSoundPicker(frame)
  if frame.soundPicker then
    return frame.soundPicker
  end

  local picker = CreateFrame("Frame", "PopAurasSoundPicker", UIParent, "BackdropTemplate")
  picker:SetSize(280, 300)
  picker:SetFrameStrata("FULLSCREEN_DIALOG")
  picker:SetToplevel(true)
  picker:SetClampedToScreen(true)
  picker:EnableMouse(true)
  picker:Hide()
  picker:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  picker:SetBackdropColor(0.05, 0.07, 0.10, 0.97)
  picker:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)
  picker.rows = {}

  picker.title = Frames.CreateLabel(picker, "Select Sound", "GameFontNormal")
  picker.title:SetPoint("TOPLEFT", 12, -10)

  picker.closeButton = Frames.CreateButton(picker, "X", 22, 20, function()
    picker:Hide()
  end)
  picker.closeButton:SetPoint("TOPRIGHT", -8, -8)
  Frames.StyleSecondaryButton(picker.closeButton)

  picker.scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
  picker.scroll:SetPoint("TOPLEFT", 12, -34)
  picker.scroll:SetPoint("BOTTOMRIGHT", -28, 12)
  picker.scroll:EnableMouseWheel(true)
  picker.scroll:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll() or 0
    local maxValue = self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(math.max(0, math.min(maxValue, current - (delta * 24))))
  end)

  picker.content = CreateFrame("Frame", nil, picker.scroll)
  picker.content:SetSize(240, 1)
  picker.scroll:SetScrollChild(picker.content)

  if UISpecialFrames then
    local exists = false
    for _, name in ipairs(UISpecialFrames) do
      if name == picker:GetName() then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(UISpecialFrames, picker:GetName())
    end
  end

  frame.soundPicker = picker
  return picker
end

local function RefreshSoundPicker(frame)
  local picker = frame.soundPicker
  if not picker or not picker.valuesProvider then
    return
  end

  local options = picker.valuesProvider() or {}
  local currentValue = picker.dropdown and UIDropDownMenu_GetSelectedValue(picker.dropdown) or nil
  local rowHeight = 22

  for index, option in ipairs(options) do
    local row = picker.rows[index]
    if not row then
      row = CreateFrame("Button", nil, picker.content, "BackdropTemplate")
      row:SetSize(232, rowHeight)
      row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
      })
      row:SetBackdropBorderColor(0.19, 0.24, 0.33, 1)
      row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.Text:SetPoint("LEFT", 8, 0)
      row.Text:SetPoint("RIGHT", -8, 0)
      row.Text:SetJustifyH("LEFT")
      row.Text:SetWordWrap(false)
      row:SetScript("OnEnter", function(selfRow)
        if selfRow.option and not selfRow.isSelected then
          selfRow:SetBackdropColor(0.10, 0.13, 0.18, 0.98)
        end
      end)
      row:SetScript("OnLeave", function(selfRow)
        if selfRow.option and not selfRow.isSelected then
          selfRow:SetBackdropColor(0.07, 0.09, 0.12, 0.94)
        end
      end)
      row:SetScript("OnClick", function(selfRow)
        local activePicker = frame.soundPicker
        if not activePicker or not activePicker.dropdown or not selfRow.option then
          return
        end
        UIDropDownMenu_SetSelectedValue(activePicker.dropdown, selfRow.option.value)
        UIDropDownMenu_SetText(activePicker.dropdown, selfRow.option.label)
        if activePicker.onChanged then
          activePicker.onChanged(selfRow.option.value)
        end
        activePicker:Hide()
      end)
      picker.rows[index] = row
    end

    row.option = option
    row.isSelected = option.value == currentValue
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight))
    row.Text:SetText(option.label or tostring(option.value or ""))
    if row.isSelected then
      row:SetBackdropColor(0.09, 0.28, 0.48, 0.98)
    else
      row:SetBackdropColor(0.07, 0.09, 0.12, 0.94)
    end
    row:Show()
  end

  for index = #options + 1, #picker.rows do
    picker.rows[index]:Hide()
    picker.rows[index].option = nil
  end

  picker.content:SetHeight(math.max(1, #options * rowHeight))
  picker.scroll:SetVerticalScroll(0)
end

local function ToggleSoundPicker(frame, anchor, dropdown, valuesProvider, title, onChanged)
  local picker = EnsureSoundPicker(frame)
  if picker:IsShown() and picker.dropdown == dropdown then
    picker:Hide()
    return
  end

  picker.dropdown = dropdown
  picker.valuesProvider = valuesProvider
  picker.onChanged = onChanged
  picker.title:SetText(title or "Select Sound")

  RefreshSoundPicker(frame)

  picker:ClearAllPoints()
  local anchorBottom = anchor and anchor.GetBottom and anchor:GetBottom() or nil
  if type(anchorBottom) == "number" and anchorBottom < 330 then
    picker:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
  else
    picker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  end
  picker:Show()
end

local function SplitEntries(input)
  local results = {}
  for token in tostring(input or ""):gmatch("([^,]+)") do
    token = token:gsub("^%s+", ""):gsub("%s+$", "")
    if token ~= "" then
      results[#results + 1] = token
    end
  end
  return results
end

local function ResolveSpellId(input)
  input = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if input == "" then
    return nil, "Enter a spell name or spell ID."
  end

  local numeric = tonumber(input)
  if numeric then
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(numeric)
    return numeric, spellName or ("Spell " .. tostring(numeric))
  end

  local needle = input:lower()
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
    local lineCount = C_SpellBook.GetNumSpellBookSkillLines() or 0
    for lineIndex = 1, lineCount do
      local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
      local startIndex = lineInfo and lineInfo.itemIndexOffset and (lineInfo.itemIndexOffset + 1)
      local endIndex = lineInfo and lineInfo.numSpellBookItems and (lineInfo.itemIndexOffset + lineInfo.numSpellBookItems)
      if startIndex and endIndex then
        for slotIndex = startIndex, endIndex do
          local itemInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, Enum.SpellBookSpellBank.Player)
          local spellId = itemInfo and itemInfo.spellID
          if spellId and C_Spell and C_Spell.GetSpellName then
            local spellName = C_Spell.GetSpellName(spellId)
            if spellName and spellName:lower() == needle then
              return spellId, spellName
            end
          end
        end
      end
    end
  end

  return nil, "Spell name not found in your spellbook."
end

local function ResolveItemId(input)
  input = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local numeric = tonumber(input)
  if not numeric then
    return nil, "Items currently require a numeric item ID."
  end
  return numeric, (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(numeric)) or ("Item " .. numeric)
end

local function ResolveSpellList(input)
  local entries = SplitEntries(input)
  if #entries == 0 then
    return nil, "Enter one or more spell names or spell IDs."
  end

  local spellIDs = {}
  local labels = {}
  local names = {}
  local seen = {}

  for _, entry in ipairs(entries) do
    local spellId, result = ResolveSpellId(entry)
    if not spellId then
      return nil, result
    end
    if not seen[spellId] then
      seen[spellId] = true
      spellIDs[#spellIDs + 1] = spellId
      labels[#labels + 1] = string.format("%s (%d)", result, spellId)
      names[#names + 1] = tostring(result or entry):lower()
    end
  end

  return spellIDs, table.concat(labels, ", "), names
end

local function GetTriggerSpellIDs(trigger)
  local ids = {}
  local seen = {}
  if type(trigger.spellIDs) == "table" then
    for _, value in ipairs(trigger.spellIDs) do
      local spellId = tonumber(value or 0) or 0
      if spellId > 0 and not seen[spellId] then
        seen[spellId] = true
        ids[#ids + 1] = spellId
      end
    end
  end
  local primary = tonumber(trigger.spellId or 0) or 0
  if primary > 0 and not seen[primary] then
    ids[#ids + 1] = primary
  end
  return ids
end

function Panel:ApplyCurrent()
  if self.suppressUpdates then
    return
  end

  local frame = self.frame
  local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
  if not aura then
    return
  end

  local trigger = aura.triggers[1] or {}
  trigger.type = UIDropDownMenu_GetSelectedValue(frame.typeDropDown) or "simple"
  trigger.mode = UIDropDownMenu_GetSelectedValue(frame.modeDropDown) or "always"
  trigger.manualCooldown = tonumber(frame.manualCooldownInput:GetText()) or 0
  trigger.showChargeCooldown = frame.chargeCooldownCheck:GetChecked() == true
  trigger.auraType = UIDropDownMenu_GetSelectedValue(frame.auraTypeDropDown) or trigger.auraType or "buff"
  trigger.auraFilter = UIDropDownMenu_GetSelectedValue(frame.auraFilterDropDown) or trigger.auraFilter or "present"
  trigger.unit = UIDropDownMenu_GetSelectedValue(frame.auraUnitDropDown) or trigger.unit or "player"
  trigger.aliveOnly = frame.auraAliveOnlyCheck:GetChecked() == true
  trigger.ignoreNPCs = frame.auraIgnoreNPCsCheck:GetChecked() == true
  trigger.debug = frame.debugCheck:GetChecked() == true
  trigger.alertDuration = tonumber(frame.deathDurationInput:GetText()) or trigger.alertDuration or 2
  trigger.showTank = frame.deathTankCheck:GetChecked() == true
  trigger.showHealer = frame.deathHealerCheck:GetChecked() == true
  trigger.showDPS = frame.deathDPSCheck:GetChecked() == true
  trigger.soundTank = UIDropDownMenu_GetSelectedValue(frame.deathTankSoundDropDown) or trigger.soundTank or "None"
  trigger.soundHealer = UIDropDownMenu_GetSelectedValue(frame.deathHealerSoundDropDown) or trigger.soundHealer or "None"
  trigger.soundDPS = UIDropDownMenu_GetSelectedValue(frame.deathDPSSoundDropDown) or trigger.soundDPS or "None"

  local input = frame.argInput:GetText()
  if trigger.type == "spell_cooldown" or trigger.type == "aura" then
    local spellIDs, result, names = ResolveSpellList(input)
    if not spellIDs then
      frame.resolvedLabel:SetText("|cffff4444" .. result .. "|r")
      return
    end
    trigger.spellIDs = spellIDs
    trigger.spellNames = names
    trigger.spellId = spellIDs[1]
    trigger.itemId = nil
    local resolved = string.format("|cff88ff88Resolved:|r %s", result)
    if trigger.type == "spell_cooldown" and ns.CooldownManager and ns.CooldownManager.FindCooldownIDForSpellID then
      local mapped = {}
      local unmapped = {}
      for _, spellId in ipairs(spellIDs) do
        local cooldownID = ns.CooldownManager:FindCooldownIDForSpellID(spellId)
        if cooldownID then
          mapped[#mapped + 1] = tostring(cooldownID)
        else
          unmapped[#unmapped + 1] = tostring(spellId)
        end
      end
      if #mapped > 0 then
        resolved = string.format("%s  |cff66ccffCDM:|r %s", resolved, table.concat(mapped, ", "))
      end
      if #unmapped > 0 then
        resolved = string.format("%s  |cffffcc66Unmapped:|r %s", resolved, table.concat(unmapped, ", "))
      end
    end
    frame.resolvedLabel:SetText(resolved)
  elseif trigger.type == "item_cooldown" then
    local itemId, result = ResolveItemId(input)
    if not itemId then
      frame.resolvedLabel:SetText("|cffff4444" .. result .. "|r")
      return
    end
    trigger.itemId = itemId
    trigger.spellId = nil
    frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s (%d)", result or "Item", itemId))
  elseif trigger.type == "cast" then
    local spellIDs, result, names = ResolveSpellList(input)
    if spellIDs then
      trigger.spellIDs = spellIDs
      trigger.spellNames = names
      trigger.spellId = spellIDs[1]
      frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s", result))
    else
      trigger.spellIDs = nil
      trigger.spellNames = nil
      trigger.spellId = nil
      frame.resolvedLabel:SetText("|cffaaaaaaTracking any cast for selected unit.|r")
    end
    trigger.itemId = nil
  elseif trigger.type == "death_alert" then
    trigger.spellIDs = nil
    trigger.spellNames = nil
    trigger.spellId = nil
    trigger.itemId = nil
    frame.resolvedLabel:SetText("|cff88ff88Tracks party or raid member deaths only.|r")
  else
    trigger.spellIDs = nil
    trigger.spellNames = nil
    trigger.spellId = nil
    trigger.itemId = nil
    frame.resolvedLabel:SetText("|cffaaaaaaNo spell/item lookup needed for this trigger.|r")
  end

  if trigger.type == "aura" and not trigger.unit then
    trigger.unit = "player"
    trigger.auraType = "buff"
    trigger.auraFilter = "present"
    trigger.aliveOnly = false
    trigger.ignoreNPCs = false
  elseif trigger.type == "cast" and not trigger.unit then
    trigger.unit = "player"
  end

  aura.triggers[1] = trigger
  aura.triggerOp = UIDropDownMenu_GetSelectedValue(frame.opDropDown) or "AND"
  ns.runtime:RefreshAura(aura.id)
  if ns.CooldownManager and ns.CooldownManager.ApplyVisibilityOverrides then
    ns.CooldownManager:ApplyVisibilityOverrides()
  end
  ns.ui.MainWindow:RefreshSelection()
end

function Panel:WireLiveInput(input)
  input:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    Panel:ApplyCurrent()
  end)
  input:SetScript("OnEditFocusLost", function()
    Panel:ApplyCurrent()
  end)
end

function Panel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()

  frame.typeLabel = Frames.CreateLabel(frame, "Trigger Type", "GameFontNormal")
  frame.typeLabel:SetPoint("TOPLEFT", 16, -20)
  frame.typeDropDown = Frames.CreateDropdown(frame, 180, function(self, level)
    for value, label in pairs(triggerTypes) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = label
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.typeDropDown, value)
        UIDropDownMenu_SetText(frame.typeDropDown, label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.typeDropDown:SetPoint("TOPLEFT", frame.typeLabel, "BOTTOMLEFT", -14, -4)

  frame.opLabel = Frames.CreateLabel(frame, "Trigger Logic", "GameFontNormal")
  frame.opLabel:SetPoint("TOPLEFT", frame.typeDropDown, "BOTTOMLEFT", 14, -16)
  frame.opDropDown = Frames.CreateDropdown(frame, 120, function(self, level)
    for _, value in ipairs({ "AND", "OR" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = value
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.opDropDown, value)
        UIDropDownMenu_SetText(frame.opDropDown, value)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.opDropDown:SetPoint("TOPLEFT", frame.opLabel, "BOTTOMLEFT", -14, -4)

  frame.argLabel = Frames.CreateLabel(frame, "Spell / Item Name or IDs", "GameFontNormal")
  frame.argLabel:SetPoint("TOPLEFT", frame.opDropDown, "BOTTOMLEFT", 14, -16)
  frame.argInput = Frames.CreateInput(frame, 140, 24)
  frame.argInput:SetPoint("TOPLEFT", frame.argLabel, "BOTTOMLEFT", 0, -6)

  frame.resolvedLabel = Frames.CreateLabel(frame, "", "GameFontHighlightSmall")
  frame.resolvedLabel:SetPoint("TOPLEFT", frame.argInput, "BOTTOMLEFT", 0, -6)

  frame.deathDurationLabel = Frames.CreateLabel(frame, "Alert Duration Seconds", "GameFontNormal")
  frame.deathDurationLabel:SetPoint("TOPLEFT", frame.resolvedLabel, "BOTTOMLEFT", 0, -10)
  frame.deathDurationInput = Frames.CreateInput(frame, 120, 24)
  frame.deathDurationInput:SetPoint("TOPLEFT", frame.deathDurationLabel, "BOTTOMLEFT", 0, -6)

  frame.deathRolesLabel = Frames.CreateLabel(frame, "Show Roles", "GameFontNormal")
  frame.deathRolesLabel:SetPoint("TOPLEFT", frame.deathDurationInput, "BOTTOMLEFT", 0, -12)
  frame.deathTankCheck = Frames.CreateCheckbox(frame, "Tanks")
  frame.deathTankCheck:SetPoint("TOPLEFT", frame.deathRolesLabel, "BOTTOMLEFT", 0, -6)
  frame.deathHealerCheck = Frames.CreateCheckbox(frame, "Healers")
  frame.deathHealerCheck:SetPoint("TOPLEFT", frame.deathTankCheck, "TOPRIGHT", 96, 0)
  frame.deathDPSCheck = Frames.CreateCheckbox(frame, "DPS")
  frame.deathDPSCheck:SetPoint("TOPLEFT", frame.deathHealerCheck, "TOPRIGHT", 96, 0)

  frame.deathSoundsLabel = Frames.CreateLabel(frame, "Role Sounds", "GameFontNormal")
  frame.deathSoundsLabel:SetPoint("TOPLEFT", frame.deathTankCheck, "BOTTOMLEFT", 0, -12)
  frame.deathTankSoundLabel = Frames.CreateLabel(frame, "Tank", "GameFontNormalSmall")
  frame.deathTankSoundLabel:SetPoint("TOPLEFT", frame.deathSoundsLabel, "BOTTOMLEFT", 0, -6)
  frame.deathTankSoundDropDown = Frames.CreateDropdown(frame, 180)
  frame.deathTankSoundDropDown:SetPoint("TOPLEFT", frame.deathTankSoundLabel, "BOTTOMLEFT", -14, -2)
  frame.deathTankSoundButton = CreateFrame("Button", nil, frame.deathTankSoundDropDown)
  frame.deathTankSoundButton:SetAllPoints(frame.deathTankSoundDropDown)
  frame.deathTankSoundButton:SetFrameLevel(frame.deathTankSoundDropDown:GetFrameLevel() + 8)
  frame.deathTankSoundButton:RegisterForClicks("LeftButtonUp")
  frame.deathTankSoundButton:SetScript("OnClick", function()
    ToggleSoundPicker(frame, frame.deathTankSoundButton, frame.deathTankSoundDropDown, GetSoundDropdownValues, "Select Tank Sound", function()
      UpdateSoundPreviewButton(frame.deathTankSoundPreview, frame.deathTankSoundDropDown)
      Panel:ApplyCurrent()
    end)
  end)
  frame.deathTankSoundPreview = Frames.CreateButton(frame, "Test", 42, 20, function()
    if frame.deathTankSoundPreview and frame.deathTankSoundPreview.isEnabled == false then
      return
    end
    PlayPreviewSound(frame.deathTankSoundDropDown)
  end)
  frame.deathTankSoundPreview:SetPoint("LEFT", frame.deathTankSoundDropDown, "RIGHT", -6, 2)
  Frames.StyleSecondaryButton(frame.deathTankSoundPreview)
  frame.deathHealerSoundLabel = Frames.CreateLabel(frame, "Healer", "GameFontNormalSmall")
  frame.deathHealerSoundLabel:SetPoint("TOPLEFT", frame.deathTankSoundDropDown, "BOTTOMLEFT", 14, -8)
  frame.deathHealerSoundDropDown = Frames.CreateDropdown(frame, 180)
  frame.deathHealerSoundDropDown:SetPoint("TOPLEFT", frame.deathHealerSoundLabel, "BOTTOMLEFT", -14, -2)
  frame.deathHealerSoundButton = CreateFrame("Button", nil, frame.deathHealerSoundDropDown)
  frame.deathHealerSoundButton:SetAllPoints(frame.deathHealerSoundDropDown)
  frame.deathHealerSoundButton:SetFrameLevel(frame.deathHealerSoundDropDown:GetFrameLevel() + 8)
  frame.deathHealerSoundButton:RegisterForClicks("LeftButtonUp")
  frame.deathHealerSoundButton:SetScript("OnClick", function()
    ToggleSoundPicker(frame, frame.deathHealerSoundButton, frame.deathHealerSoundDropDown, GetSoundDropdownValues, "Select Healer Sound", function()
      UpdateSoundPreviewButton(frame.deathHealerSoundPreview, frame.deathHealerSoundDropDown)
      Panel:ApplyCurrent()
    end)
  end)
  frame.deathHealerSoundPreview = Frames.CreateButton(frame, "Test", 42, 20, function()
    if frame.deathHealerSoundPreview and frame.deathHealerSoundPreview.isEnabled == false then
      return
    end
    PlayPreviewSound(frame.deathHealerSoundDropDown)
  end)
  frame.deathHealerSoundPreview:SetPoint("LEFT", frame.deathHealerSoundDropDown, "RIGHT", -6, 2)
  Frames.StyleSecondaryButton(frame.deathHealerSoundPreview)
  frame.deathDPSSoundLabel = Frames.CreateLabel(frame, "DPS", "GameFontNormalSmall")
  frame.deathDPSSoundLabel:SetPoint("TOPLEFT", frame.deathHealerSoundDropDown, "BOTTOMLEFT", 14, -8)
  frame.deathDPSSoundDropDown = Frames.CreateDropdown(frame, 180)
  frame.deathDPSSoundDropDown:SetPoint("TOPLEFT", frame.deathDPSSoundLabel, "BOTTOMLEFT", -14, -2)
  frame.deathDPSSoundButton = CreateFrame("Button", nil, frame.deathDPSSoundDropDown)
  frame.deathDPSSoundButton:SetAllPoints(frame.deathDPSSoundDropDown)
  frame.deathDPSSoundButton:SetFrameLevel(frame.deathDPSSoundDropDown:GetFrameLevel() + 8)
  frame.deathDPSSoundButton:RegisterForClicks("LeftButtonUp")
  frame.deathDPSSoundButton:SetScript("OnClick", function()
    ToggleSoundPicker(frame, frame.deathDPSSoundButton, frame.deathDPSSoundDropDown, GetSoundDropdownValues, "Select DPS Sound", function()
      UpdateSoundPreviewButton(frame.deathDPSSoundPreview, frame.deathDPSSoundDropDown)
      Panel:ApplyCurrent()
    end)
  end)
  frame.deathDPSSoundPreview = Frames.CreateButton(frame, "Test", 42, 20, function()
    if frame.deathDPSSoundPreview and frame.deathDPSSoundPreview.isEnabled == false then
      return
    end
    PlayPreviewSound(frame.deathDPSSoundDropDown)
  end)
  frame.deathDPSSoundPreview:SetPoint("LEFT", frame.deathDPSSoundDropDown, "RIGHT", -6, 2)
  Frames.StyleSecondaryButton(frame.deathDPSSoundPreview)

  frame.modeLabel = Frames.CreateLabel(frame, "Simple Mode", "GameFontNormal")
  frame.modeLabel:SetPoint("TOPLEFT", frame.resolvedLabel, "BOTTOMLEFT", 0, -10)
  frame.modeDropDown = Frames.CreateDropdown(frame, 160, function(self, level)
    local modes = {
      { value = "always", label = "Always" },
      { value = "in_combat", label = "In Combat" },
      { value = "target_exists", label = "Target Exists" },
    }
    for _, mode in ipairs(modes) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = mode.label
      info.value = mode.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.modeDropDown, mode.value)
        UIDropDownMenu_SetText(frame.modeDropDown, mode.label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.modeDropDown:SetPoint("TOPLEFT", frame.modeLabel, "BOTTOMLEFT", -14, -4)

  frame.auraTypeLabel = Frames.CreateLabel(frame, "Aura Type", "GameFontNormal")
  frame.auraTypeLabel:SetPoint("TOPLEFT", frame.resolvedLabel, "BOTTOMLEFT", 0, -10)
  frame.auraTypeDropDown = Frames.CreateDropdown(frame, 140, function(self, level)
    for _, option in ipairs(auraTypeValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraTypeDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraTypeDropDown, option.label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.auraTypeDropDown:SetPoint("TOPLEFT", frame.auraTypeLabel, "BOTTOMLEFT", -14, -4)

  frame.auraFilterLabel = Frames.CreateLabel(frame, "Aura Filter", "GameFontNormal")
  frame.auraFilterLabel:SetPoint("TOPLEFT", frame.auraTypeDropDown, "BOTTOMLEFT", 14, -10)
  frame.auraFilterDropDown = Frames.CreateDropdown(frame, 160, function(self, level)
    for _, option in ipairs(auraFilterValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraFilterDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraFilterDropDown, option.label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.auraFilterDropDown:SetPoint("TOPLEFT", frame.auraFilterLabel, "BOTTOMLEFT", -14, -4)

  frame.auraUnitLabel = Frames.CreateLabel(frame, "Aura Unit", "GameFontNormal")
  frame.auraUnitLabel:SetPoint("TOPLEFT", frame.auraFilterDropDown, "BOTTOMLEFT", 14, -10)
  frame.auraUnitDropDown = Frames.CreateDropdown(frame, 160, function(self, level)
    for _, option in ipairs(auraUnitValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraUnitDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraUnitDropDown, option.label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.auraUnitDropDown:SetPoint("TOPLEFT", frame.auraUnitLabel, "BOTTOMLEFT", -14, -4)

  frame.auraAliveOnlyCheck = Frames.CreateCheckbox(frame, "Alive Only")
  frame.auraAliveOnlyCheck:SetPoint("TOPLEFT", frame.auraUnitDropDown, "BOTTOMLEFT", 14, -10)

  frame.auraIgnoreNPCsCheck = Frames.CreateCheckbox(frame, "Ignore NPCs")
  frame.auraIgnoreNPCsCheck:SetPoint("TOPLEFT", frame.auraAliveOnlyCheck, "BOTTOMLEFT", 0, -6)

  frame.showAlwaysCheck = Frames.CreateCheckbox(frame, "Always Show")
  frame.showAlwaysCheck:SetPoint("TOPLEFT", frame.modeDropDown, "BOTTOMLEFT", 14, -10)
  frame.showAlwaysCheck:Hide()

  frame.manualCooldownLabel = Frames.CreateLabel(frame, "Manual Cooldown Seconds", "GameFontNormal")
  frame.manualCooldownLabel:SetPoint("TOPLEFT", frame.resolvedLabel, "BOTTOMLEFT", 0, -10)
  frame.manualCooldownInput = Frames.CreateInput(frame, 120, 24)
  frame.manualCooldownInput:SetPoint("TOPLEFT", frame.manualCooldownLabel, "BOTTOMLEFT", 0, -6)
  frame.manualCooldownHint = Frames.CreateLabel(frame, "Optional fallback for spells whose cooldown API is restricted. Used when learned from cast.", "GameFontDisableSmall")
  frame.manualCooldownHint:SetPoint("TOPLEFT", frame.manualCooldownInput, "BOTTOMLEFT", 0, -6)
  frame.manualCooldownHint:SetWidth(320)

  frame.chargeCooldownCheck = Frames.CreateCheckbox(frame, "Show cooldown while charges remain")
  frame.chargeCooldownCheck:SetPoint("TOPLEFT", frame.manualCooldownHint, "BOTTOMLEFT", 0, -12)

  frame.debugCheck = Frames.CreateCheckbox(frame, "Debug Trigger")
  frame.debugCheck:SetPoint("TOPLEFT", frame.chargeCooldownCheck, "BOTTOMLEFT", 0, -8)
  frame.debugCheck:Hide()

  frame.saveButton = Frames.CreateButton(frame, "Apply Trigger", 120, 22, function()
    Panel:ApplyCurrent()
  end)
  frame.saveButton:SetPoint("TOPLEFT", frame.debugCheck, "BOTTOMLEFT", 0, -14)
  frame.saveButton:Hide()

  self.frame = frame

  UIDropDownMenu_Initialize(frame.typeDropDown, function(self, level)
    for value, label in pairs(triggerTypes) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = label
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.typeDropDown, value)
        UIDropDownMenu_SetText(frame.typeDropDown, label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_Initialize(frame.opDropDown, function(self, level)
    for _, value in ipairs({ "AND", "OR" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = value
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.opDropDown, value)
        UIDropDownMenu_SetText(frame.opDropDown, value)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_Initialize(frame.modeDropDown, function(self, level)
    local modes = {
      { value = "always", label = "Always" },
      { value = "in_combat", label = "In Combat" },
      { value = "target_exists", label = "Target Exists" },
    }
    for _, mode in ipairs(modes) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = mode.label
      info.value = mode.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.modeDropDown, mode.value)
        UIDropDownMenu_SetText(frame.modeDropDown, mode.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_Initialize(frame.auraTypeDropDown, function(self, level)
    for _, option in ipairs(auraTypeValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraTypeDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraTypeDropDown, option.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_Initialize(frame.auraFilterDropDown, function(self, level)
    for _, option in ipairs(auraFilterValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraFilterDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraFilterDropDown, option.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_Initialize(frame.auraUnitDropDown, function(self, level)
    for _, option in ipairs(auraUnitValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraUnitDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraUnitDropDown, option.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  InitDropdownValues(frame.deathTankSoundDropDown, GetSoundDropdownValues, function()
    UpdateSoundPreviewButton(frame.deathTankSoundPreview, frame.deathTankSoundDropDown)
    Panel:ApplyCurrent()
  end)
  InitDropdownValues(frame.deathHealerSoundDropDown, GetSoundDropdownValues, function()
    UpdateSoundPreviewButton(frame.deathHealerSoundPreview, frame.deathHealerSoundDropDown)
    Panel:ApplyCurrent()
  end)
  InitDropdownValues(frame.deathDPSSoundDropDown, GetSoundDropdownValues, function()
    UpdateSoundPreviewButton(frame.deathDPSSoundPreview, frame.deathDPSSoundDropDown)
    Panel:ApplyCurrent()
  end)

  SetSoundPreviewTooltip(frame.deathTankSoundPreview, "Preview Tank Sound")
  SetSoundPreviewTooltip(frame.deathHealerSoundPreview, "Preview Healer Sound")
  SetSoundPreviewTooltip(frame.deathDPSSoundPreview, "Preview DPS Sound")

  self:WireLiveInput(frame.argInput)
  self:WireLiveInput(frame.manualCooldownInput)
  self:WireLiveInput(frame.deathDurationInput)
  frame.showAlwaysCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  frame.auraAliveOnlyCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  frame.auraIgnoreNPCsCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  frame.chargeCooldownCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  frame.deathTankCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  frame.deathHealerCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  frame.deathDPSCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)
  frame.debugCheck:SetScript("OnClick", function() Panel:ApplyCurrent() end)

  return frame
end

function Panel:Refresh(aura)
  self.suppressUpdates = true
  local trigger = aura.triggers and aura.triggers[1] or {}
  UIDropDownMenu_SetSelectedValue(self.frame.typeDropDown, trigger.type or "simple")
  UIDropDownMenu_SetText(self.frame.typeDropDown, triggerTypes[trigger.type or "simple"] or "Simple")
  UIDropDownMenu_SetSelectedValue(self.frame.opDropDown, aura.triggerOp or "AND")
  UIDropDownMenu_SetText(self.frame.opDropDown, aura.triggerOp or "AND")
  UIDropDownMenu_SetSelectedValue(self.frame.modeDropDown, trigger.mode or "always")
  UIDropDownMenu_SetText(self.frame.modeDropDown, trigger.mode or "always")
  if trigger.type == "spell_cooldown" or trigger.type == "aura" or trigger.type == "cast" then
    local spellIDs = GetTriggerSpellIDs(trigger)
    local idTokens = {}
    for _, spellId in ipairs(spellIDs) do
      idTokens[#idTokens + 1] = tostring(spellId)
    end
    self.frame.argInput:SetText(table.concat(idTokens, ", "))
    if #spellIDs > 0 then
      local resolvedNames = {}
      for _, spellId in ipairs(spellIDs) do
        local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)
        resolvedNames[#resolvedNames + 1] = string.format("%s (%d)", spellName or "Spell", spellId)
      end
      self.frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s", table.concat(resolvedNames, ", ")))
    else
      self.frame.resolvedLabel:SetText("|cffaaaaaaEnter spell names or IDs separated by commas.|r")
    end
  elseif trigger.type == "item_cooldown" then
    local itemId = trigger.itemId
    local itemName = itemId and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId)
    self.frame.argInput:SetText(itemName or tostring(itemId or ""))
    if itemId then
      self.frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s (%d)", itemName or "Item", itemId))
    else
      self.frame.resolvedLabel:SetText("|cffaaaaaaEnter a numeric item ID.|r")
    end
  else
    self.frame.argInput:SetText("")
    self.frame.resolvedLabel:SetText("|cffaaaaaaNo spell or item lookup needed for this trigger.|r")
  end
  self.frame.debugCheck:SetChecked(trigger.debug == true)
  local isCooldownType = trigger.type == "spell_cooldown" or trigger.type == "item_cooldown"
  local isSimple = trigger.type == "simple"
  local isSpellCooldown = trigger.type == "spell_cooldown"
  local isAura = trigger.type == "aura"
  local isDeathAlert = trigger.type == "death_alert"
  self.frame.modeLabel:SetShown(isSimple)
  self.frame.modeDropDown:SetShown(isSimple)
  self.frame.auraTypeLabel:SetShown(isAura)
  self.frame.auraTypeDropDown:SetShown(isAura)
  self.frame.auraFilterLabel:SetShown(isAura)
  self.frame.auraFilterDropDown:SetShown(isAura)
  self.frame.auraUnitLabel:SetShown(isAura)
  self.frame.auraUnitDropDown:SetShown(isAura)
  self.frame.auraAliveOnlyCheck:SetShown(isAura)
  self.frame.auraIgnoreNPCsCheck:SetShown(isAura and (trigger.unit or "player") == "group")
  self.frame.argLabel:SetShown(not isDeathAlert)
  self.frame.argInput:SetShown(not isDeathAlert)
  UIDropDownMenu_SetSelectedValue(self.frame.auraTypeDropDown, trigger.auraType or "buff")
  UIDropDownMenu_SetText(self.frame.auraTypeDropDown, (trigger.auraType or "buff"):gsub("^%l", string.upper))
  UIDropDownMenu_SetSelectedValue(self.frame.auraFilterDropDown, trigger.auraFilter or "present")
  UIDropDownMenu_SetText(self.frame.auraFilterDropDown, ({
    present = "When Present",
    missing = "When Missing",
  })[trigger.auraFilter or "present"] or "When Present")
  UIDropDownMenu_SetSelectedValue(self.frame.auraUnitDropDown, trigger.unit or "player")
  UIDropDownMenu_SetText(self.frame.auraUnitDropDown, ({
    player = "Player",
    target = "Target",
    group = "Party / Raid",
    nameplate = "Nameplate",
  })[trigger.unit or "player"] or "Player")
  self.frame.auraAliveOnlyCheck:SetChecked(trigger.aliveOnly == true)
  self.frame.auraIgnoreNPCsCheck:SetChecked(trigger.ignoreNPCs == true)
  self.frame.manualCooldownLabel:SetShown(isSpellCooldown)
  self.frame.manualCooldownInput:SetShown(isSpellCooldown)
  self.frame.manualCooldownHint:SetShown(isSpellCooldown)
  self.frame.chargeCooldownCheck:SetShown(isSpellCooldown)
  self.frame.chargeCooldownCheck:SetChecked(trigger.showChargeCooldown ~= false)
  self.frame.deathDurationLabel:SetShown(isDeathAlert)
  self.frame.deathDurationInput:SetShown(isDeathAlert)
  self.frame.deathRolesLabel:SetShown(isDeathAlert)
  self.frame.deathTankCheck:SetShown(isDeathAlert)
  self.frame.deathHealerCheck:SetShown(isDeathAlert)
  self.frame.deathDPSCheck:SetShown(isDeathAlert)
  self.frame.deathSoundsLabel:SetShown(isDeathAlert)
  self.frame.deathTankSoundLabel:SetShown(isDeathAlert)
  self.frame.deathTankSoundDropDown:SetShown(isDeathAlert)
  self.frame.deathTankSoundButton:SetShown(isDeathAlert)
  self.frame.deathTankSoundPreview:SetShown(isDeathAlert)
  self.frame.deathHealerSoundLabel:SetShown(isDeathAlert)
  self.frame.deathHealerSoundDropDown:SetShown(isDeathAlert)
  self.frame.deathHealerSoundButton:SetShown(isDeathAlert)
  self.frame.deathHealerSoundPreview:SetShown(isDeathAlert)
  self.frame.deathDPSSoundLabel:SetShown(isDeathAlert)
  self.frame.deathDPSSoundDropDown:SetShown(isDeathAlert)
  self.frame.deathDPSSoundButton:SetShown(isDeathAlert)
  self.frame.deathDPSSoundPreview:SetShown(isDeathAlert)
  if self.frame.soundPicker and self.frame.soundPicker:IsShown() and not isDeathAlert then
    self.frame.soundPicker:Hide()
  end
  self.frame.deathDurationInput:SetText(isDeathAlert and tostring(trigger.alertDuration or 2) or "")
  self.frame.deathTankCheck:SetChecked(trigger.showTank ~= false)
  self.frame.deathHealerCheck:SetChecked(trigger.showHealer ~= false)
  self.frame.deathDPSCheck:SetChecked(trigger.showDPS ~= false)
  SetDropdownValue(self.frame.deathTankSoundDropDown, trigger.soundTank or "None", GetSoundDropdownValues)
  SetDropdownValue(self.frame.deathHealerSoundDropDown, trigger.soundHealer or "None", GetSoundDropdownValues)
  SetDropdownValue(self.frame.deathDPSSoundDropDown, trigger.soundDPS or "None", GetSoundDropdownValues)
  if self.frame.soundPicker and self.frame.soundPicker:IsShown() then
    RefreshSoundPicker(self.frame)
  end
  UpdateSoundPreviewButton(self.frame.deathTankSoundPreview, self.frame.deathTankSoundDropDown)
  UpdateSoundPreviewButton(self.frame.deathHealerSoundPreview, self.frame.deathHealerSoundDropDown)
  UpdateSoundPreviewButton(self.frame.deathDPSSoundPreview, self.frame.deathDPSSoundDropDown)
  self.frame.debugCheck:SetShown(false)
  self.frame.manualCooldownInput:SetText(trigger.type == "spell_cooldown" and tostring(trigger.manualCooldown or 0) or "")

  if isDeathAlert then
    self.frame.resolvedLabel:SetText("|cff88ff88Tracks party or raid member deaths only.|r")
  end

  if isSpellCooldown and ns.CooldownManager and ns.CooldownManager.FindCooldownIDForSpellID then
    local spellIDs = GetTriggerSpellIDs(trigger)
    if #spellIDs > 0 then
      local mapped = {}
      local unresolved = {}
      for _, spellId in ipairs(spellIDs) do
        local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId) or "Spell"
        local cooldownID = ns.CooldownManager:FindCooldownIDForSpellID(spellId)
        unresolved[#unresolved + 1] = string.format("%s (%d)", spellName, spellId)
        if cooldownID then
          mapped[#mapped + 1] = tostring(cooldownID)
        end
      end
      self.frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s%s",
        table.concat(unresolved, ", "),
        #mapped > 0 and ("  |cff66ccffCDM:|r " .. table.concat(mapped, ", ")) or "  |cffffcc66CDM: not mapped|r"))
    end
  end
  self.suppressUpdates = false
end
