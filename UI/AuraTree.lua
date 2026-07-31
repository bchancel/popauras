local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts
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

local function ShowTooltip(owner, title, body)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(title)
  if body and body ~= "" then
    GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
  end
  GameTooltip:Show()
end

local function AddIconLine(icon, width, height, point, x, y, rotation)
  local line = icon:CreateTexture(nil, "OVERLAY")
  line:SetTexture("Interface\\Buttons\\WHITE8x8")
  line:SetSize(width, height)
  line:SetPoint(point or "CENTER", icon, point or "CENTER", x or 0, y or 0)
  if rotation and line.SetRotation then
    line:SetRotation(rotation)
  end
  icon.lines[#icon.lines + 1] = line
  return line
end

local function AddOutlineSquare(icon, x, y, size)
  AddIconLine(icon, size, 1, "TOPLEFT", x, y)
  AddIconLine(icon, size, 1, "TOPLEFT", x, y - size + 1)
  AddIconLine(icon, 1, size, "TOPLEFT", x, y)
  AddIconLine(icon, 1, size, "TOPLEFT", x + size - 1, y)
end

local function CreateActionIcon(button, kind)
  local icon = CreateFrame("Frame", nil, button)
  icon:SetSize(16, 16)
  icon:SetPoint("CENTER")
  icon.lines = {}
  icon.kind = kind

  if kind == "copy" then
    AddOutlineSquare(icon, 2, -2, 8)
    AddOutlineSquare(icon, 6, -6, 8)
  elseif kind == "trash" then
    AddIconLine(icon, 8, 1, "TOPLEFT", 4, -4)
    AddIconLine(icon, 4, 1, "TOPLEFT", 6, -2)
    AddIconLine(icon, 1, 8, "TOPLEFT", 5, -6)
    AddIconLine(icon, 1, 8, "TOPLEFT", 11, -6)
    AddIconLine(icon, 7, 1, "TOPLEFT", 5, -13)
    AddIconLine(icon, 1, 5, "TOPLEFT", 7, -7)
    AddIconLine(icon, 1, 5, "TOPLEFT", 9, -7)
  elseif kind == "up" or kind == "down" then
    local direction = kind == "up" and 1 or -1
    AddIconLine(icon, 1, 8, "CENTER", 0, -direction)
    AddIconLine(icon, 1, 6, "CENTER", -2, direction * 3, -math.rad(45) * direction)
    AddIconLine(icon, 1, 6, "CENTER", 2, direction * 3, math.rad(45) * direction)
  end

  button._popAurasActionIcon = icon
  return icon
end

local function SetActionIconColor(button, color)
  local icon = button and button._popAurasActionIcon
  if not icon then
    return
  end
  for _, line in ipairs(icon.lines or {}) do
    Theme.SetTexture(line, color)
  end
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
  Fonts.Apply(frame.searchLabel, 9, "OUTLINE")
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
  Fonts.Apply(frame.collapseButton:GetFontString(), 11, "")

  frame.dragProxy = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame.dragProxy:SetSize(150, 24)
  frame.dragProxy:SetFrameStrata("TOOLTIP")
  frame.dragProxy:SetFrameLevel(100)
  Theme.StyleSurface(frame.dragProxy, "surfaceHover", "borderFocus")
  frame.dragProxy.text = frame.dragProxy:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.dragProxy.text, 12, "OUTLINE")
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
    Fonts.Apply(header, 10, "")
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
    Theme.SetText(header, text:find("Not Loaded", 1, true) and "textMuted" or "textAccent")
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
    row:SetSize(272, 40)
    row:SetFrameStrata("FULLSCREEN_DIALOG")
    row:SetFrameLevel(self.frame:GetFrameLevel() + 40)
    row:EnableMouse(false)
    Theme.StyleSurface(row, "surface", "border")

    row.button = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.button:SetPoint("LEFT", 0, 0)
    row.button:SetSize(192, 38)
    row.button:SetFrameStrata("FULLSCREEN_DIALOG")
    row.button:SetFrameLevel(row:GetFrameLevel() + 1)
    row.button:EnableMouse(true)
    Theme.StyleSurface(row.button, "transparent", "transparent")
    row.button.text = row.button:CreateFontString(nil, "OVERLAY")
    Fonts.Apply(row.button.text, 12, "")
    row.button.text:SetPoint("TOPLEFT", 12, -5)
    row.button.text:SetPoint("TOPRIGHT", -8, -5)
    row.button.text:SetJustifyH("LEFT")
    row.button.text:SetJustifyV("TOP")
    Theme.SetText(row.button.text, "text")
    row.button.text:SetAlpha(1)
    row.button.text:SetShadowOffset(1, -1)
    row.button.text:SetShadowColor(0, 0, 0, 0.55)

    row.button.kindText = row.button:CreateFontString(nil, "OVERLAY")
    Fonts.Apply(row.button.kindText, 10, "")
    row.button.kindText:SetPoint("BOTTOMLEFT", 12, 5)
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
    row.groupIndicator:SetPoint("TOPLEFT", 5, -5)
    row.groupIndicator:SetPoint("BOTTOMLEFT", 5, 5)
    row.groupIndicator:SetWidth(3)
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
    Theme.SetText(row.topDottedLine, "textMuted")
    row.topDottedLine:Hide()

    row.bottomDottedLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.bottomDottedLine:SetPoint("BOTTOMLEFT", 6, 1)
    row.bottomDottedLine:SetPoint("BOTTOMRIGHT", -6, 1)
    row.bottomDottedLine:SetJustifyH("CENTER")
    row.bottomDottedLine:SetText(string.rep(". ", 40))
    Theme.SetText(row.bottomDottedLine, "textMuted")
    row.bottomDottedLine:Hide()

    row.button:SetScript("OnClick", function(selfButton)
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
        Theme.StyleSurface(row, "surfaceHover", "borderStrong")
      end
      if aura then
        ShowTooltip(selfButton, aura.name or "Aura", GetAuraKindLabel(aura) .. " — drag to reorder")
      end
    end)
    row.button:SetScript("OnLeave", function()
      GameTooltip:Hide()
      if row.auraId ~= ns.db.ui.selectedAuraId and not AuraTree.draggingAuraId then
        Theme.StyleSurface(row, "surface", "border")
      end
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
    Fonts.Apply(row.expandButton.text, 13, "")
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

    row.upButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.upButton:SetSize(20, 20)
    row.upButton:SetFrameStrata("FULLSCREEN_DIALOG")
    row.upButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.upButton:EnableMouse(true)
    row.upButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.upButton.text = row.upButton:CreateFontString(nil, "OVERLAY")
    row.upButton.Text = row.upButton.text
    Fonts.Apply(row.upButton.text, 10, "")
    row.upButton.text:SetPoint("CENTER")
    row.upButton.text:SetText("")
    CreateActionIcon(row.upButton, "up")
    SetActionIconColor(row.upButton, "textMuted")
    row.upButton:SetScript("OnClick", function(selfButton)
      local aura = ns.Registry:GetAura(selfButton.auraId)
      local _, currentIndex = GetSiblingInfo(aura)
      if aura and currentIndex > 1 then
        ns.Registry:MoveAura(aura.id, currentIndex - 1, aura.parentId)
        ns.runtime:RefreshAll()
        ns.ui.MainWindow:Refresh()
      end
    end)
    row.upButton:SetScript("OnEnter", function(selfButton)
      SetActionIconColor(selfButton, "text")
      ShowTooltip(selfButton, "Move Up", "Moves this aura earlier in its current list or group.")
    end)
    row.upButton:SetScript("OnLeave", function(selfButton)
      SetActionIconColor(selfButton, "textMuted")
      GameTooltip:Hide()
    end)

    row.downButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.downButton:SetSize(20, 20)
    row.downButton:SetFrameStrata("FULLSCREEN_DIALOG")
    row.downButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.downButton:EnableMouse(true)
    row.downButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.downButton.text = row.downButton:CreateFontString(nil, "OVERLAY")
    row.downButton.Text = row.downButton.text
    Fonts.Apply(row.downButton.text, 10, "")
    row.downButton.text:SetPoint("CENTER")
    row.downButton.text:SetText("")
    CreateActionIcon(row.downButton, "down")
    SetActionIconColor(row.downButton, "textMuted")
    row.downButton:SetScript("OnClick", function(selfButton)
      local aura = ns.Registry:GetAura(selfButton.auraId)
      local _, currentIndex, count = GetSiblingInfo(aura)
      if aura and currentIndex > 0 and currentIndex < count then
        ns.Registry:MoveAura(aura.id, currentIndex + 1, aura.parentId)
        ns.runtime:RefreshAll()
        ns.ui.MainWindow:Refresh()
      end
    end)
    row.downButton:SetScript("OnEnter", function(selfButton)
      SetActionIconColor(selfButton, "text")
      ShowTooltip(selfButton, "Move Down", "Moves this aura later in its current list or group.")
    end)
    row.downButton:SetScript("OnLeave", function(selfButton)
      SetActionIconColor(selfButton, "textMuted")
      GameTooltip:Hide()
    end)

    row.duplicateButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.duplicateButton:SetSize(20, 20)
    row.duplicateButton:SetFrameStrata("FULLSCREEN_DIALOG")
    row.duplicateButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.duplicateButton:EnableMouse(true)
    row.duplicateButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.duplicateButton.text = row.duplicateButton:CreateFontString(nil, "OVERLAY")
    row.duplicateButton.Text = row.duplicateButton.text
    Fonts.Apply(row.duplicateButton.text, 10, "")
    row.duplicateButton.text:SetPoint("CENTER")
    row.duplicateButton.text:SetText("")
    CreateActionIcon(row.duplicateButton, "copy")
    SetActionIconColor(row.duplicateButton, "textSecondary")
    row.duplicateButton:SetScript("OnClick", function(selfButton)
      local copy = ns.Registry:DuplicateAura(selfButton.auraId)
      if copy then
        ns.db.ui.editorMode = "config"
        ns.db.ui.selectedAuraId = copy.id
        ns.runtime:RefreshAll()
        ns.ui.MainWindow:Refresh()
      end
    end)
    row.duplicateButton:SetScript("OnEnter", function(selfButton)
      SetActionIconColor(selfButton, "text")
      ShowTooltip(selfButton, "Duplicate Aura", "Creates a copy of this aura or group.")
    end)
    row.duplicateButton:SetScript("OnLeave", function(selfButton)
      SetActionIconColor(selfButton, "textSecondary")
      GameTooltip:Hide()
    end)

    row.deleteButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.deleteButton:SetSize(20, 20)
    row.deleteButton:SetFrameStrata("FULLSCREEN_DIALOG")
    row.deleteButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.deleteButton:EnableMouse(true)
    row.deleteButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.deleteButton.text = row.deleteButton:CreateFontString(nil, "OVERLAY")
    row.deleteButton.Text = row.deleteButton.text
    Fonts.Apply(row.deleteButton.text, 10, "")
    row.deleteButton.text:SetPoint("CENTER")
    row.deleteButton.text:SetText("")
    CreateActionIcon(row.deleteButton, "trash")
    SetActionIconColor(row.deleteButton, "dangerBorder")
    row.deleteButton:SetScript("OnClick", function(selfButton)
      GameTooltip:Hide()
      local aura = ns.Registry:GetAura(selfButton.auraId)
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
          ns.runtime:RefreshAll()
          ns.ui.MainWindow:Refresh()
        end,
      })
    end)
    row.deleteButton:SetScript("OnEnter", function(selfButton)
      SetActionIconColor(selfButton, "text")
      ShowTooltip(selfButton, "Delete Aura", "Deletes this aura. Groups delete their child auras too.")
    end)
    row.deleteButton:SetScript("OnLeave", function(selfButton)
      SetActionIconColor(selfButton, "dangerBorder")
      GameTooltip:Hide()
    end)

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
    row.button.text:SetPoint("TOPLEFT", 12, -5)
    row.button.text:SetPoint("TOPRIGHT", -8, -5)
    row.button.auraId = aura.id
    row.auraId = aura.id
    row.depth = depth
    row:Show()
    row.button:Show()
    row.button.text:Show()
    if aura.id == ns.db.ui.selectedAuraId then
      Theme.StyleSurface(row, "surfaceHover", "borderFocus")
      row.button.selectionBar:Show()
    else
      local isGroupDropTarget = AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "group" and (aura.kind == "group" or aura.kind == "dynamic_group")
      local isReorderTarget = AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "reorder"
      Theme.StyleSurface(
        row,
        (isGroupDropTarget or isReorderTarget) and "accentSoft" or "surface",
        (isGroupDropTarget or isReorderTarget) and "borderFocus" or "border"
      )
      row.button.selectionBar:Hide()
    end
    Theme.StyleSurface(row.button, "transparent", "transparent")

    local contentAlpha = isLoaded and 1 or 0.52
    local buttonAlpha = isLoaded and 1 or 0.66
    local statusAlpha = isLoaded and 1 or 0.68
    local hasPreviewOutline = AuraHasPreviewEnabled(aura)
    local hasDebugOutline = AuraHasDebugEnabled(aura)
    row:SetAlpha(buttonAlpha)
    row.button:SetAlpha(1)
    row.button.text:SetAlpha(contentAlpha)
    row.button.kindText:SetAlpha(contentAlpha)
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

    local _, siblingIndex, siblingCount = GetSiblingInfo(aura)
    row.upButton.auraId = aura.id
    row.upButton:SetShown(aura.parentId ~= nil and siblingIndex > 1)
    row.upButton.text:SetShown(aura.parentId ~= nil and siblingIndex > 1)
    Theme.StyleButton(row.upButton, "ghost")

    row.downButton.auraId = aura.id
    row.downButton:SetShown(aura.parentId ~= nil and siblingIndex > 0 and siblingIndex < siblingCount)
    row.downButton.text:SetShown(aura.parentId ~= nil and siblingIndex > 0 and siblingIndex < siblingCount)
    Theme.StyleButton(row.downButton, "ghost")

    row.duplicateButton.auraId = aura.id
    row.duplicateButton:SetShown(true)
    Theme.StyleButton(row.duplicateButton, "ghost")

    row.deleteButton.auraId = aura.id
    row.deleteButton:SetShown(true)
    Theme.StyleButton(row.deleteButton, "ghostDanger")

    local actionCount = 2 + (isGroup and 1 or 0) + (row.upButton:IsShown() and 1 or 0) + (row.downButton:IsShown() and 1 or 0)
    local buttonWidth = rowWidth - 4 - (actionCount * 22)
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
      row.button.text:SetPoint("TOPLEFT", 12, -5)
      row.button.text:SetPoint("TOPRIGHT", -8, -5)
    else
      row.button.text:SetPoint("LEFT", 12, 0)
      row.button.text:SetPoint("RIGHT", -8, 0)
    end
    local anchor = row.button
    if row.expandButton:IsShown() then
      row.expandButton:ClearAllPoints()
      row.expandButton:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
      anchor = row.expandButton
    end
    if row.upButton:IsShown() then
      row.upButton:ClearAllPoints()
      row.upButton:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
      anchor = row.upButton
    end
    if row.downButton:IsShown() then
      row.downButton:ClearAllPoints()
      row.downButton:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
      anchor = row.downButton
    end
    row.duplicateButton:ClearAllPoints()
    row.duplicateButton:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
    row.deleteButton:ClearAllPoints()
    row.deleteButton:SetPoint("LEFT", row.duplicateButton, "RIGHT", 2, 0)

    row.expandButton:SetAlpha(contentAlpha)
    row.upButton:SetAlpha(contentAlpha)
    row.downButton:SetAlpha(contentAlpha)
    row.duplicateButton:SetAlpha(contentAlpha)
    row.deleteButton:SetAlpha(contentAlpha)
    yOffset = yOffset + 46

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
