local _, ns = ...

local Safe = ns.SafeValues
local provider = ns.TriggerBase:CreateProvider("spell_cast_event", {
  events = {
    "UNIT_SPELLCAST_SUCCEEDED",
  },
})

provider.activeByAura = {}
provider.sequence = 0
provider.indexBySpellID = nil

local EMPTY = {}

local function AddSpellID(target, seen, value)
  local spellID = Safe:Number(value)
  if spellID and spellID > 0 and not seen[spellID] then
    seen[spellID] = true
    target[#target + 1] = spellID
  end
end

local function GetConfiguredSpellIDs(trigger)
  local result = {}
  local seen = {}
  for _, value in ipairs(type(trigger and trigger.spellIDs) == "table" and trigger.spellIDs or EMPTY) do
    AddSpellID(result, seen, value)
  end
  AddSpellID(result, seen, trigger and trigger.spellId)
  return result
end

local function MatchesSpell(trigger, spellID)
  if not spellID then
    return false
  end
  for _, configuredSpellID in ipairs(GetConfiguredSpellIDs(trigger)) do
    if configuredSpellID == spellID then
      return true
    end
  end
  return false
end

local function GetEventDuration(trigger)
  local duration = Safe:Number(trigger and trigger.castEventDuration) or 1
  return math.max(0.1, math.min(duration, 10))
end

local function GetSpellPresentation(spellID)
  local name = nil
  local icon = nil

  if C_Spell and C_Spell.GetSpellName then
    name = Safe:String(C_Spell.GetSpellName(spellID))
  end
  if C_Spell and C_Spell.GetSpellTexture then
    icon = Safe:Number(C_Spell.GetSpellTexture(spellID))
  end

  return name or ("Spell " .. tostring(spellID)), icon
end

function provider:InvalidateCaches()
  self.indexBySpellID = nil
  self.activeByAura = {}
end

function provider:BuildIndex()
  local indexBySpellID = {}
  for _, auraId in ipairs(ns.Registry:GetFlatOrder()) do
    local aura = ns.Registry:GetAura(auraId)
    if aura then
      for triggerIndex, trigger in ns.TriggerBase:IterateTriggers(aura, "spell_cast_event") do
        for _, spellID in ipairs(GetConfiguredSpellIDs(trigger)) do
          indexBySpellID[spellID] = indexBySpellID[spellID] or {}
          indexBySpellID[spellID][#indexBySpellID[spellID] + 1] = {
            auraId = auraId,
            triggerIndex = triggerIndex,
          }
        end
      end
    end
  end
  self.indexBySpellID = indexBySpellID
end

function provider:HandleEvent(event, ...)
  if event ~= "UNIT_SPELLCAST_SUCCEEDED" then
    return {}
  end

  local unit, castGUID, spellID = ...
  unit = Safe:String(unit)
  if unit ~= "player" then
    return {}
  end

  spellID = Safe:Number(spellID)
  if not spellID or spellID <= 0 then
    return {}
  end

  castGUID = Safe:String(castGUID)
  self.sequence = self.sequence + 1
  local eventKey = castGUID or string.format("player-cast-%d", self.sequence)
  local spellName, icon = GetSpellPresentation(spellID)
  local now = GetTime()
  local affectedAuraIds = {}
  local affectedAuraSet = {}

  if not self.indexBySpellID then
    self:BuildIndex()
  end
  for _, entry in ipairs(self.indexBySpellID[spellID] or EMPTY) do
    local auraId = entry.auraId
    local aura = ns.Registry:GetAura(auraId)
    local trigger = ns.TriggerBase:GetTrigger(aura, entry.triggerIndex)
    if aura and aura.enabled ~= false and trigger and trigger.enabled ~= false
      and trigger.type == "spell_cast_event" and MatchesSpell(trigger, spellID) then
      local duration = GetEventDuration(trigger)
      self.activeByAura[auraId] = self.activeByAura[auraId] or {}
      self.activeByAura[auraId][entry.triggerIndex] = {
        eventKey = eventKey,
        spellID = spellID,
        name = spellName,
        icon = icon,
        duration = duration,
        expirationTime = now + duration,
      }
      if not affectedAuraSet[auraId] then
        affectedAuraSet[auraId] = true
        affectedAuraIds[#affectedAuraIds + 1] = auraId
      end
    end
  end

  return affectedAuraIds
end

function provider:Evaluate(trigger, aura, triggerIndex)
  local byTrigger = aura and self.activeByAura[aura.id] or nil
  local activeEvent = byTrigger and byTrigger[triggerIndex] or nil
  local now = GetTime()
  if not activeEvent or activeEvent.expirationTime <= now or not MatchesSpell(trigger, activeEvent.spellID) then
    if byTrigger then
      byTrigger[triggerIndex] = nil
      if next(byTrigger) == nil then
        self.activeByAura[aura.id] = nil
      end
    end
    return ns.Schema.NormalizeRuntimeState({
      show = false,
      active = false,
      source = "spell_cast_event",
      unit = "player",
    })
  end

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    active = true,
    icon = activeEvent.icon,
    name = activeEvent.name,
    duration = activeEvent.duration,
    expirationTime = activeEvent.expirationTime,
    progressType = "timed",
    value = math.max(0, activeEvent.expirationTime - now),
    total = activeEvent.duration,
    unit = "player",
    spellId = activeEvent.spellID,
    source = "spell_cast_event",
    statusText = "Cast succeeded",
    actionEventKey = activeEvent.eventKey,
  })
end
