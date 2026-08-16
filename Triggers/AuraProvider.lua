local _, ns = ...

local Safe = ns.SafeValues
local Duration = ns.Duration
local EMPTY = {}
local DEFERRED_GROUP_MISSING_SECONDS = 0.05

local PARTY_UNIT_TOKENS = {}
local RAID_UNIT_TOKENS = {}
for index = 1, 4 do PARTY_UNIT_TOKENS[index] = "party" .. index end
for index = 1, 40 do RAID_UNIT_TOKENS[index] = "raid" .. index end

local provider = ns.TriggerBase:CreateProvider("aura", {
  events = {
    "UNIT_AURA",
    "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "UNIT_FLAGS",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
  },
})

local function AddSpellID(result, seen, value)
  local spellIDs = ns.util.Spells:GetAuraSpellIDs(value)
  for _, spellID in ipairs(spellIDs) do
    if spellID > 0 and not seen[spellID] then
      seen[spellID] = true
      result[#result + 1] = spellID
    end
  end
end

local function BuildSpellIDs(trigger)
  local result, seen = {}, {}
  for _, value in ipairs(type(trigger and trigger.spellIDs) == "table" and trigger.spellIDs or EMPTY) do
    AddSpellID(result, seen, value)
  end
  AddSpellID(result, seen, trigger and trigger.spellId)
  local names = type(trigger and trigger.spellNames) == "table" and trigger.spellNames
    or type(trigger and trigger.exactSpellNames) == "table" and trigger.exactSpellNames or EMPTY
  for _, name in ipairs(names) do
    AddSpellID(result, seen, ns.util.Spells:ResolveConfiguredSpellID(name))
  end
  return result
end

local function GetSpellIDs(trigger)
  local compiled = provider.compiledSpellIDsByTrigger
  local cached = compiled and compiled[trigger]
  if cached then return cached end
  return BuildSpellIDs(trigger)
end

local function GetSpellPresentation(spellID, auraConfig)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and not Safe:IsSecret(info) and type(info) == "table" then
      return Safe:String(info.name) or (auraConfig and auraConfig.name) or "Aura", Safe:Number(info.iconID)
    end
  end
  return auraConfig and auraConfig.name or "Aura", nil
end

local function UnitExistsSafe(unit)
  local ok, result = pcall(UnitExists, unit)
  return ok and Safe:Boolean(result) == true
end

local function UnitPassesFilters(unit, trigger)
  if not UnitExistsSafe(unit) then return false end
  if trigger.aliveOnly == true then
    local ok, dead = pcall(UnitIsDeadOrGhost, unit)
    if ok and Safe:Boolean(dead) == true then return false end
  end
  if trigger.ignoreNPCs == true then
    local ok, player = pcall(UnitIsPlayer, unit)
    if not ok or Safe:Boolean(player) ~= true then return false end
  end
  local rangeMode = trigger.groupRange
  if rangeMode == "nearby" or rangeMode == "spell" or rangeMode == "in_range" then
    local ok, inRange, checked = pcall(UnitInRange, unit)
    local safeChecked = Safe:Boolean(checked)
    if ok and safeChecked == true and Safe:Boolean(inRange) ~= true then return false end
  end
  return true
end

local function GetUnits(trigger)
  local configured = trigger.unit or "player"
  if configured ~= "group" then return { configured } end
  local result = { "player" }
  if IsInRaid and IsInRaid() then
    local count = Safe:Number(GetNumGroupMembers and GetNumGroupMembers()) or 0
    for index = 1, count do result[#result + 1] = "raid" .. index end
  elseif IsInGroup and IsInGroup() then
    local count = Safe:Number(GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
    for index = 1, count do result[#result + 1] = "party" .. index end
  end
  return result
end

local function MatchesAuraType(auraData, helpful)
  if helpful then
    return Safe:Boolean(auraData.isHelpful) == true
  end
  return Safe:Boolean(auraData.isHarmful) == true
end

local function MatchesCaster(auraData, trigger)
  if trigger.castByMe ~= true then return true end
  local sourceUnit = Safe:String(auraData.sourceUnit)
  if sourceUnit == "player" or sourceUnit == "pet" or sourceUnit == "vehicle" then return true end
  if sourceUnit and UnitIsUnit then
    local ok, same = pcall(UnitIsUnit, sourceUnit, "player")
    return ok and Safe:Boolean(same) == true
  end
  return false
end

local function QueryAura(unit, spellID, helpful, trigger)
  if Safe:ShouldSpellAuraBeSecret(spellID) then
    return nil, "unavailable"
  end
  if not C_UnitAuras or not C_UnitAuras.GetUnitAuraBySpellID then
    return nil, "unavailable"
  end
  local ok, auraData = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
  if not ok then return nil, "unavailable" end
  if Safe:IsSecret(auraData) then return nil, "unavailable" end
  if auraData == nil then return nil, "absent" end
  if type(auraData) ~= "table" then return nil, "unavailable" end
  if not MatchesAuraType(auraData, helpful) or not MatchesCaster(auraData, trigger) then
    return nil, "absent"
  end
  return auraData, "present"
end

local function GetAuraDurationObject(unit, auraInstanceID)
  if not C_UnitAuras or not C_UnitAuras.GetAuraDuration or not auraInstanceID then return nil end
  local ok, object = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
  return ok and object or nil
end

local function GetApplicationDisplay(unit, auraInstanceID)
  if not C_UnitAuras or not C_UnitAuras.GetAuraApplicationDisplayCount or not auraInstanceID then
    return nil, false
  end
  local ok, display = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 2)
  if not ok then return nil, false end
  return Safe:Display(display), true
end

local function BuildPresentState(auraData, unit, helpful, auraConfig)
  local auraInstanceID = Safe:Number(auraData.auraInstanceID)
  local spellID = Safe:Number(auraData.spellId)
  local name = Safe:String(auraData.name)
  local icon = Safe:Number(auraData.icon)
  local durationObject = GetAuraDurationObject(unit, auraInstanceID)
  local timer = Duration:BuildTimer(durationObject, "aura", true)
  timer.duration = timer.duration or Safe:Number(auraData.duration)
  timer.expirationTime = timer.expirationTime or Safe:Number(auraData.expirationTime)
  if timer.object == nil and timer.duration and timer.expirationTime then
    timer.object = Duration:CreateFromEnd(timer.expirationTime, timer.duration)
  end

  local applications = Safe:Number(auraData.applications) or 0
  local display, hasDisplay = GetApplicationDisplay(unit, auraInstanceID)
  return ns.Schema.NormalizeRuntimeState({
    show = true,
    matched = true,
    active = true,
    availability = "available",
    unit = unit,
    matchedUnits = { unit },
    name = name or (auraConfig and auraConfig.name) or "Aura",
    icon = icon,
    stacks = applications,
    stackDisplayValue = display,
    hasStackDisplayValue = hasDisplay,
    duration = timer.duration or 0,
    expirationTime = timer.expirationTime or 0,
    durationObject = timer.object,
    timer = timer,
    progressType = (timer.object ~= nil or timer.expirationTime ~= nil) and "timed" or "static",
    value = timer.remaining or timer.duration or 0,
    total = timer.duration or 0,
    spellId = spellID,
    auraInstanceID = auraInstanceID,
    helpful = helpful,
    source = "aura",
    statusText = helpful and "Buff Active" or "Debuff Active",
  })
end

local function BuildUnavailable(trigger, auraConfig, helpful, spellID)
  local name, icon = GetSpellPresentation(spellID, auraConfig)
  return ns.Schema.NormalizeRuntimeState({
    show = false,
    matched = false,
    active = false,
    availability = "unavailable",
    unit = trigger.unit or "player",
    name = name,
    icon = icon,
    spellId = spellID,
    source = "aura",
    statusText = helpful and "Buff Restricted" or "Debuff Restricted",
    debugExtra = "Logical aura data is restricted; use native aura presentation.",
  })
end

local function BuildAbsent(trigger, auraConfig, helpful, spellID, missingMatched, matchedUnits)
  local name, icon = GetSpellPresentation(spellID, auraConfig)
  local show = missingMatched or trigger.showAlways == true
  return ns.Schema.NormalizeRuntimeState({
    show = show,
    matched = missingMatched,
    active = false,
    isReady = show,
    availability = "available",
    unit = trigger.unit or "player",
    matchedUnits = matchedUnits,
    name = name,
    icon = icon,
    spellId = spellID,
    source = "aura",
    statusText = helpful and "Missing Buff" or "Missing Debuff",
  })
end

local function CollectMissingGroupUnit(absentUnits, unit, trigger, helpful, spellIDs)
  if not UnitPassesFilters(unit, trigger) then return false end

  local unitAbsent = true
  local unitUnavailable = false
  for _, spellID in ipairs(spellIDs) do
    local auraData, availability = QueryAura(unit, spellID, helpful, trigger)
    if auraData then
      unitAbsent = false
      break
    elseif availability == "unavailable" then
      unitUnavailable = true
      unitAbsent = false
    end
  end
  if unitAbsent then absentUnits[#absentUnits + 1] = unit end
  return unitUnavailable
end

local function EvaluateGroupMissing(trigger, auraConfig, helpful, spellIDs)
  local absentUnits = {}
  local anyUnavailable = CollectMissingGroupUnit(absentUnits, "player", trigger, helpful, spellIDs)
  local units, count
  if IsInRaid and IsInRaid() then
    units = RAID_UNIT_TOKENS
    count = math.min(Safe:Number(GetNumGroupMembers and GetNumGroupMembers()) or 0, #RAID_UNIT_TOKENS)
  elseif IsInGroup and IsInGroup() then
    units = PARTY_UNIT_TOKENS
    count = math.min(Safe:Number(GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0, #PARTY_UNIT_TOKENS)
  end
  for index = 1, count or 0 do
    if CollectMissingGroupUnit(absentUnits, units[index], trigger, helpful, spellIDs) then
      anyUnavailable = true
    end
  end

  if anyUnavailable then return BuildUnavailable(trigger, auraConfig, helpful, spellIDs[1]) end
  return BuildAbsent(trigger, auraConfig, helpful, spellIDs[1], #absentUnits > 0, absentUnits)
end

function provider:Evaluate(trigger, auraConfig)
  local helpful = trigger.auraType ~= "debuff"
  if trigger.unit == "nameplate" then
    return ns.Schema.NormalizeRuntimeState({
      show = false,
      matched = false,
      active = false,
      availability = "unavailable",
      unit = "nameplate",
      name = auraConfig and auraConfig.name or "Nameplate Buffs",
      source = "nameplate_aura",
      statusText = "Native Nameplate Display",
      debugExtra = "Blizzard owns nameplate aura presence and presentation.",
    })
  end
  local spellIDs = GetSpellIDs(trigger)
  if #spellIDs == 0 then
    return BuildUnavailable(trigger, auraConfig, helpful, nil)
  end
  if trigger.unit == "group" and trigger.auraFilter == "missing"
      and auraConfig and provider.deferredAuraIDs
      and provider.deferredAuraIDs[auraConfig.id] == true then
    return EvaluateGroupMissing(trigger, auraConfig, helpful, spellIDs)
  end

  local anyUnavailable = false
  local eligibleUnits, absentUnits = {}, {}
  local firstPresentState, matchedUnits, unitStates = nil, {}, {}
  for _, unit in ipairs(GetUnits(trigger)) do
    if UnitPassesFilters(unit, trigger) then
      eligibleUnits[#eligibleUnits + 1] = unit
      local unitAbsent = true
      for _, spellID in ipairs(spellIDs) do
        local auraData, availability = QueryAura(unit, spellID, helpful, trigger)
        if auraData then
          if trigger.auraFilter == "missing" then
            unitAbsent = false
            break
          end
          local presentState = BuildPresentState(auraData, unit, helpful, auraConfig)
          matchedUnits[#matchedUnits + 1] = unit
          unitStates[unit] = presentState
          firstPresentState = firstPresentState or presentState
          unitAbsent = false
          break
        elseif availability == "unavailable" then
          anyUnavailable = true
          unitAbsent = false
        end
      end
      if unitAbsent then absentUnits[#absentUnits + 1] = unit end
    end
  end

  if trigger.auraFilter == "missing" then
    if anyUnavailable then return BuildUnavailable(trigger, auraConfig, helpful, spellIDs[1]) end
    return BuildAbsent(trigger, auraConfig, helpful, spellIDs[1], #absentUnits > 0, absentUnits)
  end
  if firstPresentState then
    firstPresentState.matchedUnits = matchedUnits
    firstPresentState.unitStates = unitStates
    return firstPresentState
  end
  if anyUnavailable then return BuildUnavailable(trigger, auraConfig, helpful, spellIDs[1]) end
  return BuildAbsent(trigger, auraConfig, helpful, spellIDs[1], false, eligibleUnits)
end

local function HasImmediateConsumers(aura)
  if type(aura) ~= "table" then return true end
  if type(aura.actions) == "table" and next(aura.actions) ~= nil then return true end
  if type(aura.conditions) == "table" and next(aura.conditions) ~= nil then return true end
  local display = aura.display
  if type(display) == "table" and (display.soundEnabled == true
      or display.showOnRaidFrames == true) then
    return true
  end
  for _, trigger in ns.TriggerBase:IterateTriggers(aura) do
    if trigger.debug == true then return true end
  end
  return false
end

local function CanCoalesceGroupMissing(aura, selectedTrigger)
  -- A short delay is valid only when the aura and its ancestors consume final
  -- presentation state. Edge-sensitive actions, sounds, raid overlays,
  -- conditions, debug output, and multi-trigger combinations stay immediate.
  if type(aura) ~= "table" or type(selectedTrigger) ~= "table"
      or selectedTrigger.unit ~= "group" or selectedTrigger.auraFilter ~= "missing" then
    return false
  end
  if aura.kind ~= "icon" and aura.kind ~= "bar" and aura.kind ~= "text" then return false end

  local enabledCount = 0
  for _, trigger in ns.TriggerBase:IterateTriggers(aura) do
    enabledCount = enabledCount + 1
    if trigger ~= selectedTrigger then return false end
  end
  if enabledCount ~= 1 then return false end

  local current = aura
  local visited = {}
  while current do
    if visited[current] then return false end
    visited[current] = true
    if HasImmediateConsumers(current) then return false end
    current = current.parentId and ns.Registry:GetAura(current.parentId) or nil
  end
  return true
end

local function IsEditorOpen()
  return ns.ui and ns.ui.MainWindow and ns.ui.MainWindow.IsOpen
    and ns.ui.MainWindow:IsOpen() == true
end

function provider:GetUnitAuraRoutes(unit)
  if not self.byUnit then self:RebuildIndex() end
  local cached = self.unitAuraRoutes and self.unitAuraRoutes[unit]
  if cached then return cached.immediate, cached.deferred end

  local immediate, deferred = {}, {}
  for _, auraID in ipairs(self:GetAffectedAurasForUnit(unit)) do
    local target = self.deferredAuraIDs and self.deferredAuraIDs[auraID] and deferred or immediate
    target[#target + 1] = auraID
  end
  self.unitAuraRoutes[unit] = { immediate = immediate, deferred = deferred }
  return immediate, deferred
end

function provider:ScheduleDeferredAuraRefresh(auraIDs)
  if type(auraIDs) ~= "table" or #auraIDs == 0 or not (C_Timer and C_Timer.After) then
    return false
  end
  -- Queue configuration IDs only. Aura payloads and presence results are
  -- always queried fresh at execution time and never cross the secret boundary.
  self.pendingDeferredAuraIDs = self.pendingDeferredAuraIDs or {}
  for _, auraID in ipairs(auraIDs) do self.pendingDeferredAuraIDs[auraID] = true end
  if self.deferredRefreshPending then return true end

  self.deferredRefreshPending = true
  C_Timer.After(DEFERRED_GROUP_MISSING_SECONDS, function()
    provider.deferredRefreshPending = false
    local pending = provider.pendingDeferredAuraIDs or {}
    provider.pendingDeferredAuraIDs = {}
    local refreshIDs = {}
    for auraID in pairs(pending) do
      if provider.deferredAuraIDs and provider.deferredAuraIDs[auraID] then
        refreshIDs[#refreshIDs + 1] = auraID
      end
    end
    if #refreshIDs == 0 or not (ns.runtime and ns.runtime.RefreshAuras) then return end

    local profileStart = ns.Profiler and ns.Profiler.IsEnabled and ns.Profiler:IsEnabled()
      and ns.Profiler:Begin("provider_deferred:aura") or nil
    ns.runtime:RefreshAuras(refreshIDs)
    if profileStart and ns.Profiler and ns.Profiler.Finish then
      ns.Profiler:Finish("provider_deferred:aura", profileStart)
    end
  end)
  return true
end

function provider:RebuildIndex()
  self.byUnit, self.allAuraIDs = {}, {}
  self.eventUnits = {}
  self.affectedByUnit = {}
  self.unitAuraRoutes = {}
  self.deferredAuraIDs = {}
  self.compiledSpellIDsByTrigger = setmetatable({}, { __mode = "k" })
  local allSeen = {}
  local byUnitSeen = {}
  for _, auraID in ipairs(ns.Registry:GetFlatOrder()) do
    local aura = ns.Registry:GetAura(auraID)
    for _, trigger in ns.TriggerBase:IterateTriggers(aura, "aura") do
      if aura and aura.enabled ~= false and not allSeen[auraID] then
        allSeen[auraID] = true
        self.allAuraIDs[#self.allAuraIDs + 1] = auraID
      end

      local unit = trigger.unit or "player"
      if aura and aura.enabled ~= false and unit ~= "nameplate" then
        -- Native containers own aura presentation, but PopAuras still needs a
        -- scoped event for late CDM source binding and target/death invalidation.
        self.eventUnits[unit] = true
      end

      local nameplateManaged = ns.renderers and ns.renderers.NameplateAuraRegion
        and ns.renderers.NameplateAuraRegion:CanHandle(aura) or false
      local nativeManaged = ns.renderers and ns.renderers.NativeAuraRegion
        and ns.renderers.NativeAuraRegion:CanHandle(aura) or false
      local needsLogicalRefresh = not nativeManaged
        or (type(aura.actions) == "table" and next(aura.actions) ~= nil)
        or (type(aura.conditions) == "table" and next(aura.conditions) ~= nil)
        or (aura.display and (aura.display.showOnRaidFrames == true or aura.display.soundEnabled == true))
        or trigger.debug == true

      -- Nameplate buffs are presentation-only even when an unsupported logical
      -- consumer was imported with the aura.
      if nameplateManaged then
        needsLogicalRefresh = false
      end

      if aura and aura.enabled ~= false and needsLogicalRefresh
          and CanCoalesceGroupMissing(aura, trigger) then
        self.deferredAuraIDs[auraID] = true
        self.compiledSpellIDsByTrigger[trigger] = BuildSpellIDs(trigger)
      end

      -- Blizzard's native AuraContainer receives UNIT_AURA directly. Avoid a
      -- second PopAuras evaluation/render pass unless another feature consumes
      -- the logical activation state.
      if aura and aura.enabled ~= false and needsLogicalRefresh then
        self.byUnit[unit] = self.byUnit[unit] or {}
        byUnitSeen[unit] = byUnitSeen[unit] or {}
        if not byUnitSeen[unit][auraID] then
          byUnitSeen[unit][auraID] = true
          self.byUnit[unit][#self.byUnit[unit] + 1] = auraID
        end
      end
    end
  end
end

function provider:InvalidateCaches()
  self.byUnit = nil
  self.allAuraIDs = nil
  self.eventUnits = nil
  self.affectedByUnit = nil
  self.unitAuraRoutes = nil
  self.deferredAuraIDs = nil
  self.compiledSpellIDsByTrigger = nil
  self.pendingDeferredAuraIDs = {}
end

function provider:GetUnitEventUnits(event)
  if event ~= "UNIT_AURA" and event ~= "UNIT_FLAGS" then
    return false
  end
  if not self.eventUnits then self:RebuildIndex() end
  return self.eventUnits
end

function provider:GetAffectedAurasForUnit(unit)
  if not self.byUnit then self:RebuildIndex() end
  local cached = self.affectedByUnit and self.affectedByUnit[unit]
  if cached then return cached end

  local result, seen = {}, {}
  local function add(list)
    for _, auraID in ipairs(list or EMPTY) do
      if not seen[auraID] then
        seen[auraID] = true
        result[#result + 1] = auraID
      end
    end
  end
  add(self.byUnit[unit])
  if unit == "player" or unit:find("^party%d+$") or unit:find("^raid%d+$") then
    add(self.byUnit.group)
  end
  self.affectedByUnit[unit] = result
  return result
end

function provider:HandleEvent(event, ...)
  local unit
  if event == "UNIT_AURA" then
    unit = Safe:String((...))
    if unit and unit:find("^nameplate%d+$") then
      return
    end
    if unit and ns.runtime and ns.runtime.RefreshNativeAuraSources then
      ns.runtime:RefreshNativeAuraSources(unit)
    end
    return
  elseif event == "PLAYER_TARGET_CHANGED" then
    unit = "target"
  elseif event == "UNIT_FLAGS" then
    unit = Safe:String((...))
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "SPELLS_CHANGED" then
    self:InvalidateCaches()
    return
  end

  -- Blizzard's managed AuraContainer subscribes to UNIT_AURA itself, but a
  -- unit token such as "target" can start referring to a different GUID
  -- without the token string changing. SetUnit("target") is consequently a
  -- no-op. Blizzard exposes UpdateAllAuras specifically for external target
  -- changes, and UNIT_FLAGS gives us a cheap full rebuild when that target
  -- dies without adding a high-frequency health-event path. UNIT_AURA above
  -- performs only a lightweight late-CDM-source bind, not a container rebuild.
  if unit and ns.runtime and ns.runtime.RefreshNativeAuraContainers then
    ns.runtime:RefreshNativeAuraContainers(unit)
  end
end

function provider:GetAffectedAuras(event, ...)
  if not self.byUnit then self:RebuildIndex() end
  if event == "PLAYER_TARGET_CHANGED" then return self.byUnit.target or {} end
  if event == "GROUP_ROSTER_UPDATE" then return self.byUnit.group or {} end
  if event == "PLAYER_ENTERING_WORLD" then return self.allAuraIDs end
  if event == "UNIT_AURA" or event == "UNIT_FLAGS" then
    local unit = Safe:String((...))
    -- Secret aura payloads do not make the UNIT_AURA unit token unusable.
    -- Refreshing every configured aura here creates an event storm in combat;
    -- if a future client does hide the token, native containers still update
    -- themselves and logical evaluation must wait for a scoped/global event.
    if not unit then return EMPTY end
    if event == "UNIT_AURA" and not IsEditorOpen() then
      local immediate, deferred = self:GetUnitAuraRoutes(unit)
      if self:ScheduleDeferredAuraRefresh(deferred) then return immediate end
    end
    return self:GetAffectedAurasForUnit(unit)
  end
  return self.allAuraIDs
end
