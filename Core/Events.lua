local _, ns = ...

local Events = {}
ns.Events = Events
local EMPTY = {}

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

  -- `UNIT_AURA` and `UNIT_FLAGS` need to support party / raid member updates.
  -- Register them generically and let providers filter units in their handlers.
  if event == "UNIT_AURA" or event == "UNIT_FLAGS" then
    return pcall(frame.RegisterEvent, frame, event)
  end

  if event:find("^UNIT_SPELLCAST") then
    return pcall(frame.RegisterUnitEvent, frame, event, "player", "target")
  end

  -- Retail patch branches do not always expose the same events. An event that
  -- does not exist on this client can never fire, so skip it without aborting
  -- initialization while retaining it for clients that do support it.
  return pcall(frame.RegisterEvent, frame, event)
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
    local eventBucket = string.format("event:%s", tostring(event or "UNKNOWN"))
    local eventProfile = ProfileStart(eventBucket)
    local fullRefresh = GLOBAL_REFRESH_EVENTS[event] == true
    local affectedAuraIds = {}
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
      local providerKey = tostring(provider and provider.key or "unknown")
      local handledAffected = nil
      if provider.HandleEvent then
        local handleBucket = string.format("provider_handle:%s", providerKey)
        local handleProfile = ProfileStart(handleBucket)
        handledAffected = provider:HandleEvent(event, ...)
        ProfileFinish(handleBucket, handleProfile)
      end

      local shouldEvaluate = true
      if provider.ShouldEvaluate then
        local shouldBucket = string.format("provider_should:%s", providerKey)
        local shouldProfile = ProfileStart(shouldBucket)
        shouldEvaluate = provider:ShouldEvaluate(event, ...) ~= false
        ProfileFinish(shouldBucket, shouldProfile)
      end

      if shouldEvaluate and not fullRefresh then
        local providerAffected = handledAffected
        if providerAffected == nil and provider.GetAffectedAuras then
          local affectsBucket = string.format("provider_affects:%s", providerKey)
          local affectsProfile = ProfileStart(affectsBucket)
          providerAffected = provider:GetAffectedAuras(event, ...)
          ProfileFinish(affectsBucket, affectsProfile)
        end

        if providerAffected == true then
          fullRefresh = true
        elseif type(providerAffected) == "table" then
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
      ProfileFinish(eventBucket, eventProfile)
      return
    end

    if hasAffectedAuras then
      local auraIds = {}
      for auraId in pairs(affectedAuraIds) do
        auraIds[#auraIds + 1] = auraId
      end
      ns.runtime:RefreshAuras(auraIds)
    end
    ProfileFinish(eventBucket, eventProfile)
  end)
end

function Events:RebuildSubscriptions(snapshot)
  if not self.frame then
    return
  end

  snapshot = snapshot or (ns.FeatureInventory and ns.FeatureInventory:GetSnapshot()) or nil
  local activeProviderTypes = snapshot and snapshot.providerTypes or nil
  self.providersByEvent = BuildProvidersByEvent(activeProviderTypes)

  local desiredEvents = {}
  for event in pairs(self.providersByEvent or EMPTY) do
    desiredEvents[event] = true
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
  local eventCount, providerCount = 0, 0
  for _ in pairs(self.registeredEvents or EMPTY) do eventCount = eventCount + 1 end
  for _ in pairs((ns.FeatureInventory and ns.FeatureInventory:GetSnapshot().providerTypes) or EMPTY) do
    providerCount = providerCount + 1
  end
  return { registeredEvents = eventCount, activeProviderTypes = providerCount }
end

function Events:Initialize(snapshot)
  if self.frame then
    self:RebuildSubscriptions(snapshot)
    return
  end

  self:InitializeEventFrame()
  self:RebuildSubscriptions(snapshot)
end
