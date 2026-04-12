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
CooldownManager.pendingVisibilityOverrideSync = false

local HookCooldownWidget

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

local function SafeBoolean(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "boolean" then
    return value
  end
  return nil
end

local function SafeGetFrameScript(node, scriptName)
  if not node or not node.GetScript then
    return nil
  end

  local ok, script = pcall(node.GetScript, node, scriptName)
  if ok then
    return script
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
  self.pendingVisibilityOverrideSync = self.pendingVisibilityOverrideSync == true
  if not self.hiddenParent then
    local parent = CreateFrame("Frame", nil, UIParent)
    parent:SetAllPoints(UIParent)
    parent:SetFrameStrata("BACKGROUND")
    parent:Hide()
    self.hiddenParent = parent
  end
  if not self.visibilityOverrideEventFrame then
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
      if self.pendingVisibilityOverrideSync == true then
        self.pendingVisibilityOverrideSync = false
        self:ApplyVisibilityOverrides()
      end
    end)
    self.visibilityOverrideEventFrame = eventFrame
  end
end

function CooldownManager:Invalidate()
  self.spellToCooldownIDCache = nil
  self.spellToCooldownIDsCache = nil
  self.spellToCooldownIDCacheSpec = nil
  self.frameCache = {}
  self.auraStateCache = {}
  self.auraFrameRefs = CreateWeakValueTable()
  self.pendingVisibilityOverrideSync = false
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

function CooldownManager:FindFramesByCooldownID(cooldownID, forceRefresh)
  cooldownID = tonumber(cooldownID or 0) or 0
  if cooldownID <= 0 then
    return {}
  end

  if forceRefresh ~= true then
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
    HookCooldownWidget(frame)
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

local function GetFrameCooldownWidget(frame)
  if not frame then
    return nil
  end

  local direct = frame.Cooldown
    or frame.cooldown
    or (frame.Icon and (frame.Icon.Cooldown or frame.Icon.cooldown))
  if direct and direct.GetCooldownTimes then
    return direct
  end

  local visited = {}
  local function findNested(owner)
    if not owner or visited[owner] then
      return nil
    end
    visited[owner] = true

    local nested = owner.Cooldown or owner.cooldown or (owner.Icon and (owner.Icon.Cooldown or owner.Icon.cooldown))
    if nested and nested.GetCooldownTimes then
      return nested
    end

    if owner.GetChildren then
      for _, child in ipairs({ owner:GetChildren() }) do
        local found = findNested(child)
        if found then
          return found
        end
      end
    end

    return nil
  end

  return findNested(frame)
end

local function GetFrameTimerBar(frame)
  if not frame then
    return nil
  end

  local direct = frame.Bar
    or frame.bar
    or (frame.Icon and (frame.Icon.Bar or frame.Icon.bar))
  if direct and direct.SetTimerDuration then
    return direct
  end

  return nil
end

local function GetFrameStoredDurationObject(frame, widget)
  local candidates = {
    frame and frame._popaurasDurationObject,
    frame and frame._arcTextColorDurObj,
    widget and widget._popaurasDurationObject,
    frame and frame.Bar and frame.Bar._popaurasDurationObject,
    frame and frame.bar and frame.bar._popaurasDurationObject,
    frame and frame.Icon and frame.Icon._popaurasDurationObject,
    frame and frame.Icon and frame.Icon._arcTextColorDurObj,
    frame and frame.Icon and frame.Icon.Bar and frame.Icon.Bar._popaurasDurationObject,
    frame and frame.Icon and frame.Icon.bar and frame.Icon.bar._popaurasDurationObject,
    frame and frame.cooldownInfo and frame.cooldownInfo.durationObject,
    frame and frame.Icon and frame.Icon.cooldownInfo and frame.Icon.cooldownInfo.durationObject,
  }

  for _, candidate in ipairs(candidates) do
    if candidate ~= nil then
      return candidate
    end
  end

  return nil
end

local function GetDurationObjectFromCooldownInfo(info)
  if type(info) ~= "table" or not C_Spell then
    return nil
  end

  local isOnActualCooldown = SafeBoolean(info.isOnActualCooldown)
  local isOnGCD = SafeBoolean(info.isOnGCD)
  if isOnActualCooldown == false or isOnGCD == true then
    return nil
  end

  local spellID = tonumber(info.overrideSpellID or info.spellID or 0) or 0
  if spellID <= 0 then
    return nil
  end

  local chargeInfo = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID) or nil
  local maxCharges = SafeNumber(chargeInfo and chargeInfo.maxCharges)
  if maxCharges and maxCharges > 1 and C_Spell.GetSpellChargeDuration then
    local ok, durationObject = pcall(C_Spell.GetSpellChargeDuration, spellID)
    if ok and durationObject ~= nil then
      return durationObject
    end
  end

  if C_Spell.GetSpellCooldownDuration then
    local ok, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    if ok and durationObject ~= nil then
      return durationObject
    end
  end

  return nil
end

HookCooldownWidget = function(frame)
  local widget = GetFrameCooldownWidget(frame)
  if widget and not widget._popaurasDurationHooked then
    widget._popaurasDurationHooked = true
    widget._popaurasOwnerFrame = frame

    if widget.SetCooldownFromDurationObject then
      hooksecurefunc(widget, "SetCooldownFromDurationObject", function(self, durationObject)
        local owner = self._popaurasOwnerFrame or frame
        if not owner or durationObject == nil then
          return
        end

        local isOnGCD = SafeBoolean(owner.isOnGCD)
        local isOnActualCooldown = SafeBoolean(owner.isOnActualCooldown)
        if isOnActualCooldown == false then
          return
        end
        if isOnGCD == true and isOnActualCooldown ~= true then
          return
        end

        owner._popaurasDurationObject = durationObject
        self._popaurasDurationObject = durationObject
      end)
    end

    if widget.Clear then
      hooksecurefunc(widget, "Clear", function(self)
        local owner = self._popaurasOwnerFrame or frame
        if owner then
          owner._popaurasDurationObject = nil
        end
        self._popaurasDurationObject = nil
      end)
    end

    if widget.SetCooldown then
      hooksecurefunc(widget, "SetCooldown", function(self, startTime, duration)
        if issecretvalue and (issecretvalue(startTime) or issecretvalue(duration)) then
          return
        end

        if type(startTime) == "number" and type(duration) == "number" and startTime == 0 and duration == 0 then
          local owner = self._popaurasOwnerFrame or frame
          if owner then
            owner._popaurasDurationObject = nil
          end
          self._popaurasDurationObject = nil
        end
      end)
    end

    if widget.HookScript then
      widget:HookScript("OnHide", function(self)
        local owner = self._popaurasOwnerFrame or frame
        if owner then
          owner._popaurasDurationObject = nil
        end
        self._popaurasDurationObject = nil
      end)
    end
  end

  local timerBar = GetFrameTimerBar(frame)
  if timerBar and not timerBar._popaurasTimerDurationHooked then
    timerBar._popaurasTimerDurationHooked = true
    timerBar._popaurasOwnerFrame = frame

    if timerBar.SetTimerDuration then
      hooksecurefunc(timerBar, "SetTimerDuration", function(self, durationObject)
        local owner = self._popaurasOwnerFrame or frame
        if not owner then
          return
        end
        owner._popaurasDurationObject = durationObject
        self._popaurasDurationObject = durationObject
      end)
    end

    if timerBar.HookScript then
      timerBar:HookScript("OnHide", function(self)
        local owner = self._popaurasOwnerFrame or frame
        if owner then
          owner._popaurasDurationObject = nil
        end
        self._popaurasDurationObject = nil
      end)
    end
  end
end

local function ResolveTimingFromLiveFrame(frame)
  local widget = GetFrameCooldownWidget(frame)
  if not widget then
    return nil, nil, false
  end

  local duration, expirationTime = ResolveTimingFromCooldownWidget(widget)
  if duration and duration > 0 and expirationTime and expirationTime > GetTime() then
    return duration, expirationTime, true
  end

  return nil, nil, false
end

local function ResolveTimingFromFrameInfo(frame)
  if not frame then
    return nil, nil
  end

  local duration, expirationTime = ResolveTimingFromTable(frame.cooldownInfo)
  if (not duration or duration <= 0) and frame.Icon and frame.Icon.cooldownInfo then
    duration, expirationTime = ResolveTimingFromTable(frame.Icon.cooldownInfo)
  end

  return duration, expirationTime
end

local GetFrameCountText

local function BuildFrameCooldownState(frame)
  if not frame then
    return nil
  end

  local widget = GetFrameCooldownWidget(frame)
  local duration, expirationTime, hasLiveWidget = ResolveTimingFromLiveFrame(frame)
  if not hasLiveWidget then
    duration, expirationTime = ResolveTimingFromFrameInfo(frame)
  end

  local isShown = frame.IsShown and frame:IsShown() or false
  local rawActive = SafeBoolean(frame.isActive) == true
    or SafeBoolean(frame.cooldownInfo and frame.cooldownInfo.isActive) == true
    or SafeBoolean(frame.Icon and frame.Icon.cooldownInfo and frame.Icon.cooldownInfo.isActive) == true
  local isOnActualCooldown = SafeBoolean(frame.isOnActualCooldown)
  if isOnActualCooldown == nil then
    isOnActualCooldown = SafeBoolean(frame.cooldownInfo and frame.cooldownInfo.isOnActualCooldown)
  end
  if isOnActualCooldown == nil then
    isOnActualCooldown = SafeBoolean(frame.Icon and frame.Icon.cooldownInfo and frame.Icon.cooldownInfo.isOnActualCooldown)
  end
  local isOnGCD = SafeBoolean(frame.isOnGCD)
  if isOnGCD == nil then
    isOnGCD = SafeBoolean(frame.cooldownInfo and frame.cooldownInfo.isOnGCD)
  end
  if isOnGCD == nil then
    isOnGCD = SafeBoolean(frame.Icon and frame.Icon.cooldownInfo and frame.Icon.cooldownInfo.isOnGCD)
  end
  local durationObject = GetFrameStoredDurationObject(frame, widget)
  if durationObject == nil and (isOnActualCooldown == true or (isOnActualCooldown == nil and rawActive and isOnGCD ~= true)) then
    durationObject = GetDurationObjectFromCooldownInfo(frame.cooldownInfo)
      or (frame.Icon and GetDurationObjectFromCooldownInfo(frame.Icon.cooldownInfo))
  end
  local numericActive = duration and expirationTime and expirationTime > GetTime() or false
  local active = numericActive
    or isOnActualCooldown == true
    or (isOnActualCooldown == nil and rawActive and isOnGCD ~= true and durationObject ~= nil)
  local countText = GetFrameCountText(frame)
  local count = tonumber(countText or "")

  return {
    frame = frame,
    duration = numericActive and duration or 0,
    expirationTime = numericActive and expirationTime or 0,
    durationObject = active and durationObject or nil,
    active = active,
    rawActive = rawActive,
    isOnActualCooldown = isOnActualCooldown == true,
    isOnGCD = isOnGCD == true,
    countText = countText,
    count = count,
    isShown = isShown,
  }
end

GetFrameCountText = function(frame)
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
    frame._popaurasDurationObject = nil
    if frame.Bar then
      frame.Bar._popaurasDurationObject = nil
    end
    if frame.bar then
      frame.bar._popaurasDurationObject = nil
    end
    if frame.Icon and frame.Icon.Bar then
      frame.Icon.Bar._popaurasDurationObject = nil
    end
    if frame.Icon and frame.Icon.bar then
      frame.Icon.bar._popaurasDurationObject = nil
    end
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
  local frames = self:FindFramesByCooldownID(cooldownID)
  local bestFrameState = nil

  for _, frame in ipairs(frames) do
    local candidate = BuildFrameCooldownState(frame)
    if candidate then
      local candidateHasCount = (candidate.countText and candidate.countText ~= "") or ((candidate.count or 0) > 0)
      local bestHasCount = bestFrameState and ((bestFrameState.countText and bestFrameState.countText ~= "") or ((bestFrameState.count or 0) > 0)) or false
      if not bestFrameState
        or (candidate.active and not bestFrameState.active)
        or (candidate.active == bestFrameState.active and candidate.rawActive and not bestFrameState.rawActive)
        or (candidate.active == bestFrameState.active and candidate.rawActive == bestFrameState.rawActive and candidateHasCount and not bestHasCount)
        or (candidate.active == bestFrameState.active and candidate.rawActive == bestFrameState.rawActive and candidateHasCount == bestHasCount and candidate.isShown and not bestFrameState.isShown)
        or (candidate.active == bestFrameState.active and candidate.rawActive == bestFrameState.rawActive and candidateHasCount == bestHasCount and candidate.isShown == bestFrameState.isShown and (candidate.expirationTime or 0) > (bestFrameState.expirationTime or 0)) then
        bestFrameState = candidate
      end
    end
  end

  local frame = bestFrameState and bestFrameState.frame or nil
  local duration = bestFrameState and bestFrameState.duration or nil
  local expirationTime = bestFrameState and bestFrameState.expirationTime or nil
  local durationObject = bestFrameState and bestFrameState.durationObject or nil

  if not duration or duration <= 0 then
    duration, expirationTime = ResolveTimingFromTable(info)
  end

  local maxDuration = nil
  if info then
    maxDuration = SafeNumber(info.duration) or SafeNumber(info.cooldownDuration)
  end
  if (not maxDuration or maxDuration <= 0) and duration and duration > 0 then
    maxDuration = duration
  end

  local active = (bestFrameState and bestFrameState.active == true)
    or (duration and expirationTime and expirationTime > GetTime())
    or false
  local countText = bestFrameState and bestFrameState.countText or GetFrameCountText(frame)
  local count = bestFrameState and bestFrameState.count or tonumber(countText or "")
  local rawActive = bestFrameState and bestFrameState.rawActive
    or SafeBoolean(info and info.isActive)
    or false

  return {
    cooldownID = cooldownID,
    frame = frame,
    info = info,
    duration = active and duration or 0,
    expirationTime = active and expirationTime or 0,
    durationObject = active and durationObject or nil,
    maxDuration = maxDuration or 0,
    active = active,
    rawActive = rawActive,
    isOnActualCooldown = bestFrameState and bestFrameState.isOnActualCooldown or false,
    isOnGCD = bestFrameState and bestFrameState.isOnGCD or false,
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
      local frame = self.auraFrameRefs[cooldownID]
      local frameState = BuildFrameCooldownState(frame)
      return {
        cooldownID = cooldownID,
        unit = unit,
        frame = frame,
        auraInstanceID = cached.auraInstanceID,
        auraData = auraData,
        duration = frameState and frameState.duration or 0,
        expirationTime = frameState and frameState.expirationTime or 0,
        durationObject = frameState and frameState.durationObject or nil,
        active = frameState and frameState.active == true or false,
        rawActive = frameState and frameState.rawActive == true or false,
        isOnActualCooldown = frameState and frameState.isOnActualCooldown == true or false,
        isOnGCD = frameState and frameState.isOnGCD == true or false,
        countText = frameState and frameState.countText or nil,
        count = frameState and frameState.count or nil,
      }
    end
  end

  for _, frame in ipairs(self:FindFramesByCooldownID(cooldownID)) do
    local auraInstanceID = GetFrameAuraInstanceID(frame)
    if auraInstanceID ~= nil then
      local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
      if auraData then
        local frameState = BuildFrameCooldownState(frame)
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
          duration = frameState and frameState.duration or 0,
          expirationTime = frameState and frameState.expirationTime or 0,
          durationObject = frameState and frameState.durationObject or nil,
          active = frameState and frameState.active == true or false,
          rawActive = frameState and frameState.rawActive == true or false,
          isOnActualCooldown = frameState and frameState.isOnActualCooldown == true or false,
          isOnGCD = frameState and frameState.isOnGCD == true or false,
          countText = frameState and frameState.countText or nil,
          count = frameState and frameState.count or nil,
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

local function ApplyForcedHiddenAlpha(frame)
  if not frame or not frame.SetAlpha or frame._popaurasApplyingHiddenAlpha then
    return
  end

  frame._popaurasApplyingHiddenAlpha = true
  pcall(frame.SetAlpha, frame, 0)
  frame._popaurasApplyingHiddenAlpha = false
end

local function EnsureHiddenAlphaHook(frame)
  if not frame or frame._popaurasHiddenAlphaHooked then
    return
  end

  frame._popaurasHiddenAlphaHooked = true

  if frame.HookScript then
    frame:HookScript("OnShow", function(self)
      if self._popaurasForceHidden == true then
        ApplyForcedHiddenAlpha(self)
      end
    end)
  end

  if frame.SetAlpha then
    hooksecurefunc(frame, "SetAlpha", function(self, alpha)
      if self._popaurasForceHidden == true and alpha ~= 0 then
        ApplyForcedHiddenAlpha(self)
      end
    end)
  end
end

function CooldownManager:ApplyHiddenFrame(record)
  if not record or not record.frame then
    return
  end

  record.alpha = record.alpha or record.frame:GetAlpha()
  record.nodes = record.nodes or {}
  if not record.nodes[record.frame] then
    record.nodes[record.frame] = {
      alpha = record.alpha,
    }
  end

  EnsureHiddenAlphaHook(record.frame)
  record.frame._popaurasForceHidden = true
  ApplyForcedHiddenAlpha(record.frame)

  if GameTooltip and GameTooltip.Hide then
    pcall(GameTooltip.Hide, GameTooltip)
  end
end

function CooldownManager:RestoreHiddenRecord(record)
  local frame = record and record.frame
  if not frame then
    return
  end

  frame._popaurasForceHidden = false
  for node, entry in pairs(record.nodes or {}) do
    if node.SetAlpha and entry.alpha ~= nil then
      pcall(node.SetAlpha, node, entry.alpha)
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

local function AddTriggerSpellCooldownIDs(self, hiddenCooldownIDs, trigger)
  if type(trigger) ~= "table" then
    return
  end

  local spellIDs = {}
  local seen = {}

  local function addSpellID(spellID)
    spellID = tonumber(spellID or 0) or 0
    if spellID > 0 and not seen[spellID] then
      seen[spellID] = true
      spellIDs[#spellIDs + 1] = spellID
    end
  end

  addSpellID(trigger.spellId)

  if type(trigger.spellIDs) == "table" then
    for _, spellID in ipairs(trigger.spellIDs) do
      addSpellID(spellID)
    end
  end

  for _, spellID in ipairs(spellIDs) do
    for _, cooldownID in ipairs(self:GetCooldownIDsForSpellID(spellID)) do
      AddHiddenCooldownID(hiddenCooldownIDs, cooldownID)
    end
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
  for _, trigger in ns.TriggerBase:IterateTriggers(aura) do
    if trigger.type == "spell_cooldown" or trigger.type == "aura" then
      AddTriggerSpellCooldownIDs(self, hiddenCooldownIDs, trigger)
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
    for _, frame in ipairs(self:FindFramesByCooldownID(cooldownID, true)) do
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
