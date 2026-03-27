local _, ns = ...

local GroupRegion = ns.renderers.GroupRegion

local DynamicGroupRegion = {}
ns.renderers.DynamicGroupRegion = DynamicGroupRegion

function DynamicGroupRegion:New(aura)
  local instance = GroupRegion:New(aura)
  setmetatable(instance, { __index = self })
  return instance
end

function DynamicGroupRegion:CollectChildren(aura)
  local regions = GroupRegion.CollectChildren(self, aura)
  if aura.display and aura.display.maintainAuraOrder == true then
    local childOrder = {}
    for index, childId in ipairs(aura.children or {}) do
      childOrder[childId] = index
    end
    table.sort(regions, function(left, right)
      local leftId = left.frame and left.frame.auraId
      local rightId = right.frame and right.frame.auraId
      local leftIndex = childOrder[leftId] or math.huge
      local rightIndex = childOrder[rightId] or math.huge
      if leftIndex == rightIndex then
        return (leftId or "") < (rightId or "")
      end
      return leftIndex < rightIndex
    end)
  else
    table.sort(regions, function(left, right)
      local leftOrder = ns.runtime:GetActivationOrder(left.frame and left.frame.auraId)
      local rightOrder = ns.runtime:GetActivationOrder(right.frame and right.frame.auraId)
      if leftOrder == rightOrder then
        return (left.frame and left.frame.auraId or "") < (right.frame and right.frame.auraId or "")
      end
      return leftOrder < rightOrder
    end)
  end
  return regions
end

function DynamicGroupRegion:Update(aura, state)
  GroupRegion.Update(self, aura, state)
end

setmetatable(DynamicGroupRegion, { __index = GroupRegion })
