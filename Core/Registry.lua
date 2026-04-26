local _, ns = ...

local Tables = ns.util.Tables

local Registry = {}
ns.Registry = Registry

Registry.treeDirty = true
Registry.flatOrderCache = nil
Registry.flatOrderIndexCache = nil

function Registry:MarkDirty()
  self.treeDirty = true
  self.flatOrderCache = nil
  self.flatOrderIndexCache = nil
  if ns.TriggerBase and ns.TriggerBase.InvalidateProviderCaches then
    ns.TriggerBase:InvalidateProviderCaches()
  end
  if ns.runtime and ns.runtime.MarkMissingRegionsDirty then
    ns.runtime:MarkMissingRegionsDirty()
  end
end

function Registry:GetAuras()
  return ns.db.auras
end

function Registry:GetOrder()
  self:NormalizeTree()
  return ns.db.order
end

function Registry:GetAura(auraId)
  return ns.db.auras[auraId]
end

function Registry:IsNameTaken(name, excludeAuraId)
  name = tostring(name or ""):lower()
  if name == "" then
    return false
  end
  for auraId, aura in pairs(ns.db.auras or {}) do
    if auraId ~= excludeAuraId and tostring(aura.name or ""):lower() == name then
      return true
    end
  end
  return false
end

function Registry:GetUniqueAuraName(baseName, excludeAuraId)
  local root = tostring(baseName or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if root == "" then
    root = "New Aura"
  end
  if not self:IsNameTaken(root, excludeAuraId) then
    return root
  end

  local index = 2
  while true do
    local candidate = string.format("%s %d", root, index)
    if not self:IsNameTaken(candidate, excludeAuraId) then
      return candidate
    end
    index = index + 1
  end
end

function Registry:AddAura(aura)
  ns.db.auras[aura.id] = aura
  if aura.parentId then
    local parent = self:GetAura(aura.parentId)
    if parent then
      if not Tables.IndexOf(parent.children, aura.id) then
        parent.children[#parent.children + 1] = aura.id
      end
      self:MarkDirty()
      return
    end
  end

  if not Tables.IndexOf(ns.db.order, aura.id) then
    ns.db.order[#ns.db.order + 1] = aura.id
  end
  self:MarkDirty()
end

function Registry:NormalizeTree()
  if not self.treeDirty then
    return
  end

  ns.db.order = ns.db.order or {}
  ns.db.auras = ns.db.auras or {}

  local childIds = {}
  for auraId, aura in pairs(ns.db.auras) do
    aura.children = aura.children or {}
    if aura.parentId and not ns.db.auras[aura.parentId] then
      aura.parentId = nil
    end

    local normalizedChildren = {}
    local seenChildren = {}
    for _, childId in ipairs(aura.children) do
      if ns.db.auras[childId] and not seenChildren[childId] and childId ~= auraId then
        normalizedChildren[#normalizedChildren + 1] = childId
        seenChildren[childId] = true
        childIds[childId] = true
        ns.db.auras[childId].parentId = auraId
      end
    end
    aura.children = normalizedChildren
  end

  local normalizedOrder = {}
  local seenOrder = {}
  for _, auraId in ipairs(ns.db.order) do
    local aura = ns.db.auras[auraId]
    if aura and not childIds[auraId] and aura.parentId == nil and not seenOrder[auraId] then
      normalizedOrder[#normalizedOrder + 1] = auraId
      seenOrder[auraId] = true
    end
  end

  for auraId, aura in pairs(ns.db.auras) do
    if aura.parentId == nil and not childIds[auraId] and not seenOrder[auraId] then
      normalizedOrder[#normalizedOrder + 1] = auraId
      seenOrder[auraId] = true
    end
  end

  ns.db.order = normalizedOrder
  self.treeDirty = false
  self.flatOrderCache = nil
  self.flatOrderIndexCache = nil
end

function Registry:CreateAura(kind, triggerType)
  local aura = ns.Defaults:NewAura(kind, triggerType)
  aura.name = self:GetUniqueAuraName(aura.name)
  self:AddAura(aura)
  ns.db.ui.selectedAuraId = aura.id
  return aura
end

function Registry:DeleteAura(auraId)
  local aura = self:GetAura(auraId)
  if not aura then
    return
  end

  local childIds = {}
  for _, childId in ipairs(aura.children or {}) do
    childIds[#childIds + 1] = childId
  end
  for _, childId in ipairs(childIds) do
    self:DeleteAura(childId)
  end

  if aura.parentId then
    local parent = self:GetAura(aura.parentId)
    if parent then
      Tables.RemoveValue(parent.children, auraId)
    end
  end

  Tables.RemoveValue(ns.db.order, auraId)
  ns.db.auras[auraId] = nil
  if ns.db.ui.selectedAuraId == auraId then
    ns.db.ui.selectedAuraId = ns.db.order[1]
  end
  self:MarkDirty()
end

local function GetContainerAndIndexForAura(aura)
  if not aura then
    return nil, 0
  end

  local container = ns.db.order
  if aura.parentId then
    local parent = ns.Registry:GetAura(aura.parentId)
    container = parent and parent.children or ns.db.order
  end

  if type(container) ~= "table" then
    return nil, 0
  end

  for index, candidateId in ipairs(container) do
    if candidateId == aura.id then
      return container, index
    end
  end

  return container, 0
end

function Registry:DuplicateAura(auraId, newParentId)
  local aura = self:GetAura(auraId)
  if not aura then
    return nil
  end

  local copy = Tables.DeepCopy(aura)
  copy.id = string.format("%s_copy_%d", aura.id, math.random(1000, 9999))
  copy.name = self:GetUniqueAuraName(aura.name .. " Copy")
  copy.parentId = newParentId or aura.parentId
  copy.children = {}
  self:AddAura(copy)

  if newParentId == nil or newParentId == aura.parentId then
    local _, sourceIndex = GetContainerAndIndexForAura(aura)
    if sourceIndex > 0 then
      self:MoveAura(copy.id, sourceIndex + 1, copy.parentId)
    end
  end

  for _, childId in ipairs(aura.children or {}) do
    self:DuplicateAura(childId, copy.id)
  end

  return copy
end

function Registry:MoveAura(auraId, newIndex, newParentId)
  local aura = self:GetAura(auraId)
  if not aura then
    return
  end

  local oldContainer = ns.db.order
  if aura.parentId then
    local oldParent = self:GetAura(aura.parentId)
    oldContainer = oldParent and oldParent.children or ns.db.order
  end
  Tables.RemoveValue(oldContainer, auraId)

  aura.parentId = newParentId
  local targetContainer = ns.db.order
  if newParentId then
    local parent = self:GetAura(newParentId)
    parent.children = parent.children or {}
    targetContainer = parent.children
  end

  newIndex = math.max(1, math.min(newIndex or (#targetContainer + 1), #targetContainer + 1))
  table.insert(targetContainer, newIndex, auraId)
  self:MarkDirty()
end

function Registry:IsDescendant(candidateParentId, childId)
  if not candidateParentId or not childId then
    return false
  end
  local cursor = self:GetAura(candidateParentId)
  while cursor do
    if cursor.id == childId then
      return true
    end
    cursor = cursor.parentId and self:GetAura(cursor.parentId) or nil
  end
  return false
end

local function ApplyGroupSizeToAuraTree(group, aura)
  if not group or not aura then
    return
  end

  local width = tonumber(group.display and group.display.width or group.position and group.position.width or 0) or 0
  local height = tonumber(group.display and group.display.height or group.position and group.position.height or 0) or 0
  if width <= 0 or height <= 0 then
    return
  end

  aura.display = aura.display or {}
  aura.position = aura.position or {}
  aura.display.width = width
  aura.display.height = height
  aura.position.width = width
  aura.position.height = height

  for _, childId in ipairs(aura.children or {}) do
    local childAura = ns.Registry:GetAura(childId)
    if childAura then
      ApplyGroupSizeToAuraTree(group, childAura)
    end
  end
end

function Registry:AssignToGroup(auraId, groupId)
  local aura = self:GetAura(auraId)
  local group = self:GetAura(groupId)
  if not aura or not group then
    return false
  end
  if aura.id == group.id then
    return false
  end
  if group.kind ~= "group" and group.kind ~= "dynamic_group" then
    return false
  end
  if self:IsDescendant(groupId, auraId) then
    return false
  end

  self:MoveAura(auraId, #(group.children or {}) + 1, groupId)
  if group.kind == "group" or group.kind == "dynamic_group" then
    ApplyGroupSizeToAuraTree(group, aura)
  end
  return true
end

function Registry:RemoveFromGroup(auraId)
  local aura = self:GetAura(auraId)
  if not aura or not aura.parentId then
    return false
  end

  self:MoveAura(auraId, #ns.db.order + 1, nil)
  return true
end

function Registry:ClearAll()
  ns.db.auras = {}
  ns.db.order = {}
  ns.db.ui.selectedAuraId = nil
  self:MarkDirty()
end

function Registry:GetFlatOrder()
  self:NormalizeTree()
  if self.flatOrderCache then
    return self.flatOrderCache
  end

  local results = {}
  local indexes = {}
  local visited = {}

  local function appendAura(auraId)
    if visited[auraId] then
      return
    end

    local aura = self:GetAura(auraId)
    if not aura then
      return
    end

    visited[auraId] = true
    results[#results + 1] = auraId
    indexes[auraId] = #results

    for _, childId in ipairs(aura.children or {}) do
      appendAura(childId)
    end
  end

  for _, auraId in ipairs(ns.db.order or {}) do
    appendAura(auraId)
  end

  self.flatOrderCache = results
  self.flatOrderIndexCache = indexes
  return results
end

function Registry:GetFlatOrderIndexes()
  self:GetFlatOrder()
  return self.flatOrderIndexCache or {}
end

function Registry:CollectAuraIds(predicate)
  local results = {}
  for _, auraId in ipairs(self:GetFlatOrder()) do
    local aura = self:GetAura(auraId)
    if aura and (not predicate or predicate(aura, auraId)) then
      results[#results + 1] = auraId
    end
  end
  return results
end

function Registry:GetTreeNodes(collapsedGroups)
  self:NormalizeTree()

  local nodes = {}
  local visited = {}
  local collapsed = collapsedGroups or {}

  local function appendNode(auraId, depth)
    if visited[auraId] then
      return
    end
    local aura = self:GetAura(auraId)
    if not aura then
      return
    end
    visited[auraId] = true
    nodes[#nodes + 1] = {
      auraId = auraId,
      aura = aura,
      depth = depth or 0,
      parentId = aura.parentId,
      isRoot = aura.parentId == nil,
    }
    if collapsed[auraId] then
      return
    end
    for _, childId in ipairs(aura.children or {}) do
      appendNode(childId, (depth or 0) + 1)
    end
  end

  for _, auraId in ipairs(ns.db.order) do
    appendNode(auraId, 0)
  end

  return nodes
end

function Registry:IterateAll()
  local auraIds = self:GetFlatOrder()
  local index = 0
  return function()
    index = index + 1
    local auraId = auraIds[index]
    if auraId then
      return auraId, self:GetAura(auraId)
    end
  end
end

function Registry.IterateGroups()
  local results = {}
  for _, aura in pairs(Registry:GetAuras() or {}) do
    if aura.kind == "group" or aura.kind == "dynamic_group" then
      results[#results + 1] = aura
    end
  end
  return ipairs(results)
end
