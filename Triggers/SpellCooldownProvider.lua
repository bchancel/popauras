local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("spell_cooldown", {
  events = {
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "UNIT_SPELLCAST_SUCCEEDED",
    "PLAYER_TALENT_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "TRAIT_CONFIG_UPDATED",
    "SPELLS_CHANGED",
    "PLAYER_ENTERING_WORLD",
  },
  cache = {},
  recentCasts = {},
})

local spellIDsCache = setmetatable({}, { __mode = "k" })
local REAL_TIME_MODIFIER = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime or nil
local IsCooldownActive
local EnsureSpellAuraIndex
local ClearReadyCooldownCache
local ShouldClearExpiredReadyCooldownCache

local function IterateSpellCooldownTriggers(aura)
  return ns.TriggerBase:IterateTriggers(aura, "spell_cooldown")
end

local function GetCooldownMatchMode(trigger)
  return trigger and trigger.cooldownMatch == "ready" and "ready" or "cooldown"
end

local function ShouldPersistDisplay(trigger, aura)
  if not trigger or trigger.showAlways == false then
    return false
  end
  return not (aura and type(aura.triggers) == "table" and #aura.triggers > 1)
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

local function SafeNumber(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "number" then
    return value
  end
  return nil
end

local function SafeBoolean(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "boolean" then
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

  return SafeNumber(value)
end

local function GetDurationObjectRemaining(durationObject)
  if not durationObject then
    return nil
  end

  local remaining = CallDurationObjectMethod(durationObject, "GetRemainingDuration")
  if remaining ~= nil then
    return math.max(0, remaining)
  end

  local endTime = CallDurationObjectMethod(durationObject, "GetEndTime")
  if endTime ~= nil then
    return math.max(0, endTime - GetTime())
  end

  return nil
end

local function GetDurationObjectTiming(durationObject)
  if not durationObject then
    return 0, 0, nil
  end

  local now = GetTime()
  local remaining = GetDurationObjectRemaining(durationObject)
  local totalDuration = CallDurationObjectMethod(durationObject, "GetTotalDuration") or 0
  local endTime = CallDurationObjectMethod(durationObject, "GetEndTime") or 0
  local expirationTime = 0

  if endTime > now then
    expirationTime = endTime
  elseif remaining ~= nil and remaining > 0 then
    expirationTime = now + remaining
  end

  if totalDuration <= 0 and remaining ~= nil and remaining > 0 then
    totalDuration = remaining
  end

  return totalDuration, expirationTime, remaining
end

local function IsLikelyGCD(duration)
  return type(duration) == "number" and duration > 0 and duration <= 1.6
end

local function IsLearnedCastSource(source)
  return source == "learned_cast" or source == "learned_cast_deferred"
end

local function GetBaseCooldownSeconds(spellId)
  if not spellId or spellId == 0 then
    return 0
  end

  if GetSpellBaseCooldown then
    local ms = GetSpellBaseCooldown(spellId)
    if type(ms) == "number" and ms > 0 then
      local seconds = ms / 1000
      if not IsLikelyGCD(seconds) then
        return seconds
      end
    end
  end

  return 0
end

local function GetConfiguredCooldown(trigger, spellId)
  local manual = tonumber(trigger and trigger.manualCooldown or 0) or 0
  if manual > 0 then
    return manual
  end
  return GetBaseCooldownSeconds(spellId)
end

local function IsUsableCooldownDuration(duration, expirationTime, isOnGCD)
  duration = SafeNumber(duration) or 0
  expirationTime = SafeNumber(expirationTime) or 0

  if duration <= 0 or IsLikelyGCD(duration) or isOnGCD == true then
    return false
  end

  return expirationTime <= 0 or expirationTime > GetTime()
end

local function PreferShorterCooldownDuration(currentDuration, candidateDuration)
  currentDuration = SafeNumber(currentDuration)
  candidateDuration = SafeNumber(candidateDuration)

  if not candidateDuration or candidateDuration <= 0 or IsLikelyGCD(candidateDuration) then
    return currentDuration
  end
  if not currentDuration or currentDuration <= 0 or IsLikelyGCD(currentDuration) then
    return candidateDuration
  end

  return math.min(currentDuration, candidateDuration)
end

local function ShouldProbeSpellCooldownDuration(cooldown)
  if type(cooldown) ~= "table" then
    return false
  end

  local isOnGCD = SafeBoolean(cooldown.isOnGCD)
  if isOnGCD == true then
    return false
  end

  local explicitActive = SafeBoolean(cooldown.isActive)
  if explicitActive ~= nil then
    return explicitActive == true
  end

  local duration = SafeNumber(cooldown.duration)
  local startTime = SafeNumber(cooldown.startTime)
  return (duration and duration > 0 and not IsLikelyGCD(duration)) or (startTime and startTime > 0) or false
end

local function CooldownLooksReady(cooldown, duration, expirationTime, durationObject, isOnGCD)
  if type(cooldown) ~= "table" then
    return false
  end

  local explicitActive = SafeBoolean(cooldown.isActive)
  local enabled = SafeBoolean(cooldown.isEnabled)
  local startTime = SafeNumber(cooldown.startTime) or 0
  local liveDuration = SafeNumber(cooldown.duration) or 0
  local now = GetTime()
  local durationObjectRemaining = GetDurationObjectRemaining(durationObject)

  if explicitActive == true then
    return false
  end

  if enabled == false then
    return false
  end

  if expirationTime and expirationTime > now then
    return false
  end

  if durationObjectRemaining ~= nil and durationObjectRemaining > 0 then
    return false
  end

  if duration and duration > 0 and not IsLikelyGCD(duration) then
    return false
  end

  if startTime > 0 and liveDuration > 0 and not IsLikelyGCD(liveDuration) then
    return false
  end

  if isOnGCD == true then
    return true
  end

  return explicitActive == false or startTime <= 0 or liveDuration <= 0
end

local function GetSpellCooldownTiming(spellId, cooldown)
  local duration = 0
  local expirationTime = 0
  local durationObject = nil
  local now = GetTime()
  local isOnGCD = cooldown and SafeBoolean(cooldown.isOnGCD)

  if ShouldProbeSpellCooldownDuration(cooldown) and C_Spell and C_Spell.GetSpellCooldownDuration then
    local ok, rawDurationObject = pcall(C_Spell.GetSpellCooldownDuration, spellId)
    if ok and rawDurationObject then
      durationObject = rawDurationObject
      local totalDuration = CallDurationObjectMethod(rawDurationObject, "GetTotalDuration")
      local remaining = nil
      if C_Spell.GetSpellCooldownRemaining then
        local remainingOK, rawRemaining = pcall(C_Spell.GetSpellCooldownRemaining, spellId)
        remaining = remainingOK and SafeNumber(rawRemaining) or nil
      end
      if remaining == nil then
        remaining = CallDurationObjectMethod(rawDurationObject, "GetRemainingDuration")
      end
      local startTime = CallDurationObjectMethod(rawDurationObject, "GetStartTime")
      local endTime = CallDurationObjectMethod(rawDurationObject, "GetEndTime")

      if totalDuration and totalDuration > 0 then
        duration = totalDuration
      end
      if remaining and remaining > 0 then
        expirationTime = now + remaining
      elseif endTime and endTime > now then
        expirationTime = endTime
      elseif startTime and startTime > 0 and duration and duration > 0 then
        expirationTime = startTime + duration
      end
      if duration <= 0 and startTime and endTime and endTime > startTime then
        duration = endTime - startTime
      end
    end
  end

  if duration <= 0 then
    local liveDuration = cooldown and SafeNumber(cooldown.duration) or 0
    if liveDuration and liveDuration > 0 and isOnGCD ~= true and not IsLikelyGCD(liveDuration) then
      duration = liveDuration
    end
  end

  if expirationTime <= 0 then
    local startTime = cooldown and SafeNumber(cooldown.startTime)
    local liveDuration = cooldown and SafeNumber(cooldown.duration)
    if startTime and startTime > 0 and liveDuration and liveDuration > 0 and isOnGCD ~= true and not IsLikelyGCD(liveDuration) then
      expirationTime = startTime + liveDuration
    end
  end

  if duration <= 0 and expirationTime > now then
    duration = expirationTime - now
  end

  return duration, expirationTime, durationObject, isOnGCD
end

local function GetSpellCooldownInfoForID(queryId)
  if not C_Spell or not C_Spell.GetSpellCooldown then
    return nil
  end

  queryId = tonumber(queryId or 0) or 0
  if queryId <= 0 then
    return nil
  end

  local ok, cooldown = pcall(C_Spell.GetSpellCooldown, queryId)
  if not ok then
    return nil
  end
  return cooldown
end

local function BuildCooldownQueryIDs(spellId, cache, cdmState)
  local ids = {}
  local seen = {}

  local function add(id)
    id = tonumber(id or 0) or 0
    if id > 0 and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end

  add(spellId)
  add(cache and cache.cooldownID)
  add(cdmState and cdmState.cooldownID)

  if ns.CooldownManager and ns.CooldownManager.GetCooldownIDsForSpellID then
    for _, cooldownID in ipairs(ns.CooldownManager:GetCooldownIDsForSpellID(spellId)) do
      add(cooldownID)
    end
  end

  return ids
end

local function ScoreCooldownQuery(cooldown, duration, expirationTime, durationObject, isOnGCD)
  local score = 0
  if durationObject ~= nil then
    score = score + 120
  end

  if IsCooldownActive(cooldown) then
    score = score + 90
  end

  if type(duration) == "number" and duration > 0 and type(expirationTime) == "number" and expirationTime > GetTime() then
    score = score + 60
  end

  if SafeBoolean(cooldown and cooldown.isActive) == true then
    score = score + 20
  end

  if isOnGCD == true then
    score = score - 150
  end

  return score
end

local function QueryLooksLikeBorrowedGCD(spellId, queryId, cooldown, duration, expirationTime, durationObject, isOnGCD)
  spellId = tonumber(spellId or 0) or 0
  queryId = tonumber(queryId or 0) or 0
  if spellId <= 0 or queryId <= 0 or queryId == spellId then
    return false
  end

  if isOnGCD == true then
    return true
  end

  local liveDuration = SafeNumber(cooldown and cooldown.duration) or 0
  local remaining = 0
  if type(expirationTime) == "number" and expirationTime > GetTime() then
    remaining = expirationTime - GetTime()
  end

  if liveDuration > 0 and IsLikelyGCD(liveDuration) then
    return true
  end

  if type(duration) == "number" and duration > 0 and IsLikelyGCD(duration) then
    return true
  end

  if durationObject ~= nil and remaining > 0 and IsLikelyGCD(remaining) then
    return true
  end

  return false
end

local function QueryHasUsableExplicitState(cooldown, duration, expirationTime, durationObject, isOnGCD)
  if type(cooldown) ~= "table" or isOnGCD == true then
    return false
  end

  local explicitActive = SafeBoolean(cooldown.isActive)
  if explicitActive == nil then
    return false
  end

  if explicitActive == false then
    return CooldownLooksReady(cooldown, duration, expirationTime, durationObject, isOnGCD)
  end

  return durationObject ~= nil or IsUsableCooldownDuration(duration, expirationTime, isOnGCD)
end

local function SelectBestCooldownQuery(spellId, cache, cdmState)
  local primaryCooldown = GetSpellCooldownInfoForID(spellId)
  if primaryCooldown then
    local duration, expirationTime, durationObject, isOnGCD = GetSpellCooldownTiming(spellId, primaryCooldown)
    if QueryLooksLikeBorrowedGCD(spellId, spellId, primaryCooldown, duration, expirationTime, durationObject, isOnGCD) then
      duration = 0
      expirationTime = 0
      durationObject = nil
      isOnGCD = true
    end
    if QueryHasUsableExplicitState(primaryCooldown, duration, expirationTime, durationObject, isOnGCD) then
      return spellId, primaryCooldown, duration, expirationTime, durationObject, isOnGCD
    end
  end

  local best = nil

  for _, queryId in ipairs(BuildCooldownQueryIDs(spellId, cache, cdmState)) do
    local cooldown = GetSpellCooldownInfoForID(queryId)
    if cooldown then
      local duration, expirationTime, durationObject, isOnGCD = GetSpellCooldownTiming(queryId, cooldown)
      if QueryLooksLikeBorrowedGCD(spellId, queryId, cooldown, duration, expirationTime, durationObject, isOnGCD) then
        duration = 0
        expirationTime = 0
        durationObject = nil
        isOnGCD = true
      end
      local score = ScoreCooldownQuery(cooldown, duration, expirationTime, durationObject, isOnGCD)

      if not best
        or score > best.score
        or (score == best.score and queryId == spellId and best.queryId ~= spellId)
        or (score == best.score and (expirationTime or 0) < (best.expirationTime or 0))
        or (score == best.score and (expirationTime or 0) == (best.expirationTime or 0) and (duration or 0) < (best.duration or 0)) then
        best = {
          queryId = queryId,
          cooldown = cooldown,
          duration = duration,
          expirationTime = expirationTime,
          durationObject = durationObject,
          isOnGCD = isOnGCD,
          score = score,
        }
      end
    end
  end

  if best then
    return best.queryId, best.cooldown, best.duration, best.expirationTime, best.durationObject, best.isOnGCD
  end

  return spellId, nil, 0, 0, nil, nil
end

local function GetSpellChargeTiming(spellId, chargeInfo)
  local duration = chargeInfo and SafeNumber(chargeInfo.cooldownDuration) or 0
  local expirationTime = 0
  local durationObject = nil
  local now = GetTime()

  if C_Spell and C_Spell.GetSpellChargeDuration then
    local ok, rawDurationObject = pcall(C_Spell.GetSpellChargeDuration, spellId)
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
      elseif startTime and startTime > 0 and duration and duration > 0 then
        expirationTime = startTime + duration
      end
      if duration <= 0 and startTime and endTime and endTime > startTime then
        duration = endTime - startTime
      end
    end
  end

  if expirationTime <= 0 then
    local startTime = chargeInfo and SafeNumber(chargeInfo.cooldownStartTime)
    if startTime and startTime > 0 and duration and duration > 0 then
      expirationTime = startTime + duration
    end
  end

  if duration <= 0 and expirationTime > now then
    duration = expirationTime - now
  end

  return duration, expirationTime, durationObject
end

local function GetCDMState(spellId)
  if not ns.CooldownManager or not ns.CooldownManager.GetCooldownStateForSpell then
    return nil
  end
  return ns.CooldownManager:GetCooldownStateForSpell(spellId)
end

local function HasRecoverableCDMObjectSignal(cdmState)
  return type(cdmState) == "table"
    and cdmState.active == true
    and cdmState.isOnGCD ~= true
    and cdmState.durationObject ~= nil
end

local function IsUsableCDMCooldownState(cdmState)
  if type(cdmState) ~= "table" or cdmState.active ~= true then
    return false
  end

  if cdmState.durationObject ~= nil then
    return cdmState.isOnActualCooldown == true
      or IsUsableCooldownDuration(cdmState.duration, cdmState.expirationTime, false)
  end

  return IsUsableCooldownDuration(cdmState.duration, cdmState.expirationTime, false)
end

local function GetRecentCastFallbackCooldownDuration(spellId, cache, sharedCache, configuredCooldown, cdmState)
  local candidates = {
    SafeNumber(cache and cache.duration),
    SafeNumber(sharedCache and sharedCache.duration),
    SafeNumber(configuredCooldown),
    SafeNumber(cdmState and cdmState.maxDuration),
    GetBaseCooldownSeconds(spellId),
  }

  for _, candidate in ipairs(candidates) do
    if candidate and candidate > 0 and not IsLikelyGCD(candidate) then
      return candidate
    end
  end

  return 0
end

local function GetCDMAuraState(spellId)
  if not ns.CooldownManager or not ns.CooldownManager.GetAuraStateForSpell then
    return nil
  end

  -- Spell cooldown triggers should only borrow player aura state. Target debuffs
  -- with the same spell ID can otherwise replace the actual cooldown state.
  local auraState = ns.CooldownManager:GetAuraStateForSpell(spellId, "player")
  if auraState and auraState.auraData then
    return auraState
  end

  return nil
end

local function GetSecretSafeAuraTiming(unit, auraInstanceID, auraData)
  local duration = 0
  local expirationTime = 0
  local durationObject = nil
  local now = GetTime()

  if C_UnitAuras and C_UnitAuras.GetAuraDurationRemaining and auraInstanceID and unit then
    local ok, remaining = pcall(C_UnitAuras.GetAuraDurationRemaining, unit, auraInstanceID)
    remaining = ok and SafeNumber(remaining) or nil
    if remaining and remaining > 0 then
      expirationTime = now + remaining
    end
  end

  if C_UnitAuras and C_UnitAuras.GetAuraDuration and auraInstanceID and unit then
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
      elseif startTime and startTime > 0 and duration and duration > 0 then
        expirationTime = startTime + duration
      end
      if duration <= 0 and startTime and endTime and endTime > startTime then
        duration = endTime - startTime
      end
      if type(rawDurationObject) == "table" then
        duration = SafeNumber(rawDurationObject.duration) or duration
        remaining = SafeNumber(rawDurationObject.remainingTime) or remaining
        startTime = SafeNumber(rawDurationObject.startTime) or startTime
        if remaining and remaining > 0 then
          expirationTime = now + remaining
        elseif startTime and startTime > 0 and duration and duration > 0 then
          expirationTime = startTime + duration
        end
      end
    end
  end

  if duration <= 0 and C_UnitAuras and C_UnitAuras.GetAuraBaseDuration and auraInstanceID and unit then
    local ok, baseDuration = pcall(C_UnitAuras.GetAuraBaseDuration, unit, auraInstanceID, SafeNumber(auraData and auraData.spellId))
    duration = ok and (SafeNumber(baseDuration) or duration) or duration
  end

  if duration <= 0 then
    duration = SafeNumber(auraData and auraData.duration) or 0
  end
  if expirationTime <= 0 then
    expirationTime = SafeNumber(auraData and auraData.expirationTime) or 0
  end
  if duration <= 0 and expirationTime > now then
    duration = expirationTime - now
  end

  return duration, expirationTime, durationObject
end

local function GetSecretSafeAuraStacks(unit, auraInstanceID, auraData)
  local liveAuraData = auraData
  if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID and unit and auraInstanceID then
    local ok, refreshedAuraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
    if ok and refreshedAuraData then
      liveAuraData = refreshedAuraData
    end
  end

  local stacks = SafeNumber(liveAuraData and liveAuraData.applications)
    or SafeNumber(liveAuraData and liveAuraData.charges)
    or SafeNumber(auraData and auraData.applications)
    or SafeNumber(auraData and auraData.charges)
  local stackText = (stacks and stacks > 0) and tostring(stacks) or nil
  local rawStackValue = PickDisplayValue(
    liveAuraData and liveAuraData.applications,
    liveAuraData and liveAuraData.charges,
    auraData and auraData.applications,
    auraData and auraData.charges
  )

  if C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount and auraInstanceID and unit then
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
  local stackDisplayValue, hasStackDisplayValue = BuildStackDisplayValue(rawStackValue, stackText, stacks or 0, false)
  return stacks or 0, stackText, stackDisplayValue, hasStackDisplayValue
end

local function GetSafeAuraString(value)
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "string" then
    return value
  end
  return nil
end

local function GetCDMAuraDetails(cdmAuraState, expectedSpellId)
  if type(cdmAuraState) ~= "table" or type(cdmAuraState.auraData) ~= "table" then
    return nil
  end

  local auraData = cdmAuraState.auraData
  local unit = cdmAuraState.unit
  local auraInstanceID = cdmAuraState.auraInstanceID
  local duration, expirationTime, durationObject = GetSecretSafeAuraTiming(unit, auraInstanceID, auraData)
  local stacks, stackText, stackDisplayValue, hasStackDisplayValue = GetSecretSafeAuraStacks(unit, auraInstanceID, auraData)
  local auraSpellId = SafeNumber(auraData.spellId) or SafeNumber(auraData.spellID)
  local safeExpectedSpellId = tonumber(expectedSpellId or 0) or 0
  local spellMatches = safeExpectedSpellId <= 0 or auraSpellId == nil or auraSpellId == safeExpectedSpellId
  local auraActive = spellMatches and auraInstanceID ~= nil and (stacks > 0 or duration > 0 or expirationTime > GetTime() or auraData ~= nil)

  return {
    active = auraActive,
    duration = auraActive and duration or 0,
    expirationTime = auraActive and expirationTime or 0,
    durationObject = auraActive and durationObject or nil,
    stacks = auraActive and stacks or 0,
    stackText = auraActive and stackText or nil,
    stackDisplayValue = auraActive and stackDisplayValue or nil,
    hasStackDisplayValue = auraActive and hasStackDisplayValue or false,
    icon = auraActive and SafeNumber(auraData.icon) or nil,
    name = auraActive and GetSafeAuraString(auraData.name) or nil,
    auraInstanceID = auraInstanceID,
    unit = unit,
    spellId = auraSpellId,
    spellMatches = spellMatches,
  }
end

local function BuildDebugBits(parts)
  local result = {}
  for _, value in ipairs(parts or {}) do
    if value and value ~= "" then
      result[#result + 1] = tostring(value)
    end
  end
  return table.concat(result, " ")
end

local function QuantizeTime(value)
  value = SafeNumber(value)
  if value == nil then
    return ""
  end
  return string.format("%.3f", value)
end

local function GetDurationObjectWindow(durationObject)
  if not durationObject then
    return nil, nil, nil
  end

  local startTime = CallDurationObjectMethod(durationObject, "GetStartTime")
  local endTime = CallDurationObjectMethod(durationObject, "GetEndTime")
  local totalDuration = CallDurationObjectMethod(durationObject, "GetTotalDuration")
  if totalDuration == nil and startTime ~= nil and endTime ~= nil and endTime > startTime then
    totalDuration = endTime - startTime
  end

  return startTime, endTime, totalDuration
end

local function BuildCooldownEventQueryIDs(spellId, cache)
  local ids = {}
  local seen = {}

  local function add(id)
    id = tonumber(id or 0) or 0
    if id > 0 and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end

  add(spellId)
  add(cache and cache.cooldownID)

  if ns.CooldownManager and ns.CooldownManager.GetCooldownIDsForSpellID then
    for _, cooldownID in ipairs(ns.CooldownManager:GetCooldownIDsForSpellID(spellId)) do
      add(cooldownID)
    end
  end

  table.sort(ids)
  return ids
end

local function BuildCooldownEventQuerySignature(spellId, queryId)
  local cooldown = GetSpellCooldownInfoForID(queryId)
  if type(cooldown) ~= "table" then
    return string.format("%d:nil", queryId)
  end

  local duration = SafeNumber(cooldown.duration) or 0
  local startTime = SafeNumber(cooldown.startTime) or 0
  local expirationTime = (startTime > 0 and duration > 0) and (startTime + duration) or 0
  local durationObject = nil
  if (startTime <= 0 or duration <= 0) and ShouldProbeSpellCooldownDuration(cooldown) and C_Spell and C_Spell.GetSpellCooldownDuration then
    local ok, rawDurationObject = pcall(C_Spell.GetSpellCooldownDuration, queryId)
    if ok then
      durationObject = rawDurationObject
    end
  end

  local objectStartTime, objectEndTime, objectDuration = GetDurationObjectWindow(durationObject)
  local isOnGCD = SafeBoolean(cooldown.isOnGCD)
  if QueryLooksLikeBorrowedGCD(spellId, queryId, cooldown, duration, expirationTime, durationObject, isOnGCD) then
    duration = 0
    startTime = 0
    expirationTime = 0
    objectStartTime = nil
    objectEndTime = nil
    objectDuration = nil
    durationObject = nil
    isOnGCD = true
  end

  return table.concat({
    tostring(queryId),
    tostring(SafeBoolean(cooldown.isActive)),
    tostring(SafeBoolean(cooldown.isEnabled)),
    tostring(isOnGCD == true),
    QuantizeTime(startTime),
    QuantizeTime(duration),
    QuantizeTime(expirationTime),
    QuantizeTime(objectStartTime),
    QuantizeTime(objectEndTime),
    QuantizeTime(objectDuration),
    durationObject ~= nil and "1" or "0",
  }, ":")
end

local function BuildChargeEventSignature(spellId)
  if not C_Spell or not C_Spell.GetSpellCharges then
    return ""
  end

  local chargeInfo = C_Spell.GetSpellCharges(spellId)
  if type(chargeInfo) ~= "table" then
    return "charges:nil"
  end

  local durationObject = nil
  local currentCharges = SafeNumber(chargeInfo.currentCharges)
  local maxCharges = SafeNumber(chargeInfo.maxCharges)
  local cooldownStartTime = SafeNumber(chargeInfo.cooldownStartTime)
  local cooldownDuration = SafeNumber(chargeInfo.cooldownDuration)
  local missingCharges = currentCharges ~= nil and maxCharges ~= nil and maxCharges > 1 and currentCharges < maxCharges
  if missingCharges and (not cooldownStartTime or cooldownStartTime <= 0 or not cooldownDuration or cooldownDuration <= 0) and C_Spell.GetSpellChargeDuration then
    local ok, rawDurationObject = pcall(C_Spell.GetSpellChargeDuration, spellId)
    if ok then
      durationObject = rawDurationObject
    end
  end

  local objectStartTime, objectEndTime, objectDuration = GetDurationObjectWindow(durationObject)
  return table.concat({
    "charges",
    tostring(currentCharges or ""),
    tostring(maxCharges or ""),
    tostring(SafeBoolean(chargeInfo.isActive)),
    QuantizeTime(cooldownStartTime),
    QuantizeTime(cooldownDuration),
    QuantizeTime(objectStartTime),
    QuantizeTime(objectEndTime),
    QuantizeTime(objectDuration),
    durationObject ~= nil and "1" or "0",
  }, ":")
end

local function BuildCooldownEventSignature(spellId, cache)
  local parts = {}

  for _, queryId in ipairs(BuildCooldownEventQueryIDs(spellId, cache)) do
    parts[#parts + 1] = BuildCooldownEventQuerySignature(spellId, queryId)
  end

  parts[#parts + 1] = BuildChargeEventSignature(spellId)

  return table.concat(parts, "|")
end

local function GetCooldownDebugSpellLabel(spellId)
  spellId = tonumber(spellId or 0) or 0
  local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId) or nil
  if spellName and spellName ~= "" then
    return string.format("%s (%d)", tostring(spellName), spellId)
  end
  return string.format("Spell %d", spellId)
end

local function BuildRecentPlayerCastDebugSummary(castInfo, age)
  castInfo = type(castInfo) == "table" and castInfo or nil
  local castSpellId = tonumber(castInfo and castInfo.spellId or 0) or 0
  if castSpellId <= 0 then
    return "spell="
  end

  return BuildDebugBits({
    string.format("spell=%s", GetCooldownDebugSpellLabel(castSpellId)),
    string.format("age=%s", QuantizeTime(age)),
  })
end

local function BuildCacheDebugSummary(cache)
  cache = type(cache) == "table" and cache or nil
  local now = GetTime()
  local expirationTime = SafeNumber(cache and cache.expirationTime) or 0
  local remaining = expirationTime > now and (expirationTime - now) or 0
  return BuildDebugBits({
    string.format("src=%s", tostring(cache and cache.source or "")),
    string.format("active=%s", tostring(cache and cache.active == true)),
    string.format("dur=%s", QuantizeTime(cache and cache.duration)),
    string.format("exp=%s", QuantizeTime(expirationTime > 0 and expirationTime or nil)),
    string.format("rem=%s", QuantizeTime(remaining > 0 and remaining or nil)),
    string.format("cdmID=%s", tostring(cache and cache.cooldownID or "")),
    string.format("charges=%s", tostring(cache and cache.currentCharges or "")),
    string.format("max=%s", tostring(cache and cache.maxCharges or "")),
    string.format("chargeSpell=%s", tostring(cache and cache.isChargeSpell == true)),
    string.format("deferred=%s", tostring(cache and cache.deferredByActiveAura == true)),
    string.format("deferredExp=%s", QuantizeTime(cache and cache.deferredExpirationTime)),
  })
end

local function BuildCooldownQueryDebugSummary(spellId, queryId)
  local cooldown = GetSpellCooldownInfoForID(queryId)
  if type(cooldown) ~= "table" then
    return string.format("query=%d nil", tonumber(queryId or 0) or 0)
  end

  local duration, expirationTime, durationObject, isOnGCD = GetSpellCooldownTiming(queryId, cooldown)
  local borrowedGCD = QueryLooksLikeBorrowedGCD(spellId, queryId, cooldown, duration, expirationTime, durationObject, isOnGCD)
  if borrowedGCD then
    duration = 0
    expirationTime = 0
    durationObject = nil
    isOnGCD = true
  end

  local startTime = SafeNumber(cooldown.startTime)
  local liveDuration = SafeNumber(cooldown.duration)
  local objectStartTime, objectEndTime, objectDuration = GetDurationObjectWindow(durationObject)
  local objectRemaining = GetDurationObjectRemaining(durationObject)
  return BuildDebugBits({
    string.format("query=%d", tonumber(queryId or 0) or 0),
    string.format("active=%s", tostring(SafeBoolean(cooldown.isActive))),
    string.format("enabled=%s", tostring(SafeBoolean(cooldown.isEnabled))),
    string.format("gcd=%s", tostring(isOnGCD == true)),
    string.format("borrowedGCD=%s", tostring(borrowedGCD == true)),
    string.format("start=%s", QuantizeTime(startTime)),
    string.format("liveDur=%s", QuantizeTime(liveDuration)),
    string.format("dur=%s", QuantizeTime(duration)),
    string.format("exp=%s", QuantizeTime(expirationTime)),
    string.format("objStart=%s", QuantizeTime(objectStartTime)),
    string.format("objEnd=%s", QuantizeTime(objectEndTime)),
    string.format("objDur=%s", QuantizeTime(objectDuration)),
    string.format("objRem=%s", QuantizeTime(objectRemaining)),
  })
end

local function BuildChargeDebugSummary(spellId)
  if not C_Spell or not C_Spell.GetSpellCharges then
    return "charges unsupported"
  end

  local chargeInfo = C_Spell.GetSpellCharges(spellId)
  if type(chargeInfo) ~= "table" then
    return "charges nil"
  end

  local chargeDuration, chargeExpirationTime, chargeDurationObject = GetSpellChargeTiming(spellId, chargeInfo)
  local objectStartTime, objectEndTime, objectDuration = GetDurationObjectWindow(chargeDurationObject)
  local objectRemaining = GetDurationObjectRemaining(chargeDurationObject)
  return BuildDebugBits({
    string.format("charges=%s", tostring(SafeNumber(chargeInfo.currentCharges) or "")),
    string.format("max=%s", tostring(SafeNumber(chargeInfo.maxCharges) or "")),
    string.format("active=%s", tostring(SafeBoolean(chargeInfo.isActive))),
    string.format("start=%s", QuantizeTime(chargeInfo and chargeInfo.cooldownStartTime)),
    string.format("liveDur=%s", QuantizeTime(chargeInfo and chargeInfo.cooldownDuration)),
    string.format("dur=%s", QuantizeTime(chargeDuration)),
    string.format("exp=%s", QuantizeTime(chargeExpirationTime)),
    string.format("objStart=%s", QuantizeTime(objectStartTime)),
    string.format("objEnd=%s", QuantizeTime(objectEndTime)),
    string.format("objDur=%s", QuantizeTime(objectDuration)),
    string.format("objRem=%s", QuantizeTime(objectRemaining)),
  })
end

local function BuildCDMDebugSummary(cdmState, cdmAuraDetails)
  local cdmObjectDuration, cdmObjectExpirationTime, cdmObjectRemaining = GetDurationObjectTiming(cdmState and cdmState.durationObject or nil)
  local cdmLine = BuildDebugBits({
    string.format("id=%s", tostring(cdmState and cdmState.cooldownID or "")),
    string.format("active=%s", tostring(cdmState and cdmState.active == true)),
    string.format("rawActive=%s", tostring(cdmState and cdmState.rawActive == true)),
    string.format("actual=%s", tostring(cdmState and cdmState.isOnActualCooldown == true)),
    string.format("gcd=%s", tostring(cdmState and cdmState.isOnGCD == true)),
    string.format("dur=%s", QuantizeTime(cdmState and cdmState.duration)),
    string.format("exp=%s", QuantizeTime(cdmState and cdmState.expirationTime)),
    string.format("maxDur=%s", QuantizeTime(cdmState and cdmState.maxDuration)),
    string.format("count=%s", tostring(cdmState and cdmState.count or "")),
    string.format("text=%s", tostring(cdmState and cdmState.countText or "")),
    string.format("obj=%s", tostring(cdmState and cdmState.durationObject ~= nil)),
    string.format("objDur=%s", QuantizeTime(cdmObjectDuration > 0 and cdmObjectDuration or nil)),
    string.format("objExp=%s", QuantizeTime(cdmObjectExpirationTime > 0 and cdmObjectExpirationTime or nil)),
    string.format("objRem=%s", QuantizeTime(cdmObjectRemaining)),
  })
  local auraLine = BuildDebugBits({
    string.format("active=%s", tostring(cdmAuraDetails and cdmAuraDetails.active == true)),
    string.format("spell=%s", tostring(cdmAuraDetails and cdmAuraDetails.spellId or "")),
    string.format("match=%s", tostring(cdmAuraDetails and cdmAuraDetails.spellMatches ~= false or false)),
    string.format("inst=%s", tostring(cdmAuraDetails and cdmAuraDetails.auraInstanceID or "")),
    string.format("unit=%s", tostring(cdmAuraDetails and cdmAuraDetails.unit or "")),
    string.format("stacks=%s", tostring(cdmAuraDetails and cdmAuraDetails.stacks or "")),
    string.format("text=%s", tostring(cdmAuraDetails and cdmAuraDetails.stackText or "")),
    string.format("dur=%s", QuantizeTime(cdmAuraDetails and cdmAuraDetails.duration)),
    string.format("exp=%s", QuantizeTime(cdmAuraDetails and cdmAuraDetails.expirationTime)),
    string.format("obj=%s", tostring(cdmAuraDetails and cdmAuraDetails.durationObject ~= nil)),
  })
  return cdmLine, auraLine
end

local function BuildCooldownStateDebugSummary(state)
  if type(state) ~= "table" then
    return "state=nil"
  end

  return BuildDebugBits({
    string.format("show=%s", tostring(state.show)),
    string.format("matched=%s", tostring(state.matched)),
    string.format("active=%s", tostring(state.active)),
    string.format("ready=%s", tostring(state.isReady)),
    string.format("enabled=%s", tostring(state.isEnabled ~= false)),
    string.format("src=%s", tostring(state.source or "")),
    string.format("dur=%s", QuantizeTime(state.duration)),
    string.format("exp=%s", QuantizeTime(state.expirationTime)),
    string.format("stacks=%s", tostring(state.stacks or "")),
    string.format("text=%s", tostring(state.stackText or "")),
    string.format("status=%s", tostring(state.statusText or "")),
  })
end

local function BuildCooldownRenderDebugSummary(region, state, now)
  region = type(region) == "table" and region or nil
  state = type(state) == "table" and state or nil
  now = SafeNumber(now) or GetTime()

  local regionKind = "unknown"
  if region and region.bar then
    regionKind = "bar"
  elseif region and region.cooldown then
    regionKind = "icon"
  elseif region and region.rows then
    regionKind = "aura_bar_list"
  end

  local expirationTime = SafeNumber(state and state.expirationTime) or 0
  local numericRemaining = expirationTime > 0 and math.max(0, expirationTime - now) or nil
  local objectRemaining = GetDurationObjectRemaining(state and state.durationObject or nil)
  local barValue, barMin, barMax = nil, nil, nil
  if region and region.bar and region.bar.GetValue then
    local ok, value = pcall(region.bar.GetValue, region.bar)
    if ok then
      barValue = SafeNumber(value)
    end
  end
  if region and region.bar and region.bar.GetMinMaxValues then
    local ok, minValue, maxValue = pcall(region.bar.GetMinMaxValues, region.bar)
    if ok then
      barMin = SafeNumber(minValue)
      barMax = SafeNumber(maxValue)
    end
  end

  local timerText = region and region.timerText and region.timerText.GetText and region.timerText:GetText() or nil
  return BuildDebugBits({
    string.format("kind=%s", tostring(regionKind)),
    string.format("stateObj=%s", tostring(state and state.durationObject ~= nil or false)),
    string.format("progress=%s", tostring(state and state.progressType or "")),
    string.format("numRem=%s", QuantizeTime(numericRemaining)),
    string.format("objRem=%s", QuantizeTime(objectRemaining)),
    string.format("barMin=%s", QuantizeTime(barMin)),
    string.format("barMax=%s", QuantizeTime(barMax)),
    string.format("barValue=%s", QuantizeTime(barValue)),
    string.format("timerShown=%s", tostring(region and region.timerText and region.timerText.IsShown and region.timerText:IsShown() or false)),
    string.format("timerText=%s", tostring(timerText or "")),
    string.format("nativeShown=%s", tostring(region and region.timerCooldown and region.timerCooldown.IsShown and region.timerCooldown:IsShown() or false)),
    string.format("swipeShown=%s", tostring(region and region.cooldown and region.cooldown.IsShown and region.cooldown:IsShown() or false)),
  })
end

function provider:IsCooldownDebugSpell(spellId)
  spellId = tonumber(spellId or 0) or 0
  return spellId > 0 and spellId == (tonumber(self.cooldownDebugSpellID or 0) or 0)
end

function provider:IsCooldownDebugAura(aura, state)
  if self:IsCooldownDebugSpell(state and state.spellId) then
    return true
  end

  if type(aura) ~= "table" then
    return false
  end

  for _, trigger in IterateSpellCooldownTriggers(aura) do
    for _, spellId in ipairs(GetSpellIDs(trigger)) do
      if self:IsCooldownDebugSpell(spellId) then
        return true
      end
    end
  end

  return false
end

function provider:AppendCooldownDebugHistory(lines)
  if type(lines) ~= "table" or #lines == 0 then
    return
  end

  self.cooldownDebugHistory = self.cooldownDebugHistory or {}
  self.cooldownDebugHistoryMaxLines = tonumber(self.cooldownDebugHistoryMaxLines or 240) or 240

  for _, line in ipairs(lines) do
    self.cooldownDebugHistory[#self.cooldownDebugHistory + 1] = tostring(line)
  end

  while #self.cooldownDebugHistory > self.cooldownDebugHistoryMaxLines do
    table.remove(self.cooldownDebugHistory, 1)
  end
end

function provider:BuildCooldownDebugLines(spellId, reason, aura, state, extra)
  spellId = tonumber(spellId or 0) or 0
  if spellId <= 0 then
    return {}
  end

  local now = GetTime()
  local cache = self.cache and self.cache[spellId] or nil
  local cdmState = GetCDMState(spellId)
  local cdmAuraDetails = GetCDMAuraDetails(GetCDMAuraState(spellId), spellId)
  local querySummaries = {}
  for _, queryId in ipairs(BuildCooldownQueryIDs(spellId, cache, cdmState)) do
    querySummaries[#querySummaries + 1] = BuildCooldownQueryDebugSummary(spellId, queryId)
  end

  local lastCastAt = self.recentCasts and self.recentCasts[spellId] or nil
  local recentCastAge = (type(lastCastAt) == "number" and lastCastAt > 0) and (now - lastCastAt) or nil
  local lastPlayerCast = self.cooldownDebugLastPlayerCast
  local recentPlayerCastAge = (type(lastPlayerCast and lastPlayerCast.at) == "number" and lastPlayerCast.at > 0)
    and (now - lastPlayerCast.at)
    or nil
  local cdmLine, cdmAuraLine = BuildCDMDebugSummary(cdmState, cdmAuraDetails)
  local header = BuildDebugBits({
    string.format("t=%s", QuantizeTime(now)),
    string.format("spell=%s", GetCooldownDebugSpellLabel(spellId)),
    string.format("reason=%s", tostring(reason or "")),
    aura and aura.name and string.format("aura=%s", tostring(aura.name)) or nil,
    extra and extra ~= "" and extra or nil,
  })

  local lines = {
    header,
    "  cache " .. BuildCacheDebugSummary(cache),
    "  recentCast age=" .. tostring(recentCastAge and QuantizeTime(recentCastAge) or ""),
    "  queries " .. table.concat(querySummaries, " || "),
    "  charge " .. BuildChargeDebugSummary(spellId),
    "  cdm " .. cdmLine,
    "  cdmAura " .. cdmAuraLine,
  }

  if recentPlayerCastAge and recentPlayerCastAge <= 2 then
    lines[#lines + 1] = "  playerCast " .. BuildRecentPlayerCastDebugSummary(lastPlayerCast, recentPlayerCastAge)
  end

  if state then
    lines[#lines + 1] = "  final " .. BuildCooldownStateDebugSummary(state)
    if state.debugExtra and state.debugExtra ~= "" then
      lines[#lines + 1] = "  decision " .. tostring(state.debugExtra)
    end
  end

  return lines
end

function provider:LogCooldownDebug(spellId, reason, aura, state, extra)
  if not self:IsCooldownDebugSpell(spellId) then
    return
  end

  local lines = self:BuildCooldownDebugLines(spellId, reason, aura, state, extra)
  self:AppendCooldownDebugHistory(lines)

  if ns.Debug and ns.Debug.Log then
    for _, line in ipairs(lines) do
      ns.Debug:Log("CDWatch", line)
    end
  end
end

function provider:LogCooldownRenderDebug(aura, state, region, reason, extra)
  if not self:IsCooldownDebugAura(aura, state) then
    return
  end

  local spellId = tonumber(state and state.spellId or self.cooldownDebugSpellID or 0) or 0
  if spellId <= 0 then
    return
  end

  self.cooldownDebugLastRenderSignatures = self.cooldownDebugLastRenderSignatures or {}
  local stateKey = tostring(aura and aura.id or spellId)
  local now = GetTime()
  local expirationTime = SafeNumber(state and state.expirationTime) or 0
  local numericRemaining = expirationTime > 0 and math.max(0, expirationTime - now) or 0
  local objectRemaining = GetDurationObjectRemaining(state and state.durationObject or nil) or 0
  local renderSignature = table.concat({
    tostring(reason or ""),
    tostring(state and state.show),
    tostring(state and state.active),
    tostring(state and state.isReady),
    tostring(state and state.source or ""),
    QuantizeTime(state and state.duration),
    QuantizeTime(expirationTime > 0 and expirationTime or nil),
    QuantizeTime(numericRemaining > 0 and numericRemaining or nil),
    QuantizeTime(objectRemaining > 0 and objectRemaining or nil),
    tostring(state and state.durationObject ~= nil),
    tostring(region and region.timerCooldown and region.timerCooldown.IsShown and region.timerCooldown:IsShown() or false),
    tostring(region and region.cooldown and region.cooldown.IsShown and region.cooldown:IsShown() or false),
    tostring(region and region.timerText and region.timerText.GetText and region.timerText:GetText() or ""),
  }, "|")

  if self.cooldownDebugLastRenderSignatures[stateKey] == renderSignature then
    return
  end
  self.cooldownDebugLastRenderSignatures[stateKey] = renderSignature

  local lines = {
    BuildDebugBits({
      string.format("t=%s", QuantizeTime(now)),
      string.format("spell=%s", GetCooldownDebugSpellLabel(spellId)),
      string.format("reason=%s", tostring(reason or "render")),
      aura and aura.name and string.format("aura=%s", tostring(aura.name)) or nil,
      extra and extra ~= "" and extra or nil,
    }),
    "  render " .. BuildCooldownRenderDebugSummary(region, state, now),
    "  final " .. BuildCooldownStateDebugSummary(state),
  }
  if state and state.debugExtra and state.debugExtra ~= "" then
    lines[#lines + 1] = "  decision " .. tostring(state.debugExtra)
  end

  self:AppendCooldownDebugHistory(lines)
  if ns.Debug and ns.Debug.Log then
    for _, line in ipairs(lines) do
      ns.Debug:Log("CDRender", line)
    end
  end
end

function provider:QueueCooldownDebugReason(spellId, reason)
  if not self:IsCooldownDebugSpell(spellId) then
    return
  end

  self.cooldownDebugPendingReasons = self.cooldownDebugPendingReasons or {}
  self.cooldownDebugPendingReasons[spellId] = {
    reason = tostring(reason or "event"),
    expiresAt = GetTime() + 0.25,
  }
end

function provider:GetCooldownDebugReason(spellId)
  if not self:IsCooldownDebugSpell(spellId) then
    return nil
  end

  local pending = self.cooldownDebugPendingReasons and self.cooldownDebugPendingReasons[spellId] or nil
  if type(pending) ~= "table" then
    return nil
  end
  if (pending.expiresAt or 0) < GetTime() then
    self.cooldownDebugPendingReasons[spellId] = nil
    return nil
  end
  return pending.reason
end

function provider:SetCooldownDebugSpell(spellId)
  spellId = tonumber(spellId or 0) or 0
  self.cooldownDebugSpellID = spellId > 0 and spellId or nil
  self.cooldownDebugHistory = {}
  self.cooldownDebugPendingReasons = {}
  self.cooldownDebugLastEvalSignatures = {}
  self.cooldownDebugLastRenderSignatures = {}
  self.cooldownDebugLastPlayerCast = nil
  self.cooldownDebugHistoryMaxLines = tonumber(self.cooldownDebugHistoryMaxLines or 240) or 240
  if self.cooldownDebugSpellID then
    self:LogCooldownDebug(self.cooldownDebugSpellID, "watch_start")
  end
end

function provider:ClearCooldownDebugSpell()
  local watchedSpellId = tonumber(self.cooldownDebugSpellID or 0) or 0
  if watchedSpellId > 0 then
    local lines = self:BuildCooldownDebugLines(watchedSpellId, "watch_stop")
    self:AppendCooldownDebugHistory(lines)
    if ns.Debug and ns.Debug.Log then
      for _, line in ipairs(lines) do
        ns.Debug:Log("CDWatch", line)
      end
    end
  end
  self.cooldownDebugSpellID = nil
  self.cooldownDebugPendingReasons = {}
  self.cooldownDebugLastEvalSignatures = {}
  self.cooldownDebugLastRenderSignatures = {}
  self.cooldownDebugLastPlayerCast = nil
end

function provider:GetCooldownDebugStatusLine()
  local watchedSpellId = tonumber(self.cooldownDebugSpellID or 0) or 0
  if watchedSpellId <= 0 then
    return "Cooldown debug watch is off."
  end
  return string.format(
    "Cooldown debug watch: %s | historyLines=%d",
    GetCooldownDebugSpellLabel(watchedSpellId),
    #(self.cooldownDebugHistory or {})
  )
end

function provider:GetCooldownDebugSpellLabel()
  local watchedSpellId = tonumber(self.cooldownDebugSpellID or 0) or 0
  if watchedSpellId <= 0 then
    return nil
  end
  return GetCooldownDebugSpellLabel(watchedSpellId)
end

function provider:ShowCooldownDebugHistory()
  local lines = self.cooldownDebugHistory
  if type(lines) ~= "table" or #lines == 0 then
    lines = { "No cooldown debug history captured yet." }
  end

  if ns.Debug and ns.Debug.ShowSnapshot then
    ns.Debug:ShowSnapshot("PopAuras Cooldown Debug", lines, true)
  elseif ns.Debug and ns.Debug.Log then
    ns.Debug:Clear()
    for _, line in ipairs(lines) do
      ns.Debug:Log("CDWatch", line)
    end
  end
end

function provider:CaptureCooldownDebugSnapshot(reason, extra)
  local watchedSpellId = tonumber(self.cooldownDebugSpellID or 0) or 0
  if watchedSpellId <= 0 then
    return false
  end
  self:LogCooldownDebug(watchedSpellId, reason or "manual_snapshot", nil, nil, extra)
  return true
end

function provider:ResolveCooldownDebugSpellID(query)
  query = tostring(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if query == "" then
    return nil
  end

  local numeric = tonumber(query)
  if numeric and numeric > 0 then
    return numeric
  end

  if C_Spell and C_Spell.GetSpellInfo then
    local ok, spellInfo = pcall(C_Spell.GetSpellInfo, query)
    if ok and type(spellInfo) == "table" then
      local spellId = tonumber(spellInfo.spellID or spellInfo.spellId or spellInfo.id or 0) or 0
      if spellId > 0 then
        return spellId
      end
    end
  end

  EnsureSpellAuraIndex(self)
  local lowered = query:lower()
  local partialMatch = nil
  for _, spellId in ipairs(self.watchedSpellIDs or {}) do
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId) or nil
    local normalizedName = type(spellName) == "string" and spellName:lower() or nil
    if normalizedName == lowered then
      return spellId
    end
    if normalizedName and normalizedName:find(lowered, 1, true) then
      if partialMatch and partialMatch ~= spellId then
        return nil, "Multiple configured cooldown spells match that name. Use the numeric spell ID instead."
      end
      partialMatch = spellId
    end
  end

  if partialMatch then
    return partialMatch
  end

  return nil, "No cooldown spell matched that name. Use the numeric spell ID if needed."
end

function provider:GetTrackedCooldownSpellIDs()
  EnsureSpellAuraIndex(self)

  local trackedSpellIDs = {}
  local seenSpellIDs = {}

  for _, spellID in ipairs(self.watchedSpellIDs or {}) do
    spellID = tonumber(spellID or 0) or 0
    if spellID > 0 and not seenSpellIDs[spellID] then
      seenSpellIDs[spellID] = true
      trackedSpellIDs[#trackedSpellIDs + 1] = spellID
    end
  end

  local debugSpellId = tonumber(self.cooldownDebugSpellID or 0) or 0
  if debugSpellId > 0 and not seenSpellIDs[debugSpellId] then
    trackedSpellIDs[#trackedSpellIDs + 1] = debugSpellId
  end

  table.sort(trackedSpellIDs)
  return trackedSpellIDs
end

EnsureSpellAuraIndex = function(self)
  if not ns.Registry or not ns.Registry.GetFlatOrder then
    self.spellAuraIndex = {}
    self.watchedSpellIDs = {}
    self.spellAuraIndexOrder = nil
    return
  end

  local flatOrder = ns.Registry:GetFlatOrder()
  if self.spellAuraIndex and self.watchedSpellIDs and self.spellAuraIndexOrder == flatOrder then
    return
  end

  local spellAuraIndex = {}
  local watchedSpellIDs = {}
  local seenSpellIDs = {}

  for _, aura in ns.Registry:IterateAll() do
    local spellIDsForAura = {}
    for _, trigger in IterateSpellCooldownTriggers(aura) do
      for _, spellID in ipairs(GetSpellIDs(trigger)) do
        if spellID > 0 and not spellIDsForAura[spellID] then
          spellIDsForAura[spellID] = true
          local auraIds = spellAuraIndex[spellID]
          if not auraIds then
            auraIds = {}
            spellAuraIndex[spellID] = auraIds
          end
          auraIds[#auraIds + 1] = aura.id
          if not seenSpellIDs[spellID] then
            seenSpellIDs[spellID] = true
            watchedSpellIDs[#watchedSpellIDs + 1] = spellID
          end
        end
      end
    end
  end

  table.sort(watchedSpellIDs)
  self.spellAuraIndex = spellAuraIndex
  self.watchedSpellIDs = watchedSpellIDs
  self.spellAuraIndexOrder = flatOrder
end

function provider:GetAffectedAurasForSpellIDs(spellIDs)
  EnsureSpellAuraIndex(self)

  local results = {}
  local seenAuraIds = {}
  for _, spellID in ipairs(spellIDs or {}) do
    spellID = tonumber(spellID or 0) or 0
    if spellID > 0 then
      for _, auraId in ipairs(self.spellAuraIndex and self.spellAuraIndex[spellID] or {}) do
        if not seenAuraIds[auraId] then
          seenAuraIds[auraId] = true
          results[#results + 1] = auraId
        end
      end
    end
  end

  return results
end

function provider:GetAffectedAuras(event, ...)
  if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
    return {}
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and spellID then
      return self:GetAffectedAurasForSpellIDs({ spellID })
    end
    return {}
  end

  return true
end

function provider:PruneCache()
  local activeSpellIDs = {}
  for _, spellID in ipairs(self:GetTrackedCooldownSpellIDs()) do
    activeSpellIDs[spellID] = true
  end

  for spellID in pairs(self.cache) do
    if not activeSpellIDs[spellID] then
      self.cache[spellID] = nil
    end
  end

  self.cooldownEventSignatures = self.cooldownEventSignatures or {}
  for spellID in pairs(self.cooldownEventSignatures) do
    if not activeSpellIDs[spellID] then
      self.cooldownEventSignatures[spellID] = nil
    end
  end
end

function provider:GetChangedSpellIDsForCooldownEvent()
  self.cooldownEventSignatures = self.cooldownEventSignatures or {}
  local changedSpellIDs = {}

  for _, spellID in ipairs(self:GetTrackedCooldownSpellIDs()) do
    local cache = self.cache[spellID]
    if ShouldClearExpiredReadyCooldownCache(spellID, cache) then
      ClearReadyCooldownCache(cache)
      self.cooldownEventSignatures[spellID] = BuildCooldownEventSignature(spellID, cache)
      changedSpellIDs[#changedSpellIDs + 1] = spellID
    else
      local signature = BuildCooldownEventSignature(spellID, cache)
      if self.cooldownEventSignatures[spellID] ~= signature then
        self.cooldownEventSignatures[spellID] = signature
        changedSpellIDs[#changedSpellIDs + 1] = spellID
      end
    end
  end

  return changedSpellIDs
end

IsCooldownActive = function(cooldown)
  if type(cooldown) ~= "table" then
    return false
  end
  local isOnGCD = SafeBoolean(cooldown.isOnGCD)
  if isOnGCD == true then
    return false
  end
  local duration = SafeNumber(cooldown.duration)
  local startTime = SafeNumber(cooldown.startTime)
  local enabled = SafeBoolean(cooldown.isEnabled)
  local explicitActive = SafeBoolean(cooldown.isActive)
  if explicitActive ~= nil then
    if explicitActive ~= true then
      return false
    end
    if duration and IsLikelyGCD(duration) then
      return false
    end
    return (duration and duration > 0) or (startTime and enabled == true) or false
  end

  return startTime and duration and enabled == true and duration > 0 and not IsLikelyGCD(duration) or false
end

local function IsChargeCooldownActive(chargeInfo)
  if type(chargeInfo) ~= "table" then
    return false
  end
  local explicitActive = SafeBoolean(chargeInfo.isActive)
  if explicitActive ~= nil then
    return explicitActive
  end

  local currentCharges = SafeNumber(chargeInfo.currentCharges)
  local maxCharges = SafeNumber(chargeInfo.maxCharges)
  local duration = SafeNumber(chargeInfo.cooldownDuration)
  local startTime = SafeNumber(chargeInfo.cooldownStartTime)
  return currentCharges and maxCharges and maxCharges > 1 and currentCharges < maxCharges and startTime and duration and duration > 0 or false
end

local function ShouldShowChargeCount(currentCharges, maxCharges)
  currentCharges = SafeNumber(currentCharges)
  maxCharges = SafeNumber(maxCharges)
  return currentCharges ~= nil and maxCharges ~= nil and maxCharges > 1
end

local function HasMissingCharges(currentCharges, maxCharges)
  currentCharges = SafeNumber(currentCharges)
  maxCharges = SafeNumber(maxCharges)
  return currentCharges ~= nil and maxCharges ~= nil and maxCharges > 1 and currentCharges < maxCharges
end

local function InferReadyChargeCount(cache, maxCharges, isReady, cooldownIsOnGCD)
  maxCharges = SafeNumber(maxCharges)
  if maxCharges == nil or maxCharges <= 1 then
    return nil
  end
  if not isReady or cooldownIsOnGCD == true then
    return nil
  end
  if cache and cache.expirationTime and cache.expirationTime > GetTime() then
    return nil
  end
  return maxCharges
end

ClearReadyCooldownCache = function(cache)
  if type(cache) ~= "table" then
    return
  end

  cache.expirationTime = 0
  cache.active = false
  cache.deferredByActiveAura = nil
  cache.deferredExpirationTime = nil

  local maxCharges = SafeNumber(cache.maxCharges)
  if cache.isChargeSpell == true and maxCharges and maxCharges > 1 then
    cache.currentCharges = maxCharges
  end
end

ShouldClearExpiredReadyCooldownCache = function(spellId, cache)
  cache = type(cache) == "table" and cache or nil
  if not cache or cache.active ~= true then
    return false
  end

  local expirationTime = SafeNumber(cache.expirationTime) or 0
  local now = GetTime()
  if expirationTime <= 0 or expirationTime > now then
    return false
  end

  local cdmState = GetCDMState(spellId)
  if IsUsableCDMCooldownState(cdmState) then
    return false
  end

  local _, cooldown, cooldownDuration, cooldownExpirationTime, cooldownDurationObject, cooldownIsOnGCD =
    SelectBestCooldownQuery(spellId, cache, cdmState)
  if not CooldownLooksReady(
    cooldown,
    cooldownDuration,
    cooldownExpirationTime,
    cooldownDurationObject,
    cooldownIsOnGCD
  ) then
    return false
  end

  if C_Spell and C_Spell.GetSpellCharges then
    local chargeInfo = C_Spell.GetSpellCharges(spellId)
    if IsChargeCooldownActive(chargeInfo) then
      return false
    end
  end

  return true
end

local function AdvanceCachedCharges(cache)
  if type(cache) ~= "table" or cache.isChargeSpell ~= true then
    return
  end

  local maxCharges = SafeNumber(cache.maxCharges)
  local currentCharges = SafeNumber(cache.currentCharges)
  local duration = SafeNumber(cache.duration)
  local expirationTime = SafeNumber(cache.expirationTime)
  if maxCharges == nil or maxCharges <= 1 or currentCharges == nil or duration == nil or duration <= 0 or expirationTime == nil or expirationTime <= 0 then
    return
  end

  local now = GetTime()
  while currentCharges < maxCharges and expirationTime <= now do
    currentCharges = math.min(maxCharges, currentCharges + 1)
    if currentCharges < maxCharges then
      expirationTime = expirationTime + duration
    else
      expirationTime = 0
      cache.active = false
      break
    end
  end

  cache.currentCharges = currentCharges
  cache.expirationTime = expirationTime
end

function provider:HandleEvent(event, ...)
  if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
    local watchedSpellId = tonumber(self.cooldownDebugSpellID or 0) or 0
    local changedSpellIDs = self:GetChangedSpellIDsForCooldownEvent()
    if #changedSpellIDs == 0 then
      if watchedSpellId > 0 then
        self:LogCooldownDebug(
          watchedSpellId,
          "event:" .. tostring(event) .. ":no_change",
          nil,
          nil,
          "changed=false"
        )
      end
      return {}
    end
    local watchedSpellChanged = false
    for _, spellId in ipairs(changedSpellIDs) do
      if watchedSpellId > 0 and spellId == watchedSpellId then
        watchedSpellChanged = true
      end
      if self:IsCooldownDebugSpell(spellId) then
        self:LogCooldownDebug(
          spellId,
          "event:" .. tostring(event),
          nil,
          nil,
          string.format("changed=true affected=%d", #self:GetAffectedAurasForSpellIDs({ spellId }))
        )
        self:QueueCooldownDebugReason(spellId, event)
      end
    end
    if watchedSpellId > 0 and not watchedSpellChanged then
      self:LogCooldownDebug(
        watchedSpellId,
        "event:" .. tostring(event) .. ":no_watch_change",
        nil,
        nil,
        string.format("changed=false changedCount=%d", #changedSpellIDs)
      )
    end
    return self:GetAffectedAurasForSpellIDs(changedSpellIDs)
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellId = ...
    if unit ~= "player" or type(spellId) ~= "number" then
      return {}
    end

    local now = GetTime()
    if self.cooldownDebugSpellID then
      self.cooldownDebugLastPlayerCast = {
        spellId = spellId,
        at = now,
      }
    end

    local affectedAuraIds = self:GetAffectedAurasForSpellIDs({ spellId })
    if self:IsCooldownDebugSpell(spellId) then
      self:LogCooldownDebug(
        spellId,
        "event:UNIT_SPELLCAST_SUCCEEDED",
        nil,
        nil,
        string.format("castSpell=%s affected=%d", tostring(spellId), #affectedAuraIds)
      )
      self:QueueCooldownDebugReason(spellId, "UNIT_SPELLCAST_SUCCEEDED")
    end
    if #affectedAuraIds == 0 then
      return affectedAuraIds
    end

    self.recentCasts = self.recentCasts or {}
    local lastCastAt = self.recentCasts[spellId]
    if lastCastAt and (now - lastCastAt) < 0.15 then
      return affectedAuraIds
    end
    self.recentCasts[spellId] = now

    for _, auraId in ipairs(affectedAuraIds) do
      local aura = ns.Registry:GetAura(auraId)
      for _, trigger in IterateSpellCooldownTriggers(aura) do
        local baseCooldown = nil
        local triggerSpellIDs = GetSpellIDs(trigger)

        for _, linkedSpellID in ipairs(triggerSpellIDs) do
          local cache = self.cache[linkedSpellID]
          local cdmState = GetCDMState(linkedSpellID)

          local _, _, cooldownDuration, cooldownExpirationTime, _, cooldownIsOnGCD =
            SelectBestCooldownQuery(linkedSpellID, cache, cdmState)
          if IsUsableCooldownDuration(cooldownDuration, cooldownExpirationTime, cooldownIsOnGCD) then
            baseCooldown = PreferShorterCooldownDuration(baseCooldown, cooldownDuration)
          end

          if C_Spell and C_Spell.GetSpellCharges then
            local chargeInfo = C_Spell.GetSpellCharges(linkedSpellID)
            local chargeDuration, chargeExpirationTime = GetSpellChargeTiming(linkedSpellID, chargeInfo)
            if IsUsableCooldownDuration(chargeDuration, chargeExpirationTime, false) then
              baseCooldown = PreferShorterCooldownDuration(baseCooldown, chargeDuration)
            end
          end

          if cache and IsUsableCooldownDuration(cache.duration, cache.expirationTime, false) then
            baseCooldown = PreferShorterCooldownDuration(baseCooldown, cache.duration)
          end

          if cdmState and cdmState.active and IsUsableCooldownDuration(cdmState.duration, cdmState.expirationTime, false) then
            baseCooldown = PreferShorterCooldownDuration(baseCooldown, cdmState.duration)
          end

          if (not baseCooldown or baseCooldown <= 0) and cdmState and cdmState.maxDuration and cdmState.maxDuration > 0 then
            baseCooldown = cdmState.maxDuration
          end
        end

        if not baseCooldown or baseCooldown <= 0 then
          for _, linkedSpellID in ipairs(triggerSpellIDs) do
            local configuredCooldown = GetConfiguredCooldown(trigger, linkedSpellID)
            if configuredCooldown and configuredCooldown > 0 and not IsLikelyGCD(configuredCooldown) then
              baseCooldown = configuredCooldown
              break
            end
          end
        end

        if baseCooldown and baseCooldown > 0 and not IsLikelyGCD(baseCooldown) then
          for _, linkedSpellID in ipairs(triggerSpellIDs) do
            self.cache[linkedSpellID] = self.cache[linkedSpellID] or {}
            self.cache[linkedSpellID].duration = baseCooldown
            self.cache[linkedSpellID].expirationTime = now + baseCooldown
            self.cache[linkedSpellID].active = true
            self.cache[linkedSpellID].source = "learned_cast"
            self.cache[linkedSpellID].deferredByActiveAura = nil
            self.cache[linkedSpellID].deferredExpirationTime = nil
            local inferredCharges = self.cache[linkedSpellID].currentCharges
            if inferredCharges == nil and (self.cache[linkedSpellID].isChargeSpell or ((self.cache[linkedSpellID].maxCharges or 0) > 1)) then
              inferredCharges = self.cache[linkedSpellID].maxCharges
            end
            if inferredCharges and inferredCharges > 0 then
              self.cache[linkedSpellID].currentCharges = math.max(0, inferredCharges - 1)
            end
            if self:IsCooldownDebugSpell(linkedSpellID) then
              self:LogCooldownDebug(
                linkedSpellID,
                "event:UNIT_SPELLCAST_SUCCEEDED",
                aura,
                nil,
                string.format("castSpell=%s injectedCooldown=%s", tostring(spellId), QuantizeTime(baseCooldown))
              )
              self:QueueCooldownDebugReason(linkedSpellID, "UNIT_SPELLCAST_SUCCEEDED")
            end
          end
        end
      end
    end
    return affectedAuraIds
  elseif event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
    if self.cooldownDebugSpellID then
      self:LogCooldownDebug(self.cooldownDebugSpellID, "event:" .. tostring(event))
    end
    self.spellAuraIndex = nil
    self.watchedSpellIDs = nil
    self.spellAuraIndexOrder = nil
    self.cooldownEventSignatures = {}
    self:PruneCache()
    if ns.CooldownManager and ns.CooldownManager.Invalidate then
      ns.CooldownManager:Invalidate()
    end
    for spellId, entry in pairs(self.cache) do
      local baseCooldown = GetBaseCooldownSeconds(spellId)
      if baseCooldown and baseCooldown > 0 then
        entry.duration = baseCooldown
      end
    end
    return true
  end
end

function provider:Evaluate(trigger, aura)
  local spellIDs = GetSpellIDs(trigger)
  if #spellIDs == 0 or not C_Spell then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "spell_cooldown" })
  end
  local allowChargeTracking = #spellIDs == 1
  local matchMode = GetCooldownMatchMode(trigger)

  local sharedCache = {}
  local sharedCharges
  local sharedDisplayCharges
  local sharedMaxCharges
  local sharedStackText
  local sharedStackDisplayValue
  local sharedHasStackDisplayValue
  for _, spellId in ipairs(spellIDs) do
    local cache = self.cache[spellId]
    if cache then
      if cache.expirationTime and (not sharedCache.expirationTime or cache.expirationTime > sharedCache.expirationTime) then
        sharedCache.expirationTime = cache.expirationTime
        sharedCache.duration = cache.duration
        sharedCache.source = cache.source
        sharedCache.cooldownID = cache.cooldownID
      end
      if cache.duration and (not sharedCache.duration or cache.duration > sharedCache.duration) then
        sharedCache.duration = cache.duration
      end
      if cache.maxCharges ~= nil and (sharedMaxCharges == nil or cache.maxCharges > sharedMaxCharges) then
        sharedMaxCharges = cache.maxCharges
      end
    end
  end

  local bestState
  local fallbackState
  local fallbackPriority = nil

  for _, spellId in ipairs(spellIDs) do
    local name = C_Spell.GetSpellName(spellId)
    local icon = C_Spell.GetSpellTexture(spellId)
    local chargeInfo = C_Spell.GetSpellCharges(spellId)
    local chargeDuration, chargeExpirationTime, chargeDurationObject = GetSpellChargeTiming(spellId, chargeInfo)
    local cache = self.cache[spellId] or {}
    AdvanceCachedCharges(cache)
    local isReady = true
    local duration = 0
    local expirationTime = 0
    local currentCharges
    local activeDurationObject = nil
    local source = "spell_cooldown"
    local configuredCooldown = GetConfiguredCooldown(trigger, spellId)
    local currentStackDisplayValue = nil
    local hasCurrentStackDisplayValue = false
    local activeAuraOnly = false

    local cdmState = GetCDMState(spellId)
    local cdmStateActive = IsUsableCDMCooldownState(cdmState)
    if cdmState and cdmState.maxDuration and cdmState.maxDuration > 0 then
      cache.duration = PreferShorterCooldownDuration(cache.duration, cdmState.maxDuration)
      cache.cooldownID = cdmState.cooldownID
      cache.source = cache.source or "cdm"
    end

    local cooldownQueryID, cooldown, cooldownDuration, cooldownExpirationTime, cooldownDurationObject, cooldownIsOnGCD =
      SelectBestCooldownQuery(spellId, cache, cdmState)
    local lastCastAt = self.recentCasts and self.recentCasts[spellId] or nil
    local learnedCastGraceElapsed = (not lastCastAt) or ((GetTime() - lastCastAt) > 0.45)

    if cdmStateActive then
      isReady = false
      duration = cdmState.duration or 0
      expirationTime = cdmState.expirationTime or 0
      activeDurationObject = cdmState.durationObject or nil
      if duration and duration > 0 then
        cache.duration = duration
      end
      if expirationTime and expirationTime > 0 then
        cache.expirationTime = expirationTime
      end
      cache.active = true
      cache.cooldownID = cdmState.cooldownID
      cache.source = "cdm"
      cache.deferredByActiveAura = nil
      cache.deferredExpirationTime = nil
      source = "cdm"
    end

    local cdmCountText = cdmState and cdmState.countText or nil
    local cdmCount = cdmState and cdmState.count or nil
    if cdmCountText and cdmCountText ~= "" then
      currentCharges = cdmCount or currentCharges
      sharedStackText = sharedStackText or cdmCountText
      currentStackDisplayValue = cdmCountText
      hasCurrentStackDisplayValue = true
    end
    if currentCharges ~= nil and (sharedCharges == nil or currentCharges > sharedCharges) then
      sharedCharges = currentCharges
    end
    if cdmCount ~= nil and cdmCount > 0 and (sharedDisplayCharges == nil or cdmCount > sharedDisplayCharges) then
      sharedDisplayCharges = cdmCount
    end

    local cdmAuraState = GetCDMAuraState(spellId)
    local cdmAuraDetails = GetCDMAuraDetails(cdmAuraState, spellId)
    local cdmAuraData = cdmAuraState and cdmAuraState.auraData or nil
    local cdmAuraStacks = cdmAuraDetails and cdmAuraDetails.stacks or 0
    local cdmAuraDuration = cdmAuraDetails and cdmAuraDetails.duration or 0
    local cdmAuraExpiration = cdmAuraDetails and cdmAuraDetails.expirationTime or 0
    local cdmAuraActive = cdmAuraDetails and cdmAuraDetails.active or false

    local cdmAuraStackText = cdmAuraDetails and cdmAuraDetails.stackText or nil
    if cdmAuraStacks > 0 then
      currentCharges = cdmAuraStacks
      if sharedCharges == nil or cdmAuraStacks > sharedCharges then
        sharedCharges = cdmAuraStacks
      end
      if sharedDisplayCharges == nil or cdmAuraStacks > sharedDisplayCharges then
        sharedDisplayCharges = cdmAuraStacks
      end
      if not sharedStackText or sharedStackText == "" then
        sharedStackText = cdmAuraStackText or tostring(cdmAuraStacks)
      end
      if cdmAuraDetails and cdmAuraDetails.hasStackDisplayValue == true then
        currentStackDisplayValue = cdmAuraDetails.stackDisplayValue
        hasCurrentStackDisplayValue = true
      end
    end

    local liveDuration = cooldown and SafeNumber(cooldown.duration)
    local cooldownActive = IsCooldownActive(cooldown)
    local cooldownHasUsableWindow = cooldownDuration and cooldownDuration > 0 and cooldownExpirationTime > GetTime()
    local cooldownLooksLikeGCD = IsLikelyGCD(cooldownDuration)
      or IsLikelyGCD(liveDuration)

    -- Some direct spell cooldown queries still expose the active GCD as a short
    -- duration object. Filter that from the primary query, but do not classify a
    -- legitimate cooldown as GCD just because its remaining time is now short.
    if cooldownLooksLikeGCD or cooldownIsOnGCD == true then
      cooldownDuration = 0
      cooldownExpirationTime = 0
      cooldownDurationObject = nil
      cooldownActive = false
    end

    local cooldownDurationObjectRemaining = GetDurationObjectRemaining(cooldownDurationObject)
    local cooldownApiActive = SafeBoolean(cooldown and cooldown.isActive) == true
    local usedCachedTimingForApiDuration = false
    local renderableCooldownDurationObject = cooldownDurationObject ~= nil
      and cooldownDurationObjectRemaining ~= nil
      and cooldownDurationObjectRemaining > 0
    local hasCooldownDurationObject = cooldownDurationObject ~= nil
      and cooldownIsOnGCD ~= true
      and cooldownLooksLikeGCD ~= true
      and (
        (cooldownDurationObjectRemaining ~= nil and cooldownDurationObjectRemaining > 0)
        or cooldownApiActive
        or cooldownActive
      )
    if isReady and (hasCooldownDurationObject or (cooldownActive and cooldownHasUsableWindow)) then
      isReady = false
      activeDurationObject = renderableCooldownDurationObject and cooldownDurationObject or nil

      if cooldownHasUsableWindow then
        duration = cooldownDuration
        expirationTime = cooldownExpirationTime
        cache.duration = cooldownDuration
        cache.expirationTime = cooldownExpirationTime
      elseif hasCooldownDurationObject then
        local cachedExpirationTime = cache.expirationTime or sharedCache.expirationTime
        local cachedDuration = cache.duration or sharedCache.duration or configuredCooldown
        if cachedExpirationTime and cachedExpirationTime > GetTime() and cachedDuration and cachedDuration > 0 then
          duration = cachedDuration
          expirationTime = cachedExpirationTime
          usedCachedTimingForApiDuration = true
        else
          duration = 0
          expirationTime = 0
        end
      end

      cache.active = true
      cache.source = hasCooldownDurationObject and "api_duration" or "api"
      cache.deferredByActiveAura = nil
      cache.deferredExpirationTime = nil
      source = cache.source
    end

    if allowChargeTracking and chargeInfo then
      cache.isChargeSpell = true
    end

    if allowChargeTracking and (chargeInfo or cache.isChargeSpell) then
      local rawCurrentCharges = nil
      if chargeInfo then
        rawCurrentCharges = chargeInfo.currentCharges
      end
      local safeCurrentCharges = SafeNumber(chargeInfo and chargeInfo.currentCharges)
      local safeMaxCharges = SafeNumber(chargeInfo and chargeInfo.maxCharges) or cache.maxCharges
      local safeChargeDuration = chargeDuration or 0
      local safeChargeExpiration = chargeExpirationTime or 0
      local hasRealCharges = safeMaxCharges and safeMaxCharges > 1
      if safeCurrentCharges == nil and ShouldShowChargeCount(cache.currentCharges, safeMaxCharges) then
        safeCurrentCharges = cache.currentCharges
      end
      if safeCurrentCharges == nil then
        safeCurrentCharges = InferReadyChargeCount(cache, safeMaxCharges, isReady, cooldownIsOnGCD)
      end
      local shouldShowCharges = ShouldShowChargeCount(safeCurrentCharges, safeMaxCharges)
      local missingCharges = HasMissingCharges(safeCurrentCharges, safeMaxCharges)
      local noChargesAvailable = missingCharges and safeCurrentCharges == 0
      if hasRealCharges then
        if shouldShowCharges then
          local chargeDisplayValue, hasChargeDisplayValue = BuildStackDisplayValue(rawCurrentCharges, tostring(safeCurrentCharges), safeCurrentCharges, true)
          currentCharges = safeCurrentCharges
          cache.currentCharges = safeCurrentCharges
          if sharedCharges == nil or safeCurrentCharges > sharedCharges then
            sharedCharges = safeCurrentCharges
          end
          if sharedDisplayCharges == nil or safeCurrentCharges > sharedDisplayCharges then
            sharedDisplayCharges = safeCurrentCharges
          end
          if not sharedStackText or sharedStackText == "" then
            sharedStackText = tostring(safeCurrentCharges)
          end
          currentStackDisplayValue = chargeDisplayValue
          hasCurrentStackDisplayValue = hasChargeDisplayValue
        else
          currentCharges = cache.currentCharges
        end
        cache.maxCharges = safeMaxCharges
        if sharedMaxCharges == nil or safeMaxCharges > sharedMaxCharges then
          sharedMaxCharges = safeMaxCharges
        end
        if safeChargeDuration and safeChargeDuration > 0 then
          cache.duration = safeChargeDuration
        end
        if missingCharges and safeChargeExpiration and safeChargeExpiration > 0 then
          cache.expirationTime = safeChargeExpiration
        end
      else
        cache.currentCharges = nil
        cache.maxCharges = safeMaxCharges
        cache.isChargeSpell = false
      end
      local chargeCooldownActive = chargeInfo and IsChargeCooldownActive(chargeInfo) or false
      local chargeApiActive = SafeBoolean(chargeInfo and chargeInfo.isActive) == true
      local hasChargeDurationObject = chargeDurationObject ~= nil and (
        (safeChargeExpiration or 0) > GetTime()
        or (safeChargeDuration or 0) > 0
        or chargeApiActive
        or chargeCooldownActive
      )
      local shouldShowChargeCooldown = hasRealCharges and missingCharges and (trigger.showChargeCooldown ~= false or noChargesAvailable)
      if shouldShowChargeCooldown and isReady and (
        hasChargeDurationObject
        or (chargeCooldownActive and safeChargeDuration and safeChargeDuration > 0)
        or (cache.expirationTime and cache.expirationTime > GetTime() and (cache.duration or 0) > 0)
      ) then
        isReady = false
        activeDurationObject = chargeDurationObject or activeDurationObject
        if safeChargeDuration and safeChargeDuration > 0 and safeChargeExpiration and safeChargeExpiration > GetTime() then
          duration = safeChargeDuration
          expirationTime = safeChargeExpiration
          cache.duration = safeChargeDuration
          cache.expirationTime = expirationTime
        else
          duration = cache.duration or 0
          expirationTime = cache.expirationTime or 0
        end
        cache.active = true
        cache.source = "charges"
        cache.deferredByActiveAura = nil
        cache.deferredExpirationTime = nil
        source = "charges"
      end
    end

    activeAuraOnly = cdmAuraActive
      and not cdmStateActive
      and not hasCooldownDurationObject
      and not cooldownActive
      and activeDurationObject == nil

    if activeAuraOnly then
      if IsLearnedCastSource(cache.source) and (cache.expirationTime or 0) > GetTime() and (cache.duration or 0) > 0 then
        cache.deferredByActiveAura = true
        cache.deferredExpirationTime = cache.expirationTime
        cache.expirationTime = 0
        cache.active = false
      end
      isReady = false
      duration = 0
      expirationTime = 0
      activeDurationObject = nil
      source = "cdm_aura"
      cache.source = "cdm_aura"
      cache.active = false
    elseif cache.deferredByActiveAura == true and isReady and (cache.duration or 0) > 0 then
      local deferredExpirationTime = SafeNumber(cache.deferredExpirationTime)
      if deferredExpirationTime and deferredExpirationTime > GetTime() then
        cache.expirationTime = deferredExpirationTime
        cache.active = true
        cache.source = "learned_cast_deferred"
      else
        cache.expirationTime = 0
        cache.active = false
      end
      cache.deferredByActiveAura = nil
      cache.deferredExpirationTime = nil
    end

    local cooldownReadyNow = CooldownLooksReady(
      cooldown,
      cooldownDuration,
      cooldownExpirationTime,
      cooldownDurationObject,
      cooldownIsOnGCD
    )
    local hasMissingChargeState = HasMissingCharges(cache.currentCharges, cache.maxCharges)
      or HasMissingCharges(currentCharges, cache.maxCharges)
      or HasMissingCharges(currentCharges, sharedMaxCharges)
    local suppressStaleCachedCooldown = learnedCastGraceElapsed
      and cooldownReadyNow
      and not activeAuraOnly
      and not cdmStateActive
      and not hasMissingChargeState
    if isReady
      and suppressStaleCachedCooldown
      and IsLearnedCastSource(cache.source) then
      cache.expirationTime = 0
      cache.active = false
      cache.deferredByActiveAura = nil
      cache.deferredExpirationTime = nil
      if cache.isChargeSpell == true and SafeNumber(cache.maxCharges) and cache.maxCharges > 1 then
        cache.currentCharges = cache.maxCharges
      end
    end

    if currentCharges == nil and ShouldShowChargeCount(cache.currentCharges, cache.maxCharges) then
      currentCharges = cache.currentCharges
    end
    if currentCharges ~= nil and ShouldShowChargeCount(currentCharges, cache.maxCharges or sharedMaxCharges) then
      if sharedCharges == nil or currentCharges > sharedCharges then
        sharedCharges = currentCharges
      end
      if sharedDisplayCharges == nil or currentCharges > sharedDisplayCharges then
        sharedDisplayCharges = currentCharges
      end
      if not sharedStackText or sharedStackText == "" then
        sharedStackText = tostring(currentCharges)
      end
    end

    local cacheExpirationTime = cache.expirationTime or sharedCache.expirationTime
    local cacheDuration = cache.duration or sharedCache.duration
    if suppressStaleCachedCooldown and cacheExpirationTime and cacheExpirationTime > GetTime() then
      cache.expirationTime = 0
      cache.active = false
      cache.deferredByActiveAura = nil
      cache.deferredExpirationTime = nil
      cacheExpirationTime = 0
    end
    local hasSingleChargeStyleCooldown = allowChargeTracking
      and type(chargeInfo) == "table"
      and (SafeNumber(chargeInfo.maxCharges) or 0) == 1

    if isReady
      and not activeAuraOnly
      and not cdmStateActive
      and hasSingleChargeStyleCooldown
      and HasRecoverableCDMObjectSignal(cdmState)
      and lastCastAt
    then
      local fallbackDuration = GetRecentCastFallbackCooldownDuration(spellId, cache, sharedCache, configuredCooldown, cdmState)
      local fallbackExpirationTime = fallbackDuration > 0 and (lastCastAt + fallbackDuration) or 0
      if fallbackExpirationTime > (GetTime() + 0.15) then
        isReady = false
        duration = fallbackDuration
        expirationTime = fallbackExpirationTime
        activeDurationObject = nil
        cache.duration = fallbackDuration
        cache.expirationTime = fallbackExpirationTime
        cache.active = true
        cache.cooldownID = cdmState.cooldownID or cache.cooldownID
        cache.source = "cdm_recent_cast"
        cache.deferredByActiveAura = nil
        cache.deferredExpirationTime = nil
        source = "cdm_recent_cast"
        cacheExpirationTime = fallbackExpirationTime
        cacheDuration = fallbackDuration
      end
    end
    if isReady and not activeAuraOnly and cacheExpirationTime and cacheExpirationTime > GetTime() then
      isReady = false
      duration = cacheDuration or GetConfiguredCooldown(trigger, spellId)
      expirationTime = cacheExpirationTime
      if activeDurationObject == nil and (cache.source == "api_duration" or sharedCache.source == "api_duration") and HasRecoverableCDMObjectSignal(cdmState) then
        activeDurationObject = cdmState.durationObject
      end
      source = cache.source or sharedCache.source or "learned_cast"
    end

    if not isReady and activeDurationObject == nil and expirationTime <= GetTime() then
      isReady = true
      duration = 0
      expirationTime = 0
      cache.active = false
    end

    if not isReady
      and activeDurationObject == nil
      and source == "api_duration"
      and type(cdmState) == "table"
      and cdmState.durationObject ~= nil
      and cdmState.isOnGCD ~= true
    then
      activeDurationObject = cdmState.durationObject
    end

    if not cache.duration or cache.duration <= 0 then
      local baseCooldown = configuredCooldown
      if baseCooldown and baseCooldown > 0 then
        cache.duration = baseCooldown
      end
    end

    self.cache[spellId] = cache

    local candidateDisplayCharges = cdmCount
      or cdmAuraStacks
      or currentCharges
    local candidateStackText = cdmCountText
      or cdmAuraStackText
      or (candidateDisplayCharges ~= nil and candidateDisplayCharges > 0 and tostring(candidateDisplayCharges) or nil)
    local candidateStackDisplayValue = currentStackDisplayValue
    local candidateHasStackDisplayValue = hasCurrentStackDisplayValue
    local candidateProgressType = (activeDurationObject ~= nil or duration > 0 or expirationTime > GetTime()) and "timed" or "static"
    local candidateValue = duration
    local candidateTotal = duration
    if activeAuraOnly then
      candidateProgressType = "static"
      candidateValue = 1
      candidateTotal = 1
    end

    local matched = (matchMode == "ready") == isReady
    local candidate = ns.Schema.NormalizeRuntimeState({
      show = ShouldPersistDisplay(trigger, aura) or matched,
      matched = matched,
      active = not isReady,
      icon = (cdmAuraDetails and cdmAuraDetails.icon) or icon,
      name = (cdmAuraDetails and cdmAuraDetails.name) or name,
      stacks = candidateDisplayCharges or 0,
      stackText = candidateStackText,
      stackDisplayValue = candidateStackDisplayValue,
      hasStackDisplayValue = candidateHasStackDisplayValue,
      duration = duration,
      expirationTime = expirationTime,
      durationObject = activeDurationObject or nil,
      progressType = candidateProgressType,
      value = candidateValue,
      total = candidateTotal,
      isReady = isReady,
      isUsable = true,
      auraInstanceID = cdmAuraDetails and cdmAuraDetails.auraInstanceID or nil,
      unit = (cdmAuraDetails and cdmAuraDetails.unit) or nil,
      spellId = spellId,
      source = source,
      statusText = isReady and "Ready" or ((source == "cdm_aura" and "Active") or "Cooldown"),
      debugExtra = BuildDebugBits({
        string.format("spellIDs=%s", table.concat(spellIDs, ",")),
        string.format("cdmID=%s", tostring(cdmState and cdmState.cooldownID or cache.cooldownID or "")),
        string.format("cooldownQueryID=%s", tostring(cooldownQueryID or "")),
        string.format("cdmActive=%s", tostring(cdmStateActive == true)),
        string.format("cdmActiveRaw=%s", tostring(cdmState and (cdmState.rawActive == true or cdmState.active == true) or false)),
        string.format("cdmActual=%s", tostring(cdmState and cdmState.isOnActualCooldown == true or false)),
        string.format("cdmGCD=%s", tostring(cdmState and cdmState.isOnGCD == true or false)),
        string.format("cdmDur=%s", tostring(cdmState and cdmState.duration or "")),
        string.format("cdmObj=%s", tostring(cdmState and cdmState.durationObject ~= nil or false)),
        string.format("cdmCount=%s", tostring(cdmCount ~= nil and cdmCount or "")),
        string.format("cdmText=%s", tostring(cdmCountText or "")),
        string.format("cdmAura=%s", tostring(cdmAuraActive)),
        string.format("cdmAuraSpell=%s", tostring(cdmAuraDetails and cdmAuraDetails.spellId or "")),
        string.format("cdmAuraMatch=%s", tostring(cdmAuraDetails and cdmAuraDetails.spellMatches ~= false or false)),
        string.format("isOnGCD=%s", tostring(cooldownIsOnGCD == true)),
        string.format("gcdLike=%s", tostring(cooldownLooksLikeGCD == true)),
        string.format("cooldownReady=%s", tostring(cooldownReadyNow == true)),
        string.format("learnedGrace=%s", tostring(learnedCastGraceElapsed ~= true)),
        string.format("staleCacheSuppressed=%s", tostring(suppressStaleCachedCooldown == true)),
        string.format("durObj=%s", tostring(hasCooldownDurationObject)),
        string.format("apiFallbackCache=%s", tostring(usedCachedTimingForApiDuration == true)),
        string.format("chargeObj=%s", tostring(chargeDurationObject ~= nil)),
        string.format("chargeCount=%s", tostring(currentCharges ~= nil and currentCharges or "")),
        string.format("chargeMax=%s", tostring(cache.maxCharges ~= nil and cache.maxCharges or "")),
        string.format("chargeDisplay=%s", tostring(candidateDisplayCharges ~= nil and candidateDisplayCharges or "")),
        string.format("activeAuraOnly=%s", tostring(activeAuraOnly == true)),
        string.format("apiActive=%s", tostring(cooldownActive)),
        string.format("matchMode=%s", tostring(matchMode)),
        string.format("matched=%s", tostring(matched)),
      }),
    })
    local cooldownEnabled = cooldown and SafeBoolean(cooldown.isEnabled)
    candidate.isEnabled = cooldownEnabled ~= false

    if candidate.active then
      if not bestState or (candidate.expirationTime or 0) > (bestState.expirationTime or 0) then
        bestState = candidate
      end
    else
      local candidatePriority = 0
      if (candidate.stackText and candidate.stackText ~= "") or (candidate.stacks or 0) > 0 then
        candidatePriority = candidatePriority + 2
      end
      if candidate.source == "cdm" or candidate.source == "cdm_aura" then
        candidatePriority = candidatePriority + 1
      end
      if not fallbackState or candidatePriority > (fallbackPriority or -1) then
        fallbackState = candidate
        fallbackPriority = candidatePriority
      end
    end

    if candidateDisplayCharges ~= nil and (sharedDisplayCharges == nil or candidateDisplayCharges >= sharedDisplayCharges) then
      if candidateHasStackDisplayValue == true then
        sharedStackDisplayValue = candidateStackDisplayValue
        sharedHasStackDisplayValue = true
      elseif candidateStackText and candidateStackText ~= "" then
        sharedStackDisplayValue = candidateStackText
        sharedHasStackDisplayValue = true
      end
    end
  end

  local finalState = bestState or fallbackState or ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "spell_cooldown" })
  if sharedDisplayCharges ~= nil then
    finalState.stacks = sharedDisplayCharges
  end
  if sharedStackText and sharedStackText ~= "" then
    finalState.stackText = sharedStackText
  elseif sharedDisplayCharges ~= nil and sharedDisplayCharges > 0 and (not finalState.stackText or finalState.stackText == "") then
    finalState.stackText = tostring(sharedDisplayCharges)
  end
  if sharedHasStackDisplayValue == true then
    finalState.stackDisplayValue = sharedStackDisplayValue
    finalState.hasStackDisplayValue = true
  end

  for _, spellId in ipairs(spellIDs) do
    self.cache[spellId] = self.cache[spellId] or {}
    if sharedCharges ~= nil and ShouldShowChargeCount(sharedCharges, sharedMaxCharges) then
      self.cache[spellId].currentCharges = sharedCharges
    elseif not self.cache[spellId].isChargeSpell then
      self.cache[spellId].currentCharges = nil
    end
    if sharedMaxCharges ~= nil then
      self.cache[spellId].maxCharges = sharedMaxCharges
    end
    if sharedCache.duration and (not self.cache[spellId].duration or self.cache[spellId].duration <= 0) then
      self.cache[spellId].duration = sharedCache.duration
    end
  end

  local watchedSpellId = nil
  for _, spellId in ipairs(spellIDs) do
    if self:IsCooldownDebugSpell(spellId) then
      watchedSpellId = spellId
      break
    end
  end

  if watchedSpellId then
    self.cooldownDebugLastEvalSignatures = self.cooldownDebugLastEvalSignatures or {}
    local stateKey = tostring(aura and aura.id or watchedSpellId)
    local evalSignature = table.concat({
      tostring(finalState.show),
      tostring(finalState.matched),
      tostring(finalState.active),
      tostring(finalState.isReady),
      tostring(finalState.source or ""),
      QuantizeTime(finalState.duration),
      QuantizeTime(finalState.expirationTime),
      tostring(finalState.stacks or ""),
      tostring(finalState.stackText or ""),
      tostring(finalState.statusText or ""),
      tostring(finalState.debugExtra or ""),
    }, "|")
    local pendingReason = self:GetCooldownDebugReason(watchedSpellId)
    if pendingReason or self.cooldownDebugLastEvalSignatures[stateKey] ~= evalSignature then
      self.cooldownDebugLastEvalSignatures[stateKey] = evalSignature
      self:LogCooldownDebug(
        watchedSpellId,
        pendingReason and ("eval:" .. tostring(pendingReason)) or "eval:state_changed",
        aura,
        finalState,
        string.format("triggerSpellIDs=%s", table.concat(spellIDs, ","))
      )
      if pendingReason and self.cooldownDebugPendingReasons then
        self.cooldownDebugPendingReasons[watchedSpellId] = nil
      end
    end
  end

  return finalState
end
