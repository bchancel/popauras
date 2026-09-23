local _, ns = ...

local FeatureInventory = {
  revision = 0,
  rebuildPending = false,
  snapshot = nil,
}
ns.FeatureInventory = FeatureInventory

local SPECIALIZATION_EVENTS = {
  "PLAYER_TALENT_UPDATE",
  "PLAYER_SPECIALIZATION_CHANGED",
  "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
  "ACTIVE_TALENT_GROUP_CHANGED",
  "TRAIT_CONFIG_UPDATED",
  "TRAIT_CONFIG_LIST_UPDATED",
  "ACTIVE_COMBAT_CONFIG_CHANGED",
  "SELECTED_LOADOUT_CHANGED",
  "SPELLS_CHANGED",
}

local function HasEnabledEntry(values)
  if type(values) ~= "table" then
    return false
  end
  for _, enabled in pairs(values) do
    if enabled == true then
      return true
    end
  end
  return false
end

local function HasAnyEntry(values)
  return type(values) == "table" and next(values) ~= nil
end

local function VisibilityIsRestricted(visibility)
  if type(visibility) ~= "table" then
    return false
  end
  for _, key in ipairs({ "dungeon", "delve", "raid", "open_world", "solo", "arena", "battleground" }) do
    if visibility[key] ~= true then
      return true
    end
  end
  return false
end

local function AddAuraSubtree(target, aura, visited)
  if type(target) ~= "table" or type(aura) ~= "table" or not aura.id then return end
  visited = visited or {}
  if visited[aura.id] then return end
  visited[aura.id] = true
  target[aura.id] = true
  for _, childID in ipairs(type(aura.children) == "table" and aura.children or {}) do
    local child = ns.Registry and ns.Registry:GetAura(childID) or nil
    if child then AddAuraSubtree(target, child, visited) end
  end
end

local function AddLoadEvent(snapshot, event, aura)
  snapshot.loadEvents[event] = true
  snapshot.loadAuraIDsByEvent[event] = snapshot.loadAuraIDsByEvent[event] or {}
  -- A parent's load state is inherited by every descendant. Index the whole
  -- subtree so a scoped load event cannot leave a child rendered from stale
  -- ancestor state.
  AddAuraSubtree(snapshot.loadAuraIDsByEvent[event], aura)
end

local function AddLoadEvents(snapshot, events, aura)
  for _, event in ipairs(events or {}) do AddLoadEvent(snapshot, event, aura) end
end

local function AddLoadDemand(snapshot, aura)
  local load = type(aura) == "table" and aura.load or nil
  if type(load) ~= "table" then
    return
  end

  local hasClassOrSpec = (type(load.class) == "string" and load.class ~= "")
    or (tonumber(load.spec or 0) or 0) > 0
    or HasEnabledEntry(load.classes)
    or HasEnabledEntry(load.specs)
  local hasTalent = load.talent == true and HasEnabledEntry(load.talents)
  local hasSavedLoadout = tostring(load.savedLoadoutMode or "any") ~= "any"
    or HasAnyEntry(load.savedLoadoutSelections)

  if hasClassOrSpec or hasTalent or hasSavedLoadout then
    AddLoadEvents(snapshot, SPECIALIZATION_EVENTS, aura)
  end

  if (tonumber(load.equippedItemId or 0) or 0) > 0
      or (type(load.equippedItemName) == "string" and load.equippedItemName ~= "") then
    AddLoadEvent(snapshot, "PLAYER_EQUIPMENT_CHANGED", aura)
  end

  if (tonumber(load.level or 0) or 0) > 0 then
    AddLoadEvent(snapshot, "PLAYER_LEVEL_UP", aura)
  end

  if tostring(load.combat or "any") ~= "any" then
    AddLoadEvent(snapshot, "PLAYER_REGEN_DISABLED", aura)
    AddLoadEvent(snapshot, "PLAYER_REGEN_ENABLED", aura)
  end

  local hasLocation = (tonumber(load.instanceId or 0) or 0) > 0
    or (type(load.instanceType) == "string" and load.instanceType ~= "")
    or VisibilityIsRestricted(load.visibility)
  if hasLocation then
    AddLoadEvent(snapshot, "ZONE_CHANGED_NEW_AREA", aura)
    AddLoadEvent(snapshot, "GROUP_ROSTER_UPDATE", aura)
  end

  if (tonumber(load.encounterId or 0) or 0) > 0 then
    AddLoadEvent(snapshot, "ENCOUNTER_START", aura)
    AddLoadEvent(snapshot, "ENCOUNTER_END", aura)
    AddLoadEvent(snapshot, "ZONE_CHANGED_NEW_AREA", aura)
  end
end

local function AddTriggerDemand(snapshot, aura, trigger)
  if type(trigger) ~= "table" or trigger.enabled == false then
    return
  end

  local triggerType = tostring(trigger.type or "simple")
  snapshot.providerTypes[triggerType] = true

  if triggerType == "aura" or triggerType == "aura_list" then
    snapshot.needsNativeAuras = true
  end
  if triggerType == "aura" or triggerType == "spell_cooldown" or triggerType == "trinket_cooldown" then
    snapshot.needsCooldownManager = true
  end
  if triggerType == "spell_cooldown"
      and aura.display and aura.display.activeGlowStyle == "ACTIVE_DURATION" then
    snapshot.needsNativeAuras = true
  end
end

local function CountKeys(values)
  local count = 0
  for _ in pairs(values or {}) do
    count = count + 1
  end
  return count
end

function FeatureInventory:BuildSnapshot()
  local snapshot = {
    providerTypes = {},
    loadEvents = { PLAYER_ENTERING_WORLD = true },
    loadAuraIDsByEvent = {},
    configuredAuraCount = 0,
    enabledAuraCount = 0,
    needsInterruptTracker = false,
    needsNativeAuras = false,
    needsCooldownManager = false,
    needsSpellAlerts = false,
    needsSharedMedia = false,
  }

  if not (ns.Registry and ns.Registry.IterateAll and ns.db) then
    return snapshot
  end

  for _, aura in ns.Registry:IterateAll() do
    if type(aura) == "table" then
      snapshot.configuredAuraCount = snapshot.configuredAuraCount + 1
      if aura.enabled ~= false then
        -- Disabled definitions remain editable and saved, but LoadEvaluator
        -- will never run them. They should not keep runtime systems awake.
        snapshot.enabledAuraCount = snapshot.enabledAuraCount + 1
        if aura.kind == "interrupt_tracker" then
          snapshot.needsInterruptTracker = true
        elseif aura.kind == "aura_bar_list" then
          snapshot.needsNativeAuras = true
        end

        local display = type(aura.display) == "table" and aura.display or nil
        if display and display.hideBlizzardSpellAlert == true then
          snapshot.needsSpellAlerts = true
        end
        if display and display.hideCDMIcon == true then
          snapshot.needsCooldownManager = true
        end
        if display and type(display.barTexture) == "string"
            and display.barTexture:match("^sm:") then
          snapshot.needsSharedMedia = true
        end

        for _, trigger in ipairs(type(aura.triggers) == "table" and aura.triggers or {}) do
          AddTriggerDemand(snapshot, aura, trigger)
        end
        AddLoadDemand(snapshot, aura)
      end
    end
  end

  snapshot.providerTypeCount = CountKeys(snapshot.providerTypes)
  snapshot.loadEventCount = CountKeys(snapshot.loadEvents)
  return snapshot
end

function FeatureInventory:ApplyDemand(snapshot)
  snapshot = snapshot or self.snapshot or self:BuildSnapshot()

  if snapshot.needsNativeAuras and ns.NativeAuras and ns.NativeAuras.EnsureActive then
    ns.NativeAuras:EnsureActive()
  end
  if snapshot.needsCooldownManager and ns.CooldownManager and ns.CooldownManager.EnsureActive then
    ns.CooldownManager:EnsureActive(true)
  end
  if snapshot.needsSpellAlerts and ns.BlizzardSpellAlerts and ns.BlizzardSpellAlerts.EnsureActive then
    ns.BlizzardSpellAlerts:EnsureActive(true)
  end
  if snapshot.needsInterruptTracker and ns.InterruptTracker and ns.InterruptTracker.EnsureInitialized then
    ns.InterruptTracker:EnsureInitialized(true)
  end
  if snapshot.needsSharedMedia and ns.util.Media then
    ns.util.Media:EnsureSharedMedia(true)
  end
  if ns.Events and ns.Events.RebuildSubscriptions then
    ns.Events:RebuildSubscriptions(snapshot)
  end
  -- Configuration changes rebuild demand asynchronously. Reconcile every
  -- manager once after that rebuild so turning an option off also restores the
  -- Blizzard-owned presentation it previously suppressed.
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

function FeatureInventory:Rebuild(applyDemand)
  self.rebuildPending = false
  self.snapshot = self:BuildSnapshot()
  self.revision = self.revision + 1
  self.snapshot.revision = self.revision
  if applyDemand ~= false then
    self:ApplyDemand(self.snapshot)
  end
  return self.snapshot
end

function FeatureInventory:ScheduleRebuild()
  if self.rebuildPending then
    return
  end
  self.rebuildPending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      FeatureInventory:Rebuild(true)
    end)
  else
    self:Rebuild(true)
  end
end

function FeatureInventory:GetSnapshot()
  return self.snapshot or self:Rebuild(false)
end

function FeatureInventory:IsRequired(key)
  return self:GetSnapshot()[key] == true
end
