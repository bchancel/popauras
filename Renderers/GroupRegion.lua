local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Layouts = ns.renderers.Layouts

local GroupRegion = {}
ns.renderers.GroupRegion = GroupRegion

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
      if region then
        regions[#regions + 1] = region
      end
    end
  end
  return regions
end

function GroupRegion:Update(aura, state)
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)
  local editorOpen = ns.ui and ns.ui.MainWindow and ns.ui.MainWindow.IsOpen and ns.ui.MainWindow:IsOpen()
  local visible = false
  local children = self:CollectChildren(aura)
  for _, child in ipairs(children) do
    if child.frame:IsShown() then
      visible = true
      break
    end
  end
  local hasBackground = aura.display and aura.display.showBackground == true
  local backgroundColor = (aura.display and aura.display.backgroundColor) or { r = 0.08, g = 0.45, b = 0.9, a = 0.12 }
  local borderAlpha = math.min(1, (backgroundColor.a or 0.3) + 0.16)
  local showPlaceholder = editorOpen and not visible
  local showBackground = hasBackground and visible
  BaseRegion:ApplyCommonAppearance(aura, self.frame, { show = visible or state.show or showPlaceholder or showBackground })
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
