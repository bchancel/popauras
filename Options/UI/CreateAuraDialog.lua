local _, ns = ...

local Frames = ns.util.Frames
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

local DIALOG_WIDTH = 440
local DIALOG_HEIGHT = 286
local CONTENT_WIDTH = DIALOG_WIDTH - 40

function dialog:Create()
  local frame = CreateFrame("Frame", "PopAurasCreateDialog", UIParent, "BackdropTemplate")
  frame:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
  frame:SetPoint("CENTER")
  frame:Hide()
  Theme.StyleSurface(frame, "canvasAlt", "borderStrong")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(200)
  frame:SetToplevel(true)
  frame:EnableMouse(true)

  -- Soft accent wash behind the title, matching the editor header.
  frame.glow = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  frame.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
  frame.glow:SetPoint("TOPLEFT", 1, -1)
  frame.glow:SetPoint("TOPRIGHT", -1, -1)
  frame.glow:SetHeight(86)
  local glowColor = Theme.GetColor("accent")
  if frame.glow.SetGradient and CreateColor then
    frame.glow:SetGradient("HORIZONTAL",
      CreateColor(glowColor[1], glowColor[2], glowColor[3], 0.14),
      CreateColor(glowColor[1], glowColor[2], glowColor[3], 0))
  else
    frame.glow:SetVertexColor(glowColor[1], glowColor[2], glowColor[3], 0.05)
  end

  frame.glyphBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.glyphBox:SetSize(48, 48)
  frame.glyphBox:SetPoint("TOPLEFT", 20, -20)
  Theme.StyleSurface(frame.glyphBox, "accentSoft", "accent")
  frame.glyph = frame.glyphBox:CreateTexture(nil, "ARTWORK")
  frame.glyph:SetSize(30, 30)
  frame.glyph:SetPoint("CENTER")
  Theme.SetTexture(frame.glyph, "accentBright")

  frame.eyebrow = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.eyebrow, "caption")
  frame.eyebrow:SetPoint("TOPLEFT", frame.glyphBox, "TOPRIGHT", 14, -6)
  Theme.SetText(frame.eyebrow, "navigation")

  frame.kindLabel = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.kindLabel, "sectionTitle")
  frame.kindLabel:SetPoint("TOPLEFT", frame.eyebrow, "BOTTOMLEFT", 0, -3)
  frame.kindLabel:SetPoint("RIGHT", frame, "RIGHT", -44, 0)
  frame.kindLabel:SetJustifyH("LEFT")
  frame.kindLabel:SetWordWrap(false)
  Theme.SetText(frame.kindLabel, "text")

  frame.closeButton = Frames.CreateButton(frame, "x", 26, 24, function()
    frame:Hide()
  end)
  frame.closeButton:SetPoint("TOPRIGHT", -10, -10)
  Theme.StyleButton(frame.closeButton, "ghost")

  frame.divider = Theme.CreateAccentLine(frame, 1, "border")
  frame.divider:SetPoint("TOPLEFT", 1, -86)
  frame.divider:SetPoint("TOPRIGHT", -1, -86)

  frame.description = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.description, "bodySmall")
  frame.description:SetPoint("TOPLEFT", 20, -102)
  frame.description:SetWidth(CONTENT_WIDTH)
  frame.description:SetJustifyH("LEFT")
  frame.description:SetWordWrap(true)
  if frame.description.SetMaxLines then
    frame.description:SetMaxLines(2)
  end
  Theme.SetText(frame.description, "textMuted")

  frame.nameLabel = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.nameLabel, "caption")
  frame.nameLabel:SetPoint("TOPLEFT", 20, -146)
  frame.nameLabel:SetText("AURA NAME")
  Theme.SetText(frame.nameLabel, "navigation")

  frame.nameInput = Frames.CreateInput(frame, CONTENT_WIDTH, 28)
  frame.nameInput:SetPoint("TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, -6)
  frame.nameInput:SetScript("OnEscapePressed", function(selfInput)
    selfInput:ClearFocus()
    frame:Hide()
  end)

  frame.nameNote = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.nameNote, "caption")
  frame.nameNote:SetPoint("TOPLEFT", frame.nameInput, "BOTTOMLEFT", 0, -6)
  frame.nameNote:SetText("Names are made unique automatically.")
  Theme.SetText(frame.nameNote, "textMuted")

  frame:SetScript("OnHide", function(selfFrame)
    local onHide = selfFrame.onHide
    selfFrame.onHide = nil
    if type(onHide) == "function" then
      onHide()
    end
  end)

  frame.cancelButton = Frames.CreateButton(frame, "Cancel", 100, 28, function()
    frame:Hide()
  end)
  frame.cancelButton:SetPoint("BOTTOMRIGHT", -128, 20)
  Theme.StyleButton(frame.cancelButton, "ghost")
  Theme.ApplyTypography(frame.cancelButton:GetFontString(), "control")

  frame.createButton = Frames.CreateButton(frame, "Create", 100, 28, function()
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
  frame.createButton:SetPoint("BOTTOMRIGHT", -20, 20)
  Frames.StylePrimaryButton(frame.createButton)
  Theme.ApplyTypography(frame.createButton:GetFontString(), "control")

  frame.nameInput:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    frame.createButton:Click()
  end)

  self.frame = frame
  return frame
end

-- meta (optional, from the New Aura picker): title, category, description,
-- glyph (a UiType* texture name) and onHide.
function dialog:Show(kind, preset, meta)
  if not IsPresetEnabled(preset) then
    return
  end

  if not self.frame then
    self:Create()
  end
  meta = type(meta) == "table" and meta or {}

  local info = GetAuraKindInfo(kind, preset)
  self.frame.pendingKind = kind or "bar"
  self.frame.pendingPreset = preset
  if self.frame:IsShown() then
    self.frame:Hide()
  end
  self.frame.onHide = meta.onHide
  self.frame.kindLabel:SetText(meta.title or info.label)
  self.frame.eyebrow:SetText(string.upper(meta.category or "New aura"))
  self.frame.description:SetText(meta.description or "")
  self.frame.glyph:SetTexture(Frames.UI_ICON_PATH .. (meta.glyph or "UiTypeIcon"))
  self.frame.nameInput:SetText(ns.Registry:GetUniqueAuraName(info.defaultName))
  self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
  self.frame:SetFrameLevel(200)
  self.frame:Raise()
  self.frame:Show()
  self.frame.nameInput:SetFocus()
  self.frame.nameInput:HighlightText()
end
