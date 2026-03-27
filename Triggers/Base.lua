local _, ns = ...

local Base = {}
ns.TriggerBase = Base

function Base:CreateProvider(key, definition)
  definition.key = key
  ns.providers[key] = definition
  return definition
end
