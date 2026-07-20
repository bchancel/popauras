local _, ns = ...

local Safe = ns.SafeValues
local Schema = {}
ns.Schema = Schema

local function SafeNumber(value, fallback)
  local safe = Safe:Number(value)
  return safe == nil and fallback or safe
end

local function SafeBoolean(value, fallback)
  local safe = Safe:Boolean(value)
  return safe == nil and fallback or safe
end

local function SafeString(value, fallback)
  local safe = Safe:String(value)
  return safe == nil and fallback or safe
end

local function NormalizeTimer(state)
  local inbound = type(state.timer) == "table" and state.timer or nil
  local object = inbound and inbound.object or state.durationObject
  local duration = inbound and inbound.duration or state.duration
  local expirationTime = inbound and inbound.expirationTime or state.expirationTime
  local remaining = inbound and inbound.remaining or nil
  local active = inbound and inbound.active
  if active == nil then
    active = state.active
  end

  return {
    active = SafeBoolean(active, false),
    object = object,
    duration = Safe:Number(duration),
    expirationTime = Safe:Number(expirationTime),
    remaining = Safe:Number(remaining),
    opaque = inbound and SafeBoolean(inbound.opaque, false) or (object and Safe:DurationHasSecrets(object) or false),
    zero = inbound and SafeBoolean(inbound.zero, false) or false,
    source = inbound and SafeString(inbound.source, nil) or SafeString(state.source, nil),
  }
end

local function NormalizeCount(state)
  local inbound = type(state.count) == "table" and state.count or nil
  return {
    value = Safe:Number(inbound and inbound.value or state.stacks),
    max = Safe:Number(inbound and inbound.max or state.maxStacks),
    display = Safe:Display(inbound and inbound.display or state.stackDisplayValue),
  }
end

function Schema.NormalizeRuntimeState(state)
  state = type(state) == "table" and state or {}

  local show = SafeBoolean(state.show, false)
  local matched = Safe:Boolean(state.matched)
  if matched == nil then
    matched = show
  end

  state.show = show
  state.matched = matched
  state.active = SafeBoolean(state.active, false)
  state.icon = Safe:Number(state.icon) or Safe:String(state.icon, nil)
  state.name = SafeString(state.name, "")
  state.stacks = SafeNumber(state.stacks, 0)
  state.stackText = SafeString(state.stackText, nil)
  state.stackDisplayValue = Safe:Display(state.stackDisplayValue)
  state.hasStackDisplayValue = SafeBoolean(state.hasStackDisplayValue, false)
  state.duration = SafeNumber(state.duration, 0)
  state.expirationTime = SafeNumber(state.expirationTime, 0)
  state.progressType = SafeString(state.progressType, "static")
  state.value = SafeNumber(state.value, 0)
  state.total = SafeNumber(state.total, 0)
  state.isUsable = SafeBoolean(state.isUsable, true)
  state.isReady = SafeBoolean(state.isReady, false)
  state.noCharges = SafeBoolean(state.noCharges, false)
  -- Spell cooldowns use a separate, buff-aware active signal for appearance.
  -- Their ordinary `active` value means that the cooldown/recharge is running.
  state.activeBuff = SafeBoolean(state.activeBuff, false)
  state.activeBuffGlow = SafeBoolean(state.activeBuffGlow, false)
  state.activeGlowStyle = SafeString(state.activeGlowStyle, "NONE")
  state.activeBuffDuration = SafeNumber(state.activeBuffDuration, 0)
  state.activeBuffExpirationTime = SafeNumber(state.activeBuffExpirationTime, 0)
  state.isEnabled = SafeBoolean(state.isEnabled, true)
  state.loadMatched = SafeBoolean(state.loadMatched, true)
  state.source = SafeString(state.source, "")
  state.statusText = SafeString(state.statusText, "")
  state.message = SafeString(state.message, "")
  state.desaturate = SafeBoolean(state.desaturate, false)
  state.glow = SafeBoolean(state.glow, false)
  state.key = SafeString(state.key, nil)
  state.equipSlot = SafeNumber(state.equipSlot, 0)
  state.trinketEffectActive = SafeBoolean(state.trinketEffectActive, false)
  state.availability = SafeString(state.availability, "available")

  state.timer = NormalizeTimer(state)
  state.count = NormalizeCount(state)
  state.durationObject = state.timer.object
  if state.timer.duration ~= nil then
    state.duration = state.timer.duration
  end
  if state.timer.expirationTime ~= nil then
    state.expirationTime = state.timer.expirationTime
  end

  state.matchedUnits = type(state.matchedUnits) == "table" and state.matchedUnits or nil
  state.unitStates = type(state.unitStates) == "table" and state.unitStates or nil
  state._durationRemainingCacheStamp = nil
  state._durationRemainingCacheValue = nil
  return state
end
