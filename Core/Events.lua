local _, ns = ...

local Events = {}
ns.Events = Events
local EMPTY = {}

local GLOBAL_REFRESH_EVENTS = {
  PLAYER_ENTERING_WORLD = true,
  PLAYER_EQUIPMENT_CHANGED = true,
  PLAYER_TALENT_UPDATE = true,
  PLAYER_SPECIALIZATION_CHANGED = true,
  TRAIT_CONFIG_UPDATED = true,
  TRAIT_CONFIG_LIST_UPDATED = true,
  ACTIVE_COMBAT_CONFIG_CHANGED = true,
  SELECTED_LOADOUT_CHANGED = true,
  SPELLS_CHANGED = true,
  PLAYER_REGEN_DISABLED = true,
  PLAYER_REGEN_ENABLED = true,
  ZONE_CHANGED_NEW_AREA = true,
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

local function BuildProvidersByEvent()
  local providersByEvent = {}
  for _, provider in pairs(ns.providers or EMPTY) do
    for _, event in ipairs(provider.events or EMPTY) do
      providersByEvent[event] = providersByEvent[event] or {}
      providersByEvent[event][#providersByEvent[event] + 1] = provider
    end
  end
  return providersByEvent
end

local function RegisterTrackedEvent(frame, event)
  if type(event) ~= "string" or event == "" then
    return
  end

  -- `UNIT_AURA` and `UNIT_FLAGS` need to support party / raid member updates.
  -- Register them generically and let providers filter units in their handlers.
  if event == "UNIT_AURA" or event == "UNIT_FLAGS" then
    frame:RegisterEvent(event)
    return
  end

  if event:find("^UNIT_SPELLCAST") then
    frame:RegisterUnitEvent(event, "player", "target")
    return
  end

  frame:RegisterEvent(event)
end

function Events:InitializeEventFrame()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame")
  self.frame = frame

  for event in pairs(self.providersByEvent or EMPTY) do
    RegisterTrackedEvent(frame, event)
  end

  for event in pairs(GLOBAL_REFRESH_EVENTS) do
    RegisterTrackedEvent(frame, event)
  end

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

function Events:Initialize()
  if self.frame then
    return
  end

  self.providersByEvent = BuildProvidersByEvent()
  self:InitializeEventFrame()
end
