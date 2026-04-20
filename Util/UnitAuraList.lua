local _, ns = ...

local UnitAuraList = {}
ns.util.UnitAuraList = UnitAuraList

local REAL_TIME_MODIFIER = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime or nil
local UNIT_AURA_SORT_RULE = Enum and Enum.UnitAuraSortRule or nil
local UNIT_AURA_SORT_DIRECTION = Enum and Enum.UnitAuraSortDirection or nil
local KNOWN_STACK_SPELLS = {}
local KNOWN_AURA_INSTANCES = {}

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

local function AuraWasCastByPlayer(auraData)
  if type(auraData) ~= "table" then
    return false
  end

  local sourceUnit = SafeAuraString(auraData.sourceUnit) or SafeAuraString(auraData.unitCaster)
  if sourceUnit == nil or sourceUnit == "" then
    return false
  end

  if sourceUnit == "player" or sourceUnit == "pet" or sourceUnit == "vehicle" then
    return true
  end

  if UnitIsUnit then
    return UnitIsUnit(sourceUnit, "player") or UnitIsUnit(sourceUnit, "pet") or UnitIsUnit(sourceUnit, "vehicle")
  end

  return false
end

local function AuraSourceIsOtherPlayerControlled(auraData)
  if type(auraData) ~= "table" then
    return false
  end

  local sourceUnit = SafeAuraString(auraData.sourceUnit) or SafeAuraString(auraData.unitCaster)
  if sourceUnit == nil or sourceUnit == "" then
    return false
  end

  if AuraWasCastByPlayer(auraData) then
    return false
  end

  if UnitExists and UnitExists(sourceUnit) then
    if UnitIsPlayer and UnitIsPlayer(sourceUnit) then
      return true
    end
    if UnitPlayerControlled and UnitPlayerControlled(sourceUnit) then
      return true
    end
  end

  if sourceUnit:match("^party%d+$")
    or sourceUnit:match("^raid%d+$")
    or sourceUnit:match("^arena%d+$")
    or sourceUnit:match("^partypet%d+$")
    or sourceUnit:match("^raidpet%d+$")
    or sourceUnit:match("^arenapet%d+$") then
    return true
  end

  return false
end

local function ShouldIncludeTargetDebuff(trigger, auraData, unit, helpful)
  if type(trigger) ~= "table" or trigger.targetMineOrUnownedOnly ~= true then
    return true
  end

  if helpful ~= false or unit ~= "target" then
    return true
  end

  if AuraWasCastByPlayer(auraData) then
    return true
  end

  return not AuraSourceIsOtherPlayerControlled(auraData)
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

local function RememberAuraInstanceInfo(unit, auraInstanceID, spellID, stackCapable)
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

local function ResolveAuraName(auraData)
  local safeName = SafeString(auraData and auraData.name, "")
  if safeName ~= "" then
    return safeName
  end

  return ResolveSpellName(SafeSpellID(auraData and auraData.spellId))
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
  local label = name ~= "" and name or "?"
  return string.format("%s(%s)#%s@%d icon=%s",
    tostring(label),
    tostring(spellID or "?"),
    tostring(auraInstanceID or "?"),
    tonumber(index or 0) or 0,
    tostring(icon ~= nil))
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

  return string.format(
    "unit=%s type=%s combat=%s reader=%s raw=%d returned=%d stop=%s sort=%s ordered=%d preview=%s",
    tostring(debugInfo.unit or ""),
    debugInfo.helpful == false and "debuff" or "buff",
    tostring(debugInfo.inCombat == true),
    tostring(debugInfo.reader or "none"),
    tonumber(debugInfo.rawCount or 0) or 0,
    tonumber(debugInfo.returnedCount or 0) or 0,
    tostring(debugInfo.stopReason or "nil"),
    tostring(debugInfo.sortMode or "none"),
    tonumber(debugInfo.orderedCount or 0) or 0,
    preview
  )
end

function UnitAuraList:CollectInternal(trigger, maxCount, includeDebug)
  local unit, helpful = self:GetTriggerConfig(trigger)
  local debugInfo = includeDebug == true and {
    unit = unit,
    helpful = helpful,
    inCombat = InCombatLockdown and InCombatLockdown() or false,
    reader = "none",
    rawCount = 0,
    returnedCount = 0,
    orderedCount = 0,
    sortMode = "none",
    preview = {},
  } or nil
  if not unit or not UnitExists or not UnitExists(unit) then
    if debugInfo then
      debugInfo.stopReason = unit and "unit_missing" or "unit_nil"
      return {}, BuildDebugSummary(debugInfo)
    end
    return {}
  end

  local reader = nil
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local filter = helpful and "HELPFUL" or "HARMFUL"
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

  if not reader then
    if debugInfo then
      debugInfo.stopReason = "no_reader"
      return {}, BuildDebugSummary(debugInfo)
    end
    return {}
  end

  local entries = {}
  local index = 1
  while true do
    local auraData = reader(index)
    if not auraData then
      if debugInfo then
        debugInfo.stopReason = "reader_nil@" .. tostring(index)
      end
      break
    end

    if auraData.icon == nil then
      if debugInfo then
        debugInfo.stopReason = "missing_icon@" .. tostring(index)
        if #debugInfo.preview < 4 then
          debugInfo.preview[#debugInfo.preview + 1] = BuildDebugPreviewEntry(auraData, nil, index)
        end
      end
      break
    end

    if debugInfo then
      debugInfo.rawCount = (debugInfo.rawCount or 0) + 1
      if #debugInfo.preview < 4 then
        debugInfo.preview[#debugInfo.preview + 1] = BuildDebugPreviewEntry(auraData, nil, index)
      end
    end

    if ShouldIncludeTargetDebuff(trigger, auraData, unit, helpful) then
      local auraInstanceID = SafeNumber(auraData.auraInstanceID, nil)
      local cachedAuraInfo = GetKnownAuraInstanceInfo(unit, auraInstanceID)
      local spellID = SafeSpellID(auraData.spellId) or (cachedAuraInfo and cachedAuraInfo.spellId) or nil
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

      RememberAuraInstanceInfo(unit, auraInstanceID, spellID, knownStackCapable)

      entries[#entries + 1] = {
        unit = unit,
        helpful = helpful,
        index = index,
        name = ResolveAuraName(auraData),
        icon = auraData.icon or 134400,
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

    index = index + 1
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
