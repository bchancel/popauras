local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

-- Header search box that finds settings across the editor tabs. Display
-- settings come live from the Display panel's visible grid rows (and jump to
-- the exact row); other tabs use a curated list of their setting labels and
-- switch to that tab.
local SettingsSearch = {}
ns.ui.SettingsSearch = SettingsSearch

local MAX_RESULTS = 8
local RESULT_HEIGHT = 34
local BOX_WIDTH = 200

local TAB_LABELS = {
  display = "Display",
  trigger = "Trigger",
  actions = "Actions",
  load = "Load",
  import_export = "Import/Export",
}

local STATIC_ENTRIES = {
  { tab = "trigger", section = "Trigger", labels = {
    "Trigger Type", "Trigger Logic", "Spell / Item Name or IDs", "Aura Type", "Aura Unit", "Aura Filter",
    "Cast By Me", "Alive Only", "Ignore NPCs", "Group Range", "Match When", "State", "Stack Count",
    "Debug Trigger", "Trinket Slots", "Top Trinket Slot", "Bottom Trinket Slot", "Ignored Trinkets",
    "Manual Cooldown Seconds", "Chat Channels", "Exact Match", "From Player", "Display Seconds",
    "Alert Duration Seconds", "Max Alerts / Combat", "Show Roles", "Role Sounds",
  } },
  { tab = "actions", section = "Actions", labels = {
    "Action", "Action Type", "When", "Target", "Glow Duration", "Sound", "Chat Message",
  } },
  { tab = "load", section = "Load", labels = {
    "Load Aura", "Combat", "Class Filter", "Specializations", "Talent Filter", "Require Talents",
    "Talent Layouts", "Use Talent Layouts", "Visibility", "Minimum Level", "Instance Type",
    "Instance ID", "Encounter ID", "Only Load If Item Equipped",
  } },
  { tab = "import_export", section = "Import / Export", labels = {
    "Export", "Import", "Share",
  } },
}

local function Normalize(text)
  return string.lower(tostring(text or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetSelectedAura()
  return ns.Registry and ns.Registry:GetAura(ns.db.ui.selectedAuraId) or nil
end

local function IsTabAvailable(tab)
  local frame = ns.ui.MainWindow and ns.ui.MainWindow.frame
  local button = frame and frame.tabs and frame.tabs[tab]
  return button ~= nil and button:IsShown()
end

local function CollectResults(query)
  local needle = Normalize(query)
  local results = {}
  if needle == "" then
    return results
  end

  local displayPanel = ns.panels and ns.panels.DisplayPanel
  if IsTabAvailable("display") and displayPanel and displayPanel.GetSearchEntries then
    for _, entry in ipairs(displayPanel:GetSearchEntries()) do
      local haystack = Normalize(entry.label .. " " .. (entry.section or ""))
      if haystack:find(needle, 1, true) then
        results[#results + 1] = {
          tab = "display",
          crumb = "Display  \194\183  " .. tostring(entry.section or ""),
          label = entry.label,
          sectionKey = entry.sectionKey,
          row = entry.row,
        }
      end
    end
  end

  for _, group in ipairs(STATIC_ENTRIES) do
    if IsTabAvailable(group.tab) then
      for _, label in ipairs(group.labels) do
        if Normalize(label):find(needle, 1, true) then
          results[#results + 1] = {
            tab = group.tab,
            crumb = TAB_LABELS[group.tab] or group.section,
            label = label,
          }
        end
      end
    end
  end
  return results
end

function SettingsSearch:Navigate(result)
  if not result then
    return
  end
  self:HideResults()
  self.frame.input:ClearFocus()
  ns.db.ui.editorMode = "config"
  ns.db.ui.activeTab = result.tab
  ns.ui.MainWindow:RefreshSelection()
  if result.tab == "display" and result.sectionKey then
    local displayPanel = ns.panels and ns.panels.DisplayPanel
    if displayPanel and displayPanel.RevealSearchResult then
      -- Wait one frame so the panel has laid out for the selected aura.
      C_Timer.After(0, function()
        displayPanel:RevealSearchResult(result.sectionKey, result.row)
      end)
    end
  end
end

function SettingsSearch:HideResults()
  if self.frame and self.frame.results then
    self.frame.results:Hide()
  end
end

local function StyleResultButton(button, hovered)
  Theme.SetBackdrop(button, hovered and "surfaceHover" or "transparent", "transparent")
  Theme.SetText(button.label, hovered and "text" or "textSecondary")
end

function SettingsSearch:UpdateResults()
  local frame = self.frame
  local query = frame.input:GetText() or ""
  local results = CollectResults(query)
  self.currentResults = results
  local list = frame.results

  if Normalize(query) == "" or not GetSelectedAura() then
    list:Hide()
    return
  end

  local shown = math.min(#results, MAX_RESULTS)
  for index = 1, MAX_RESULTS do
    local button = list.buttons[index]
    local result = results[index]
    if index <= shown then
      button.result = result
      button.crumb:SetText(result.crumb)
      button.label:SetText(result.label)
      StyleResultButton(button, false)
      button:Show()
    else
      button.result = nil
      button:Hide()
    end
  end

  list.empty:SetShown(shown == 0)
  list:SetHeight(math.max(1, shown) * RESULT_HEIGHT + 8)
  list:Show()
end

function SettingsSearch:Create(parent)
  local frame = CreateFrame("Frame", "PopAurasSettingsSearch", parent)
  frame:SetSize(BOX_WIDTH, 26)

  frame.input = Frames.CreateInput(frame, BOX_WIDTH, 26)
  frame.input:SetAllPoints()
  frame.input:SetTextInsets(26, 8, 0, 0)

  frame.icon = frame:CreateTexture(nil, "OVERLAY")
  frame.icon:SetTexture(Frames.UI_ICON_PATH .. "UiSearch")
  frame.icon:SetSize(12, 12)
  frame.icon:SetPoint("LEFT", 9, 0)
  Theme.SetTexture(frame.icon, "textSecondary")

  frame.placeholder = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.placeholder, "bodySmall")
  frame.placeholder:SetPoint("LEFT", 26, 0)
  frame.placeholder:SetText("Search settings")
  Theme.SetText(frame.placeholder, "textSecondary")

  frame.results = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.results:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
  frame.results:SetWidth(280)
  frame.results:SetFrameStrata("FULLSCREEN_DIALOG")
  frame.results:SetFrameLevel(400)
  frame.results:SetClampedToScreen(true)
  Theme.StyleSurface(frame.results, "canvasAlt", "borderStrong")
  frame.results:Hide()
  frame.results.buttons = {}
  for index = 1, MAX_RESULTS do
    local button = CreateFrame("Button", nil, frame.results, "BackdropTemplate")
    button:SetHeight(RESULT_HEIGHT)
    button:SetPoint("TOPLEFT", 4, -4 - ((index - 1) * RESULT_HEIGHT))
    button:SetPoint("TOPRIGHT", -4, -4 - ((index - 1) * RESULT_HEIGHT))
    button.crumb = button:CreateFontString(nil, "OVERLAY")
    Theme.ApplyTypography(button.crumb, "caption")
    button.crumb:SetPoint("TOPLEFT", 10, -4)
    button.crumb:SetPoint("TOPRIGHT", -10, -4)
    button.crumb:SetJustifyH("LEFT")
    Theme.SetText(button.crumb, "textMuted")
    button.label = button:CreateFontString(nil, "OVERLAY")
    Theme.ApplyTypography(button.label, "control")
    button.label:SetPoint("BOTTOMLEFT", 10, 5)
    button.label:SetPoint("BOTTOMRIGHT", -10, 5)
    button.label:SetJustifyH("LEFT")
    button:SetScript("OnEnter", function(selfButton) StyleResultButton(selfButton, true) end)
    button:SetScript("OnLeave", function(selfButton) StyleResultButton(selfButton, false) end)
    button:SetScript("OnClick", function(selfButton)
      SettingsSearch:Navigate(selfButton.result)
    end)
    button:Hide()
    frame.results.buttons[index] = button
  end
  frame.results.empty = frame.results:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.results.empty, "bodySmall")
  frame.results.empty:SetPoint("LEFT", 14, 0)
  frame.results.empty:SetText("No settings match.")
  Theme.SetText(frame.results.empty, "textMuted")

  frame.input:SetScript("OnTextChanged", function(selfInput)
    frame.placeholder:SetShown((selfInput:GetText() or "") == "" and not selfInput:HasFocus())
    SettingsSearch:UpdateResults()
  end)
  frame.input:HookScript("OnEditFocusGained", function()
    frame.placeholder:Hide()
    SettingsSearch:UpdateResults()
  end)
  frame.input:HookScript("OnEditFocusLost", function(selfInput)
    frame.placeholder:SetShown((selfInput:GetText() or "") == "")
    -- Let a click on a result land before the list closes.
    C_Timer.After(0.15, function()
      if not frame.input:HasFocus() and not frame.results:IsMouseOver() then
        SettingsSearch:HideResults()
      end
    end)
  end)
  frame.input:SetScript("OnEnterPressed", function()
    local first = SettingsSearch.currentResults and SettingsSearch.currentResults[1]
    if first then
      SettingsSearch:Navigate(first)
    else
      frame.input:ClearFocus()
    end
  end)
  frame.input:SetScript("OnEscapePressed", function(selfInput)
    selfInput:SetText("")
    selfInput:ClearFocus()
    SettingsSearch:HideResults()
  end)
  frame:SetScript("OnHide", function()
    SettingsSearch:HideResults()
  end)

  self.frame = frame
  return frame
end
