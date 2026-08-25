local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Layouts = ns.renderers.Layouts

local GroupRegion = {}
ns.renderers.GroupRegion = GroupRegion

local function IsRegionLayoutVisible(region)
  if not region or not region.frame then return false end
  return region.layoutVisible == true
end

local function AppendLayoutRegions(target, region)
  if not region then return end
  if region.GetLayoutRegions then
    for _, layoutRegion in ipairs(region:GetLayoutRegions()) do
      target[#target + 1] = layoutRegion
    end
    return
  end
  target[#target + 1] = region
end

function GroupRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.placeholder = instance.frame:CreateTexture(nil, "ARTWORK")
  instance.placeholder:SetAllPoints()
  instance.placeholder:SetTexture("Interface\\Buttons\\WHITE8x8")
  instance.placeholder:SetVertexColor(0.08, 0.45, 0.9, 0.12)
  instance.border = instance.frame:CreateTexture(nil, "BORDER")
  instance.border:SetPoint("TOPLEFT", 0, 0)
  instance.border:SetPoint("BOTTOMRIGHT", 0, 0)
  instance.border:SetTexture("Interface\\Buttons\\WHITE8x8")
  instance.border:SetVertexColor(0.08, 0.65, 1, 0.28)
  instance.label = instance.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  instance.label:SetPoint("CENTER")
  return instance
end

function GroupRegion:CollectChildren(aura)
  local regions = {}
  for _, childId in ipairs(aura.children or {}) do
    local childAura = ns.Registry:GetAura(childId)
    if childAura then
      local childState = ns.runtime:GetPresentation(childId)
      ns.Render:RenderAura(childAura, childState)
      local region = ns.runtime:GetRegionByAuraId(childId)
      AppendLayoutRegions(regions, region)
    end
  end
  return regions
end

function GroupRegion:CollectExistingChildren(aura)
  local regions = {}
  for _, childId in ipairs(aura.children or {}) do
    local region = ns.runtime:GetRegionByAuraId(childId)
    AppendLayoutRegions(regions, region)
  end
  return regions
end

function GroupRegion:ApplyChildLayout(aura, state, children)
  local editorOpen = ns.ui and ns.ui.MainWindow and ns.ui.MainWindow.IsOpen and ns.ui.MainWindow:IsOpen()
  local loadMatched = not state or state.loadMatched ~= false
  local visible = false
  if loadMatched then
    for _, child in ipairs(children) do
      if IsRegionLayoutVisible(child) then
        visible = true
        break
      end
    end
  end
  local hasBackground = aura.display and aura.display.showBackground == true
  local backgroundColor = (aura.display and aura.display.backgroundColor) or { r = 0.08, g = 0.45, b = 0.9, a = 0.12 }
  local borderAlpha = math.min(1, (backgroundColor.a or 0.3) + 0.16)
  local showPlaceholder = editorOpen and not visible
  local showBackground = loadMatched and hasBackground and visible
  local shouldShow = visible or (loadMatched and state and state.show == true) or showPlaceholder or showBackground
  self.layoutVisible = shouldShow
  BaseRegion:ApplyCommonAppearance(aura, self.frame, { show = shouldShow })
  Layouts.ApplyGroupLayout(aura, self.frame, children)
  self.placeholder:SetVertexColor(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, backgroundColor.a or 0)
  self.border:SetVertexColor(backgroundColor.r or 0, backgroundColor.g or 0, backgroundColor.b or 0, borderAlpha)
  self.placeholder:SetShown(showPlaceholder or showBackground)
  self.border:SetShown(showPlaceholder or showBackground)
  self.label:SetShown(showPlaceholder)
  if showPlaceholder then
    local hasChildren = aura.children and #aura.children > 0
    if hasChildren then
      self.label:SetText(aura.name or (aura.kind == "dynamic_group" and "Dynamic Group" or "Group"))
    else
      self.label:SetText((aura.name or (aura.kind == "dynamic_group" and "Dynamic Group" or "Group")) .. "\nEmpty Group")
    end
  end
end

function GroupRegion:Update(aura, state)
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)
  self:ApplyChildLayout(aura, state, self:CollectChildren(aura))
end

function GroupRegion:RefreshChildLayout()
  local auraId = self.frame and self.frame.auraId
  local aura = auraId and ns.Registry:GetAura(auraId) or nil
  if not aura then return false end
  self:ApplyChildLayout(aura, ns.runtime:GetPresentation(auraId), self:CollectExistingChildren(aura))
  return true
end
