local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts
local Theme = ns.util.Theme

local MainWindow = {}
ns.ui.MainWindow = MainWindow

local SIDEBAR_WIDTH = 340

local function GetAddonVersion()
  local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  if type(getter) ~= "function" then return nil end
  local ok, version = pcall(getter, ns.name, "Version")
  if not ok or type(version) ~= "string" or version == "" then return nil end
  return version
end

local panelMap = {
  trigger = "TriggerPanel",
  actions = "ActionsPanel",
  load = "LoadPanel",
  group = "GroupPanel",
  import_export = "ImportExportPanel",
}

local tabLabels = {
  display = "Display",
  trigger = "Trigger",
  actions = "Actions",
  load = "Load",
  group = "Group",
  import_export = "Import/Export",
}

local function GetAuraKindLabel(aura)
  local kind = aura and tostring(aura.kind or "") or ""
  kind = kind:gsub("_", " ")
  kind = kind:gsub("(%a)([%w']*)", function(first, rest)
    return first:upper() .. rest
  end)
  return kind ~= "" and kind or "Aura"
end

local function GetAuraLoadCounts()
  local loaded = 0
  local total = 0
  for _, aura in pairs(ns.Registry:GetAuras() or {}) do
    total = total + 1
    local isLoaded = true
    if ns.LoadEvaluator and ns.LoadEvaluator.MatchesWithAncestors then
      isLoaded = ns.LoadEvaluator:MatchesWithAncestors(aura) == true
    elseif ns.LoadEvaluator and ns.LoadEvaluator.Matches then
      isLoaded = ns.LoadEvaluator:Matches(aura) == true
    end
    if isLoaded then
      loaded = loaded + 1
    end
  end
  return loaded, total
end

local function IsAuraLoaded(aura)
  if not aura then
    return false
  end
  if ns.LoadEvaluator and ns.LoadEvaluator.MatchesWithAncestors then
    return ns.LoadEvaluator:MatchesWithAncestors(aura) == true
  end
  if ns.LoadEvaluator and ns.LoadEvaluator.Matches then
    return ns.LoadEvaluator:Matches(aura) == true
  end
  return true
end

local function GetSortedGroups()
  local groups = {}
  for _, aura in pairs(ns.Registry:GetAuras() or {}) do
    if aura.kind == "group" or aura.kind == "dynamic_group" then
      groups[#groups + 1] = {
        aura = aura,
        isLoaded = IsAuraLoaded(aura),
      }
    end
  end
  table.sort(groups, function(left, right)
    if left.isLoaded ~= right.isLoaded then
      return left.isLoaded
    end
    local leftName = tostring(left.aura.name or ""):lower()
    local rightName = tostring(right.aura.name or ""):lower()
    if leftName ~= rightName then
      return leftName < rightName
    end
    return tostring(left.aura.id or "") < tostring(right.aura.id or "")
  end)
  return groups
end

local function GetEditorMode()
  return (ns.db and ns.db.ui and ns.db.ui.editorMode) or "config"
end

local function GetDisplayPanelKey(aura)
  if aura and aura.kind == "interrupt_tracker" then
    return "InterruptTrackerDisplayPanel"
  end
  return "DisplayPanel"
end

local function IsNameplateBuffAura(aura)
  local trigger = aura and aura.triggers and aura.triggers[1] or nil
  return aura and aura.kind == "icon"
    and type(aura.triggers) == "table" and #aura.triggers == 1
    and trigger and trigger.type == "aura" and trigger.unit == "nameplate"
end

local function ShouldShowTab(aura, key)
  if not aura then
    return key == "import_export"
  end

  local isGroup = aura.kind == "group" or aura.kind == "dynamic_group"
  local isInterruptTracker = aura.kind == "interrupt_tracker"
  if isGroup or isInterruptTracker then
    if key == "trigger" or key == "actions" or key == "group" then
      return false
    end
    return true
  end
  if key == "group" then
    return false
  end
  if key == "trigger" and IsNameplateBuffAura(aura) then
    return false
  end

  return true
end

local function GetSelectedAuraTrigger(aura)
  if not aura or type(aura.triggers) ~= "table" or #aura.triggers == 0 then
    return nil
  end
  local index = tonumber(ns.db and ns.db.ui and ns.db.ui.selectedTriggerIndex or 1) or 1
  index = math.max(1, math.min(index, #aura.triggers))
  ns.db.ui.selectedTriggerIndex = index
  return aura.triggers[index]
end

local function HidePanel(panel)
  if panel then
    local target = panel.host or panel.frame
    if target then
      target:Hide()
    end
  end
end

local function LayoutTabs(frame, aura)
  if not frame or not frame.tabs then
    return
  end

  local visibleTabs = {}
  for _, key in ipairs(ns.Constants.TAB_KEYS) do
    local tab = frame.tabs[key]
    if tab and ShouldShowTab(aura, key) then
      visibleTabs[#visibleTabs + 1] = tab
    end
  end

  local availableWidth = math.max(1, (frame.editor and frame.editor:GetWidth() or 0) - 24)
  local tabWidth = math.max(90, math.floor(availableWidth / math.max(1, #visibleTabs)))
  local previousVisible
  for _, tab in ipairs(visibleTabs) do
    tab:ClearAllPoints()
    tab:SetSize(tabWidth, 38)
    if previousVisible then
      tab:SetPoint("TOPLEFT", previousVisible, "TOPRIGHT", 0, 0)
    else
      tab:SetPoint("TOPLEFT", 12, -86)
    end
    previousVisible = tab
  end
end

local function ApplyWindowDragClamp(frame)
  if not frame then
    return
  end

  frame:SetClampedToScreen(false)
  if not frame.SetClampRectInsets then
    return
  end

  frame:SetClampRectInsets(0, 0, 0, 0)
end

local function ResetWindowPosition(frame)
  if not frame then
    return
  end

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  ns.db.ui.window.point = "CENTER"
  ns.db.ui.window.relativePoint = "CENTER"
  ns.db.ui.window.x = 0
  ns.db.ui.window.y = 0
end

function MainWindow:Create()
  local frame = CreateFrame("Frame", "PopAurasMainWindow", UIParent, "BackdropTemplate")
  frame:SetPoint(
    ns.db.ui.window.point,
    UIParent,
    ns.db.ui.window.relativePoint,
    ns.db.ui.window.x,
    ns.db.ui.window.y
  )
  local windowWidth = math.max(1100, math.min(1700, tonumber(ns.db.ui.window.width) or 1100))
  local windowHeight = math.max(640, math.min(1050, tonumber(ns.db.ui.window.height) or 700))
  ns.db.ui.window.width = windowWidth
  ns.db.ui.window.height = windowHeight
  frame:SetSize(windowWidth, windowHeight)
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(1100, 640, 1700, 1050)
  else
    frame:SetMinResize(1100, 640)
    frame:SetMaxResize(1700, 1050)
  end
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  ApplyWindowDragClamp(frame)
  frame:SetScript("OnSizeChanged", function(self, width, height)
    ApplyWindowDragClamp(self)
    if self.isResizing and ns.db and ns.db.ui and ns.db.ui.window then
      ns.db.ui.window.width = math.floor((width or self:GetWidth()) + 0.5)
      ns.db.ui.window.height = math.floor((height or self:GetHeight()) + 0.5)
    end
    if self.editor and ns.Registry then
      LayoutTabs(self, ns.Registry:GetAura(ns.db.ui.selectedAuraId))
    end
  end)
  Theme.StyleSurface(frame, "canvas", "borderStrong")
  frame:SetFrameStrata("DIALOG")
  frame:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then
      return
    end
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    ns.db.ui.window.point = point
    ns.db.ui.window.relativePoint = relativePoint
    ns.db.ui.window.x = x
    ns.db.ui.window.y = y
  end)
  frame:Hide()
  frame:SetScript("OnHide", function(self)
    if self.isResizing then
      self:StopMovingOrSizing()
      self.isResizing = false
      ns.db.ui.window.width = math.floor(self:GetWidth() + 0.5)
      ns.db.ui.window.height = math.floor(self:GetHeight() + 0.5)
    end
    if GetEditorMode() == "config" and ns.db.ui.activeTab == "trigger" then
      local triggerPanel = ns.panels and ns.panels.TriggerPanel
      if triggerPanel and triggerPanel.frame and triggerPanel.ApplyCurrent then
        triggerPanel:ApplyCurrent()
      end
    end
    if ns.runtime and ns.runtime.RefreshAll then
      ns.runtime:RefreshAll()
    end
  end)

  frame.sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.sidebar:SetPoint("TOPLEFT", 1, -1)
  frame.sidebar:SetPoint("BOTTOMLEFT", 1, 1)
  frame.sidebar:SetWidth(SIDEBAR_WIDTH)
  Theme.StyleSurface(frame.sidebar, "canvasAlt", "border")

  frame.header = CreateFrame("Frame", nil, frame.sidebar, "BackdropTemplate")
  frame.header:SetPoint("TOPLEFT", 1, -1)
  frame.header:SetPoint("TOPRIGHT", -1, -1)
  frame.header:SetHeight(70)
  Theme.StyleSurface(frame.header, "transparent", "transparent")

  frame.brandMark = CreateFrame("Frame", nil, frame.header, "BackdropTemplate")
  frame.brandMark:SetSize(36, 36)
  frame.brandMark:SetPoint("LEFT", 18, 0)
  Theme.StyleSurface(frame.brandMark, "accentSoft", "accent")

  frame.brandText = frame.brandMark:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.brandText, 13, "")
  frame.brandText:SetPoint("CENTER", 0, 1)
  frame.brandText:SetText("/PA")
  Theme.SetText(frame.brandText, "accentBright")

  frame.headerText = frame.header:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.headerText, 19, "")
  frame.headerText:SetPoint("LEFT", frame.brandMark, "RIGHT", 10, 1)
  local version = GetAddonVersion()
  frame.headerText:SetText("PopAuras")
  Theme.SetText(frame.headerText, "accentBright")

  frame.accent = Theme.CreateAccentLine(frame, 2, "accent")
  frame.accent:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 16, -70)
  frame.accent:SetPoint("TOPRIGHT", frame.sidebar, "TOPRIGHT", -16, -70)

  frame.toolbar = ns.ui.Toolbar:Create(frame.sidebar)
  frame.toolbar:SetPoint("TOPLEFT", 18, -84)
  frame.toolbar:SetPoint("TOPRIGHT", -18, -84)

  frame.tree = ns.ui.AuraTree:Create(frame.sidebar)
  frame.tree:SetPoint("TOPLEFT", 18, -146)
  frame.tree:SetPoint("BOTTOMRIGHT", -18, 48)
  frame.tree:SetFrameStrata("FULLSCREEN_DIALOG")
  frame.tree:SetFrameLevel(frame:GetFrameLevel() + 60)

  frame.editor = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  Theme.StyleSurface(frame.editor, "canvas", "border")
  frame.editor:SetPoint("TOPLEFT", frame.sidebar, "TOPRIGHT", 0, 0)
  frame.editor:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.editor:SetFrameStrata("DIALOG")
  frame.editor:SetFrameLevel(frame:GetFrameLevel() + 5)

  frame.editorTitle = frame.editor:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.editorTitle, 18, "")
  frame.editorTitle:SetPoint("TOPLEFT", 24, -20)
  frame.editorTitle:SetText("Aura Configuration")
  Theme.SetText(frame.editorTitle, "text")

  frame.editorSubtitle = frame.editor:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.editorSubtitle, 11, "")
  frame.editorSubtitle:SetPoint("TOPLEFT", frame.editorTitle, "BOTTOMLEFT", 0, -7)
  frame.editorSubtitle:SetText("Configure the selected aura.")
  Theme.SetText(frame.editorSubtitle, "textMuted")

  frame.closeButton = Frames.CreateButton(frame.editor, "x", 28, 28, function()
    frame:Hide()
  end)
  frame.closeButton:SetPoint("TOPRIGHT", -16, -14)
  Theme.StyleButton(frame.closeButton, "ghost")
  Fonts.Apply(frame.closeButton:GetFontString(), 15, "")

  frame.previewAnimateCheck = Frames.CreateToggle(frame.editor)
  frame.previewAnimateCheck:SetPoint("RIGHT", frame.closeButton, "LEFT", -18, 0)
  frame.previewAnimateLabel = frame.editor:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.previewAnimateLabel, 11, "")
  frame.previewAnimateLabel:SetPoint("RIGHT", frame.previewAnimateCheck, "LEFT", -8, 0)
  frame.previewAnimateLabel:SetText("Preview Animation")
  Theme.SetText(frame.previewAnimateLabel, "textSecondary")
  frame.previewAnimateCheck:SetScript("OnClick", function(selfCheck)
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      selfCheck:SetChecked(false)
      return
    end
    aura.display = aura.display or {}
    aura.display.previewAnimate = selfCheck:GetChecked() and true or false
    if ns.runtime and ns.runtime.RefreshAuras then
      -- RefreshAuras also updates ancestor groups, so a child transitioning
      -- into or out of preview is laid out and made visible immediately.
      ns.runtime:RefreshAuras({ aura.id })
    end
    if ns.ui and ns.ui.AuraTree and ns.ui.AuraTree.Refresh then
      ns.ui.AuraTree:Refresh()
    end
  end)

  frame.triggerDebugCheck = Frames.CreateToggle(frame.editor)
  frame.triggerDebugCheck:SetPoint("RIGHT", frame.previewAnimateLabel, "LEFT", -24, 0)
  frame.triggerDebugLabel = frame.editor:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.triggerDebugLabel, 11, "")
  frame.triggerDebugLabel:SetPoint("RIGHT", frame.triggerDebugCheck, "LEFT", -8, 0)
  frame.triggerDebugLabel:SetText("Debug Trigger")
  Theme.SetText(frame.triggerDebugLabel, "textSecondary")
  frame.triggerDebugCheck:SetScript("OnClick", function(selfCheck)
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    local trigger = GetSelectedAuraTrigger(aura)
    if not aura or not trigger then
      selfCheck:SetChecked(false)
      return
    end

    trigger.debug = selfCheck:GetChecked() and true or false

    local triggerPanel = ns.panels and ns.panels.TriggerPanel or nil
    if triggerPanel and triggerPanel.frame and triggerPanel.frame.debugCheck then
      triggerPanel.frame.debugCheck:SetChecked(trigger.debug == true)
    end

    if ns.runtime and ns.runtime.RefreshAura then
      ns.runtime:RefreshAura(aura.id)
    end
    if ns.ui and ns.ui.AuraTree and ns.ui.AuraTree.Refresh then
      ns.ui.AuraTree:Refresh()
    end
  end)

  frame.removeFromGroupButton = Frames.CreateButton(frame.editor, "Remove From Group", 122, 26, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura or not aura.parentId then
      return
    end
    if ns.Registry:RemoveFromGroup(aura.id) then
      ns.runtime:RefreshAll()
      ns.ui.MainWindow:Refresh()
    end
  end)
  frame.removeFromGroupButton:SetPoint("RIGHT", frame.triggerDebugLabel, "LEFT", -18, 0)
  Frames.StyleDangerButton(frame.removeFromGroupButton)
  Fonts.Apply(frame.removeFromGroupButton:GetFontString(), 10, "")

  frame.addToGroupDropdown = Frames.CreateDropdown(frame.editor, 122, function(_, level)
    if level ~= 1 then
      return
    end

    local selectedAura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    local groups = GetSortedGroups()
    if not selectedAura or selectedAura.parentId or #groups == 0 then
      local info = UIDropDownMenu_CreateInfo()
      info.text = "No groups available"
      info.isTitle = true
      info.notCheckable = true
      info.disabled = true
      UIDropDownMenu_AddButton(info, level)
      return
    end

    local previousLoaded
    for _, entry in ipairs(groups) do
      if previousLoaded == nil or previousLoaded ~= entry.isLoaded then
        local heading = UIDropDownMenu_CreateInfo()
        heading.text = entry.isLoaded and "Loaded Groups" or "Not Loaded Groups"
        heading.isTitle = true
        heading.notCheckable = true
        heading.disabled = true
        UIDropDownMenu_AddButton(heading, level)
        previousLoaded = entry.isLoaded
      end

      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.aura.name or "Unnamed Group"
      info.value = entry.aura.id
      info.notCheckable = true
      info.arg1 = entry.aura.id
      info.func = function(_, groupId)
        local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
        if not aura or aura.parentId then
          return
        end
        if ns.Registry:AssignToGroup(aura.id, groupId) then
          ns.db.ui.collapsedGroups[groupId] = nil
          ns.runtime:RefreshAll()
          ns.ui.MainWindow:Refresh()
        end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.addToGroupDropdown:SetPoint("RIGHT", frame.triggerDebugLabel, "LEFT", -2, 0)
  UIDropDownMenu_SetText(frame.addToGroupDropdown, "Add to Group")
  Theme.StyleDropdown(frame.addToGroupDropdown, "success")
  Fonts.Apply(frame.addToGroupDropdown.Text, 10, "")

  frame.editorDivider = Theme.CreateAccentLine(frame.editor, 1, "borderStrong")
  frame.editorDivider:SetPoint("TOPLEFT", 0, -124)
  frame.editorDivider:SetPoint("TOPRIGHT", 0, -124)

  frame.tabs = {}
  for _, key in ipairs(ns.Constants.TAB_KEYS) do
    local tab = Frames.CreateButton(frame.editor, tabLabels[key], 112, 38, function()
      ns.db.ui.activeTab = key
      self:RefreshSelection()
    end)
    Fonts.Apply(tab:GetFontString(), 12, "")
    Theme.StyleTab(tab, false)
    frame.tabs[key] = tab
  end

  frame.content = CreateFrame("Frame", nil, frame.editor)
  frame.content:SetPoint("TOPLEFT", 24, -140)
  frame.content:SetPoint("BOTTOMRIGHT", -18, 14)

  frame.sidebarFooterLine = Theme.CreateAccentLine(frame.sidebar, 1, "border")
  frame.sidebarFooterLine:SetPoint("BOTTOMLEFT", 16, 44)
  frame.sidebarFooterLine:SetPoint("BOTTOMRIGHT", -16, 44)

  frame.sidebarStatus = frame.sidebar:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.sidebarStatus, 10, "")
  frame.sidebarStatus:SetPoint("BOTTOMLEFT", 18, 16)
  frame.sidebarStatus:SetText("0 of 0 auras loaded")
  Theme.SetText(frame.sidebarStatus, "textMuted")

  frame.sidebarBuild = frame.sidebar:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.sidebarBuild, 10, "")
  frame.sidebarBuild:SetPoint("BOTTOMRIGHT", -18, 16)
  frame.sidebarBuild:SetText(version and ("v" .. version) or "")
  Theme.SetText(frame.sidebarBuild, "textSecondary")

  frame.resizeHandle = CreateFrame("Button", nil, frame)
  frame.resizeHandle:SetSize(24, 24)
  frame.resizeHandle:SetPoint("BOTTOMRIGHT", -2, 2)
  frame.resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 80)
  frame.resizeHandle.text = frame.resizeHandle:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.resizeHandle.text, 15, "OUTLINE")
  frame.resizeHandle.text:SetPoint("CENTER", 1, -1)
  frame.resizeHandle.text:SetText("//")
  Theme.SetText(frame.resizeHandle.text, "textMuted")
  frame.resizeHandle:SetScript("OnEnter", function(selfHandle)
    Theme.SetText(selfHandle.text, "accentBright")
  end)
  frame.resizeHandle:SetScript("OnLeave", function(selfHandle)
    Theme.SetText(selfHandle.text, "textMuted")
  end)
  frame.resizeHandle:SetScript("OnMouseDown", function(_, mouseButton)
    if mouseButton ~= "LeftButton" or InCombatLockdown() then
      return
    end
    frame.isResizing = true
    frame:StartSizing("BOTTOMRIGHT")
  end)
  frame.resizeHandle:SetScript("OnMouseUp", function()
    if not frame.isResizing then
      return
    end
    frame:StopMovingOrSizing()
    frame.isResizing = false
    ns.db.ui.window.width = math.floor(frame:GetWidth() + 0.5)
    ns.db.ui.window.height = math.floor(frame:GetHeight() + 0.5)
  end)

  self.frame = frame
  return frame
end

function MainWindow:GetOrCreatePanel(key, aura)
  local panelKey = key == "display" and GetDisplayPanelKey(aura) or panelMap[key]
  if not panelKey then
    return nil
  end
  local panelModule = ns.panels[panelKey]
  if not panelModule then
    return nil
  end
  if not panelModule.frame then
    panelModule:Create(self.frame.content)
  end
  return panelModule
end

function MainWindow:GetOrCreateNewAuraPanel()
  if not ns.ui.NewAuraPanel then
    return nil
  end
  if not ns.ui.NewAuraPanel.frame then
    ns.ui.NewAuraPanel:Create(self.frame.content)
  end
  return ns.ui.NewAuraPanel
end

function MainWindow:HideAllPanels()
  HidePanel(ns.panels.DisplayPanel)
  HidePanel(ns.panels.InterruptTrackerDisplayPanel)
  HidePanel(ns.panels.TriggerPanel)
  HidePanel(ns.panels.ActionsPanel)
  HidePanel(ns.panels.LoadPanel)
  HidePanel(ns.panels.GroupPanel)
  HidePanel(ns.panels.ImportExportPanel)
  if ns.ui.NewAuraPanel and ns.ui.NewAuraPanel.frame then
    ns.ui.NewAuraPanel.frame:Hide()
  end
end

function MainWindow:Refresh()
  if not self.frame then
    return
  end
  self:RefreshSelection()
end

function MainWindow:RefreshSelection()
  if not self.frame then
    return
  end

  local editorMode = GetEditorMode()
  local isGlobalImport = editorMode == "global_import"
  local aura = not isGlobalImport and ns.Registry:GetAura(ns.db.ui.selectedAuraId) or nil
  if not aura and not isGlobalImport and ns.Registry:GetOrder()[1] then
    ns.db.ui.selectedAuraId = ns.Registry:GetOrder()[1]
    aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
  end
  if not aura and not isGlobalImport and (ns.db.ui.activeTab or "display") ~= "import_export" and editorMode ~= "new_aura" then
    ns.db.ui.editorMode = "new_aura"
    editorMode = "new_aura"
  end

  ns.ui.AuraTree:Refresh()
  local loadedCount, totalCount = GetAuraLoadCounts()
  self.frame.sidebarStatus:SetText(string.format("%d of %d auras loaded", loadedCount, totalCount))

  local hasTrigger = editorMode ~= "new_aura"
    and aura ~= nil
    and aura.kind ~= "group"
    and aura.kind ~= "dynamic_group"
    and aura.kind ~= "interrupt_tracker"
    and aura.triggers
    and GetSelectedAuraTrigger(aura) ~= nil
    and not IsNameplateBuffAura(aura)
  local showPreviewToggle = editorMode ~= "new_aura" and aura ~= nil and aura.kind ~= "interrupt_tracker"
  local selectedTrigger = GetSelectedAuraTrigger(aura)

  self.frame.previewAnimateCheck:SetShown(showPreviewToggle)
  self.frame.previewAnimateLabel:SetShown(showPreviewToggle)
  self.frame.previewAnimateCheck:SetChecked(showPreviewToggle and aura and aura.display and aura.display.previewAnimate == true or false)
  Theme.UpdateToggle(self.frame.previewAnimateCheck)
  self.frame.triggerDebugCheck:SetShown(hasTrigger)
  self.frame.triggerDebugLabel:SetShown(hasTrigger)
  self.frame.triggerDebugCheck:SetChecked(hasTrigger and selectedTrigger and selectedTrigger.debug == true or false)
  Theme.UpdateToggle(self.frame.triggerDebugCheck)
  self.frame.removeFromGroupButton:SetShown(editorMode ~= "new_aura" and aura ~= nil and aura.parentId ~= nil)
  local isGroup = aura and (aura.kind == "group" or aura.kind == "dynamic_group")
  local showAddToGroup = editorMode ~= "new_aura" and aura ~= nil and aura.parentId == nil and not isGroup
  self.frame.addToGroupDropdown:SetShown(showAddToGroup)
  if showAddToGroup then
    UIDropDownMenu_SetSelectedValue(self.frame.addToGroupDropdown, nil)
    UIDropDownMenu_SetText(self.frame.addToGroupDropdown, "Add to Group")
    Theme.StyleDropdown(self.frame.addToGroupDropdown, "success")
  end

  self:HideAllPanels()

  if editorMode == "new_aura" then
    self.frame.editorTitle:SetText("Create a New Aura")
    self.frame.editorSubtitle:SetText("Choose a starting point, then tailor every detail.")
    self.frame.editorDivider:Show()
    for _, tab in pairs(self.frame.tabs) do
      tab:Hide()
    end

    local newAuraPanel = self:GetOrCreateNewAuraPanel()
    if newAuraPanel and newAuraPanel.frame then
      newAuraPanel.frame:Show()
      if newAuraPanel.Refresh then
        newAuraPanel:Refresh()
      end
    end
    return
  end

  if isGlobalImport then
    self.frame.editorTitle:SetText("Import Auras")
    self.frame.editorSubtitle:SetText("Paste and review a PopAuras package without tying it to a selected aura.")
  elseif aura then
    self.frame.editorTitle:SetText(aura.name or "Aura Configuration")
    self.frame.editorSubtitle:SetText(GetAuraKindLabel(aura) .. " configuration")
  else
    self.frame.editorTitle:SetText("Import & Export")
    self.frame.editorSubtitle:SetText("Move PopAuras configurations between characters and players.")
  end
  self.frame.editorDivider:Show()

  for key, tab in pairs(self.frame.tabs) do
    if ShouldShowTab(aura, key) then
      tab:Show()
      local active = (ns.db.ui.activeTab or "display") == key
      Theme.StyleTab(tab, active)
    else
      tab:Hide()
      if ns.db.ui.activeTab == key then
        ns.db.ui.activeTab = aura and "display" or "import_export"
      end
    end
  end

  LayoutTabs(self.frame, aura)

  local activeKey = ns.db.ui.activeTab or "display"
  if not aura and activeKey ~= "import_export" then
    activeKey = "import_export"
    ns.db.ui.activeTab = activeKey
  end

  local activePanel = self:GetOrCreatePanel(activeKey, aura)
  if activePanel and activePanel.frame then
    local activeFrame = activePanel.host or activePanel.frame
    activeFrame:Show()
    if aura or activeKey == "import_export" then
      activePanel:Refresh(aura)
    end
  end
end

function MainWindow:OpenNewAuraPicker()
  if not self.frame then
    self:Create()
  end
  ResetWindowPosition(self.frame)
  ns.db.ui.editorMode = "new_aura"
  if not self.frame:IsShown() then
    self.frame:Show()
  end
  self:Refresh()
end

function MainWindow:OpenGlobalImport()
  if not self.frame then
    self:Create()
  end
  ResetWindowPosition(self.frame)
  ns.db.ui.editorMode = "global_import"
  ns.db.ui.activeTab = "import_export"
  ns.db.ui.selectedAuraId = nil
  if not self.frame:IsShown() then
    self.frame:Show()
  end
  self:Refresh()
end

function MainWindow:Toggle()
  if not self.frame then
    self:Create()
  end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    ResetWindowPosition(self.frame)
    self.frame:Show()
    self:Refresh()
  end
end

function MainWindow:IsOpen()
  return self.frame and self.frame:IsShown()
end
