local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts

local dialog = {}
ns.ui.CreateAuraDialog = dialog

local auraKinds = {
  icon = {
    label = "Icon Aura",
    defaultName = "New Icon",
    triggerType = "spell_cooldown",
  },
  bar = {
    label = "Bar Aura",
    defaultName = "New Bar",
    triggerType = "spell_cooldown",
  },
  text = {
    label = "Text Aura",
    defaultName = "New Text",
    triggerType = "simple",
  },
  group = {
    label = "Group",
    defaultName = "New Group",
  },
  dynamic_group = {
    label = "Dynamic Group",
    defaultName = "New Dynamic Group",
  },
  interrupt_tracker = {
    label = "Interrupt Tracker",
    defaultName = "New Interrupt Tracker",
  },
}

local presetOverrides = {
  death_alert_text = {
    label = "Death Alert",
    defaultName = "Death Alert",
    triggerType = "death_alert",
  },
}

local function GetAuraKindInfo(kind, preset)
  if preset and presetOverrides[preset] then
    return presetOverrides[preset]
  end
  return auraKinds[kind] or auraKinds.bar
end

function dialog:Create()
  local frame = CreateFrame("Frame", "PopAurasCreateDialog", UIParent, "BackdropTemplate")
  frame:SetSize(420, 220)
  frame:SetPoint("CENTER")
  frame:Hide()
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.08, 0.10, 0.15, 0.98)
  frame:SetBackdropBorderColor(0.22, 0.28, 0.36, 1)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(200)
  frame:SetToplevel(true)

  frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.header:SetPoint("TOPLEFT", 1, -1)
  frame.header:SetPoint("TOPRIGHT", -1, -1)
  frame.header:SetHeight(34)
  frame.header:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.header:SetBackdropColor(0.10, 0.14, 0.22, 1)
  frame.header:SetBackdropBorderColor(0.18, 0.25, 0.36, 1)

  frame.headerText = Frames.CreateLabel(frame.header, "Create Aura", "GameFontNormalLarge")
  frame.headerText:SetPoint("LEFT", 12, 0)
  Fonts.Apply(frame.headerText, 16, "OUTLINE")
  frame.headerText:SetTextColor(0.92, 0.95, 1)

  frame.closeButton = CreateFrame("Button", nil, frame.header, "UIPanelCloseButton")
  frame.closeButton:SetPoint("RIGHT", -2, 0)
  frame.closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame.kindLabel = Frames.CreateLabel(frame, "", "GameFontHighlight")
  frame.kindLabel:SetPoint("TOPLEFT", 18, -52)
  frame.kindLabel:SetWidth(360)
  frame.kindLabel:SetTextColor(0.82, 0.88, 0.97)

  frame.nameLabel = Frames.CreateLabel(frame, "Aura Name", "GameFontNormal")
  frame.nameLabel:SetPoint("TOPLEFT", frame.kindLabel, "BOTTOMLEFT", 0, -16)
  frame.nameLabel:SetTextColor(1, 0.88, 0.15)

  frame.nameInput = Frames.CreateInput(frame, 290, 24)
  frame.nameInput:SetPoint("TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, -6)
  frame.nameInput:SetScript("OnEscapePressed", function(selfInput)
    selfInput:ClearFocus()
    frame:Hide()
  end)

  frame.cancelButton = Frames.CreateButton(frame, "Cancel", 120, 28, function()
    frame:Hide()
  end)
  frame.cancelButton:SetPoint("BOTTOMRIGHT", -144, 18)
  Frames.StyleSecondaryButton(frame.cancelButton)
  Fonts.Apply(frame.cancelButton:GetFontString(), 14, "OUTLINE")

  frame.createButton = Frames.CreateButton(frame, "Create", 120, 28, function()
    local kind = frame.pendingKind or "bar"
    local info = GetAuraKindInfo(kind, frame.pendingPreset)
    local requestedName = ns.Registry:GetUniqueAuraName(frame.nameInput:GetText())
    local aura = ns.Registry:CreateAura(kind, info.triggerType)
    aura.name = requestedName
    ns.db.ui.editorMode = "config"
    ns.db.ui.activeTab = "display"
    ns.db.ui.selectedAuraId = aura.id
    ns.runtime:RefreshAll()
    ns.ui.MainWindow:Refresh()
    frame:Hide()
  end)
  frame.createButton:SetPoint("BOTTOMRIGHT", -18, 18)
  Frames.StylePrimaryButton(frame.createButton)
  Fonts.Apply(frame.createButton:GetFontString(), 14, "OUTLINE")

  frame.nameInput:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    frame.createButton:Click()
  end)

  self.frame = frame
  return frame
end

function dialog:Show(kind, preset)
  if not self.frame then
    self:Create()
  end

  local info = GetAuraKindInfo(kind, preset)
  self.frame.pendingKind = kind or "bar"
  self.frame.pendingPreset = preset
  self.frame.kindLabel:SetText(string.format("Create %s", info.label))
  self.frame.nameInput:SetText(ns.Registry:GetUniqueAuraName(info.defaultName))
  self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
  self.frame:SetFrameLevel(200)
  self.frame:Raise()
  self.frame:Show()
  self.frame.nameInput:SetFocus()
  self.frame.nameInput:HighlightText()
end
