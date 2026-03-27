local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts

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

local function IsAuraLoadedForList(aura)
  if not aura or not ns.LoadEvaluator or not ns.LoadEvaluator.Matches then
    return true
  end
  return ns.LoadEvaluator:Matches(aura) == true
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

local function BuildOrderedTreeNodes(collapsedGroups)
  local loadedRoots = {}
  local unloadedRoots = {}

  for _, auraId in ipairs(ns.Registry:GetOrder()) do
    local aura = ns.Registry:GetAura(auraId)
    if aura then
      local bucket = IsAuraLoadedForList(aura) and loadedRoots or unloadedRoots
      CollectTreeNodesForRoot(auraId, collapsedGroups, 0, bucket)
    end
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
    local canReorder = hoveredAura and (not targetParentId or not ns.Registry:IsDescendant(targetParentId, self.draggingAuraId))

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
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.09, 0.11, 0.16, 0.97)
  frame:SetBackdropBorderColor(0.20, 0.26, 0.34, 1)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(parent:GetFrameLevel() + 30)
  frame:EnableMouse(true)

  frame.titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.titleBar:SetPoint("TOPLEFT", 1, -1)
  frame.titleBar:SetPoint("TOPRIGHT", -1, -1)
  frame.titleBar:SetHeight(32)
  frame.titleBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.titleBar:SetBackdropColor(0.13, 0.16, 0.22, 1)
  frame.titleBar:SetBackdropBorderColor(0.22, 0.28, 0.36, 1)

  frame.title = Frames.CreateLabel(frame.titleBar, "Auras", "GameFontNormalLarge")
  frame.title:SetPoint("LEFT", 10, 0)
  Fonts.Apply(frame.title, 16, "OUTLINE")
  frame.title:SetTextColor(0.93, 0.95, 1)
  frame.title:SetShadowOffset(1, -1)

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 8, -38)
  frame.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  frame.scroll:EnableMouse(true)

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

  frame.dragProxy = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame.dragProxy:SetSize(150, 24)
  frame.dragProxy:SetFrameStrata("TOOLTIP")
  frame.dragProxy:SetFrameLevel(100)
  frame.dragProxy:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.dragProxy:SetBackdropColor(0.10, 0.18, 0.32, 0.95)
  frame.dragProxy:SetBackdropBorderColor(0.26, 0.62, 1, 1)
  frame.dragProxy.text = frame.dragProxy:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.dragProxy.text, 12, "OUTLINE")
  frame.dragProxy.text:SetPoint("CENTER")
  frame.dragProxy.text:SetTextColor(0.96, 0.98, 1)
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
  end

  local index = 0
  local yOffset = 0
  local sectionHeaderIndex = 0

  local function EnsureSectionHeader(i)
    if self.frame.sectionHeaders[i] then
      return self.frame.sectionHeaders[i]
    end

    local header = Frames.CreateLabel(content, "", "GameFontNormal")
    Fonts.Apply(header, 13, "OUTLINE")
    header:SetTextColor(1, 0.88, 0.15)
    self.frame.sectionHeaders[i] = header
    return header
  end

  local function RenderSectionHeader(text)
    sectionHeaderIndex = sectionHeaderIndex + 1
    local header = EnsureSectionHeader(sectionHeaderIndex)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", 0, -yOffset)
    header:SetText(text)
    header:Show()
    yOffset = yOffset + 22
  end

  local function EnsureRow(i)
    if self.frame.rows[i] then
      return self.frame.rows[i]
    end
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(240, 28)
    row:SetFrameStrata("FULLSCREEN_DIALOG")
    row:SetFrameLevel(self.frame:GetFrameLevel() + 40)
    row:EnableMouse(false)

    row.button = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.button:SetPoint("LEFT", 0, 0)
    row.button:SetSize(192, 26)
    row.button:SetFrameStrata("FULLSCREEN_DIALOG")
    row.button:SetFrameLevel(row:GetFrameLevel() + 1)
    row.button:EnableMouse(true)
    row.button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.button.text = row.button:CreateFontString(nil, "OVERLAY")
    Fonts.Apply(row.button.text, 13, "OUTLINE")
    row.button.text:SetPoint("LEFT", 8, 0)
    row.button.text:SetPoint("RIGHT", -8, 0)
    row.button.text:SetJustifyH("LEFT")
    row.button.text:SetJustifyV("MIDDLE")
    row.button.text:SetTextColor(0.97, 0.98, 1)
    row.button.text:SetAlpha(1)
    row.button.text:SetShadowOffset(1, -1)
    row.button.text:SetShadowColor(0, 0, 0, 0.9)

    row.topDottedLine = row.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.topDottedLine:SetPoint("TOPLEFT", 6, -1)
    row.topDottedLine:SetPoint("TOPRIGHT", -6, -1)
    row.topDottedLine:SetJustifyH("CENTER")
    row.topDottedLine:SetText(string.rep(". ", 40))
    row.topDottedLine:SetTextColor(0.72, 0.76, 0.84, 0.85)
    row.topDottedLine:Hide()

    row.bottomDottedLine = row.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.bottomDottedLine:SetPoint("BOTTOMLEFT", 6, 1)
    row.bottomDottedLine:SetPoint("BOTTOMRIGHT", -6, 1)
    row.bottomDottedLine:SetJustifyH("CENTER")
    row.bottomDottedLine:SetText(string.rep(". ", 40))
    row.bottomDottedLine:SetTextColor(0.72, 0.76, 0.84, 0.85)
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
      end
    end)
    row.button:SetScript("OnLeave", function()
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
    Fonts.Apply(row.expandButton.text, 11, "OUTLINE")
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

    row.ungroupButton = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.ungroupButton:SetSize(20, 20)
    row.ungroupButton:SetFrameStrata("FULLSCREEN_DIALOG")
    row.ungroupButton:SetFrameLevel(row:GetFrameLevel() + 2)
    row.ungroupButton:EnableMouse(true)
    row.ungroupButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row.ungroupButton.text = row.ungroupButton:CreateFontString(nil, "OVERLAY")
    Fonts.Apply(row.ungroupButton.text, 12, "OUTLINE")
    row.ungroupButton.text:SetPoint("CENTER")
    row.ungroupButton.text:SetText("-")
    row.ungroupButton:SetScript("OnClick", function(selfButton)
      if ns.Registry:RemoveFromGroup(selfButton.auraId) then
        ns.runtime:RefreshAll()
        ns.ui.MainWindow:Refresh()
      end
    end)
    row.ungroupButton:SetScript("OnEnter", function(selfButton)
      ShowTooltip(selfButton, "Remove From Group", "Moves this aura back to the top level.")
    end)
    row.ungroupButton:SetScript("OnLeave", function()
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
    Fonts.Apply(row.upButton.text, 11, "OUTLINE")
    row.upButton.text:SetPoint("CENTER")
    row.upButton.text:SetText("^")
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
      ShowTooltip(selfButton, "Move Up", "Moves this aura earlier in its current list or group.")
    end)
    row.upButton:SetScript("OnLeave", function()
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
    Fonts.Apply(row.downButton.text, 11, "OUTLINE")
    row.downButton.text:SetPoint("CENTER")
    row.downButton.text:SetText("v")
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
      ShowTooltip(selfButton, "Move Down", "Moves this aura later in its current list or group.")
    end)
    row.downButton:SetScript("OnLeave", function()
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
    Fonts.Apply(row.duplicateButton.text, 11, "OUTLINE")
    row.duplicateButton.text:SetPoint("CENTER")
    row.duplicateButton.text:SetText("D")
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
      ShowTooltip(selfButton, "Duplicate Aura", "Creates a copy of this aura or group.")
    end)
    row.duplicateButton:SetScript("OnLeave", function()
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
    Fonts.Apply(row.deleteButton.text, 12, "OUTLINE")
    row.deleteButton.text:SetPoint("CENTER")
    row.deleteButton.text:SetText("X")
    row.deleteButton:SetScript("OnClick", function(selfButton)
      ns.db.ui.editorMode = "config"
      ns.Registry:DeleteAura(selfButton.auraId)
      ns.runtime:RefreshAll()
      ns.ui.MainWindow:Refresh()
    end)
    row.deleteButton:SetScript("OnEnter", function(selfButton)
      ShowTooltip(selfButton, "Delete Aura", "Deletes this aura. Groups delete their child auras too.")
    end)
    row.deleteButton:SetScript("OnLeave", function()
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
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -yOffset)
    local label = aura.name .. " [" .. aura.kind .. "]"
    if AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "group" and (aura.kind == "group" or aura.kind == "dynamic_group") then
      label = "> Drop into " .. aura.name
    elseif AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "reorder" then
      label = (AuraTree.dropInsertAfter and "v " or "^ ") .. label
    end
    row.button.text:SetText(label)
    row.button.text:ClearAllPoints()
    row.button.text:SetPoint("LEFT", 8, 0)
    row.button.text:SetPoint("RIGHT", -8, 0)
    row.button.auraId = aura.id
    row.auraId = aura.id
    row.depth = depth
    row:Show()
    row.button:Show()
    row.button.text:Show()
    if aura.id == ns.db.ui.selectedAuraId then
      row.button:SetBackdropColor(0.16, 0.31, 0.58, 1)
      row.button:SetBackdropBorderColor(0.26, 0.62, 1, 1)
    else
      local isGroupDropTarget = AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "group" and (aura.kind == "group" or aura.kind == "dynamic_group")
      local isReorderTarget = AuraTree.dropTargetAuraId == aura.id and AuraTree.dropMode == "reorder"
      row.button:SetBackdropColor((isGroupDropTarget or isReorderTarget) and 0.14 or 0.10, (isGroupDropTarget or isReorderTarget) and 0.28 or 0.13, (isGroupDropTarget or isReorderTarget) and 0.52 or 0.18, 0.98)
      row.button:SetBackdropBorderColor((isGroupDropTarget or isReorderTarget) and 0.32 or 0.22, (isGroupDropTarget or isReorderTarget) and 0.62 or 0.30, (isGroupDropTarget or isReorderTarget) and 1.0 or 0.40, 1)
    end

    local contentAlpha = isLoaded and 1 or 0.52
    local buttonAlpha = isLoaded and 0.98 or 0.72
    row.button:SetAlpha(buttonAlpha)
    row.button.text:SetAlpha(contentAlpha)
    row.topDottedLine:SetShown(not isLoaded)
    row.bottomDottedLine:SetShown(not isLoaded)
    row.topDottedLine:SetAlpha(contentAlpha)
    row.bottomDottedLine:SetAlpha(contentAlpha)

    local isGroup = aura.kind == "group" or aura.kind == "dynamic_group"
    local inGroup = aura.parentId ~= nil
    row.expandButton.auraId = aura.id
    row.expandButton:SetShown(isGroup)
    if isGroup then
      row.expandButton.text:SetText(ns.db.ui.collapsedGroups[aura.id] and ">" or "v")
      row.expandButton.text:Show()
      row.expandButton:SetBackdropColor(0.12, 0.15, 0.20, 1)
      row.expandButton:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)
    end

    row.ungroupButton.auraId = aura.id
    row.ungroupButton:SetShown(inGroup)
    row.ungroupButton.text:SetShown(inGroup)
    row.ungroupButton:SetBackdropColor(0.16, 0.11, 0.12, 1)
    row.ungroupButton:SetBackdropBorderColor(0.40, 0.18, 0.20, 1)

    local _, siblingIndex, siblingCount = GetSiblingInfo(aura)
    row.upButton.auraId = aura.id
    row.upButton:SetShown(siblingIndex > 1)
    row.upButton.text:SetShown(siblingIndex > 1)
    row.upButton:SetBackdropColor(0.11, 0.16, 0.22, 1)
    row.upButton:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)

    row.downButton.auraId = aura.id
    row.downButton:SetShown(siblingIndex > 0 and siblingIndex < siblingCount)
    row.downButton.text:SetShown(siblingIndex > 0 and siblingIndex < siblingCount)
    row.downButton:SetBackdropColor(0.11, 0.16, 0.22, 1)
    row.downButton:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)

    row.duplicateButton.auraId = aura.id
    row.duplicateButton:SetShown(true)
    row.duplicateButton:SetBackdropColor(0.11, 0.16, 0.22, 1)
    row.duplicateButton:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)

    row.deleteButton.auraId = aura.id
    row.deleteButton:SetShown(true)
    row.deleteButton:SetBackdropColor(0.22, 0.10, 0.12, 1)
    row.deleteButton:SetBackdropBorderColor(0.55, 0.18, 0.20, 1)

    local actionCount = 2 + (isGroup and 1 or 0) + (inGroup and 1 or 0) + (row.upButton:IsShown() and 1 or 0) + (row.downButton:IsShown() and 1 or 0)
    local indent = depth * 14
    local buttonWidth = 236 - (actionCount * 22) - indent
    row.button:SetWidth(math.max(120, buttonWidth))
    row.button:ClearAllPoints()
    row.button:SetPoint("LEFT", indent, 0)
    local anchor = row.button
    if row.expandButton:IsShown() then
      row.expandButton:ClearAllPoints()
      row.expandButton:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
      anchor = row.expandButton
    end
    if row.ungroupButton:IsShown() then
      row.ungroupButton:ClearAllPoints()
      row.ungroupButton:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
      anchor = row.ungroupButton
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
    row.ungroupButton:SetAlpha(contentAlpha)
    row.upButton:SetAlpha(contentAlpha)
    row.downButton:SetAlpha(contentAlpha)
    row.duplicateButton:SetAlpha(contentAlpha)
    row.deleteButton:SetAlpha(contentAlpha)
    yOffset = yOffset + 28

  end

  local loadedNodes, unloadedNodes = BuildOrderedTreeNodes(ns.db.ui.collapsedGroups)
  RenderSectionHeader("Loaded Auras")
  for _, node in ipairs(loadedNodes) do
    RenderNode(node)
  end
  if #unloadedNodes > 0 then
    yOffset = yOffset + (#loadedNodes > 0 and 10 or 0)
    RenderSectionHeader("Not Loaded")
    for _, node in ipairs(unloadedNodes) do
      RenderNode(node)
    end
  end

  content:SetSize(240, math.max(1, yOffset))
  content:SetFrameStrata("FULLSCREEN_DIALOG")
  content:SetFrameLevel(self.frame:GetFrameLevel() + 35)
end
