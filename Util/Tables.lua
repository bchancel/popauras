local _, ns = ...

local Tables = {}
ns.util.Tables = Tables

function Tables.DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, nested in pairs(value) do
    copy[Tables.DeepCopy(key)] = Tables.DeepCopy(nested)
  end
  return copy
end

function Tables.MergeDefaults(target, defaults)
  target = target or {}
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      target[key] = Tables.MergeDefaults(type(target[key]) == "table" and target[key] or {}, value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
  return target
end

function Tables.WipeArray(tbl)
  for i = #tbl, 1, -1 do
    tbl[i] = nil
  end
end

function Tables.IndexOf(tbl, needle)
  for index, value in ipairs(tbl) do
    if value == needle then
      return index
    end
  end
  return nil
end

function Tables.RemoveValue(tbl, needle)
  local index = Tables.IndexOf(tbl, needle)
  if index then
    table.remove(tbl, index)
    return true
  end
  return false
end
