local _, ns = ...

local TextResolver = {}
ns.TextResolver = TextResolver

local REAL_TIME_MODIFIER = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime or nil
local DURATION_REMAINING_CACHE_INTERVAL = 0.05

local function SafeDurationNumber(value)
  if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
    return value
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

  local ok, result
  if REAL_TIME_MODIFIER ~= nil then
    ok, result = pcall(method, durationObject, REAL_TIME_MODIFIER)
  else
    ok, result = pcall(method, durationObject)
  end

  if not ok then
    return nil
  end

  return SafeDurationNumber(result)
end

local function GetDurationClockTime()
  if C_DurationUtil and C_DurationUtil.GetCurrentTime then
    return C_DurationUtil.GetCurrentTime()
  end
  return GetTime()
end

local function GetDurationCacheStamp(now)
  return math.floor((tonumber(now) or 0) / DURATION_REMAINING_CACHE_INTERVAL)
end

local function FormatTime(seconds, decimals)
  seconds = math.max(0, tonumber(seconds) or 0)
  decimals = math.max(0, math.min(2, tonumber(decimals) or 1))
  local pattern = "%." .. tostring(decimals) .. "f"
  if seconds >= 60 then
    return string.format(pattern .. "m", seconds / 60)
  end
  return string.format(pattern, seconds)
end

function TextResolver:IsReadyState(state, remainingFromObject)
  state = state or {}
  if remainingFromObject == nil then
    remainingFromObject = self:GetDurationObjectRemaining(state)
  end
  local hasRunningTimer = (remainingFromObject ~= nil and remainingFromObject > 0)
    or (state.progressType == "timed" and (state.expirationTime or 0) > GetTime())
  return state.isReady == true and state.active ~= true and not hasRunningTimer
end

function TextResolver:GetDurationObjectRemaining(state, now)
  state = state or {}
  local queryTime = now or GetDurationClockTime()
  local cacheStamp = GetDurationCacheStamp(queryTime)
  if state._durationRemainingCacheStamp == cacheStamp then
    return state._durationRemainingCacheValue
  end

  local remainingValue = nil
  local hasNumericTiming = (tonumber(state.expirationTime or 0) or 0) > 0 or (tonumber(state.duration or 0) or 0) > 0
  local preferDurationObjectOverAuraAPI = state.source == "cdm_aura" and state.durationObject ~= nil
  local displayOnlyDurationObject = (state.source == "cdm" or state.source == "cdm_aura") and state.durationObject ~= nil and not hasNumericTiming
  if not preferDurationObjectOverAuraAPI
    and C_UnitAuras and C_UnitAuras.GetAuraDurationRemaining
    and state.unit and state.auraInstanceID and (state.durationObject ~= nil or not hasNumericTiming) then
    local ok, remaining = pcall(C_UnitAuras.GetAuraDurationRemaining, state.unit, state.auraInstanceID)
    if ok and SafeDurationNumber(remaining) ~= nil then
      remainingValue = math.max(0, remaining)
    end
  end

  local durationObject = state.durationObject
  if remainingValue == nil and durationObject and not displayOnlyDurationObject then
    local remaining = CallDurationObjectMethod(durationObject, "GetRemainingDuration")
    if remaining ~= nil then
      remainingValue = math.max(0, remaining)
    else
      local endTime = CallDurationObjectMethod(durationObject, "GetEndTime")
      if endTime ~= nil then
        remainingValue = math.max(0, endTime - queryTime)
      end
    end
  end

  state._durationRemainingCacheStamp = cacheStamp
  state._durationRemainingCacheValue = remainingValue
  return remainingValue
end

function TextResolver:GetTimerText(state, aura, remainingFromObject)
  state = state or {}
  aura = aura or {}
  local display = aura.display or {}
  if remainingFromObject == nil then
    remainingFromObject = self:GetDurationObjectRemaining(state)
  end

  if display.readyLook and self:IsReadyState(state, remainingFromObject) then
    return display.readyText or "Ready"
  end

  if display.hideReadyTimer and self:IsReadyState(state, remainingFromObject) then
    return ""
  end

  if remainingFromObject ~= nil then
    return FormatTime(remainingFromObject, display.timerDecimals)
  end

  if (state.source == "aura" or state.source == "cdm_aura") and state.progressType ~= "timed" and (tonumber(state.duration or 0) or 0) <= 0 then
    return ""
  end

  if state.durationObject and (tonumber(state.duration or 0) or 0) <= 0 and (tonumber(state.expirationTime or 0) or 0) <= 0 then
    return ""
  end

  local progress = state.progressType == "timed" and ((state.expirationTime or 0) - GetTime()) or state.value or state.duration or 0
  return FormatTime(progress, display.timerDecimals)
end

function TextResolver:Resolve(template, state, aura)
  template = template or ""
  state = state or {}
  aura = aura or {}
  local text = aura.text or {}
  if aura.kind == "text" and type(text.nameOverride) == "string" and text.nameOverride ~= "" then
    template = text.nameOverride
  end
  local resolvedName = text.nameOverride
  if aura.kind == "text" then
    resolvedName = state.name or ""
  end
  if type(resolvedName) ~= "string" or resolvedName == "" then
    resolvedName = state.name or ""
  end
  template = template:gsub("%%n", resolvedName)
  template = template:gsub("%%s", state.statusText or "")
  template = template:gsub("%%m", state.message or "")
  template = template:gsub("%%p", self:GetTimerText(state, aura))
  return template
end
