local _, ns = ...

local Schema = {}
ns.Schema = Schema

function Schema.NormalizeRuntimeState(state)
  state = state or {}

  local show = state.show == true
  local matched = state.matched
  if matched == nil then
    matched = show
  end
  matched = matched == true
  local active = state.active == true
  local icon = state.icon
  local name = state.name or ""
  local stacks = state.stacks or 0
  local stackText = state.stackText
  local stackDisplayValue = state.stackDisplayValue
  local hasStackDisplayValue = state.hasStackDisplayValue == true
  local duration = state.duration or 0
  local expirationTime = state.expirationTime or 0
  local durationObject = state.durationObject
  local progressType = state.progressType or "static"
  local value = state.value or 0
  local total = state.total or 0
  local isUsable = state.isUsable ~= false
  local isReady = state.isReady == true
  local isEnabled = state.isEnabled ~= false
  local unit = state.unit
  local matchedUnits = type(state.matchedUnits) == "table" and state.matchedUnits or nil
  local unitStates = type(state.unitStates) == "table" and state.unitStates or nil
  local auraInstanceID = state.auraInstanceID
  local spellId = state.spellId
  local itemId = state.itemId
  local source = state.source or ""
  local statusText = state.statusText or ""
  local message = state.message or ""
  local actionEventKey = state.actionEventKey
  local debugExtra = state.debugExtra
  local color = state.color
  local desaturate = state.desaturate == true
  local glow = state.glow == true

  state.show = show
  state.matched = matched
  state.active = active
  state.icon = icon
  state.name = name
  state.stacks = stacks
  state.stackText = stackText
  state.stackDisplayValue = stackDisplayValue
  state.hasStackDisplayValue = hasStackDisplayValue
  state.duration = duration
  state.expirationTime = expirationTime
  state.durationObject = durationObject
  state.progressType = progressType
  state.value = value
  state.total = total
  state.isUsable = isUsable
  state.isReady = isReady
  state.isEnabled = isEnabled
  state.unit = unit
  state.matchedUnits = matchedUnits
  state.unitStates = unitStates
  state.auraInstanceID = auraInstanceID
  state.spellId = spellId
  state.itemId = itemId
  state.source = source
  state.statusText = statusText
  state.message = message
  state.actionEventKey = actionEventKey
  state.debugExtra = debugExtra
  state.color = color
  state.desaturate = desaturate
  state.glow = glow
  state._durationRemainingCacheStamp = nil
  state._durationRemainingCacheValue = nil
  return state
end
