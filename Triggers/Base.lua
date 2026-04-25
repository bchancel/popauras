local _, ns = ...

local Base = {}
ns.TriggerBase = Base

local EMPTY = {}

function Base:CreateProvider(key, definition)
  definition.key = key
  ns.providers[key] = definition
  return definition
end

function Base:InvalidateProviderCaches(providerKey)
  if type(providerKey) == "string" and providerKey ~= "" then
    local provider = ns.providers and ns.providers[providerKey] or nil
    if provider then
      provider._cacheToken = nil
      provider._cachedAuraIds = nil
      provider._cachedAuraIdsByUnit = nil
    end
    return
  end

  for _, provider in pairs(ns.providers or EMPTY) do
    provider._cacheToken = nil
    provider._cachedAuraIds = nil
    provider._cachedAuraIdsByUnit = nil
  end
end

function Base:GetTriggers(aura)
  if type(aura) ~= "table" or type(aura.triggers) ~= "table" then
    return EMPTY
  end
  return aura.triggers
end

function Base:GetTrigger(aura, index)
  local triggers = self:GetTriggers(aura)
  return triggers[tonumber(index or 1) or 1]
end

function Base:IterateTriggers(aura, triggerType)
  local triggers = self:GetTriggers(aura)
  local index = 0
  return function()
    while true do
      index = index + 1
      local trigger = triggers[index]
      if trigger == nil then
        return nil
      end
      if trigger.enabled ~= false and (triggerType == nil or trigger.type == triggerType) then
        return index, trigger
      end
    end
  end
end

function Base:AnyTriggerMatches(aura, triggerType, predicate)
  for index, trigger in self:IterateTriggers(aura, triggerType) do
    if not predicate or predicate(trigger, index) then
      return true, trigger, index
    end
  end
  return false, nil, nil
end
