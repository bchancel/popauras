local _, ns = ...

local ConditionEngine = {}
ns.ConditionEngine = ConditionEngine

function ConditionEngine:Apply(aura, state)
  state = ns.Schema.NormalizeRuntimeState(state)

  for _, condition in ipairs(aura.conditions or {}) do
    local threshold = condition.value or 0
    local current = state.duration
    local hasNumericTimer = (tonumber(state.duration or 0) or 0) > 0 or (tonumber(state.expirationTime or 0) or 0) > 0
    if state.progressType == "timed" and state.expirationTime and state.expirationTime > 0 then
      current = math.max(0, state.expirationTime - GetTime())
    elseif state.durationObject and ns.TextResolver and ns.TextResolver.GetDurationObjectRemaining then
      current = ns.TextResolver:GetDurationObjectRemaining(state)
    elseif state.durationObject and not hasNumericTimer then
      current = nil
    end

    local passes = false
    if condition.type == "threshold" then
      local op = condition.operator or "<="
      if current == nil then
        passes = false
      elseif op == "<=" then
        passes = current <= threshold
      elseif op == "<" then
        passes = current < threshold
      elseif op == ">=" then
        passes = current >= threshold
      elseif op == ">" then
        passes = current > threshold
      end
    end

    if passes then
      if condition.action == "color" and condition.color then
        state.color = condition.color
      elseif condition.action == "hide" then
        state.show = false
      elseif condition.action == "show" then
        state.show = true
      elseif condition.action == "glow" then
        state.glow = true
      elseif condition.action == "desaturate" then
        state.desaturate = true
      end
    end
  end

  return state
end
