local _, ns = ...

local UnitFrameGlow = {}
ns.UnitFrameGlow = UnitFrameGlow

local ACTION_GLOW_KEY = "PopAurasAction"
local activeGlows = {}
local frameCache = {}
local FRAME_CACHE_TTL = 1.0

local function IsAuraDebugEnabled(aura)
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

local function DebugLogAction(aura, message)
  if not IsAuraDebugEnabled(aura) then
    return
  end
  if ns.Debug and ns.Debug.Log then
    ns.Debug:Log("GlowAction", string.format("%s: %s", tostring(aura and aura.name or "Unknown Aura"), tostring(message or "")))
  end
end

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
  if not frame then
    return false
  end

  local frameUnit = frame.unit
  if not frameUnit and frame.displayedUnit then
    frameUnit = frame.displayedUnit
  end
  if not frameUnit and frame.unitToken then
    frameUnit = frame.unitToken
  end
  if not frameUnit and frame.GetUnit then
    frameUnit = frame:GetUnit()
  end
  if not frameUnit and frame.GetAttribute then
    frameUnit = frame:GetAttribute("unit")
  end
  if type(frameUnit) ~= "string" or frameUnit == "" then
    return false
  end
  return UnitIsUnit(frameUnit, targetUnitId)
end

local function SafeFrameMatchesUnit(frame, targetUnitId)
  local ok, matches = pcall(FrameMatchesUnit, frame, targetUnitId)
  return ok and matches == true
end

local function IsFrameUsable(frame)
  if type(frame) ~= "table" then
    return false
  end

  local okShown, isShown = pcall(function()
    return frame.IsShown and frame:IsShown()
  end)
  if okShown and isShown == false then
    return false
  end

  local okVisible, isVisible = pcall(function()
    return frame.IsVisible and frame:IsVisible()
  end)
  if okVisible and isVisible == false then
    return false
  end

  return true
end

local function CloneFrameList(frames)
  local copy = {}
  for index, frame in ipairs(frames or {}) do
    copy[index] = frame
  end
  return copy
end

local function GetFrameCacheKey(targetUnitId)
  return tostring(targetUnitId or "")
end

local function GetCachedFrames(targetUnitId)
  local cacheKey = GetFrameCacheKey(targetUnitId)
  local cached = frameCache[cacheKey]
  local now = GetTime()
  if not cached or type(cached) ~= "table" or (cached.expiresAt or 0) <= now then
    frameCache[cacheKey] = nil
    return nil
  end

  local valid = {}
  for _, frame in ipairs(cached.frames or {}) do
    if IsFrameUsable(frame) and SafeFrameMatchesUnit(frame, targetUnitId) then
      valid[#valid + 1] = frame
    end
  end

  if #valid == 0 then
    frameCache[cacheKey] = nil
    return nil
  end

  cached.frames = valid
  cached.expiresAt = now + FRAME_CACHE_TTL
  return CloneFrameList(valid)
end

local function SetCachedFrames(targetUnitId, frames)
  local cacheKey = GetFrameCacheKey(targetUnitId)
  if not cacheKey or cacheKey == "" or type(frames) ~= "table" or #frames == 0 then
    frameCache[cacheKey] = nil
    return
  end

  frameCache[cacheKey] = {
    frames = CloneFrameList(frames),
    expiresAt = GetTime() + FRAME_CACHE_TTL,
  }
end

local function CollectChildFramesRecursive(parent, targetUnitId, results, depth)
  -- UIParent has thousands of descendants. Calling GetChildren() on it can
  -- overflow WoW's Lua C stack before Lua receives the returned values.
  if not parent or parent == UIParent or not parent.GetChildren then
    return
  end
  depth = depth or 0
  if depth > 3 then
    return
  end
  for _, child in pairs({ parent:GetChildren() }) do
    if IsFrameUsable(child) and SafeFrameMatchesUnit(child, targetUnitId) then
      results[#results + 1] = child
    elseif child.GetChildren then
      CollectChildFramesRecursive(child, targetUnitId, results, depth + 1)
    end
  end
end

local function AddMatchingFrame(frame, targetUnitId, results)
  if IsFrameUsable(frame) and SafeFrameMatchesUnit(frame, targetUnitId) then
    results[#results + 1] = frame
  end
end

local function CollectBlizzardUnitFrames(targetUnitId, results)
  -- The default party UI owns its member frames through a frame pool.
  local partyFrame = _G.PartyFrame
  local partyPool = partyFrame and partyFrame.PartyMemberFramePool
  if partyPool and partyPool.EnumerateActive then
    pcall(function()
      for memberFrame in partyPool:EnumerateActive() do
        AddMatchingFrame(memberFrame, targetUnitId, results)
      end
    end)
  end

  -- Raid-style party frames expose their fixed member collections directly.
  local compactPartyFrame = _G.CompactPartyFrame
  if compactPartyFrame then
    for _, memberFrame in ipairs(compactPartyFrame.memberUnitFrames or {}) do
      AddMatchingFrame(memberFrame, targetUnitId, results)
    end
    for _, petFrame in ipairs(compactPartyFrame.petUnitFrames or {}) do
      AddMatchingFrame(petFrame, targetUnitId, results)
    end
  end

  -- The compact raid container already owns traversal of its pooled/grouped
  -- frames. Its callback path avoids GetChildren() and follows frame reuse.
  local raidContainer = _G.CompactRaidFrameContainer
  if raidContainer and raidContainer.ApplyToFrames then
    pcall(raidContainer.ApplyToFrames, raidContainer, "all", function(unitFrame)
      AddMatchingFrame(unitFrame, targetUnitId, results)
    end)
  end
end

local CONTAINER_GLOBALS = {
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

  local cached = GetCachedFrames(targetUnitId)
  if cached then
    return cached
  end

  local frames = {}

  CollectBlizzardUnitFrames(targetUnitId, frames)

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
          if IsFrameUsable(frame) and SafeFrameMatchesUnit(frame, targetUnitId) then
            frames[#frames + 1] = frame
          end
        end
      end
    else
      for i = 1, spec.count do
        local frameName = string.format(spec.pattern, i)
        local frame = _G[frameName]
        if IsFrameUsable(frame) and SafeFrameMatchesUnit(frame, targetUnitId) then
          frames[#frames + 1] = frame
        end
      end
    end
  end

  local unique = {}
  local uniqueSeen = {}
  for _, frame in ipairs(frames) do
    if not uniqueSeen[frame] then
      uniqueSeen[frame] = true
      unique[#unique + 1] = frame
    end
  end

  if #unique == 0 then
    return nil
  end
  SetCachedFrames(targetUnitId, unique)
  return unique
end

local function GetFrameDebugName(frame)
  if not frame then
    return "nil"
  end
  local name = frame.GetName and frame:GetName() or nil
  if name and name ~= "" then
    return name
  end
  local objectType = frame.GetObjectType and frame:GetObjectType() or "Frame"
  return string.format("<%s>", tostring(objectType))
end

function UnitFrameGlow:FindUnitFramesForUnit(unitId)
  return FindUnitFramesForUnit(unitId)
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

function UnitFrameGlow:ApplyByUnit(targetUnitId, auraId, duration)
  if not targetUnitId or not UnitExists(targetUnitId) then
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

function UnitFrameGlow:ApplyByUnits(targetUnitIds, auraId, duration)
  if type(targetUnitIds) ~= "table" or #targetUnitIds == 0 then
    return
  end

  self:CancelForAura(auraId)

  local seenFrames = {}
  local glowedFrames = {}
  for _, unitId in ipairs(targetUnitIds) do
    if type(unitId) == "string" and unitId ~= "" and UnitExists(unitId) then
      local unitFrames = FindUnitFramesForUnit(unitId)
      for _, frame in ipairs(unitFrames or {}) do
        if not seenFrames[frame] and StartGlow(frame) then
          seenFrames[frame] = true
          glowedFrames[#glowedFrames + 1] = frame
        end
      end
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

ns.ActionEngine:RegisterHandler("glow_unit_frame", function(action, aura, state)
  local template = action.unit or "%n"
  local resolved = ns.ActionEngine:ResolveTemplate(template, state)
  local targetName = NormalizePlayerName(resolved)
  local duration = tonumber(action.duration or 0) or 0

  if type(state and state.matchedUnits) == "table" and #state.matchedUnits > 0 then
    DebugLogAction(aura, string.format("matchedUnits=%d duration=%.2f", #state.matchedUnits, duration))
    UnitFrameGlow:ApplyByUnits(state.matchedUnits, aura.id, duration)
    local active = activeGlows[aura.id]
    DebugLogAction(aura, string.format("glowApplied matchedUnits activeFrames=%d", active and #active or 0))
    return
  end

  if targetName then
    local unitId = FindUnitIdForName(targetName)
    DebugLogAction(aura, string.format("resolvedTarget=%s normalized=%s unitId=%s duration=%.2f", tostring(resolved or ""), tostring(targetName or ""), tostring(unitId or ""), duration))
    if unitId then
      local unitFrames = FindUnitFramesForUnit(unitId)
      if not unitFrames or #unitFrames == 0 then
        DebugLogAction(aura, string.format("noFramesFound unitId=%s", tostring(unitId)))
      else
        local names = {}
        for index, frame in ipairs(unitFrames) do
          names[#names + 1] = GetFrameDebugName(frame)
          if index >= 6 then
            break
          end
        end
        DebugLogAction(aura, string.format("framesFound unitId=%s count=%d frames=%s", tostring(unitId), #unitFrames, table.concat(names, ", ")))
      end
      UnitFrameGlow:ApplyByUnit(unitId, aura.id, duration)
      local active = activeGlows[aura.id]
      DebugLogAction(aura, string.format("glowApplied unitId=%s activeFrames=%d", tostring(unitId), active and #active or 0))
      return
    end
  end

  local stateUnit = state and state.unit
  if stateUnit and type(stateUnit) == "string" and UnitExists(stateUnit) then
    DebugLogAction(aura, string.format("fallbackStateUnit=%s duration=%.2f", tostring(stateUnit), duration))
    local unitFrames = FindUnitFramesForUnit(stateUnit)
    if not unitFrames or #unitFrames == 0 then
      DebugLogAction(aura, string.format("noFramesFound unitId=%s", tostring(stateUnit)))
    else
      local names = {}
      for index, frame in ipairs(unitFrames) do
        names[#names + 1] = GetFrameDebugName(frame)
        if index >= 6 then
          break
        end
      end
      DebugLogAction(aura, string.format("framesFound unitId=%s count=%d frames=%s", tostring(stateUnit), #unitFrames, table.concat(names, ", ")))
    end
    UnitFrameGlow:ApplyByUnit(stateUnit, aura.id, duration)
    local active = activeGlows[aura.id]
    DebugLogAction(aura, string.format("glowApplied unitId=%s activeFrames=%d", tostring(stateUnit), active and #active or 0))
    return
  end

  DebugLogAction(aura, string.format("failedToResolveTarget template=%s resolved=%s stateUnit=%s", tostring(template or ""), tostring(resolved or ""), tostring(stateUnit or "")))
end)
