local _, ns = ...

local Anchors = {}
ns.util.Anchors = Anchors

Anchors.points = {
  "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT",
  "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

Anchors.pointEntries = {
  { key = "CENTER", label = "Center" },
  { key = "TOP", label = "Top Center" },
  { key = "BOTTOM", label = "Bottom Center" },
  { key = "LEFT", label = "Left" },
  { key = "RIGHT", label = "Right" },
  { key = "TOPLEFT", label = "Top Left" },
  { key = "TOPRIGHT", label = "Top Right" },
  { key = "BOTTOMLEFT", label = "Bottom Left" },
  { key = "BOTTOMRIGHT", label = "Bottom Right" },
}

Anchors.nameplateAnchorEntries = {
  { key = "LEFT", label = "Left" },
  { key = "RIGHT", label = "Right" },
  { key = "TOPRIGHT", label = "Top Right" },
  { key = "TOP", label = "Top Center" },
  { key = "TOPLEFT", label = "Top Left" },
  { key = "BOTTOMRIGHT", label = "Bottom Right" },
  { key = "BOTTOM", label = "Bottom Center" },
  { key = "BOTTOMLEFT", label = "Bottom Left" },
}

local nameplateAnchorPoints = {
  LEFT = { point = "RIGHT", relativePoint = "LEFT" },
  RIGHT = { point = "LEFT", relativePoint = "RIGHT" },
  TOPRIGHT = { point = "BOTTOMRIGHT", relativePoint = "TOPRIGHT" },
  TOP = { point = "BOTTOM", relativePoint = "TOP" },
  TOPLEFT = { point = "BOTTOMLEFT", relativePoint = "TOPLEFT" },
  BOTTOMRIGHT = { point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT" },
  BOTTOM = { point = "TOP", relativePoint = "BOTTOM" },
  BOTTOMLEFT = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT" },
}

Anchors.targets = {
  { key = "UIParent", label = "Screen", resolver = function() return UIParent end },
  { key = "PlayerFrame", label = "Player Frame", resolver = function() return _G.PlayerFrame end },
  { key = "TargetFrame", label = "Target Frame", resolver = function() return _G.TargetFrame end },
  { key = "FocusFrame", label = "Focus Frame", resolver = function() return _G.FocusFrame end },
  { key = "BuffIconCooldownViewer", label = "Tracked Buffs", resolver = function() return _G.BuffIconCooldownViewer end },
  { key = "BuffBarCooldownViewer", label = "Tracked Bars", resolver = function() return _G.BuffBarCooldownViewer end },
  { key = "EssentialCooldownViewer", label = "Essential Cooldowns", resolver = function() return _G.EssentialCooldownViewer end },
  { key = "UtilityCooldownViewer", label = "Utility Cooldowns", resolver = function() return _G.UtilityCooldownViewer end },
}

function Anchors.Resolve(anchorTarget)
  if anchorTarget == nil or anchorTarget == "" or anchorTarget == "UIParent" then
    return UIParent
  end

  if ns.runtime and ns.runtime.GetRegionByAuraId then
    local region = ns.runtime:GetRegionByAuraId(anchorTarget)
    if region and region.frame then
      return region.frame
    end
  end

  for _, entry in ipairs(Anchors.targets) do
    if entry.key == anchorTarget then
      local resolved = entry.resolver and entry.resolver() or nil
      if resolved then
        return resolved
      end
      break
    end
  end

  return _G[anchorTarget] or UIParent
end

function Anchors.GetTargetList()
  local items = {}
  for _, entry in ipairs(Anchors.targets) do
    items[#items + 1] = entry
  end

  if ns.Registry and ns.Registry.IterateGroups then
    for _, aura in ns.Registry.IterateGroups() do
      items[#items + 1] = { key = aura.id, label = "Group: " .. aura.name }
    end
  end

  return items
end

function Anchors.GetPointList()
  local items = {}
  for _, entry in ipairs(Anchors.pointEntries) do
    items[#items + 1] = entry
  end
  return items
end

function Anchors.GetNameplateAnchorList()
  local items = {}
  for _, entry in ipairs(Anchors.nameplateAnchorEntries) do
    items[#items + 1] = entry
  end
  return items
end

function Anchors.GetNameplateAnchor(position)
  position = type(position) == "table" and position or {}
  if nameplateAnchorPoints[position.nameplateAnchor] then
    return position.nameplateAnchor
  end

  -- Older builds exposed the raw relative point. Preserve the intended side
  -- while migrating the old default (BOTTOMLEFT -> TOP) to top center.
  if nameplateAnchorPoints[position.relativePoint] then
    return position.relativePoint
  end
  return "TOP"
end

function Anchors.ResolveNameplatePoints(position)
  local key = Anchors.GetNameplateAnchor(position)
  local mapping = nameplateAnchorPoints[key] or nameplateAnchorPoints.TOP
  return mapping.point, mapping.relativePoint, key
end

function Anchors.ApplyNameplateAnchor(position, key)
  if type(position) ~= "table" then
    return
  end
  local mapping = nameplateAnchorPoints[key] or nameplateAnchorPoints.TOP
  position.nameplateAnchor = nameplateAnchorPoints[key] and key or "TOP"
  position.point = mapping.point
  position.relativePoint = mapping.relativePoint
  position.relativeTo = "UIParent"
end
