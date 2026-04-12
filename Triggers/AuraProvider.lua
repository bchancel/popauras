local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("aura", {
  events = {
    "UNIT_AURA",
    "UNIT_FLAGS",
    "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "UNIT_SPELLCAST_SUCCEEDED",
  },
})

local function IterateAuraTriggers(aura)
  return ns.TriggerBase:IterateTriggers(aura, "aura")
end

local Strings = ns.util.Strings

provider.pendingTargetAuras = provider.pendingTargetAuras or {}
provider.cachedTargetAuras = provider.cachedTargetAuras or {}
provider.learnedTargetDurations = provider.learnedTargetDurations or {}

local TARGET_CACHE_TTL = 45
local MAX_TARGET_CACHE_ENTRIES = 8
local CACHE_PRUNE_INTERVAL = 5
local REAL_TIME_MODIFIER = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime or nil
local spellIDsCache = setmetatable({}, { __mode = "k" })
local spellNamesCache = setmetatable({}, { __mode = "k" })

local function GetLearnedTargetDurations()
  ns.session = ns.session or {}
  ns.session.learnedTargetDurations = ns.session.learnedTargetDurations or {}
  provider.learnedTargetDurations = ns.session.learnedTargetDurations
  return provider.learnedTargetDurations
end

local function GetSpellIDs(trigger)
  trigger = trigger or {}
  local signatureParts = { tostring(tonumber(trigger.spellId or 0) or 0) }
  if type(trigger.spellIDs) == "table" then
    for _, value in ipairs(trigger.spellIDs) do
      signatureParts[#signatureParts + 1] = tostring(tonumber(value or 0) or 0)
    end
  end
  local signature = table.concat(signatureParts, ",")
  local cached = spellIDsCache[trigger]
  if cached and cached.signature == signature then
    return cached.ids
  end

  local ids = {}
  local seen = {}
  if type(trigger.spellIDs) == "table" then
    for _, value in ipairs(trigger.spellIDs) do
      local spellId = tonumber(value or 0) or 0
      if spellId > 0 and not seen[spellId] then
        seen[spellId] = true
        ids[#ids + 1] = spellId
      end
    end
  end
  local primary = tonumber(trigger.spellId or 0) or 0
  if primary > 0 and not seen[primary] then
    ids[#ids + 1] = primary
  end
  spellIDsCache[trigger] = {
    signature = signature,
    ids = ids,
  }
  return ids
end

local function GetSpellNames(trigger)
  trigger = trigger or {}
  local signatureParts = {}
  if type(trigger.spellNames) == "table" then
    for _, value in ipairs(trigger.spellNames) do
      signatureParts[#signatureParts + 1] = tostring(value or "")
    end
  end
  local signature = table.concat(signatureParts, ",")
  local cached = spellNamesCache[trigger]
  if cached and cached.signature == signature then
    return cached.names
  end

  local names = {}
  local seen = {}
  if type(trigger.spellNames) == "table" then
    for _, value in ipairs(trigger.spellNames) do
      local key = tostring(value or ""):lower()
      if key ~= "" and not seen[key] then
        seen[key] = true
        names[#names + 1] = key
      end
    end
  end
  spellNamesCache[trigger] = {
    signature = signature,
    names = names,
  }
  return names
end

local function SafeLower(value)
  if type(value) == "string" and not (issecretvalue and issecretvalue(value)) then
    return value:lower()
  end
  return nil
end

local function SafeSpellID(value)
  if value and not (issecretvalue and issecretvalue(value)) then
    return tonumber(value)
  end
  return nil
end

local function SafeAuraNumber(value, fallback)
  if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
    return value
  end
  return fallback
end

local function SafeAuraBoolean(value)
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "boolean" then
    return value
  end
  return nil
end

local function SafeAuraString(value)
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "string" then
    return value
  end
  return nil
end

local function PickDisplayValue(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    if issecretvalue and issecretvalue(value) then
      return value
    end
    local valueType = type(value)
    if valueType == "number" or valueType == "string" then
      return value
    end
  end
  return nil
end

local function BuildStackDisplayValue(rawValue, safeText, safeNumber, allowZero)
  if issecretvalue and issecretvalue(rawValue) then
    return rawValue, true
  end

  local rawType = type(rawValue)
  if rawType == "string" then
    if rawValue ~= "" or allowZero == true then
      return rawValue, true
    end
  elseif rawType == "number" then
    if allowZero == true or rawValue > 0 then
      return rawValue, true
    end
  end

  if type(safeText) == "string" and (safeText ~= "" or allowZero == true) then
    return safeText, true
  end
  if type(safeNumber) == "number" and (allowZero == true or safeNumber > 0) then
    return safeNumber, true
  end

  return nil, false
end

local function SafeUnitGUID(unit)
  if not UnitGUID then
    return nil
  end
  local guid = UnitGUID(unit)
  if guid and not (issecretvalue and issecretvalue(guid)) then
    return guid
  end
  return nil
end

local function CallDurationObjectMethod(durationObject, methodName)
  if not durationObject then
    return nil
  end

  local method = durationObject[methodName]
  if type(method) ~= "function" then
    return nil
  end

  local ok, value
  if REAL_TIME_MODIFIER ~= nil then
    ok, value = pcall(method, durationObject, REAL_TIME_MODIFIER)
  else
    ok, value = pcall(method, durationObject)
  end

  if not ok then
    return nil
  end

  return SafeAuraNumber(value, nil)
end

local function GetSecretSafeAuraTiming(unit, auraInstanceID, auraData)
  local duration = 0
  local expirationTime = 0
  local durationObject = nil
  local now = GetTime()

  if C_UnitAuras and C_UnitAuras.GetAuraDurationRemaining and auraInstanceID then
    local ok, remaining = pcall(C_UnitAuras.GetAuraDurationRemaining, unit, auraInstanceID)
    remaining = ok and SafeAuraNumber(remaining, nil) or nil
    if remaining and remaining > 0 then
      expirationTime = now + remaining
    end
  end

  if C_UnitAuras and C_UnitAuras.GetAuraDuration and auraInstanceID then
    local ok, rawDurationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
    if ok and rawDurationObject then
      durationObject = rawDurationObject
      local totalDuration = CallDurationObjectMethod(rawDurationObject, "GetTotalDuration")
      local remaining = CallDurationObjectMethod(rawDurationObject, "GetRemainingDuration")
      local startTime = CallDurationObjectMethod(rawDurationObject, "GetStartTime")
      local endTime = CallDurationObjectMethod(rawDurationObject, "GetEndTime")
      if totalDuration and totalDuration > 0 then
        duration = totalDuration
      end
      if remaining and remaining > 0 then
        expirationTime = now + remaining
      elseif endTime and endTime > now then
        expirationTime = endTime
      elseif startTime and duration and duration > 0 then
        expirationTime = startTime + duration
      end
      if duration <= 0 and startTime and endTime and endTime > startTime then
        duration = endTime - startTime
      end
      if type(rawDurationObject) == "table" then
        duration = SafeAuraNumber(rawDurationObject.duration, duration)
        remaining = SafeAuraNumber(rawDurationObject.remainingTime, remaining)
        startTime = SafeAuraNumber(rawDurationObject.startTime, startTime)
        if remaining and remaining > 0 then
          expirationTime = now + remaining
        elseif startTime and duration and duration > 0 then
          expirationTime = startTime + duration
        end
      end
    end
  end

  if duration <= 0 and C_UnitAuras and C_UnitAuras.GetAuraBaseDuration and auraInstanceID and unit then
    local ok, baseDuration = pcall(C_UnitAuras.GetAuraBaseDuration, unit, auraInstanceID, SafeSpellID(auraData and auraData.spellId))
    duration = ok and SafeAuraNumber(baseDuration, duration) or duration
  end

  if duration <= 0 then
    duration = SafeAuraNumber(auraData and auraData.duration, 0)
  end
  if expirationTime <= 0 then
    expirationTime = SafeAuraNumber(auraData and auraData.expirationTime, 0)
  end

  if duration <= 0 and expirationTime > now then
    duration = expirationTime - now
  end

  return duration or 0, expirationTime or 0, durationObject
end

local function GetSecretSafeAuraStacks(unit, auraInstanceID, auraData)
  local liveAuraData = auraData
  if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID and unit and auraInstanceID then
    local ok, refreshedAuraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
    if ok and refreshedAuraData then
      liveAuraData = refreshedAuraData
    end
  end

  local stacks = SafeAuraNumber(liveAuraData and liveAuraData.applications,
    SafeAuraNumber(liveAuraData and liveAuraData.charges,
      SafeAuraNumber(auraData and auraData.applications, SafeAuraNumber(auraData and auraData.charges, 0))))
  local stackText = (stacks and stacks > 0) and tostring(stacks) or nil
  local rawStackValue = PickDisplayValue(
    liveAuraData and liveAuraData.applications,
    liveAuraData and liveAuraData.charges,
    auraData and auraData.applications,
    auraData and auraData.charges
  )

  if C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount and auraInstanceID then
    local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 0)
    if ok and not (issecretvalue and issecretvalue(count)) then
      if type(count) == "string" then
        local displayText = count ~= "" and count or nil
        if displayText ~= nil then
          local numeric = tonumber(displayText)
          if numeric ~= nil then
            local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, displayText, numeric, false)
            return numeric, displayText, stackDisplayValue, hasStackDisplayValue
          end
          local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, displayText, stacks or 0, false)
          return stacks or 0, displayText, stackDisplayValue, hasStackDisplayValue
        end
      elseif type(count) == "number" and count > 0 then
        local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, tostring(count), count, false)
        return count, tostring(count), stackDisplayValue, hasStackDisplayValue
      end
    end
  end
  local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, stackText, stacks, false)
  return stacks, stackText, stackDisplayValue, hasStackDisplayValue
end

local function ScanLegacyUnitAuras(unit, isHelpful, spellIDs, spellNames, collectOnly, maxSummary)
  local wantedIDs = {}
  for _, spellId in ipairs(spellIDs or {}) do
    wantedIDs[spellId] = true
  end
  local wantedNames = {}
  for _, spellName in ipairs(spellNames or {}) do
    wantedNames[spellName] = true
  end

  local summary = {}
  local index = 1
  local reader = isHelpful and UnitBuff or UnitDebuff
  while reader do
    local name, icon, applications, _, duration, expirationTime, sourceUnit, _, _, spellId = reader(unit, index)
    if not name then
      break
    end
    local lowerName = SafeLower(name)
    local safeSpellId = SafeSpellID(spellId)
    if #summary < (maxSummary or 10) then
      summary[#summary + 1] = string.format("%s(%s)", tostring(name), tostring(safeSpellId or "?"))
    end
    if not collectOnly and ((safeSpellId and wantedIDs[safeSpellId]) or (lowerName and wantedNames[lowerName])) then
      return {
        name = name,
        icon = icon,
        applications = applications,
        duration = duration,
        expirationTime = expirationTime,
        sourceUnit = sourceUnit,
        spellId = safeSpellId,
      }, summary
    end
    index = index + 1
  end

  return nil, summary
end

local function ScanModernUnitAuras(unit, isHelpful, spellIDs, spellNames, collectOnly, maxSummary)
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
    return nil, {}
  end

  local wantedIDs = {}
  for _, spellId in ipairs(spellIDs or {}) do
    wantedIDs[spellId] = true
  end
  local wantedNames = {}
  for _, spellName in ipairs(spellNames or {}) do
    wantedNames[spellName] = true
  end

  local summary = {}
  local filter = isHelpful and "HELPFUL" or "HARMFUL"
  local index = 1
  while true do
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    if not aura then
      break
    end
    local auraSpellId = SafeSpellID(aura.spellId)
    local auraName = aura.name
    local lowerName = SafeLower(auraName)
    if #summary < (maxSummary or 10) then
      summary[#summary + 1] = string.format("%s(%s)", tostring(lowerName and auraName or "?"), tostring(auraSpellId or "?"))
    end
    if not collectOnly and ((auraSpellId and wantedIDs[auraSpellId]) or (lowerName and wantedNames[lowerName])) then
      return aura, summary
    end
    index = index + 1
  end

  return nil, summary
end

local function FindAura(unit, spellIDs, spellNames, isHelpful)
  if not unit or type(spellIDs) ~= "table" or #spellIDs == 0 then
    if type(spellNames) ~= "table" or #spellNames == 0 then
      return nil
    end
  end

  local filter = isHelpful and "HELPFUL" or "HARMFUL"
  if AuraUtil and AuraUtil.FindAuraBySpellID then
    for _, spellId in ipairs(spellIDs) do
      local aura = AuraUtil.FindAuraBySpellID(spellId, unit, filter)
      if aura then
        return aura
      end
    end
  end

  local legacyAura = ScanLegacyUnitAuras(unit, isHelpful, spellIDs, spellNames, false)
  if legacyAura then
    return legacyAura
  end

  local modernAura = ScanModernUnitAuras(unit, isHelpful, spellIDs, spellNames, false)
  if modernAura then
    return modernAura
  end

  return nil
end

local function BuildAuraSummary(unit, isHelpful)
  local legacySummary = select(2, ScanLegacyUnitAuras(unit, isHelpful, {}, {}, true, 8))
  local modernSummary = select(2, ScanModernUnitAuras(unit, isHelpful, {}, {}, true, 8))
  return string.format("legacy=[%s] modern=[%s]",
    table.concat(legacySummary or {}, ", "),
    table.concat(modernSummary or {}, ", "))
end

local function IterateUnits(unitMode)
  if unitMode == "group" then
    local units = {}
    local seen = {}

    local function AddUnit(unit)
      if not unit or unit == "" or not UnitExists or not UnitExists(unit) then
        return
      end
      local key = SafeUnitGUID(unit) or unit
      if seen[key] then
        return
      end
      seen[key] = true
      units[#units + 1] = unit
    end

    AddUnit("player")

    if IsInRaid and IsInRaid() then
      local memberCount = GetNumGroupMembers and GetNumGroupMembers() or 0
      for index = 1, memberCount do
        AddUnit("raid" .. tostring(index))
      end
    elseif IsInGroup and IsInGroup() then
      local memberCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
      for index = 1, memberCount do
        AddUnit("party" .. tostring(index))
      end
    end

    return units
  end

  if unitMode == "nameplate" then
    local units = {}
    if C_NamePlate and C_NamePlate.GetNamePlates then
      for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unitToken = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unitToken then
          units[#units + 1] = unitToken
        end
      end
    end
    return units
  end
  return { unitMode or "player" }
end

local function IsGroupUnitToken(unit)
  if unit == "player" then
    return true
  end
  if type(unit) ~= "string" then
    return false
  end
  return unit:match("^party%d+$") ~= nil or unit:match("^raid%d+$") ~= nil
end

local function TriggerUsesUnit(triggerUnit, requestedUnit)
  triggerUnit = triggerUnit or "player"
  if not requestedUnit then
    return true
  end
  if requestedUnit == "group" then
    return triggerUnit == "group"
  end
  if triggerUnit == "group" then
    return IsGroupUnitToken(requestedUnit)
  end
  return triggerUnit == requestedUnit
end

local function UnitPassesAliveFilter(unit, aliveOnly)
  if not unit or unit == "" then
    return false
  end
  if not aliveOnly then
    return true
  end
  if UnitExists and not UnitExists(unit) then
    return false
  end
  if UnitIsConnected and UnitIsConnected(unit) == false then
    return false
  end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
    return false
  end
  return true
end

local function UnitPassesNPCFilter(unit, trigger)
  if not trigger or trigger.unit ~= "group" or trigger.ignoreNPCs ~= true then
    return true
  end
  if unit == "player" then
    return true
  end
  if not IsGroupUnitToken(unit) then
    return true
  end
  if UnitIsPlayer then
    return UnitIsPlayer(unit) == true
  end
  return true
end

local function NormalizeRangeResult(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end

  local valueType = type(value)
  if valueType == "boolean" then
    return value
  end
  if valueType == "number" then
    if value == 1 then
      return true
    end
    if value == 0 then
      return false
    end
  end
  return nil
end

local function QueryUnitInRange(unit)
  if not UnitInRange then
    return nil
  end

  local inRange, checkedRange = UnitInRange(unit)
  if issecretvalue and (issecretvalue(inRange) or issecretvalue(checkedRange)) then
    return nil
  end

  if checkedRange == false then
    return nil
  end

  return NormalizeRangeResult(inRange)
end

local function UnitPassesInstanceFilter(unit, trigger)
  if not trigger or trigger.unit ~= "group" then
    return true
  end
  if unit == "player" then
    return true
  end
  if not IsGroupUnitToken(unit) then
    return true
  end
  if UnitExists and not UnitExists(unit) then
    return false
  end
  if UnitIsConnected and UnitIsConnected(unit) == false then
    return false
  end

  local playerX, playerY, playerZ, playerInstance = UnitPosition and UnitPosition("player")
  local unitX, unitY, unitZ, unitInstance = UnitPosition and UnitPosition(unit)
  if playerInstance and unitInstance then
    return playerInstance == unitInstance
  end

  return true
end

local function NormalizeAuraRangeMode(rangeMode)
  if rangeMode == "nearby" or rangeMode == "spell" then
    return "in_range"
  end
  if rangeMode == "in_range" then
    return "in_range"
  end
  return "any"
end

local function QueryConfiguredSpellRange(unit, trigger)
  if not trigger or trigger.unit ~= "group" or not C_Spell or not C_Spell.IsSpellInRange then
    return nil
  end

  for _, spellId in ipairs(GetSpellIDs(trigger)) do
    local ok, inRange = pcall(C_Spell.IsSpellInRange, spellId, unit)
    if ok and not (issecretvalue and issecretvalue(inRange)) then
      inRange = NormalizeRangeResult(inRange)
      if inRange ~= nil then
        return inRange
      end
    end
  end

  return nil
end

local function QueryInteractRange(unit)
  if not CheckInteractDistance or (InCombatLockdown and InCombatLockdown()) then
    return nil
  end

  local ok, inRange = pcall(CheckInteractDistance, unit, 4)
  if not ok or (issecretvalue and issecretvalue(inRange)) then
    return nil
  end
  if inRange == true then
    return true
  end
  return nil
end

local function IsUnitWithinRange(unit, trigger, maxDistance)
  local unitInRange = QueryUnitInRange(unit)
  if unitInRange == true then
    return true
  end

  local spellRange = QueryConfiguredSpellRange(unit, trigger)
  if spellRange ~= nil then
    return spellRange
  end

  local interactRange = QueryInteractRange(unit)
  if interactRange ~= nil then
    return interactRange
  end

  maxDistance = tonumber(maxDistance or 0) or 0
  if maxDistance > 0 and UnitPosition then
    local playerX, playerY, _, playerInstance = UnitPosition("player")
    local unitX, unitY, _, unitInstance = UnitPosition(unit)
    if playerX and playerY and unitX and unitY and playerInstance and unitInstance and playerInstance == unitInstance then
      local deltaX = playerX - unitX
      local deltaY = playerY - unitY
      return ((deltaX * deltaX) + (deltaY * deltaY)) <= (maxDistance * maxDistance)
    end
  end

  return unitInRange
end

local function UnitPassesRangeFilter(unit, trigger)
  if not trigger or trigger.unit ~= "group" then
    return true
  end
  if unit == "player" then
    return true
  end
  if not IsGroupUnitToken(unit) then
    return true
  end

  local rangeMode = NormalizeAuraRangeMode(trigger.groupRange or "any")
  if rangeMode == "any" then
    return true
  end

  local inRange = IsUnitWithinRange(unit, trigger, 40)
  if inRange ~= nil then
    return inRange
  end

  return rangeMode ~= "in_range"
end

local function UnitPassesAuraFilters(unit, trigger, aliveOnly)
  return UnitPassesAliveFilter(unit, aliveOnly)
    and UnitPassesNPCFilter(unit, trigger)
    and UnitPassesInstanceFilter(unit, trigger)
    and UnitPassesRangeFilter(unit, trigger)
end

local function BuildAuraFilterTrace(unit, trigger, aliveOnly)
  local trace = {}

  local alivePass = UnitPassesAliveFilter(unit, aliveOnly)
  trace[#trace + 1] = string.format("alive=%s", tostring(alivePass))
  if not alivePass then
    return table.concat(trace, ",")
  end

  local npcPass = UnitPassesNPCFilter(unit, trigger)
  trace[#trace + 1] = string.format("npc=%s", tostring(npcPass))
  if not npcPass then
    return table.concat(trace, ",")
  end

  local instancePass = UnitPassesInstanceFilter(unit, trigger)
  trace[#trace + 1] = string.format("instance=%s", tostring(instancePass))
  if not instancePass then
    return table.concat(trace, ",")
  end

  local rangePass = UnitPassesRangeFilter(unit, trigger)
  trace[#trace + 1] = string.format("range=%s", tostring(rangePass))
  if not rangePass then
    if UnitInRange then
      local inRange, checkedRange = nil, nil
      inRange, checkedRange = UnitInRange(unit)
      if issecretvalue and (issecretvalue(inRange) or issecretvalue(checkedRange)) then
        trace[#trace + 1] = "unitInRange=secret"
      else
        trace[#trace + 1] = string.format("unitInRange=%s/%s", tostring(inRange), tostring(checkedRange))
      end
    end
    local spellRange = QueryConfiguredSpellRange(unit, trigger)
    trace[#trace + 1] = string.format("spellRange=%s", tostring(spellRange))
    local interactRange = QueryInteractRange(unit)
    trace[#trace + 1] = string.format("interactRange=%s", tostring(interactRange))
    if UnitPosition then
      local playerX, playerY, _, playerInstance = UnitPosition("player")
      local unitX, unitY, _, unitInstance = UnitPosition(unit)
      playerX = SafeAuraNumber(playerX, nil)
      playerY = SafeAuraNumber(playerY, nil)
      unitX = SafeAuraNumber(unitX, nil)
      unitY = SafeAuraNumber(unitY, nil)
      if issecretvalue and issecretvalue(playerInstance) then
        playerInstance = nil
      end
      if issecretvalue and issecretvalue(unitInstance) then
        unitInstance = nil
      end
      if playerX and playerY and unitX and unitY and playerInstance and unitInstance and playerInstance == unitInstance then
        local deltaX = playerX - unitX
        local deltaY = playerY - unitY
        local distance = math.sqrt((deltaX * deltaX) + (deltaY * deltaY))
        trace[#trace + 1] = string.format("distance=%.2f", distance)
      else
        trace[#trace + 1] = "distance=?"
      end
    end
  end

  return table.concat(trace, ",")
end

local function TriggerMatchesSpell(trigger, spellID)
  spellID = tonumber(spellID or 0) or 0
  if spellID > 0 then
    for _, configuredID in ipairs(GetSpellIDs(trigger)) do
      if configuredID == spellID then
        return true
      end
    end
  end

  local castName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
  local castKey = SafeLower(castName)
  if castKey then
    for _, configuredName in ipairs(GetSpellNames(trigger)) do
      if configuredName == castKey then
        return true
      end
    end
  end

  return false
end

local function TriggerMatchesAuraData(trigger, auraData)
  if not trigger or not auraData then
    return false
  end

  local auraSpellId = SafeSpellID(auraData.spellId)
  if auraSpellId and auraSpellId > 0 then
    for _, configuredID in ipairs(GetSpellIDs(trigger)) do
      if configuredID == auraSpellId then
        return true
      end
    end
  end

  local auraName = SafeLower(auraData.name)
  if auraName then
    for _, configuredName in ipairs(GetSpellNames(trigger)) do
      if configuredName == auraName then
        return true
      end
    end
  end

  return false
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

local function GetPreferredAuraName(trigger, auraConfig)
  if C_Spell and C_Spell.GetSpellName then
    for _, spellId in ipairs(GetSpellIDs(trigger)) do
      local spellName = C_Spell.GetSpellName(spellId)
      if spellName and spellName ~= "" then
        return spellName
      end
    end
  end
  if type(trigger and trigger.spellNames) == "table" then
    for _, spellName in ipairs(trigger.spellNames) do
      if type(spellName) == "string" and spellName ~= "" then
        return spellName
      end
    end
  end
  for _, spellName in ipairs(GetSpellNames(trigger)) do
    if spellName and spellName ~= "" then
      return spellName:gsub("^%l", string.upper)
    end
  end
  if auraConfig and auraConfig.name and auraConfig.name ~= "" then
    return auraConfig.name
  end
  return "Aura"
end

local function GetPreferredAuraIcon(trigger)
  if C_Spell and C_Spell.GetSpellTexture then
    for _, spellId in ipairs(GetSpellIDs(trigger)) do
      local icon = C_Spell.GetSpellTexture(spellId)
      if icon then
        return icon
      end
    end
  end
  return nil
end

local function GetSafeUnitDisplayName(unit)
  if not unit or not (Strings and Strings.GetSafeUnitDisplayName) then
    return nil
  end
  return Strings.GetSafeUnitDisplayName(unit, false)
end

local function GetSafeAuraIcon(auraData, trigger)
  local icon = SafeAuraNumber(auraData and auraData.icon, nil)
  if icon then
    return icon
  end
  return GetPreferredAuraIcon(trigger)
end

local function BuildMissingState(trigger, auraConfig, helpful, unit, missingUnit, missingCount)
  local preferredName = GetPreferredAuraName(trigger, auraConfig)
  local missingLabel = helpful and "Missing Buff" or "Missing Debuff"
  local missingName = GetSafeUnitDisplayName(missingUnit)
  local safeMissingCount = tonumber(missingCount or 0) or 0
  local stackText = safeMissingCount > 0 and tostring(safeMissingCount) or nil
  local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(PickDisplayValue(stackText, safeMissingCount), stackText, safeMissingCount, false)
  local statusText = missingLabel

  if unit == "group" and missingName and safeMissingCount > 1 then
    statusText = string.format("%s (+%d)", missingName, safeMissingCount - 1)
  elseif unit == "group" and missingName then
    statusText = missingName
  end

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    matched = true,
    active = true,
    icon = GetPreferredAuraIcon(trigger),
    name = preferredName,
    stacks = safeMissingCount,
    stackText = stackText,
    stackDisplayValue = stackDisplayValue,
    hasStackDisplayValue = hasStackDisplayValue,
    duration = 0,
    expirationTime = 0,
    progressType = "static",
    value = 0,
    total = 0,
    unit = missingUnit or unit,
    source = "aura",
    statusText = statusText,
  })
end

local function BuildSatisfiedState(trigger, auraConfig, helpful, unit, matchedUnit)
  local shouldShowSatisfied = trigger and trigger.showAlways == true
  return ns.Schema.NormalizeRuntimeState({
    show = shouldShowSatisfied,
    matched = false,
    active = false,
    isReady = shouldShowSatisfied,
    icon = shouldShowSatisfied and GetPreferredAuraIcon(trigger) or nil,
    name = shouldShowSatisfied and GetPreferredAuraName(trigger, auraConfig) or "",
    duration = 0,
    expirationTime = 0,
    progressType = "static",
    value = 0,
    total = 0,
    unit = matchedUnit or unit,
    source = "aura",
    statusText = helpful and "Buff Present" or "Debuff Present",
  })
end

local function BuildFilteredOutState(unit)
  return ns.Schema.NormalizeRuntimeState({
    show = false,
    matched = false,
    active = false,
    duration = 0,
    expirationTime = 0,
    progressType = "static",
    value = 0,
    total = 0,
    unit = unit,
    source = "aura",
    statusText = "",
  })
end

local function BuildStateFromAuraData(auraData, matchedUnit, helpful, fallbackName, trigger)
  if not auraData then
    return nil
  end
  local auraInstanceID = auraData.auraInstanceID
  local duration, expirationTime, durationObject = GetSecretSafeAuraTiming(matchedUnit, auraInstanceID, auraData)
  local stacks, stackText, stackDisplayValue, hasStackDisplayValue = GetSecretSafeAuraStacks(matchedUnit, auraInstanceID, auraData)
  if (stacks or 0) <= 0 and trigger and matchedUnit then
    local legacyNames = {}
    local seenLegacyNames = {}
    for _, configuredName in ipairs(GetSpellNames(trigger)) do
      if configuredName ~= "" and not seenLegacyNames[configuredName] then
        seenLegacyNames[configuredName] = true
        legacyNames[#legacyNames + 1] = configuredName
      end
    end
    local liveAuraName = SafeLower(auraData.name)
    if liveAuraName and not seenLegacyNames[liveAuraName] then
      seenLegacyNames[liveAuraName] = true
      legacyNames[#legacyNames + 1] = liveAuraName
    end
    local fallbackAuraName = SafeLower(fallbackName)
    if fallbackAuraName and not seenLegacyNames[fallbackAuraName] then
      seenLegacyNames[fallbackAuraName] = true
      legacyNames[#legacyNames + 1] = fallbackAuraName
    end

    local legacyAura = ScanLegacyUnitAuras(matchedUnit, helpful, GetSpellIDs(trigger), legacyNames, false)
    local legacyStacks = SafeAuraNumber(legacyAura and legacyAura.applications, 0)
    if legacyStacks and legacyStacks > 0 then
      stacks = legacyStacks
      stackText = tostring(legacyStacks)
      stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(PickDisplayValue(legacyAura and legacyAura.applications), stackText, legacyStacks, false)
    end
  end
  local auraName = SafeAuraString(auraData.name)
  local auraSpellId = auraData.spellId
  if issecretvalue and issecretvalue(auraSpellId) then
    auraSpellId = nil
  end
  return ns.Schema.NormalizeRuntimeState({
    show = true,
    matched = true,
    active = true,
    icon = GetSafeAuraIcon(auraData, trigger),
    name = auraName or fallbackName or "",
    stacks = stacks,
    stackText = stackText,
    stackDisplayValue = stackDisplayValue,
    hasStackDisplayValue = hasStackDisplayValue,
    duration = duration,
    expirationTime = expirationTime,
    durationObject = durationObject,
    progressType = (durationObject ~= nil or duration > 0 or expirationTime > GetTime()) and "timed" or "static",
    value = duration,
    total = duration,
    unit = matchedUnit,
    auraInstanceID = auraInstanceID,
    spellId = auraSpellId,
    source = "aura",
    statusText = helpful and "Buff" or "Debuff",
  })
end

local function ApplyCDMAuraTiming(state, cdmState)
  if not state or type(cdmState) ~= "table" then
    return state, false
  end

  local now = GetTime()
  local durationObject = cdmState.durationObject
  local duration = tonumber(cdmState.duration or 0) or 0
  local expirationTime = tonumber(cdmState.expirationTime or 0) or 0
  local hasNumericTiming = duration > 0 and expirationTime > now
  local hasCDMTimer = durationObject ~= nil or hasNumericTiming

  if not hasCDMTimer then
    return state, false
  end

  state.duration = hasNumericTiming and duration or 0
  state.expirationTime = hasNumericTiming and expirationTime or 0
  state.durationObject = durationObject
  state.progressType = "timed"
  state.value = state.duration
  state.total = state.duration
  state.source = "cdm_aura"

  local countText = cdmState.countText
  local count = tonumber(cdmState.count or "") or tonumber(countText or "")
  if (state.stacks or 0) <= 0 and count and count > 0 then
    state.stacks = count
  end
  if (not state.stackText or state.stackText == "") and countText and countText ~= "" then
    state.stackText = countText
  end

  return ns.Schema.NormalizeRuntimeState(state), true
end

local function CloneRuntimeState(state)
  if not state then
    return nil
  end
  return ns.Schema.NormalizeRuntimeState({
    show = state.show,
    matched = state.matched,
    active = state.active,
    icon = state.icon,
    name = state.name,
    stacks = state.stacks,
    stackText = state.stackText,
    stackDisplayValue = state.stackDisplayValue,
    hasStackDisplayValue = state.hasStackDisplayValue,
    duration = state.duration,
    expirationTime = state.expirationTime,
    durationObject = state.durationObject,
    progressType = state.progressType,
    value = state.value,
    total = state.total,
    isUsable = state.isUsable,
    isReady = state.isReady,
    unit = state.unit,
    auraInstanceID = state.auraInstanceID,
    spellId = state.spellId,
    itemId = state.itemId,
    source = state.source,
    statusText = state.statusText,
    color = state.color,
    desaturate = state.desaturate,
    glow = state.glow,
  })
end

local function GetAuraTargetCache(auraConfig)
  if not auraConfig or not auraConfig.id then
    return nil
  end
  provider.cachedTargetAuras[auraConfig.id] = provider.cachedTargetAuras[auraConfig.id] or { byGUID = {} }
  provider.cachedTargetAuras[auraConfig.id].byGUID = provider.cachedTargetAuras[auraConfig.id].byGUID or {}
  return provider.cachedTargetAuras[auraConfig.id]
end

local function PruneTargetCache(cache, now)
  if type(cache) ~= "table" or type(cache.byGUID) ~= "table" then
    return
  end

  now = now or GetTime()
  local staleBefore = now - TARGET_CACHE_TTL
  local candidates = {}

  for targetGUID, entry in pairs(cache.byGUID) do
    local touchedAt = tonumber(entry and (entry.lastSeenAt or entry.updatedAt or entry.castAt) or 0) or 0
    local expirationTime = tonumber(entry and entry.lastExpirationTime or 0) or 0
    if touchedAt > 0 and touchedAt < staleBefore and expirationTime <= now then
      cache.byGUID[targetGUID] = nil
    else
      candidates[#candidates + 1] = {
        targetGUID = targetGUID,
        score = math.max(touchedAt, expirationTime),
      }
    end
  end

  if #candidates <= MAX_TARGET_CACHE_ENTRIES then
    return
  end

  table.sort(candidates, function(left, right)
    if left.score == right.score then
      return tostring(left.targetGUID) < tostring(right.targetGUID)
    end
    return left.score > right.score
  end)

  for index = MAX_TARGET_CACHE_ENTRIES + 1, #candidates do
    cache.byGUID[candidates[index].targetGUID] = nil
  end
end

local function GetCachedTargetEntry(auraConfig, targetGUID)
  local cache = GetAuraTargetCache(auraConfig)
  if not cache or not targetGUID or targetGUID == "" then
    return nil
  end
  return cache.byGUID[targetGUID]
end

local function SetCachedTargetEntry(auraConfig, targetGUID, entry)
  local cache = GetAuraTargetCache(auraConfig)
  if not cache or not targetGUID or targetGUID == "" then
    return
  end
  entry = entry or {}
  entry.targetGUID = targetGUID
  entry.updatedAt = GetTime()
  cache.byGUID[targetGUID] = entry
  PruneTargetCache(cache, entry.updatedAt)
end

local function RemoveCachedTargetEntry(auraConfig, targetGUID)
  local cache = GetAuraTargetCache(auraConfig)
  if not cache or not cache.byGUID or not targetGUID or targetGUID == "" then
    return
  end
  cache.byGUID[targetGUID] = nil
end

local function PrunePendingTargetAuras()
  local now = GetTime()
  for auraId, pending in pairs(provider.pendingTargetAuras or {}) do
    if not ns.Registry:GetAura(auraId) or (pending.expiresAt and pending.expiresAt < now) then
      provider.pendingTargetAuras[auraId] = nil
    end
  end
end

local function PruneOrphanedCaches()
  local now = GetTime()
  if (provider.lastCachePruneAt or 0) + CACHE_PRUNE_INTERVAL > now then
    return
  end
  provider.lastCachePruneAt = now

  for auraId in pairs(provider.cachedTargetAuras or {}) do
    if not ns.Registry:GetAura(auraId) then
      provider.cachedTargetAuras[auraId] = nil
    else
      PruneTargetCache(provider.cachedTargetAuras[auraId], now)
    end
  end

  for key in pairs(GetLearnedTargetDurations()) do
    local auraId = tostring(key):match("^aura:(.+)$")
    if auraId and not ns.Registry:GetAura(auraId) then
      provider.learnedTargetDurations[key] = nil
    end
  end
end

local function AuraTriggerMatches(aura, unit, auraType)
  for _, trigger in IterateAuraTriggers(aura) do
    if (not unit or TriggerUsesUnit(trigger.unit, unit))
      and (not auraType or (trigger.auraType or "buff") == auraType) then
      return true
    end
  end
  return false
end

function provider:GetAffectedAurasForUnit(unit, auraType)
  return ns.Registry:CollectAuraIds(function(aura)
    return AuraTriggerMatches(aura, unit, auraType)
  end)
end

function provider:GetAffectedAurasForSpellIDs(spellIDs, unit, auraType)
  local wanted = {}
  local wantedNames = {}
  for _, spellID in ipairs(spellIDs or {}) do
    spellID = tonumber(spellID or 0) or 0
    if spellID > 0 then
      wanted[spellID] = true
      local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil
      local loweredName = SafeLower(spellName)
      if loweredName then
        wantedNames[loweredName] = true
      end
    end
  end

  if next(wanted) == nil and next(wantedNames) == nil then
    return {}
  end

  return ns.Registry:CollectAuraIds(function(aura)
    if not AuraTriggerMatches(aura, unit, auraType) then
      return false
    end

    for _, trigger in IterateAuraTriggers(aura) do
      if (not unit or TriggerUsesUnit(trigger.unit, unit))
        and (not auraType or (trigger.auraType or "buff") == auraType) then
        for _, spellID in ipairs(GetSpellIDs(trigger)) do
          if wanted[spellID] then
            return true
          end
        end
        for _, spellName in ipairs(GetSpellNames(trigger)) do
          if wantedNames[spellName] then
            return true
          end
        end
      end
    end
    return false
  end)
end

function provider:GetAffectedAuras(event, ...)
  if event == "GROUP_ROSTER_UPDATE" then
    return self:GetAffectedAurasForUnit("group")
  end

  if event == "UNIT_FLAGS" then
    local unit = ...
    if unit == "player" or unit == "target" or IsGroupUnitToken(unit) then
      return self:GetAffectedAurasForUnit(unit)
    end
    return {}
  end

  if event == "PLAYER_TARGET_CHANGED" then
    return self:GetAffectedAurasForUnit("target")
  end

  if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
    return self:GetAffectedAurasForUnit("nameplate")
  end

  if event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" or unit == "target" or IsGroupUnitToken(unit) then
      return self:GetAffectedAurasForUnit(unit)
    end
    return {}
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and spellID then
      local results = {}
      local seen = {}
      AddUniqueAuraIds(results, seen, self:GetAffectedAurasForSpellIDs({ spellID }, "player"))
      AddUniqueAuraIds(results, seen, self:GetAffectedAurasForSpellIDs({ spellID }, "target"))
      return results
    end
    return {}
  end

  return {}
end

local function GetTargetDurationCacheKey(trigger, auraConfig, state)
  if auraConfig and auraConfig.id then
    return "aura:" .. tostring(auraConfig.id)
  end

  local spellId = state and state.spellId or (trigger and trigger.spellId)
  spellId = tonumber(spellId or 0) or 0
  if spellId > 0 then
    return "spell:" .. tostring(spellId)
  end

  local names = GetSpellNames(trigger)
  if #names > 0 then
    return "name:" .. tostring(names[1])
  end

  return nil
end

local function ApplyLearnedDuration(trigger, auraConfig, state, castAt)
  if not state or state.show ~= true or state.active ~= true then
    return state, false
  end
  if tonumber(state.duration or 0) > 0 and tonumber(state.expirationTime or 0) > GetTime() then
    return state, false
  end

  local cacheKey = GetTargetDurationCacheKey(trigger, auraConfig, state)
  local learnedStore = GetLearnedTargetDurations()
  local learnedDuration = cacheKey and learnedStore and learnedStore[cacheKey] or nil
  learnedDuration = tonumber(learnedDuration or 0) or 0
  if learnedDuration <= 0 then
    return state, false
  end

  local appliedAt = tonumber(castAt or 0) or 0
  if appliedAt <= 0 then
    appliedAt = GetTime()
  end

  state.duration = learnedDuration
  state.expirationTime = appliedAt + learnedDuration
  state.durationObject = nil
  state.progressType = "timed"
  state.value = learnedDuration
  state.total = learnedDuration
  return state, true
end

local function RememberLearnedTargetDuration(trigger, auraConfig, state)
  local duration = tonumber(state and state.duration or 0) or 0
  if duration <= 0 then
    return
  end

  local cacheKey = GetTargetDurationCacheKey(trigger, auraConfig, state)
  if not cacheKey then
    return
  end

  local learnedStore = GetLearnedTargetDurations()
  local current = tonumber(learnedStore[cacheKey] or 0) or 0
  if current <= 0 or duration < current then
    learnedStore[cacheKey] = duration
  end
end

local function LogAuraEvent(aura, trigger, message)
  if not (ns.Debug and ns.Debug.Log) then
    return
  end
  if not trigger or trigger.debug ~= true then
    return
  end
  ns.Debug:Log("AuraEvent", string.format("%s: %s", tostring(aura and aura.name or "Unknown Aura"), tostring(message or "")))
end

local function RememberTargetAuraState(auraConfig, state, extra)
  if not auraConfig or not auraConfig.id or not state or state.show ~= true then
    return
  end

  local targetGUID = SafeUnitGUID("target")
  if not targetGUID then
    return
  end

  local cache = GetCachedTargetEntry(auraConfig, targetGUID) or {}
  cache.lastState = CloneRuntimeState(state)
  cache.lastSeenAt = GetTime()
  cache.lastExpirationTime = tonumber(state.expirationTime or 0) or 0

  if type(extra) == "table" then
    for key, value in pairs(extra) do
      cache[key] = value
    end
  end

  SetCachedTargetEntry(auraConfig, targetGUID, cache)
end

local function AuraDataMatchesType(auraData, unit, helpful)
  if type(auraData) ~= "table" then
    return false
  end

  local auraInstanceID = tonumber(auraData.auraInstanceID or 0) or 0
  if auraInstanceID > 0 and unit and C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID then
    local filter = helpful and "HELPFUL" or "HARMFUL"
    local ok, isFilteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, auraInstanceID, filter)
    if ok and type(isFilteredOut) == "boolean" then
      return not isFilteredOut
    end
  end

  local isHelpful = SafeAuraBoolean(auraData.isHelpful)
  if isHelpful ~= nil then
    return isHelpful == helpful
  end

  local isHarmful = SafeAuraBoolean(auraData.isHarmful)
  if isHarmful ~= nil then
    return isHarmful ~= helpful
  end

  return true
end

local function FindCDMAura(trigger, auraConfig, unit, helpful)
  if unit ~= "player" and unit ~= "target" then
    return nil, nil, nil, "skip_unit"
  end
  if not ns.CooldownManager or not ns.CooldownManager.GetAuraStateForSpell then
    return nil, nil, nil, "no_cdm"
  end

  for _, spellID in ipairs(GetSpellIDs(trigger)) do
    local cooldownID = ns.CooldownManager.FindCooldownIDForSpellID and ns.CooldownManager:FindCooldownIDForSpellID(spellID) or nil
    local cdmState = ns.CooldownManager:GetAuraStateForSpell(spellID, unit)
    local auraData = cdmState and cdmState.auraData
    if auraData and AuraDataMatchesType(auraData, unit, helpful) then
      if auraConfig and auraConfig.id and unit == "target" then
        SetCachedTargetEntry(auraConfig, SafeUnitGUID(unit), {
          auraInstanceID = cdmState.auraInstanceID,
          spellID = spellID,
          viaCDM = true,
        })
      end
      return auraData, unit, cdmState, string.format("cdm_hit spellID=%s cooldownID=%s auraInstanceID=%s", tostring(spellID), tostring(cdmState.cooldownID), tostring(cdmState.auraInstanceID))
    end
    if cooldownID then
      local cachedState = ns.CooldownManager.auraStateCache and ns.CooldownManager.auraStateCache[cooldownID]
      if cachedState and cachedState.auraInstanceID ~= nil then
        return nil, nil, nil, string.format("cdm_cached_no_aura spellID=%s cooldownID=%s auraInstanceID=%s", tostring(spellID), tostring(cooldownID), tostring(cachedState.auraInstanceID))
      end
      local frame = ns.CooldownManager.FindFrameByCooldownID and ns.CooldownManager:FindFrameByCooldownID(cooldownID) or nil
      return nil, nil, nil, string.format("cdm_no_aura spellID=%s cooldownID=%s frame=%s", tostring(spellID), tostring(cooldownID), tostring(frame ~= nil))
    end
  end

  return nil, nil, nil, "cdm_unmapped"
end

function provider:HandleEvent(event, ...)
  PrunePendingTargetAuras()
  PruneOrphanedCaches()

  if event == "GROUP_ROSTER_UPDATE" then
    return self:GetAffectedAurasForUnit("group")
  end

  if event == "UNIT_FLAGS" then
    local unit = ...
    if unit == "player" or unit == "target" or IsGroupUnitToken(unit) then
      return self:GetAffectedAurasForUnit(unit)
    end
    return {}
  end

  if event == "PLAYER_TARGET_CHANGED" then
    local targetGUID = SafeUnitGUID("target")
    for auraId, pending in pairs(self.pendingTargetAuras or {}) do
      if pending.targetGUID == nil or targetGUID == nil or pending.targetGUID ~= targetGUID then
        local aura = ns.Registry:GetAura(auraId)
        local _, trigger = ns.TriggerBase:AnyTriggerMatches(aura, "aura")
        LogAuraEvent(aura, trigger, string.format("PLAYER_TARGET_CHANGED cleared pending castSpellID=%s", tostring(pending.castSpellID)))
        self.pendingTargetAuras[auraId] = nil
      end
    end
    return self:GetAffectedAurasForUnit("target")
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit ~= "player" then
      return
    end
    local targetGUID = SafeUnitGUID("target")
    local now = GetTime()
    local affectedAuraIds = {}
    local affectedSeen = {}
    for auraId, aura in ns.Registry:IterateAll() do
      for _, trigger in IterateAuraTriggers(aura) do
        if TriggerMatchesSpell(trigger, spellID) then
          if trigger.unit == "target" and trigger.auraType == "debuff" then
            self.pendingTargetAuras[auraId] = {
              targetGUID = targetGUID,
              expiresAt = now + 2,
              castAt = now,
              castSpellID = tonumber(spellID or 0) or 0,
              castSpellName = SafeLower(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)),
            }
            LogAuraEvent(aura, trigger, string.format("UNIT_SPELLCAST_SUCCEEDED set pending spellID=%s targetGUID=%s", tostring(spellID), tostring(targetGUID)))
          end
          if trigger.unit == "player" or trigger.unit == "target" or trigger.unit == "group" then
            if not affectedSeen[auraId] then
              affectedSeen[auraId] = true
              affectedAuraIds[#affectedAuraIds + 1] = auraId
            end
          end
          break
        end
      end
    end
    return affectedAuraIds
  end

  if event == "UNIT_AURA" then
    local unit, unitAuraUpdateInfo = ...
    if unit == "player" then
      return self:GetAffectedAurasForUnit("player")
    end
    if IsGroupUnitToken(unit) then
      return self:GetAffectedAurasForUnit(unit)
    end
    if unit ~= "target" then
      return {}
    end
    if type(unitAuraUpdateInfo) ~= "table" then
      return self:GetAffectedAurasForUnit("target")
    end

    local targetGUID = SafeUnitGUID("target")
    local now = GetTime()
    local changedAuras = {}
    local changedAuraInstanceIDs = {}
    local addedCount = unitAuraUpdateInfo.addedAuras and #unitAuraUpdateInfo.addedAuras or 0
    local updatedCount = unitAuraUpdateInfo.updatedAuraInstanceIDs and #unitAuraUpdateInfo.updatedAuraInstanceIDs or 0
    local removedCount = unitAuraUpdateInfo.removedAuraInstanceIDs and #unitAuraUpdateInfo.removedAuraInstanceIDs or 0

    local function RememberChangedAura(auraData)
      if type(auraData) ~= "table" then
        return
      end
      local auraInstanceID = auraData.auraInstanceID
      if auraInstanceID then
        changedAuras[auraInstanceID] = auraData
        changedAuraInstanceIDs[auraInstanceID] = true
      end
    end

    if unitAuraUpdateInfo.removedAuraInstanceIDs then
      for auraId, aura in ns.Registry:IterateAll() do
        local cached = GetCachedTargetEntry(aura, targetGUID)
        for _, removedId in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
          if cached and cached.auraInstanceID == removedId then
            local _, trigger = ns.TriggerBase:AnyTriggerMatches(aura, "aura")
            LogAuraEvent(aura, trigger, string.format("UNIT_AURA removed cached auraInstanceID=%s added=%d updated=%d removed=%d", tostring(removedId), addedCount, updatedCount, removedCount))
            RemoveCachedTargetEntry(aura, targetGUID)
            break
          end
        end
      end
    end

    if unitAuraUpdateInfo.addedAuras then
      for _, auraData in ipairs(unitAuraUpdateInfo.addedAuras) do
        RememberChangedAura(auraData)
      end
    end

    if unitAuraUpdateInfo.updatedAuraInstanceIDs then
      for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
        changedAuraInstanceIDs[auraInstanceID] = true
        if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
          RememberChangedAura(C_UnitAuras.GetAuraDataByAuraInstanceID("target", auraInstanceID))
        end
      end
    end

    if next(changedAuras) then
      for auraId, aura in ns.Registry:IterateAll() do
        for _, trigger in IterateAuraTriggers(aura) do
          if trigger.unit == "target" and trigger.auraType == "debuff" then
            for auraInstanceID, auraData in pairs(changedAuras) do
              if TriggerMatchesAuraData(trigger, auraData) then
                SetCachedTargetEntry(aura, targetGUID, {
                  auraInstanceID = auraInstanceID,
                })
                self.pendingTargetAuras[auraId] = nil
                LogAuraEvent(aura, trigger, string.format("UNIT_AURA matched changed auraInstanceID=%s spellId=%s added=%d updated=%d removed=%d", tostring(auraInstanceID), tostring(SafeSpellID(auraData.spellId)), addedCount, updatedCount, removedCount))
                break
              end
            end
          end
        end
      end
    end

    if next(changedAuraInstanceIDs) then
      local candidates = {}
      for auraInstanceID in pairs(changedAuraInstanceIDs) do
        candidates[#candidates + 1] = auraInstanceID
      end

      if #candidates > 0 then
        for auraId, pending in pairs(self.pendingTargetAuras or {}) do
          if pending.expiresAt and pending.expiresAt >= now and (pending.targetGUID == nil or targetGUID == nil or pending.targetGUID == targetGUID) then
            local chosenAuraInstanceID = nil
            for _, auraInstanceID in ipairs(candidates) do
              local auraData = changedAuras[auraInstanceID] or (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID and C_UnitAuras.GetAuraDataByAuraInstanceID("target", auraInstanceID))
              if auraData then
                local auraSpellId = SafeSpellID(auraData.spellId)
                local auraName = SafeLower(auraData.name)
                local exactMatch = (pending.castSpellID and pending.castSpellID > 0 and auraSpellId == pending.castSpellID)
                  or (pending.castSpellName and auraName and auraName == pending.castSpellName)
                if exactMatch then
                  chosenAuraInstanceID = auraInstanceID
                  break
                end
                if not chosenAuraInstanceID then
                  chosenAuraInstanceID = auraInstanceID
                end
              elseif not chosenAuraInstanceID then
                chosenAuraInstanceID = auraInstanceID
              end
            end
            if not chosenAuraInstanceID then
              chosenAuraInstanceID = candidates[1]
            end
            if chosenAuraInstanceID then
              local aura = ns.Registry:GetAura(auraId)
              SetCachedTargetEntry(aura, targetGUID, {
                auraInstanceID = chosenAuraInstanceID,
                viaPending = true,
                castAt = pending.castAt,
              })
              local _, trigger = ns.TriggerBase:AnyTriggerMatches(aura, "aura")
              LogAuraEvent(aura, trigger, string.format("UNIT_AURA resolved pending auraInstanceID=%s added=%d updated=%d removed=%d", tostring(chosenAuraInstanceID), addedCount, updatedCount, removedCount))
            end
            self.pendingTargetAuras[auraId] = nil
          elseif pending.expiresAt and pending.expiresAt < now then
            local aura = ns.Registry:GetAura(auraId)
            local _, trigger = ns.TriggerBase:AnyTriggerMatches(aura, "aura")
            LogAuraEvent(aura, trigger, string.format("UNIT_AURA expired pending spellID=%s", tostring(pending.castSpellID)))
            self.pendingTargetAuras[auraId] = nil
          end
        end
      end
    end
    return self:GetAffectedAurasForUnit("target")
  end
end

function provider:ShouldEvaluate(event, ...)
  return true
end

function provider:Evaluate(trigger, auraConfig)
  local unit = trigger.unit or "player"
  local helpful = trigger.auraType ~= "debuff"
  local filterMode = trigger.auraFilter or "present"
  local aliveOnly = trigger.aliveOnly == true
  local aura
  local matchedUnit = unit
  local spellIDs = GetSpellIDs(trigger)
  local spellNames = GetSpellNames(trigger)

  if unit == "group" then
    local checkedUnits = {}
    local eligibleUnits = {}
    local ignoredUnits = {}
    local ignoredReasons = {}
    local firstMissingUnit = nil
    local missingCount = 0

    for _, candidateUnit in ipairs(IterateUnits(unit)) do
      checkedUnits[#checkedUnits + 1] = candidateUnit
      if UnitPassesAuraFilters(candidateUnit, trigger, aliveOnly) then
        eligibleUnits[#eligibleUnits + 1] = candidateUnit
        local candidateAura = FindAura(candidateUnit, spellIDs, spellNames, helpful)
        if filterMode == "missing" then
          if not candidateAura then
            missingCount = missingCount + 1
            if not firstMissingUnit then
              firstMissingUnit = candidateUnit
            end
          end
        elseif candidateAura then
          aura = candidateAura
          matchedUnit = candidateUnit
          break
        end
      else
        ignoredUnits[#ignoredUnits + 1] = candidateUnit
        if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
          ignoredReasons[#ignoredReasons + 1] = string.format("%s{%s}", tostring(candidateUnit), BuildAuraFilterTrace(candidateUnit, trigger, aliveOnly))
        end
      end
    end

    if filterMode == "missing" then
      local state
      if firstMissingUnit then
        state = BuildMissingState(trigger, auraConfig, helpful, unit, firstMissingUnit, missingCount)
      elseif aliveOnly and #eligibleUnits == 0 then
        state = BuildFilteredOutState(unit)
      else
        state = BuildSatisfiedState(trigger, auraConfig, helpful, unit, matchedUnit)
      end
      if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
        local details = string.format("checked=%s eligible=%s ignored=%s missingCount=%d firstMissing=%s range=%s names=%s ids=%s",
          table.concat(checkedUnits, "/"),
          table.concat(eligibleUnits, "/"),
          table.concat(ignoredUnits, "/"),
          missingCount,
          tostring(firstMissingUnit or ""),
          tostring(NormalizeAuraRangeMode(trigger.groupRange or "any")),
          table.concat(spellNames or {}, ","),
          table.concat(spellIDs or {}, ","))
        if #ignoredReasons > 0 then
          details = string.format("%s ignoredWhy=%s", details, table.concat(ignoredReasons, ";"))
        end
        ns.Debug:LogTrigger(nil, trigger, state, details)
      end
      return state
    end
  end

  local supportsTargetCache = unit == "target" and helpful == false
  if supportsTargetCache then
    local cacheKey = auraConfig and auraConfig.id or nil
    if cacheKey then
      local currentTargetGUID = SafeUnitGUID("target")
      local cached = GetCachedTargetEntry(auraConfig, currentTargetGUID)
      if cached and cached.auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("target", cached.auraInstanceID)
        if auraData and (cached.viaCDM == true or cached.viaPending == true or TriggerMatchesAuraData(trigger, auraData)) then
          local activeCDMState = nil
          local activeCDMAura = nil
          local activeCDMUnit = nil
          if cached.viaCDM == true then
            activeCDMAura, activeCDMUnit, activeCDMState = FindCDMAura(trigger, auraConfig, "target", helpful)
            if activeCDMState and cached.auraInstanceID and activeCDMState.auraInstanceID ~= cached.auraInstanceID then
              activeCDMState = nil
              activeCDMAura = nil
              activeCDMUnit = nil
            end
          end

          local cachedState = BuildStateFromAuraData(
            activeCDMAura or auraData,
            activeCDMUnit or "target",
            helpful,
            GetPreferredAuraName(trigger, auraConfig),
            trigger
          )
          if cachedState then
            local usedCDMTiming = false
            cachedState, usedCDMTiming = ApplyCDMAuraTiming(cachedState, activeCDMState)
            local usedLearnedDuration = false
            if not usedCDMTiming then
              cachedState, usedLearnedDuration = ApplyLearnedDuration(trigger, auraConfig, cachedState, cached.castAt)
            end
            RememberTargetAuraState(auraConfig, cachedState)
            RememberLearnedTargetDuration(trigger, auraConfig, cachedState)
            if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
              ns.Debug:LogTrigger(nil, trigger, cachedState, string.format("cachedAuraInstanceID=%s viaCDM=%s viaPending=%s usedCDMTiming=%s usedLearnedDuration=%s", tostring(cached.auraInstanceID), tostring(cached.viaCDM == true), tostring(cached.viaPending == true), tostring(usedCDMTiming == true), tostring(usedLearnedDuration == true)))
            end
            if filterMode == "missing" then
              return BuildSatisfiedState(trigger, auraConfig, helpful, unit, matchedUnit)
            end
            return cachedState
          end
        elseif cached.lastState then
          local fallbackState = CloneRuntimeState(cached.lastState)
          local now = GetTime()
          if (cached.lastExpirationTime or 0) > now then
            fallbackState.expirationTime = cached.lastExpirationTime
            fallbackState.duration = math.max(0, cached.lastExpirationTime - (cached.lastSeenAt or now))
            fallbackState.value = fallbackState.duration
            fallbackState.total = fallbackState.duration
            fallbackState.progressType = "timed"
            if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
              ns.Debug:LogTrigger(nil, trigger, fallbackState, string.format("stickyTargetFallback auraInstanceID=%s viaCDM=%s", tostring(cached.auraInstanceID), tostring(cached.viaCDM == true)))
            end
            if filterMode == "missing" then
              return BuildSatisfiedState(trigger, auraConfig, helpful, unit, matchedUnit)
            end
            return fallbackState
          end
        else
          RemoveCachedTargetEntry(auraConfig, currentTargetGUID)
        end
      end
    end
  end

  local cdmReason = nil
  if unit == "player" or unit == "target" then
    local cdmAura, cdmUnit, cdmState, reason = FindCDMAura(trigger, auraConfig, unit, helpful)
    cdmReason = reason
    if cdmAura then
      local cdmFound = BuildStateFromAuraData(cdmAura, cdmUnit or unit, helpful, GetPreferredAuraName(trigger, auraConfig), trigger)
      local usedCDMTiming = false
      cdmFound, usedCDMTiming = ApplyCDMAuraTiming(cdmFound, cdmState)
      if supportsTargetCache then
        local usedLearnedDuration = false
        if not usedCDMTiming then
          cdmFound, usedLearnedDuration = ApplyLearnedDuration(trigger, auraConfig, cdmFound)
        end
        RememberTargetAuraState(auraConfig, cdmFound, {
          auraInstanceID = cdmState and cdmState.auraInstanceID or nil,
          viaCDM = true,
        })
        RememberLearnedTargetDuration(trigger, auraConfig, cdmFound)
        if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
          ns.Debug:LogTrigger(nil, trigger, cdmFound, string.format("cdmAuraInstanceID=%s cooldownID=%s usedCDMTiming=%s usedLearnedDuration=%s", tostring(cdmState and cdmState.auraInstanceID), tostring(cdmState and cdmState.cooldownID), tostring(usedCDMTiming == true), tostring(usedLearnedDuration == true)))
        end
      elseif ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
        ns.Debug:LogTrigger(nil, trigger, cdmFound, string.format("cdmAuraInstanceID=%s cooldownID=%s usedCDMTiming=%s", tostring(cdmState and cdmState.auraInstanceID), tostring(cdmState and cdmState.cooldownID), tostring(usedCDMTiming == true)))
      end
      if filterMode == "missing" then
        return BuildSatisfiedState(trigger, auraConfig, helpful, unit, cdmUnit or unit)
      end
      return cdmFound
    end
  end

  if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true and cdmReason then
    ns.Debug:LogTrigger(nil, trigger, ns.Schema.NormalizeRuntimeState({
      show = false,
      active = false,
      source = "aura",
      unit = unit,
    }), cdmReason)
  end

  local checkedUnits = {}
  local ignoredUnits = {}
  local ignoredReasons = {}
  local hasEligibleUnit = false
  for _, candidateUnit in ipairs(IterateUnits(unit)) do
    checkedUnits[#checkedUnits + 1] = candidateUnit
    if UnitPassesAuraFilters(candidateUnit, trigger, aliveOnly) then
      hasEligibleUnit = true
      aura = FindAura(candidateUnit, spellIDs, spellNames, helpful)
      if aura then
        matchedUnit = candidateUnit
        break
      end
    else
      ignoredUnits[#ignoredUnits + 1] = candidateUnit
      if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
        ignoredReasons[#ignoredReasons + 1] = string.format("%s{%s}", tostring(candidateUnit), BuildAuraFilterTrace(candidateUnit, trigger, aliveOnly))
      end
    end
  end
  if not aura then
    local missing
    if not hasEligibleUnit and (aliveOnly or (unit == "group" and trigger.ignoreNPCs == true)) then
      missing = BuildFilteredOutState(unit)
    elseif filterMode == "missing" then
      missing = BuildMissingState(trigger, auraConfig, helpful, unit, unit, 1)
    else
      local shouldShowMissing = trigger.showAlways == true
      missing = ns.Schema.NormalizeRuntimeState({
        show = shouldShowMissing,
        matched = false,
        active = false,
        isReady = shouldShowMissing,
        icon = shouldShowMissing and GetPreferredAuraIcon(trigger) or nil,
        name = shouldShowMissing and GetPreferredAuraName(trigger, auraConfig) or "",
        source = "aura",
        unit = unit,
        statusText = helpful and "Missing Buff" or "Missing Debuff",
        progressType = "static",
        duration = 0,
        expirationTime = 0,
        value = 0,
        total = 0,
      })
    end
    if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
      local details = string.format("checked=%s ignored=%s range=%s names=%s ids=%s",
        table.concat(checkedUnits, "/"),
        table.concat(ignoredUnits, "/"),
        tostring(NormalizeAuraRangeMode(trigger.groupRange or "any")),
        table.concat(spellNames or {}, ","),
        table.concat(spellIDs or {}, ","))
      if #ignoredReasons > 0 then
        details = string.format("%s ignoredWhy=%s", details, table.concat(ignoredReasons, ";"))
      end
      if unit == "target" then
        details = string.format("%s | %s", details, BuildAuraSummary("target", helpful))
      end
      ns.Debug:LogTrigger(nil, trigger, missing, details)
    end
    return missing
  end

  local found = BuildStateFromAuraData(aura, matchedUnit, helpful, GetPreferredAuraName(trigger, auraConfig), trigger)
  if unit == "target" and helpful == false then
    local usedLearnedDuration = false
    found, usedLearnedDuration = ApplyLearnedDuration(trigger, auraConfig, found)
    RememberTargetAuraState(auraConfig, found, {
      auraInstanceID = aura and aura.auraInstanceID or nil,
      viaCDM = false,
    })
    RememberLearnedTargetDuration(trigger, auraConfig, found)
    if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true and usedLearnedDuration then
      ns.Debug:LogTrigger(nil, trigger, found, "usedLearnedDuration=true")
    end
  end
  if ns.Debug and ns.Debug.LogTrigger and trigger.debug == true then
    ns.Debug:LogTrigger(nil, trigger, found, string.format("matchedUnit=%s auraName=%s", tostring(matchedUnit), tostring(aura.name or "")))
  end
  if filterMode == "missing" then
    return BuildSatisfiedState(trigger, auraConfig, helpful, unit, matchedUnit)
  end
  return found
end
