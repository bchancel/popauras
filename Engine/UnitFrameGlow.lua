local _, ns = ...

local UnitFrameGlow = {}
ns.UnitFrameGlow = UnitFrameGlow

local ACTION_GLOW_KEY = "PopAurasAction"
local activeGlows = {}

local function GetGlowLibrary()
  if not LibStub then
    return nil
  end
  local lib = LibStub("ArcGlow-1.0", true)
  if lib and lib.ButtonGlow_Start and lib.ButtonGlow_Stop then
    return lib
  end
  lib = LibStub("LibCustomGlow-1.0", true)
  if lib and lib.ButtonGlow_Start and lib.ButtonGlow_Stop then
    return lib
  end
  lib = LibStub("LibButtonGlow-1.0", true)
  if lib and lib.ButtonGlow_Start and lib.ButtonGlow_Stop then
    return lib
  end
  return nil
end

local function StartGlow(frame)
  local lib = GetGlowLibrary()
  if lib then
    lib.ButtonGlow_Start(frame, nil, nil, 1, ACTION_GLOW_KEY)
    frame._popAurasActionGlowLib = lib
    return true
  end
  return false
end

local function StopGlow(frame)
  local lib = frame._popAurasActionGlowLib or GetGlowLibrary()
  if lib and lib.ButtonGlow_Stop then
    lib.ButtonGlow_Stop(frame, ACTION_GLOW_KEY)
  end
  frame._popAurasActionGlowLib = nil
end

local function NormalizePlayerName(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if issecretvalue and issecretvalue(name) then
    return nil
  end
  local short = name:match("^([^%-]+)")
  if short then
    return short:lower()
  end
  return name:lower()
end

local function UnitMatchesName(unitId, targetName)
  if not UnitExists(unitId) then
    return false
  end
  local unitName = UnitName(unitId)
  if type(unitName) ~= "string" then
    return false
  end
  return NormalizePlayerName(unitName) == targetName
end

local function FindUnitIdForName(targetName)
  if not targetName then
    return nil
  end
  if UnitMatchesName("player", targetName) then
    return "player"
  end
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unitId = "raid" .. i
      if UnitMatchesName(unitId, targetName) then
        return unitId
      end
    end
  else
    for i = 1, 4 do
      local unitId = "party" .. i
      if UnitMatchesName(unitId, targetName) then
        return unitId
      end
    end
  end
  return nil
end

local function FrameMatchesUnit(frame, targetUnitId)
  if not frame or not frame.unit then
    return false
  end
  return UnitIsUnit(frame.unit, targetUnitId)
end

local function CollectChildFrames(parent, targetUnitId, results)
  if not parent or not parent.GetChildren then
    return
  end
  for _, child in pairs({ parent:GetChildren() }) do
    if child:IsVisible() and FrameMatchesUnit(child, targetUnitId) then
      results[#results + 1] = child
    end
  end
end

local function CollectChildFramesRecursive(parent, targetUnitId, results, depth)
  if not parent or not parent.GetChildren then
    return
  end
  depth = depth or 0
  if depth > 3 then
    return
  end
  for _, child in pairs({ parent:GetChildren() }) do
    if child:IsVisible() and FrameMatchesUnit(child, targetUnitId) then
      results[#results + 1] = child
    elseif child.GetChildren then
      CollectChildFramesRecursive(child, targetUnitId, results, depth + 1)
    end
  end
end

local CONTAINER_GLOBALS = {
  "CompactRaidFrameContainer",
  "CompactPartyFrame",
  "Grid2LayoutFrame",
  "Grid2Layout",
  "ElvUF_Raid",
  "ElvUF_Raid40",
  "ElvUF_Party",
  "CellMainFrame",
  "CellSoloFramePlayer",
}

local INDEXED_FRAME_PATTERNS = {
  { pattern = "CompactRaidFrame%d",        count = 80 },
  { pattern = "CompactPartyFrameMember%d",  count = 5 },
  { pattern = "Grid2LayoutFrame%dUnitButton%d", outer = 8, inner = 40 },
}

local function FindUnitFramesForUnit(targetUnitId)
  if not targetUnitId then
    return nil
  end

  local frames = {}
  local seen = {}

  for _, globalName in ipairs(CONTAINER_GLOBALS) do
    local container = _G[globalName]
    if container and type(container) == "table" and container.GetChildren then
      CollectChildFramesRecursive(container, targetUnitId, frames, 0)
    end
  end

  for _, spec in ipairs(INDEXED_FRAME_PATTERNS) do
    if spec.outer then
      for g = 1, spec.outer do
        for b = 1, spec.inner do
          local frameName = string.format(spec.pattern, g, b)
          local frame = _G[frameName]
          if frame and frame.IsVisible and frame:IsVisible() and FrameMatchesUnit(frame, targetUnitId) then
            frames[#frames + 1] = frame
          end
        end
      end
    else
      for i = 1, spec.count do
        local frameName = string.format(spec.pattern, i)
        local frame = _G[frameName]
        if frame and frame.IsVisible and frame:IsVisible() and FrameMatchesUnit(frame, targetUnitId) then
          frames[#frames + 1] = frame
        end
      end
    end
  end

  local unique = {}
  for _, frame in ipairs(frames) do
    if not seen[frame] then
      seen[frame] = true
      unique[#unique + 1] = frame
    end
  end

  if #unique == 0 then
    return nil
  end
  return unique
end

function UnitFrameGlow:Apply(targetName, auraId, duration)
  local targetUnitId = FindUnitIdForName(targetName)
  if not targetUnitId then
    return
  end

  local unitFrames = FindUnitFramesForUnit(targetUnitId)
  if not unitFrames then
    return
  end

  self:CancelForAura(auraId)

  local glowedFrames = {}
  for _, frame in ipairs(unitFrames) do
    if StartGlow(frame) then
      glowedFrames[#glowedFrames + 1] = frame
    end
  end

  if #glowedFrames == 0 then
    return
  end

  activeGlows[auraId] = glowedFrames

  if duration and duration > 0 then
    C_Timer.After(duration, function()
      self:CancelForAura(auraId)
    end)
  end
end

function UnitFrameGlow:CancelForAura(auraId)
  local frames = activeGlows[auraId]
  if not frames then
    return
  end
  for _, frame in ipairs(frames) do
    StopGlow(frame)
  end
  activeGlows[auraId] = nil
end

ns.ActionEngine:RegisterHandler("glow_unit_frame", function(action, aura, state)
  local resolved = ns.ActionEngine:ResolveTemplate(action.unit or "%n", state)
  local targetName = NormalizePlayerName(resolved)
  if not targetName then
    return
  end
  local duration = tonumber(action.duration or 0) or 0
  UnitFrameGlow:Apply(targetName, aura.id, duration)
end)
