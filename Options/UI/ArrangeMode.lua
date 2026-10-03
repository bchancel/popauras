local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme
local Anchors = ns.util.Anchors
local SafeValues = ns.SafeValues

local Arrange = { movers = {}, pending = {}, dirty = {}, gridSize = 20, snap = true, showGrid = true, loadedOnly = true }
ns.ui.ArrangeMode = Arrange

local positionKeys = { "point", "relativePoint", "relativeTo", "x", "y" }
local TOOLBAR_WIDTH = 608
local GROUP_GREEN = { 0.35, 0.9, 0.25, 1 }
local ICON_PATH = "Interface\\AddOns\\PopAuras_Options\\Media\\Icons\\Arrange"
local arrowParts = {
  { width = 3, height = 8, x = 0, y = 2, rotation = 0 },
  { width = 8, height = 3, x = -2.2, y = -2.4, rotation = -math.pi / 4 },
  { width = 8, height = 3, x = 2.2, y = -2.4, rotation = math.pi / 4 },
}
local growthAngles = { DOWN = 0, UP = math.pi, LEFT = -math.pi / 2, RIGHT = math.pi / 2 }
local pointFactors = {
  CENTER = { 0.5, 0.5 }, TOP = { 0.5, 1 }, BOTTOM = { 0.5, 0 },
  LEFT = { 0, 0.5 }, RIGHT = { 1, 0.5 }, TOPLEFT = { 0, 1 },
  TOPRIGHT = { 1, 1 }, BOTTOMLEFT = { 0, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function CreateIconButton(parent, iconName, title, description, onClick)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(24, 24)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetSize(18, 18)
  button.icon:SetPoint("CENTER")
  button.icon:SetTexture(ICON_PATH .. iconName .. ".tga")
  button.icon:SetAlpha(0.85)
  button.highlight = button:CreateTexture(nil, "BACKGROUND")
  button.highlight:SetAllPoints()
  button.highlight:SetColorTexture(0.07, 0.19, 0.245, 0.8)
  button.highlight:Hide()
  local function Restore()
    button.highlight:Hide()
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER")
    button.icon:SetAlpha(0.85)
    if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
  end
  button:SetScript("OnEnter", function()
    button.highlight:Show()
    button.icon:SetAlpha(1)
    if GameTooltip then
      GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
      GameTooltip:SetText(title)
      GameTooltip:AddLine(description, 0.725, 0.79, 0.835, true)
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", Restore)
  button:SetScript("OnHide", Restore)
  button:SetScript("OnMouseDown", function(_, mouseButton)
    if mouseButton == "LeftButton" then
      button.icon:ClearAllPoints()
      button.icon:SetPoint("CENTER", button, "CENTER", 0, -1)
    end
  end)
  button:SetScript("OnMouseUp", function()
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER")
  end)
  button:SetScript("OnClick", onClick)
  return button
end

local function Number(value)
  local number = SafeValues:Number(value)
  if number and number == number and number > -math.huge and number < math.huge then return number end
end

local function ReadNumber(frame, method)
  if not frame or (frame.IsForbidden and frame:IsForbidden()) then return nil end
  local ok, value = pcall(frame[method], frame)
  if ok then return Number(value) end
end

local function OwnedFrame(auraId)
  local region = ns.runtime:GetRegionByAuraId(auraId)
  -- Only the renderer's PopAuras host is accessed, never native AuraButtons.
  local frame = region and not region.isNameplateAuraRegion and region.frame
  if frame and not (frame.IsForbidden and frame:IsForbidden()) then return frame end
end

local function ScreenRect(frame)
  local left = ReadNumber(frame, "GetLeft")
  local bottom = ReadNumber(frame, "GetBottom")
  local width = ReadNumber(frame, "GetWidth")
  local height = ReadNumber(frame, "GetHeight")
  local scale = ReadNumber(frame, "GetEffectiveScale")
  local screenScale = ReadNumber(UIParent, "GetEffectiveScale")
  if not left or not bottom or not width or not height or not scale or not screenScale or screenScale <= 0 then return nil end
  local ratio = scale / screenScale
  return left * ratio, bottom * ratio, width * ratio, height * ratio
end

local function CursorPosition()
  local rawX, rawY = GetCursorPosition()
  local x, y = Number(rawX), Number(rawY)
  local scale = ReadNumber(UIParent, "GetEffectiveScale")
  if x and y and scale and scale > 0 then return x / scale, y / scale end
end

local function Round(value, step)
  return math.floor(value / step + 0.5) * step
end

local function Notice(message)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff35c9ffPopAuras:|r " .. message) end
end

function Arrange:IsActive()
  return self.active == true
end

function Arrange:GetPosition(aura)
  return self.active and self.pending[aura.id] or aura.position
end

local function IsAuraLoaded(aura)
  if ns.LoadEvaluator and ns.LoadEvaluator.MatchesWithAncestors then
    return ns.LoadEvaluator:MatchesWithAncestors(aura) == true
  end
  if ns.LoadEvaluator and ns.LoadEvaluator.Matches then return ns.LoadEvaluator:Matches(aura) == true end
  return true
end

function Arrange:StyleMover(mover, highlighted)
  Theme.StyleSurface(mover, "transparent", highlighted and "accentBright" or "accent")
  if mover.loaded == false then
    mover.fill:SetColorTexture(0.30, 0.32, 0.34, 0.85)
    mover:SetBackdropBorderColor(highlighted and 0.92 or 0.64, highlighted and 0.95 or 0.68,
      highlighted and 0.97 or 0.72, 1)
    mover.label:SetTextColor(0.88, 0.9, 0.92, 1)
  else
    mover.fill:SetColorTexture(highlighted and 0.045 or 0.035, highlighted and 0.19 or 0.064,
      highlighted and 0.24 or 0.084, 0.82)
    Theme.SetText(mover.label, "text")
  end
end

function Arrange:UpdateGroupMarker(mover, aura)
  local marker = mover.groupMarker
  local growth = aura.display and aura.display.growth or "DOWN"
  if marker.kind == aura.kind and marker.growth == growth then return end
  marker.kind, marker.growth = aura.kind, growth
  local static = aura.kind == "group"
  local dynamic = aura.kind == "dynamic_group"
  marker:SetShown(static or dynamic)
  marker.letter:SetShown(static)
  local angle = growthAngles[growth] or growthAngles.DOWN
  for index, texture in ipairs(marker.arrow) do
    texture:SetShown(dynamic)
    if dynamic then
      local part = arrowParts[index]
      texture:ClearAllPoints()
      texture:SetPoint("CENTER", marker, "CENTER",
        part.x * math.cos(angle) - part.y * math.sin(angle),
        part.x * math.sin(angle) + part.y * math.cos(angle))
      texture:SetRotation(part.rotation + angle)
    end
  end
end

function Arrange:CanAnchorTo(auraId, targetId)
  -- Include parent relationships: a group cannot be attached to its own child,
  -- nor to another group whose attachment chain eventually points back to it.
  local visited = {}
  local function ReachesSelf(id)
    if id == auraId then return true end
    if visited[id] then return false end
    visited[id] = true
    local aura = ns.Registry:GetAura(id)
    if not aura then return false end
    local position = self:GetPosition(aura) or {}
    return (aura.parentId and ReachesSelf(aura.parentId))
      or (position.relativeTo and ReachesSelf(position.relativeTo)) or false
  end
  return not ReachesSelf(targetId)
end

function Arrange:ResolveTarget(position)
  local frame = Anchors.Resolve(position.relativeTo)
  if frame and not (frame.IsForbidden and frame:IsForbidden()) then return frame end
end

function Arrange:GetAnchorTargets(auraId)
  local entries = {}
  for _, entry in ipairs(Anchors.GetTargetList()) do
    if self:CanAnchorTo(auraId, entry.key) then
      local target = self:ResolveTarget({ relativeTo = entry.key })
      if target and ScreenRect(target) then
        entries[#entries + 1] = { value = entry.key, label = entry.label }
      end
    end
  end
  return entries
end

function Arrange:SyncMover(auraId)
  if not self.active then return end
  local mover = self.movers[auraId]
  local aura = ns.Registry:GetAura(auraId)
  if not mover or not aura then return end
  local position = self:GetPosition(aura) or {}
  local frame = OwnedFrame(auraId)
  local width = ReadNumber(frame, "GetWidth") or position.width or aura.display.width or 100
  local height = ReadNumber(frame, "GetHeight") or position.height or aura.display.height or 32
  mover:SetSize(math.max(1, width), math.max(1, height))
  local hasMarker = aura.kind == "group" or aura.kind == "dynamic_group"
  local markerPadding = hasMarker and height < 34 and 20 or 0
  mover.label:ClearAllPoints()
  mover.label:SetPoint("CENTER", mover, "CENTER", markerPadding / 2, 0)
  mover.label:SetWidth(math.max(8, width - 12 - markerPadding))
  mover:ClearAllPoints()
  local target = self:ResolveTarget(position)
  mover.unavailable = target == nil
  mover:SetPoint(position.point or "CENTER", target or UIParent,
    position.relativePoint or "CENTER", position.x or 0, position.y or 0)
  local name = (aura.name or "Aura") .. (mover.loaded == false and "  /  Unloaded" or "")
  mover.coordinates:SetText(mover.unavailable and (name .. "  /  Anchor unavailable")
    or string.format("%s  /  X %.0f   Y %.0f", name, position.x or 0, position.y or 0))
  self:UpdateGroupMarker(mover, aura)
end

function Arrange:ApplyPosition(auraId)
  if not self.active then return end
  local aura = ns.Registry:GetAura(auraId)
  local position = aura and self:GetPosition(aura)
  if not position then return end
  local frame = OwnedFrame(auraId)
  local target = self:ResolveTarget(position)
  if frame and target then
    -- Move only the owned host. Children follow their established anchors;
    -- no provider evaluation, native filter resets, or renderer handoffs.
    frame:ClearAllPoints()
    frame:SetPoint(position.point or "CENTER", target, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
  end
  self:SyncMover(auraId)
end

function Arrange:SetOffset(auraId, x, y)
  if not self.active or InCombatLockdown() then return false end
  local position = self.pending[auraId]
  x, y = Number(x), Number(y)
  if not position or not x or not y then return false end
  position.x, position.y = x, y
  self.dirty[auraId] = true
  self:ApplyPosition(auraId)
  return true
end

function Arrange:ChangeAnchor(auraId, changes)
  if not self.active or InCombatLockdown() then return false end
  local position = self.pending[auraId]
  local mover = self.movers[auraId]
  if not position or not mover then return false end
  local relativeTo = changes.relativeTo or position.relativeTo or "UIParent"
  if not self:CanAnchorTo(auraId, relativeTo) then return false end
  local target = self:ResolveTarget({ relativeTo = relativeTo })
  local left, bottom, width, height = ScreenRect(mover)
  local targetLeft, targetBottom, targetWidth, targetHeight = ScreenRect(target)
  if not left or not targetLeft then
    Notice("This anchor's position is unavailable. Choose another anchor.")
    return false
  end
  local point = changes.point or position.point or "CENTER"
  local relativePoint = changes.relativePoint or position.relativePoint or "CENTER"
  local ownFactor, targetFactor = pointFactors[point], pointFactors[relativePoint]
  if not ownFactor or not targetFactor then return false end
  -- Convert anchor points without jumping on screen, including scaled targets.
  position.relativeTo, position.point, position.relativePoint = relativeTo, point, relativePoint
  return self:SetOffset(auraId,
    left + width * ownFactor[1] - targetLeft - targetWidth * targetFactor[1],
    bottom + height * ownFactor[2] - targetBottom - targetHeight * targetFactor[2])
end

function Arrange:Select(mover)
  if mover and mover.arrangeVisible ~= true then return end
  if self.selected and self.selected ~= mover then
    self:StyleMover(self.selected, false)
    self.selected:SetFrameLevel(self.selected.baseLevel)
    self.selected.coordinates:Hide()
    self.selected.controls:Hide()
  end
  if self.anchorPopover and self.selected ~= mover then self.anchorPopover:Hide() end
  self.selected = mover
  if not mover then return end
  mover:SetFrameLevel(mover.baseLevel)
  self:StyleMover(mover, true)
  mover.coordinates:Show()
  mover.controls:Show()
end

function Arrange:BeginDrag(mover)
  if not self.active or InCombatLockdown() or mover.unavailable or mover.arrangeVisible ~= true then return end
  local x, y = CursorPosition()
  if not x then return end
  self:Select(mover)
  mover:SetFrameLevel(self.frame:GetFrameLevel() + 70)
  if self.anchorPopover then self.anchorPopover:Hide() end
  local position = self.pending[mover.auraId]
  local left, bottom, width, height = ScreenRect(mover)
  if not left then return end
  self.drag = { mover = mover, cursorX = x, cursorY = y, x = position.x or 0, y = position.y or 0,
    centerX = left + width / 2, centerY = bottom + height / 2 }
  self:SetToolbarVisible(false, true)
  self.frame.bar:EnableMouse(false)
  mover:SetScript("OnUpdate", function() self:UpdateDrag() end)
end

function Arrange:UpdateDrag()
  local drag = self.drag
  if not drag or not self.active or InCombatLockdown() then return end
  local x, y = CursorPosition()
  if not x then return end
  local dx, dy = x - drag.cursorX, y - drag.cursorY
  if self.snap and not IsShiftKeyDown() then
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    dx = Round(drag.centerX + dx - width / 2, self.gridSize) + width / 2 - drag.centerX
    dy = Round(drag.centerY + dy - height / 2, self.gridSize) + height / 2 - drag.centerY
  end
  self:SetOffset(drag.mover.auraId, drag.x + dx, drag.y + dy)
end

function Arrange:StopDrag()
  if self.drag then
    self:UpdateDrag()
    self.drag.mover:SetScript("OnUpdate", nil)
    self.drag = nil
    self.frame.bar:EnableMouse(true)
    if self.toolbarPinned then self:SetToolbarVisible(true, true) end
  end
  if self.selected then self.selected:SetFrameLevel(self.selected.baseLevel) end
end

function Arrange:Nudge(dx, dy)
  if not self.selected or self.drag then return end
  local position = self.pending[self.selected.auraId]
  if not position or self.selected.unavailable then return end
  local step = IsShiftKeyDown() and 10 or 1
  self:SetOffset(self.selected.auraId, (position.x or 0) + dx * step, (position.y or 0) + dy * step)
end

function Arrange:ShowAnchors(mover)
  self:Select(mover)
  if not self.anchorPopover then
    local function Position() return self.selected and self.pending[self.selected.auraId] or {} end
    local function Change(key, value)
      if self.selected then self:ChangeAnchor(self.selected.auraId, { [key] = value }) end
    end
    self.anchorPopover = Frames.CreateSettingsPopover({
      title = "Anchor & Position", width = 360,
      rows = {
        { label = "Attach to", type = "dropdown", width = 190,
          values = function() return self.selected and self:GetAnchorTargets(self.selected.auraId) or {} end,
          get = function() return Position().relativeTo or "UIParent" end,
          set = function(value) Change("relativeTo", value) end },
        { label = "Aura point", type = "dropdown", values = Anchors.GetPointList,
          get = function() return Position().point or "CENTER" end,
          set = function(value) Change("point", value) end },
        { label = "Anchor point", type = "dropdown", values = Anchors.GetPointList,
          get = function() return Position().relativePoint or "CENTER" end,
          set = function(value) Change("relativePoint", value) end },
        { label = "Offset X", get = function() return Position().x or 0 end,
          set = function(value)
            if self.selected then self:SetOffset(self.selected.auraId, tonumber(value), Position().y or 0) end
          end },
        { label = "Offset Y", get = function() return Position().y or 0 end,
          set = function(value)
            if self.selected then self:SetOffset(self.selected.auraId, Position().x or 0, tonumber(value)) end
          end },
      },
    })
  end
  self.anchorPopover:ShowFor(mover.anchorButton)
end

function Arrange:CreateMover(aura)
  local mover = self.movers[aura.id]
  if not mover then
    mover = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    if mover.SetParentKey then mover:SetParentKey("PopAurasArrange_" .. tostring(aura.id):gsub("[^%w_]", "_")) end
    mover.auraId = aura.id
    mover.baseLevel = self.frame:GetFrameLevel() + 20
    mover:SetFrameLevel(mover.baseLevel)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    Theme.StyleSurface(mover, "transparent", "accent")
    mover.fill = mover:CreateTexture(nil, "BACKGROUND")
    mover.fill:SetAllPoints()
    mover.fill:SetColorTexture(0.035, 0.064, 0.084, 0.82)
    mover.label = Frames.CreateLabel(mover, "", "GameFontHighlight", "bodySmall")
    mover.label:SetPoint("CENTER")
    mover.label:SetJustifyH("CENTER")
    mover.label:SetWordWrap(false)
    mover.coordinates = Frames.CreateLabel(mover, "", "GameFontHighlight", "caption")
    mover.coordinates:SetPoint("BOTTOMLEFT", mover, "TOPLEFT", 0, 4)
    mover.coordinates:Hide()

    mover.groupMarker = CreateFrame("Frame", nil, mover)
    mover.groupMarker:SetSize(14, 14)
    mover.groupMarker:SetPoint("TOPLEFT", mover, "TOPLEFT", 3, -3)
    mover.groupMarker:SetFrameLevel(mover:GetFrameLevel() + 5)
    mover.groupMarker:EnableMouse(false)
    mover.groupMarker.letter = Frames.CreateLabel(mover.groupMarker, "G", "GameFontNormal", "glyphSmall")
    mover.groupMarker.letter:SetPoint("CENTER")
    mover.groupMarker.letter:SetTextColor(unpack(GROUP_GREEN))
    mover.groupMarker.arrow = {}
    for _, part in ipairs(arrowParts) do
      local texture = mover.groupMarker:CreateTexture(nil, "OVERLAY")
      texture:SetSize(part.width, part.height)
      texture:SetColorTexture(unpack(GROUP_GREEN))
      mover.groupMarker.arrow[#mover.groupMarker.arrow + 1] = texture
    end

    mover.controls = CreateFrame("Frame", nil, mover, "BackdropTemplate")
    mover.controls:SetSize(111, 28)
    mover.controls:SetPoint("TOPLEFT", mover, "BOTTOMLEFT", 0, -2)
    mover.controls:SetFrameLevel(mover:GetFrameLevel() + 10)
    mover.controls:SetClampedToScreen(true)
    Theme.StyleSurface(mover.controls, "canvasAlt", "borderStrong")
    mover.anchorButton = CreateIconButton(mover.controls, "Anchor", "Anchor", "Change the attachment point and position offsets.",
      function() self:ShowAnchors(mover) end)
    mover.anchorButton:SetPoint("LEFT", 3, 0)
    mover.centerButton = CreateIconButton(mover.controls, "Center", "Center", "Move this item to the center of the screen.", function()
      local position = self.pending[mover.auraId]
      if not position or not self.active or InCombatLockdown() then return end
      position.relativeTo, position.point, position.relativePoint = "UIParent", "CENTER", "CENTER"
      self:SetOffset(mover.auraId, 0, 0)
    end)
    mover.centerButton:SetPoint("LEFT", mover.anchorButton, "RIGHT", 3, 0)
    mover.resetButton = CreateIconButton(mover.controls, "Reset", "Reset", "Restore the position from before entering Arrange.", function()
      if not self.active or InCombatLockdown() then return end
      local original = ns.Registry:GetAura(mover.auraId)
      if not original then return end
      self.pending[mover.auraId] = ns.util.Tables.DeepCopy(original.position)
      self.dirty[mover.auraId] = nil
      self:ApplyPosition(mover.auraId)
      if self.anchorPopover then self.anchorPopover:Refresh() end
    end)
    mover.resetButton:SetPoint("LEFT", mover.centerButton, "RIGHT", 3, 0)
    mover.configButton = CreateIconButton(mover.controls, "Configure", "Configure", "Save this layout and open the item's Display options.", function()
      self:Finish(true, true, mover.auraId)
    end)
    mover.configButton:SetPoint("LEFT", mover.resetButton, "RIGHT", 3, 0)
    mover.controls:Hide()
    mover:SetScript("OnEnter", function()
      mover.controls:Show()
      mover.coordinates:Show()
      self:StyleMover(mover, true)
    end)
    local function Leave()
      C_Timer.After(0.15, function()
        if not self.active or self.selected == mover then return end
        if mover:IsMouseOver() or mover.controls:IsMouseOver() then return end
        mover.controls:Hide()
        mover.coordinates:Hide()
        self:StyleMover(mover, false)
      end)
    end
    mover:SetScript("OnLeave", Leave)
    mover.controls:EnableMouse(true)
    mover.controls:SetScript("OnLeave", Leave)
    for _, button in ipairs({ mover.anchorButton, mover.centerButton, mover.resetButton, mover.configButton }) do
      button:HookScript("OnLeave", Leave)
    end
    mover:SetScript("OnMouseDown", function(_, button)
      if button == "LeftButton" then self:Select(mover) end
    end)
    mover:SetScript("OnDragStart", function() self:BeginDrag(mover) end)
    mover:SetScript("OnDragStop", function() self:StopDrag() end)
    self.movers[aura.id] = mover
  end
  mover.label:SetText(aura.name or "Unnamed Aura")
  self.pending[aura.id] = self.pending[aura.id] or ns.util.Tables.DeepCopy(aura.position or {})
  self:SyncMover(aura.id)
  local frame = OwnedFrame(aura.id)
  if frame and not frame._popAurasArrangeSizeHook then
    frame:HookScript("OnSizeChanged", function() self:SyncMover(aura.id) end)
    frame._popAurasArrangeSizeHook = true
  end
  return mover
end

function Arrange:RefreshMovers()
  if not self.active then return end
  local current, ordered = {}, {}
  for _, auraId in ipairs(ns.Registry:GetOrder()) do
    local aura = ns.Registry:GetAura(auraId)
    local nameplate = ns.renderers.NameplateAuraRegion and ns.renderers.NameplateAuraRegion:CanHandle(aura)
    if aura and not aura.parentId and not nameplate then
      current[auraId] = true
      local mover = self.movers[auraId] or self:CreateMover(aura)
      self.pending[auraId] = self.pending[auraId] or ns.util.Tables.DeepCopy(aura.position or {})
      mover.loaded = IsAuraLoaded(aura)
      mover.arrangeVisible = not self.loadedOnly or mover.loaded
      if not mover.arrangeVisible then
        if self.drag and self.drag.mover == mover then self:StopDrag() end
        if self.selected == mover then self:Select(nil) end
        mover.controls:Hide()
        mover.coordinates:Hide()
      end
      mover:SetShown(mover.arrangeVisible)
      self:StyleMover(mover, self.selected == mover)
      self:SyncMover(auraId)
      ordered[#ordered + 1] = mover
    end
  end
  for auraId, mover in pairs(self.movers) do
    if not current[auraId] then
      if self.drag and self.drag.mover == mover then self:StopDrag() end
      if self.selected == mover then self:Select(nil) end
      mover.arrangeVisible = false
      mover.controls:Hide()
      mover.coordinates:Hide()
      mover:Hide()
    end
  end
  -- Smaller handles remain reachable when large group bounds overlap them.
  table.sort(ordered, function(left, right)
    local leftArea, rightArea = left:GetWidth() * left:GetHeight(), right:GetWidth() * right:GetHeight()
    if leftArea == rightArea then return tostring(left.auraId) < tostring(right.auraId) end
    return leftArea > rightArea
  end)
  for index, mover in ipairs(ordered) do
    mover.baseLevel = self.frame:GetFrameLevel() + 20 + math.min(index, 40)
    mover:SetFrameLevel(mover.baseLevel)
  end
  if #ordered == 0 then Notice("No screen groups or standalone auras to arrange.") end
end

function Arrange:DrawGrid()
  if not self.frame then return end
  local grid = self.frame.grid
  grid:SetShown(self.showGrid)
  if not self.showGrid then return end
  local width, height = UIParent:GetWidth(), UIParent:GetHeight()
  local count = 0
  local function Line(vertical, offset, axis)
    count = count + 1
    local texture = grid.lines[count]
    if not texture then texture = grid:CreateTexture(nil, "ARTWORK"); grid.lines[count] = texture end
    texture:ClearAllPoints()
    texture:SetColorTexture(0.21, 0.79, 1, axis and 0.45 or 0.1)
    texture:SetSize(vertical and 1 or width, vertical and height or 1)
    texture:SetPoint("CENTER", grid, "CENTER", vertical and offset or 0, vertical and 0 or offset)
    texture:Show()
  end
  Line(true, 0, true)
  Line(false, 0, true)
  for offset = self.gridSize, width / 2, self.gridSize do Line(true, offset); Line(true, -offset) end
  for offset = self.gridSize, height / 2, self.gridSize do Line(false, offset); Line(false, -offset) end
  for index = count + 1, #grid.lines do grid.lines[index]:Hide() end
end

function Arrange:PositionToolbarControls()
  local bar, controls = self.frame.bar, self.frame.toolbarControls
  local left, _, width = ScreenRect(bar)
  local screenWidth = ReadNumber(UIParent, "GetWidth")
  local scale = ReadNumber(bar, "GetEffectiveScale")
  local screenScale = ReadNumber(UIParent, "GetEffectiveScale")
  controls:ClearAllPoints()
  if left and screenWidth and scale and screenScale and screenScale > 0
      and left + width + (controls:GetWidth() + 4) * scale / screenScale > screenWidth then
    controls:SetPoint("RIGHT", bar, "LEFT", -4, 0)
  else
    controls:SetPoint("LEFT", bar, "RIGHT", 4, 0)
  end
end

function Arrange:LayoutToolbar()
  local bar = self.frame.bar
  local width = ReadNumber(UIParent, "GetWidth") or TOOLBAR_WIDTH
  local scale = math.max(0.1, math.min(1, (width - 24) / TOOLBAR_WIDTH))
  bar:SetScale(scale)
  bar:ClearAllPoints()
  if self.toolbarPosition then
    bar:SetPoint("CENTER", UIParent, "CENTER", self.toolbarPosition.x / scale, self.toolbarPosition.y / scale)
  else
    bar:SetPoint("TOPLEFT", UIParent, "TOP", -TOOLBAR_WIDTH / 2, -10 / scale)
  end
  self:PositionToolbarControls()
end

function Arrange:SetToolbarVisible(visible, immediate)
  local bar, controls = self.frame.bar, self.frame.toolbarControls
  if visible and (not self.active or self.drag) then return end
  self.toolbarHoverToken = (self.toolbarHoverToken or 0) + 1
  controls:SetScript("OnUpdate", nil)
  bar:SetAlpha(visible and 1 or 0.65)
  local fromAlpha = controls:IsShown() and (self.toolbarAlpha or 1) or 0
  local toAlpha = visible and 1 or 0
  if visible then self:PositionToolbarControls(); controls:Show() end
  if immediate or fromAlpha == toAlpha then
    self.toolbarAlpha = toAlpha
    controls:SetAlpha(toAlpha)
    controls:SetShown(visible)
    return
  end
  local elapsed = 0
  controls:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    local progress = math.min(1, elapsed / 0.14)
    self.toolbarAlpha = fromAlpha + (toAlpha - fromAlpha) * progress
    controls:SetAlpha(self.toolbarAlpha)
    if progress == 1 then
      controls:SetScript("OnUpdate", nil)
      -- Hiding the controls removes their mouse hit area as well as the visual.
      if not visible then controls:Hide() end
    end
  end)
end

function Arrange:ScheduleToolbarCollapse(delay)
  if not self.active then return end
  self.toolbarHoverToken = (self.toolbarHoverToken or 0) + 1
  local token = self.toolbarHoverToken
  C_Timer.After(delay or 0.55, function()
    if not self.active or token ~= self.toolbarHoverToken then return end
    if self.toolbarPinned or self.toolbarDragging or self.frame.spacing:HasFocus() then return end
    if self.frame.bar:IsMouseOver()
        or (self.frame.toolbarControls:IsShown() and self.frame.toolbarControls:IsMouseOver()) then return end
    self:SetToolbarVisible(false)
  end)
end

function Arrange:BeginToolbarDrag()
  if not self.active or self.drag or InCombatLockdown() then return end
  self.toolbarDragging = true
  self:SetToolbarVisible(true, true)
  self.frame.bar:StartMoving()
end

function Arrange:StopToolbarDrag()
  if not self.toolbarDragging then return end
  self.frame.bar:StopMovingOrSizing()
  self.toolbarDragging = false
  local left, bottom, width, height = ScreenRect(self.frame.bar)
  local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
  if left then
    -- Remember the toolbar location between Arrange sessions without changing
    -- any aura positions. All geometry here belongs to our own toolbar.
    self.toolbarPosition = { x = left + width / 2 - screenWidth / 2,
      y = bottom + height / 2 - screenHeight / 2 }
  end
  self:LayoutToolbar()
  self:ScheduleToolbarCollapse()
end

function Arrange:Create()
  local frame = CreateFrame("Frame", "PopAurasArrangeMode", UIParent)
  frame:SetAllPoints(UIParent)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(200)
  frame:EnableMouse(true)
  frame:Hide()
  frame.dim = frame:CreateTexture(nil, "BACKGROUND")
  frame.dim:SetAllPoints()
  frame.dim:SetColorTexture(0, 0, 0, 0.35)
  frame.grid = CreateFrame("Frame", nil, frame)
  frame.grid:SetAllPoints()
  frame.grid.lines = {}

  frame.bar = CreateFrame("Frame", "PopAurasArrangeToolbar", frame, "BackdropTemplate")
  frame.bar:SetSize(86, 34)
  frame.bar:SetFrameLevel(300)
  frame.bar:EnableMouse(true)
  frame.bar:SetMovable(true)
  frame.bar:SetClampedToScreen(true)
  frame.bar:RegisterForDrag("LeftButton")
  frame.bar:SetScript("OnDragStart", function() self:BeginToolbarDrag() end)
  frame.bar:SetScript("OnDragStop", function() self:StopToolbarDrag() end)
  Theme.StyleSurface(frame.bar, "canvas", "accent")
  frame.title = Frames.CreateLabel(frame.bar, "Arrange  ::", "GameFontNormal", "controlSmall")
  frame.title:SetPoint("CENTER")
  Theme.SetText(frame.title, "accentBright")

  frame.toolbarControls = CreateFrame("Frame", "PopAurasArrangeControls", frame.bar, "BackdropTemplate")
  frame.toolbarControls:SetSize(518, 34)
  frame.toolbarControls:SetFrameLevel(301)
  frame.toolbarControls:SetClampedToScreen(true)
  frame.toolbarControls:EnableMouse(true)
  Theme.StyleSurface(frame.toolbarControls, "canvas", "borderStrong")

  frame.loadedOnlyCheck = Frames.CreateCheckbox(frame.toolbarControls, "Loaded Only")
  frame.loadedOnlyCheck:SetSize(20, 20)
  frame.loadedOnlyCheck:SetPoint("LEFT", 6, 0)
  frame.loadedOnlyCheck:SetChecked(self.loadedOnly)
  frame.loadedOnlyCheck.Text:ClearAllPoints()
  frame.loadedOnlyCheck.Text:SetPoint("LEFT", frame.loadedOnlyCheck, "RIGHT", 4, 0)
  frame.loadedOnlyCheck.Text:SetWidth(72)
  Theme.ApplyTypography(frame.loadedOnlyCheck.Text, "caption")
  frame.loadedOnlyCheck:SetScript("OnClick", function(check)
    self.loadedOnly = check:GetChecked() and true or false
    self:RefreshMovers()
  end)

  frame.gridButton = Frames.CreateButton(frame.toolbarControls, "Grid: On", 58, 24, function()
    self.showGrid = not self.showGrid
    frame.gridButton:SetText(self.showGrid and "Grid: On" or "Grid: Off")
    self:DrawGrid()
  end)
  frame.gridButton:SetPoint("LEFT", 110, 0)
  frame.snapButton = Frames.CreateButton(frame.toolbarControls, "Snap: On", 58, 24, function()
    self.snap = not self.snap
    frame.snapButton:SetText(self.snap and "Snap: On" or "Snap: Off")
  end)
  frame.snapButton:SetPoint("LEFT", frame.gridButton, "RIGHT", 4, 0)
  frame.spacing = Frames.CreateInput(frame.toolbarControls, 34, 24)
  frame.spacing:SetPoint("LEFT", frame.snapButton, "RIGHT", 6, 0)
  frame.spacing:SetText(tostring(self.gridSize))
  local function CommitSpacing(input)
    local value = tonumber(input:GetText())
    self.gridSize = math.max(4, math.min(100, math.floor(Number(value) or self.gridSize)))
    input:SetText(tostring(self.gridSize))
    input:ClearFocus()
    self:DrawGrid()
  end
  frame.spacing:SetScript("OnEnterPressed", CommitSpacing)
  frame.spacing:SetScript("OnEscapePressed", function(input) input:SetText(tostring(self.gridSize)); input:ClearFocus() end)
  frame.spacingLabel = Frames.CreateLabel(frame.toolbarControls, "px", "GameFontNormalSmall", "caption")
  frame.spacingLabel:SetSize(12, 16)
  frame.spacingLabel:SetPoint("LEFT", frame.spacing, "RIGHT", 4, 0)
  frame.pinButton = Frames.CreateButton(frame.toolbarControls, "Pin", 48, 24, function()
    self.toolbarPinned = not self.toolbarPinned
    frame.pinButton:SetText(self.toolbarPinned and "Pinned" or "Pin")
    self:SetToolbarVisible(true)
    self:ScheduleToolbarCollapse()
  end)
  frame.pinButton:SetPoint("LEFT", frame.spacingLabel, "RIGHT", 8, 0)
  frame.cancelButton = Frames.CreateButton(frame.toolbarControls, "Cancel", 56, 24, function() self:Finish(false, true) end)
  frame.cancelButton:SetPoint("RIGHT", -108, 0)
  frame.saveButton = Frames.CreateButton(frame.toolbarControls, "Save & Exit", 94, 24, function() self:Finish(true, false) end)
  frame.saveButton:SetPoint("RIGHT", -6, 0)
  Theme.StyleButton(frame.saveButton, "success")
  local function EnterToolbar() self:SetToolbarVisible(true) end
  local function LeaveToolbar() self:ScheduleToolbarCollapse() end
  for _, widget in ipairs({ frame.bar, frame.toolbarControls, frame.gridButton, frame.snapButton,
      frame.spacing, frame.loadedOnlyCheck, frame.pinButton, frame.cancelButton, frame.saveButton }) do
    widget:HookScript("OnEnter", EnterToolbar)
    widget:HookScript("OnLeave", LeaveToolbar)
  end
  frame.spacing:HookScript("OnEditFocusGained", EnterToolbar)
  frame.spacing:HookScript("OnEditFocusLost", LeaveToolbar)
  for _, button in ipairs({ frame.gridButton, frame.snapButton, frame.pinButton, frame.cancelButton, frame.saveButton }) do
    Theme.ApplyTypography(button:GetFontString(), "caption")
  end
  frame.help = Frames.CreateLabel(frame, "", "GameFontHighlight", "bodySmall")
  frame.help:SetPoint("BOTTOM", 0, 28)
  frame.help:SetJustifyH("CENTER")
  frame.help:SetText("Toolbar: hover to open, drag to move.  Arrows: 1 px  /  Shift + arrows: 10 px  /  Shift + drag: no snap  /  Esc: cancel")

  frame:EnableKeyboard(true)
  frame:SetPropagateKeyboardInput(true)
  frame:SetScript("OnKeyDown", function(_, key)
    if InCombatLockdown() then return end
    local editing = frame.spacing:HasFocus()
    if self.anchorPopover and self.anchorPopover:IsShown() then editing = true end
    local consumed = false
    if key == "ESCAPE" and self.anchorPopover and self.anchorPopover:IsShown() then
      self.anchorPopover:Hide(); consumed = true
    elseif key == "ESCAPE" and not editing then self:Finish(false, true); consumed = true
    elseif not editing and self.selected then
      local offsets = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
      local offset = offsets[key]
      if offset then self:Nudge(offset[1], offset[2]); consumed = true end
    end
    frame:SetPropagateKeyboardInput(not consumed)
  end)
  frame:SetScript("OnHide", function() if self.active then self:Finish(false, false) end end)
  frame:SetScript("OnMouseDown", function()
    self:Select(nil)
    if self.anchorPopover then self.anchorPopover:Hide() end
  end)
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_LOGOUT")
  frame:RegisterEvent("UI_SCALE_CHANGED")
  frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
  frame:SetScript("OnEvent", function(_, event)
    if not self.active then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LOGOUT" then
      self:Finish(false, false)
      if event == "PLAYER_REGEN_DISABLED" then Notice("Arrange closed for combat. Unsaved positions were discarded.") end
    else
      self:LayoutToolbar()
      self:DrawGrid()
      for auraId in pairs(self.pending) do self:SyncMover(auraId) end
    end
  end)
  self.frame = frame
  return frame
end

function Arrange:Start()
  if self.active then return end
  if InCombatLockdown() then Notice("Arrange is available after combat ends."); return end
  if not self.frame then self:Create() end
  self.pending, self.dirty = {}, {}
  self.active = true
  self.selected = nil
  -- Closing the editor ends its selected-aura preview. Arrange uses separate
  -- labeled handles and never converts live restricted state into preview data.
  if ns.ui.MainWindow.frame then ns.ui.MainWindow.frame:Hide() end
  self.frame:Show()
  self.frame:SetPropagateKeyboardInput(true)
  self.frame.bar:EnableMouse(true)
  self:LayoutToolbar()
  self:SetToolbarVisible(true, true)
  self:ScheduleToolbarCollapse(2)
  self:DrawGrid()
  self.frame.loadedOnlyCheck:SetChecked(self.loadedOnly)
  self:RefreshMovers()
end

function Arrange:Finish(save, reopenEditor, auraId)
  if not self.active then return end
  self:StopDrag()
  self:StopToolbarDrag()
  if InCombatLockdown() then save, reopenEditor = false, false end
  if save then
    for id in pairs(self.dirty) do
      local aura = ns.Registry:GetAura(id)
      local position = self.pending[id]
      if aura and not aura.parentId and position then
        for _, key in ipairs(positionKeys) do aura.position[key] = position[key] end
      end
    end
  end
  self.active = false
  self.toolbarHoverToken = (self.toolbarHoverToken or 0) + 1
  self.frame.toolbarControls:SetScript("OnUpdate", nil)
  self.frame.toolbarControls:Hide()
  self.pending, self.dirty = {}, {}
  self.selected = nil
  if self.anchorPopover then self.anchorPopover:Hide() end
  for _, mover in pairs(self.movers) do
    mover:SetScript("OnUpdate", nil)
    mover.controls:Hide()
    mover.coordinates:Hide()
    mover:Hide()
    self:StyleMover(mover, false)
  end
  self.frame:Hide()
  if reopenEditor and ns.ui.MainWindow.frame then
    if auraId then
      ns.db.ui.selectedAuraId = auraId
      ns.db.ui.editorMode, ns.db.ui.activeTab = "config", "display"
    end
    ns.ui.MainWindow.frame:Show()
    ns.ui.MainWindow:RefreshSelection()
  end
  ns.runtime:RefreshAll()
end
