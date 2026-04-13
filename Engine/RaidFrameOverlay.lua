local _, ns = ...

local RaidFrameOverlay = {}
ns.RaidFrameOverlay = RaidFrameOverlay

local ICON_SIZE = 18
local ICON_PADDING = 2
local OVERLAY_KEY = "PopAurasRFOverlay"

local pool = {}
local activeIcons = {}

local function AcquireIcon()
  local icon = table.remove(pool)
  if icon then
    return icon
  end

  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(ICON_SIZE, ICON_SIZE)
  frame:SetFrameStrata("HIGH")

  frame.texture = frame:CreateTexture(nil, "ARTWORK")
  frame.texture:SetAllPoints()

  frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  frame.cooldown:SetAllPoints()
  frame.cooldown:SetDrawEdge(false)
  frame.cooldown:SetDrawBling(false)
  frame.cooldown:SetReverse(true)
  if frame.cooldown.SetSwipeColor then
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.5)
  end
  if frame.cooldown.SetHideCountdownNumbers then
    frame.cooldown:SetHideCountdownNumbers(true)
  end

  frame.border = frame:CreateTexture(nil, "BACKGROUND")
  frame.border:SetPoint("TOPLEFT", -1, 1)
  frame.border:SetPoint("BOTTOMRIGHT", 1, -1)
  frame.border:SetTexture("Interface\\Buttons\\WHITE8x8")
  frame.border:SetVertexColor(0, 0, 0, 0.9)

  return frame
end

local function ReleaseIcon(icon)
  icon:ClearAllPoints()
  icon:SetParent(UIParent)
  icon:Hide()
  icon.cooldown:Hide()
  icon._overlayAuraId = nil
  pool[#pool + 1] = icon
end

local function PositionIconsOnFrame(unitFrame, icons)
  if not unitFrame or #icons == 0 then
    return
  end

  local totalWidth = #icons * ICON_SIZE + (#icons - 1) * ICON_PADDING
  local startX = -math.floor(totalWidth / 2)

  for i, icon in ipairs(icons) do
    icon:ClearAllPoints()
    icon:SetParent(unitFrame)
    icon:SetFrameStrata("HIGH")
    icon:SetPoint("BOTTOMLEFT", unitFrame, "BOTTOM", startX + (i - 1) * (ICON_SIZE + ICON_PADDING), 2)
    icon:Show()
  end
end

function RaidFrameOverlay:Update(auraId, aura, state)
  if not auraId or not aura or not state then
    self:Clear(auraId)
    return
  end

  if not state.show or not state.active then
    self:Clear(auraId)
    return
  end

  local matchedUnits = state.matchedUnits
  if not matchedUnits or #matchedUnits == 0 then
    self:Clear(auraId)
    return
  end

  if not ns.UnitFrameGlow or not ns.UnitFrameGlow.FindUnitFramesForUnit then
    self:Clear(auraId)
    return
  end

  local iconTexture = ns.util.Spells:ResolveDisplayIcon(aura, state)
  local canRenderCooldown = state.progressType == "timed"
    and (state.duration or 0) > 0
    and (state.expirationTime or 0) > GetTime()
  local start = canRenderCooldown and (state.expirationTime - state.duration) or 0
  local duration = canRenderCooldown and state.duration or 0

  self:Clear(auraId)
  local icons = {}

  for _, unitId in ipairs(matchedUnits) do
    local unitFrames = ns.UnitFrameGlow:FindUnitFramesForUnit(unitId)
    if unitFrames then
      for _, unitFrame in ipairs(unitFrames) do
        local icon = AcquireIcon()
        icon._overlayAuraId = auraId
        icon.texture:SetTexture(iconTexture)

        if canRenderCooldown and not (issecretvalue and (issecretvalue(start) or issecretvalue(duration))) then
          icon.cooldown:SetCooldown(start, duration)
          icon.cooldown:Show()
        else
          icon.cooldown:Hide()
        end

        icon:ClearAllPoints()
        icon:SetParent(unitFrame)
        icon:SetFrameStrata("HIGH")

        local existing = activeIcons[auraId]
        local count = existing and #existing or 0
        icon:SetPoint("BOTTOMLEFT", unitFrame, "BOTTOM",
          -(ICON_SIZE / 2) + count * (ICON_SIZE + ICON_PADDING), 2)
        icon:Show()

        if not activeIcons[auraId] then
          activeIcons[auraId] = {}
        end
        activeIcons[auraId][#activeIcons[auraId] + 1] = icon
      end
    end
  end

  self:RepositionForAura(auraId)
end

function RaidFrameOverlay:RepositionForAura(auraId)
  local icons = activeIcons[auraId]
  if not icons or #icons == 0 then
    return
  end

  local byParent = {}
  for _, icon in ipairs(icons) do
    local parent = icon:GetParent()
    if parent then
      byParent[parent] = byParent[parent] or {}
      byParent[parent][#byParent[parent] + 1] = icon
    end
  end

  for unitFrame, frameIcons in pairs(byParent) do
    PositionIconsOnFrame(unitFrame, frameIcons)
  end
end

function RaidFrameOverlay:Clear(auraId)
  if not auraId then
    return
  end

  local icons = activeIcons[auraId]
  if not icons then
    return
  end

  for _, icon in ipairs(icons) do
    ReleaseIcon(icon)
  end
  activeIcons[auraId] = nil
end

function RaidFrameOverlay:ClearAll()
  for auraId in pairs(activeIcons) do
    self:Clear(auraId)
  end
end
