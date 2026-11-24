local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

local AuraTree = {}
ns.ui.AuraTree = AuraTree

AuraTree.draggingAuraId = nil
AuraTree.dropTargetAuraId = nil
AuraTree.dropMode = nil
AuraTree.dropInsertAfter = false
AuraTree.draggingButton = nil
AuraTree.dragProxy = nil
AuraTree.dragStartX = nil
AuraTree.dragStartY = nil
AuraTree.dragMoved = false

local DEBUG_OUTLINE_COLOR = { 0.92, 0.24, 0.22, 0.98 }
local PREVIEW_OUTLINE_COLOR = { 0.24, 0.84, 0.38, 0.98 }

local TRIGGER_TYPE_LABELS = {
  simple = "basic state",
  aura = "aura",
  spell_cooldown = "spell cooldown",
  item_cooldown = "item cooldown",
  trinket_cooldown = "trinket cooldown",
  cast = "cast / channel",
  spell_cast_event = "spell cast event",
  chat = "chat",
  timer = "internal timer",
  death_alert = "death alert",
  aura_list = "buffs and debuffs",
}

local function ShowTooltip(owner, title, body)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(title)
  if body and body ~= "" then
    GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
  end
  GameTooltip:Show()
end

local function IsGroupAura(aura)
  return aura and (aura.kind == "group" or aura.kind == "dynamic_group")
end

local function GetSiblingInfo(aura)
  if not aura then
    return nil, 0, 0
  end

  local container
  if aura.parentId then
    local parent = ns.Registry:GetAura(aura.parentId)
    container = parent and parent.children or nil
  else
    container = ns.Registry:GetOrder()
  end

  if type(container) ~= "table" then
    return nil, 0, 0
  end

  for index, auraId in ipairs(container) do
    if auraId == aura.id then
      return container, index, #container
    end
  end

  return container, 0, #container
end

local QUESTION_MARK_ICON = 134400

-- Row icon from the aura's own configuration (icon override, else the first
-- configured trigger spell). Reads saved settings only, never live aura state;
-- the Spells helper drops any secret texture value.
local function GetAuraListIcon(aura)
  local Spells = ns.util.Spells
  if not aura or not Spells or not Spells.GetSpellTextureByOverride then
    return QUESTION_MARK_ICON
  end
  local display = aura.display or {}
  local texture = Spells:GetSpellTextureByOverride(display.iconOverrideId, display.iconOverrideName)
  if not texture and type(aura.triggers) == "table" then
    for _, trigger in ipairs(aura.triggers) do
      local spellId = type(trigger) == "table" and tonumber(trigger.spellId) or nil
      if spellId and spellId > 0 then
        texture = Spells:GetSpellTextureByOverride(spellId)
        break
      end
    end
  end
  return texture or QUESTION_MARK_ICON
end

local function IsAuraLoadedForList(aura)
  if not aura or not ns.LoadEvaluator or not ns.LoadEvaluator.Matches then
    return true
  end
  if ns.LoadEvaluator.MatchesWithAncestors then
    return ns.LoadEvaluator:MatchesWithAncestors(aura) == true
  end
  return ns.LoadEvaluator:Matches(aura) == true
end

local function AuraHasPreviewEnabled(aura)
  return aura and aura.display and aura.display.previewAnimate == true
end

local function AuraHasDebugEnabled(aura)
  if not aura or type(aura.triggers) ~= "table" then
    return false
  end

  for _, trigger in ipairs(aura.triggers) do
    if type(trigger) == "table" and trigger.debug == true then
      return true
    end
  end

  return false
end

local function NormalizeSearchQuery(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value:lower()
end

local function GetAuraKindLabel(aura)
  local kind = aura and tostring(aura.kind or "") or ""
  kind = kind:gsub("_", " ")

  if kind == "group" or kind == "dynamic group" then
    return kind
  end

  local trigger = aura and type(aura.triggers) == "table" and aura.triggers[1] or nil
  local triggerType = trigger and trigger.type or nil
  local triggerLabel = triggerType and TRIGGER_TYPE_LABELS[triggerType] or nil
  if triggerLabel then
    return string.format("%s - %s", kind, triggerLabel)
  end

  return kind
end

local function AuraMatchesQuery(aura, query)
  if not aura or not query or query == "" then
    return true
  end

  local name = tostring(aura.name or ""):lower()
  if name:find(query, 1, true) then
    return true
  end

  local kind = tostring(aura.kind or ""):lower()
  return kind:find(query, 1, true) ~= nil
end

local function CollectTreeNodesForRoot(auraId, collapsedGroups, depth, results)
  local aura = ns.Registry:GetAura(auraId)
  if not aura then
    return
  end

  results[#results + 1] = {
    aura = aura,
    depth = depth or 0,
    isLoaded = IsAuraLoadedForList(aura),
  }

  if collapsedGroups and collapsedGroups[auraId] then
    return
  end

  for _, childId in ipairs(aura.children or {}) do
    CollectTreeNodesForRoot(childId, collapsedGroups, (depth or 0) + 1, results)
  end
end

local function CompareAuraNames(leftId, rightId)
  local left = ns.Registry:GetAura(leftId)
  local right = ns.Registry:GetAura(rightId)
  local leftName = tostring(left and left.name or ""):lower()
  local rightName = tostring(right and right.name or ""):lower()
  if leftName ~= rightName then
    return leftName < rightName
  end
  return tostring(leftId or "") < tostring(rightId or "")
end

local function BuildSortedRootAuraIds()
  local buckets = {
    loadedGroups = {},
    loadedStandalone = {},
    unloadedGroups = {},
    unloadedStandalone = {},
  }

  for _, auraId in ipairs(ns.Registry:GetOrder()) do
    local aura = ns.Registry:GetAura(auraId)
    if aura then
      local loadedPrefix = IsAuraLoadedForList(aura) and "loaded" or "unloaded"
      local kindSuffix = IsGroupAura(aura) and "Groups" or "Standalone"
      local bucket = buckets[loadedPrefix .. kindSuffix]
      bucket[#bucket + 1] = auraId
    end
  end

  for _, bucket in pairs(buckets) do
    table.sort(bucket, CompareAuraNames)
  end

  local loaded = {}
  local unloaded = {}
  for _, auraId in ipairs(buckets.loadedGroups) do loaded[#loaded + 1] = auraId end
  for _, auraId in ipairs(buckets.loadedStandalone) do loaded[#loaded + 1] = auraId end
  for _, auraId in ipairs(buckets.unloadedGroups) do unloaded[#unloaded + 1] = auraId end
  for _, auraId in ipairs(buckets.unloadedStandalone) do unloaded[#unloaded + 1] = auraId end
  return loaded, unloaded
end

local function BuildOrderedTreeNodes(collapsedGroups)
  local loadedRoots = {}
  local unloadedRoots = {}
  local loadedRootIds, unloadedRootIds = BuildSortedRootAuraIds()

  for _, auraId in ipairs(loadedRootIds) do
    CollectTreeNodesForRoot(auraId, collapsedGroups, 0, loadedRoots)
  end
  for _, auraId in ipairs(unloadedRootIds) do
    CollectTreeNodesForRoot(auraId, collapsedGroups, 0, unloadedRoots)
  end

  return loadedRoots, unloadedRoots
end

local function CollectFilteredTreeNodesForRoot(auraId, query, depth, results)
  local aura = ns.Registry:GetAura(auraId)
  if not aura then
    return false
  end

  local matchedSelf = AuraMatchesQuery(aura, query)
  local childNodes = {}
  local matchedChild = false

  for _, childId in ipairs(aura.children or {}) do
    if CollectFilteredTreeNodesForRoot(childId, query, (depth or 0) + 1, childNodes) then
      matchedChild = true
    end
  end

  if not matchedSelf and not matchedChild then
    return false
  end

  results[#results + 1] = {
    aura = aura,
    depth = depth or 0,
    isLoaded = IsAuraLoadedForList(aura),
    searchMatched = matchedSelf,
    searchAncestor = matchedChild and not matchedSelf,
  }

  for _, node in ipairs(childNodes) do
    results[#results + 1] = node
  end

  return true
end

local function BuildFilteredTreeNodes(query)
  local loadedRoots = {}
  local unloadedRoots = {}
  local loadedRootIds, unloadedRootIds = BuildSortedRootAuraIds()

  for _, auraId in ipairs(loadedRootIds) do
    CollectFilteredTreeNodesForRoot(auraId, query, 0, loadedRoots)
  end
  for _, auraId in ipairs(unloadedRootIds) do
    CollectFilteredTreeNodesForRoot(auraId, query, 0, unloadedRoots)
  end

  return loadedRoots, unloadedRoots
end

function AuraTree:CompleteDrop(targetAuraId)
  local draggedAuraId = self.draggingAuraId
  if self.draggingButton then
    self.draggingButton:SetAlpha(1)
  end
  if self.dragProxy then
    self.dragProxy:Hide()
  end
  self.draggingAuraId = nil
  self.dropTargetAuraId = nil
  self.dropMode = nil
  self.dropInsertAfter = false
  self.draggingButton = nil
  if not draggedAuraId or not targetAuraId or draggedAuraId == targetAuraId then
    self:Refresh()
    return
  end
  if ns.Registry:AssignToGroup(draggedAuraId, targetAuraId) then
    ns.db.ui.selectedAuraId = draggedAuraId
    ns.runtime:RefreshAll()
    ns.ui.MainWindow:Refresh()
    return
  end
  self:Refresh()
end

function AuraTree:CompleteDropToRoot()
  local draggedAuraId = self.draggingAuraId
  if self.draggingButton then
    self.draggingButton:SetAlpha(1)
  end
  if self.dragProxy then
    self.dragProxy:Hide()
  end
  self.draggingAuraId = nil
  self.dropTargetAuraId = nil
  self.dropMode = nil
  self.dropInsertAfter = false
  self.draggingButton = nil
  if not draggedAuraId then
    self:Refresh()
    return
  end
  if ns.Registry:RemoveFromGroup(draggedAuraId) then
    ns.db.ui.selectedAuraId = draggedAuraId
    ns.runtime:RefreshAll()
    ns.ui.MainWindow:Refresh()
    return
  end
  self:Refresh()
end

function AuraTree:BeginDrag(auraId, button)
  local startX, startY = self:GetCursorPositionScaled()
  self.draggingAuraId = auraId
  self.dropTargetAuraId = nil
  self.dropMode = nil
  self.dropInsertAfter = false
  self.draggingButton = button
  self.dragStartX = startX
  self.dragStartY = startY
  self.dragMoved = false
  if button then
    button:SetAlpha(0.6)
  end
  if self.dragProxy then
    local aura = ns.Registry:GetAura(auraId)
    self.dragProxy.text:SetText(aura and aura.name or "Dragging")
    self.dragProxy:Hide()
  end
  if self.frame then
    self.frame:SetScript("OnUpdate", function()
      AuraTree:UpdateDragSession()
    end)
  end
end

function AuraTree:CancelDrag()
  if self.frame then
    self.frame:SetScript("OnUpdate", nil)
  end
  if self.draggingButton then
    self.draggingButton:SetAlpha(1)
  end
  if self.dragProxy then
    self.dragProxy:Hide()
  end
  self.draggingAuraId = nil
  self.draggingButton = nil
  self.dropTargetAuraId = nil
  self.dropMode = nil
  self.dropInsertAfter = false
  self.dragStartX = nil
  self.dragStartY = nil
  self.dragMoved = false
  self:Refresh()
end

function AuraTree:CompleteReorder(targetAuraId, insertAfter)
  local draggedAuraId = self.draggingAuraId
  if self.draggingButton then
    self.draggingButton:SetAlpha(1)
  end
  if self.dragProxy then
    self.dragProxy:Hide()
  end
  self.draggingAuraId = nil
  self.dropTargetAuraId = nil
  self.dropMode = nil
  self.dropInsertAfter = false
  self.draggingButton = nil
  if not draggedAuraId or not targetAuraId or draggedAuraId == targetAuraId then
    self:Refresh()
    return
  end

  local draggedAura = ns.Registry:GetAura(draggedAuraId)
  local targetAura = ns.Registry:GetAura(targetAuraId)
  if not draggedAura or not targetAura then
    self:Refresh()
    return
  end

  local newParentId = targetAura.parentId
  if not newParentId then
    self:Refresh()
    return
  end
  if newParentId and ns.Registry:IsDescendant(newParentId, draggedAuraId) then
    self:Refresh()
    return
  end

  local _, targetIndex = GetSiblingInfo(targetAura)
  local _, currentIndex = GetSiblingInfo(draggedAura)
  if targetIndex <= 0 then
    self:Refresh()
    return
  end

  local newIndex = targetIndex + (insertAfter and 1 or 0)
  if draggedAura.parentId == newParentId and currentIndex > 0 and currentIndex < newIndex then
    newIndex = newIndex - 1
  end

  ns.Registry:MoveAura(draggedAuraId, newIndex, newParentId)
  ns.db.ui.selectedAuraId = draggedAuraId
  ns.runtime:RefreshAll()
  ns.ui.MainWindow:Refresh()
end

function AuraTree:FinishDrag()
  if not self.dragMoved then
    self:CancelDrag()
    return
  end

  local row = self:GetHoveredRowAtCursor()
  local hoveredAuraId = row and row.button and row.button.auraId or self.dropTargetAuraId
  local hoveredAura = hoveredAuraId and ns.Registry:GetAura(hoveredAuraId) or nil
  if self.dropMode == "group" and hoveredAuraId and hoveredAura and hoveredAuraId ~= self.draggingAuraId and IsGroupAura(hoveredAura) then
    self:CompleteDrop(hoveredAuraId)
    return
  end
  if self.dropMode == "reorder" and hoveredAuraId and hoveredAura and hoveredAuraId ~= self.draggingAuraId then
    self:CompleteReorder(hoveredAuraId, self.dropInsertAfter)
    return
  end

  local draggedAura = ns.Registry:GetAura(self.draggingAuraId)
  if draggedAura and draggedAura.parentId and self:IsCursorInsideContent() then
    self:CompleteDropToRoot()
    return
  end

  self:CancelDrag()
end

function AuraTree:GetAuraIdFromFocus(focus)
  local cursor = focus
  while cursor do
    if cursor.auraId then
      return cursor.auraId
    end
    cursor = cursor.GetParent and cursor:GetParent() or nil
  end
  return nil
end

function AuraTree:IsFocusInsideTree(focus)
  local cursor = focus
  while cursor do
    if cursor == self.frame or cursor == self.frame.content or cursor == self.frame.scroll then
      return true
    end
    cursor = cursor.GetParent and cursor:GetParent() or nil
  end
  return false
end

function AuraTree:GetCursorPositionScaled()
  local scale = UIParent and UIParent:GetEffectiveScale() or 1
  local cursorX, cursorY = GetCursorPosition()
  return cursorX / scale, cursorY / scale
end

function AuraTree:GetHoveredRowAtCursor()
  if not self.frame or not self.frame.rows then
    return nil
  end
  local cursorX, cursorY = self:GetCursorPositionScaled()
  for _, row in ipairs(self.frame.rows) do
    if row:IsShown() then
      local left = row:GetLeft()
      local right = row:GetRight()
      local top = row:GetTop()
      local bottom = row:GetBottom()
      if left and right and top and bottom and cursorX >= left and cursorX <= right and cursorY <= top and cursorY >= bottom then
        return row
      end
    end
  end
  return nil
end

function AuraTree:IsCursorInsideContent()
  if not self.frame or not self.frame.content then
    return false
  end
  local cursorX, cursorY = self:GetCursorPositionScaled()
  local content = self.frame.content
  local left = content:GetLeft()
  local right = content:GetRight()
  local top = content:GetTop()
  local bottom = content:GetBottom()
  return left and right and top and bottom and cursorX >= left and cursorX <= right and cursorY <= top and cursorY >= bottom
end

function AuraTree:UpdateDragSession()
  if not self.draggingAuraId then
    if self.frame then
      self.frame:SetScript("OnUpdate", nil)
    end
    return
  end

  local row = self:GetHoveredRowAtCursor()
  local hoveredAuraId = row and row.button and row.button.auraId or nil
  local hoveredAura = hoveredAuraId and ns.Registry:GetAura(hoveredAuraId) or nil
  local newDropTarget = nil
  local newDropMode = nil
  local newDropInsertAfter = false
  local cursorX, cursorY = self:GetCursorPositionScaled()
  if not self.dragMoved and self.dragStartX and self.dragStartY then
    local deltaX = cursorX - self.dragStartX
    local deltaY = cursorY - self.dragStartY
    if (deltaX * deltaX) + (deltaY * deltaY) >= 64 then
      self.dragMoved = true
    end
  end

  if self.dragProxy and self.dragMoved then
    self.dragProxy:ClearAllPoints()
    self.dragProxy:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cursorX + 12, cursorY - 8)
    self.dragProxy:Show()
  end

  if self.dragMoved and hoveredAuraId and hoveredAuraId ~= self.draggingAuraId and row then
    local draggedAura = ns.Registry:GetAura(self.draggingAuraId)
    local _, rowCenterY = row:GetCenter()
    local rowHeight = row:GetHeight() or 28
    local zoneOffset = rowHeight * 0.22
    local targetParentId = hoveredAura and hoveredAura.parentId or nil
    local canReorder = hoveredAura and targetParentId and not ns.Registry:IsDescendant(targetParentId, self.draggingAuraId)

    if rowCenterY and hoveredAura and IsGroupAura(hoveredAura) and math.abs(cursorY - rowCenterY) <= zoneOffset and not ns.Registry:IsDescendant(hoveredAuraId, self.draggingAuraId) then
      newDropTarget = hoveredAuraId
      newDropMode = "group"
    elseif rowCenterY and canReorder and draggedAura then
      newDropTarget = hoveredAuraId
      newDropMode = "reorder"
      newDropInsertAfter = cursorY < rowCenterY
    end
  end

  if newDropTarget ~= self.dropTargetAuraId or newDropMode ~= self.dropMode or newDropInsertAfter ~= self.dropInsertAfter then
    self.dropTargetAuraId = newDropTarget
    self.dropMode = newDropMode
    self.dropInsertAfter = newDropInsertAfter
    self:Refresh()
  end

  if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
    return
  end

  if self.frame then
    self.frame:SetScript("OnUpdate", nil)
  end
  self:FinishDrag()
end

local function RefreshAfterTreeChange()
  ns.runtime:RefreshAll()
  ns.ui.MainWindow:Refresh()
end

function AuraTree:MoveAuraBy(auraId, delta)
  local aura = ns.Registry:GetAura(auraId)
  local _, currentIndex, count = GetSiblingInfo(aura)
  local target = currentIndex + (delta or 0)
  if not aura or not aura.parentId or currentIndex < 1 or target < 1 or target > count then
    return
  end
  ns.Registry:MoveAura(aura.id, target, aura.parentId)
  RefreshAfterTreeChange()
end

function AuraTree:DuplicateAura(auraId)
  local copy = ns.Registry:DuplicateAura(auraId)
  if copy then
    ns.db.ui.editorMode = "config"
    ns.db.ui.selectedAuraId = copy.id
    RefreshAfterTreeChange()
  end
end

function AuraTree:RemoveAuraFromGroup(auraId)
  local aura = ns.Registry:GetAura(auraId)
  if aura and aura.parentId and ns.Registry:RemoveFromGroup(aura.id) then
    RefreshAfterTreeChange()
  end
end

function AuraTree:AddAuraToGroup(auraId, groupId)
  local aura = ns.Registry:GetAura(auraId)
  if aura and not aura.parentId and ns.Registry:AssignToGroup(aura.id, groupId) then
    ns.db.ui.collapsedGroups[groupId] = nil
    RefreshAfterTreeChange()
  end
end

function AuraTree:ConfirmDeleteAura(auraId)
  GameTooltip:Hide()
  local aura = ns.Registry:GetAura(auraId)
  if not aura then
    return
  end

  local descendantCount = ns.Registry:CountDescendants(aura.id)
  local isGroup = IsGroupAura(aura)
  local message = string.format("Are you sure you want to delete \"%s\"?", tostring(aura.name or "Aura"))
  if descendantCount > 0 then
    local noun = descendantCount == 1 and "aura" or "auras"
    message = string.format(
      "%s\n\nThis group contains %d nested %s. Deleting the group will permanently delete %s as well.",
      message,
      descendantCount,
      noun,
      descendantCount == 1 and "it" or "them"
    )
  end

  Frames.ShowConfirmation({
    title = isGroup and "Delete Group" or "Delete Aura",
    message = message,
    acceptText = "Delete",
    cancelText = "Cancel",
    acceptStyle = "danger",
    cancelStyle = "secondary",
    onAccept = function()
      if not ns.Registry:GetAura(aura.id) then
        return
      end
      ns.db.ui.editorMode = "config"
      ns.Registry:DeleteAura(aura.id)
      RefreshAfterTreeChange()
    end,
  })
end

local function GetGroupMenuEntries(excludeAuraId)
  local groups = {}
  for _, aura in pairs(ns.Registry:GetAuras() or {}) do
    if IsGroupAura(aura) and aura.id ~= excludeAuraId then
      groups[#groups + 1] = aura
    end
  end
  table.sort(groups, function(left, right)
    local leftName = tostring(left.name or ""):lower()
    local rightName = tostring(right.name or ""):lower()
    if leftName ~= rightName then
      return leftName < rightName
    end
    return tostring(left.id or "") < tostring(right.id or "")
  end)
  return groups
end

-- Builds a flat, renderer-agnostic description of the row menu so the modern
-- Menu API and the UIDropDownMenu fallback show exactly the same actions.
local function BuildRowMenuItems(aura)
  local items = {}
  local _, index, count = GetSiblingInfo(aura)
  local inGroup = aura.parentId ~= nil
  local isGroup = IsGroupAura(aura)
  local auraId = aura.id

  if inGroup then
    items[#items + 1] = { text = "Move Up", enabled = index > 1,
      func = function() AuraTree:MoveAuraBy(auraId, -1) end }
    items[#items + 1] = { text = "Move Down", enabled = index > 0 and index < count,
      func = function() AuraTree:MoveAuraBy(auraId, 1) end }
    items[#items + 1] = { divider = true }
  end

  items[#items + 1] = { text = "Duplicate", enabled = true,
    func = function() AuraTree:DuplicateAura(auraId) end }

  if inGroup then
    items[#items + 1] = { text = "Remove from Group", enabled = true,
      func = function() AuraTree:RemoveAuraFromGroup(auraId) end }
  elseif not isGroup then
    local children = {}
    for _, group in ipairs(GetGroupMenuEntries(auraId)) do
      local groupId = group.id
      children[#children + 1] = { text = group.name or "Unnamed Group", enabled = true,
        func = function() AuraTree:AddAuraToGroup(auraId, groupId) end }
    end
    items[#items + 1] = { text = "Add to Group", enabled = #children > 0, children = children }
  end

  if isGroup then
    local collapsed = ns.db.ui.collapsedGroups and ns.db.ui.collapsedGroups[auraId]
    items[#items + 1] = { text = collapsed and "Expand Group" or "Collapse Group", enabled = true,
      func = function()
        ns.db.ui.collapsedGroups[auraId] = not ns.db.ui.collapsedGroups[auraId] or nil
        AuraTree:Refresh()
      end }
  end

  items[#items + 1] = { divider = true }
  items[#items + 1] = { text = isGroup and "Delete Group..." or "Delete...", enabled = true, danger = true,
    func = function() AuraTree:ConfirmDeleteAura(auraId) end }
  return items
end

local DANGER_TEXT_FORMAT = "|cffe0585e%s|r"

local function AddMenuItems(description, items)
  for _, item in ipairs(items) do
    if item.divider then
      description:CreateDivider()
    else
      local text = item.danger and string.format(DANGER_TEXT_FORMAT, item.text) or item.text
      local element = description:CreateButton(text, item.func)
      if item.children then
        AddMenuItems(element, item.children)
      end
      if item.enabled == false and element.SetEnabled then
        element:SetEnabled(false)
      end
    end
  end
end

local function ShowFallbackRowMenu(owner, title, items)
  local dropdown = AuraTree.fallbackMenu
  if not dropdown then
    dropdown = CreateFrame("Frame", "PopAurasAuraRowMenu", UIParent, "UIDropDownMenuTemplate")
    AuraTree.fallbackMenu = dropdown
  end
  UIDropDownMenu_Initialize(dropdown, function(_, level, menuList)
    local list = level == 1 and items or menuList
    if level == 1 then
      local header = UIDropDownMenu_CreateInfo()
      header.text = title
      header.isTitle = true
      header.notCheckable = true
      UIDropDownMenu_AddButton(header, level)
    end
    for _, item in ipairs(list or {}) do
      local info = UIDropDownMenu_CreateInfo()
      info.notCheckable = true
      if item.divider then
        info.text = ""
        info.disabled = true
        info.isTitle = true
      else
        info.text = item.danger and string.format(DANGER_TEXT_FORMAT, item.text) or item.text
        info.disabled = item.enabled == false
        if item.children then
          info.hasArrow = true
          info.menuList = item.children
        else
          info.func = function()
            CloseDropDownMenus()
            item.func()
          end
        end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end, "MENU")
  ToggleDropDownMenu(1, nil, dropdown, owner or "cursor", 0, 0)
end

function AuraTree:ShowRowMenu(auraId, owner)
  local aura = ns.Registry:GetAura(auraId)
  if not aura then
    return
  end
  GameTooltip:Hide()
  local title = aura.name or "Aura"
  local items = BuildRowMenuItems(aura)
  if MenuUtil and MenuUtil.CreateContextMenu then
    -- The menu frame belongs to Blizzard's Menu system (and may be reused for
    -- other context menus), so its strata is left untouched.
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
      rootDescription:CreateTitle(title)
      AddMenuItems(rootDescription, items)
    end)
  else
    ShowFallbackRowMenu(owner, title, items)
  end
end

-- Grip and the ... button only show on hover or for the selected row, so idle
-- rows stay quiet while the drag and action affordances stay discoverable.
local function UpdateRowChrome(row)
  if not row or not row.auraId then
    return
  end
  local selected = row.auraId == ns.db.ui.selectedAuraId
  local hovered = row:IsMouseOver() and not AuraTree.draggingAuraId
  local show = selected or hovered
  row.grip:SetShown(show)
  row.grip:SetAlpha(hovered and 1 or 0.6)
  row.moreButton:SetShown(show)
end
AuraTree.UpdateRowChrome = UpdateRowChrome

function AuraTree:Create(parent)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Theme.StyleSurface(frame, "transparent", "transparent")
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(parent:GetFrameLevel() + 30)
  frame:EnableMouse(true)

  frame.titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.titleBar:SetPoint("TOPLEFT", 1, -1)
  frame.titleBar:SetPoint("TOPRIGHT", -1, -1)
  frame.titleBar:SetHeight(42)
  Theme.StyleSurface(frame.titleBar, "transparent", "transparent")

  frame.searchLabel = Frames.CreateLabel(frame.titleBar, "FILTER", "GameFontNormalSmall")
  Theme.ApplyTypography(frame.searchLabel, "micro", "OUTLINE")
  frame.searchLabel:SetPoint("LEFT", 2, 0)
  Theme.SetText(frame.searchLabel, "textMuted")

  frame.searchInput = Frames.CreateInput(frame.titleBar, 184, 28)
  frame.searchInput:SetPoint("LEFT", frame.searchLabel, "RIGHT", 8, 0)
  frame.searchInput:SetPoint("RIGHT", -2, 0)
  frame.searchInput:SetTextInsets(6, 6, 0, 0)
  frame.searchInput:SetScript("OnTextChanged", function()
    AuraTree:Refresh()
  end)
  frame.searchInput:SetScript("OnEscapePressed", function(selfInput)
    selfInput:SetText("")
    selfInput:ClearFocus()
  end)

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 0, -50)
  frame.scroll:SetPoint("BOTTOMRIGHT", -24, 44)
  frame.scroll:EnableMouse(true)
  Theme.StyleScrollFrame(frame.scroll)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(1, 1)
  frame.scroll:SetScrollChild(frame.content)
  frame.content:EnableMouse(true)
  frame.content:SetScript("OnMouseUp", function(_, mouseButton)
    if mouseButton ~= "LeftButton" or not AuraTree.draggingAuraId then
      return
    end
    local draggedAura = ns.Registry:GetAura(AuraTree.draggingAuraId)
    if draggedAura and draggedAura.parentId then
      AuraTree:CompleteDropToRoot()
    else
      AuraTree:CancelDrag()
    end
  end)
  frame.rows = {}
  frame.sectionHeaders = {}
  frame.emptyText = Frames.CreateLabel(frame.content, "", "GameFontHighlightSmall")
  Theme.SetText(frame.emptyText, "textMuted")
  frame.emptyText:SetWidth(220)
  frame.emptyText:SetJustifyH("LEFT")
  frame.emptyText:Hide()

  frame.collapseButton = Frames.CreateButton(frame, "Collapse Groups", 120, 28, function()
    ns.db.ui.collapsedGroups = ns.db.ui.collapsedGroups or {}
    for auraId, aura in pairs(ns.Registry:GetAuras() or {}) do
      if IsGroupAura(aura) then
        ns.db.ui.collapsedGroups[auraId] = true
      end
    end
    AuraTree:Refresh()
  end)
  frame.collapseButton:SetPoint("BOTTOMLEFT", 0, 6)
  frame.collapseButton:SetPoint("BOTTOMRIGHT", -2, 6)
  Theme.StyleButton(frame.collapseButton, "ghost")
  Theme.ApplyTypography(frame.collapseButton:GetFontString(), "controlSmall")

  frame.dragProxy = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame.dragProxy:SetSize(150, 24)
  frame.dragProxy:SetFrameStrata("TOOLTIP")
  frame.dragProxy:SetFrameLevel(100)
  Theme.StyleSurface(frame.dragProxy, "surfaceHover", "borderFocus")
  frame.dragProxy.text = frame.dragProxy:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.dragProxy.text, "control", "OUTLINE")
  frame.dragProxy.text:SetPoint("CENTER")
  Theme.SetText(frame.dragProxy.text, "text")
  frame.dragProxy:Hide()
  self.dragProxy = frame.dragProxy

  self.frame = frame
  return frame
end

function AuraTree:Refresh()
  if not self.frame then
    return
  end

  ns.db.ui.collapsedGroups = ns.db.ui.collapsedGroups or {}

  local content = self.frame.content
  for _, row in ipairs(self.frame.rows) do
    row:Hide()
  end
  for _, header in ipairs(self.frame.sectionHeaders or {}) do
    header:Hide()
    if header.line then
      header.line:Hide()
    end
  end
  if self.frame.emptyText then
    self.frame.emptyText:Hide()
  end

  local index = 0
  local yOffset = 0
  local sectionHeaderIndex = 0
  local searchQuery = NormalizeSearchQuery(self.frame.searchInput and self.frame.searchInput:GetText() or "")

  local function EnsureSectionHeader(i)
    if self.frame.sectionHeaders[i] then
      return self.frame.sectionHeaders[i]
    end

    local header = Frames.CreateLabel(content, "", "GameFontNormal")
    Theme.ApplyTypography(header, "caption")
    Theme.SetText(header, "textAccent")
    header.line = Theme.CreateAccentLine(content, 1, "border")
    self.frame.sectionHeaders[i] = header
    return header
  end

  local function RenderSectionHeader(text)
    sectionHeaderIndex = sectionHeaderIndex + 1
    local header = EnsureSectionHeader(sectionHeaderIndex)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", 0, -yOffset)
    header:SetText(text:upper())
    Theme.SetText(header, text:find("Not Loaded", 1, true) and "textMuted" or "navigation")
    header:Show()
    header.line:ClearAllPoints()
    header.line:SetPoint("LEFT", header, "RIGHT", 10, 0)
    header.line:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    header.line:Show()
    yOffset = yOffset + 26
  end

  local function EnsureRow(i)
    if self.frame.rows[i] then
      return self.frame.rows[i]
    end
    local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
    row:SetSize(272, Theme.layout.auraRowHeight)
    row:SetFrameStrata("FULLSCREEN_DIALOG")
    row:SetFrameLevel(self.frame:GetFrameLevel() + 40)
    row:EnableMouse(false)
    Theme.StyleSurface(row, "transparent", "transparent")

    -- Spell icon (or a group glyph) gives each row an at-a-glance identity.
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 24, 0)

    row.button = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.button:SetPoint("LEFT", 0, 0)
    row.button:SetSize(192, 38)
    row.button:SetFrameStrata("FULLSCREEN_DIALOG")
    row.button:SetFrameLevel(row:GetFrameLevel() + 1)
    row.button:EnableMouse(true)
    Theme.StyleSurface(row.button, "transparent", "transparent")
    row.button.text = row.button:CreateFontString(nil, "OVERLAY")
    Theme.ApplyTypography(row.button.text, "control")
    row.button.text:SetPoint("TOPLEFT", 56, -5)
    row.button.text:SetPoint("TOPRIGHT", -8, -5)
    row.button.text:SetJustifyH("LEFT")
    row.button.text:SetJustifyV("TOP")
    Theme.SetText(row.button.text, "text")
    row.button.text:SetAlpha(1)
    row.button.text:SetShadowOffset(1, -1)
    row.button.text:SetShadowColor(0, 0, 0, 0.55)

    row.button.kindText = row.button:CreateFontString(nil, "OVERLAY")
    Theme.ApplyTypography(row.button.kindText, "caption")
    row.button.kindText:SetPoint("BOTTOMLEFT", 56, 5)
    row.button.kindText:SetPoint("BOTTOMRIGHT", -8, 5)
    row.button.kindText:SetJustifyH("LEFT")
    Theme.SetText(row.button.kindText, "textMuted")

    row.button.selectionBar = Theme.CreateAccentLine(row, 1, "accentBright")
    row.button.selectionBar:ClearAllPoints()
    row.button.selectionBar:SetPoint("TOPLEFT", 0, -1)
    row.button.selectionBar:SetPoint("BOTTOMLEFT", 0, 1)
    row.button.selectionBar:SetWidth(3)
    row.button.selectionBar:Hide()

    row.groupIndicator = Theme.CreateAccentLine(row, 1, "groupAccent")
    row.groupIndicator:ClearAllPoints()
    row.groupIndicator:SetPoint("TOPLEFT", 1, -8)
    row.groupIndicator:SetPoint("BOTTOMLEFT", 1, 8)
    row.groupIndicator:SetWidth(2)
    row.groupIndicator:Hide()

    row.previewOutline = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.previewOutline:SetPoint("TOPLEFT", -1, 1)
    row.previewOutline:SetPoint("BOTTOMRIGHT", 1, -1)
    row.previewOutline:SetFrameStrata("FULLSCREEN_DIALOG")
    row.previewOutline:SetFrameLevel(row:GetFrameLevel() + 3)
    row.previewOutline:EnableMouse(false)
    row.previewOutline:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.previewOutline:SetBackdropBorderColor(unpack(PREVIEW_OUTLINE_COLOR))
    row.previewOutline:Hide()

    row.debugOutline = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.debugOutline:SetPoint("TOPLEFT", -3, 3)
    row.debugOutline:SetPoint("BOTTOMRIGHT", 3, -3)
    row.debugOutline:SetFrameStrata("FULLSCREEN_DIALOG")
    row.debugOutline:SetFrameLevel(row:GetFrameLevel() + 4)
    row.debugOutline:EnableMouse(false)
    row.debugOutline:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.debugOutline:SetBackdropBorderColor(unpack(DEBUG_OUTLINE_COLOR))
    row.debugOutline:Hide()

    row.topDottedLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.topDottedLine:SetPoint("TOPLEFT", 6, -1)
    row.topDottedLine:SetPoint("TOPRIGHT", -6, -1)
    row.topDottedLine:SetJustifyH("CENTER")
    row.topDottedLine:SetText(string.rep(". ", 40))
    Theme.SetText(row.topDottedLine, "border")
    row.topDottedLine:Hide()

    row.bottomDottedLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.bottomDottedLine:SetPoint("BOTTOMLEFT", 6, 1)
    row.bottomDottedLine:SetPoint("BOTTOMRIGHT", -6, 1)
    row.bottomDottedLine:SetJustifyH("CENTER")
    row.bottomDottedLine:SetText(string.rep(". ", 40))
    Theme.SetText(row.bottomDottedLine, "border")
    row.bottomDottedLine:Hide()

    row.button:SetScript("OnClick", function(selfButton, mouseButton, down)
      if mouseButton == "RightButton" then
        if not down then
          ns.db.ui.editorMode = "config"
          ns.db.ui.selectedAuraId = selfButton.auraId
          ns.ui.MainWindow:RefreshSelection()
          AuraTree:ShowRowMenu(selfButton.auraId, selfButton)
        end
        return
      end
      ns.db.ui.editorMode = "config"
      ns.db.ui.selectedAuraId = selfButton.auraId
      ns.ui.MainWindow:RefreshSelection()
    end)
    row.button:RegisterForClicks("AnyUp", "AnyDown")
    row.button:SetScript("OnMouseDown", function(selfButton, mouseButton)
      if mouseButton == "LeftButton" then
        AuraTree:BeginDrag(selfButton.auraId, selfButton)
      end
    end)
    row.button:SetScript("OnMouseUp", function(_, mouseButton)
      if mouseButton == "LeftButton" and AuraTree.draggingAuraId then
        AuraTree:FinishDrag()
      end
    end)
    row.button:SetScript("OnEnter", function(selfButton)
      if AuraTree.draggingAuraId then
        AuraTree:UpdateDragSession()
        return
      end
      local aura = ns.Registry:GetAura(selfButton.auraId)
      if aura and aura.id ~= ns.db.ui.selectedAuraId then
        Theme.StyleSurface(row, "surfaceHover", "transparent")
      end
      UpdateRowChrome(row)
      if aura then
        ShowTooltip(selfButton, aura.name or "Aura",
          GetAuraKindLabel(aura) .. "\nDrag to reorder or move into a group. Right-click for actions.")
      end
    end)
    row.button:SetScript("OnLeave", function()
      GameTooltip:Hide()
      if row.auraId ~= ns.db.ui.selectedAuraId and not AuraTree.draggingAuraId then
        Theme.StyleSurface(row, "transparent", "transparent")
      end
      UpdateRowChrome(row)
      if AuraTree.draggingAuraId then
        AuraTree:UpdateDragSession()
      end
    end)
    row.expandButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.expandButton:SetSize(20, 20)
    row.expandButton:SetFrameStrata("FULLSCREEN_DIALOG")
    row.expandButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.expandButton:EnableMouse(true)
    row.expandButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.expandButton.text = row.expandButton:CreateFontString(nil, "OVERLAY")
    row.expandButton.Text = row.expandButton.text
    Theme.ApplyTypography(row.expandButton.text, "glyphSmall", "")
    row.expandButton.text:SetPoint("CENTER")
    row.expandButton:SetPoint("LEFT", row.button, "RIGHT", 2, 0)
    row.expandButton:SetScript("OnClick", function(selfButton)
      local auraId = selfButton.auraId
      ns.db.ui.collapsedGroups[auraId] = not ns.db.ui.collapsedGroups[auraId]
      AuraTree:Refresh()
    end)
    row.expandButton:SetScript("OnEnter", function(selfButton)
      if AuraTree.draggingAuraId then
        AuraTree:UpdateDragSession()
      end
      ShowTooltip(selfButton, "Collapse Group", "Show or hide this group's children in the aura list.")
    end)
    row.expandButton:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    row.grip = row:CreateTexture(nil, "OVERLAY")
    row.grip:SetTexture(Frames.UI_ICON_PATH .. "UiGrip")
    row.grip:SetSize(14, 14)
    row.grip:SetPoint("LEFT", 6, 0)
    Theme.SetTexture(row.grip, "textMuted")
    row.grip:Hide()

    row.moreButton = Frames.CreateIconButton(row, "UiMore", 24, 14, "Actions",
      "Move, duplicate, group or delete. You can also right-click the row.", true)
    row.moreButton:SetFrameStrata("FULLSCREEN_DIALOG")
    row.moreButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.moreButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.moreButton:SetScript("OnClick", function(selfButton)
      AuraTree:ShowRowMenu(selfButton.auraId, selfButton)
    end)
    row.moreButton:HookScript("OnEnter", function()
      UpdateRowChrome(row)
    end)
    row.moreButton:HookScript("OnLeave", function()
      UpdateRowChrome(row)
    end)
    row.moreButton:Hide()

    self.frame.rows[i] = row
    return row
  end

  local function RenderNode(node)
    local aura = node.aura
    local depth = node.depth or 0
    local isLoaded = node.isLoaded ~= false
    index = index + 1
    local row = EnsureRow(index)
    local indent = math.min(depth, 3) * 14
    local rowWidth = 272 - indent
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", indent, -yOffset)
    row:SetWidth(rowWidth)
    local label = aura.name
    local kindLabel = GetAuraKindLabel(aura)
    local isDropPrompt = false
    if AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "group" and (aura.kind == "group" or aura.kind == "dynamic_group") then
      label = "> Drop into " .. aura.name
      isDropPrompt = true
    elseif AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "reorder" then
      label = (AuraTree.dropInsertAfter and "v " or "^ ") .. label
      isDropPrompt = true
    end
    row.button.text:SetText(label)
    row.button.kindText:SetText(kindLabel)
    row.button.text:ClearAllPoints()
    row.button.text:SetPoint("TOPLEFT", 56, -5)
    row.button.text:SetPoint("TOPRIGHT", -8, -5)
    row.button.auraId = aura.id
    row.auraId = aura.id
    row.depth = depth
    row:Show()
    row.button:Show()
    row.button.text:Show()
    if aura.id == ns.db.ui.selectedAuraId then
      Theme.StyleSurface(row, "accentSoft", "transparent")
      row.button.selectionBar:Show()
    else
      local isGroupDropTarget = AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "group" and (aura.kind == "group" or aura.kind == "dynamic_group")
      local isReorderTarget = AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "reorder"
      Theme.StyleSurface(
        row,
        (isGroupDropTarget or isReorderTarget) and "accentSoft" or "transparent",
        (isGroupDropTarget or isReorderTarget) and "borderFocus" or "transparent"
      )
      row.button.selectionBar:Hide()
    end
    Theme.StyleSurface(row.button, "transparent", "transparent")

    if IsGroupAura(aura) then
      row.icon:SetTexture(Frames.UI_ICON_PATH .. "UiGroup")
      row.icon:SetTexCoord(0, 1, 0, 1)
      Theme.SetTexture(row.icon, "groupAccent")
    else
      row.icon:SetTexture(GetAuraListIcon(aura))
      row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      row.icon:SetVertexColor(1, 1, 1, 1)
    end

    local contentAlpha = isLoaded and 1 or 0.52
    local buttonAlpha = isLoaded and 1 or 0.66
    local statusAlpha = isLoaded and 1 or 0.68
    local hasPreviewOutline = AuraHasPreviewEnabled(aura)
    local hasDebugOutline = AuraHasDebugEnabled(aura)
    row:SetAlpha(buttonAlpha)
    row.button:SetAlpha(1)
    row.button.text:SetAlpha(contentAlpha)
    row.button.kindText:SetAlpha(contentAlpha)
    row.icon:SetAlpha(contentAlpha)
    row.icon:SetDesaturated(not isLoaded)
    row.topDottedLine:SetShown(not isLoaded)
    row.bottomDottedLine:SetShown(not isLoaded)
    row.topDottedLine:SetAlpha(contentAlpha)
    row.bottomDottedLine:SetAlpha(contentAlpha)
    row.previewOutline:SetShown(hasPreviewOutline)
    row.previewOutline:SetAlpha(statusAlpha)
    row.debugOutline:SetShown(hasDebugOutline)
    row.debugOutline:SetAlpha(statusAlpha)

    local isGroup = aura.kind == "group" or aura.kind == "dynamic_group"
    row.groupIndicator:SetShown(isGroup)
    row.groupIndicator:SetAlpha(contentAlpha)
    row.expandButton.auraId = aura.id
    row.expandButton:SetShown(isGroup and searchQuery == "")
    if isGroup then
      row.expandButton.text:SetText(ns.db.ui.collapsedGroups[aura.id] and "+" or "-")
      row.expandButton.text:Show()
      Theme.StyleButton(row.expandButton, "ghost")
    end

    row.moreButton.auraId = aura.id
    row.moreButton:SetAlpha(1)

    local reservedWidth = 28 + (row.expandButton:IsShown() and 22 or 0)
    local buttonWidth = rowWidth - 4 - reservedWidth
    row.button:SetWidth(math.max(112, buttonWidth))
    row.button:ClearAllPoints()
    row.button:SetPoint("LEFT", 0, 0)
    local showKind = buttonWidth >= 126 and not isDropPrompt
    row.button.kindText:SetShown(showKind)
    if not showKind and not isDropPrompt then
      row.button.text:SetText(aura.name .. " [" .. kindLabel .. "]")
    end
    row.button.text:ClearAllPoints()
    if showKind then
      row.button.text:SetPoint("TOPLEFT", 56, -5)
      row.button.text:SetPoint("TOPRIGHT", -8, -5)
    else
      row.button.text:SetPoint("LEFT", 56, 0)
      row.button.text:SetPoint("RIGHT", -8, 0)
    end
    if row.expandButton:IsShown() then
      row.expandButton:ClearAllPoints()
      row.expandButton:SetPoint("RIGHT", row.moreButton, "LEFT", -2, 0)
    end
    row.expandButton:SetAlpha(contentAlpha)
    UpdateRowChrome(row)
    yOffset = yOffset + Theme.layout.auraRowStep

  end

  local loadedNodes, unloadedNodes
  if searchQuery ~= "" then
    loadedNodes, unloadedNodes = BuildFilteredTreeNodes(searchQuery)
  else
    loadedNodes, unloadedNodes = BuildOrderedTreeNodes(ns.db.ui.collapsedGroups)
  end

  RenderSectionHeader(searchQuery ~= "" and "Matching Auras" or "Loaded Auras")
  for _, node in ipairs(loadedNodes) do
    RenderNode(node)
  end
  if #unloadedNodes > 0 then
    yOffset = yOffset + (#loadedNodes > 0 and 10 or 0)
    RenderSectionHeader(searchQuery ~= "" and "Matching But Not Loaded" or "Not Loaded")
    for _, node in ipairs(unloadedNodes) do
      RenderNode(node)
    end
  end

  if #loadedNodes == 0 and #unloadedNodes == 0 and self.frame.emptyText then
    self.frame.emptyText:ClearAllPoints()
    self.frame.emptyText:SetPoint("TOPLEFT", 0, -yOffset)
    self.frame.emptyText:SetText(searchQuery ~= "" and "No auras match that search." or "No auras created yet.")
    self.frame.emptyText:Show()
    yOffset = yOffset + 22
  end

  content:SetSize(272, math.max(1, yOffset))
  content:SetFrameStrata("FULLSCREEN_DIALOG")
  content:SetFrameLevel(self.frame:GetFrameLevel() + 35)
end
