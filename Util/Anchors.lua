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
