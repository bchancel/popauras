local _, ns = ...

local Layouts = {}
ns.renderers.Layouts = Layouts

local function GetChildNudge(region)
  if not region or not region.frame or not region.frame.auraId then
    return 0, 0
  end

  local aura = ns.Registry and ns.Registry.GetAura and ns.Registry:GetAura(region.frame.auraId) or nil
  if not aura or not aura.parentId then
    return 0, 0
  end

  local position = aura.position or {}
  return tonumber(position.x or 0) or 0, tonumber(position.y or 0) or 0
end

function Layouts.ApplyGroupLayout(aura, frame, childRegions)
  local spacing = aura.display.spacing or 6
  local growth = aura.display.growth or "DOWN"
  local targetWidth = aura.position.width or aura.display.width or frame:GetWidth() or 200
  local targetHeight = aura.position.height or aura.display.height or frame:GetHeight() or 32
  local entries = {}
  local visibleCount = 0
  local naturalPrimarySize = 0

  for _, region in ipairs(childRegions) do
    local layoutVisible = region and region.layoutVisible
    if layoutVisible == nil and region and region.frame then
      layoutVisible = region.frame:IsShown()
    end
    if region and region.frame and layoutVisible then
      local regionWidth = region.frame:GetWidth() or targetWidth
      local regionHeight = region.frame:GetHeight() or targetHeight
      local nudgeX, nudgeY = GetChildNudge(region)
      visibleCount = visibleCount + 1
      entries[#entries + 1] = {
        region = region,
        width = regionWidth,
        height = regionHeight,
        nudgeX = nudgeX,
        nudgeY = nudgeY,
      }
      if growth == "RIGHT" or growth == "LEFT" then
        naturalPrimarySize = naturalPrimarySize + regionWidth
      else
        naturalPrimarySize = naturalPrimarySize + regionHeight
      end
    end
  end

  if visibleCount > 1 then
    naturalPrimarySize = naturalPrimarySize + (visibleCount - 1) * spacing
  end

  local cursor = 0
  local minLeft = 0
  local minTop = 0
  local maxRight = 0
  local maxBottom = 0

  for _, entry in ipairs(entries) do
    local left
    local top

    if growth == "DOWN" then
      left = entry.nudgeX
      top = cursor - entry.nudgeY
      cursor = cursor + entry.height + spacing
    elseif growth == "UP" then
      left = entry.nudgeX
      top = (naturalPrimarySize - cursor - entry.height) - entry.nudgeY
      cursor = cursor + entry.height + spacing
    elseif growth == "LEFT" then
      left = (naturalPrimarySize - cursor - entry.width) + entry.nudgeX
      top = -entry.nudgeY
      cursor = cursor + entry.width + spacing
    else
      left = cursor + entry.nudgeX
      top = -entry.nudgeY
      cursor = cursor + entry.width + spacing
    end

    entry.left = left
    entry.top = top
    entry.right = left + entry.width
    entry.bottom = top + entry.height

    minLeft = math.min(minLeft, entry.left)
    minTop = math.min(minTop, entry.top)
    maxRight = math.max(maxRight, entry.right)
    maxBottom = math.max(maxBottom, entry.bottom)
  end

  local shiftX = minLeft < 0 and -minLeft or 0
  local shiftY = minTop < 0 and -minTop or 0

  for _, entry in ipairs(entries) do
    entry.region.frame:ClearAllPoints()
    entry.region.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.left + shiftX, -(entry.top + shiftY))
  end

  local requiredWidth = math.max(targetWidth, maxRight + shiftX, 20)
  local requiredHeight = math.max(targetHeight, maxBottom + shiftY, 20)
  frame:SetSize(requiredWidth, requiredHeight)
end
