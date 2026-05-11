local _, ns = ...

local LoadEvaluator = {}
ns.LoadEvaluator = LoadEvaluator
local Items = ns.util.Items

LoadEvaluator.activeTalentKeys = nil
LoadEvaluator.activeTalentConfigID = nil
LoadEvaluator.availableTalentKeys = nil
LoadEvaluator.availableTalentConfigID = nil
LoadEvaluator.currentEncounterId = 0

local function GetPlayerSpecIndex()
  if GetSpecialization then
    return GetSpecialization() or 0
  end
  return 0
end

local function GetPlayerSpecID()
  local specIndex = GetPlayerSpecIndex()
  if specIndex > 0 and GetSpecializationInfo then
    return tonumber((GetSpecializationInfo(specIndex))) or 0
  end
  return 0
end

local function GetPlayerClassToken()
  local _, classToken = UnitClass("player")
  return classToken
end

local function NormalizeSavedLoadoutNameKey(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return ""
  end
  return string.lower(value)
end

local function BuildSavedLoadoutKey(classToken, specID, configID, name)
  classToken = tostring(classToken or "")
  specID = tonumber(specID or 0) or 0
  configID = tonumber(configID or 0) or 0
  if classToken == "" or specID <= 0 then
    return nil
  end

  local nameKey = NormalizeSavedLoadoutNameKey(name)
  if nameKey ~= "" then
    return string.format("%s:%d:name:%s", classToken, specID, nameKey)
  end

  if configID == 0 then
    return nil
  end

  return string.format("%s:%d:config:%d", classToken, specID, configID)
end

local function ParseSavedLoadoutKey(key)
  local legacyClassToken, legacySpecID, legacyConfigID = tostring(key or ""):match("^([^:]+):(-?%d+):(-?%d+)$")
  legacySpecID = tonumber(legacySpecID or 0) or 0
  legacyConfigID = tonumber(legacyConfigID or 0) or 0
  if legacyClassToken and legacyClassToken ~= "" and legacySpecID > 0 and legacyConfigID ~= 0 then
    return legacyClassToken, legacySpecID, legacyConfigID, ""
  end

  local classToken, specID, keyType, keyValue = tostring(key or ""):match("^([^:]+):(-?%d+):([^:]+):(.*)$")
  specID = tonumber(specID or 0) or 0
  if not classToken or classToken == "" or specID <= 0 then
    return nil, 0, 0, ""
  end

  if keyType == "config" then
    local configID = tonumber(keyValue or 0) or 0
    if configID == 0 then
      return nil, 0, 0, ""
    end
    return classToken, specID, configID, ""
  end

  if keyType == "name" then
    local nameKey = NormalizeSavedLoadoutNameKey(keyValue)
    if nameKey == "" then
      return nil, 0, 0, ""
    end
    return classToken, specID, 0, nameKey
  end

  return nil, 0, 0, ""
end

local function GetSavedLoadoutSelections(load)
  local results = {}
  local selections = type(load and load.savedLoadoutSelections) == "table" and load.savedLoadoutSelections or nil

  if selections then
    for key, entry in pairs(selections) do
      local parsedClassToken, parsedSpecID, parsedConfigID, parsedNameKey = ParseSavedLoadoutKey(key)
      local classToken = parsedClassToken
      local specID = parsedSpecID
      local configID = parsedConfigID
      local nameKey = parsedNameKey

      if type(entry) == "table" then
        classToken = tostring(entry.classToken or classToken or "")
        specID = tonumber(entry.specID or specID or 0) or 0
        configID = tonumber(entry.configID or configID or 0) or 0
        nameKey = NormalizeSavedLoadoutNameKey(entry.name or nameKey)
      elseif entry ~= true then
        classToken = ""
        specID = 0
        configID = 0
        nameKey = ""
      end

      local normalizedKey = BuildSavedLoadoutKey(classToken, specID, configID, nameKey)
      if normalizedKey then
        results[#results + 1] = {
          key = normalizedKey,
          classToken = classToken,
          specID = specID,
          configID = configID,
          nameKey = nameKey,
        }
      end
    end
  end

  if #results == 0 then
    local legacyName = NormalizeSavedLoadoutNameKey(load and load.savedLoadoutName)
    local legacyKey = BuildSavedLoadoutKey(
      load and load.savedLoadoutClassToken,
      load and load.savedLoadoutSpecId,
      load and load.savedLoadoutId,
      legacyName
    )
    if legacyKey then
      results[1] = {
        key = legacyKey,
        classToken = tostring(load and load.savedLoadoutClassToken or ""),
        specID = tonumber(load and load.savedLoadoutSpecId or 0) or 0,
        configID = tonumber(load and load.savedLoadoutId or 0) or 0,
        nameKey = legacyName,
      }
    end
  end

  return results
end

function LoadEvaluator:GetCurrentSavedLoadoutInfo()
  if not (C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and C_Traits and C_Traits.GetConfigInfo) then
    return nil, "Saved loadout APIs unavailable."
  end

  local classToken = GetPlayerClassToken()
  local specIndex = GetPlayerSpecIndex()
  local specID = GetPlayerSpecID()
  if not classToken or classToken == "" or specIndex <= 0 or specID <= 0 then
    return nil, "No active specialization."
  end

  local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
  if configID == nil then
    return nil, "No saved talent loadout selected."
  end

  local configInfo = C_Traits.GetConfigInfo(configID)
  local specName = select(2, GetSpecializationInfo(specIndex))
  local loadoutName = configInfo and configInfo.name or nil
  if not loadoutName or loadoutName == "" then
    loadoutName = configID == -2 and "Starter Build" or ("Loadout " .. tostring(configID))
  end

  return {
    classToken = classToken,
    specIndex = specIndex,
    specID = specID,
    specName = specName or "",
    configID = configID,
    name = loadoutName,
  }, nil
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

local function GetAvailableTalentKeys()
  if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID or not C_Traits then
    return {}
  end

  local configID = C_ClassTalents.GetActiveConfigID()
  if not configID then
    return {}
  end

  if LoadEvaluator.availableTalentConfigID == configID and type(LoadEvaluator.availableTalentKeys) == "table" then
    return LoadEvaluator.availableTalentKeys
  end

  local configInfo = C_Traits.GetConfigInfo(configID)
  if not configInfo or type(configInfo.treeIDs) ~= "table" then
    return {}
  end

  local results = {}
  for _, treeID in ipairs(configInfo.treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
      if nodeInfo then
        if type(nodeInfo.entryIDs) == "table" and #nodeInfo.entryIDs > 1 then
          for _, entryID in ipairs(nodeInfo.entryIDs) do
            results[string.format("%s:%s", tostring(nodeID), tostring(entryID))] = true
          end
        else
          results[tostring(nodeID)] = true
        end
      end
    end
  end

  LoadEvaluator.availableTalentConfigID = configID
  LoadEvaluator.availableTalentKeys = results
  return results
end

function LoadEvaluator:InvalidateCache()
  self.activeTalentKeys = nil
  self.activeTalentConfigID = nil
  self.availableTalentKeys = nil
  self.availableTalentConfigID = nil
end

function LoadEvaluator:SetCurrentEncounterId(encounterId)
  self.currentEncounterId = tonumber(encounterId or 0) or 0
end

function LoadEvaluator:GetCurrentEncounterId()
  return tonumber(self.currentEncounterId or 0) or 0
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

local EQUIPMENT_SLOTS = {
  INVSLOT_HEAD or 1,
  INVSLOT_NECK or 2,
  INVSLOT_SHOULDER or 3,
  INVSLOT_CHEST or 5,
  INVSLOT_WAIST or 6,
  INVSLOT_LEGS or 7,
  INVSLOT_FEET or 8,
  INVSLOT_WRIST or 9,
  INVSLOT_HAND or 10,
  INVSLOT_FINGER1 or 11,
  INVSLOT_FINGER2 or 12,
  INVSLOT_TRINKET1 or 13,
  INVSLOT_TRINKET2 or 14,
  INVSLOT_BACK or 15,
  INVSLOT_MAINHAND or 16,
  INVSLOT_OFFHAND or 17,
}

local function NormalizeText(value)
  if Items and Items.NormalizeText then
    return Items.NormalizeText(value)
  end
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function IsItemEquippedByName(itemName)
  itemName = NormalizeText(itemName)
  if itemName == "" then
    return true
  end

  if Items and Items.ResolveItemReference then
    local resolvedId = Items:ResolveItemReference(0, itemName)
    resolvedId = tonumber(resolvedId or 0) or 0
    if resolvedId > 0 then
      return IsItemEquippedByID(resolvedId)
    end
  end

  local needle = string.lower(itemName)
  for _, slotId in ipairs(EQUIPMENT_SLOTS) do
    local itemId = GetInventoryItemID and GetInventoryItemID("player", slotId) or nil
    itemId = tonumber(itemId or 0) or 0
    if itemId > 0 then
      local equippedName = Items and Items.GetItemName and Items:GetItemName(itemId) or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId)) or nil
      if equippedName and string.lower(equippedName) == needle then
        return true
      end
    end
  end

  return false
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
    local hasRelevantSpecFilter = false
    local prefix = tostring(classToken or "") .. ":"
    for configuredSpecKey, enabled in pairs(load.specs) do
      if enabled and tostring(configuredSpecKey):sub(1, #prefix) == prefix then
        hasRelevantSpecFilter = true
        break
      end
    end
    if hasRelevantSpecFilter and not TableHasEnabled(load.specs, specKey) then
      return false
    end
  end

  if load.talent == true and TableHasAnyEnabled(load.talents) then
    local activeTalents = GetActiveTalentKeys()
    local availableTalents = GetAvailableTalentKeys()
    local hasAvailableTalents = next(availableTalents) ~= nil
    for talentKey, enabled in pairs(load.talents) do
      if enabled and (not hasAvailableTalents or availableTalents[talentKey]) and not activeTalents[talentKey] then
        return false
      end
    end
  end

  local savedLoadoutMode = tostring(load.savedLoadoutMode or "any")
  if savedLoadoutMode == "only" or savedLoadoutMode == "except" then
    local selectedLoadouts = GetSavedLoadoutSelections(load)
    if #selectedLoadouts > 0 then
      local currentInfo = self:GetCurrentSavedLoadoutInfo()
      local currentNameKey = NormalizeSavedLoadoutNameKey(currentInfo and currentInfo.name)
      local loadoutMatches = false

      if currentInfo then
        for _, selectedEntry in ipairs(selectedLoadouts) do
          if selectedEntry.classToken == currentInfo.classToken and selectedEntry.specID == currentInfo.specID then
            if selectedEntry.configID ~= 0 and selectedEntry.configID == currentInfo.configID then
              loadoutMatches = true
              break
            end
            if selectedEntry.nameKey ~= "" and selectedEntry.nameKey == currentNameKey then
              loadoutMatches = true
              break
            end
          end
        end
      end

      if savedLoadoutMode == "only" and not loadoutMatches then
        return false
      end

      if savedLoadoutMode == "except" and loadoutMatches then
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

  if load.equippedItemId == nil or (tonumber(load.equippedItemId or 0) or 0) <= 0 then
    if not IsItemEquippedByName(load.equippedItemName) then
      return false
    end
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

  if load.instanceId and load.instanceId > 0 then
    local instanceId = select(8, GetInstanceInfo())
    if instanceId ~= load.instanceId then
      return false
    end
  end

  if load.encounterId and load.encounterId > 0 then
    local encounterId = self:GetCurrentEncounterId()
    if encounterId ~= load.encounterId then
      return false
    end
  end

  return aura.enabled ~= false
end
