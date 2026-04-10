local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("timer", {
  events = {
    "PLAYER_ENTERING_WORLD",
  },
  timers = {},
})

function provider:GetAffectedAurasForTimer(timerId)
  return ns.Registry:CollectAuraIds(function(aura)
    return ns.TriggerBase:AnyTriggerMatches(aura, "timer", function(trigger)
      return trigger.timerId == timerId
    end)
  end)
end

function provider:StartTimer(timerId, duration, label, icon)
  self.timers[timerId] = {
    startedAt = GetTime(),
    duration = duration,
    expirationTime = GetTime() + duration,
    label = label or "Timer",
    icon = icon,
  }
  ns.runtime:RefreshAuras(self:GetAffectedAurasForTimer(timerId))
end

function provider:StopTimer(timerId)
  self.timers[timerId] = nil
  ns.runtime:RefreshAuras(self:GetAffectedAurasForTimer(timerId))
end

function provider:Evaluate(trigger)
  local timer = self.timers[trigger.timerId]
  if not timer then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "timer" })
  end

  local remaining = math.max(0, timer.expirationTime - GetTime())
  if remaining <= 0 then
    self.timers[trigger.timerId] = nil
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "timer" })
  end

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    active = true,
    icon = timer.icon,
    name = timer.label,
    duration = timer.duration,
    expirationTime = timer.expirationTime,
    progressType = "timed",
    value = remaining,
    total = timer.duration,
    source = "timer",
    statusText = "Timer",
  })
end
