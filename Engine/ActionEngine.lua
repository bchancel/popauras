local _, ns = ...

local ActionEngine = {}
ns.ActionEngine = ActionEngine

local handlers = {}

local function IsAuraDebugEnabled(aura)
  if not aura or type(aura.triggers) ~= "table" then
    return false
  end
  for _, trigger in ipairs(aura.triggers) do
    if type(trigger) == "table" and trigger.debug == true then
      return true
    end
  end
  return false
end

local function DebugLogAction(aura, message)
  if not IsAuraDebugEnabled(aura) then
    return
  end
  if ns.Debug and ns.Debug.Log then
    ns.Debug:Log("ActionEngine", string.format("%s: %s", tostring(aura and aura.name or "Unknown Aura"), tostring(message or "")))
  end
end

function ActionEngine:RegisterHandler(actionType, handler)
  handlers[actionType] = handler
end

function ActionEngine:Fire(aura, event, state)
  local actions = aura and aura.actions
  if type(actions) ~= "table" or #actions == 0 then
    DebugLogAction(aura, string.format("event=%s noActionsConfigured", tostring(event)))
    return
  end

  DebugLogAction(aura, string.format("event=%s actionCount=%d", tostring(event), #actions))

  for index, action in ipairs(actions) do
    DebugLogAction(aura, string.format(
      "action[%d] enabled=%s type=%s configuredEvent=%s unit=%s duration=%s",
      index,
      tostring(action and action.enabled ~= false),
      tostring(action and action.type or ""),
      tostring(action and action.event or ""),
      tostring(action and action.unit or ""),
      tostring(action and action.duration or "")
    ))
    if action.enabled ~= false and action.event == event then
      local handler = handlers[action.type]
      if handler then
        DebugLogAction(aura, string.format("action[%d] firing type=%s", index, tostring(action.type or "")))
        local ok, err = pcall(handler, action, aura, state)
        if not ok and ns.Debug and ns.Debug.Log then
          ns.Debug:Log("ActionEngine", string.format("Error in %s action: %s", tostring(action.type), tostring(err)))
        end
      else
        DebugLogAction(aura, string.format("action[%d] noHandler type=%s", index, tostring(action.type or "")))
      end
    else
      DebugLogAction(aura, string.format("action[%d] skipped eventMismatch=%s disabled=%s", index, tostring(action and action.event ~= event), tostring(action and action.enabled == false)))
    end
  end
end

function ActionEngine:CancelForAura(auraId)
  if ns.UnitFrameGlow and ns.UnitFrameGlow.CancelForAura then
    ns.UnitFrameGlow:CancelForAura(auraId)
  end
end

function ActionEngine:ResolveTemplate(template, state)
  if type(template) ~= "string" or template == "" then
    return template
  end
  template = template:gsub("%%n", state and state.name or "")
  template = template:gsub("%%m", state and state.message or "")
  template = template:gsub("%%s", state and state.statusText or "")
  template = template:gsub("%%u", function()
    local unit = state and state.unit
    if unit and type(unit) == "string" and UnitExists(unit) then
      return UnitName(unit) or ""
    end
    return ""
  end)
  return template
end
