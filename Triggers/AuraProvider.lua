local _, ns = ...

local Safe = ns.SafeValues
local Duration = ns.Duration
local EMPTY = {}

local provider = ns.TriggerBase:CreateProvider("aura", {
  events = {
    "UNIT_AURA",
    "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "UNIT_FLAGS",
    "PLAYER_ENTERING_WORLD",
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

local function GetSpellIDs(trigger)
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

function provider:RebuildIndex()
  self.byUnit, self.allAuraIDs = {}, {}
  for _, auraID in ipairs(ns.Registry:GetFlatOrder()) do
    local aura = ns.Registry:GetAura(auraID)
    for _, trigger in ns.TriggerBase:IterateTriggers(aura, "aura") do
      self.allAuraIDs[#self.allAuraIDs + 1] = auraID

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

      -- Blizzard's native AuraContainer receives UNIT_AURA directly. Avoid a
      -- second PopAuras evaluation/render pass unless another feature consumes
      -- the logical activation state.
      if needsLogicalRefresh then
        local unit = trigger.unit or "player"
        self.byUnit[unit] = self.byUnit[unit] or {}
        self.byUnit[unit][#self.byUnit[unit] + 1] = auraID
      end
    end
  end
end

function provider:InvalidateCaches()
  self.byUnit = nil
  self.allAuraIDs = nil
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
    local result, seen = {}, {}
    local function add(list)
      for _, auraID in ipairs(list or EMPTY) do
        if not seen[auraID] then seen[auraID] = true result[#result + 1] = auraID end
      end
    end
    add(self.byUnit[unit])
    if unit == "player" or unit:find("^party") or unit:find("^raid") then add(self.byUnit.group) end
    return result
  end
  return self.allAuraIDs
end
