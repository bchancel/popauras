local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts

local MainWindow = {}
ns.ui.MainWindow = MainWindow

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

local function GetEditorMode()
  return (ns.db and ns.db.ui and ns.db.ui.editorMode) or "config"
end

local function GetDisplayPanelKey(aura)
  if aura and aura.kind == "interrupt_tracker" then
    return "InterruptTrackerDisplayPanel"
  end
  return "DisplayPanel"
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
  if panel and panel.frame then
    panel.frame:Hide()
  end
end

local function LayoutTabs(frame, aura)
  if not frame or not frame.tabs then
    return
  end

  local previousVisible
  for _, key in ipairs(ns.Constants.TAB_KEYS) do
    local tab = frame.tabs[key]
    if tab then
      tab:ClearAllPoints()
      if ShouldShowTab(aura, key) then
        if previousVisible then
          tab:SetPoint("TOPLEFT", previousVisible, "TOPRIGHT", 8, 0)
        else
          tab:SetPoint("TOPLEFT", 12, -48)
        end
        previousVisible = tab
      end
    end
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
  frame:SetSize(ns.db.ui.window.width, ns.db.ui.window.height)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  ApplyWindowDragClamp(frame)
  frame:SetScript("OnSizeChanged", function(self)
    ApplyWindowDragClamp(self)
  end)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.06, 0.08, 0.12, 0.98)
  frame:SetBackdropBorderColor(0.32, 0.06, 0.08, 0.95)
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

  frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.header:SetPoint("TOPLEFT", 1, -1)
  frame.header:SetPoint("TOPRIGHT", -1, -1)
  frame.header:SetHeight(38)
  frame.header:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.header:SetBackdropColor(0.10, 0.14, 0.22, 1)
  frame.header:SetBackdropBorderColor(0.18, 0.25, 0.36, 1)

  frame.headerText = frame.header:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.headerText, 20, "OUTLINE")
  frame.headerText:SetPoint("LEFT", 14, 0)
  frame.headerText:SetText("PopAuras")
  frame.headerText:SetTextColor(0.92, 0.95, 1)

  frame.closeButton = CreateFrame("Button", nil, frame.header, "UIPanelCloseButton")
  frame.closeButton:SetPoint("RIGHT", -2, 0)
  frame.closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame.accent = frame:CreateTexture(nil, "BORDER")
  frame.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
  frame.accent:SetVertexColor(0.10, 0.48, 0.92, 1)
  frame.accent:SetPoint("TOPLEFT", 220, -40)
  frame.accent:SetSize(400, 2)

  frame.toolbar = ns.ui.Toolbar:Create(frame)
  frame.toolbar:SetPoint("TOPLEFT", 14, -48)
  frame.toolbar:SetPoint("TOPRIGHT", -14, -32)

  frame.tree = ns.ui.AuraTree:Create(frame)
  frame.tree:SetPoint("TOPLEFT", 14, -92)
  frame.tree:SetPoint("BOTTOMLEFT", 14, 14)
  frame.tree:SetWidth(275)
  frame.tree:SetFrameStrata("FULLSCREEN_DIALOG")
  frame.tree:SetFrameLevel(frame:GetFrameLevel() + 60)

  frame.editor = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.editor:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.editor:SetBackdropColor(0.09, 0.11, 0.16, 0.96)
  frame.editor:SetBackdropBorderColor(0.20, 0.26, 0.34, 1)
  frame.editor:SetPoint("TOPLEFT", frame.tree, "TOPRIGHT", 12, 0)
  frame.editor:SetPoint("BOTTOMRIGHT", -14, 14)
  frame.editor:SetFrameStrata("DIALOG")
  frame.editor:SetFrameLevel(frame:GetFrameLevel() + 5)

  frame.editorTitle = frame.editor:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.editorTitle, 16, "OUTLINE")
  frame.editorTitle:SetPoint("TOPLEFT", 14, -16)
  frame.editorTitle:SetText("Aura Configuration")
  frame.editorTitle:SetTextColor(0.92, 0.95, 1)

  frame.previewAnimateCheck = Frames.CreateCheckbox(frame.editor, "")
  frame.previewAnimateCheck:SetPoint("TOPRIGHT", -18, -14)
  if frame.previewAnimateCheck.Text then
    frame.previewAnimateCheck.Text:SetText("")
    frame.previewAnimateCheck.Text:Hide()
  end
  frame.previewAnimateLabel = frame.editor:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.previewAnimateLabel, 12, "OUTLINE")
  frame.previewAnimateLabel:SetPoint("RIGHT", frame.previewAnimateCheck, "LEFT", -6, 0)
  frame.previewAnimateLabel:SetText("Preview Animation")
  frame.previewAnimateLabel:SetTextColor(0.92, 0.95, 1)
  frame.previewAnimateCheck:SetScript("OnClick", function(selfCheck)
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      selfCheck:SetChecked(false)
      return
    end
    aura.display = aura.display or {}
    aura.display.previewAnimate = selfCheck:GetChecked() == true
    if ns.runtime and ns.runtime.RefreshAura then
      ns.runtime:RefreshAura(aura.id)
    end
    if ns.ui and ns.ui.AuraTree and ns.ui.AuraTree.Refresh then
      ns.ui.AuraTree:Refresh()
    end
  end)

  frame.triggerDebugCheck = Frames.CreateCheckbox(frame.editor, "")
  frame.triggerDebugCheck:SetPoint("RIGHT", frame.previewAnimateLabel, "LEFT", -28, 0)
  if frame.triggerDebugCheck.Text then
    frame.triggerDebugCheck.Text:SetText("")
    frame.triggerDebugCheck.Text:Hide()
  end
  frame.triggerDebugLabel = frame.editor:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.triggerDebugLabel, 12, "OUTLINE")
  frame.triggerDebugLabel:SetPoint("RIGHT", frame.triggerDebugCheck, "LEFT", -6, 0)
  frame.triggerDebugLabel:SetText("Debug Trigger")
  frame.triggerDebugLabel:SetTextColor(0.92, 0.95, 1)
  frame.triggerDebugCheck:SetScript("OnClick", function(selfCheck)
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    local trigger = GetSelectedAuraTrigger(aura)
    if not aura or not trigger then
      selfCheck:SetChecked(false)
      return
    end

    trigger.debug = selfCheck:GetChecked() == true

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

  frame.editorDivider = frame.editor:CreateTexture(nil, "BORDER")
  frame.editorDivider:SetTexture("Interface\\Buttons\\WHITE8x8")
  frame.editorDivider:SetVertexColor(0.20, 0.36, 0.60, 0.75)
  frame.editorDivider:SetPoint("TOPLEFT", 12, -42)
  frame.editorDivider:SetPoint("TOPRIGHT", -12, -42)
  frame.editorDivider:SetHeight(1)

  frame.tabs = {}
  for _, key in ipairs(ns.Constants.TAB_KEYS) do
    local tab = Frames.CreateButton(frame.editor, tabLabels[key], 116, 22, function()
      ns.db.ui.activeTab = key
      self:RefreshSelection()
    end)
    tab:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    tab:SetBackdropColor(0.11, 0.15, 0.21, 0.96)
    tab:SetBackdropBorderColor(0.22, 0.29, 0.38, 1)
    Fonts.Apply(tab:GetFontString(), 12, "OUTLINE")
    frame.tabs[key] = tab
  end

  frame.content = CreateFrame("Frame", nil, frame.editor)
  frame.content:SetPoint("TOPLEFT", 10, -76)
  frame.content:SetPoint("BOTTOMRIGHT", -10, 10)

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

  local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
  if not aura and ns.Registry:GetOrder()[1] then
    ns.db.ui.selectedAuraId = ns.Registry:GetOrder()[1]
    aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
  end
  if not aura and (ns.db.ui.activeTab or "display") ~= "import_export" and GetEditorMode() ~= "new_aura" then
    ns.db.ui.editorMode = "new_aura"
  end

  ns.ui.AuraTree:Refresh()

  local editorMode = GetEditorMode()
  local hasTrigger = editorMode ~= "new_aura"
    and aura ~= nil
    and aura.kind ~= "group"
    and aura.kind ~= "dynamic_group"
    and aura.kind ~= "interrupt_tracker"
    and aura.triggers
    and GetSelectedAuraTrigger(aura) ~= nil
  local showPreviewToggle = editorMode ~= "new_aura" and aura ~= nil and aura.kind ~= "interrupt_tracker"
  local selectedTrigger = GetSelectedAuraTrigger(aura)

  self.frame.previewAnimateCheck:SetShown(showPreviewToggle)
  self.frame.previewAnimateLabel:SetShown(showPreviewToggle)
  self.frame.previewAnimateCheck:SetChecked(showPreviewToggle and aura and aura.display and aura.display.previewAnimate == true or false)
  self.frame.triggerDebugCheck:SetShown(hasTrigger)
  self.frame.triggerDebugLabel:SetShown(hasTrigger)
  self.frame.triggerDebugCheck:SetChecked(hasTrigger and selectedTrigger and selectedTrigger.debug == true or false)

  self:HideAllPanels()

  if editorMode == "new_aura" then
    self.frame.editorTitle:SetText("New Aura")
    self.frame.editorDivider:Hide()
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

  self.frame.editorTitle:SetText("Aura Configuration")
  self.frame.editorDivider:Show()

  for key, tab in pairs(self.frame.tabs) do
    if ShouldShowTab(aura, key) then
      tab:Show()
      local active = (ns.db.ui.activeTab or "display") == key
      tab:SetBackdropColor(active and 0.08 or 0.11, active and 0.42 or 0.15, active and 0.82 or 0.21, 0.96)
      tab:SetBackdropBorderColor(active and 0.18 or 0.22, active and 0.62 or 0.29, active and 1.0 or 0.38, 1)
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
    activePanel.frame:Show()
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
