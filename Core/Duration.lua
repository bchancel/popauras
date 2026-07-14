local _, ns = ...

local Safe = ns.SafeValues
local Duration = {}
ns.Duration = Duration

function Duration:Inspect(durationObject, now)
  local result = {
    object = durationObject,
    duration = nil,
    expirationTime = nil,
    remaining = nil,
    opaque = false,
    zero = false,
  }
  if durationObject == nil then
    return result
  end

  now = Safe:Number(now) or GetTime()
  result.opaque = Safe:DurationHasSecrets(durationObject)
  result.duration = Safe:DurationNumber(durationObject, "GetTotalDuration")
  result.expirationTime = Safe:DurationNumber(durationObject, "GetEndTime")
  result.remaining = Safe:DurationNumber(durationObject, "GetRemainingDuration")

  local okZero, isZero = Safe:CallMethod(durationObject, "IsZero")
  result.zero = okZero and Safe:Boolean(isZero) == true

  if result.remaining == nil and result.expirationTime ~= nil then
    result.remaining = math.max(0, result.expirationTime - now)
  end
  if result.expirationTime == nil and result.remaining ~= nil and result.remaining > 0 then
    result.expirationTime = now + result.remaining
  end
  if result.duration == nil and result.remaining ~= nil and result.remaining > 0 then
    result.duration = result.remaining
  end
  return result
end
function Duration:CreateFromStart(startTime, duration)
  startTime = Safe:Number(startTime)
  duration = Safe:Number(duration)
  if not startTime or not duration or duration <= 0 or not C_DurationUtil or not C_DurationUtil.CreateDuration then
    return nil
  end
  local object = C_DurationUtil.CreateDuration()
  if object and object.SetTimeFromStart then
    local ok = pcall(object.SetTimeFromStart, object, startTime, duration)
    if ok then
      return object
    end
  end
  return nil
end

function Duration:CreateFromEnd(expirationTime, duration)
  expirationTime = Safe:Number(expirationTime)
  duration = Safe:Number(duration)
  if not expirationTime or not duration or duration <= 0 or not C_DurationUtil or not C_DurationUtil.CreateDuration then
    return nil
  end
  local object = C_DurationUtil.CreateDuration()
  if object and object.SetTimeFromEnd then
    local ok = pcall(object.SetTimeFromEnd, object, expirationTime, duration)
    if ok then
      return object
    end
  end
  return nil
end

function Duration:BuildTimer(durationObject, source, active)
  local inspected = self:Inspect(durationObject)
  return {
    active = active == true,
    object = durationObject,
    duration = inspected.duration,
    expirationTime = inspected.expirationTime,
    remaining = inspected.remaining,
    opaque = inspected.opaque,
    zero = inspected.zero,
    source = source,
  }
end
