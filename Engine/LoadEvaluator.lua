local _, ns = ...

local LoadEvaluator = {}
ns.LoadEvaluator = LoadEvaluator

LoadEvaluator.activeTalentKeys = nil
LoadEvaluator.activeTalentConfigID = nil

local function GetPlayerSpecIndex()
  if GetSpecialization then
    return GetSpecialization() or 0
  end
  return 0
end

local function GetPlayerClassToken()
  local _, classToken = UnitClass("player")
  return classToken
end

local function GetActiveTalentKeys()
  if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID or not C_Traits then
    return {}
  end

  local configID = C_ClassTalents.GetActiveConfigID()
  if not configID then
    return {}
  end

  if LoadEvaluator.activeTalentConfigID == configID and type(LoadEvaluator.activeTalentKeys) == "table" then
    return LoadEvaluator.activeTalentKeys
  end

  local configInfo = C_Traits.GetConfigInfo(configID)
  if not configInfo or type(configInfo.treeIDs) ~= "table" then
    return {}
  end

  local results = {}
  for _, treeID in ipairs(configInfo.treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
      if nodeInfo and (nodeInfo.activeRank or 0) > 0 then
        local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or nil
        if activeEntryID and type(nodeInfo.entryIDs) == "table" and #nodeInfo.entryIDs > 1 then
          results[string.format("%s:%s", tostring(nodeID), tostring(activeEntryID))] = true
        else
          results[tostring(nodeID)] = true
        end
      end
    end
  end

  LoadEvaluator.activeTalentConfigID = configID
  LoadEvaluator.activeTalentKeys = results
  return results
end

function LoadEvaluator:InvalidateCache()
  self.activeTalentKeys = nil
  self.activeTalentConfigID = nil
end

local function TableHasEnabled(map, key)
  return type(map) == "table" and map[key] == true
end

local function TableHasAnyEnabled(map)
  if type(map) ~= "table" then
    return false
  end
  for _, enabled in pairs(map) do
    if enabled then
      return true
    end
  end
  return false
end

local function IsVisibilityEnabled(visibility, key)
  if type(visibility) ~= "table" then
    return true
  end
  if key == "solo" or key == "delve" then
    return visibility[key] ~= false
  end
  return visibility[key] == true
end

local function VisibilityHasAnyEnabled(visibility)
  if type(visibility) ~= "table" then
    return true
  end
  for _, key in ipairs({ "dungeon", "delve", "raid", "open_world", "solo", "arena", "battleground" }) do
    if IsVisibilityEnabled(visibility, key) then
      return true
    end
  end
  return false
end

local function IsItemEquippedByID(itemId)
  itemId = tonumber(itemId or 0) or 0
  if itemId <= 0 then
    return true
  end

  if C_Item and C_Item.IsEquippedItem then
    return C_Item.IsEquippedItem(itemId) == true
  end

  if IsEquippedItem then
    return IsEquippedItem(itemId) == true
  end

  return true
end

local function MatchesVisibility(load)
  if type(load.visibility) ~= "table" then
    return true
  end

  if not VisibilityHasAnyEnabled(load.visibility) then
    return false
  end

  local soloAllowed = IsVisibilityEnabled(load.visibility, "solo")
  local inGroup = false
  if IsInGroup then
    inGroup = IsInGroup() == true
  end
  if not inGroup and GetNumGroupMembers then
    inGroup = (GetNumGroupMembers() or 0) > 0
  end
  if not inGroup and not soloAllowed then
    return false
  end

  local inInstance, instanceType = IsInInstance()
  if not inInstance then
    return IsVisibilityEnabled(load.visibility, "open_world")
  end

  if instanceType == "scenario" then
    return IsVisibilityEnabled(load.visibility, "delve")
  elseif instanceType == "party" then
    return IsVisibilityEnabled(load.visibility, "dungeon")
  elseif instanceType == "raid" then
    return IsVisibilityEnabled(load.visibility, "raid")
  elseif instanceType == "arena" then
    return IsVisibilityEnabled(load.visibility, "arena")
  elseif instanceType == "pvp" then
    return IsVisibilityEnabled(load.visibility, "battleground")
  end

  return IsVisibilityEnabled(load.visibility, "open_world")
end

function LoadEvaluator:Matches(aura)
  local load = aura.load or {}
  local classToken = GetPlayerClassToken()

  if load.class and load.class ~= "" and not TableHasAnyEnabled(load.classes) then
    if classToken ~= load.class then
      return false
    end
  end

  if TableHasAnyEnabled(load.classes) and not TableHasEnabled(load.classes, classToken) then
    return false
  end

  local specIndex = GetPlayerSpecIndex()
  if load.spec and load.spec > 0 and not TableHasAnyEnabled(load.specs) and load.spec ~= specIndex then
    return false
  end

  if TableHasAnyEnabled(load.specs) then
    local specKey = string.format("%s:%d", classToken or "", specIndex or 0)
    if not TableHasEnabled(load.specs, specKey) then
      return false
    end
  end

  if load.talent == true and TableHasAnyEnabled(load.talents) then
    local activeTalents = GetActiveTalentKeys()
    for talentKey, enabled in pairs(load.talents) do
      if enabled and not activeTalents[talentKey] then
        return false
      end
    end
  end

  if load.level and load.level > 0 and UnitLevel("player") < load.level then
    return false
  end

  if load.combat == "in" and not InCombatLockdown() then
    return false
  end

  if load.combat == "out" and InCombatLockdown() then
    return false
  end

  if not IsItemEquippedByID(load.equippedItemId) then
    return false
  end

  if not MatchesVisibility(load) then
    return false
  end

  if load.instanceType and load.instanceType ~= "" then
    local _, instanceType = IsInInstance()
    if instanceType ~= load.instanceType then
      return false
    end
  end

  if load.encounterId and load.encounterId > 0 then
    local encounterId = select(8, GetInstanceInfo())
    if encounterId ~= load.encounterId then
      return false
    end
  end

  return aura.enabled ~= false
end
