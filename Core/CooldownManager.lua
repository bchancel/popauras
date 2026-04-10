local _, ns = ...

local CooldownManager = {}
ns.CooldownManager = CooldownManager

local function CreateWeakKeyTable()
  return setmetatable({}, { __mode = "k" })
end

local function CreateWeakValueTable()
  return setmetatable({}, { __mode = "v" })
end

local function CountEntries(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

local function ProfileStart(bucket)
  if ns.Profiler and ns.Profiler.IsEnabled and ns.Profiler:IsEnabled() then
    return ns.Profiler:Begin(bucket)
  end
  return nil
end

local function ProfileFinish(bucket, startedAt)
  if startedAt and ns.Profiler and ns.Profiler.Finish then
    ns.Profiler:Finish(bucket, startedAt)
  end
end

CooldownManager.viewerNames = {
  "BuffIconCooldownViewer",
  "BuffBarCooldownViewer",
  "EssentialCooldownViewer",
  "UtilityCooldownViewer",
}

CooldownManager.spellToCooldownIDCache = nil
CooldownManager.spellToCooldownIDsCache = nil
CooldownManager.spellToCooldownIDCacheSpec = nil
CooldownManager.frameCache = {}
CooldownManager.hiddenFrames = {}
CooldownManager.auraStateCache = {}
CooldownManager.auraFrameRefs = CreateWeakValueTable()
CooldownManager.hookedAuraFrames = CreateWeakKeyTable()
CooldownManager.pendingAuraRefreshes = {}

local function SafeNumber(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "number" then
    return value
  end
  return nil
end

local function UniqueCategoryList()
  local categories = {}
  local seen = {}

  local candidates = {
    Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff,
    Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar,
    Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Essential,
    Enum and Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Utility,
    2,
    3,
    0,
    1,
  }

  for _, value in ipairs(candidates) do
    if type(value) == "number" and value >= 0 and value <= 3 and not seen[value] then
      seen[value] = true
      categories[#categories + 1] = value
    end
  end

  return categories
end

function CooldownManager:Initialize()
  self:Invalidate()
  self:RestoreAllHiddenFrames()
  self.hookedAuraFrames = self.hookedAuraFrames or CreateWeakKeyTable()
  self.pendingAuraRefreshes = self.pendingAuraRefreshes or {}
  if not self.hiddenParent then
    local parent = CreateFrame("Frame", nil, UIParent)
    parent:SetAllPoints(UIParent)
    parent:SetFrameStrata("BACKGROUND")
    parent:Hide()
    self.hiddenParent = parent
  end
end

function CooldownManager:Invalidate()
  self.spellToCooldownIDCache = nil
  self.spellToCooldownIDsCache = nil
  self.spellToCooldownIDCacheSpec = nil
  self.frameCache = {}
  self.auraStateCache = {}
  self.auraFrameRefs = CreateWeakValueTable()
  if self.pendingAuraRefreshes then
    wipe(self.pendingAuraRefreshes)
  end
  if self.pendingRefreshFrame then
    self.pendingRefreshFrame:Hide()
  end
end

local function AddSpellCooldownMapping(mapping, multiMapping, spellID, cooldownID)
  spellID = tonumber(spellID or 0) or 0
  cooldownID = tonumber(cooldownID or 0) or 0
  if spellID <= 0 or cooldownID <= 0 then
    return
  end

  if not mapping[spellID] then
    mapping[spellID] = cooldownID
  end

  local list = multiMapping[spellID]
  if not list then
    list = {}
    multiMapping[spellID] = list
  end

  for _, existingID in ipairs(list) do
    if existingID == cooldownID then
      return
    end
  end

  list[#list + 1] = cooldownID
end

function CooldownManager:BuildSpellToCooldownIDMapping()
  local mapping = {}
  local multiMapping = {}

  if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
    return mapping, multiMapping
  end

  for _, category in ipairs(UniqueCategoryList()) do
    local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
    if cooldownIDs then
      for _, cooldownID in ipairs(cooldownIDs) do
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if info then
          local primarySpellID = tonumber(info.spellID or info.overrideSpellID or 0) or 0
          AddSpellCooldownMapping(mapping, multiMapping, primarySpellID, cooldownID)

          local linkedSpellIDs = info.linkedSpellIDs
          if type(linkedSpellIDs) == "table" then
            for _, linkedSpellID in ipairs(linkedSpellIDs) do
              AddSpellCooldownMapping(mapping, multiMapping, linkedSpellID, cooldownID)
            end
          end
        end
      end
    end
  end

  return mapping, multiMapping
end

function CooldownManager:GetSpellToCooldownIDMapping()
  local currentSpec = GetSpecialization() or 0
  if not self.spellToCooldownIDCache or self.spellToCooldownIDCacheSpec ~= currentSpec then
    self.spellToCooldownIDCache, self.spellToCooldownIDsCache = self:BuildSpellToCooldownIDMapping()
    self.spellToCooldownIDCacheSpec = currentSpec
  end
  return self.spellToCooldownIDCache
end

function CooldownManager:GetCooldownIDsForSpellID(spellID)
  spellID = tonumber(spellID or 0) or 0
  if spellID <= 0 then
    return {}
  end

  self:GetSpellToCooldownIDMapping()

  local list = self.spellToCooldownIDsCache and self.spellToCooldownIDsCache[spellID]
  if type(list) == "table" and #list > 0 then
    local result = {}
    for _, cooldownID in ipairs(list) do
      result[#result + 1] = cooldownID
    end
    return result
  end

  local single = self.spellToCooldownIDCache and self.spellToCooldownIDCache[spellID]
  return single and { single } or {}
end

function CooldownManager:FindCooldownIDForSpellID(spellID)
  spellID = tonumber(spellID or 0) or 0
  if spellID <= 0 then
    return nil
  end
  local mapping = self:GetSpellToCooldownIDMapping()
  return mapping[spellID]
end

function CooldownManager:GetCooldownInfo(cooldownID)
  if not cooldownID or cooldownID <= 0 or not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
    return nil
  end
  return C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
end

function CooldownManager:GetFrameCooldownID(frame)
  if not frame then
    return nil
  end

  local cooldownID = tonumber(frame.cooldownID or 0) or 0
  if cooldownID > 0 then
    return cooldownID
  end

  cooldownID = tonumber(frame.cooldownInfo and frame.cooldownInfo.cooldownID or 0) or 0
  if cooldownID > 0 then
    return cooldownID
  end

  if frame.Icon then
    cooldownID = tonumber(frame.Icon.cooldownID or 0) or 0
    if cooldownID > 0 then
      return cooldownID
    end
    cooldownID = tonumber(frame.Icon.cooldownInfo and frame.Icon.cooldownInfo.cooldownID or 0) or 0
    if cooldownID > 0 then
      return cooldownID
    end
  end

  return nil
end

local function CollectFramesByCooldownID(owner, cooldownID, results, visited)
  if not owner or visited[owner] then
    return
  end
  visited[owner] = true

  if CooldownManager:GetFrameCooldownID(owner) == cooldownID then
    results[#results + 1] = owner
  end

  if owner.GetChildren then
    for _, child in ipairs({ owner:GetChildren() }) do
      CollectFramesByCooldownID(child, cooldownID, results, visited)
    end
  end
end

function CooldownManager:FindFramesByCooldownID(cooldownID)
  cooldownID = tonumber(cooldownID or 0) or 0
  if cooldownID <= 0 then
    return {}
  end

  local cached = self.frameCache[cooldownID]
  if cached and #cached > 0 then
    local valid = {}
    for _, frame in ipairs(cached) do
      if self:GetFrameCooldownID(frame) == cooldownID then
        valid[#valid + 1] = frame
      end
    end
    if #valid > 0 then
      self.frameCache[cooldownID] = valid
      return valid
    end
  end

  local results = {}
  local visited = {}
  for _, viewerName in ipairs(self.viewerNames) do
    local viewer = _G[viewerName]
    if viewer then
      CollectFramesByCooldownID(viewer, cooldownID, results, visited)
    end
  end

  for _, frame in ipairs(results) do
    self:HookFrameForAuraUpdates(frame)
  end

  self.frameCache[cooldownID] = results
  return results
end

function CooldownManager:FindFrameByCooldownID(cooldownID)
  local frames = self:FindFramesByCooldownID(cooldownID)
  return frames[1]
end

local function ResolveTimingFromTable(data)
  if type(data) ~= "table" then
    return nil, nil
  end

  local duration = SafeNumber(data.duration) or SafeNumber(data.cooldownDuration)
  local startTime = SafeNumber(data.startTime) or SafeNumber(data.cooldownStartTime)
  local expirationTime = SafeNumber(data.expirationTime)

  if duration and duration > 0 then
    if expirationTime and expirationTime > 0 then
      return duration, expirationTime
    end
    if startTime and startTime > 0 then
      return duration, startTime + duration
    end
  end

  return nil, nil
end

local function ResolveTimingFromCooldownWidget(widget)
  if not widget or not widget.GetCooldownTimes then
    return nil, nil
  end

  local startMS, durationMS = widget:GetCooldownTimes()
  startMS = SafeNumber(startMS)
  durationMS = SafeNumber(durationMS)

  if startMS and durationMS and durationMS > 0 then
    local startTime = startMS / 1000
    local duration = durationMS / 1000
    if duration > 0 then
      return duration, startTime + duration
    end
  end

  return nil, nil
end

local function GetFrameCountText(frame)
  local candidates = {
    frame and frame.Count,
    frame and frame.CountText,
    frame and frame.count,
    frame and frame.countText,
    frame and frame.currentText,
    frame and frame.ApplicationText,
    frame and frame.applicationsText,
    frame and frame.Applications,
    frame and frame.ChargeCount,
    frame and frame.chargesText,
    frame and frame.StackCount,
    frame and frame.stackText,
    frame and frame.Icon and frame.Icon.Count,
    frame and frame.Icon and frame.Icon.CountText,
    frame and frame.Icon and frame.Icon.count,
    frame and frame.Icon and frame.Icon.countText,
    frame and frame.Icon and frame.Icon.currentText,
    frame and frame.Icon and frame.Icon.ApplicationText,
    frame and frame.Icon and frame.Icon.applicationsText,
    frame and frame.Icon and frame.Icon.Applications,
    frame and frame.Icon and frame.Icon.ChargeCount,
    frame and frame.Icon and frame.Icon.chargesText,
    frame and frame.Icon and frame.Icon.StackCount,
    frame and frame.Icon and frame.Icon.stackText,
  }

  for _, widget in ipairs(candidates) do
    if widget and widget.GetText then
      local text = widget:GetText()
      if text ~= nil and text ~= "" then
        return tostring(text)
      end
    end
  end

  return nil
end

local function GetFrameAuraInstanceID(frame)
  if not frame then
    return nil
  end

  local auraInstanceID = frame.auraInstanceID
  if auraInstanceID ~= nil then
    return auraInstanceID
  end

  if frame.cooldownInfo and frame.cooldownInfo.auraInstanceID ~= nil then
    return frame.cooldownInfo.auraInstanceID
  end

  if frame.Icon then
    if frame.Icon.auraInstanceID ~= nil then
      return frame.Icon.auraInstanceID
    end
    if frame.Icon.cooldownInfo and frame.Icon.cooldownInfo.auraInstanceID ~= nil then
      return frame.Icon.cooldownInfo.auraInstanceID
    end
  end

  return nil
end

function CooldownManager:UpdateCachedAuraStateFromFrame(frame)
  local cooldownID = self:GetFrameCooldownID(frame)
  if not cooldownID or cooldownID <= 0 then
    return false
  end

  local previousState = self.auraStateCache[cooldownID]
  local auraInstanceID = GetFrameAuraInstanceID(frame)
  local countText = GetFrameCountText(frame)
  if auraInstanceID ~= nil then
    local changed = previousState == nil
      or previousState.auraInstanceID ~= auraInstanceID
      or previousState.countText ~= countText

    self.auraStateCache[cooldownID] = {
      auraInstanceID = auraInstanceID,
      countText = countText,
    }
    self.auraFrameRefs[cooldownID] = frame
    return changed
  else
    local changed = previousState ~= nil
    self.auraStateCache[cooldownID] = nil
    self.auraFrameRefs[cooldownID] = nil
    return changed
  end
end

function CooldownManager:EnsurePendingRefreshDriver()
  if self.pendingRefreshFrame then
    return
  end

  local frame = CreateFrame("Frame")
  frame:Hide()
  frame:SetScript("OnUpdate", function(driver)
    driver:Hide()

    local auraIds = {}
    for auraId in pairs(self.pendingAuraRefreshes) do
      auraIds[#auraIds + 1] = auraId
      self.pendingAuraRefreshes[auraId] = nil
    end

    if #auraIds == 0 then
      return
    end

    local flushProfile = ProfileStart("cdm:flush_refresh")
    if ns.runtime and ns.runtime.RefreshAuras then
      ns.runtime:RefreshAuras(auraIds)
    end
    ProfileFinish("cdm:flush_refresh", flushProfile)
  end)

  self.pendingRefreshFrame = frame
end

function CooldownManager:QueueAffectedAuraRefreshes(auraIds)
  if type(auraIds) ~= "table" or #auraIds == 0 then
    return
  end

  self:EnsurePendingRefreshDriver()
  for _, auraId in ipairs(auraIds) do
    if auraId then
      self.pendingAuraRefreshes[auraId] = true
    end
  end

  if self.pendingRefreshFrame then
    self.pendingRefreshFrame:Show()
  end
end

local function AddUniqueAuraIds(results, seen, auraIds)
  if type(auraIds) ~= "table" then
    return
  end

  for _, auraId in ipairs(auraIds) do
    if auraId and not seen[auraId] then
      seen[auraId] = true
      results[#results + 1] = auraId
    end
  end
end

local function CollectSpellIDsFromCooldownInfo(info)
  local results = {}
  local seen = {}

  local function addSpellID(spellID)
    spellID = tonumber(spellID or 0) or 0
    if spellID > 0 and not seen[spellID] then
      seen[spellID] = true
      results[#results + 1] = spellID
    end
  end

  if type(info) ~= "table" then
    return results
  end

  addSpellID(info.spellID)
  addSpellID(info.overrideSpellID)

  for _, linkedSpellID in ipairs(info.linkedSpellIDs or {}) do
    addSpellID(linkedSpellID)
  end

  return results
end

function CooldownManager:GetAffectedAurasForCooldownID(cooldownID)
  local info = self:GetCooldownInfo(cooldownID)
  local spellIDs = CollectSpellIDsFromCooldownInfo(info)
  if #spellIDs == 0 then
    return nil
  end

  local results = {}
  local seen = {}
  local spellProvider = ns.providers and ns.providers.spell_cooldown or nil
  local auraProvider = ns.providers and ns.providers.aura or nil

  if spellProvider and spellProvider.GetAffectedAurasForSpellIDs then
    AddUniqueAuraIds(results, seen, spellProvider:GetAffectedAurasForSpellIDs(spellIDs))
  end
  if auraProvider and auraProvider.GetAffectedAurasForSpellIDs then
    AddUniqueAuraIds(results, seen, auraProvider:GetAffectedAurasForSpellIDs(spellIDs))
  end

  return #results > 0 and results or nil
end

function CooldownManager:HookFrameForAuraUpdates(frame)
  if not frame or self.hookedAuraFrames[frame] then
    return
  end
  self.hookedAuraFrames[frame] = true

  local function HandleAuraFrameUpdate(updatedFrame)
    local hookProfile = ProfileStart("cdm:hook_update")
    local changed = CooldownManager:UpdateCachedAuraStateFromFrame(updatedFrame)
    if not changed then
      ProfileFinish("cdm:hook_update", hookProfile)
      return
    end

    if ns.runtime then
      local affectedAuraIds = CooldownManager:GetAffectedAurasForCooldownID(CooldownManager:GetFrameCooldownID(updatedFrame))
      if type(affectedAuraIds) == "table" and #affectedAuraIds > 0 then
        CooldownManager:QueueAffectedAuraRefreshes(affectedAuraIds)
      end
    end
    ProfileFinish("cdm:hook_update", hookProfile)
  end

  if frame.SetAuraInstanceInfo then
    hooksecurefunc(frame, "SetAuraInstanceInfo", HandleAuraFrameUpdate)
  end
  if frame.ClearAuraInstanceInfo then
    hooksecurefunc(frame, "ClearAuraInstanceInfo", HandleAuraFrameUpdate)
  end

  if frame.Icon then
    if frame.Icon.SetAuraInstanceInfo then
      hooksecurefunc(frame.Icon, "SetAuraInstanceInfo", HandleAuraFrameUpdate)
    end
    if frame.Icon.ClearAuraInstanceInfo then
      hooksecurefunc(frame.Icon, "ClearAuraInstanceInfo", HandleAuraFrameUpdate)
    end
  end

  self:UpdateCachedAuraStateFromFrame(frame)
end

function CooldownManager:GetCooldownStateForCooldownID(cooldownID)
  cooldownID = tonumber(cooldownID or 0) or 0
  if cooldownID <= 0 then
    return nil
  end
  local info = self:GetCooldownInfo(cooldownID)
  local frame = self:FindFrameByCooldownID(cooldownID)
  local duration, expirationTime = ResolveTimingFromTable(info)

  if (not duration or duration <= 0) and frame and frame.cooldownInfo then
    duration, expirationTime = ResolveTimingFromTable(frame.cooldownInfo)
  end

  if (not duration or duration <= 0) and frame then
    duration, expirationTime = ResolveTimingFromCooldownWidget(frame.Cooldown or frame.cooldown)
  end

  local maxDuration = nil
  if info then
    maxDuration = SafeNumber(info.duration) or SafeNumber(info.cooldownDuration)
  end
  if (not maxDuration or maxDuration <= 0) and duration and duration > 0 then
    maxDuration = duration
  end

  local active = duration and expirationTime and expirationTime > GetTime() or false
  local countText = GetFrameCountText(frame)
  local count = tonumber(countText or "")

  return {
    cooldownID = cooldownID,
    frame = frame,
    info = info,
    duration = active and duration or 0,
    expirationTime = active and expirationTime or 0,
    maxDuration = maxDuration or 0,
    active = active,
    count = count,
    countText = countText,
  }
end

function CooldownManager:GetCooldownStateForSpell(spellID)
  local bestState = nil

  for _, cooldownID in ipairs(self:GetCooldownIDsForSpellID(spellID)) do
    local state = self:GetCooldownStateForCooldownID(cooldownID)
    if state then
      local stateHasCount = (state.countText and state.countText ~= "") or ((state.count or 0) > 0)
      local bestHasCount = bestState and ((bestState.countText and bestState.countText ~= "") or ((bestState.count or 0) > 0)) or false
      if not bestState
        or (state.active and not bestState.active)
        or (state.active == bestState.active and stateHasCount and not bestHasCount)
        or (state.active == bestState.active and stateHasCount == bestHasCount and (state.expirationTime or 0) > (bestState.expirationTime or 0))
        or (state.active == bestState.active and stateHasCount == bestHasCount and (state.expirationTime or 0) == (bestState.expirationTime or 0) and (state.maxDuration or 0) > (bestState.maxDuration or 0)) then
        bestState = state
      end
    end
  end

  return bestState
end

local function BuildAuraStateForCooldownID(self, cooldownID, unit)
  local cached = self.auraStateCache[cooldownID]
  if cached and cached.auraInstanceID ~= nil then
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, cached.auraInstanceID)
    if auraData then
      return {
        cooldownID = cooldownID,
        unit = unit,
        frame = self.auraFrameRefs[cooldownID],
        auraInstanceID = cached.auraInstanceID,
        auraData = auraData,
      }
    end
  end

  for _, frame in ipairs(self:FindFramesByCooldownID(cooldownID)) do
    local auraInstanceID = GetFrameAuraInstanceID(frame)
    if auraInstanceID ~= nil then
      local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
      if auraData then
        self.auraStateCache[cooldownID] = {
          auraInstanceID = auraInstanceID,
        }
        self.auraFrameRefs[cooldownID] = frame
        return {
          cooldownID = cooldownID,
          unit = unit,
          frame = frame,
          auraInstanceID = auraInstanceID,
          auraData = auraData,
        }
      end
    end
  end

  return nil
end

local function ScoreAuraState(entry)
  if not entry or type(entry.auraData) ~= "table" then
    return -1
  end

  local auraData = entry.auraData
  local applications = SafeNumber(auraData.applications) or SafeNumber(auraData.charges) or 0
  local expirationTime = SafeNumber(auraData.expirationTime) or 0
  local duration = SafeNumber(auraData.duration) or 0
  local score = 0

  if applications > 0 then
    score = score + 10 + applications
  end
  if expirationTime > GetTime() then
    score = score + 5
  end
  if duration > 0 then
    score = score + 2
  end

  return score
end

function CooldownManager:GetAuraStateForSpell(spellID, unit)
  spellID = tonumber(spellID or 0) or 0
  if spellID <= 0 or not unit or not C_UnitAuras or not C_UnitAuras.GetAuraDataByAuraInstanceID then
    return nil
  end

  local bestState = nil
  local bestScore = -1

  for _, cooldownID in ipairs(self:GetCooldownIDsForSpellID(spellID)) do
    local state = BuildAuraStateForCooldownID(self, cooldownID, unit)
    if state then
      local score = ScoreAuraState(state)
      if not bestState or score > bestScore then
        bestState = state
        bestScore = score
      end
    end
  end

  return bestState
end

function CooldownManager:GetCacheStats()
  return {
    frameCacheEntries = CountEntries(self.frameCache),
    auraStateEntries = CountEntries(self.auraStateCache),
    hookedFrameEntries = CountEntries(self.hookedAuraFrames),
  }
end

local function ForEachFrameTree(root, callback, visited)
  if not root then
    return
  end
  visited = visited or {}
  if visited[root] then
    return
  end
  visited[root] = true
  callback(root)
  if root.GetChildren then
    for _, child in ipairs({ root:GetChildren() }) do
      ForEachFrameTree(child, callback, visited)
    end
  end
end

function CooldownManager:ApplyHiddenFrame(record)
  if not record or not record.frame then
    return
  end

  record.alpha = record.alpha or record.frame:GetAlpha()
  record.wasShown = record.wasShown == nil and record.frame:IsShown() or record.wasShown
  record.nodes = record.nodes or {}
  if not record.points and record.frame.GetNumPoints and record.frame.GetPoint then
    record.points = {}
    local pointCount = record.frame:GetNumPoints() or 0
    for index = 1, pointCount do
      local point, relativeTo, relativePoint, xOfs, yOfs = record.frame:GetPoint(index)
      record.points[#record.points + 1] = { point, relativeTo, relativePoint, xOfs, yOfs }
    end
  end
  if record.width == nil and record.frame.GetWidth then
    record.width = record.frame:GetWidth()
  end
  if record.height == nil and record.frame.GetHeight then
    record.height = record.frame:GetHeight()
  end
  if record.parent == nil and record.frame.GetParent then
    record.parent = record.frame:GetParent()
  end

  ForEachFrameTree(record.frame, function(node)
    if not record.nodes[node] then
      local entry = {
        alpha = node.GetAlpha and node:GetAlpha() or nil,
        wasShown = node.IsShown and node:IsShown() or nil,
      }
      if node.IsMouseEnabled then
        entry.mouseEnabled = node:IsMouseEnabled()
      end
      if node.GetScript then
        entry.onEnter = node:GetScript("OnEnter")
        entry.onLeave = node:GetScript("OnLeave")
        entry.onMotion = node:GetScript("OnMouseMotion")
      end
      record.nodes[node] = entry
    end

    if node.EnableMouse then
      pcall(node.EnableMouse, node, false)
    end
    if node.SetMouseMotionEnabled then
      pcall(node.SetMouseMotionEnabled, node, false)
    end
    if node.SetScript then
      pcall(node.SetScript, node, "OnEnter", nil)
      pcall(node.SetScript, node, "OnLeave", nil)
      pcall(node.SetScript, node, "OnMouseMotion", nil)
    end
    if node.SetAlpha then
      pcall(node.SetAlpha, node, 0)
    end
    if node.Hide then
      pcall(node.Hide, node)
    end
  end)

  if record.frame.SetPropagateMouseMotion then
    pcall(record.frame.SetPropagateMouseMotion, record.frame, false)
  end
  if GameTooltip and GameTooltip.Hide then
    pcall(GameTooltip.Hide, GameTooltip)
  end
  if self.hiddenParent and record.frame.SetParent then
    pcall(record.frame.SetParent, record.frame, self.hiddenParent)
  end
  if record.frame.ClearAllPoints then
    pcall(record.frame.ClearAllPoints, record.frame)
  end
  if record.frame.SetPoint then
    pcall(record.frame.SetPoint, record.frame, "TOPLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
  end
  if record.frame.SetSize then
    pcall(record.frame.SetSize, record.frame, 1, 1)
  end
end

function CooldownManager:RestoreHiddenRecord(record)
  local frame = record and record.frame
  if not frame then
    return
  end

  if frame.ClearAllPoints then
    pcall(frame.ClearAllPoints, frame)
  end
  if frame.SetParent and record.parent then
    pcall(frame.SetParent, frame, record.parent)
  end
  if record.points and #record.points > 0 and frame.SetPoint then
    for _, pointData in ipairs(record.points) do
      pcall(frame.SetPoint, frame, pointData[1], pointData[2], pointData[3], pointData[4], pointData[5])
    end
  end
  if frame.SetSize and record.width and record.height then
    pcall(frame.SetSize, frame, record.width, record.height)
  end
  for node, entry in pairs(record.nodes or {}) do
    if node.SetAlpha and entry.alpha ~= nil then
      pcall(node.SetAlpha, node, entry.alpha)
    end
    if node.EnableMouse and entry.mouseEnabled ~= nil then
      pcall(node.EnableMouse, node, entry.mouseEnabled)
    end
    if node.SetMouseMotionEnabled then
      pcall(node.SetMouseMotionEnabled, node, entry.mouseEnabled == true)
    end
    if node.SetScript then
      pcall(node.SetScript, node, "OnEnter", entry.onEnter)
      pcall(node.SetScript, node, "OnLeave", entry.onLeave)
      pcall(node.SetScript, node, "OnMouseMotion", entry.onMotion)
    end
    if entry.wasShown and node.Show then
      pcall(node.Show, node)
    end
  end
end

function CooldownManager:RestoreHiddenFrames(cooldownID)
  local records = self.hiddenFrames[cooldownID]
  if not records then
    return
  end

  for _, record in ipairs(records) do
    self:RestoreHiddenRecord(record)
  end

  self.hiddenFrames[cooldownID] = nil
end

function CooldownManager:RestoreAllHiddenFrames()
  for cooldownID in pairs(self.hiddenFrames) do
    self:RestoreHiddenFrames(cooldownID)
  end
end

local function AddHiddenCooldownID(hiddenCooldownIDs, cooldownID)
  cooldownID = tonumber(cooldownID or 0) or 0
  if cooldownID > 0 then
    hiddenCooldownIDs[cooldownID] = true
  end
end

function CooldownManager:GetHiddenCooldownIDsForAura(aura)
  if not aura or not aura.display or aura.display.hideCDMIcon ~= true then
    return nil
  end
  if not ns.runtime or not ns.runtime.GetState then
    return nil
  end

  local state = ns.runtime:GetState(aura.id)
  if not state or state.show ~= true then
    return nil
  end

  local hiddenCooldownIDs = {}
  for trigger in ns.TriggerBase:IterateTriggers(aura) do
    local spellID = 0
    if trigger.type == "spell_cooldown" or trigger.type == "aura" then
      spellID = tonumber(trigger.spellId or 0) or 0
    end

    if spellID > 0 then
      for _, cooldownID in ipairs(self:GetCooldownIDsForSpellID(spellID)) do
        AddHiddenCooldownID(hiddenCooldownIDs, cooldownID)
      end
    end
  end

  return next(hiddenCooldownIDs) and hiddenCooldownIDs or nil
end

function CooldownManager:ApplyVisibilityOverrides()
  local desiredByCooldownID = {}

  if ns.Registry and ns.Registry.GetFlatOrder then
    for _, auraId in ipairs(ns.Registry:GetFlatOrder()) do
      local aura = ns.Registry:GetAura(auraId)
      local hiddenCooldownIDs = self:GetHiddenCooldownIDsForAura(aura)
      if hiddenCooldownIDs then
        for cooldownID in pairs(hiddenCooldownIDs) do
          desiredByCooldownID[cooldownID] = true
        end
      end
    end
  end

  for cooldownID in pairs(self.hiddenFrames) do
    if not desiredByCooldownID[cooldownID] then
      self:RestoreHiddenFrames(cooldownID)
    end
  end

  for cooldownID in pairs(desiredByCooldownID) do
    local existingRecords = self.hiddenFrames[cooldownID] or {}
    local existingByFrame = {}
    for _, record in ipairs(existingRecords) do
      if record and record.frame then
        existingByFrame[record.frame] = record
      end
    end

    local updatedRecords = {}
    for _, frame in ipairs(self:FindFramesByCooldownID(cooldownID)) do
      local record = existingByFrame[frame]
      if not record then
        record = { frame = frame }
        self:ApplyHiddenFrame(record)
      end
      updatedRecords[#updatedRecords + 1] = record
      existingByFrame[frame] = nil
    end

    for _, record in pairs(existingByFrame) do
      self:RestoreHiddenRecord(record)
    end

    self.hiddenFrames[cooldownID] = #updatedRecords > 0 and updatedRecords or nil
  end
end
