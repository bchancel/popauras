local _, ns = ...

local ActionEngine = {}
ns.ActionEngine = ActionEngine

local handlers = {}

function ActionEngine:RegisterHandler(actionType, handler)
  handlers[actionType] = handler
end

function ActionEngine:Fire(aura, event, state)
  local actions = aura and aura.actions
  if type(actions) ~= "table" or #actions == 0 then
    return
  end

  for _, action in ipairs(actions) do
    if action.enabled ~= false and action.event == event then
      local handler = handlers[action.type]
      if handler then
        local ok, err = pcall(handler, action, aura, state)
        if not ok and ns.Debug and ns.Debug.Log then
          ns.Debug:Log("ActionEngine", string.format("Error in %s action: %s", tostring(action.type), tostring(err)))
        end
      end
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
