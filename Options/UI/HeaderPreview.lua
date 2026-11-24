local _, ns = ...

local Theme = ns.util.Theme

-- Live preview in the editor header. It is drawn ONLY from the selected aura's
-- saved display settings plus a sample countdown; it never reads live aura,
-- cooldown or Cooldown Manager state, so restricted (secret) values cannot
-- reach it. Click cycles through Active / Inactive / Unavailable so authors can
-- see each state without waiting for it in combat.
local HeaderPreview = {}
ns.ui.HeaderPreview = HeaderPreview

local STAGE_WIDTH, STAGE_HEIGHT = 300, 58
local SAMPLE_DURATION = 12
local SAMPLE_STACKS = "3"
local LAYOUT_INTERVAL = 0.25
local QUESTION_MARK_ICON = 134400
local STATES = { "active", "inactive", "unavailable" }
local STATE_LABELS = { active = "ACTIVE", inactive = "INACTIVE", unavailable = "UNAVAILABLE" }

local function ReadColor(color, r, g, b, a)
  if type(color) ~= "table" then
    return r, g, b, a
  end
  local function Channel(value, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.max(0, math.min(1, value))
  end
  return Channel(color.r, r), Channel(color.g, g), Channel(color.b, b), Channel(color.a, a)
end

local function ApplyFont(fontString, size, scale)
  Theme.ApplyFontSize(fontString, math.max(8, (tonumber(size) or 12) * scale), "OUTLINE")
end

local function GetSampleTexture(aura)
  local Spells = ns.util.Spells
  if not Spells or not Spells.GetSpellTextureByOverride then
    return QUESTION_MARK_ICON
  end
  local display = aura.display or {}
  local texture = Spells:GetSpellTextureByOverride(display.iconOverrideId, display.iconOverrideName)
  local trigger = type(aura.triggers) == "table" and aura.triggers[1] or nil
  local spellId = trigger and tonumber(trigger.spellId) or nil
  if not texture and spellId and spellId > 0 then
    texture = Spells:GetSpellTextureByOverride(spellId)
  end
  return texture or QUESTION_MARK_ICON
end

function HeaderPreview:Create(parent)
  local frame = CreateFrame("Button", "PopAurasOptionsPreview", parent, "BackdropTemplate")
  frame:SetSize(STAGE_WIDTH, STAGE_HEIGHT)
  Theme.StyleSurface(frame, "canvasAlt", "border")
  frame:RegisterForClicks("LeftButtonUp")

  frame.label = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.label, "micro")
  frame.label:SetPoint("TOPLEFT", 8, -5)
  frame.label:SetText("PREVIEW")
  Theme.SetText(frame.label, "textMuted")

  frame.stateText = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.stateText, "micro")
  frame.stateText:SetPoint("TOPRIGHT", -8, -5)
  Theme.SetText(frame.stateText, "accentBright")

  frame.sample = CreateFrame("Frame", nil, frame)
  frame.sample:SetPoint("CENTER", 0, -5)
  frame.sample:SetSize(200, 20)

  frame.icon = frame.sample:CreateTexture(nil, "ARTWORK")
  frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  frame.bar = CreateFrame("StatusBar", nil, frame.sample)
  frame.bar:SetMinMaxValues(0, 1)
  frame.bar:SetValue(1)
  frame.barBackground = frame.bar:CreateTexture(nil, "BACKGROUND")
  frame.barBackground:SetAllPoints()
  frame.barBackground:SetTexture("Interface\\Buttons\\WHITE8x8")

  -- Text sits on its own frame above the bar so it always draws on top.
  frame.textLayer = CreateFrame("Frame", nil, frame.sample)
  frame.textLayer:SetAllPoints()
  frame.textLayer:SetFrameLevel(frame.bar:GetFrameLevel() + 3)
  frame.nameText = frame.textLayer:CreateFontString(nil, "OVERLAY")
  frame.timerText = frame.textLayer:CreateFontString(nil, "OVERLAY")
  frame.stacksText = frame.textLayer:CreateFontString(nil, "OVERLAY")
  frame.nameText:SetWordWrap(false)

  frame.message = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.message, "bodySmall")
  frame.message:SetPoint("CENTER", 0, -5)
  Theme.SetText(frame.message, "textMuted")
  frame.message:Hide()

  frame:SetScript("OnClick", function()
    HeaderPreview:CycleState()
  end)
  frame:SetScript("OnEnter", function(selfFrame)
    Theme.SetBackdrop(selfFrame, "canvasAlt", "borderStrong")
    GameTooltip:SetOwner(selfFrame, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Preview")
    GameTooltip:AddLine("A sample built from this aura's display settings. It updates as you edit.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Click to switch between Active, Inactive and Unavailable.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function(selfFrame)
    Theme.SetBackdrop(selfFrame, "canvasAlt", "border")
    GameTooltip:Hide()
  end)

  self.state = "active"
  self.sampleClock = 0
  self.layoutClock = 0
  frame:SetScript("OnUpdate", function(_, elapsed)
    HeaderPreview:OnUpdate(tonumber(elapsed) or 0)
  end)

  self.frame = frame
  return frame
end

function HeaderPreview:SetAura(aura)
  self.auraId = aura and aura.id or nil
  self.sampleClock = 0
  self:Layout()
end

function HeaderPreview:CycleState()
  local nextIndex = 1
  for index, state in ipairs(STATES) do
    if state == self.state then
      nextIndex = (index % #STATES) + 1
      break
    end
  end
  self.state = STATES[nextIndex]
  self.sampleClock = 0
  self:Layout()
end

function HeaderPreview:OnUpdate(elapsed)
  -- The editor only opens out of combat, but it can stay open into a fight;
  -- the preview simply freezes until combat ends.
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  self.layoutClock = self.layoutClock + elapsed
  if self.layoutClock >= LAYOUT_INTERVAL then
    -- Cheap re-read of saved settings so edits show without wiring every control.
    self.layoutClock = 0
    self:Layout()
  end
  self.sampleClock = (self.sampleClock + elapsed) % SAMPLE_DURATION
  self:UpdateCountdown()
end

function HeaderPreview:UpdateCountdown()
  local frame = self.frame
  if not frame or not frame.sample:IsShown() then
    return
  end
  if self.state == "active" then
    local remaining = SAMPLE_DURATION - self.sampleClock
    frame.bar:SetValue(remaining / SAMPLE_DURATION)
    if remaining < 3 then
      frame.timerText:SetText(string.format("%.1f", remaining))
    else
      frame.timerText:SetText(tostring(math.ceil(remaining)))
    end
  elseif self.state == "inactive" then
    frame.bar:SetValue(0)
    frame.timerText:SetText("")
  else
    frame.bar:SetValue(0)
    frame.timerText:SetText("")
  end
end

function HeaderPreview:Layout()
  local frame = self.frame
  if not frame then
    return
  end
  local aura = self.auraId and ns.Registry:GetAura(self.auraId) or nil
  local kind = aura and aura.kind or nil
  local supported = kind == "bar" or kind == "icon"
  frame.stateText:SetText(supported and STATE_LABELS[self.state] or "")
  frame.sample:SetShown(supported)
  if not supported then
    frame.message:SetText(aura and "No preview for this aura type" or "")
    Theme.SetText(frame.message, "textMuted")
    frame.message:Show()
    return
  end

  local display = aura.display or {}
  local width = math.max(8, tonumber(display.width) or 220)
  local height = math.max(8, tonumber(display.height) or 32)
  -- Small icons are shown up to 1.4x so the sample reads; large ones shrink to fit.
  local scale = math.min(1.4, (STAGE_WIDTH - 24) / width, (STAGE_HEIGHT - 22) / height)
  local sampleWidth = math.max(8, math.floor(width * scale + 0.5))
  local sampleHeight = math.max(8, math.floor(height * scale + 0.5))
  frame.sample:SetSize(sampleWidth, sampleHeight)

  frame.icon:SetTexture(GetSampleTexture(aura))
  frame.icon:ClearAllPoints()
  frame.bar:ClearAllPoints()
  frame.nameText:ClearAllPoints()
  frame.timerText:ClearAllPoints()
  frame.stacksText:ClearAllPoints()

  if kind == "icon" then
    frame.icon:SetAllPoints(frame.sample)
    frame.icon:Show()
    frame.bar:Hide()
    frame.timerText:SetPoint("CENTER", frame.sample, "CENTER", 0, 0)
    frame.nameText:SetPoint("TOP", frame.sample, "BOTTOM", 0, -1)
    frame.nameText:SetWidth(math.max(40, sampleWidth + 40))
    frame.stacksText:SetPoint("BOTTOMRIGHT", frame.sample, "BOTTOMRIGHT", -1, 1)
  else
    local showIcon = display.icon == true
    frame.icon:SetShown(showIcon)
    if showIcon then
      frame.icon:SetPoint("TOPLEFT", frame.sample, "TOPLEFT", 0, 0)
      frame.icon:SetSize(sampleHeight, sampleHeight)
      frame.bar:SetPoint("TOPLEFT", frame.sample, "TOPLEFT", sampleHeight, 0)
    else
      frame.bar:SetPoint("TOPLEFT", frame.sample, "TOPLEFT", 0, 0)
    end
    frame.bar:SetPoint("BOTTOMRIGHT", frame.sample, "BOTTOMRIGHT", 0, 0)
    frame.bar:Show()
    local Media = ns.util.Media
    frame.bar:SetStatusBarTexture(Media and Media.ResolveStatusBarTexture
      and Media:ResolveStatusBarTexture(display.barTexture) or "Interface\\Buttons\\WHITE8x8")
    frame.bar:SetStatusBarColor(ReadColor(display.color, 0.1, 0.6, 1, 1))
    local showBackground = display.showBackground == true
    frame.barBackground:SetShown(showBackground)
    if showBackground then
      frame.barBackground:SetVertexColor(ReadColor(display.backgroundColor, 0, 0, 0, 0.5))
    end
    frame.nameText:SetPoint("LEFT", frame.bar, "LEFT", 4, 0)
    frame.nameText:SetPoint("RIGHT", frame.timerText, "LEFT", -4, 0)
    frame.nameText:SetJustifyH("LEFT")
    frame.timerText:SetPoint("RIGHT", frame.bar, "RIGHT", -4, 0)
    frame.stacksText:SetPoint("BOTTOMRIGHT", frame.icon:IsShown() and frame.icon or frame.bar, "BOTTOMRIGHT", -1, 1)
  end

  local nameText = aura.text and aura.text.nameOverride
  if type(nameText) ~= "string" or nameText == "" then
    nameText = aura.name or ""
  end
  ApplyFont(frame.nameText, display.nameFontSize, scale)
  ApplyFont(frame.timerText, display.timerFontSize, scale)
  ApplyFont(frame.stacksText, display.stacksFontSize, scale)
  frame.nameText:SetTextColor(ReadColor(display.nameColor, 1, 1, 1, 1))
  frame.timerText:SetTextColor(ReadColor(display.timerColor, 1, 1, 1, 1))
  frame.stacksText:SetTextColor(ReadColor(display.stacksColor, 1, 1, 1, 1))
  frame.nameText:SetText(nameText)
  frame.stacksText:SetText(SAMPLE_STACKS)
  frame.nameText:SetShown(display.showName ~= false)
  frame.timerText:SetShown(display.showTimer ~= false and self.state == "active")
  frame.stacksText:SetShown(display.showStacks == true and self.state == "active")

  local unavailable = self.state == "unavailable"
  local inactive = self.state == "inactive"
  frame.sample:SetAlpha((inactive or unavailable) and 0.38 or 1)
  frame.icon:SetDesaturated(inactive or unavailable)
  frame.message:SetShown(unavailable)
  if unavailable then
    frame.message:SetText("Restricted or unsupported slot")
    Theme.SetText(frame.message, "textSecondary")
  end
  self:UpdateCountdown()
end
