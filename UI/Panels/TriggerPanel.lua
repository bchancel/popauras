local _, ns = ...

local Frames = ns.util.Frames
local Items = ns.util.Items
local SoundPicker = ns.util.SoundPicker
local Tables = ns.util.Tables

local triggerTypes = {
  simple = "Simple",
  aura = "Aura",
  spell_cooldown = "Spell Cooldown",
  item_cooldown = "Item Cooldown",
  cast = "Cast / Channel",
  chat = "Chat",
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

local auraGroupRangeValues = {
  { value = "any", label = "Any Range" },
  { value = "in_range", label = "In Range" },
}

local simpleModeValues = {
  { value = "always", label = "Always" },
  { value = "never", label = "Never" },
  { value = "in_combat", label = "In Combat" },
  { value = "target_exists", label = "Target Exists" },
}

local cooldownMatchValues = {
  { value = "cooldown", label = "On Cooldown" },
  { value = "ready", label = "Ready" },
}

local chatChannelValues = {
  { value = "ANY", label = "Any Channel" },
  { value = "WHISPER", label = "Whisper" },
  { value = "SAY", label = "Say" },
  { value = "YELL", label = "Yell" },
  { value = "PARTY", label = "Party" },
  { value = "PARTY_LEADER", label = "Party Leader" },
  { value = "RAID", label = "Raid" },
  { value = "RAID_LEADER", label = "Raid Leader" },
  { value = "RAID_WARNING", label = "Raid Warning" },
  { value = "INSTANCE_CHAT", label = "Instance" },
  { value = "GUILD", label = "Guild" },
  { value = "OFFICER", label = "Officer" },
  { value = "EMOTE", label = "Emote" },
  { value = "TEXT_EMOTE", label = "Text Emote" },
}

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

local function GetDropdownOptionLabel(value, valuesProvider)
  local label = tostring(value or "")
  for _, option in ipairs(valuesProvider()) do
    if option.value == value then
      return option.label
    end
  end
  return label
end

local function UpdateSelectorButtonText(button, dropdown, valuesProvider)
  if not button or not dropdown then
    return
  end
  local value = UIDropDownMenu_GetSelectedValue(dropdown) or "None"
  button:SetText(GetDropdownOptionLabel(value, valuesProvider))
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

local function ToggleSoundPicker(frame, anchor, dropdown, valuesProvider, title, onChanged)
  if SoundPicker then
    SoundPicker:Toggle(anchor, dropdown, valuesProvider, {
      title = title,
      onChanged = onChanged,
    })
  end
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

local function UpdatePrimaryTriggerLayout(frame, aura)
  if not frame then
    return
  end

  local triggerCount = aura and aura.triggers and #aura.triggers or 0
  local showTriggerLogic = triggerCount > 1
  frame.opLabel:SetShown(showTriggerLogic)
  frame.opDropDown:SetShown(showTriggerLogic)

  frame.argLabel:ClearAllPoints()
  if showTriggerLogic then
    frame.argLabel:SetPoint("TOPLEFT", frame.opDropDown, "BOTTOMLEFT", 14, -16)
  else
    frame.argLabel:SetPoint("TOPLEFT", frame.typeDropDown, "BOTTOMLEFT", 14, -16)
  end
end

local function NormalizeAuraGroupRange(value)
  if value == "nearby" or value == "spell" then
    return "in_range"
  end
  if value == "in_range" then
    return "in_range"
  end
  return "any"
end

local function NormalizeDeathAlertCap(value)
  value = tonumber(value)
  if value == nil then
    return 7
  end
  value = math.floor(value)
  return math.max(0, math.min(20, value))
end

local function NormalizeChatDuration(value)
  value = tonumber(value)
  if value == nil then
    return 4
  end
  return math.max(0.5, math.min(60, value))
end

local function EnsureAuraTriggers(aura)
  if not aura then
    return {}
  end
  if type(aura.triggers) ~= "table" then
    aura.triggers = {}
  end
  if #aura.triggers == 0 then
    aura.triggers[1] = Tables.DeepCopy(ns.Defaults.baseTrigger)
    ns.Defaults:ApplyTriggerDefaults(aura.triggers[1])
  end
  return aura.triggers
end

function Panel:GetSelectedTriggerIndex(aura)
  local triggers = EnsureAuraTriggers(aura)
  local index = tonumber(ns.db and ns.db.ui and ns.db.ui.selectedTriggerIndex or 1) or 1
  index = math.max(1, math.min(index, #triggers))
  ns.db.ui.selectedTriggerIndex = index
  return index
end

function Panel:GetSelectedTrigger(aura)
  local triggers = EnsureAuraTriggers(aura)
  local index = self:GetSelectedTriggerIndex(aura)
  return triggers[index], index
end

local function GetTriggerDropdownValues(aura)
  local values = {}
  for index, trigger in ipairs(EnsureAuraTriggers(aura)) do
    local label = triggerTypes[trigger.type or "simple"] or "Trigger"
    values[#values + 1] = {
      value = index,
      label = string.format("Trigger %d: %s", index, label),
    }
  end
  return values
end

local function ResolveSpellId(input)
  input = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if input == "" then
    return nil, "Enter a spell name or spell ID."
  end

  local numeric = tonumber(input)
  if numeric then
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(numeric)
    return numeric, spellName or ("Spell " .. tostring(numeric)), spellName
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
              return spellId, spellName, spellName
            end
          end
        end
      end
    end
  end

  return nil, "Spell name not found in your spellbook."
end

local function ResolveItemId(input)
  input = Items and Items.NormalizeText and Items.NormalizeText(input) or tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if input == "" then
    return 0, ""
  end

  if Items and Items.ResolveInput then
    return Items:ResolveInput(input)
  end

  local numeric = tonumber(input)
  if numeric then
    local itemId = math.max(0, math.floor(numeric + 0.5))
    return itemId, "Item " .. tostring(itemId)
  end

  return 0, input
end

local function ResolveSpellList(input)
  local entries = SplitEntries(input)
  if #entries == 0 then
    return nil, "Enter one or more spell names or spell IDs."
  end

  local spellIDs = {}
  local labels = {}
  local names = {}
  local seenIDs = {}
  local seenNames = {}

  for _, entry in ipairs(entries) do
    local spellId, result, resolvedName = ResolveSpellId(entry)
    if not spellId then
      return nil, result
    end
    if not seenIDs[spellId] then
      seenIDs[spellId] = true
      spellIDs[#spellIDs + 1] = spellId
      labels[#labels + 1] = resolvedName and string.format("%s (%d)", resolvedName, spellId) or string.format("Spell ID %d", spellId)
    end
    if resolvedName then
      local nameKey = resolvedName:lower()
      if not seenNames[nameKey] then
        seenNames[nameKey] = true
        names[#names + 1] = resolvedName
      end
    end
  end

  return spellIDs, table.concat(labels, ", "), #names > 0 and names or nil
end

local function ResolveAuraList(input)
  local entries = SplitEntries(input)
  if #entries == 0 then
    return nil, nil, nil, "Enter one or more aura names or spell IDs."
  end

  local spellIDs = {}
  local labels = {}
  local names = {}
  local seenIDs = {}
  local seenNames = {}

  for _, entry in ipairs(entries) do
    local spellId, _, resolvedName = ResolveSpellId(entry)
    if spellId then
      if not seenIDs[spellId] then
        seenIDs[spellId] = true
        spellIDs[#spellIDs + 1] = spellId
        labels[#labels + 1] = resolvedName and string.format("%s (%d)", resolvedName, spellId) or string.format("Spell ID %d", spellId)
      end
      if resolvedName then
        local resolvedKey = resolvedName:lower()
        if not seenNames[resolvedKey] then
          seenNames[resolvedKey] = true
          names[#names + 1] = resolvedName
        end
      end
    else
      local nameKey = entry:lower()
      if not seenNames[nameKey] then
        seenNames[nameKey] = true
        names[#names + 1] = entry
        labels[#labels + 1] = string.format("%s (name match)", entry)
      end
    end
  end

  return #spellIDs > 0 and spellIDs or nil, table.concat(labels, ", "), #names > 0 and names or nil, nil
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

local function GetTriggerSpellNames(trigger)
  local names = {}
  local seen = {}
  if type(trigger and trigger.spellNames) == "table" then
    for _, value in ipairs(trigger.spellNames) do
      local spellName = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
      local key = spellName:lower()
      if key ~= "" and not seen[key] then
        seen[key] = true
        names[#names + 1] = spellName
      end
    end
  end
  return names
end

local function BuildAuraInputTokens(trigger)
  local inputTokens = {}
  local resolvedNameKeys = {}

  for _, spellId in ipairs(GetTriggerSpellIDs(trigger)) do
    inputTokens[#inputTokens + 1] = tostring(spellId)
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)
    if spellName and spellName ~= "" then
      resolvedNameKeys[spellName:lower()] = true
    end
  end

  for _, spellName in ipairs(GetTriggerSpellNames(trigger)) do
    if not resolvedNameKeys[spellName:lower()] then
      inputTokens[#inputTokens + 1] = spellName
    end
  end

  return inputTokens
end

local function BuildAuraResolvedTokens(trigger)
  local resolvedTokens = {}
  local resolvedNameKeys = {}

  for _, spellId in ipairs(GetTriggerSpellIDs(trigger)) do
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)
    if spellName and spellName ~= "" then
      resolvedNameKeys[spellName:lower()] = true
      resolvedTokens[#resolvedTokens + 1] = string.format("%s (%d)", spellName, spellId)
    else
      resolvedTokens[#resolvedTokens + 1] = string.format("Spell ID %d", spellId)
    end
  end

  for _, spellName in ipairs(GetTriggerSpellNames(trigger)) do
    if not resolvedNameKeys[spellName:lower()] then
      resolvedTokens[#resolvedTokens + 1] = string.format("%s (name match)", spellName)
    end
  end

  return resolvedTokens
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

  local triggers = EnsureAuraTriggers(aura)
  local trigger, triggerIndex = self:GetSelectedTrigger(aura)
  trigger = trigger or Tables.DeepCopy(ns.Defaults.baseTrigger)
  triggers[triggerIndex] = trigger

  trigger.type = UIDropDownMenu_GetSelectedValue(frame.typeDropDown) or "simple"
  ns.Defaults:ApplyTriggerDefaults(trigger)
  trigger.cooldownMatch = UIDropDownMenu_GetSelectedValue(frame.cooldownMatchDropDown) or trigger.cooldownMatch or "cooldown"
  trigger.mode = UIDropDownMenu_GetSelectedValue(frame.modeDropDown) or trigger.mode or "always"
  trigger.showAlways = frame.showAlwaysCheck:GetChecked() == true
  trigger.manualCooldown = tonumber(frame.manualCooldownInput:GetText()) or 0
  trigger.showChargeCooldown = frame.chargeCooldownCheck:GetChecked() == true
  trigger.auraType = UIDropDownMenu_GetSelectedValue(frame.auraTypeDropDown) or trigger.auraType or "buff"
  trigger.auraFilter = UIDropDownMenu_GetSelectedValue(frame.auraFilterDropDown) or trigger.auraFilter or "present"
  trigger.unit = UIDropDownMenu_GetSelectedValue(frame.auraUnitDropDown) or trigger.unit or "player"
  trigger.groupRange = NormalizeAuraGroupRange(UIDropDownMenu_GetSelectedValue(frame.auraRangeDropDown) or trigger.groupRange or "any")
  trigger.aliveOnly = frame.auraAliveOnlyCheck:GetChecked() == true
  trigger.ignoreNPCs = frame.auraIgnoreNPCsCheck:GetChecked() == true
  trigger.chatChannel = UIDropDownMenu_GetSelectedValue(frame.chatChannelDropDown) or trigger.chatChannel or "WHISPER"
  trigger.chatSource = tostring(frame.chatSourceInput:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
  trigger.chatDuration = NormalizeChatDuration(frame.chatDurationInput:GetText() ~= "" and frame.chatDurationInput:GetText() or trigger.chatDuration)
  trigger.debug = frame.debugCheck:GetChecked() == true
  trigger.alertDuration = tonumber(frame.deathDurationInput:GetText()) or trigger.alertDuration or 2
  trigger.maxAlertsPerCombat = NormalizeDeathAlertCap(frame.deathMaxAlertsInput:GetText() ~= "" and frame.deathMaxAlertsInput:GetText() or trigger.maxAlertsPerCombat)
  trigger.showTank = frame.deathTankCheck:GetChecked() == true
  trigger.showHealer = frame.deathHealerCheck:GetChecked() == true
  trigger.showDPS = frame.deathDPSCheck:GetChecked() == true
  trigger.soundTank = UIDropDownMenu_GetSelectedValue(frame.deathTankSoundDropDown) or trigger.soundTank or "None"
  trigger.soundHealer = UIDropDownMenu_GetSelectedValue(frame.deathHealerSoundDropDown) or trigger.soundHealer or "None"
  trigger.soundDPS = UIDropDownMenu_GetSelectedValue(frame.deathDPSSoundDropDown) or trigger.soundDPS or "None"

  local input = frame.argInput:GetText()
  if trigger.type == "spell_cooldown" then
    local spellIDs, result, names = ResolveSpellList(input)
    if not spellIDs then
      frame.resolvedLabel:SetText("|cffff4444" .. result .. "|r")
      return
    end
    trigger.spellIDs = spellIDs
    trigger.spellNames = names
    trigger.spellId = spellIDs[1]
    trigger.itemId = nil
    trigger.itemName = nil
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
  elseif trigger.type == "aura" then
    local spellIDs, result, names, errorMessage = ResolveAuraList(input)
    if errorMessage then
      frame.resolvedLabel:SetText("|cffff4444" .. errorMessage .. "|r")
      return
    end
    trigger.spellIDs = spellIDs
    trigger.spellNames = names
    trigger.spellId = spellIDs and spellIDs[1] or nil
    trigger.itemId = nil
    trigger.itemName = nil
    frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s", result))
  elseif trigger.type == "item_cooldown" then
    input = Items and Items.NormalizeText and Items.NormalizeText(input) or tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then
      frame.resolvedLabel:SetText("|cffff4444Enter an item name or item ID.|r")
      return
    end
    local itemId, result = ResolveItemId(input)
    trigger.itemId = itemId or 0
    trigger.itemName = trigger.itemId > 0 and (result or input) or input
    trigger.spellId = nil
    if trigger.itemId > 0 then
      frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s (%d)", result or "Item", trigger.itemId))
    else
      frame.resolvedLabel:SetText(string.format("|cffffcc66Saved item name:|r %s  |cffaaaaaaItem ID will resolve when cached or equipped.|r", trigger.itemName))
    end
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
    trigger.itemName = nil
  elseif trigger.type == "death_alert" then
    trigger.spellIDs = nil
    trigger.spellNames = nil
    trigger.spellId = nil
    trigger.itemId = nil
    trigger.itemName = nil
    frame.resolvedLabel:SetText("|cff88ff88Tracks party or raid member deaths only.|r")
  elseif trigger.type == "chat" then
    trigger.spellIDs = nil
    trigger.spellNames = nil
    trigger.spellId = nil
    trigger.itemId = nil
    trigger.itemName = nil
    trigger.chatMessage = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trigger.chatMessage == "" then
      frame.resolvedLabel:SetText("|cffaaaaaaEnter one or more comma-separated phrases to watch for in chat.|r")
    else
      frame.resolvedLabel:SetText(string.format("|cff88ff88Watching:|r %s  |cff66ccffChannel:|r %s%s",
        trigger.chatMessage,
        GetDropdownOptionLabel(trigger.chatChannel or "WHISPER", function() return chatChannelValues end),
        trigger.chatSource ~= "" and ("  |cff66ccffFrom:|r " .. trigger.chatSource) or ""))
    end
  else
    trigger.spellIDs = nil
    trigger.spellNames = nil
    trigger.spellId = nil
    trigger.itemId = nil
    trigger.itemName = nil
    frame.resolvedLabel:SetText("|cffaaaaaaNo spell/item lookup needed for this trigger.|r")
  end

  if trigger.type == "aura" and not trigger.unit then
    trigger.unit = "player"
    trigger.auraType = "buff"
    trigger.auraFilter = "present"
    trigger.groupRange = "any"
    trigger.aliveOnly = false
    trigger.ignoreNPCs = false
  elseif trigger.type == "cast" and not trigger.unit then
    trigger.unit = "player"
  end

  triggers[triggerIndex] = trigger
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

  frame.triggerSelectLabel = Frames.CreateLabel(frame, "Trigger", "GameFontNormal")
  frame.triggerSelectLabel:SetPoint("TOPLEFT", 16, -20)
  frame.triggerSelectDropDown = Frames.CreateDropdown(frame, 220)
  frame.triggerSelectDropDown:SetPoint("TOPLEFT", frame.triggerSelectLabel, "BOTTOMLEFT", -14, -4)
  frame.addTriggerButton = Frames.CreateButton(frame, "Add Trigger", 108, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      return
    end
    local triggers = EnsureAuraTriggers(aura)
    local newTrigger = Tables.DeepCopy(ns.Defaults.baseTrigger)
    newTrigger.mode = "never"
    ns.Defaults:ApplyTriggerDefaults(newTrigger)
    triggers[#triggers + 1] = newTrigger
    ns.db.ui.selectedTriggerIndex = #triggers
    if aura.triggerOp ~= "OR" then
      aura.triggerOp = "AND"
    end
    ns.runtime:RefreshAura(aura.id)
    ns.ui.MainWindow:RefreshSelection()
  end)
  frame.addTriggerButton:SetPoint("LEFT", frame.triggerSelectDropDown, "RIGHT", 6, 0)
  Frames.StyleSecondaryButton(frame.addTriggerButton)
  frame.removeTriggerButton = Frames.CreateButton(frame, "Remove", 82, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    local triggers = aura and EnsureAuraTriggers(aura) or nil
    local index = triggers and Panel:GetSelectedTriggerIndex(aura) or nil
    if not aura or not triggers or #triggers <= 1 or not index then
      return
    end
    table.remove(triggers, index)
    ns.db.ui.selectedTriggerIndex = math.max(1, math.min(index, #triggers))
    ns.runtime:RefreshAura(aura.id)
    ns.ui.MainWindow:RefreshSelection()
  end)
  frame.removeTriggerButton:SetPoint("LEFT", frame.addTriggerButton, "RIGHT", 6, 0)
  Frames.StyleSecondaryButton(frame.removeTriggerButton)

  frame.typeLabel = Frames.CreateLabel(frame, "Trigger Type", "GameFontNormal")
  frame.typeLabel:SetPoint("TOPLEFT", frame.triggerSelectDropDown, "BOTTOMLEFT", 14, -14)
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

  frame.deathMaxAlertsLabel = Frames.CreateLabel(frame, "Max Alerts / Combat (0-20, 0 = unlimited)", "GameFontNormal")
  frame.deathMaxAlertsLabel:SetPoint("TOPLEFT", frame.deathDurationInput, "BOTTOMLEFT", 0, -12)
  frame.deathMaxAlertsInput = Frames.CreateInput(frame, 120, 24)
  frame.deathMaxAlertsInput:SetPoint("TOPLEFT", frame.deathMaxAlertsLabel, "BOTTOMLEFT", 0, -6)

  frame.deathRolesLabel = Frames.CreateLabel(frame, "Show Roles", "GameFontNormal")
  frame.deathRolesLabel:SetPoint("TOPLEFT", frame.deathMaxAlertsInput, "BOTTOMLEFT", 0, -12)
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
  frame.deathTankSoundDropDown:Hide()
  frame.deathTankSoundButton = Frames.CreateSelectorButton(frame, 180, 24)
  frame.deathTankSoundButton:SetPoint("TOPLEFT", frame.deathTankSoundLabel, "BOTTOMLEFT", 0, -6)
  frame.deathTankSoundButton:SetScript("OnClick", function()
    ToggleSoundPicker(frame, frame.deathTankSoundButton, frame.deathTankSoundDropDown, GetSoundDropdownValues, "Select Tank Sound", function()
      UpdateSelectorButtonText(frame.deathTankSoundButton, frame.deathTankSoundDropDown, GetSoundDropdownValues)
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
  frame.deathTankSoundPreview:SetPoint("LEFT", frame.deathTankSoundButton, "RIGHT", 8, 0)
  Frames.StyleSecondaryButton(frame.deathTankSoundPreview)
  frame.deathHealerSoundLabel = Frames.CreateLabel(frame, "Healer", "GameFontNormalSmall")
  frame.deathHealerSoundLabel:SetPoint("TOPLEFT", frame.deathTankSoundButton, "BOTTOMLEFT", 0, -12)
  frame.deathHealerSoundDropDown = Frames.CreateDropdown(frame, 180)
  frame.deathHealerSoundDropDown:SetPoint("TOPLEFT", frame.deathHealerSoundLabel, "BOTTOMLEFT", -14, -2)
  frame.deathHealerSoundDropDown:Hide()
  frame.deathHealerSoundButton = Frames.CreateSelectorButton(frame, 180, 24)
  frame.deathHealerSoundButton:SetPoint("TOPLEFT", frame.deathHealerSoundLabel, "BOTTOMLEFT", 0, -6)
  frame.deathHealerSoundButton:SetScript("OnClick", function()
    ToggleSoundPicker(frame, frame.deathHealerSoundButton, frame.deathHealerSoundDropDown, GetSoundDropdownValues, "Select Healer Sound", function()
      UpdateSelectorButtonText(frame.deathHealerSoundButton, frame.deathHealerSoundDropDown, GetSoundDropdownValues)
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
  frame.deathHealerSoundPreview:SetPoint("LEFT", frame.deathHealerSoundButton, "RIGHT", 8, 0)
  Frames.StyleSecondaryButton(frame.deathHealerSoundPreview)
  frame.deathDPSSoundLabel = Frames.CreateLabel(frame, "DPS", "GameFontNormalSmall")
  frame.deathDPSSoundLabel:SetPoint("TOPLEFT", frame.deathHealerSoundButton, "BOTTOMLEFT", 0, -12)
  frame.deathDPSSoundDropDown = Frames.CreateDropdown(frame, 180)
  frame.deathDPSSoundDropDown:SetPoint("TOPLEFT", frame.deathDPSSoundLabel, "BOTTOMLEFT", -14, -2)
  frame.deathDPSSoundDropDown:Hide()
  frame.deathDPSSoundButton = Frames.CreateSelectorButton(frame, 180, 24)
  frame.deathDPSSoundButton:SetPoint("TOPLEFT", frame.deathDPSSoundLabel, "BOTTOMLEFT", 0, -6)
  frame.deathDPSSoundButton:SetScript("OnClick", function()
    ToggleSoundPicker(frame, frame.deathDPSSoundButton, frame.deathDPSSoundDropDown, GetSoundDropdownValues, "Select DPS Sound", function()
      UpdateSelectorButtonText(frame.deathDPSSoundButton, frame.deathDPSSoundDropDown, GetSoundDropdownValues)
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
  frame.deathDPSSoundPreview:SetPoint("LEFT", frame.deathDPSSoundButton, "RIGHT", 8, 0)
  Frames.StyleSecondaryButton(frame.deathDPSSoundPreview)

  frame.modeLabel = Frames.CreateLabel(frame, "Simple Mode", "GameFontNormal")
  frame.modeLabel:SetPoint("TOPLEFT", frame.resolvedLabel, "BOTTOMLEFT", 0, -10)
  frame.modeDropDown = Frames.CreateDropdown(frame, 160, function(self, level)
    for _, mode in ipairs(simpleModeValues) do
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

  frame.auraRangeLabel = Frames.CreateLabel(frame, "Group Range", "GameFontNormal")
  frame.auraRangeLabel:SetPoint("TOPLEFT", frame.auraUnitDropDown, "BOTTOMLEFT", 14, -10)
  frame.auraRangeDropDown = Frames.CreateDropdown(frame, 160, function(self, level)
    for _, option in ipairs(auraGroupRangeValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraRangeDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraRangeDropDown, option.label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.auraRangeDropDown:SetPoint("TOPLEFT", frame.auraRangeLabel, "BOTTOMLEFT", -14, -4)

  frame.auraAliveOnlyCheck = Frames.CreateCheckbox(frame, "Alive Only")
  frame.auraAliveOnlyCheck:SetPoint("TOPLEFT", frame.auraRangeDropDown, "BOTTOMLEFT", 14, -10)

  frame.auraIgnoreNPCsCheck = Frames.CreateCheckbox(frame, "Ignore NPCs")
  frame.auraIgnoreNPCsCheck:SetPoint("TOPLEFT", frame.auraAliveOnlyCheck, "BOTTOMLEFT", 0, -6)

  frame.cooldownMatchLabel = Frames.CreateLabel(frame, "Match When", "GameFontNormal")
  frame.cooldownMatchLabel:SetPoint("TOPLEFT", frame.resolvedLabel, "BOTTOMLEFT", 0, -10)
  frame.cooldownMatchDropDown = Frames.CreateDropdown(frame, 170)
  frame.cooldownMatchDropDown:SetPoint("TOPLEFT", frame.cooldownMatchLabel, "BOTTOMLEFT", -14, -4)

  frame.showAlwaysCheck = Frames.CreateCheckbox(frame, "Always Show")
  frame.showAlwaysCheck:SetPoint("TOPLEFT", frame.cooldownMatchDropDown, "BOTTOMLEFT", 14, -10)
  frame.showAlwaysCheck:Hide()

  frame.manualCooldownLabel = Frames.CreateLabel(frame, "Manual Cooldown Seconds", "GameFontNormal")
  frame.manualCooldownLabel:SetPoint("TOPLEFT", frame.showAlwaysCheck, "BOTTOMLEFT", 0, -10)
  frame.manualCooldownInput = Frames.CreateInput(frame, 120, 24)
  frame.manualCooldownInput:SetPoint("TOPLEFT", frame.manualCooldownLabel, "BOTTOMLEFT", 0, -6)
  frame.manualCooldownHint = Frames.CreateLabel(frame, "Optional fallback for spells whose cooldown API is restricted. Used when learned from cast.", "GameFontDisableSmall")
  frame.manualCooldownHint:SetPoint("TOPLEFT", frame.manualCooldownInput, "BOTTOMLEFT", 0, -6)
  frame.manualCooldownHint:SetWidth(320)

  frame.chargeCooldownCheck = Frames.CreateCheckbox(frame, "Show cooldown while charges remain")
  frame.chargeCooldownCheck:SetPoint("TOPLEFT", frame.manualCooldownHint, "BOTTOMLEFT", 0, -12)

  frame.chatChannelLabel = Frames.CreateLabel(frame, "Chat Channel", "GameFontNormal")
  frame.chatChannelLabel:SetPoint("TOPLEFT", frame.resolvedLabel, "BOTTOMLEFT", 0, -10)
  frame.chatChannelDropDown = Frames.CreateDropdown(frame, 180)
  frame.chatChannelDropDown:SetPoint("TOPLEFT", frame.chatChannelLabel, "BOTTOMLEFT", -14, -4)
  frame.chatSourceLabel = Frames.CreateLabel(frame, "From Player (optional)", "GameFontNormal")
  frame.chatSourceLabel:SetPoint("TOPLEFT", frame.chatChannelDropDown, "BOTTOMLEFT", 14, -10)
  frame.chatSourceInput = Frames.CreateInput(frame, 180, 24)
  frame.chatSourceInput:SetPoint("TOPLEFT", frame.chatSourceLabel, "BOTTOMLEFT", 0, -6)
  frame.chatDurationLabel = Frames.CreateLabel(frame, "Display Seconds", "GameFontNormal")
  frame.chatDurationLabel:SetPoint("TOPLEFT", frame.chatSourceInput, "BOTTOMLEFT", 0, -10)
  frame.chatDurationInput = Frames.CreateInput(frame, 90, 24)
  frame.chatDurationInput:SetPoint("TOPLEFT", frame.chatDurationLabel, "BOTTOMLEFT", 0, -6)
  frame.chatHint = Frames.CreateLabel(frame, "Use comma-separated phrases in the match box. Sender matching accepts short or full player names.", "GameFontDisableSmall")
  frame.chatHint:SetPoint("TOPLEFT", frame.chatDurationInput, "BOTTOMLEFT", 0, -6)
  frame.chatHint:SetWidth(420)

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
  InitDropdownValues(frame.triggerSelectDropDown, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    return GetTriggerDropdownValues(aura)
  end, function(value)
    ns.db.ui.selectedTriggerIndex = tonumber(value or 1) or 1
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if aura then
      ns.ui.MainWindow:RefreshSelection()
    end
  end)
  UIDropDownMenu_Initialize(frame.modeDropDown, function(self, level)
    for _, mode in ipairs(simpleModeValues) do
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
  UIDropDownMenu_Initialize(frame.cooldownMatchDropDown, function(self, level)
    for _, option in ipairs(cooldownMatchValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.cooldownMatchDropDown, option.value)
        UIDropDownMenu_SetText(frame.cooldownMatchDropDown, option.label)
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
  UIDropDownMenu_Initialize(frame.auraRangeDropDown, function(self, level)
    for _, option in ipairs(auraGroupRangeValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.auraRangeDropDown, option.value)
        UIDropDownMenu_SetText(frame.auraRangeDropDown, option.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  InitDropdownValues(frame.chatChannelDropDown, function()
    return chatChannelValues
  end, function()
    Panel:ApplyCurrent()
  end)
  InitDropdownValues(frame.deathTankSoundDropDown, GetSoundDropdownValues, function()
    UpdateSelectorButtonText(frame.deathTankSoundButton, frame.deathTankSoundDropDown, GetSoundDropdownValues)
    UpdateSoundPreviewButton(frame.deathTankSoundPreview, frame.deathTankSoundDropDown)
    Panel:ApplyCurrent()
  end)
  InitDropdownValues(frame.deathHealerSoundDropDown, GetSoundDropdownValues, function()
    UpdateSelectorButtonText(frame.deathHealerSoundButton, frame.deathHealerSoundDropDown, GetSoundDropdownValues)
    UpdateSoundPreviewButton(frame.deathHealerSoundPreview, frame.deathHealerSoundDropDown)
    Panel:ApplyCurrent()
  end)
  InitDropdownValues(frame.deathDPSSoundDropDown, GetSoundDropdownValues, function()
    UpdateSelectorButtonText(frame.deathDPSSoundButton, frame.deathDPSSoundDropDown, GetSoundDropdownValues)
    UpdateSoundPreviewButton(frame.deathDPSSoundPreview, frame.deathDPSSoundDropDown)
    Panel:ApplyCurrent()
  end)

  SetSoundPreviewTooltip(frame.deathTankSoundPreview, "Preview Tank Sound")
  SetSoundPreviewTooltip(frame.deathHealerSoundPreview, "Preview Healer Sound")
  SetSoundPreviewTooltip(frame.deathDPSSoundPreview, "Preview DPS Sound")

  self:WireLiveInput(frame.argInput)
  self:WireLiveInput(frame.manualCooldownInput)
  self:WireLiveInput(frame.chatSourceInput)
  self:WireLiveInput(frame.chatDurationInput)
  self:WireLiveInput(frame.deathDurationInput)
  self:WireLiveInput(frame.deathMaxAlertsInput)
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
  local triggers = EnsureAuraTriggers(aura)
  local trigger, triggerIndex = self:GetSelectedTrigger(aura)
  UpdatePrimaryTriggerLayout(self.frame, aura)
  SetDropdownValue(self.frame.triggerSelectDropDown, triggerIndex, function()
    return GetTriggerDropdownValues(aura)
  end)
  self.frame.removeTriggerButton:SetShown(#triggers > 1)
  UIDropDownMenu_SetSelectedValue(self.frame.typeDropDown, trigger.type or "simple")
  UIDropDownMenu_SetText(self.frame.typeDropDown, triggerTypes[trigger.type or "simple"] or "Simple")
  UIDropDownMenu_SetSelectedValue(self.frame.opDropDown, aura.triggerOp or "AND")
  UIDropDownMenu_SetText(self.frame.opDropDown, aura.triggerOp or "AND")
  UIDropDownMenu_SetSelectedValue(self.frame.modeDropDown, trigger.mode or "always")
  UIDropDownMenu_SetText(self.frame.modeDropDown, GetDropdownOptionLabel(trigger.mode or "always", function()
    return simpleModeValues
  end))
  if trigger.type == "aura" then
    self.frame.argLabel:SetText("Aura Name or Spell IDs")
    local inputTokens = BuildAuraInputTokens(trigger)
    local resolvedTokens = BuildAuraResolvedTokens(trigger)
    self.frame.argInput:SetText(table.concat(inputTokens, ", "))
    if #resolvedTokens > 0 then
      self.frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s", table.concat(resolvedTokens, ", ")))
    else
      self.frame.resolvedLabel:SetText("|cffaaaaaaEnter aura names or spell IDs separated by commas.|r")
    end
  elseif trigger.type == "spell_cooldown" or trigger.type == "cast" then
    self.frame.argLabel:SetText(trigger.type == "cast" and "Spell Name or IDs (optional)" or "Spell Name or IDs")
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
    self.frame.argLabel:SetText("Item Name or ID")
    local itemId = tonumber(trigger.itemId or 0) or 0
    local itemName = itemId > 0 and Items and Items.GetItemName and Items:GetItemName(itemId) or nil
    local configuredName = Items and Items.NormalizeText and Items.NormalizeText(trigger.itemName) or tostring(trigger.itemName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    self.frame.argInput:SetText(itemName or configuredName or (itemId > 0 and tostring(itemId) or ""))
    if itemId > 0 then
      self.frame.resolvedLabel:SetText(string.format("|cff88ff88Resolved:|r %s (%d)", itemName or configuredName or "Item", itemId))
    elseif configuredName ~= "" then
      self.frame.resolvedLabel:SetText(string.format("|cffffcc66Saved item name:|r %s  |cffaaaaaaItem ID will resolve when cached or equipped.|r", configuredName))
    else
      self.frame.resolvedLabel:SetText("|cffaaaaaaEnter an item name or item ID.|r")
    end
  elseif trigger.type == "chat" then
    self.frame.argLabel:SetText("Matching Text")
    self.frame.argInput:SetText(trigger.chatMessage or "")
    if trigger.chatMessage and trigger.chatMessage ~= "" then
      self.frame.resolvedLabel:SetText(string.format("|cff88ff88Watching:|r %s  |cff66ccffChannel:|r %s%s",
        trigger.chatMessage,
        GetDropdownOptionLabel(trigger.chatChannel or "WHISPER", function() return chatChannelValues end),
        trigger.chatSource and trigger.chatSource ~= "" and ("  |cff66ccffFrom:|r " .. trigger.chatSource) or ""))
    else
      self.frame.resolvedLabel:SetText("|cffaaaaaaEnter one or more comma-separated phrases to watch for in chat.|r")
    end
  else
    self.frame.argLabel:SetText("Spell / Item Name or IDs")
    self.frame.argInput:SetText("")
    self.frame.resolvedLabel:SetText("|cffaaaaaaNo spell or item lookup needed for this trigger.|r")
  end
  self.frame.debugCheck:SetChecked(trigger.debug == true)
  local isCooldownType = trigger.type == "spell_cooldown" or trigger.type == "item_cooldown"
  local isSimple = trigger.type == "simple"
  local isSpellCooldown = trigger.type == "spell_cooldown"
  local isItemCooldown = trigger.type == "item_cooldown"
  local isAura = trigger.type == "aura"
  local isChat = trigger.type == "chat"
  local isDeathAlert = trigger.type == "death_alert"
  self.frame.modeLabel:SetShown(isSimple)
  self.frame.modeDropDown:SetShown(isSimple)
  self.frame.auraTypeLabel:SetShown(isAura)
  self.frame.auraTypeDropDown:SetShown(isAura)
  self.frame.auraFilterLabel:SetShown(isAura)
  self.frame.auraFilterDropDown:SetShown(isAura)
  self.frame.auraUnitLabel:SetShown(isAura)
  self.frame.auraUnitDropDown:SetShown(isAura)
  self.frame.auraRangeLabel:SetShown(isAura and (trigger.unit or "player") == "group")
  self.frame.auraRangeDropDown:SetShown(isAura and (trigger.unit or "player") == "group")
  self.frame.auraAliveOnlyCheck:SetShown(isAura)
  self.frame.auraIgnoreNPCsCheck:SetShown(isAura and (trigger.unit or "player") == "group")
  self.frame.argLabel:SetShown(not isDeathAlert)
  self.frame.argInput:SetShown(not isDeathAlert)
  self.frame.chatChannelLabel:SetShown(isChat)
  self.frame.chatChannelDropDown:SetShown(isChat)
  self.frame.chatSourceLabel:SetShown(isChat)
  self.frame.chatSourceInput:SetShown(isChat)
  self.frame.chatDurationLabel:SetShown(isChat)
  self.frame.chatDurationInput:SetShown(isChat)
  self.frame.chatHint:SetShown(isChat)
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
  local normalizedGroupRange = NormalizeAuraGroupRange(trigger.groupRange or "any")
  UIDropDownMenu_SetSelectedValue(self.frame.auraRangeDropDown, normalizedGroupRange)
  UIDropDownMenu_SetText(self.frame.auraRangeDropDown, GetDropdownOptionLabel(normalizedGroupRange, function()
    return auraGroupRangeValues
  end))
  self.frame.auraAliveOnlyCheck:SetChecked(trigger.aliveOnly == true)
  self.frame.auraIgnoreNPCsCheck:SetChecked(trigger.ignoreNPCs == true)
  self.frame.manualCooldownLabel:SetShown(isSpellCooldown)
  self.frame.manualCooldownInput:SetShown(isSpellCooldown)
  self.frame.manualCooldownHint:SetShown(isSpellCooldown)
  self.frame.cooldownMatchLabel:SetShown(isSpellCooldown or isItemCooldown)
  self.frame.cooldownMatchDropDown:SetShown(isSpellCooldown or isItemCooldown)
  self.frame.showAlwaysCheck:SetShown(isCooldownType)
  self.frame.showAlwaysCheck:SetChecked(trigger.showAlways == true)
  self.frame.chargeCooldownCheck:SetShown(isSpellCooldown)
  self.frame.chargeCooldownCheck:SetChecked(trigger.showChargeCooldown ~= false)
  SetDropdownValue(self.frame.chatChannelDropDown, trigger.chatChannel or "WHISPER", function()
    return chatChannelValues
  end)
  self.frame.chatSourceInput:SetText(trigger.chatSource or "")
  self.frame.chatDurationInput:SetText(isChat and tostring(NormalizeChatDuration(trigger.chatDuration)) or "")
  self.frame.deathDurationLabel:SetShown(isDeathAlert)
  self.frame.deathDurationInput:SetShown(isDeathAlert)
  self.frame.deathMaxAlertsLabel:SetShown(isDeathAlert)
  self.frame.deathMaxAlertsInput:SetShown(isDeathAlert)
  self.frame.deathRolesLabel:SetShown(isDeathAlert)
  self.frame.deathTankCheck:SetShown(isDeathAlert)
  self.frame.deathHealerCheck:SetShown(isDeathAlert)
  self.frame.deathDPSCheck:SetShown(isDeathAlert)
  self.frame.deathSoundsLabel:SetShown(isDeathAlert)
  self.frame.deathTankSoundLabel:SetShown(isDeathAlert)
  self.frame.deathTankSoundDropDown:SetShown(false)
  self.frame.deathTankSoundButton:SetShown(isDeathAlert)
  self.frame.deathTankSoundPreview:SetShown(isDeathAlert)
  self.frame.deathHealerSoundLabel:SetShown(isDeathAlert)
  self.frame.deathHealerSoundDropDown:SetShown(false)
  self.frame.deathHealerSoundButton:SetShown(isDeathAlert)
  self.frame.deathHealerSoundPreview:SetShown(isDeathAlert)
  self.frame.deathDPSSoundLabel:SetShown(isDeathAlert)
  self.frame.deathDPSSoundDropDown:SetShown(false)
  self.frame.deathDPSSoundButton:SetShown(isDeathAlert)
  self.frame.deathDPSSoundPreview:SetShown(isDeathAlert)
  local triggerSoundPickerActive = SoundPicker and (
    SoundPicker:IsActiveDropdown(self.frame.deathTankSoundDropDown) or
    SoundPicker:IsActiveDropdown(self.frame.deathHealerSoundDropDown) or
    SoundPicker:IsActiveDropdown(self.frame.deathDPSSoundDropDown)
  )
  if triggerSoundPickerActive and not isDeathAlert then
    SoundPicker:Hide()
  end
  self.frame.deathDurationInput:SetText(isDeathAlert and tostring(trigger.alertDuration or 2) or "")
  self.frame.deathMaxAlertsInput:SetText(isDeathAlert and tostring(NormalizeDeathAlertCap(trigger.maxAlertsPerCombat)) or "")
  self.frame.deathTankCheck:SetChecked(trigger.showTank ~= false)
  self.frame.deathHealerCheck:SetChecked(trigger.showHealer ~= false)
  self.frame.deathDPSCheck:SetChecked(trigger.showDPS ~= false)
  SetDropdownValue(self.frame.cooldownMatchDropDown, trigger.cooldownMatch or "cooldown", function()
    return cooldownMatchValues
  end)
  SetDropdownValue(self.frame.deathTankSoundDropDown, trigger.soundTank or "None", GetSoundDropdownValues)
  SetDropdownValue(self.frame.deathHealerSoundDropDown, trigger.soundHealer or "None", GetSoundDropdownValues)
  SetDropdownValue(self.frame.deathDPSSoundDropDown, trigger.soundDPS or "None", GetSoundDropdownValues)
  UpdateSelectorButtonText(self.frame.deathTankSoundButton, self.frame.deathTankSoundDropDown, GetSoundDropdownValues)
  UpdateSelectorButtonText(self.frame.deathHealerSoundButton, self.frame.deathHealerSoundDropDown, GetSoundDropdownValues)
  UpdateSelectorButtonText(self.frame.deathDPSSoundButton, self.frame.deathDPSSoundDropDown, GetSoundDropdownValues)
  if triggerSoundPickerActive then
    SoundPicker:RefreshIfOpen()
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
  if ns.ui and ns.ui.MainWindow and ns.ui.MainWindow.frame and ns.ui.MainWindow.frame.triggerDebugCheck then
    ns.ui.MainWindow.frame.triggerDebugCheck:SetChecked(trigger.debug == true)
  end
  self.suppressUpdates = false
end
