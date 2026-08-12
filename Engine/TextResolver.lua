local _, ns = ...

local TextResolver = {}
ns.TextResolver = TextResolver

local DURATION_REMAINING_CACHE_INTERVAL = 0.05
local READY_TIMER_SOURCES = {
  item_cooldown = true,
  trinket_cooldown = true,
  spell_cooldown = true,
  api = true,
  api_duration = true,
  cdm = true,
  cdm_aura = true,
  charges = true,
  learned_cast = true,
  learned_cast_deferred = true,
}

local function GetDurationClockTime()
  if C_DurationUtil and C_DurationUtil.GetCurrentTime then
    return C_DurationUtil.GetCurrentTime()
  end
  return GetTime()
end

local function GetDurationCacheStamp(now)
  return math.floor((tonumber(now) or 0) / DURATION_REMAINING_CACHE_INTERVAL)
end

local function FormatTime(seconds, decimals, useExtendedUnits)
  seconds = math.max(0, tonumber(seconds) or 0)
  decimals = math.max(0, math.min(2, tonumber(decimals) or 1))
  if useExtendedUnits then
    if seconds >= 86400 then
      local days = math.floor(seconds / 86400)
      local hours = math.floor((seconds % 86400) / 3600)
      return string.format("%dd %dh", days, hours)
    end
    if seconds >= 3600 then
      local hours = math.floor(seconds / 3600)
      local minutes = math.floor((seconds % 3600) / 60)
      return string.format("%dh %dm", hours, minutes)
    end
  end
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

local function ShouldHideReadyTimerByDefault(state)
  local source = tostring(state and state.source or "")
  return READY_TIMER_SOURCES[source] == true
end

function TextResolver:GetDurationObjectRemaining(state, now)
  state = state or {}
  local queryTime = now or GetDurationClockTime()
  local cacheStamp = GetDurationCacheStamp(queryTime)
  if state._durationRemainingCacheStamp == cacheStamp then
    return state._durationRemainingCacheValue
  end

  local inspected = ns.Duration:Inspect(state.durationObject, queryTime)
  local remainingValue = inspected.remaining

  state._durationRemainingCacheStamp = cacheStamp
  state._durationRemainingCacheValue = remainingValue
  return remainingValue
end

function TextResolver:GetTimerText(state, aura, remainingFromObject)
  state = state or {}
  aura = aura or {}
  local display = aura.display or {}
  local useExtendedAuraListUnits = aura.kind == "aura_bar_list"
  if remainingFromObject == nil then
    remainingFromObject = self:GetDurationObjectRemaining(state)
  end
  local readyState = self:IsReadyState(state, remainingFromObject)

  -- An explicit request to hide ready text must win over the ready appearance.
  -- Cooldown trackers still need readyLook to remain visible while ready.
  if readyState and display.hideReadyTimer then
    return ""
  end

  if display.readyLook and readyState then
    return display.readyText or "Ready"
  end

  if readyState and ShouldHideReadyTimerByDefault(state) then
    return ""
  end

  if useExtendedAuraListUnits and state.hasExpiration == false then
    return ""
  end

  if remainingFromObject ~= nil then
    return FormatTime(remainingFromObject, display.timerDecimals, useExtendedAuraListUnits)
  end

  if (state.source == "aura" or state.source == "cdm_aura" or state.source == "cdm_aura_window") and state.progressType ~= "timed" and (tonumber(state.duration or 0) or 0) <= 0 then
    return ""
  end

  if state.durationObject and (tonumber(state.duration or 0) or 0) <= 0 and (tonumber(state.expirationTime or 0) or 0) <= 0 then
    return ""
  end

  local progress = state.progressType == "timed" and ((state.expirationTime or 0) - GetTime()) or state.value or state.duration or 0
  return FormatTime(progress, display.timerDecimals, useExtendedAuraListUnits)
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
