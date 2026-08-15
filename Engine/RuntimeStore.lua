local _, ns = ...

local RuntimeStore = {}
ns.runtime = RuntimeStore
local EMPTY = {}

RuntimeStore.states = {}
RuntimeStore.presentations = {}
RuntimeStore.regions = {}
RuntimeStore.activationOrder = {}
RuntimeStore.activationCounter = 0
RuntimeStore.timedRegions = {}
RuntimeStore.timedStateAuras = {}
RuntimeStore.timerElapsed = 0
RuntimeStore.missingRegionsDirty = true
RuntimeStore.managerSyncFingerprints = {}
RuntimeStore.nativeAuraRegionsByUnit = {}
RuntimeStore.nativeAuraUnitByRegion = setmetatable({}, { __mode = "k" })

local TIMED_UPDATE_INTERVAL = 0.05

local function IsGroupAura(aura)
  return aura and (aura.kind == "group" or aura.kind == "dynamic_group")
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

local function IsAuraInSelectedGroup(auraId, selectedAuraId)
  if not auraId or not selectedAuraId then
    return false
  end

  local cursor = ns.Registry:GetAura(auraId)
  while cursor and cursor.parentId do
    if cursor.parentId == selectedAuraId then
      return true
    end
    cursor = ns.Registry:GetAura(cursor.parentId)
  end
  return false
end

local function ShouldPlayActivationSound(previousState, nextState)
  if not previousState or type(previousState) ~= "table" then
    return false
  end
  if type(nextState) ~= "table" or nextState.source == "preview" then
    return false
  end
  if nextState.show ~= true then
    return false
  end
  if previousState.show ~= true then
    return true
  end
  return nextState.active == true and previousState.active ~= true
end

local function ShouldPlayReadySound(previousState, nextState)
  if not previousState or type(previousState) ~= "table" then
    return false
  end
  if type(nextState) ~= "table" or nextState.source == "preview" then
    return false
  end
  if nextState.show ~= true then
    return false
  end

  local previousReady = ns.TextResolver and ns.TextResolver.IsReadyState and ns.TextResolver:IsReadyState(previousState) or false
  local nextReady = ns.TextResolver and ns.TextResolver.IsReadyState and ns.TextResolver:IsReadyState(nextState) or false
  return nextReady == true and previousReady ~= true
end

local function ShouldPlaySoundForMode(soundMode, previousState, nextState)
  if soundMode == "ready" then
    return ShouldPlayReadySound(previousState, nextState)
  end
  return ShouldPlayActivationSound(previousState, nextState)
end

local DUAL_TRINKET_SOUNDS = {
  { key = "trinket_slot_13", field = "trinketTopSoundFile" },
  { key = "trinket_slot_14", field = "trinketBottomSoundFile" },
}

local function UsesDualTrinketSounds(aura)
  if not ns.TriggerBase or not ns.TriggerBase.IterateTriggers then
    return false
  end
  for _, trigger in ns.TriggerBase:IterateTriggers(aura, "trinket_cooldown") do
    if trigger.trinketTop ~= false and trigger.trinketBottom ~= false then
      return true
    end
  end
  return false
end

local function FindStateEntry(state, key)
  if type(state) ~= "table" or type(state.entries) ~= "table" then
    return nil
  end
  for _, entry in ipairs(state.entries) do
    if entry.key == key then
      return entry
    end
  end
  return nil
end

local function IsConfiguredSound(soundFile)
  return type(soundFile) == "string" and soundFile ~= "" and soundFile ~= "None"
end

local function PlayDualTrinketSounds(aura, display, previousState, nextState)
  if not UsesDualTrinketSounds(aura) or type(nextState) ~= "table"
    or nextState.source ~= "trinket_cooldown" then
    return false
  end

  local soundMode = display.soundMode == "ready" and "ready" or "activate"
  for _, config in ipairs(DUAL_TRINKET_SOUNDS) do
    local nextEntry = FindStateEntry(nextState, config.key)
    local previousEntry = FindStateEntry(previousState, config.key)
    local soundFile = display[config.field]
    local shouldPlay = ShouldPlaySoundForMode(soundMode, previousEntry, nextEntry)
    if shouldPlay and IsConfiguredSound(soundFile) and ns.Interrupts and ns.Interrupts.PlaySound then
      ns.Interrupts:PlaySound(soundFile, display.soundChannel or "Master")
    end
  end
  return true
end

local function PlayAuraActivationSound(aura, previousState, nextState)
  local display = aura and aura.display or nil
  if not display or display.soundEnabled ~= true then
    return
  end
  if PlayDualTrinketSounds(aura, display, previousState, nextState) then
    return
  end
  if not IsConfiguredSound(display.soundFile) then
    return
  end
  local soundMode = display.soundMode == "ready" and "ready" or "activate"
  local shouldPlay = ShouldPlaySoundForMode(soundMode, previousState, nextState)
  if not shouldPlay then
    return
  end
  if ns.Interrupts and ns.Interrupts.PlaySound then
    ns.Interrupts:PlaySound(display.soundFile, display.soundChannel or "Master")
  end
end

function RuntimeStore:GetState(auraId)
  return self.states[auraId]
end

function RuntimeStore:SetState(auraId, state)
  self.states[auraId] = state
end

function RuntimeStore:SetPresentation(auraId, presentation)
  self.presentations[auraId] = presentation
end

function RuntimeStore:GetPresentation(auraId)
  return self.presentations[auraId]
end

function RuntimeStore:GetRegionByAuraId(auraId)
  return self.regions[auraId]
end

function RuntimeStore:SetNativeAuraSourceUnit(region, unit)
  if not region then return end
  local previousUnit = self.nativeAuraUnitByRegion[region]
  if previousUnit == unit then return end

  if previousUnit then
    local previousSet = self.nativeAuraRegionsByUnit[previousUnit]
    if previousSet then
      previousSet[region] = nil
      if next(previousSet) == nil then self.nativeAuraRegionsByUnit[previousUnit] = nil end
    end
  end

  self.nativeAuraUnitByRegion[region] = nil
  if type(unit) ~= "string" or unit == "" then return end
  local regionSet = self.nativeAuraRegionsByUnit[unit]
  if not regionSet then
    regionSet = setmetatable({}, { __mode = "k" })
    self.nativeAuraRegionsByUnit[unit] = regionSet
  end
  regionSet[region] = true
  self.nativeAuraUnitByRegion[region] = unit
end

function RuntimeStore:RefreshNativeAuraContainers(unit)
  if type(unit) ~= "string" or unit == "" then
    return
  end

  local profileStart = ProfileStart("runtime:native_container_refresh")
  for region in pairs(self.nativeAuraRegionsByUnit[unit] or EMPTY) do
    if region and region.RefreshNativeUnit then
      region:RefreshNativeUnit(unit)
    end
  end
  ProfileFinish("runtime:native_container_refresh", profileStart)
end

function RuntimeStore:RefreshNativeAuraSources(unit)
  if type(unit) ~= "string" or unit == "" then return end
  local profileStart = ProfileStart("runtime:native_source_refresh")
  for region in pairs(self.nativeAuraRegionsByUnit[unit] or EMPTY) do
    if region and region.RefreshCDMSource then region:RefreshCDMSource(unit) end
  end
  ProfileFinish("runtime:native_source_refresh", profileStart)
end

function RuntimeStore:RefreshGroupLayouts(parentId)
  local groupId = parentId
  while groupId do
    local region = self.regions[groupId]
    if region and region.RefreshChildLayout then region:RefreshChildLayout() end
    local aura = ns.Registry:GetAura(groupId)
    groupId = aura and aura.parentId or nil
  end
end

function RuntimeStore:ScheduleGroupLayoutRefresh(parentId)
  if type(parentId) ~= "string" or parentId == "" then return end
  self.pendingGroupLayouts = self.pendingGroupLayouts or {}
  self.pendingGroupLayouts[parentId] = true
  if self.groupLayoutRefreshPending then return end
  self.groupLayoutRefreshPending = true
  C_Timer.After(0, function()
    self.groupLayoutRefreshPending = false
    local pending = self.pendingGroupLayouts or {}
    self.pendingGroupLayouts = {}
    for groupId in pairs(pending) do self:RefreshGroupLayouts(groupId) end
  end)
end

function RuntimeStore:SetRegion(auraId, region)
  self.regions[auraId] = region
end

function RuntimeStore:MarkMissingRegionsDirty()
  self.missingRegionsDirty = true
end

function RuntimeStore:EnsureTimerDriver()
  if self.timerFrame then
    return
  end

  local frame = CreateFrame("Frame")
  frame:Hide()
  frame:SetScript("OnUpdate", function(driver, elapsed)
    self.timerElapsed = (self.timerElapsed or 0) + (elapsed or 0)
    if self.timerElapsed < TIMED_UPDATE_INTERVAL then
      return
    end

    local profileStart = ProfileStart("runtime:timer_driver")
    self.timerElapsed = 0
    local now = GetTime()
    for auraId, region in pairs(self.timedRegions) do
      if not region or not region.OnTimerUpdate then
        self.timedRegions[auraId] = nil
      else
        local keepRunning = region:OnTimerUpdate(now)
        if keepRunning == false then
          self.timedRegions[auraId] = nil
        end
      end
    end

    for auraId, expirationTime in pairs(self.timedStateAuras) do
      if type(expirationTime) ~= "number" or expirationTime <= now then
        self.timedStateAuras[auraId] = nil
        self:RefreshAura(auraId, true)
      end
    end

    if next(self.timedRegions) == nil and next(self.timedStateAuras) == nil then
      driver:Hide()
    end
    ProfileFinish("runtime:timer_driver", profileStart)
  end)

  self.timerFrame = frame
end

function RuntimeStore:RegisterTimedRegion(auraId, region)
  if not auraId or not region then
    return
  end

  self:EnsureTimerDriver()
  self.timedRegions[auraId] = region
  self.timerElapsed = 0
  if self.timerFrame then
    self.timerFrame:Show()
  end
end

function RuntimeStore:RegisterTimedStateAura(auraId, expirationTime)
  if not auraId or type(expirationTime) ~= "number" or expirationTime <= GetTime() then
    self.timedStateAuras[auraId] = nil
    return
  end

  self:EnsureTimerDriver()
  self.timedStateAuras[auraId] = expirationTime
  self.timerElapsed = 0
  if self.timerFrame then
    self.timerFrame:Show()
  end
end

function RuntimeStore:UnregisterTimedStateAura(auraId)
  if not auraId then
    return
  end

  self.timedStateAuras[auraId] = nil
  if self.timerFrame and next(self.timedRegions) == nil and next(self.timedStateAuras) == nil then
    self.timerFrame:Hide()
  end
end

function RuntimeStore:UnregisterTimedRegion(auraId)
  if not auraId then
    return
  end

  self.timedRegions[auraId] = nil
  if self.timerFrame and next(self.timedRegions) == nil and next(self.timedStateAuras) == nil then
    self.timerFrame:Hide()
  end
end

function RuntimeStore:ReleaseMissingRegions()
  if self.missingRegionsDirty ~= true then
    return
  end

  for auraId, region in pairs(self.regions) do
    if not ns.Registry:GetAura(auraId) then
      self:UnregisterTimedRegion(auraId)
      if region.Release then
        region:Release()
      elseif region.frame then
        region.frame:Hide()
      end
      self.regions[auraId] = nil
      self.states[auraId] = nil
      self.presentations[auraId] = nil
      self.activationOrder[auraId] = nil
      self.timedStateAuras[auraId] = nil
      local fingerprints = self.managerSyncFingerprints[auraId]
      if fingerprints then
        if fingerprints.cdm and ns.CooldownManager and ns.CooldownManager.ScheduleVisibilityOverrideSync then
          ns.CooldownManager:ScheduleVisibilityOverrideSync()
        end
        if fingerprints.auraFrames and ns.BlizzardAuraFrames and ns.BlizzardAuraFrames.ScheduleSync then
          ns.BlizzardAuraFrames:ScheduleSync()
        end
        if fingerprints.spellAlerts and ns.BlizzardSpellAlerts and ns.BlizzardSpellAlerts.ScheduleSync then
          ns.BlizzardSpellAlerts:ScheduleSync()
        end
        self.managerSyncFingerprints[auraId] = nil
      end
    end
  end

  self.missingRegionsDirty = false
end

function RuntimeStore:GetActivationOrder(auraId)
  return self.activationOrder[auraId] or 0
end

local function BuildAncestorDepths(auraId, depths)
  local depth = 0
  local cursor = auraId and ns.Registry:GetAura(auraId) or nil
  while cursor and cursor.parentId do
    depth = depth + 1
    local parentId = cursor.parentId
    depths[parentId] = math.max(depths[parentId] or 0, depth)
    cursor = ns.Registry:GetAura(parentId)
  end
end

local function GetAuraDepth(auraId)
  local depth = 0
  local cursor = auraId and ns.Registry:GetAura(auraId) or nil
  while cursor and cursor.parentId do
    depth = depth + 1
    cursor = ns.Registry:GetAura(cursor.parentId)
  end
  return depth
end

local function GetFlatOrderIndex(indexes, auraId)
  return indexes and indexes[auraId] or math.huge
end

local function BuildCDMVisibilityFingerprint(aura, state)
  local display = aura and aura.display or nil
  if not aura or aura.enabled == false or not display or display.hideCDMIcon ~= true then
    return nil
  end

  local effectivelyLoaded = type(state) == "table" and state.loadMatched ~= false
  local nativeAuraOwnsPresentation = effectivelyLoaded and ns.renderers and ns.renderers.NativeAuraRegion
    and ns.renderers.NativeAuraRegion:CanHandle(aura) or false
  local desired = effectivelyLoaded and (state.show == true or nativeAuraOwnsPresentation)
  local parts = { desired and "1" or "0" }
  if desired and type(state.entries) == "table" then
    for _, entry in ipairs(state.entries) do
      local cooldownID = ns.SafeValues:Number(entry and entry.cooldownID)
      if entry and entry.show == true and cooldownID and cooldownID > 0 then
        parts[#parts + 1] = tostring(cooldownID)
      end
    end
  end
  return table.concat(parts, ":")
end

local function BuildAuraFrameFingerprint(aura, state)
  if not aura or aura.enabled == false then return nil end
  local controlsBuffs, controlsDebuffs = false, false
  for _, trigger in ipairs(type(aura.triggers) == "table" and aura.triggers or EMPTY) do
    if trigger and trigger.enabled ~= false and trigger.type == "aura_list" then
      local sourceValue = ns.util.UnitAuraList and ns.util.UnitAuraList.GetSourceValue
        and ns.util.UnitAuraList:GetSourceValue(trigger) or nil
      if sourceValue == "player_buff" and trigger.hideBlizzardBuffs == true then
        controlsBuffs = true
      elseif sourceValue == "player_debuff" and trigger.hideBlizzardDebuffs == true then
        controlsDebuffs = true
      end
    end
  end
  if not controlsBuffs and not controlsDebuffs then return nil end
  local active = type(state) == "table" and state.show == true and state.source ~= "preview"
  return table.concat({
    controlsBuffs and "b" or "-",
    controlsDebuffs and "d" or "-",
    active and "1" or "0",
  }, ":")
end

local function BuildSpellAlertFingerprint(aura, state)
  local display = aura and aura.display or nil
  if not aura or aura.enabled == false or not display or display.hideBlizzardSpellAlert ~= true then
    return nil
  end
  local loaded = type(state) == "table" and state.loadMatched ~= false
  local spellID = ns.SafeValues:Number(display.blizzardSpellAlertSpellId) or 0
  local spellName = type(display.blizzardSpellAlertSpellName) == "string"
    and display.blizzardSpellAlertSpellName or ""
  return table.concat({ loaded and "1" or "0", tostring(spellID), spellName }, ":")
end

function RuntimeStore:UpdateManagerSyncFingerprints(aura, state)
  if not aura or not aura.id then return end
  local previous = self.managerSyncFingerprints[aura.id] or EMPTY
  local currentCDM = BuildCDMVisibilityFingerprint(aura, state)
  local currentAuraFrames = BuildAuraFrameFingerprint(aura, state)
  local currentSpellAlerts = BuildSpellAlertFingerprint(aura, state)

  if previous.cdm ~= currentCDM
      and ns.CooldownManager and ns.CooldownManager.ScheduleVisibilityOverrideSync then
    ns.CooldownManager:ScheduleVisibilityOverrideSync()
  end
  if previous.auraFrames ~= currentAuraFrames
      and ns.BlizzardAuraFrames and ns.BlizzardAuraFrames.ScheduleSync then
    ns.BlizzardAuraFrames:ScheduleSync()
  end
  if previous.spellAlerts ~= currentSpellAlerts
      and ns.BlizzardSpellAlerts and ns.BlizzardSpellAlerts.ScheduleSync then
    ns.BlizzardSpellAlerts:ScheduleSync()
  end

  if currentCDM or currentAuraFrames or currentSpellAlerts then
    local stored = previous ~= EMPTY and previous or {}
    stored.cdm = currentCDM
    stored.auraFrames = currentAuraFrames
    stored.spellAlerts = currentSpellAlerts
    self.managerSyncFingerprints[aura.id] = stored
  else
    self.managerSyncFingerprints[aura.id] = nil
  end
end

function RuntimeStore:ScheduleAllManagerSyncs()
  if ns.CooldownManager and ns.CooldownManager.ScheduleVisibilityOverrideSync then
    ns.CooldownManager:ScheduleVisibilityOverrideSync()
  end
  if ns.BlizzardAuraFrames and ns.BlizzardAuraFrames.ScheduleSync then
    ns.BlizzardAuraFrames:ScheduleSync()
  end
  if ns.BlizzardSpellAlerts and ns.BlizzardSpellAlerts.ScheduleSync then
    ns.BlizzardSpellAlerts:ScheduleSync()
  end
end

function RuntimeStore:RefreshAura(auraId, skipVisibilitySync)
  local aura = ns.Registry:GetAura(auraId)
  if not aura then
    return
  end

  local refreshProfile = ProfileStart("runtime:refresh_aura")

  local previousState = self.states[auraId]
  local loadProfile = ProfileStart("runtime:load_eval")
  local shouldLoad
  if ns.LoadEvaluator.MatchesWithAncestors then
    shouldLoad = ns.LoadEvaluator:MatchesWithAncestors(aura)
  else
    shouldLoad = ns.LoadEvaluator:Matches(aura)
  end
  ProfileFinish("runtime:load_eval", loadProfile)
  local state
  if shouldLoad then
    local triggerProfile = ProfileStart("runtime:trigger_eval")
    state = ns.TriggerEngine:EvaluateAura(aura)
    ProfileFinish("runtime:trigger_eval", triggerProfile)
    local conditionProfile = ProfileStart("runtime:condition_apply")
    state = ns.ConditionEngine:Apply(aura, state)
    state.loadMatched = true
    ProfileFinish("runtime:condition_apply", conditionProfile)
  else
    state = ns.Schema.NormalizeRuntimeState({
      show = false,
      active = false,
      loadMatched = false,
      source = "load",
    })
  end

  local editorOpen = ns.ui and ns.ui.MainWindow and ns.ui.MainWindow.IsOpen and ns.ui.MainWindow:IsOpen()
  local selectedAuraId = ns.db.ui.selectedAuraId
  local isSelected = selectedAuraId == aura.id
  local selectedAura = selectedAuraId and ns.Registry:GetAura(selectedAuraId) or nil
  local selectedIsGroup = selectedAura and (selectedAura.kind == "group" or selectedAura.kind == "dynamic_group")

  if editorOpen and isSelected and (aura.display and aura.display.previewAnimate) then
    state = ns.TriggerEngine:BuildPreviewState(aura)
  elseif editorOpen and selectedIsGroup and aura.parentId == selectedAuraId and not state.show then
    state = ns.TriggerEngine:BuildPreviewState(aura)
  end

  if state.show and (not previousState or not previousState.show) then
    self.activationCounter = self.activationCounter + 1
    self.activationOrder[auraId] = self.activationCounter
  end

  PlayAuraActivationSound(aura, previousState, state)

  if state.show == true and state.progressType == "timed" and type(state.expirationTime) == "number" and state.expirationTime > GetTime() then
    self:RegisterTimedStateAura(auraId, state.expirationTime)
  else
    self:UnregisterTimedStateAura(auraId)
  end

  if ns.ActionEngine then
    local becameShown = state.show and (not previousState or not previousState.show)
    local repeatedActionEvent = state.show
      and previousState
      and previousState.show
      and state.actionEventKey ~= nil
      and state.actionEventKey ~= previousState.actionEventKey
    local becameHidden = not state.show and previousState and previousState.show
    if becameShown or repeatedActionEvent then
      ns.ActionEngine:Fire(aura, "on_activate", state)
    elseif becameHidden then
      ns.ActionEngine:Fire(aura, "on_deactivate", state)
      ns.ActionEngine:CancelForAura(auraId)
    end
  end

  self:SetState(auraId, state)
  self:SetPresentation(auraId, state)
  self:UpdateManagerSyncFingerprints(aura, state)
  local renderProfile = ProfileStart("runtime:render_aura")
  ns.Render:RenderAura(aura, state)
  ProfileFinish("runtime:render_aura", renderProfile)
  ProfileFinish("runtime:refresh_aura", refreshProfile)
end

function RuntimeStore:RefreshAuras(auraIds, skipVisibilitySync)
  if type(auraIds) ~= "table" or #auraIds == 0 then
    return
  end

  local refreshProfile = ProfileStart("runtime:refresh_batch")
  self:ReleaseMissingRegions()

  local leafSet = {}
  local groupSet = {}
  local ancestorDepths = {}

  for _, auraId in ipairs(auraIds) do
    local aura = ns.Registry:GetAura(auraId)
    if aura then
      if IsGroupAura(aura) then
        groupSet[auraId] = true
        ancestorDepths[auraId] = math.max(ancestorDepths[auraId] or 0, GetAuraDepth(auraId))
      else
        leafSet[auraId] = true
      end
      BuildAncestorDepths(auraId, ancestorDepths)
    end
  end

  for ancestorId in pairs(ancestorDepths) do
    groupSet[ancestorId] = true
  end

  local flatOrderIndexes = ns.Registry.GetFlatOrderIndexes and ns.Registry:GetFlatOrderIndexes() or nil
  local leafEntries = {}
  for auraId in pairs(leafSet) do
    leafEntries[#leafEntries + 1] = {
      auraId = auraId,
      index = GetFlatOrderIndex(flatOrderIndexes, auraId),
    }
  end
  table.sort(leafEntries, function(left, right)
    if left.index == right.index then
      return tostring(left.auraId) < tostring(right.auraId)
    end
    return left.index < right.index
  end)

  for _, entry in ipairs(leafEntries) do
    self:RefreshAura(entry.auraId, true)
  end

  local groups = {}
  for auraId, depth in pairs(ancestorDepths) do
    groups[#groups + 1] = {
      auraId = auraId,
      depth = depth,
      index = GetFlatOrderIndex(flatOrderIndexes, auraId),
    }
  end
  for auraId in pairs(groupSet) do
    if not ancestorDepths[auraId] then
      groups[#groups + 1] = {
        auraId = auraId,
        depth = 0,
        index = GetFlatOrderIndex(flatOrderIndexes, auraId),
      }
    end
  end

  table.sort(groups, function(left, right)
    if left.depth == right.depth then
      if left.index == right.index then
        return tostring(left.auraId) < tostring(right.auraId)
      end
      return left.index < right.index
    end
    return left.depth > right.depth
  end)

  for _, entry in ipairs(groups) do
    self:RefreshAura(entry.auraId, true)
  end

  ProfileFinish("runtime:refresh_batch", refreshProfile)
end

function RuntimeStore:RefreshAll()
  local refreshProfile = ProfileStart("runtime:refresh_all")
  self:ReleaseMissingRegions()
  local groupIds = {}

  for _, auraId in ipairs(ns.Registry:GetFlatOrder()) do
    local aura = ns.Registry:GetAura(auraId)
    if aura then
      if IsGroupAura(aura) then
        groupIds[#groupIds + 1] = auraId
      else
        self:RefreshAura(auraId, true)
      end
    end
  end

  for index = #groupIds, 1, -1 do
    self:RefreshAura(groupIds[index], true)
  end

  self:ScheduleAllManagerSyncs()
  ProfileFinish("runtime:refresh_all", refreshProfile)
end

function RuntimeStore:GetMemoryStats()
  local auraProvider = ns.providers and ns.providers.aura or nil
  local targetCacheEntries = 0
  if auraProvider and type(auraProvider.cachedTargetAuras) == "table" then
    for _, cache in pairs(auraProvider.cachedTargetAuras) do
      targetCacheEntries = targetCacheEntries + CountEntries(cache and cache.byGUID or nil)
    end
  end

  return {
    auraCount = #(ns.Registry.GetFlatOrder and ns.Registry:GetFlatOrder() or {}),
    stateCount = CountEntries(self.states),
    regionCount = CountEntries(self.regions),
    timedRegionCount = CountEntries(self.timedRegions),
    targetCacheEntries = targetCacheEntries,
    learnedDurationCount = CountEntries(ns.session and ns.session.learnedTargetDurations or nil),
    talentCatalogClasses = CountEntries(ns.session and ns.session.talentCatalog or nil),
  }
end
