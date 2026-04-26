local _, ns = ...

local UnitAuraList = {}
ns.util.UnitAuraList = UnitAuraList

local REAL_TIME_MODIFIER = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime or nil
local UNIT_AURA_SORT_RULE = Enum and Enum.UnitAuraSortRule or nil
local UNIT_AURA_SORT_DIRECTION = Enum and Enum.UnitAuraSortDirection or nil
local KNOWN_STACK_SPELLS = {}
local KNOWN_AURA_INSTANCES = {}
local PLAYER_TRACKED_TARGET_DEBUFFS = {}
local NON_PLAYER_TRACKED_TARGET_DEBUFFS = {}
local TARGET_DEBUFF_FILTER_MODES = {
  all = true,
  mine_only = true,
  mine_or_unowned = true,
}

local function SafeNumber(value, fallback)
  if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
    return value
  end
  return fallback
end

local function SafeString(value, fallback)
  if type(value) == "string" and not (issecretvalue and issecretvalue(value)) then
    return value
  end
  return fallback
end

local function SafeAuraString(value)
  return SafeString(value, nil)
end

local function SafeSpellID(value)
  if value ~= nil and not (issecretvalue and issecretvalue(value)) then
    return tonumber(value)
  end
  return nil
end

local function SafeBoolean(value)
  if type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) then
    return value
  end
  return nil
end

local function SafeGUID(value)
  if type(value) == "string" and not (issecretvalue and issecretvalue(value)) then
    return value
  end
  return nil
end

local function CallSafeBooleanAPI(func, ...)
  if type(func) ~= "function" then
    return nil
  end

  local ok, value = pcall(func, ...)
  if not ok then
    return nil
  end

  return SafeBoolean(value)
end

local function IsPlayerSourceUnit(sourceUnit)
  if sourceUnit == nil or sourceUnit == "" then
    return false
  end
  if sourceUnit == "player" or sourceUnit == "pet" or sourceUnit == "vehicle" then
    return true
  end

  if UnitIsUnit then
    if CallSafeBooleanAPI(UnitIsUnit, sourceUnit, "player") == true then
      return true
    end
    if CallSafeBooleanAPI(UnitIsUnit, sourceUnit, "pet") == true then
      return true
    end
    if CallSafeBooleanAPI(UnitIsUnit, sourceUnit, "vehicle") == true then
      return true
    end
  end

  return false
end

local function GetLegacyAuraSourceUnit(unit, helpful, index)
  if type(unit) ~= "string" or type(index) ~= "number" then
    return nil
  end

  local reader = helpful and UnitBuff or UnitDebuff
  if type(reader) ~= "function" then
    return nil
  end

  local _, _, _, _, _, _, sourceUnit = reader(unit, index)
  return SafeAuraString(sourceUnit)
end

local function GetResolvedAuraSourceUnit(unit, helpful, index, auraData)
  return SafeAuraString(auraData and auraData.sourceUnit)
    or SafeAuraString(auraData and auraData.unitCaster)
    or GetLegacyAuraSourceUnit(unit, helpful, index)
end

local function GetTrackedDebuffBucket(store, destGUID)
  if type(destGUID) ~= "string" or destGUID == "" then
    return nil
  end

  local bucket = store[destGUID]
  if type(bucket) ~= "table" then
    bucket = {}
    store[destGUID] = bucket
  end

  return bucket
end

local function IncrementTrackedDebuff(store, destGUID, spellID)
  if type(destGUID) ~= "string" or destGUID == "" or type(spellID) ~= "number" or spellID <= 0 then
    return false
  end

  local bucket = GetTrackedDebuffBucket(store, destGUID)
  if not bucket then
    return false
  end

  bucket[spellID] = (tonumber(bucket[spellID] or 0) or 0) + 1
  return true
end

local function DecrementTrackedDebuff(store, destGUID, spellID)
  if type(destGUID) ~= "string" or destGUID == "" or type(spellID) ~= "number" or spellID <= 0 then
    return false
  end

  local bucket = store[destGUID]
  if type(bucket) ~= "table" then
    return false
  end

  local nextValue = (tonumber(bucket[spellID] or 0) or 0) - 1
  if nextValue > 0 then
    bucket[spellID] = nextValue
  else
    bucket[spellID] = nil
  end

  if next(bucket) == nil then
    store[destGUID] = nil
  end

  return true
end

local function HasTrackedDebuff(store, destGUID, spellID)
  if type(destGUID) ~= "string" or destGUID == "" or type(spellID) ~= "number" or spellID <= 0 then
    return false
  end

  local bucket = store[destGUID]
  return type(bucket) == "table" and (tonumber(bucket[spellID] or 0) or 0) > 0
end

local function IsTrackedPlayerDebuff(destGUID, spellID)
  return HasTrackedDebuff(PLAYER_TRACKED_TARGET_DEBUFFS, destGUID, spellID)
end

local function IsTrackedNonPlayerDebuff(destGUID, spellID)
  return HasTrackedDebuff(NON_PLAYER_TRACKED_TARGET_DEBUFFS, destGUID, spellID)
end

local function IsPlayerControlledSourceFlags(sourceFlags)
  if type(sourceFlags) ~= "number" then
    return false
  end

  if CombatLog_Object_IsA and COMBATLOG_OBJECT_CONTROL_PLAYER then
    local ok, result = pcall(CombatLog_Object_IsA, sourceFlags, COMBATLOG_OBJECT_CONTROL_PLAYER)
    if ok and result ~= nil then
      return result == true
    end
  end

  if bit and bit.band and COMBATLOG_OBJECT_CONTROL_PLAYER then
    return bit.band(sourceFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) ~= 0
  end

  if bit32 and bit32.band and COMBATLOG_OBJECT_CONTROL_PLAYER then
    return bit32.band(sourceFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) ~= 0
  end

  return false
end

local function IsMineSourceGUID(sourceGUID)
  sourceGUID = SafeGUID(sourceGUID)
  if sourceGUID == nil then
    return false
  end

  return sourceGUID == SafeGUID(UnitGUID and UnitGUID("player"))
    or sourceGUID == SafeGUID(UnitGUID and UnitGUID("pet"))
    or sourceGUID == SafeGUID(UnitGUID and UnitGUID("vehicle"))
end

local function ClassifyAuraSource(unit, helpful, index, auraData)
  if type(auraData) ~= "table" then
    return "unknown"
  end

  local sourceUnit = GetResolvedAuraSourceUnit(unit, helpful, index, auraData)
  if sourceUnit == nil or sourceUnit == "" then
    return "unknown"
  end

  if IsPlayerSourceUnit(sourceUnit) then
    return "self"
  end

  if CallSafeBooleanAPI(UnitExists, sourceUnit) == true then
    if CallSafeBooleanAPI(UnitIsPlayer, sourceUnit) == true then
      return "other_player"
    end
    if CallSafeBooleanAPI(UnitPlayerControlled, sourceUnit) == true then
      return "other_player"
    end
    return "non_player"
  end

  if sourceUnit:match("^party%d+$")
    or sourceUnit:match("^raid%d+$")
    or sourceUnit:match("^arena%d+$")
    or sourceUnit:match("^partypet%d+$")
    or sourceUnit:match("^raidpet%d+$")
    or sourceUnit:match("^arenapet%d+$") then
    return "other_player"
  end

  return "unknown"
end

local function GetTargetDebuffFilterMode(trigger)
  local mode = tostring(trigger and trigger.targetDebuffFilterMode or "")
  if TARGET_DEBUFF_FILTER_MODES[mode] then
    return mode
  end
  if trigger and trigger.targetMineOrUnownedOnly == true then
    return "mine_or_unowned"
  end
  return "all"
end

local function CollectAuraInstanceIDsForFilter(unit, filter)
  if type(unit) ~= "string" or unit == "" or type(filter) ~= "string" or filter == "" then
    return nil, 0
  end

  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
    return nil, 0
  end

  local auraInstanceIDs = {}
  local rawCount = 0
  local index = 1

  while true do
    local ok, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
    if not ok then
      return nil, 0
    end
    if not auraData then
      break
    end

    rawCount = rawCount + 1

    local auraInstanceID = SafeNumber(auraData.auraInstanceID, nil)
    if auraInstanceID ~= nil then
      auraInstanceIDs[auraInstanceID] = true
    end

    index = index + 1
  end

  return auraInstanceIDs, rawCount
end

local function CollectPlayerFilteredAuraInstanceIDs(unit, helpful, debugInfo)
  local baseFilter = helpful and "HELPFUL" or "HARMFUL"
  local filterOrder = {
    baseFilter .. "|PLAYER",
    "PLAYER|" .. baseFilter,
  }
  local combinedAuraInstanceIDs = {}
  local sawSupportedFilter = false
  local bestFilter = nil
  local bestRawCount = 0

  for _, filter in ipairs(filterOrder) do
    local auraInstanceIDs, rawCount = CollectAuraInstanceIDsForFilter(unit, filter)
    if auraInstanceIDs ~= nil then
      sawSupportedFilter = true
      if rawCount > bestRawCount then
        bestFilter = filter
        bestRawCount = rawCount
      end
      for auraInstanceID in pairs(auraInstanceIDs) do
        combinedAuraInstanceIDs[auraInstanceID] = true
      end
    end
  end

  if sawSupportedFilter then
    if debugInfo then
      debugInfo.playerReader = "GetAuraDataByIndex(" .. tostring(bestFilter or filterOrder[1]) .. ")"
      debugInfo.playerRawCount = bestRawCount
    end
    return combinedAuraInstanceIDs
  end

  if debugInfo then
    debugInfo.playerReader = "unsupported"
    debugInfo.playerRawCount = 0
  end

  return nil
end

local function AuraMatchesPlayerFilteredSet(playerFilteredAuraInstances, auraData)
  if type(playerFilteredAuraInstances) ~= "table" then
    return false
  end

  local auraInstanceID = SafeNumber(auraData and auraData.auraInstanceID, nil)
  return auraInstanceID ~= nil and playerFilteredAuraInstances[auraInstanceID] == true
end

local function ShouldIncludeTargetDebuff(trigger, auraData, unit, helpful, index, playerFilteredAuraInstances, matchedPlayerFilteredAura)
  local filterMode = GetTargetDebuffFilterMode(trigger)
  if filterMode == "all" then
    return true
  end

  if helpful ~= false or unit ~= "target" then
    return true
  end

  if matchedPlayerFilteredAura == nil then
    matchedPlayerFilteredAura = AuraMatchesPlayerFilteredSet(playerFilteredAuraInstances, auraData)
  end
  if matchedPlayerFilteredAura then
    return true
  end

  local sourceKind = ClassifyAuraSource(unit, helpful, index, auraData)

  if sourceKind == "self" then
    return true
  end

  if sourceKind == "other_player" then
    return false
  end

  if sourceKind == "non_player" then
    return filterMode == "mine_or_unowned"
  end

  local fromPlayer = SafeBoolean(auraData and auraData.isFromPlayerOrPlayerPet)
  if fromPlayer == true then
    return false
  end

  if filterMode == "mine_or_unowned" and fromPlayer == false then
    return true
  end

  return false
end

local function GetAuraInstanceKey(unit, auraInstanceID)
  if type(unit) ~= "string" or auraInstanceID == nil then
    return nil
  end
  return unit .. ":" .. tostring(auraInstanceID)
end

local function GetKnownAuraInstanceInfo(unit, auraInstanceID)
  local key = GetAuraInstanceKey(unit, auraInstanceID)
  if not key then
    return nil
  end
  return KNOWN_AURA_INSTANCES[key]
end

local function RememberAuraInstanceInfo(unit, auraInstanceID, spellID, stackCapable, safeName)
  local key = GetAuraInstanceKey(unit, auraInstanceID)
  if not key then
    return
  end

  local info = KNOWN_AURA_INSTANCES[key]
  if type(info) ~= "table" then
    info = {}
    KNOWN_AURA_INSTANCES[key] = info
  end

  if spellID then
    info.spellId = spellID
  end
  safeName = SafeString(safeName, "")
  if safeName ~= "" then
    info.name = safeName
  end
  if stackCapable == true then
    info.stackCapable = true
    if spellID then
      KNOWN_STACK_SPELLS[spellID] = true
    end
  end
end

local function ResolveSpellName(spellID)
  if not spellID then
    return ""
  end

  local name = nil
  if C_Spell and C_Spell.GetSpellName then
    name = C_Spell.GetSpellName(spellID)
  elseif GetSpellInfo then
    name = GetSpellInfo(spellID)
  end

  return SafeString(name, "")
end

local function ResolveAuraName(auraData, fallbackSpellID, fallbackName)
  local safeName = SafeString(auraData and auraData.name, "")
  if safeName ~= "" then
    return safeName
  end

  local cachedName = SafeString(fallbackName, "")
  if cachedName ~= "" then
    return cachedName
  end

  return ResolveSpellName(SafeSpellID(auraData and auraData.spellId) or fallbackSpellID)
end

local function CallDurationObjectMethod(durationObject, methodName)
  if not durationObject then
    return nil
  end

  local method = durationObject[methodName]
  if type(method) ~= "function" then
    return nil
  end

  local ok, result
  if REAL_TIME_MODIFIER ~= nil then
    ok, result = pcall(method, durationObject, REAL_TIME_MODIFIER)
  else
    ok, result = pcall(method, durationObject)
  end

  if not ok then
    return nil
  end

  return SafeNumber(result, nil)
end

local function IsPositiveDisplayValue(value)
  if type(value) == "number" then
    return value > 0
  end

  if type(value) == "string" then
    local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
      return false
    end

    local numeric = tonumber(trimmed)
    if numeric ~= nil then
      return numeric > 0
    end

    return true
  end

  return false
end

local function GetAuraTiming(unit, auraInstanceID, auraData)
  local duration = 0
  local expirationTime = 0
  local durationObject = nil
  local now = GetTime()
  local hasExpiration = nil

  if C_UnitAuras and C_UnitAuras.DoesAuraHaveExpirationTime and unit and auraInstanceID then
    local ok, expires = pcall(C_UnitAuras.DoesAuraHaveExpirationTime, unit, auraInstanceID)
    local safeExpires = ok and SafeBoolean(expires) or nil
    if safeExpires ~= nil then
      hasExpiration = safeExpires
    end
  end

  if C_UnitAuras and C_UnitAuras.GetAuraDurationRemaining and unit and auraInstanceID then
    local ok, remaining = pcall(C_UnitAuras.GetAuraDurationRemaining, unit, auraInstanceID)
    remaining = ok and SafeNumber(remaining, nil) or nil
    if remaining and remaining > 0 then
      expirationTime = now + remaining
      hasExpiration = true
    end
  end

  if C_UnitAuras and C_UnitAuras.GetAuraDuration and unit and auraInstanceID then
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
        hasExpiration = true
      elseif endTime and endTime > now then
        expirationTime = endTime
        hasExpiration = true
      elseif startTime and duration > 0 then
        expirationTime = startTime + duration
        if expirationTime > now then
          hasExpiration = true
        end
      end
      if duration <= 0 and startTime and endTime and endTime > startTime then
        duration = endTime - startTime
      end
    end
  end

  if duration <= 0 and C_UnitAuras and C_UnitAuras.GetAuraBaseDuration and unit and auraInstanceID then
    local ok, baseDuration = pcall(C_UnitAuras.GetAuraBaseDuration, unit, auraInstanceID, SafeSpellID(auraData and auraData.spellId))
    duration = ok and SafeNumber(baseDuration, duration) or duration
  end

  if duration <= 0 then
    duration = SafeNumber(auraData and auraData.duration, 0)
  end
  if expirationTime <= 0 then
    expirationTime = SafeNumber(auraData and auraData.expirationTime, 0)
  end

  if expirationTime > now then
    hasExpiration = true
  end
  if duration <= 0 and expirationTime > now then
    duration = expirationTime - now
  end

  if hasExpiration == false then
    duration = 0
    expirationTime = 0
  end

  return duration or 0, expirationTime or 0, durationObject, hasExpiration
end

local function BuildStackDisplayValue(rawValue, safeText, safeNumberValue)
  if issecretvalue and issecretvalue(rawValue) then
    return rawValue, true
  end

  if IsPositiveDisplayValue(rawValue) then
    return rawValue, true
  end
  if IsPositiveDisplayValue(safeText) then
    return safeText, true
  end
  if type(safeNumberValue) == "number" and safeNumberValue > 0 then
    return safeNumberValue, true
  end

  return nil, false
end

local function GetEntrySortValue(entry, now)
  if not entry then
    return math.huge
  end

  if entry.isPermanent == true then
    return math.huge
  end

  if entry.progressType ~= "timed" then
    return math.huge
  end

  if type(entry.expirationTime) == "number" and entry.expirationTime > now then
    return entry.expirationTime - now
  end

  if entry.durationObject then
    local remaining = CallDurationObjectMethod(entry.durationObject, "GetRemainingDuration")
    if remaining ~= nil and remaining > 0 then
      return remaining
    end

    local endTime = CallDurationObjectMethod(entry.durationObject, "GetEndTime")
    if endTime ~= nil and endTime > now then
      return endTime - now
    end
  end

  if type(entry.duration) == "number" and entry.duration > 0 then
    return entry.duration
  end

  return 0
end

local function BuildDebugPreviewEntry(auraData, entry, index)
  local name = ResolveAuraName(auraData)
  local spellID = SafeSpellID(auraData and auraData.spellId) or (entry and entry.spellId) or nil
  local auraInstanceID = SafeNumber(auraData and auraData.auraInstanceID, nil) or (entry and entry.auraInstanceID) or nil
  local icon = (auraData and auraData.icon) or (entry and entry.icon) or nil
  local sourceUnit = SafeAuraString(auraData and auraData.sourceUnit) or SafeAuraString(auraData and auraData.unitCaster)
  local fromPlayer = SafeBoolean(auraData and auraData.isFromPlayerOrPlayerPet)
  local label = name ~= "" and name or "?"
  return string.format("%s(%s)#%s@%d icon=%s src=%s fromPlayer=%s",
    tostring(label),
    tostring(spellID or "?"),
    tostring(auraInstanceID or "?"),
    tonumber(index or 0) or 0,
    tostring(icon ~= nil),
    tostring(sourceUnit or "-"),
    tostring(fromPlayer))
end

local function SortEntries(unit, helpful, entries, debugInfo)
  if type(entries) ~= "table" or #entries <= 1 then
    if debugInfo then
      debugInfo.sortMode = "passthrough"
      debugInfo.orderedCount = #entries
    end
    return entries
  end

  if C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs and UNIT_AURA_SORT_RULE and UNIT_AURA_SORT_DIRECTION then
    local filter = helpful and "HELPFUL" or "HARMFUL"
    local sortRule = UNIT_AURA_SORT_RULE.ExpirationOnly or UNIT_AURA_SORT_RULE.Default
    local sortDirection = UNIT_AURA_SORT_DIRECTION.Reverse or UNIT_AURA_SORT_DIRECTION.Normal
    local orderedIDs = C_UnitAuras.GetUnitAuraInstanceIDs(unit, filter, nil, sortRule, sortDirection)
    if debugInfo then
      debugInfo.sortMode = "blizzard_expiration_reverse"
      debugInfo.orderedCount = type(orderedIDs) == "table" and #orderedIDs or 0
    end
    if type(orderedIDs) == "table" and #orderedIDs > 0 then
      local sorted = {}
      local byAuraID = {}
      local leftovers = {}

      for _, entry in ipairs(entries) do
        if type(entry.auraInstanceID) == "number" then
          byAuraID[entry.auraInstanceID] = entry
        else
          leftovers[#leftovers + 1] = entry
        end
      end

      for _, auraInstanceID in ipairs(orderedIDs) do
        local entry = byAuraID[auraInstanceID]
        if entry then
          sorted[#sorted + 1] = entry
          byAuraID[auraInstanceID] = nil
        end
      end

      table.sort(leftovers, function(left, right)
        return (left._sortIndex or 0) < (right._sortIndex or 0)
      end)
      for _, entry in ipairs(leftovers) do
        sorted[#sorted + 1] = entry
      end

      if #sorted > 0 then
        return sorted
      end
    end
  end

  local now = GetTime()
  if debugInfo then
    debugInfo.sortMode = "local_fallback"
    debugInfo.orderedCount = #entries
  end
  table.sort(entries, function(left, right)
    local leftValue = GetEntrySortValue(left, now)
    local rightValue = GetEntrySortValue(right, now)
    if leftValue ~= rightValue then
      return leftValue > rightValue
    end
    return (left._sortIndex or 0) < (right._sortIndex or 0)
  end)
  return entries
end

local function GetAuraStacks(unit, auraInstanceID, auraData)
  local stacks = SafeNumber(auraData and auraData.applications,
    SafeNumber(auraData and auraData.charges, 0))
  local stackText = stacks > 0 and tostring(stacks) or nil
  local rawStackValue = auraData and (auraData.applications or auraData.charges) or nil

  if C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount and unit and auraInstanceID then
    local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 1, 999)
    if ok and not (issecretvalue and issecretvalue(count)) then
      if type(count) == "string" and count ~= "" then
        local numeric = tonumber(count)
        local safeCountText = IsPositiveDisplayValue(count) and count or nil
        local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, safeCountText, numeric or stacks)
        return (numeric and numeric > 0) and numeric or stacks, safeCountText, stackDisplayValue, hasStackDisplayValue
      elseif type(count) == "number" and count > 0 then
        local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, tostring(count), count)
        return count, tostring(count), stackDisplayValue, hasStackDisplayValue
      end
    end
  end

  local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, stackText, stacks)
  return stacks, stackText, stackDisplayValue, hasStackDisplayValue
end

function UnitAuraList:GetTriggerConfig(trigger)
  local unit = trigger and trigger.unit or "player"
  local helpful = (trigger and trigger.auraType or "buff") ~= "debuff"
  return unit, helpful
end

function UnitAuraList:GetSourceValue(trigger)
  local unit, helpful = self:GetTriggerConfig(trigger)
  if unit == "target" then
    return helpful and "target_buff" or "target_debuff"
  end
  return helpful and "player_buff" or "player_debuff"
end

function UnitAuraList:GetTargetDebuffFilterMode(trigger)
  return GetTargetDebuffFilterMode(trigger)
end

function UnitAuraList:ApplyTargetDebuffFilterMode(trigger, value)
  trigger = trigger or {}
  local mode = tostring(value or "all")
  if not TARGET_DEBUFF_FILTER_MODES[mode] then
    mode = "all"
  end

  trigger.targetDebuffFilterMode = mode
  trigger.targetMineOrUnownedOnly = mode == "mine_or_unowned"
  return trigger
end

function UnitAuraList:ApplySourceValue(trigger, value)
  trigger = trigger or {}
  value = tostring(value or "player_buff")

  if value == "target_debuff" then
    trigger.unit = "target"
    trigger.auraType = "debuff"
  elseif value == "target_buff" then
    trigger.unit = "target"
    trigger.auraType = "buff"
  elseif value == "player_debuff" then
    trigger.unit = "player"
    trigger.auraType = "debuff"
  else
    trigger.unit = "player"
    trigger.auraType = "buff"
  end

  return trigger
end

local function BuildDebugSummary(debugInfo)
  debugInfo = debugInfo or {}
  local preview = type(debugInfo.preview) == "table" and table.concat(debugInfo.preview, ", ") or ""
  if preview == "" then
    preview = "-"
  end
  local keptPreview = type(debugInfo.keptPreview) == "table" and table.concat(debugInfo.keptPreview, ", ") or ""
  if keptPreview == "" then
    keptPreview = "-"
  end

  return string.format(
    "unit=%s type=%s combat=%s filter=%s reader=%s raw=%d playerReader=%s playerRaw=%d playerMatched=%d returned=%d stop=%s sort=%s ordered=%d preview=%s kept=%s",
    tostring(debugInfo.unit or ""),
    debugInfo.helpful == false and "debuff" or "buff",
    tostring(debugInfo.inCombat == true),
    tostring(debugInfo.targetDebuffFilterMode or "all"),
    tostring(debugInfo.reader or "none"),
    tonumber(debugInfo.rawCount or 0) or 0,
    tostring(debugInfo.playerReader or "none"),
    tonumber(debugInfo.playerRawCount or 0) or 0,
    tonumber(debugInfo.playerMatchedCount or 0) or 0,
    tonumber(debugInfo.returnedCount or 0) or 0,
    tostring(debugInfo.stopReason or "nil"),
    tostring(debugInfo.sortMode or "none"),
    tonumber(debugInfo.orderedCount or 0) or 0,
    preview,
    keptPreview
  )
end

function UnitAuraList:CollectInternal(trigger, maxCount, includeDebug)
  local unit, helpful = self:GetTriggerConfig(trigger)
  local filter = helpful and "HELPFUL" or "HARMFUL"
  local targetDebuffFilterMode = GetTargetDebuffFilterMode(trigger)
  local debugInfo = includeDebug == true and {
    unit = unit,
    helpful = helpful,
    inCombat = InCombatLockdown and InCombatLockdown() or false,
    targetDebuffFilterMode = targetDebuffFilterMode,
    reader = "none",
    rawCount = 0,
    playerReader = "none",
    playerRawCount = 0,
    playerMatchedCount = 0,
    returnedCount = 0,
    orderedCount = 0,
    sortMode = "none",
    preview = {},
    keptPreview = {},
  } or nil
  if type(unit) ~= "string" or unit == "" or CallSafeBooleanAPI(UnitExists, unit) ~= true then
    if debugInfo then
      debugInfo.stopReason = unit and "unit_missing" or "unit_nil"
      return {}, BuildDebugSummary(debugInfo)
    end
    return {}
  end

  local auraList = nil
  local reader = nil
  if C_UnitAuras and C_UnitAuras.GetUnitAuras then
    local sortRule = UNIT_AURA_SORT_RULE and (UNIT_AURA_SORT_RULE.ExpirationOnly or UNIT_AURA_SORT_RULE.Default) or nil
    local sortDirection = UNIT_AURA_SORT_DIRECTION and (UNIT_AURA_SORT_DIRECTION.Reverse or UNIT_AURA_SORT_DIRECTION.Normal) or nil
    local ok, result
    if sortRule ~= nil or sortDirection ~= nil then
      ok, result = pcall(C_UnitAuras.GetUnitAuras, unit, filter, nil, sortRule, sortDirection)
    else
      ok, result = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
    end
    if ok and type(result) == "table" then
      auraList = result
      if debugInfo then
        debugInfo.reader = "GetUnitAuras"
      end
    end
  end

  if auraList == nil and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    reader = function(index)
      return C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    end
    if debugInfo then
      debugInfo.reader = "GetAuraDataByIndex"
    end
  elseif helpful and C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    reader = function(index)
      return C_UnitAuras.GetBuffDataByIndex(unit, index)
    end
    if debugInfo then
      debugInfo.reader = "GetBuffDataByIndex"
    end
  elseif not helpful and C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
    reader = function(index)
      return C_UnitAuras.GetDebuffDataByIndex(unit, index)
    end
    if debugInfo then
      debugInfo.reader = "GetDebuffDataByIndex"
    end
  end

  if auraList == nil and not reader then
    if debugInfo then
      debugInfo.stopReason = "no_reader"
      return {}, BuildDebugSummary(debugInfo)
    end
    return {}
  end

  local playerFilteredAuraInstances = nil
  if helpful == false and unit == "target" and targetDebuffFilterMode ~= "all" then
    playerFilteredAuraInstances = CollectPlayerFilteredAuraInstanceIDs(unit, helpful, debugInfo)
  end

  local entries = {}
  local function AddEntryFromAuraData(auraData, index)
    if not auraData then
      return
    end

    local rawIcon = auraData.icon
    local safeIcon = (issecretvalue and issecretvalue(rawIcon)) and nil or rawIcon

    if debugInfo then
      debugInfo.rawCount = (debugInfo.rawCount or 0) + 1
      if #debugInfo.preview < 4 then
        debugInfo.preview[#debugInfo.preview + 1] = BuildDebugPreviewEntry(auraData, nil, index)
      end
    end

    local matchedPlayerFilteredAura = AuraMatchesPlayerFilteredSet(playerFilteredAuraInstances, auraData)
    if safeIcon ~= nil and ShouldIncludeTargetDebuff(trigger, auraData, unit, helpful, index, playerFilteredAuraInstances, matchedPlayerFilteredAura) then
      if debugInfo and matchedPlayerFilteredAura then
        debugInfo.playerMatchedCount = (tonumber(debugInfo.playerMatchedCount or 0) or 0) + 1
      end
      local auraInstanceID = SafeNumber(auraData.auraInstanceID, nil)
      local cachedAuraInfo = GetKnownAuraInstanceInfo(unit, auraInstanceID)
      local spellID = SafeSpellID(auraData.spellId) or (cachedAuraInfo and cachedAuraInfo.spellId) or nil
      local safeName = ResolveAuraName(auraData, spellID, cachedAuraInfo and cachedAuraInfo.name)
      local displayName = auraData and auraData.name
      if displayName == nil then
        displayName = safeName
      end
      local duration, expirationTime, durationObject, hasExpiration = GetAuraTiming(unit, auraInstanceID, auraData)
      local stacks, stackText, stackDisplayValue, hasStackDisplayValue = GetAuraStacks(unit, auraInstanceID, auraData)
      local isPermanent = hasExpiration == false
      local remaining = (not isPermanent) and expirationTime > 0 and math.max(0, expirationTime - GetTime()) or 0
      local isTimed = not isPermanent and (durationObject ~= nil or duration > 0 or expirationTime > GetTime())
      local hasSafeVisibleStack = (type(stackText) == "string" and stackText ~= "")
        or (type(stacks) == "number" and stacks > 0)
      local knownStackCapable = hasSafeVisibleStack
        or (spellID and KNOWN_STACK_SPELLS[spellID] == true)
        or (cachedAuraInfo and cachedAuraInfo.stackCapable == true)

      RememberAuraInstanceInfo(unit, auraInstanceID, spellID, knownStackCapable, safeName)

      entries[#entries + 1] = {
        unit = unit,
        helpful = helpful,
        index = index,
        name = safeName,
        displayName = displayName,
        icon = safeIcon or 134400,
        spellId = spellID,
        auraInstanceID = auraInstanceID,
        duration = duration,
        expirationTime = expirationTime,
        durationObject = durationObject,
        hasExpiration = hasExpiration,
        isPermanent = isPermanent,
        progressType = isTimed and "timed" or "static",
        value = remaining,
        total = duration > 0 and duration or math.max(1, remaining),
        stacks = stacks,
        stackText = stackText,
        stackDisplayValue = stackDisplayValue,
        hasStackDisplayValue = hasStackDisplayValue,
        knownStackCapable = knownStackCapable == true,
        _sortIndex = index,
      }
    end
  end

  if type(auraList) == "table" then
    if #auraList == 0 and debugInfo then
      debugInfo.stopReason = "empty_list"
    end
    for index, auraData in ipairs(auraList) do
      AddEntryFromAuraData(auraData, index)
    end
  else
    local index = 1
    while true do
      local auraData = reader(index)
      if not auraData then
        if debugInfo then
          debugInfo.stopReason = "reader_nil@" .. tostring(index)
        end
        break
      end

      AddEntryFromAuraData(auraData, index)
      index = index + 1
    end
  end

  entries = SortEntries(unit, helpful, entries, debugInfo)

  if maxCount and #entries > maxCount then
    for trimIndex = #entries, maxCount + 1, -1 do
      entries[trimIndex] = nil
    end
  end

  for _, entry in ipairs(entries) do
    entry._sortIndex = nil
  end

  if debugInfo then
    debugInfo.returnedCount = #entries
    for previewIndex = 1, math.min(4, #entries) do
      debugInfo.keptPreview[#debugInfo.keptPreview + 1] = BuildDebugPreviewEntry(entries[previewIndex], entries[previewIndex], entries[previewIndex].index or previewIndex)
    end
    return entries, BuildDebugSummary(debugInfo)
  end

  return entries
end

function UnitAuraList:Collect(trigger, maxCount)
  return self:CollectInternal(trigger, maxCount, false)
end

function UnitAuraList:CollectWithDebug(trigger, maxCount)
  return self:CollectInternal(trigger, maxCount, true)
end

function UnitAuraList:HandleCombatLogEvent()
  if not CombatLogGetCurrentEventInfo then
    return false
  end

  local _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID, _, _, _, spellID, _, _, auraType = CombatLogGetCurrentEventInfo()
  if auraType ~= "DEBUFF" then
    return false
  end

  destGUID = SafeGUID(destGUID)
  spellID = SafeSpellID(spellID)
  if destGUID == nil or spellID == nil then
    return false
  end

  local isAppliedEvent = subevent == "SPELL_AURA_APPLIED"
    or subevent == "SPELL_AURA_REFRESH"
    or subevent == "SPELL_AURA_APPLIED_DOSE"
  local isRemovedEvent = subevent == "SPELL_AURA_REMOVED"
    or subevent == "SPELL_AURA_BROKEN"
    or subevent == "SPELL_AURA_BROKEN_SPELL"

  if not isAppliedEvent and not isRemovedEvent then
    return false
  end

  local isMine = IsMineSourceGUID(sourceGUID)
  local isPlayerControlled = isMine or IsPlayerControlledSourceFlags(sourceFlags)

  if isAppliedEvent then
    if isMine then
      IncrementTrackedDebuff(PLAYER_TRACKED_TARGET_DEBUFFS, destGUID, spellID)
    elseif not isPlayerControlled then
      IncrementTrackedDebuff(NON_PLAYER_TRACKED_TARGET_DEBUFFS, destGUID, spellID)
    end
  elseif isRemovedEvent then
    if isMine then
      DecrementTrackedDebuff(PLAYER_TRACKED_TARGET_DEBUFFS, destGUID, spellID)
    elseif not isPlayerControlled then
      DecrementTrackedDebuff(NON_PLAYER_TRACKED_TARGET_DEBUFFS, destGUID, spellID)
    end
  end

  return destGUID == SafeGUID(UnitGUID and UnitGUID("target"))
end
