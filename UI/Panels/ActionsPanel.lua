local _, ns = ...

local Frames = ns.util.Frames
local Tables = ns.util.Tables

local Panel = {}
ns.panels.ActionsPanel = Panel

local actionTypeValues = {
  { value = "glow_unit_frame", label = "Glow Unit Frame" },
}

local actionEventValues = {
  { value = "on_activate", label = "On Activate" },
  { value = "on_deactivate", label = "On Deactivate" },
}

local function GetSelectedActionIndex()
  return tonumber(ns.db and ns.db.ui and ns.db.ui.selectedActionIndex or 1) or 1
end

local function EnsureAuraActions(aura)
  if type(aura.actions) ~= "table" then
    aura.actions = {}
  end
  return aura.actions
end

local function GetSelectedAction(aura)
  local actions = EnsureAuraActions(aura)
  local index = math.max(1, math.min(GetSelectedActionIndex(), #actions))
  return actions[index], index
end

local function SetDropdownValue(dropdown, value, optionsFn)
  UIDropDownMenu_SetSelectedValue(dropdown, value)
  local label = value
  for _, option in ipairs(optionsFn()) do
    if option.value == value then
      label = option.label
      break
    end
  end
  UIDropDownMenu_SetText(dropdown, label)
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

  local actions = EnsureAuraActions(aura)
  local _, actionIndex = GetSelectedAction(aura)
  local action = actions[actionIndex]
  if not action then
    return
  end

  action.type = UIDropDownMenu_GetSelectedValue(frame.typeDropDown) or action.type or "glow_unit_frame"
  action.event = UIDropDownMenu_GetSelectedValue(frame.eventDropDown) or action.event or "on_activate"
  action.unit = tostring(frame.unitInput:GetText() or "%n"):gsub("^%s+", ""):gsub("%s+$", "")
  action.duration = tonumber(frame.durationInput:GetText()) or 4

  if action.unit == "" then
    action.unit = "%n"
  end

  ns.runtime:RefreshAura(aura.id)
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

  frame.actionSelectLabel = Frames.CreateLabel(frame, "Action", "GameFontNormal")
  frame.actionSelectLabel:SetPoint("TOPLEFT", 16, -20)
  frame.actionSelectDropDown = Frames.CreateDropdown(frame, 220)
  frame.actionSelectDropDown:SetPoint("TOPLEFT", frame.actionSelectLabel, "BOTTOMLEFT", -14, -4)

  frame.addButton = Frames.CreateButton(frame, "Add Action", 108, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      return
    end
    local actions = EnsureAuraActions(aura)
    local newAction = Tables.DeepCopy(ns.Defaults.baseAction)
    actions[#actions + 1] = newAction
    ns.db.ui.selectedActionIndex = #actions
    ns.runtime:RefreshAura(aura.id)
    ns.ui.MainWindow:RefreshSelection()
  end)
  frame.addButton:SetPoint("LEFT", frame.actionSelectDropDown, "RIGHT", 6, 0)
  Frames.StyleSecondaryButton(frame.addButton)

  frame.removeButton = Frames.CreateButton(frame, "Remove", 82, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      return
    end
    local actions = EnsureAuraActions(aura)
    local index = GetSelectedActionIndex()
    if #actions == 0 or not actions[index] then
      return
    end
    table.remove(actions, index)
    ns.db.ui.selectedActionIndex = math.max(1, math.min(index, #actions))
    ns.runtime:RefreshAura(aura.id)
    ns.ui.MainWindow:RefreshSelection()
  end)
  frame.removeButton:SetPoint("LEFT", frame.addButton, "RIGHT", 6, 0)
  Frames.StyleSecondaryButton(frame.removeButton)

  frame.typeLabel = Frames.CreateLabel(frame, "Action Type", "GameFontNormal")
  frame.typeLabel:SetPoint("TOPLEFT", frame.actionSelectDropDown, "BOTTOMLEFT", 14, -16)
  frame.typeDropDown = Frames.CreateDropdown(frame, 180, function(self, level)
    for _, option in ipairs(actionTypeValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.typeDropDown, option.value)
        UIDropDownMenu_SetText(frame.typeDropDown, option.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.typeDropDown:SetPoint("TOPLEFT", frame.typeLabel, "BOTTOMLEFT", -14, -4)

  frame.eventLabel = Frames.CreateLabel(frame, "When", "GameFontNormal")
  frame.eventLabel:SetPoint("TOPLEFT", frame.typeDropDown, "BOTTOMLEFT", 14, -12)
  frame.eventDropDown = Frames.CreateDropdown(frame, 180, function(self, level)
    for _, option in ipairs(actionEventValues) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.eventDropDown, option.value)
        UIDropDownMenu_SetText(frame.eventDropDown, option.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.eventDropDown:SetPoint("TOPLEFT", frame.eventLabel, "BOTTOMLEFT", -14, -4)

  frame.unitLabel = Frames.CreateLabel(frame, "Target", "GameFontNormal")
  frame.unitLabel:SetPoint("TOPLEFT", frame.eventDropDown, "BOTTOMLEFT", 14, -12)
  frame.unitInput = Frames.CreateInput(frame, 200, 24)
  frame.unitInput:SetPoint("TOPLEFT", frame.unitLabel, "BOTTOMLEFT", 0, -6)
  self:WireLiveInput(frame.unitInput)

  frame.unitHint = Frames.CreateLabel(frame, "|cffaaaaaa%u = trigger unit (party/raid member)  |  %n = trigger name (spell or sender)  |  %s = status text|r", "GameFontHighlightSmall")
  frame.unitHint:SetPoint("TOPLEFT", frame.unitInput, "BOTTOMLEFT", 0, -4)
  frame.unitHint:SetWidth(500)

  frame.durationLabel = Frames.CreateLabel(frame, "Glow Duration (seconds)", "GameFontNormal")
  frame.durationLabel:SetPoint("TOPLEFT", frame.unitHint, "BOTTOMLEFT", 0, -12)
  frame.durationInput = Frames.CreateInput(frame, 80, 24)
  frame.durationInput:SetPoint("TOPLEFT", frame.durationLabel, "BOTTOMLEFT", 0, -6)
  self:WireLiveInput(frame.durationInput)

  frame.durationHint = Frames.CreateLabel(frame, "|cffaaaaaaSet to 0 to glow until the aura deactivates.|r", "GameFontHighlightSmall")
  frame.durationHint:SetPoint("TOPLEFT", frame.durationInput, "BOTTOMLEFT", 0, -4)

  frame.noActionsLabel = Frames.CreateLabel(frame, "|cffaaaaaaNo actions configured. Click \"Add Action\" to create one.|r", "GameFontHighlight")
  frame.noActionsLabel:SetPoint("TOPLEFT", frame.actionSelectDropDown, "BOTTOMLEFT", 14, -20)

  self.frame = frame
  return frame
end

function Panel:Refresh(aura)
  self.suppressUpdates = true

  local actions = EnsureAuraActions(aura)
  local hasActions = #actions > 0
  local action, actionIndex = GetSelectedAction(aura)

  UIDropDownMenu_Initialize(self.frame.actionSelectDropDown, function(self, level)
    for i, act in ipairs(actions) do
      local info = UIDropDownMenu_CreateInfo()
      local typeLabel = "Action"
      for _, opt in ipairs(actionTypeValues) do
        if opt.value == act.type then
          typeLabel = opt.label
          break
        end
      end
      info.text = string.format("%d. %s", i, typeLabel)
      info.value = i
      info.func = function()
        ns.db.ui.selectedActionIndex = i
        UIDropDownMenu_SetSelectedValue(Panel.frame.actionSelectDropDown, i)
        UIDropDownMenu_SetText(Panel.frame.actionSelectDropDown, string.format("%d. %s", i, typeLabel))
        Panel.suppressUpdates = false
        Panel:Refresh(aura)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  if hasActions then
    local typeLabel = "Action"
    for _, opt in ipairs(actionTypeValues) do
      if opt.value == (action and action.type) then
        typeLabel = opt.label
        break
      end
    end
    UIDropDownMenu_SetSelectedValue(self.frame.actionSelectDropDown, actionIndex)
    UIDropDownMenu_SetText(self.frame.actionSelectDropDown, string.format("%d. %s", actionIndex, typeLabel))
  else
    UIDropDownMenu_SetText(self.frame.actionSelectDropDown, "No Actions")
  end

  self.frame.noActionsLabel:SetShown(not hasActions)
  self.frame.typeLabel:SetShown(hasActions)
  self.frame.typeDropDown:SetShown(hasActions)
  self.frame.eventLabel:SetShown(hasActions)
  self.frame.eventDropDown:SetShown(hasActions)
  self.frame.unitLabel:SetShown(hasActions)
  self.frame.unitInput:SetShown(hasActions)
  self.frame.unitHint:SetShown(hasActions)
  self.frame.durationLabel:SetShown(hasActions)
  self.frame.durationInput:SetShown(hasActions)
  self.frame.durationHint:SetShown(hasActions)

  if hasActions and action then
    SetDropdownValue(self.frame.typeDropDown, action.type or "glow_unit_frame", function() return actionTypeValues end)
    SetDropdownValue(self.frame.eventDropDown, action.event or "on_activate", function() return actionEventValues end)
    self.frame.unitInput:SetText(action.unit or "%n")
    self.frame.durationInput:SetText(tostring(action.duration or 4))
  end

  self.suppressUpdates = false
end
