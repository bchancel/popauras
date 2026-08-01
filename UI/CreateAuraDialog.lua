local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts
local Theme = ns.util.Theme

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
  aura_bar_list = {
    label = "Buffs and Debuffs",
    defaultName = "Buffs and Debuffs",
    triggerType = "aura_list",
  },
}

local presetOverrides = {
  death_alert_text = {
    label = "Death Alert",
    defaultName = "Death Alert",
    triggerType = "death_alert",
  },
  nameplate_buffs = {
    label = "Nameplate Buff Display",
    defaultName = "Nameplate Buffs",
    triggerType = "aura",
  },
}

local function IsPresetEnabled(preset)
  return preset ~= "nameplate_buffs"
    or (ns.Features and ns.Features:IsEnabled("feature_nameplate_buffs") == true)
end

local function ApplyPreset(aura, preset)
  if not aura or preset ~= "nameplate_buffs" then
    return
  end

  local trigger = aura.triggers and aura.triggers[1]
  if not trigger then
    return
  end

  trigger.unit = "nameplate"
  trigger.auraType = "buff"
  trigger.auraFilter = "present"
  trigger.castByMe = false
  trigger.aliveOnly = true
  trigger.ignoreNPCs = false
  trigger.spellId = nil
  trigger.spellIDs = nil
  trigger.spellNames = nil
  trigger.nameplateAllBuffs = true
  trigger.nameplateStealable = false
  trigger.nameplateMagic = false
  trigger.nameplateBossAura = false
  trigger.nameplatePriorityAura = false
  trigger.nameplateMaxAuras = 3

  aura.load.instanceType = "party"
  aura.display.width = 26
  aura.display.height = 26
  aura.display.spacing = 3
  aura.display.growth = "RIGHT"
  aura.display.showName = false
  aura.display.showTimer = true
  aura.display.showStacks = true
  aura.display.showBackground = true
  aura.display.backgroundColor = { r = 0, g = 0, b = 0, a = 0.65 }
  aura.display.swipe = true
  aura.display.soundEnabled = false
  aura.display.showOnRaidFrames = false
  aura.display.frameStrata = "HIGH"
  aura.display.frameLevel = 10
  ns.util.Anchors.ApplyNameplateAnchor(aura.position, "TOP")
  aura.position.x = 0
  aura.position.y = 18
  aura.position.width = 26
  aura.position.height = 26
end

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
  Theme.StyleSurface(frame, "canvasAlt", "borderStrong")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(200)
  frame:SetToplevel(true)

  frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.header:SetPoint("TOPLEFT", 1, -1)
  frame.header:SetPoint("TOPRIGHT", -1, -1)
  frame.header:SetHeight(34)
  Theme.StyleSurface(frame.header, "surfaceRaised", "border")

  frame.headerText = Frames.CreateLabel(frame.header, "Create Aura", "GameFontNormalLarge")
  frame.headerText:SetPoint("LEFT", 12, 0)
  Fonts.Apply(frame.headerText, 16, "OUTLINE")
  Theme.SetText(frame.headerText, "text")

  frame.closeButton = Frames.CreateButton(frame.header, "x", 26, 24, function()
    frame:Hide()
  end)
  frame.closeButton:SetPoint("RIGHT", -6, 0)
  Frames.StyleSecondaryButton(frame.closeButton)

  frame.kindLabel = Frames.CreateLabel(frame, "", "GameFontHighlight")
  frame.kindLabel:SetPoint("TOPLEFT", 18, -52)
  frame.kindLabel:SetWidth(360)
  Theme.SetText(frame.kindLabel, "textSecondary")

  frame.nameLabel = Frames.CreateLabel(frame, "Aura Name", "GameFontNormal")
  frame.nameLabel:SetPoint("TOPLEFT", frame.kindLabel, "BOTTOMLEFT", 0, -16)
  Theme.SetText(frame.nameLabel, "textAccent")

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
    if not IsPresetEnabled(frame.pendingPreset) then
      frame:Hide()
      return
    end

    local kind = frame.pendingKind or "bar"
    local info = GetAuraKindInfo(kind, frame.pendingPreset)
    local requestedName = ns.Registry:GetUniqueAuraName(frame.nameInput:GetText())
    local aura = ns.Registry:CreateAura(kind, info.triggerType)
    aura.name = requestedName
    ApplyPreset(aura, frame.pendingPreset)
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
  if not IsPresetEnabled(preset) then
    return
  end

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
