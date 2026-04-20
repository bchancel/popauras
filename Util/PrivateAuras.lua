local _, ns = ...

local PrivateAuras = {}
ns.util.PrivateAuras = PrivateAuras

local function IterateRosterUnits()
  local units = {}

  if IsInRaid and IsInRaid() then
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    for index = 1, count do
      units[#units + 1] = "raid" .. index
    end
    return units
  end

  units[#units + 1] = "player"

  if IsInGroup and IsInGroup() then
    local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    for index = 1, count do
      units[#units + 1] = "party" .. index
    end
  end

  return units
end

local function IsTankUnit(unit)
  if not unit or not UnitExists or not UnitExists(unit) then
    return false
  end
  if not UnitGroupRolesAssigned then
    return false
  end
  return UnitGroupRolesAssigned(unit) == "TANK"
end

function PrivateAuras:GetTargetMode(trigger)
  local mode = tostring(trigger and trigger.privateAuraTarget or "player"):lower()
  if mode == "co_tank" then
    mode = "cotank"
  end
  if mode ~= "cotank" then
    mode = "player"
  end
  return mode
end

function PrivateAuras:ResolveCoTankUnit()
  local playerIsTank = IsTankUnit("player")
  local fallback = nil

  for _, unit in ipairs(IterateRosterUnits()) do
    if unit ~= "player" and IsTankUnit(unit) then
      if playerIsTank then
        return unit
      end
      fallback = fallback or unit
    end
  end

  return fallback
end

function PrivateAuras:ResolveUnit(trigger)
  if self:GetTargetMode(trigger) == "cotank" then
    return self:ResolveCoTankUnit()
  end
  return "player"
end

