local _, ns = ...

local Base = {}
ns.TriggerBase = Base

local EMPTY = {}

function Base:CreateProvider(key, definition)
  definition.key = key
  ns.providers[key] = definition
  return definition
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
