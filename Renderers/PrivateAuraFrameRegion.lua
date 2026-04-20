local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local PrivateAuras = ns.util.PrivateAuras

local PrivateAuraFrameRegion = {}
ns.renderers.PrivateAuraFrameRegion = PrivateAuraFrameRegion

local MAX_PRIVATE_AURA_SLOTS = 6

local function GetTrigger(aura)
  if not aura or type(aura.triggers) ~= "table" then
    return nil
  end
  return aura.triggers[1]
end

function PrivateAuraFrameRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.frame:SetClipsChildren(false)
  instance.slots = {}
  return instance
end

function PrivateAuraFrameRegion:EnsureSlot(index)
  local slot = self.slots[index]
  if slot then
    return slot
  end

  slot = CreateFrame("Frame", nil, self.frame)
  slot:SetClipsChildren(false)

  slot.previewBorder = slot:CreateTexture(nil, "BACKGROUND")
  slot.previewBorder:SetAllPoints()
  slot.previewBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
  slot.previewBorder:SetVertexColor(0.18, 0.28, 0.40, 0.55)
  slot.previewBorder:Hide()

  slot.previewIcon = slot:CreateTexture(nil, "ARTWORK")
  slot.previewIcon:SetAllPoints()
  slot.previewIcon:SetTexture(134400)
  slot.previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  slot.previewIcon:SetVertexColor(0.92, 0.95, 1, 0.85)
  slot.previewIcon:Hide()

  self.slots[index] = slot
  return slot
end

local function RemovePrivateAuraAnchor(slot)
  if not slot or not slot.privateAuraAnchorID or not (C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor) then
    return
  end

  pcall(C_UnitAuras.RemovePrivateAuraAnchor, slot.privateAuraAnchorID)
  slot.privateAuraAnchorID = nil
end

function PrivateAuraFrameRegion:LayoutSlots(aura)
  local width = self.frame:GetWidth() or aura.display.width or 40
  local height = self.frame:GetHeight() or aura.display.height or 40
  local spacing = tonumber(aura.display.spacing or 6) or 6
  local growth = tostring(aura.display.growth or "RIGHT")

  local previous = nil
  for index = 1, MAX_PRIVATE_AURA_SLOTS do
    local slot = self:EnsureSlot(index)
    slot:ClearAllPoints()
    slot:SetSize(width, height)

    if previous == nil then
      slot:SetAllPoints(self.frame)
    elseif growth == "LEFT" then
      slot:SetPoint("TOPRIGHT", previous, "TOPLEFT", -spacing, 0)
    elseif growth == "UP" then
      slot:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, spacing)
    elseif growth == "DOWN" then
      slot:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing)
    else
      slot:SetPoint("TOPLEFT", previous, "TOPRIGHT", spacing, 0)
    end

    previous = slot
  end
end

function PrivateAuraFrameRegion:SyncAnchors(aura, unit)
  local addAnchor = C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor or nil
  local width = self.frame:GetWidth() or aura.display.width or 40
  local height = self.frame:GetHeight() or aura.display.height or 40
  local signature = string.format("%s:%d:%d", tostring(unit or ""), math.floor(width + 0.5), math.floor(height + 0.5))

  for index = 1, MAX_PRIVATE_AURA_SLOTS do
    local slot = self:EnsureSlot(index)
    if slot.privateAuraSignature ~= signature then
      RemovePrivateAuraAnchor(slot)
      slot.privateAuraSignature = signature

      if addAnchor and unit then
        local ok, anchorID = pcall(addAnchor, {
          unitToken = unit,
          auraIndex = index,
          parent = slot,
          showCountdownFrame = true,
          showCountdownNumbers = true,
          iconInfo = {
            iconWidth = width,
            iconHeight = height,
            borderScale = 1,
            iconAnchor = {
              point = "CENTER",
              relativeTo = slot,
              relativePoint = "CENTER",
              offsetX = 0,
              offsetY = 0,
            },
          },
        })
        if ok then
          slot.privateAuraAnchorID = anchorID
        end
      end
    end
  end
end

function PrivateAuraFrameRegion:ApplyPreviewState(state)
  local previewCount = state and state.source == "preview" and 3 or 0
  for index = 1, MAX_PRIVATE_AURA_SLOTS do
    local slot = self:EnsureSlot(index)
    local showPreview = index <= previewCount
    slot.previewBorder:SetShown(showPreview)
    slot.previewIcon:SetShown(showPreview)
  end
end

function PrivateAuraFrameRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state

  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)
  BaseRegion:ApplyCommonAppearance(aura, self.frame, state)

  self:LayoutSlots(aura)
  self:SyncAnchors(aura, PrivateAuras and PrivateAuras.ResolveUnit and PrivateAuras:ResolveUnit(GetTrigger(aura)) or "player")
  self:ApplyPreviewState(state)
end

function PrivateAuraFrameRegion:Release()
  for _, slot in ipairs(self.slots or {}) do
    RemovePrivateAuraAnchor(slot)
  end
  BaseRegion.Release(self)
end

