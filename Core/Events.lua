local _, ns = ...

local Events = {}
ns.Events = Events
local EMPTY = {}

local UNIT_SCOPED_EVENTS = {
  UNIT_AURA = true,
  UNIT_FLAGS = true,
}

local GROUP_UNIT_TOKENS = { "player" }
for index = 1, 4 do
  GROUP_UNIT_TOKENS[#GROUP_UNIT_TOKENS + 1] = "party" .. index
end
for index = 1, 40 do
  GROUP_UNIT_TOKENS[#GROUP_UNIT_TOKENS + 1] = "raid" .. index
end

local GLOBAL_REFRESH_EVENTS = {
  PLAYER_ENTERING_WORLD = true,
  PLAYER_EQUIPMENT_CHANGED = true,
  PLAYER_LEVEL_UP = true,
  PLAYER_TALENT_UPDATE = true,
  PLAYER_SPECIALIZATION_CHANGED = true,
  ACTIVE_PLAYER_SPECIALIZATION_CHANGED = true,
  ACTIVE_TALENT_GROUP_CHANGED = true,
  TRAIT_CONFIG_UPDATED = true,
  TRAIT_CONFIG_LIST_UPDATED = true,
  ACTIVE_COMBAT_CONFIG_CHANGED = true,
  SELECTED_LOADOUT_CHANGED = true,
  SPELLS_CHANGED = true,
  PLAYER_REGEN_DISABLED = true,
  PLAYER_REGEN_ENABLED = true,
  ZONE_CHANGED_NEW_AREA = true,
  GROUP_ROSTER_UPDATE = true,
  ENCOUNTER_START = true,
  ENCOUNTER_END = true,
}

local function AddAffectedAuraIds(target, source)
  if type(source) ~= "table" then
    return false
  end

  local added = false
  for _, auraId in ipairs(source) do
    if auraId and target[auraId] ~= true then
      target[auraId] = true
      added = true
    end
  end
  return added
end

local function AcquireScratchTable(self)
  self.scratchTables = self.scratchTables or {}
  local index = #self.scratchTables
  if index == 0 then return {} end
  local result = self.scratchTables[index]
  self.scratchTables[index] = nil
  return result
end

local function ReleaseScratchTable(self, value)
  if type(value) ~= "table" then return end
  wipe(value)
  self.scratchTables[#self.scratchTables + 1] = value
end

local function AddUnitToken(target, unit)
  if type(unit) ~= "string" or unit == "" or unit == "nameplate" then
    return
  end
  if unit == "group" then
    for _, groupUnit in ipairs(GROUP_UNIT_TOKENS) do
      target[groupUnit] = true
    end
    return
  end
  target[unit] = true
end

local function AddUnitDemand(target, demand)
  if type(demand) == "string" then
    AddUnitToken(target, demand)
    return false
  end
  if demand == true or demand == nil then
    return true
  end
  if type(demand) ~= "table" then
    return false
  end

  for key, value in pairs(demand) do
    if type(key) == "number" then
      AddUnitToken(target, value)
    elseif value == true then
      AddUnitToken(target, key)
    end
  end
  return false
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

local function BuildProvidersByEvent(activeProviderTypes)
  local providersByEvent = {}
  for providerKey, provider in pairs(ns.providers or EMPTY) do
    if not activeProviderTypes or activeProviderTypes[providerKey] == true then
      for _, event in ipairs(provider.events or EMPTY) do
        providersByEvent[event] = providersByEvent[event] or {}
        providersByEvent[event][#providersByEvent[event] + 1] = provider
      end
    end
  end
  return providersByEvent
end

local function RegisterTrackedEvent(frame, event)
  if type(event) ~= "string" or event == "" then
    return false
  end

  if event:find("^UNIT_SPELLCAST") then
    return pcall(frame.RegisterUnitEvent, frame, event, "player", "target")
  end

  -- Retail patch branches do not always expose the same events. An event that
  -- does not exist on this client can never fire, so skip it without aborting
  -- initialization while retaining it for clients that do support it.
  return pcall(frame.RegisterEvent, frame, event)
end

local function GetProviderUnitDemand(provider, event)
  if provider and provider.GetUnitEventUnits then
    return provider:GetUnitEventUnits(event)
  end
  if provider and type(provider.unitEvents) == "table" then
    return provider.unitEvents[event]
  end
  -- An undeclared unit-event consumer must retain generic delivery. Providers
  -- opt into C-side unit filtering only when they can describe every unit they
  -- need, so adding a future provider cannot silently lose functionality.
  return nil
end

function Events:DispatchEvent(event, ...)
  local eventBucket = self.eventProfileBuckets and self.eventProfileBuckets[event]
    or ("event:" .. tostring(event or "UNKNOWN"))
  local eventProfile = ProfileStart(eventBucket)
  local fullRefresh = GLOBAL_REFRESH_EVENTS[event] == true
  local affectedAuraIds
  local hasAffectedAuras = false

  if fullRefresh and ns.LoadEvaluator and ns.LoadEvaluator.InvalidateCache then
    ns.LoadEvaluator:InvalidateCache()
  end
  if ns.LoadEvaluator and ns.LoadEvaluator.SetCurrentEncounterId then
    if event == "ENCOUNTER_START" then
      ns.LoadEvaluator:SetCurrentEncounterId(...)
    elseif event == "ENCOUNTER_END" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
      ns.LoadEvaluator:SetCurrentEncounterId(0)
    end
  end

  for _, provider in ipairs(self.providersByEvent[event] or EMPTY) do
    local buckets = self.providerProfileBuckets and self.providerProfileBuckets[provider] or EMPTY
    local handledAffected = nil
    if provider.HandleEvent then
      local handleProfile = ProfileStart(buckets.handle)
      handledAffected = provider:HandleEvent(event, ...)
      ProfileFinish(buckets.handle, handleProfile)
    end

    local shouldEvaluate = true
    if provider.ShouldEvaluate then
      local shouldProfile = ProfileStart(buckets.should)
      shouldEvaluate = provider:ShouldEvaluate(event, ...) ~= false
      ProfileFinish(buckets.should, shouldProfile)
    end

    if shouldEvaluate and not fullRefresh then
      local providerAffected = handledAffected
      if providerAffected == nil and provider.GetAffectedAuras then
        local affectsProfile = ProfileStart(buckets.affects)
        providerAffected = provider:GetAffectedAuras(event, ...)
        ProfileFinish(buckets.affects, affectsProfile)
      end

      if providerAffected == true then
        fullRefresh = true
      elseif type(providerAffected) == "table" then
        affectedAuraIds = affectedAuraIds or AcquireScratchTable(self)
        if AddAffectedAuraIds(affectedAuraIds, providerAffected) then
          hasAffectedAuras = true
        end
      elseif providerAffected == false then
        -- Provider explicitly reported no affected auras.
      else
        fullRefresh = true
      end
    end
  end

  if fullRefresh then
    ns.runtime:RefreshAll()
    ReleaseScratchTable(self, affectedAuraIds)
    ProfileFinish(eventBucket, eventProfile)
    return
  end

  if hasAffectedAuras then
    local auraIds = AcquireScratchTable(self)
    for auraId in pairs(affectedAuraIds) do
      auraIds[#auraIds + 1] = auraId
    end
    ns.runtime:RefreshAuras(auraIds)
    ReleaseScratchTable(self, auraIds)
  end
  ReleaseScratchTable(self, affectedAuraIds)
  ProfileFinish(eventBucket, eventProfile)
end

function Events:InitializeEventFrame()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame")
  self.frame = frame
  self.unsupportedEvents = {}
  self.registeredEvents = {}

  frame:SetScript("OnEvent", function(_, event, ...)
    self:DispatchEvent(event, ...)
  end)
end

function Events:RebuildUnitEventSubscriptions()
  local desiredByUnit = {}
  local genericFallback = {}

  for event, providers in pairs(self.providersByEvent or EMPTY) do
    if UNIT_SCOPED_EVENTS[event] then
      local units = {}
      for _, provider in ipairs(providers) do
        if AddUnitDemand(units, GetProviderUnitDemand(provider, event)) then
          genericFallback[event] = true
          break
        end
      end
      if not genericFallback[event] then
        for unit in pairs(units) do
          desiredByUnit[unit] = desiredByUnit[unit] or {}
          desiredByUnit[unit][event] = true
        end
      end
    end
  end

  self.unitEventFrames = self.unitEventFrames or {}
  self.registeredUnitEventNames = {}

  for unit, tracker in pairs(self.unitEventFrames) do
    local desiredEvents = desiredByUnit[unit] or EMPTY
    tracker._popAurasEvents = tracker._popAurasEvents or {}
    for event in pairs(tracker._popAurasEvents) do
      if not desiredEvents[event] or genericFallback[event] then
        tracker:UnregisterEvent(event)
        tracker._popAurasEvents[event] = nil
      end
    end
  end

  for unit, desiredEvents in pairs(desiredByUnit) do
    local tracker = self.unitEventFrames[unit]
    if not tracker then
      tracker = CreateFrame("Frame")
      tracker._popAurasEvents = {}
      tracker:SetScript("OnEvent", function(_, event, ...)
        self:DispatchEvent(event, ...)
      end)
      self.unitEventFrames[unit] = tracker
    end
    for event in pairs(desiredEvents) do
      if not genericFallback[event] and not tracker._popAurasEvents[event] then
        local ok = pcall(tracker.RegisterUnitEvent, tracker, event, unit)
        if ok then
          tracker._popAurasEvents[event] = true
          self.registeredUnitEventNames[event] = true
        else
          genericFallback[event] = true
        end
      elseif tracker._popAurasEvents[event] then
        self.registeredUnitEventNames[event] = true
      end
    end
  end

  -- A future client or provider can fall back to generic delivery without
  -- losing events. Remove scoped registrations for that event to avoid double
  -- dispatch, then let the main event frame own it.
  for event in pairs(genericFallback) do
    for _, tracker in pairs(self.unitEventFrames) do
      if tracker._popAurasEvents and tracker._popAurasEvents[event] then
        tracker:UnregisterEvent(event)
        tracker._popAurasEvents[event] = nil
      end
    end
    self.registeredUnitEventNames[event] = nil
  end

  self.genericUnitEvents = genericFallback
end

function Events:RebuildSubscriptions(snapshot)
  if not self.frame then
    return
  end

  snapshot = snapshot or (ns.FeatureInventory and ns.FeatureInventory:GetSnapshot()) or nil
  local activeProviderTypes = snapshot and snapshot.providerTypes or nil
  self.providersByEvent = BuildProvidersByEvent(activeProviderTypes)
  self.eventProfileBuckets = self.eventProfileBuckets or {}
  self.providerProfileBuckets = {}

  for event in pairs(self.providersByEvent or EMPTY) do
    self.eventProfileBuckets[event] = "event:" .. event
  end
  for _, provider in pairs(ns.providers or EMPTY) do
    local providerKey = tostring(provider and provider.key or "unknown")
    self.providerProfileBuckets[provider] = {
      handle = "provider_handle:" .. providerKey,
      should = "provider_should:" .. providerKey,
      affects = "provider_affects:" .. providerKey,
    }
  end

  self:RebuildUnitEventSubscriptions()

  local desiredEvents = {}
  for event in pairs(self.providersByEvent or EMPTY) do
    if not UNIT_SCOPED_EVENTS[event] or (self.genericUnitEvents and self.genericUnitEvents[event]) then
      desiredEvents[event] = true
    end
  end
  if snapshot then
    for event in pairs(snapshot.loadEvents or EMPTY) do
      desiredEvents[event] = true
    end
  else
    for event in pairs(GLOBAL_REFRESH_EVENTS) do
      desiredEvents[event] = true
    end
  end

  for event in pairs(self.registeredEvents or EMPTY) do
    if not desiredEvents[event] then
      self.frame:UnregisterEvent(event)
      self.registeredEvents[event] = nil
    end
  end
  for event in pairs(desiredEvents) do
    if not self.registeredEvents[event] and not self.unsupportedEvents[event] then
      if RegisterTrackedEvent(self.frame, event) then
        self.registeredEvents[event] = true
      else
        self.unsupportedEvents[event] = true
      end
    end
  end
end

function Events:GetSubscriptionStats()
  local eventCount, providerCount, unitTrackerCount = 0, 0, 0
  for _ in pairs(self.registeredEvents or EMPTY) do eventCount = eventCount + 1 end
  for event in pairs(self.registeredUnitEventNames or EMPTY) do
    if not (self.registeredEvents and self.registeredEvents[event]) then
      eventCount = eventCount + 1
    end
  end
  for _ in pairs((ns.FeatureInventory and ns.FeatureInventory:GetSnapshot().providerTypes) or EMPTY) do
    providerCount = providerCount + 1
  end
  for _, tracker in pairs(self.unitEventFrames or EMPTY) do
    if tracker._popAurasEvents and next(tracker._popAurasEvents) ~= nil then
      unitTrackerCount = unitTrackerCount + 1
    end
  end
  return {
    registeredEvents = eventCount,
    activeProviderTypes = providerCount,
    unitTrackers = unitTrackerCount,
  }
end

function Events:Initialize(snapshot)
  if self.frame then
    self:RebuildSubscriptions(snapshot)
    return
  end

  self:InitializeEventFrame()
  self:RebuildSubscriptions(snapshot)
end
