local _, ns = ...

local Frames = ns.util.Frames
local Items = ns.util.Items

local Panel = {}
ns.panels.LoadPanel = Panel

local STATIC_CLASS_SPECS = {
  DEATHKNIGHT = { className = "Death Knight", specs = { "Blood", "Frost", "Unholy" } },
  DEMONHUNTER = { className = "Demon Hunter", specs = { "Havoc", "Vengeance", "Devourer" } },
  DRUID = { className = "Druid", specs = { "Balance", "Feral", "Guardian", "Restoration" } },
  EVOKER = { className = "Evoker", specs = { "Devastation", "Preservation", "Augmentation" } },
  HUNTER = { className = "Hunter", specs = { "Beast Mastery", "Marksmanship", "Survival" } },
  MAGE = { className = "Mage", specs = { "Arcane", "Fire", "Frost" } },
  MONK = { className = "Monk", specs = { "Brewmaster", "Mistweaver", "Windwalker" } },
  PALADIN = { className = "Paladin", specs = { "Holy", "Protection", "Retribution" } },
  PRIEST = { className = "Priest", specs = { "Discipline", "Holy", "Shadow" } },
  ROGUE = { className = "Rogue", specs = { "Assassination", "Outlaw", "Subtlety" } },
  SHAMAN = { className = "Shaman", specs = { "Elemental", "Enhancement", "Restoration" } },
  WARLOCK = { className = "Warlock", specs = { "Affliction", "Demonology", "Destruction" } },
  WARRIOR = { className = "Warrior", specs = { "Arms", "Fury", "Protection" } },
}

local CLASS_FILE_TO_ID = {
  WARRIOR = 1,
  PALADIN = 2,
  HUNTER = 3,
  ROGUE = 4,
  PRIEST = 5,
  DEATHKNIGHT = 6,
  SHAMAN = 7,
  MAGE = 8,
  WARLOCK = 9,
  MONK = 10,
  DRUID = 11,
  DEMONHUNTER = 12,
  EVOKER = 13,
}

local CLASS_ORDER = {
  "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK",
  "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local function CopySpecs(specs)
  local copy = {}
  for index, specName in ipairs(specs or {}) do
    copy[index] = specName
  end
  return copy
end

local function BuildClassSpecs()
  local classSpecs = {}

  for classToken, info in pairs(STATIC_CLASS_SPECS) do
    classSpecs[classToken] = {
      className = info.className,
      specs = CopySpecs(info.specs),
    }
  end

  if not (GetNumSpecializationsForClassID and GetSpecializationInfoForClassID) then
    return classSpecs
  end

  for _, classToken in ipairs(CLASS_ORDER) do
    local classID = CLASS_FILE_TO_ID[classToken]
    if classID then
      local specCount = tonumber(GetNumSpecializationsForClassID(classID) or 0) or 0
      if specCount > 0 then
        local resolvedClassName = classSpecs[classToken] and classSpecs[classToken].className or classToken
        if GetClassInfo then
          local className = GetClassInfo(classID)
          if type(className) == "string" and className ~= "" then
            resolvedClassName = className
          end
        end

        local resolvedSpecs = {}
        for specIndex = 1, specCount do
          local _, specName = GetSpecializationInfoForClassID(classID, specIndex)
          resolvedSpecs[specIndex] = (type(specName) == "string" and specName ~= "") and specName or (classSpecs[classToken] and classSpecs[classToken].specs[specIndex]) or tostring(specIndex)
        end

        classSpecs[classToken] = {
          className = resolvedClassName,
          specs = resolvedSpecs,
        }
      end
    end
  end

  return classSpecs
end

local CLASS_SPECS = BuildClassSpecs()

local VISIBILITY_OPTIONS = {
  { key = "dungeon", label = "Dungeons" },
  { key = "delve", label = "Delves" },
  { key = "raid", label = "Raids" },
  { key = "open_world", label = "Open World" },
  { key = "solo", label = "Solo" },
  { key = "arena", label = "Arena" },
  { key = "battleground", label = "Battlegrounds" },
}

local INSTANCE_TYPE_OPTIONS = {
  { value = "", label = "Any Instance Type" },
  { value = "party", label = "Party / Dungeon" },
  { value = "raid", label = "Raid" },
  { value = "scenario", label = "Scenario / Delve" },
  { value = "arena", label = "Arena" },
  { value = "pvp", label = "Battleground" },
}

local SAVED_LOADOUT_MODE_OPTIONS = {
  { value = "only", label = "Only Selected Layouts" },
  { value = "except", label = "Except Selected Layouts" },
}

local FEATURE_DISABLED_NOTICES = {
  feature_nameplate_buffs = "Nameplate Buffs is temporarily disabled in this build. "
    .. "This aura remains saved, but it cannot load until the feature is enabled again.",
}

local function GetFeatureDisabledNotice(aura)
  if not (ns.LoadEvaluator and ns.LoadEvaluator.GetDisabledFeature) then
    return nil
  end

  local featureName = ns.LoadEvaluator:GetDisabledFeature(aura)
  if not featureName then
    return nil
  end

  return FEATURE_DISABLED_NOTICES[featureName]
    or string.format("This aura cannot load because the %s feature is disabled.",
      tostring(featureName):gsub("^feature_", ""):gsub("_", " "))
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

local function CombatModeLabel(current)
  if current == "in" then
    return "In Combat"
  elseif current == "out" then
    return "Out of Combat"
  end
  return "Always"
end

local function GetInstanceTypeLabel(current)
  for _, entry in ipairs(INSTANCE_TYPE_OPTIONS) do
    if entry.value == current then
      return entry.label
    end
  end
  return INSTANCE_TYPE_OPTIONS[1].label
end

local function NormalizeText(value)
  if Items and Items.NormalizeText then
    return Items.NormalizeText(value)
  end
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function GetEquippedItemResolvedText(itemId, itemName)
  local resolvedId = tonumber(itemId or 0) or 0
  local resolvedName = NormalizeText(itemName)
  if Items and Items.ResolveItemReference then
    resolvedId, resolvedName = Items:ResolveItemReference(itemId, itemName)
  end

  if resolvedId > 0 then
    local itemLabel = Items and Items.GetItemName and Items:GetItemName(resolvedId) or resolvedName
    itemLabel = NormalizeText(itemLabel)
    if itemLabel ~= "" then
      return string.format("|cff88ff88Equipped Item:|r %s (%d)", itemLabel, resolvedId)
    end
    return string.format("|cff88ff88Equipped Item ID:|r %d", resolvedId)
  end

  if resolvedName ~= "" then
    return string.format("|cff88ff88Equipped Item Name:|r %s", resolvedName)
  end

  return "|cffaaaaaaNo equipped item requirement.|r"
end

local function ResolveItemFilterInput(input)
  input = NormalizeText(input)
  if input == "" then
    return 0, ""
  end

  if Items and Items.ResolveInput then
    local itemId, itemName = Items:ResolveInput(input)
    if itemId > 0 then
      return itemId, itemName or ""
    end
    return 0, input
  end

  local numeric = tonumber(input)
  if numeric then
    return math.floor(numeric + 0.5), ""
  end

  return 0, input
end

local function SetCollapseButtonText(button, collapsed)
  if button and button.SetText then
    button:SetText(collapsed and ">" or "v")
  end
end

local function EnsureMap(tbl)
  if type(tbl) ~= "table" then
    return {}
  end
  return tbl
end

local function GetVisibilitySelection(load)
  local visibility = type(load and load.visibility) == "table" and load.visibility or nil
  local values = {}
  for _, entry in ipairs(VISIBILITY_OPTIONS) do
    values[entry.key] = IsVisibilityEnabled(visibility, entry.key)
  end
  return values
end

local function GetPlayerClassToken()
  local _, classToken = UnitClass("player")
  return classToken
end

local function GetPlayerSpecIndex()
  if GetSpecialization then
    return GetSpecialization() or 0
  end
  return 0
end

local function NormalizeSavedLoadoutMode(value)
  return tostring(value or "") == "except" and "except" or "only"
end

local function GetSavedLoadoutModeLabel(value)
  local normalized = NormalizeSavedLoadoutMode(value)
  for _, entry in ipairs(SAVED_LOADOUT_MODE_OPTIONS) do
    if entry.value == normalized then
      return entry.label
    end
  end
  return SAVED_LOADOUT_MODE_OPTIONS[1].label
end

local function GetCurrentSavedLoadoutInfo()
  if ns.LoadEvaluator and ns.LoadEvaluator.GetCurrentSavedLoadoutInfo then
    return ns.LoadEvaluator:GetCurrentSavedLoadoutInfo()
  end
  return nil, "Saved loadout APIs unavailable."
end

local function NormalizeSavedLoadoutNameKey(value)
  value = NormalizeText(value)
  if value == "" then
    return ""
  end
  return string.lower(value)
end

local function GetClassLabel(classToken)
  local classInfo = CLASS_SPECS[tostring(classToken or "")]
  return classInfo and classInfo.className or tostring(classToken or "")
end

local function GetCurrentSpecInfo()
  local classToken = GetPlayerClassToken()
  local specIndex = GetPlayerSpecIndex()
  local specID, specName = 0, ""
  if specIndex > 0 and GetSpecializationInfo then
    specID, specName = GetSpecializationInfo(specIndex)
  end
  specID = tonumber(specID or 0) or 0
  return {
    classToken = classToken,
    className = GetClassLabel(classToken),
    specIndex = specIndex,
    specID = specID,
    specName = tostring(specName or ""),
  }
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

local function CreateSavedLoadoutSelectionEntry(classToken, specID, configID, name, specName, className)
  local resolvedName = NormalizeText(name)
  if resolvedName == "" then
    resolvedName = tonumber(configID or 0) == -2 and "Starter Build" or ("Loadout " .. tostring(configID))
  end

  local key = BuildSavedLoadoutKey(classToken, specID, configID, resolvedName)
  if not key then
    return nil
  end

  return {
    key = key,
    classToken = tostring(classToken or ""),
    className = NormalizeText(className) ~= "" and NormalizeText(className) or GetClassLabel(classToken),
    specID = tonumber(specID or 0) or 0,
    specName = NormalizeText(specName),
    configID = tonumber(configID or 0) or 0,
    name = resolvedName,
    nameKey = NormalizeSavedLoadoutNameKey(resolvedName),
  }
end

local function EnsureSavedLoadoutSelections(load)
  if type(load) ~= "table" then
    return {}
  end

  local rawSelections = EnsureMap(load.savedLoadoutSelections)
  if next(rawSelections) == nil then
    local legacyEntry = CreateSavedLoadoutSelectionEntry(
      load.savedLoadoutClassToken,
      load.savedLoadoutSpecId,
      load.savedLoadoutId,
      load.savedLoadoutName,
      "",
      GetClassLabel(load.savedLoadoutClassToken)
    )
    if legacyEntry then
      rawSelections[legacyEntry.key] = legacyEntry
    end
  end

  local normalizedSelections = {}
  for key, entry in pairs(rawSelections) do
    local normalized = nil
    if entry == true then
      local classToken, specID, configID, nameKey = ParseSavedLoadoutKey(key)
      normalized = CreateSavedLoadoutSelectionEntry(classToken, specID, configID, nameKey, "", GetClassLabel(classToken))
    elseif type(entry) == "table" then
      local classToken, specID, configID, nameKey = ParseSavedLoadoutKey(key)
      normalized = CreateSavedLoadoutSelectionEntry(
        entry.classToken or classToken,
        entry.specID or specID,
        entry.configID or configID,
        entry.name or nameKey,
        entry.specName,
        entry.className
      )
    end

    if normalized then
      normalizedSelections[normalized.key] = normalized
    end
  end

  load.savedLoadoutSelections = normalizedSelections
  return load.savedLoadoutSelections
end

local function EnsureSavedLoadoutCatalog()
  ns.session = ns.session or {}
  ns.session.savedLoadoutCatalog = ns.session.savedLoadoutCatalog or {}
  return ns.session.savedLoadoutCatalog
end

local function GetSavedLoadoutName(configID, fallbackName)
  local configInfo = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID) or nil
  local name = NormalizeText(configInfo and configInfo.name or fallbackName)
  if name ~= "" then
    return name
  end
  configID = tonumber(configID or 0) or 0
  return configID == -2 and "Starter Build" or ("Loadout " .. tostring(configID))
end

local function RefreshCurrentSavedLoadoutCatalog()
  if not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_Traits and C_Traits.GetConfigInfo) then
    return nil, "Saved layout APIs unavailable."
  end

  local specInfo = GetCurrentSpecInfo()
  if not specInfo.classToken or specInfo.classToken == "" or specInfo.specID <= 0 then
    return nil, "No active specialization."
  end

  local entries = {}
  local order = {}
  local function addEntry(configID, preferredName)
    local entry = CreateSavedLoadoutSelectionEntry(
      specInfo.classToken,
      specInfo.specID,
      configID,
      preferredName or GetSavedLoadoutName(configID),
      specInfo.specName,
      specInfo.className
    )
    if entry and not entries[entry.key] then
      entries[entry.key] = entry
      order[#order + 1] = entry.key
    end
  end

  for _, configID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specInfo.specID) or {}) do
    addEntry(configID)
  end

  local currentInfo = GetCurrentSavedLoadoutInfo()
  if currentInfo and currentInfo.classToken == specInfo.classToken and currentInfo.specID == specInfo.specID then
    addEntry(currentInfo.configID, currentInfo.name)
  end

  if #order == 0 then
    return nil, "No saved layouts found for the current specialization yet."
  end

  table.sort(order, function(leftKey, rightKey)
    local left = entries[leftKey]
    local right = entries[rightKey]
    if left.name == right.name then
      return left.configID < right.configID
    end
    return string.lower(left.name) < string.lower(right.name)
  end)

  local catalog = EnsureSavedLoadoutCatalog()
  catalog[specInfo.classToken] = catalog[specInfo.classToken] or {}
  catalog[specInfo.classToken][specInfo.specID] = {
    classToken = specInfo.classToken,
    className = specInfo.className,
    specID = specInfo.specID,
    specName = specInfo.specName,
    entries = entries,
    order = order,
  }

  return catalog[specInfo.classToken][specInfo.specID], nil
end

local function GetCurrentSavedLoadoutCatalog(load)
  local specInfo = GetCurrentSpecInfo()
  if not specInfo.classToken or specInfo.classToken == "" or specInfo.specID <= 0 then
    return nil, "No active specialization."
  end

  local catalog = EnsureSavedLoadoutCatalog()
  local base = catalog[specInfo.classToken] and catalog[specInfo.classToken][specInfo.specID] or nil
  local mergedEntries = {}
  local mergedOrder = {}
  local selectedLookup = EnsureSavedLoadoutSelections(load)

  if base and type(base.entries) == "table" then
    for _, key in ipairs(base.order or {}) do
      local entry = base.entries[key]
      if entry then
        entry.offSpec = false
        entry.fromSelectionList = false
        entry.missing = false
        mergedEntries[key] = entry
        mergedOrder[#mergedOrder + 1] = key
      end
    end
  end

  for key, entry in pairs(selectedLookup) do
    if type(entry) == "table" then
      if not mergedEntries[key] then
        local cloned = CreateSavedLoadoutSelectionEntry(
          entry.classToken,
          entry.specID,
          entry.configID,
          entry.name,
          entry.specName ~= "" and entry.specName or specInfo.specName,
          entry.className ~= "" and entry.className or specInfo.className
        )
        if cloned then
          cloned.offSpec = cloned.classToken ~= specInfo.classToken or tonumber(cloned.specID or 0) ~= specInfo.specID
          cloned.fromSelectionList = true
          cloned.missing = not cloned.offSpec
          mergedEntries[key] = cloned
          mergedOrder[#mergedOrder + 1] = key
        end
      end
    end
  end

  if #mergedOrder == 0 then
    return nil, "Refresh Layouts to load the current specialization's saved layouts."
  end

  local currentInfo = GetCurrentSavedLoadoutInfo()
  table.sort(mergedOrder, function(leftKey, rightKey)
    local left = mergedEntries[leftKey]
    local right = mergedEntries[rightKey]
    local leftCurrentSpec = left and left.classToken == specInfo.classToken and tonumber(left.specID or 0) == specInfo.specID or false
    local rightCurrentSpec = right and right.classToken == specInfo.classToken and tonumber(right.specID or 0) == specInfo.specID or false
    if leftCurrentSpec ~= rightCurrentSpec then
      return leftCurrentSpec
    end
    local leftCurrent = currentInfo and left
      and currentInfo.classToken == left.classToken
      and tonumber(currentInfo.specID or 0) == tonumber(left.specID or 0)
      and tonumber(currentInfo.configID or 0) == tonumber(left.configID or 0)
      or false
    local rightCurrent = currentInfo and right
      and currentInfo.classToken == right.classToken
      and tonumber(currentInfo.specID or 0) == tonumber(right.specID or 0)
      and tonumber(currentInfo.configID or 0) == tonumber(right.configID or 0)
      or false
    if leftCurrent ~= rightCurrent then
      return leftCurrent
    end
    local leftSelected = selectedLookup[leftKey] ~= nil
    local rightSelected = selectedLookup[rightKey] ~= nil
    if leftSelected ~= rightSelected then
      return leftSelected
    end
    if not leftCurrentSpec and not rightCurrentSpec then
      local leftClass = NormalizeText(left.className)
      local rightClass = NormalizeText(right.className)
      if leftClass ~= rightClass then
        return leftClass < rightClass
      end
      local leftSpec = NormalizeText(left.specName)
      local rightSpec = NormalizeText(right.specName)
      if leftSpec ~= rightSpec then
        return leftSpec < rightSpec
      end
    end
    if left.name == right.name then
      return left.configID < right.configID
    end
    return string.lower(left.name) < string.lower(right.name)
  end)

  return {
    classToken = specInfo.classToken,
    className = specInfo.className,
    specID = specInfo.specID,
    specName = specInfo.specName,
    entries = mergedEntries,
    order = mergedOrder,
  }, nil
end

local function GetSavedLoadoutSelectionEntries(load)
  local entries = {}
  for _, entry in pairs(EnsureSavedLoadoutSelections(load)) do
    if type(entry) == "table" then
      entries[#entries + 1] = entry
    end
  end
  table.sort(entries, function(left, right)
    local leftClass = NormalizeText(left.className)
    local rightClass = NormalizeText(right.className)
    if leftClass == rightClass then
      local leftSpec = NormalizeText(left.specName)
      local rightSpec = NormalizeText(right.specName)
      if leftSpec == rightSpec then
        return string.lower(left.name or "") < string.lower(right.name or "")
      end
      return leftSpec < rightSpec
    end
    return leftClass < rightClass
  end)
  return entries
end

local function GetSavedLoadoutGroupLabel(entry)
  local classLabel = NormalizeText(entry and entry.className)
  local specLabel = NormalizeText(entry and entry.specName)
  if classLabel ~= "" and specLabel ~= "" then
    return string.format("%s / %s", classLabel, specLabel)
  end
  if specLabel ~= "" then
    return specLabel
  end
  if classLabel ~= "" then
    return classLabel
  end
  return "Selected Layouts"
end

local function BuildSavedLoadoutHint(load)
  load = load or {}
  local mode = NormalizeSavedLoadoutMode(load.savedLoadoutMode)
  local selectedEntries = GetSavedLoadoutSelectionEntries(load)
  local currentInfo = GetCurrentSavedLoadoutInfo()
  local lines = {}

  if #selectedEntries == 0 then
    lines[#lines + 1] = "|cffaaaaaaNo filtered layouts selected. Refresh Layouts for the current spec, then choose one or more layouts.|r"
  else
    local grouped = {}
    local labels = {}
    for _, entry in ipairs(selectedEntries) do
      local groupLabel = GetSavedLoadoutGroupLabel(entry)
      if not grouped[groupLabel] then
        grouped[groupLabel] = {}
        labels[#labels + 1] = groupLabel
      end
      grouped[groupLabel][#grouped[groupLabel] + 1] = entry.name
    end
    table.sort(labels)
    lines[#lines + 1] = string.format("|cff88ff88%s Selected Layouts:|r %d", mode == "except" and "Except" or "Only", #selectedEntries)
    for _, groupLabel in ipairs(labels) do
      table.sort(grouped[groupLabel])
      local displayNames = {}
      for index, name in ipairs(grouped[groupLabel]) do
        if index <= 3 then
          displayNames[#displayNames + 1] = name
        end
      end
      if #grouped[groupLabel] > 3 then
        displayNames[#displayNames + 1] = string.format("+%d more", #grouped[groupLabel] - 3)
      end
      lines[#lines + 1] = string.format("|cff88ff88%s:|r %s", groupLabel, table.concat(displayNames, ", "))
    end
  end

  if currentInfo and currentInfo.name and currentInfo.name ~= "" then
    lines[#lines + 1] = string.format("|cffaaaaaaCurrent: %s|r", currentInfo.name)
  end

  return table.concat(lines, "\n")
end

local function SetDropdown(dropdown, value, label)
  UIDropDownMenu_SetSelectedValue(dropdown, value)
  UIDropDownMenu_SetText(dropdown, label or tostring(value or ""))
end

local GetRelevantTalentContext

local function CountEnabled(map, predicate)
  local count = 0
  if type(map) ~= "table" then
    return count
  end
  for key, enabled in pairs(map) do
    if enabled and (not predicate or predicate(key)) then
      count = count + 1
    end
  end
  return count
end

local function GetSingleEnabledKey(map, predicate)
  local match = nil
  if type(map) ~= "table" then
    return nil
  end
  for key, enabled in pairs(map) do
    if enabled and (not predicate or predicate(key)) then
      if match ~= nil then
        return nil
      end
      match = key
    end
  end
  return match
end

local function ParseSpecKey(specKey)
  local classToken, specIndex = tostring(specKey or ""):match("^([^:]+):(%d+)$")
  specIndex = tonumber(specIndex or 0) or 0
  if not classToken or classToken == "" or specIndex <= 0 then
    return nil, nil
  end
  return classToken, specIndex
end

local function PruneSpecSelections(load)
  load = load or {}
  load.classes = EnsureMap(load.classes)
  load.specs = EnsureMap(load.specs)

  local changed = false
  local restrictByClass = CountEnabled(load.classes) > 0
  for specKey, enabled in pairs(load.specs) do
    if enabled then
      local classToken, specIndex = ParseSpecKey(specKey)
      local classInfo = classToken and CLASS_SPECS[classToken] or nil
      local isValidSpec = classInfo and specIndex > 0 and specIndex <= #(classInfo.specs or {})
      if not isValidSpec or (restrictByClass and not load.classes[classToken]) then
        load.specs[specKey] = nil
        changed = true
      end
    end
  end
  return changed
end

local function ClearTalentSelections(load)
  if type(load) ~= "table" then
    return false
  end

  local talents = EnsureMap(load.talents)
  if next(talents) == nil then
    load.talents = talents
    return false
  end

  load.talents = {}
  return true
end

local function BuildTalentKeyLookup(groups)
  local lookup = {}
  for _, group in ipairs(groups or {}) do
    for _, item in ipairs(group.items or {}) do
      if item.key then
        lookup[item.key] = true
      end
    end
  end
  return lookup
end

local function PruneTalentSelections(load, groups)
  if type(load) ~= "table" or type(groups) ~= "table" or #groups == 0 then
    return false
  end

  load.talents = EnsureMap(load.talents)
  local available = BuildTalentKeyLookup(groups)
  local changed = false
  for talentKey, enabled in pairs(load.talents) do
    if enabled and not available[talentKey] then
      load.talents[talentKey] = nil
      changed = true
    end
  end
  return changed
end

local function ResolveEntryInfo(configID, entryID)
  if not (C_Traits and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then
    return nil
  end
  local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
  if not entryInfo or not entryInfo.definitionID then
    return nil
  end
  local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
  if not definitionInfo then
    return nil
  end

  local spellID = definitionInfo.spellID
  local icon = nil
  if spellID and spellID > 0 then
    if C_Spell and C_Spell.GetSpellTexture then
      icon = C_Spell.GetSpellTexture(spellID)
    elseif GetSpellTexture then
      icon = GetSpellTexture(spellID)
    end
  end
  return {
    spellID = spellID,
    name = definitionInfo.overrideName or (spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or "Unknown Talent",
    icon = icon,
  }
end

local function EnsureTalentCatalog()
  ns.session = ns.session or {}
  ns.session.talentCatalog = ns.session.talentCatalog or {}
  return ns.session.talentCatalog
end

local function BuildGroupsFromActiveContext(context)
  if not context or not context.configID or type(context.treeIDs) ~= "table" then
    return {}
  end

  local groups = {}
  for treeIndex, treeID in ipairs(context.treeIDs) do
    local treeInfo = C_Traits.GetTreeInfo and C_Traits.GetTreeInfo(context.configID, treeID) or nil
    local group = {
      label = treeInfo and treeInfo.name or (treeIndex == 1 and "Class Tree" or treeIndex == 2 and "Spec Tree" or "Hero Tree"),
      items = {},
    }

    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local nodeInfo = C_Traits.GetNodeInfo(context.configID, nodeID)
      if nodeInfo and nodeInfo.isVisible ~= false then
        local hasChoices = type(nodeInfo.entryIDs) == "table" and #nodeInfo.entryIDs > 1
        if hasChoices then
          for _, entryID in ipairs(nodeInfo.entryIDs) do
            local resolved = ResolveEntryInfo(context.configID, entryID)
            if resolved and resolved.spellID then
              group.items[#group.items + 1] = {
                key = string.format("%s:%s", tostring(nodeID), tostring(entryID)),
                label = resolved.name,
                icon = resolved.icon,
                sortY = nodeInfo.posY or 0,
                sortX = nodeInfo.posX or 0,
              }
            end
          end
        else
          local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or (nodeInfo.entryIDs and nodeInfo.entryIDs[1]) or nil
          local resolved = entryID and ResolveEntryInfo(context.configID, entryID) or nil
          if resolved and resolved.spellID then
            group.items[#group.items + 1] = {
              key = tostring(nodeID),
              label = resolved.name,
              icon = resolved.icon,
              sortY = nodeInfo.posY or 0,
              sortX = nodeInfo.posX or 0,
            }
          end
        end
      end
    end

    table.sort(group.items, function(left, right)
      if left.sortY == right.sortY then
        if left.sortX == right.sortX then
          return left.label < right.label
        end
        return left.sortX < right.sortX
      end
      return left.sortY < right.sortY
    end)

    if #group.items > 0 then
      groups[#groups + 1] = group
    end
  end

  return groups
end

local function CaptureActiveTalentCatalog()
  local currentClass = GetPlayerClassToken()
  local currentSpec = GetPlayerSpecIndex()
  local context, reason = GetRelevantTalentContext({
    classes = { [currentClass] = true },
    specs = { [string.format("%s:%d", currentClass or "", currentSpec or 0)] = true },
  })
  if not context then
    return nil, reason
  end

  local groups = BuildGroupsFromActiveContext(context)
  if #groups == 0 then
    return nil, "No active talents available."
  end

  local catalog = EnsureTalentCatalog()
  local classCatalog = catalog[currentClass] or { specs = {} }
  classCatalog.classTree = groups[1] or nil
  classCatalog.specs = classCatalog.specs or {}
  classCatalog.specs[currentSpec] = {
    groups = groups,
  }
  catalog[currentClass] = classCatalog
  return groups
end

GetRelevantTalentContext = function(load)
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo) then
    return nil, "Talent APIs unavailable."
  end

  local currentClass = GetPlayerClassToken()
  local configID = C_ClassTalents.GetActiveConfigID()
  if not currentClass or not configID then
    return nil, "No active talent configuration."
  end

  local configInfo = C_Traits.GetConfigInfo(configID)
  if not configInfo or type(configInfo.treeIDs) ~= "table" or #configInfo.treeIDs == 0 then
    return nil, "No talent trees found."
  end

  local selectedClasses = EnsureMap(load and load.classes)
  if CountEnabled(selectedClasses) > 0 and not selectedClasses[currentClass] then
    return nil, "Talent picker currently works for the active player class."
  end

  local currentSpec = GetPlayerSpecIndex()
  local selectedSpecs = EnsureMap(load and load.specs)
  local specCountForClass = CountEnabled(selectedSpecs, function(key)
    return tostring(key):match("^" .. currentClass .. ":")
  end)
  local currentSpecSelected = selectedSpecs[string.format("%s:%d", currentClass, currentSpec)] == true

  local treeIDs = {}
  if specCountForClass == 1 and currentSpecSelected then
    for _, treeID in ipairs(configInfo.treeIDs) do
      treeIDs[#treeIDs + 1] = treeID
    end
  else
    treeIDs[1] = configInfo.treeIDs[1]
  end

  return {
    configID = configID,
    treeIDs = treeIDs,
  }
end

local function BuildTalentOptions(load)
  local selectedClasses = EnsureMap(load and load.classes)
  local classToken = GetSingleEnabledKey(selectedClasses)
  if not classToken then
    return nil, "Select exactly one class to choose talents."
  end

  local currentClass = GetPlayerClassToken()
  if classToken == currentClass then
    CaptureActiveTalentCatalog()
  end

  local catalog = EnsureTalentCatalog()
  local classCatalog = catalog[classToken]
  if not classCatalog then
    return nil, "No talent tree data for that class is cached this session yet. Log onto that class once to populate it."
  end

  local selectedSpecs = EnsureMap(load and load.specs)
  local specKey = GetSingleEnabledKey(selectedSpecs, function(key)
    return tostring(key):match("^" .. classToken .. ":")
  end)

  if specKey then
    local specIndex = tonumber(tostring(specKey):match(":(%d+)$") or "") or 0
    local specCatalog = classCatalog.specs and classCatalog.specs[specIndex] or nil
    if specCatalog and type(specCatalog.groups) == "table" and #specCatalog.groups > 0 then
      return specCatalog.groups, nil
    end
    return nil, "No spec talent tree data for that spec is cached this session yet. Log onto that spec once to populate it."
  end

  if classCatalog.classTree then
    return { classCatalog.classTree }, nil
  end

  return nil, "No class talent tree data for that class is cached this session yet."
end

local function GetOrderedUniquePositions(items, field)
  local seen = {}
  local values = {}
  for _, item in ipairs(items or {}) do
    local value = tonumber(item[field] or 0) or 0
    if not seen[value] then
      seen[value] = true
      values[#values + 1] = value
    end
  end
  table.sort(values)
  return values
end

local function HideTalentListWidgets(frame)
  for _, header in ipairs(frame.talentHeaders or {}) do
    header:Hide()
  end
  for _, row in ipairs(frame.talentRows or {}) do
    row:Hide()
  end
end

local function BuildTalentListEntries(groups, query)
  local entries = {}
  local needle = tostring(query or ""):lower()
  for _, group in ipairs(groups or {}) do
    local groupEntries = {}
    for _, item in ipairs(group.items or {}) do
      local label = tostring(item.label or "")
      if needle == "" or label:lower():find(needle, 1, true) then
        groupEntries[#groupEntries + 1] = item
      end
    end
    if #groupEntries > 0 then
      entries[#entries + 1] = {
        label = group.label,
        items = groupEntries,
      }
    end
  end
  return entries
end

local function GetSelectedTalentNames(groups, load)
  local names = {}
  local seen = {}
  load = load or {}
  for _, group in ipairs(groups or {}) do
    for _, item in ipairs(group.items or {}) do
      if load.talents and load.talents[item.key] == true then
        local label = tostring(item.label or "")
        if label ~= "" and not seen[label] then
          seen[label] = true
          names[#names + 1] = label
        end
      end
    end
  end
  table.sort(names)
  return names
end

local function RenderTalentList(frame, parent, groups, load, query, onChanged, showHeaders)
  frame.talentHeaders = frame.talentHeaders or {}
  frame.talentRows = frame.talentRows or {}
  HideTalentListWidgets(frame)

  local entries = BuildTalentListEntries(groups, query)
  local anchor = parent
  local contentHeight = 0
  local headerIndex = 0
  local rowIndex = 0

  for _, group in ipairs(entries) do
    if showHeaders ~= false then
      headerIndex = headerIndex + 1
      local header = frame.talentHeaders[headerIndex]
      if not header then
        header = Frames.CreateLabel(parent, "", "GameFontNormal")
        frame.talentHeaders[headerIndex] = header
      else
        header:SetParent(parent)
      end
      header:SetText(group.label)
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", anchor, anchor == parent and "TOPLEFT" or "BOTTOMLEFT", 0, anchor == parent and 0 or -12)
      header:Show()
      anchor = header
      contentHeight = contentHeight + 24
    end

    for _, item in ipairs(group.items) do
      rowIndex = rowIndex + 1
      local row = frame.talentRows[rowIndex]
      if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetSize(640, 24)
        row.check = Frames.CreateCheckbox(row, "")
        row.check:SetPoint("LEFT", 0, 0)
        if row.check.Text then
          row.check.Text:SetText("")
          row.check.Text:Hide()
        end
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.label:SetJustifyH("LEFT")
        row:SetScript("OnEnter", function(selfRow)
          GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
          GameTooltip:SetText(selfRow.itemLabel or "Talent")
          GameTooltip:AddLine("Click to require or clear this talent for the load condition.", 0.8, 0.8, 0.8, true)
          GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
          GameTooltip:Hide()
        end)
        row.check:SetScript("OnEnter", row:GetScript("OnEnter"))
        row.check:SetScript("OnLeave", row:GetScript("OnLeave"))
        frame.talentRows[rowIndex] = row
      else
        row:SetParent(parent)
      end

      row.itemKey = item.key
      row.itemLabel = item.label
      row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.label:SetText(item.label or "Unknown Talent")
      row.check:SetChecked(load.talents[item.key] == true)
      row:ClearAllPoints()
      if anchor == parent then
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
      else
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
      end
      row.check:SetScript("OnClick", function(selfCheck)
        local owner = selfCheck:GetParent()
        load.talents[owner.itemKey] = selfCheck:GetChecked() == true or nil
        if onChanged then
          onChanged()
        end
      end)
      row:Show()
      anchor = row
      contentHeight = contentHeight + 30
    end
  end

  return entries, contentHeight
end

local function HideSavedLoadoutRows(frame)
  for _, row in ipairs(frame.savedLoadoutRows or {}) do
    row:Hide()
  end
end

local function BuildSavedLoadoutListEntries(specCatalog, query)
  local entries = {}
  local needle = string.lower(tostring(query or ""))
  if not specCatalog or type(specCatalog.entries) ~= "table" then
    return entries
  end

  for _, key in ipairs(specCatalog.order or {}) do
    local entry = specCatalog.entries[key]
    local label = entry and tostring(entry.name or "") or ""
    local haystack = string.lower(table.concat({
      label,
      tostring(entry and entry.specName or ""),
      tostring(entry and entry.className or ""),
    }, " "))
    if entry and (needle == "" or haystack:find(needle, 1, true)) then
      entries[#entries + 1] = entry
    end
  end

  return entries
end

local function RenderSavedLoadoutList(frame, parent, specCatalog, load, query, onChanged)
  frame.savedLoadoutRows = frame.savedLoadoutRows or {}
  HideSavedLoadoutRows(frame)

  local entries = BuildSavedLoadoutListEntries(specCatalog, query)
  local currentInfo = GetCurrentSavedLoadoutInfo()
  local anchor = parent
  local contentHeight = 0

  for index, entry in ipairs(entries) do
    local row = frame.savedLoadoutRows[index]
    if not row then
      row = CreateFrame("Frame", nil, parent)
      row:SetSize(660, 24)
      row.check = Frames.CreateCheckbox(row, "")
      row.check:SetPoint("LEFT", 0, 0)
      if row.check.Text then
        row.check.Text:SetText("")
        row.check.Text:Hide()
      end
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.label:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
      row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
      row.label:SetJustifyH("LEFT")
      row:SetScript("OnEnter", function(selfRow)
        GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
        GameTooltip:SetText(selfRow.entryName or "Layout")
        GameTooltip:AddLine(string.format("Config ID: %s", tostring(selfRow.entryConfigID or "?")), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Check to include this layout in the filter set for this aura.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Selections match by layout name within this class and spec, so the same named layout can stay shared across characters.", 0.8, 0.8, 0.8, true)
        if selfRow.entryOffSpec then
          GameTooltip:AddLine("This layout came from the aura's saved selection list for another class or spec, and stays here until you remove it.", 0.8, 0.8, 0.8, true)
        elseif selfRow.entryMissing then
          GameTooltip:AddLine("This saved selection is not in the current refreshed list, but it remains preserved until you remove it.", 1, 0.4, 0.4, true)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
      row.check:SetScript("OnEnter", row:GetScript("OnEnter"))
      row.check:SetScript("OnLeave", row:GetScript("OnLeave"))
      frame.savedLoadoutRows[index] = row
    else
      row:SetParent(parent)
    end

    row.entryKey = entry.key
    row.entryName = entry.name
    row.entryConfigID = entry.configID
    row.entryClassToken = entry.classToken
    row.entryClassName = entry.className
    row.entrySpecID = entry.specID
    row.entrySpecName = entry.specName
    row.entryMissing = entry.missing == true
    row.entryOffSpec = entry.offSpec == true
    local isCurrent = currentInfo
      and currentInfo.classToken == entry.classToken
      and tonumber(currentInfo.specID or 0) == tonumber(entry.specID or 0)
      and tonumber(currentInfo.configID or 0) == tonumber(entry.configID or 0)

    local label = tostring(entry.name or "Unknown Layout")
    if entry.offSpec == true then
      label = string.format("%s: %s", GetSavedLoadoutGroupLabel(entry), label)
    end
    if isCurrent then
      label = label .. " |cffaaaaaa(Current)|r"
    end
    if entry.missing == true then
      label = label .. " |cffff8888(Missing)|r"
    elseif entry.offSpec == true then
      label = label .. " |cffaaaaaa(Selected)|r"
    end

    row.label:SetText(label)
    row.check:SetChecked(EnsureSavedLoadoutSelections(load)[entry.key] ~= nil)
    row:ClearAllPoints()
    if anchor == parent then
      row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    else
      row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    end
    row.check:SetScript("OnClick", function(selfCheck)
      local owner = selfCheck:GetParent()
      local liveSelections = EnsureSavedLoadoutSelections(load)
      if selfCheck:GetChecked() == true then
        liveSelections[owner.entryKey] = CreateSavedLoadoutSelectionEntry(
          owner.entryClassToken,
          owner.entrySpecID,
          owner.entryConfigID,
          owner.entryName,
          owner.entrySpecName,
          owner.entryClassName
        )
        if tostring(load.savedLoadoutMode or "") == "any" then
          load.savedLoadoutMode = "only"
        end
      else
        liveSelections[owner.entryKey] = nil
      end
      if onChanged then
        onChanged()
      end
    end)
    row:Show()
    anchor = row
    contentHeight = contentHeight + 30
  end

  return entries, contentHeight
end

function Panel:ApplyCurrent()
  if self.suppressUpdates then
    return
  end
  local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
  if not aura then
    return
  end
  aura.load.classes = aura.load.classes or {}
  aura.load.specs = aura.load.specs or {}
  aura.load.talents = aura.load.talents or {}
  aura.load.visibility = aura.load.visibility or {}
  aura.load.savedLoadoutSelections = EnsureSavedLoadoutSelections(aura.load)
  aura.load.savedLoadoutMode = NormalizeSavedLoadoutMode(aura.load.savedLoadoutMode)
  aura.enabled = self.frame.enabledCheck:GetChecked() == true
  aura.load.combat = UIDropDownMenu_GetSelectedValue(self.frame.combatDropDown) or "any"
  for classToken, check in pairs(self.frame.classChecks) do
    aura.load.classes[classToken] = check:GetChecked() == true or nil
  end
  PruneSpecSelections(aura.load)
  for key, check in pairs(self.frame.visibilityChecks or {}) do
    aura.load.visibility[key] = check:GetChecked() == true
  end
  aura.load.talent = self.frame.talentEnabledCheck:GetChecked() == true
  aura.load.savedLoadoutMode = NormalizeSavedLoadoutMode(
    UIDropDownMenu_GetSelectedValue(self.frame.savedLoadoutModeDropDown) or aura.load.savedLoadoutMode
  )
  aura.load.level = math.max(0, math.floor((tonumber(self.frame.levelInput:GetText()) or 0) + 0.5))
  aura.load.instanceType = UIDropDownMenu_GetSelectedValue(self.frame.instanceTypeDropDown) or ""
  aura.load.instanceId = math.max(0, math.floor((tonumber(self.frame.instanceIdInput:GetText()) or 0) + 0.5))
  aura.load.encounterId = math.max(0, math.floor((tonumber(self.frame.encounterIdInput:GetText()) or 0) + 0.5))
  local equippedItemId, equippedItemName = ResolveItemFilterInput(self.frame.equippedItemInput:GetText())
  aura.load.equippedItemId = equippedItemId or 0
  aura.load.equippedItemName = equippedItemName or ""
  if aura.load.talent == true then
    local groups = BuildTalentOptions(aura.load)
    PruneTalentSelections(aura.load, groups)
  end
  self.frame.levelInput:SetText(aura.load.level > 0 and tostring(aura.load.level) or "")
  self.frame.instanceIdInput:SetText(aura.load.instanceId > 0 and tostring(aura.load.instanceId) or "")
  self.frame.encounterIdInput:SetText(aura.load.encounterId > 0 and tostring(aura.load.encounterId) or "")
  self.frame.equippedItemInput:SetText(aura.load.equippedItemId > 0 and tostring(aura.load.equippedItemId) or aura.load.equippedItemName or "")
  self.frame.equippedItemResolved:SetText(GetEquippedItemResolvedText(aura.load.equippedItemId, aura.load.equippedItemName))
  self.frame.savedLoadoutHint:SetText(BuildSavedLoadoutHint(aura.load))
  ns.runtime:RefreshAura(aura.id)
end

function Panel:RefreshSpecSection(aura)
  local load = aura.load or {}
  load.classes = EnsureMap(load.classes)
  load.specs = EnsureMap(load.specs)
  load.talents = EnsureMap(load.talents)
  load.savedLoadoutSelections = EnsureSavedLoadoutSelections(load)
  load.savedLoadoutMode = NormalizeSavedLoadoutMode(load.savedLoadoutMode)
  PruneSpecSelections(load)

  local hasClasses = false
  local classCollapsed = self.frame.collapsedSections and self.frame.collapsedSections.class == true

  for _, specCheck in ipairs(self.frame.specChecks or {}) do
    specCheck:Hide()
  end
  self.frame.specChecks = self.frame.specChecks or {}

  self.frame.classHeader:ClearAllPoints()
  self.frame.classHeader:SetPoint("TOPLEFT", self.frame.combatDropDown, "BOTTOMLEFT", 14, -18)
  self.frame.classHeader:SetText("Class Filter")
  self.frame.classToggle:ClearAllPoints()
  self.frame.classToggle:SetPoint("LEFT", self.frame.classHeader, "RIGHT", 8, 0)
  self.frame.classToggle:Show()
  SetCollapseButtonText(self.frame.classToggle, classCollapsed)

  self.frame.classSection:ClearAllPoints()
  self.frame.classSection:SetPoint("TOPLEFT", self.frame.classHeader, "BOTTOMLEFT", 0, -8)

  local classRowCount = math.ceil(#CLASS_ORDER / 2)
  self.frame.classSection:SetHeight(classCollapsed and 0 or (classRowCount * 24))
  for index, classToken in ipairs(CLASS_ORDER) do
    local check = self.frame.classChecks[classToken]
    if check then
      local row = math.floor((index - 1) / 2)
      local column = (index - 1) % 2
      check:ClearAllPoints()
      check:SetPoint("TOPLEFT", self.frame.classSection, "TOPLEFT", column * 220, -(row * 24))
      check:SetShown(not classCollapsed)
    end
  end

  local bottomAnchor = classCollapsed and self.frame.classHeader or self.frame.classSection

  local specIndex = 0
  for _, classToken in ipairs(CLASS_ORDER) do
    if load.classes[classToken] then
      hasClasses = true
      local info = CLASS_SPECS[classToken]
      for si, specName in ipairs(info.specs) do
        specIndex = specIndex + 1
        local check = self.frame.specChecks[specIndex]
        if not check then
          check = Frames.CreateCheckbox(self.frame.content, "")
          self.frame.specChecks[specIndex] = check
        end
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", self.frame.specHeader, "BOTTOMLEFT", 0, -8 - ((specIndex - 1) * 24))
        local key = classToken .. ":" .. si
        check.Text:SetText(string.format("%s: %s", info.className, specName))
        check:SetChecked(load.specs[key] == true)
        check:SetScript("OnClick", function(selfCheck)
          load.specs[key] = selfCheck:GetChecked() == true or nil
          ClearTalentSelections(load)
          Panel:RefreshSpecSection(aura)
          Panel:ApplyCurrent()
        end)
        check:SetShown(not classCollapsed)
      end
    end
  end

  self.frame.specHeader:ClearAllPoints()
  if hasClasses and not classCollapsed then
    self.frame.specHeader:SetPoint("TOPLEFT", self.frame.classSection, "BOTTOMLEFT", 0, -12)
    self.frame.specHeader:SetText("Specializations")
    self.frame.specHeader:Show()
    self.frame.specToggle:Hide()
    bottomAnchor = self.frame.specChecks[specIndex] or self.frame.specHeader
  else
    self.frame.specHeader:Hide()
    self.frame.specToggle:Hide()
  end

  self.frame.talentHeader:ClearAllPoints()
  self.frame.talentEnabledCheck:ClearAllPoints()
  if hasClasses and not classCollapsed then
    self.frame.talentHeader:SetPoint("TOPLEFT", bottomAnchor, "BOTTOMLEFT", 0, -12)
    self.frame.talentHeader:SetText("Talents")
    self.frame.talentHeader:Show()
    self.frame.talentEnabledCheck:SetPoint("TOPLEFT", self.frame.talentHeader, "BOTTOMLEFT", 0, -8)
    self.frame.talentEnabledCheck:Show()
  else
    self.frame.talentHeader:Hide()
    self.frame.talentEnabledCheck:Hide()
  end

  self:RefreshTalentSection(aura, bottomAnchor)
end

function Panel:RefreshTalentSection(aura, topAnchor)
  local load = aura.load or {}
  load.talents = EnsureMap(load.talents)
  load.savedLoadoutSelections = EnsureSavedLoadoutSelections(load)
  load.savedLoadoutMode = NormalizeSavedLoadoutMode(load.savedLoadoutMode)
  local classCollapsed = self.frame.collapsedSections and self.frame.collapsedSections.class == true
  local hasClasses = CountEnabled(EnsureMap(load.classes)) > 0

  HideTalentListWidgets(self.frame)

  local classBottomAnchor = topAnchor
  local talentContentHeight = 0
  local savedLoadoutContentHeight = 0

  if hasClasses and not classCollapsed then
    self.frame.talentEnabledCheck:SetChecked(load.talent == true)
    self.frame.talentPickerButton:ClearAllPoints()
    self.frame.talentPickerButton:SetPoint("TOPLEFT", self.frame.talentEnabledCheck, "BOTTOMLEFT", 26, -6)

    local talentAnchor = self.frame.talentEnabledCheck

    if load.talent == true then
      local groups, reason = BuildTalentOptions(load)
      self.frame.talentHint:ClearAllPoints()
      self.frame.talentHint:SetPoint("TOPLEFT", talentAnchor, "BOTTOMLEFT", 0, -10)
      if not groups or #groups == 0 then
        self.frame.talentHint:SetText("|cffaaaaaa" .. tostring(reason or "No talent options available.") .. "|r")
        self.frame.talentHint:Show()
        self.frame.talentPickerButton:Hide()
        talentAnchor = self.frame.talentHint
        talentContentHeight = 34
      else
        local selectedNames = GetSelectedTalentNames(groups, load)
        local summaryText = #selectedNames > 0 and table.concat(selectedNames, ", ") or "No talents selected."
        self.frame.talentHint:SetText(string.format("|cffaaaaaa%s|r", summaryText))
        self.frame.talentHint:Show()
        self.frame.talentPickerButton:Show()
        self.frame.talentPickerButton:SetText("Choose Talents")
        self.frame.talentPickerButton:SetScript("OnClick", function()
          Panel:ShowTalentPicker(aura, groups)
        end)
        talentAnchor = self.frame.talentPickerButton
        self.frame.talentHint:ClearAllPoints()
        self.frame.talentHint:SetPoint("TOPLEFT", self.frame.talentPickerButton, "BOTTOMLEFT", 0, -8)
        talentContentHeight = 56
      end
    else
      self.frame.talentHint:Hide()
      self.frame.talentPickerButton:Hide()
    end
    classBottomAnchor = self.frame.talentHint:IsShown() and self.frame.talentHint or self.frame.talentEnabledCheck
  else
    self.frame.talentHint:Hide()
    self.frame.talentPickerButton:Hide()
  end

  self.frame.savedLoadoutHeader:ClearAllPoints()
  self.frame.savedLoadoutHeader:SetPoint("TOPLEFT", classBottomAnchor, "BOTTOMLEFT", 0, -18)
  self.frame.savedLoadoutHeader:Show()
  self.frame.savedLoadoutModeLabel:ClearAllPoints()
  self.frame.savedLoadoutModeLabel:SetPoint("TOPLEFT", self.frame.savedLoadoutHeader, "BOTTOMLEFT", 0, -8)
  self.frame.savedLoadoutModeLabel:Show()
  self.frame.savedLoadoutModeDropDown:ClearAllPoints()
  self.frame.savedLoadoutModeDropDown:SetPoint("TOPLEFT", self.frame.savedLoadoutModeLabel, "BOTTOMLEFT", -14, -4)
  self.frame.savedLoadoutModeDropDown:Show()
  self.frame.savedLoadoutCaptureButton:ClearAllPoints()
  self.frame.savedLoadoutCaptureButton:SetPoint("TOPLEFT", self.frame.savedLoadoutModeDropDown, "TOPRIGHT", 26, 0)
  self.frame.savedLoadoutCaptureButton:Show()
  self.frame.savedLoadoutPickerButton:ClearAllPoints()
  self.frame.savedLoadoutPickerButton:SetPoint("TOPLEFT", self.frame.savedLoadoutModeDropDown, "BOTTOMLEFT", 14, -12)
  self.frame.savedLoadoutPickerButton:Show()
  self.frame.savedLoadoutHint:ClearAllPoints()
  self.frame.savedLoadoutHint:SetPoint("TOPLEFT", self.frame.savedLoadoutPickerButton, "BOTTOMLEFT", -14, -10)
  self.frame.savedLoadoutHint:SetText(BuildSavedLoadoutHint(load))
  self.frame.savedLoadoutHint:Show()
  SetDropdown(self.frame.savedLoadoutModeDropDown, load.savedLoadoutMode, GetSavedLoadoutModeLabel(load.savedLoadoutMode))
  classBottomAnchor = self.frame.savedLoadoutHint
  savedLoadoutContentHeight = 126

  self.frame.visibilityHeader:ClearAllPoints()
  self.frame.visibilityHeader:SetPoint("TOPLEFT", classBottomAnchor, "BOTTOMLEFT", 0, -24)
  self.frame.visibilitySection:ClearAllPoints()
  self.frame.visibilitySection:SetPoint("TOPLEFT", self.frame.visibilityHeader, "BOTTOMLEFT", 0, -8)

  local visibilityIndex = 0
  for _, entry in ipairs(VISIBILITY_OPTIONS) do
    local check = self.frame.visibilityChecks and self.frame.visibilityChecks[entry.key] or nil
    if check then
      local row = math.floor(visibilityIndex / 3)
      local column = visibilityIndex % 3
      check:ClearAllPoints()
      check:SetPoint("TOPLEFT", self.frame.visibilitySection, "TOPLEFT", column * 180, -(row * 24))
      visibilityIndex = visibilityIndex + 1
    end
  end

  self.frame.levelLabel:ClearAllPoints()
  self.frame.levelLabel:SetPoint("TOPLEFT", self.frame.visibilitySection, "BOTTOMLEFT", 0, -20)
  self.frame.levelInput:ClearAllPoints()
  self.frame.levelInput:SetPoint("TOPLEFT", self.frame.levelLabel, "BOTTOMLEFT", 0, -6)

  self.frame.instanceTypeLabel:ClearAllPoints()
  self.frame.instanceTypeLabel:SetPoint("TOPLEFT", self.frame.visibilitySection, "BOTTOMLEFT", 110, -20)
  self.frame.instanceTypeDropDown:ClearAllPoints()
  self.frame.instanceTypeDropDown:SetPoint("TOPLEFT", self.frame.instanceTypeLabel, "BOTTOMLEFT", -14, -4)

  self.frame.instanceIdLabel:ClearAllPoints()
  self.frame.instanceIdLabel:SetPoint("TOPLEFT", self.frame.visibilitySection, "BOTTOMLEFT", 326, -20)
  self.frame.instanceIdInput:ClearAllPoints()
  self.frame.instanceIdInput:SetPoint("TOPLEFT", self.frame.instanceIdLabel, "BOTTOMLEFT", 0, -6)

  self.frame.encounterIdLabel:ClearAllPoints()
  self.frame.encounterIdLabel:SetPoint("TOPLEFT", self.frame.visibilitySection, "BOTTOMLEFT", 438, -20)
  self.frame.encounterIdInput:ClearAllPoints()
  self.frame.encounterIdInput:SetPoint("TOPLEFT", self.frame.encounterIdLabel, "BOTTOMLEFT", 0, -6)

  self.frame.equippedItemLabel:ClearAllPoints()
  self.frame.equippedItemLabel:SetPoint("TOPLEFT", self.frame.levelInput, "BOTTOMLEFT", 0, -18)
  self.frame.equippedItemInput:ClearAllPoints()
  self.frame.equippedItemInput:SetPoint("TOPLEFT", self.frame.equippedItemLabel, "BOTTOMLEFT", 0, -6)
  self.frame.equippedItemResolved:ClearAllPoints()
  self.frame.equippedItemResolved:SetPoint("TOPLEFT", self.frame.equippedItemInput, "BOTTOMLEFT", 0, -6)

  self.frame.saveButton:ClearAllPoints()
  self.frame.saveButton:SetPoint("TOPLEFT", self.frame.equippedItemResolved, "BOTTOMLEFT", 0, -18)

  local selectedSpecCount = 0
  for _, classToken in ipairs(CLASS_ORDER) do
    if load.classes[classToken] then
      selectedSpecCount = selectedSpecCount + #(CLASS_SPECS[classToken].specs or {})
    end
  end
  local classHeight = classCollapsed and 0 or (math.ceil(#CLASS_ORDER / 2) * 24)
  local specHeight = classCollapsed and 0 or (selectedSpecCount * 24)
  local featureNoticeHeight = self.frame.featureDisabledNotice:IsShown() and 72 or 0
  self.frame.content:SetHeight(math.max(980 + featureNoticeHeight,
    640 + classHeight + specHeight + talentContentHeight + savedLoadoutContentHeight + featureNoticeHeight))
end

function Panel:ShowTalentPicker(aura, groups)
  local frame = self.frame
  if not frame or not frame.talentModal then
    return
  end

  local modal = frame.talentModal
  modal.title:SetText(string.format("Talent Picker: %s", tostring(aura and aura.name or "Aura")))
  modal:Show()

  local load = aura and aura.load or {}
  load.talents = EnsureMap(load.talents)
  modal.hint:SetText("")

  local function refreshList()
    local query = modal.searchInput:GetText()
    local entries, contentHeight = RenderTalentList(modal, modal.content, groups, load, query, function()
      Panel:RefreshSpecSection(aura)
      Panel:ApplyCurrent()
    end, false)
    if #entries == 0 then
      modal.emptyText:SetText("|cffaaaaaaNo talents match that search.|r")
      modal.emptyText:Show()
    else
      modal.emptyText:Hide()
    end
    modal.content:SetSize(700, math.max(420, contentHeight + 20))
  end

  modal.searchInput:SetScript("OnTextChanged", function()
    refreshList()
  end)
  modal.searchInput:SetScript("OnEscapePressed", function(selfInput)
    selfInput:ClearFocus()
  end)
  refreshList()
end

function Panel:ShowSavedLoadoutPicker(aura)
  local frame = self.frame
  if not frame or not frame.savedLoadoutModal or not aura then
    return
  end

  aura.load = aura.load or {}
  local specCatalog, reason = GetCurrentSavedLoadoutCatalog(aura.load)
  if not specCatalog then
    specCatalog, reason = RefreshCurrentSavedLoadoutCatalog()
  end
  if not specCatalog then
    self.frame.savedLoadoutHint:SetText(string.format("|cffff8888%s|r", tostring(reason or "No saved layouts available.")))
    return
  end

  local modal = frame.savedLoadoutModal
  modal.title:SetText(string.format("Layout Picker: %s", tostring(aura.name or "Aura")))
  modal.hint:SetText(string.format(
    "|cffaaaaaa%s / %s|r\nRefresh Layouts for the current spec to load its available choices. Already selected layouts from other characters or specs stay appended below so you can keep or remove them. Matching is based on layout name within the class and spec.",
    tostring(specCatalog.className or "Class"),
    tostring(specCatalog.specName or "Spec")
  ))
  modal.searchInput:SetText("")
  modal:Show()

  local load = aura.load
  EnsureSavedLoadoutSelections(load)

  local function refreshList()
    local query = modal.searchInput:GetText()
    local activeCatalog, activeReason = GetCurrentSavedLoadoutCatalog(load)
    if not activeCatalog then
      modal.emptyText:SetText("|cffaaaaaa" .. tostring(activeReason or "No saved layouts available.") .. "|r")
      modal.emptyText:Show()
      HideSavedLoadoutRows(modal)
      modal.content:SetSize(700, 420)
      return
    end

    local entries, contentHeight = RenderSavedLoadoutList(modal, modal.content, activeCatalog, load, query, function()
      Panel:RefreshSpecSection(aura)
      Panel:ApplyCurrent()
    end)
    if #entries == 0 then
      modal.emptyText:SetText("|cffaaaaaaNo layouts match that search.|r")
      modal.emptyText:Show()
    else
      modal.emptyText:Hide()
    end
    modal.content:SetSize(700, math.max(420, contentHeight + 20))
  end

  modal.searchInput:SetScript("OnTextChanged", function()
    refreshList()
  end)
  modal.searchInput:SetScript("OnEscapePressed", function(selfInput)
    selfInput:ClearFocus()
  end)
  refreshList()
end

function Panel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()
  frame.collapsedSections = frame.collapsedSections or {}
  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 0, 0)
  frame.scroll:SetPoint("BOTTOMRIGHT", -28, 0)
  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(760, 900)
  frame.scroll:SetScrollChild(frame.content)

  frame.featureDisabledNotice = CreateFrame("Frame", nil, frame.content, "BackdropTemplate")
  frame.featureDisabledNotice:SetPoint("TOPLEFT", 16, -16)
  frame.featureDisabledNotice:SetSize(700, 58)
  frame.featureDisabledNotice:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.featureDisabledNotice:SetBackdropColor(0.22, 0.12, 0.03, 0.96)
  frame.featureDisabledNotice:SetBackdropBorderColor(0.95, 0.58, 0.12, 1)
  frame.featureDisabledNotice.text = Frames.CreateLabel(
    frame.featureDisabledNotice, "", "GameFontHighlightSmall")
  frame.featureDisabledNotice.text:SetPoint("TOPLEFT", 12, -9)
  frame.featureDisabledNotice.text:SetPoint("BOTTOMRIGHT", -12, 9)
  frame.featureDisabledNotice.text:SetJustifyH("LEFT")
  frame.featureDisabledNotice.text:SetJustifyV("MIDDLE")
  frame.featureDisabledNotice:Hide()

  frame.alwaysHeader = Frames.CreateLabel(frame.content, "Always / Never", "GameFontNormal")
  frame.alwaysHeader:SetPoint("TOPLEFT", 16, -20)
  frame.enabledCheck = Frames.CreateCheckbox(frame.content, "Load this aura")
  frame.enabledCheck:SetPoint("TOPLEFT", frame.alwaysHeader, "BOTTOMLEFT", 0, -8)

  frame.combatHeader = Frames.CreateLabel(frame.content, "Combat", "GameFontNormal")
  frame.combatHeader:SetPoint("TOPLEFT", frame.enabledCheck, "BOTTOMLEFT", 0, -18)
  frame.combatDropDown = Frames.CreateDropdown(frame.content, 180, function(self, level)
    for _, value in ipairs({ "any", "in", "out" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = CombatModeLabel(value)
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.combatDropDown, value)
        UIDropDownMenu_SetText(frame.combatDropDown, CombatModeLabel(value))
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.combatDropDown:SetPoint("TOPLEFT", frame.combatHeader, "BOTTOMLEFT", -14, -4)

  frame.classHeader = Frames.CreateLabel(frame.content, "By Class", "GameFontNormal")
  frame.classHeader:SetPoint("TOPLEFT", frame.combatDropDown, "BOTTOMLEFT", 14, -18)
  frame.classToggle = Frames.CreateButton(frame.content, "v", 22, 20, function()
    frame.collapsedSections.class = not frame.collapsedSections.class
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if aura then
      Panel:RefreshSpecSection(aura)
    end
  end)
  Frames.StyleSecondaryButton(frame.classToggle)
  frame.classSection = CreateFrame("Frame", nil, frame.content)
  frame.classSection:SetPoint("TOPLEFT", frame.classHeader, "BOTTOMLEFT", 0, -8)
  frame.classSection:SetSize(520, 180)
  frame.classChecks = {}

  for index, classToken in ipairs(CLASS_ORDER) do
    local classInfo = CLASS_SPECS[classToken]
    local check = Frames.CreateCheckbox(frame.classSection, classInfo.className)
    local row = math.floor((index - 1) / 2)
    local column = (index - 1) % 2
    check:SetPoint("TOPLEFT", column * 220, -(row * 24))
    frame.classChecks[classToken] = check
  end

  frame.specHeader = Frames.CreateLabel(frame.content, "", "GameFontNormal")
  frame.specToggle = Frames.CreateButton(frame.content, "v", 22, 20, function()
    frame.collapsedSections.spec = not frame.collapsedSections.spec
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if aura then
      Panel:RefreshSpecSection(aura)
    end
  end)
  Frames.StyleSecondaryButton(frame.specToggle)
  frame.specToggle:Hide()
  frame.specChecks = {}

  frame.talentHeader = Frames.CreateLabel(frame.content, "Talent Filter", "GameFontNormal")
  frame.talentEnabledCheck = Frames.CreateCheckbox(frame.content, "Require Talents")
  frame.talentHint = Frames.CreateLabel(frame.content, "", "GameFontHighlightSmall")
  frame.talentHint:SetWidth(700)
  frame.talentHint:SetJustifyH("LEFT")
  frame.talentPickerButton = Frames.CreateButton(frame.content, "Choose Talents", 140, 22, function() end)
  Frames.StyleSecondaryButton(frame.talentPickerButton)
  frame.talentPickerButton:Hide()
  frame.talentHeaders = {}
  frame.talentRows = {}
  frame.savedLoadoutHeader = Frames.CreateLabel(frame.content, "Filter Layouts", "GameFontNormal")
  frame.savedLoadoutModeLabel = Frames.CreateLabel(frame.content, "Mode", "GameFontNormal")
  frame.savedLoadoutModeDropDown = Frames.CreateDropdown(frame.content, 190)
  frame.savedLoadoutCaptureButton = Frames.CreateButton(frame.content, "Refresh Layouts", 160, 22, function() end)
  Frames.StyleSecondaryButton(frame.savedLoadoutCaptureButton)
  frame.savedLoadoutPickerButton = Frames.CreateButton(frame.content, "Choose Layouts", 160, 22, function() end)
  Frames.StyleSecondaryButton(frame.savedLoadoutPickerButton)
  frame.savedLoadoutHint = Frames.CreateLabel(frame.content, "", "GameFontHighlightSmall")
  frame.savedLoadoutHint:SetWidth(700)
  frame.savedLoadoutHint:SetJustifyH("LEFT")
  frame.savedLoadoutHeader:Hide()
  frame.savedLoadoutModeLabel:Hide()
  frame.savedLoadoutModeDropDown:Hide()
  frame.savedLoadoutCaptureButton:Hide()
  frame.savedLoadoutPickerButton:Hide()
  frame.savedLoadoutHint:Hide()

  frame.visibilityHeader = Frames.CreateLabel(frame.content, "Visibility", "GameFontNormal")
  frame.visibilitySection = CreateFrame("Frame", nil, frame.content)
  frame.visibilitySection:SetSize(560, 80)
  frame.visibilityChecks = {}
  for _, entry in ipairs(VISIBILITY_OPTIONS) do
    local check = Frames.CreateCheckbox(frame.visibilitySection, entry.label)
    check:SetScript("OnClick", function()
      Panel:ApplyCurrent()
    end)
    frame.visibilityChecks[entry.key] = check
  end

  frame.talentModal = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame.talentModal:SetSize(760, 560)
  frame.talentModal:SetPoint("CENTER")
  frame.talentModal:SetFrameStrata("FULLSCREEN_DIALOG")
  frame.talentModal:SetFrameLevel(120)
  frame.talentModal:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.talentModal:SetBackdropColor(0.08, 0.10, 0.15, 0.98)
  frame.talentModal:SetBackdropBorderColor(0.24, 0.31, 0.40, 1)
  frame.talentModal:Hide()

  frame.talentModal.title = Frames.CreateLabel(frame.talentModal, "Talent Picker", "GameFontNormalLarge")
  frame.talentModal.title:SetPoint("TOPLEFT", 16, -16)
  frame.talentModal.hint = Frames.CreateLabel(frame.talentModal, "", "GameFontHighlightSmall")
  frame.talentModal.hint:SetPoint("TOPLEFT", frame.talentModal.title, "BOTTOMLEFT", 0, -4)
  frame.talentModal.hint:SetWidth(700)
  frame.talentModal.hint:SetJustifyH("LEFT")
  frame.talentModal.closeButton = Frames.CreateButton(frame.talentModal, "Close", 100, 22, function()
    frame.talentModal:Hide()
  end)
  frame.talentModal.closeButton:SetPoint("TOPRIGHT", -16, -16)
  Frames.StyleSecondaryButton(frame.talentModal.closeButton)
  frame.talentModal.searchInput = Frames.CreateInput(frame.talentModal, 260, 24)
  frame.talentModal.searchInput:SetPoint("TOPLEFT", frame.talentModal.title, "BOTTOMLEFT", 0, -38)
  frame.talentModal.searchInput:SetText("")
  frame.talentModal.searchLabel = Frames.CreateLabel(frame.talentModal, "Search", "GameFontNormalSmall")
  frame.talentModal.searchLabel:SetPoint("BOTTOMLEFT", frame.talentModal.searchInput, "TOPLEFT", 0, 4)
  frame.talentModal.scroll = CreateFrame("ScrollFrame", nil, frame.talentModal, "UIPanelScrollFrameTemplate")
  frame.talentModal.scroll:SetPoint("TOPLEFT", frame.talentModal.searchInput, "BOTTOMLEFT", 0, -16)
  frame.talentModal.scroll:SetPoint("BOTTOMRIGHT", -32, 16)
  frame.talentModal.content = CreateFrame("Frame", nil, frame.talentModal.scroll)
  frame.talentModal.content:SetSize(700, 420)
  frame.talentModal.scroll:SetScrollChild(frame.talentModal.content)
  frame.talentModal.emptyText = Frames.CreateLabel(frame.talentModal.content, "", "GameFontHighlightSmall")
  frame.talentModal.emptyText:SetPoint("TOPLEFT", 0, 0)
  frame.talentModal.emptyText:SetWidth(640)
  frame.talentModal.emptyText:SetJustifyH("LEFT")
  frame.talentModal.headers = {}
  frame.talentModal.rows = {}

  frame.savedLoadoutModal = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame.savedLoadoutModal:SetSize(760, 560)
  frame.savedLoadoutModal:SetPoint("CENTER")
  frame.savedLoadoutModal:SetFrameStrata("FULLSCREEN_DIALOG")
  frame.savedLoadoutModal:SetFrameLevel(121)
  frame.savedLoadoutModal:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.savedLoadoutModal:SetBackdropColor(0.08, 0.10, 0.15, 0.98)
  frame.savedLoadoutModal:SetBackdropBorderColor(0.24, 0.31, 0.40, 1)
  frame.savedLoadoutModal:Hide()

  frame.savedLoadoutModal.title = Frames.CreateLabel(frame.savedLoadoutModal, "Layout Picker", "GameFontNormalLarge")
  frame.savedLoadoutModal.title:SetPoint("TOPLEFT", 16, -16)
  frame.savedLoadoutModal.hint = Frames.CreateLabel(frame.savedLoadoutModal, "", "GameFontHighlightSmall")
  frame.savedLoadoutModal.hint:SetPoint("TOPLEFT", frame.savedLoadoutModal.title, "BOTTOMLEFT", 0, -4)
  frame.savedLoadoutModal.hint:SetWidth(700)
  frame.savedLoadoutModal.hint:SetJustifyH("LEFT")
  frame.savedLoadoutModal.closeButton = Frames.CreateButton(frame.savedLoadoutModal, "Close", 100, 22, function()
    frame.savedLoadoutModal:Hide()
  end)
  frame.savedLoadoutModal.closeButton:SetPoint("TOPRIGHT", -16, -16)
  Frames.StyleSecondaryButton(frame.savedLoadoutModal.closeButton)
  frame.savedLoadoutModal.searchInput = Frames.CreateInput(frame.savedLoadoutModal, 260, 24)
  frame.savedLoadoutModal.searchInput:SetPoint("TOPLEFT", frame.savedLoadoutModal.title, "BOTTOMLEFT", 0, -46)
  frame.savedLoadoutModal.searchInput:SetText("")
  frame.savedLoadoutModal.searchLabel = Frames.CreateLabel(frame.savedLoadoutModal, "Search", "GameFontNormalSmall")
  frame.savedLoadoutModal.searchLabel:SetPoint("BOTTOMLEFT", frame.savedLoadoutModal.searchInput, "TOPLEFT", 0, 4)
  frame.savedLoadoutModal.scroll = CreateFrame("ScrollFrame", nil, frame.savedLoadoutModal, "UIPanelScrollFrameTemplate")
  frame.savedLoadoutModal.scroll:SetPoint("TOPLEFT", frame.savedLoadoutModal.searchInput, "BOTTOMLEFT", 0, -16)
  frame.savedLoadoutModal.scroll:SetPoint("BOTTOMRIGHT", -32, 16)
  frame.savedLoadoutModal.content = CreateFrame("Frame", nil, frame.savedLoadoutModal.scroll)
  frame.savedLoadoutModal.content:SetSize(700, 420)
  frame.savedLoadoutModal.scroll:SetScrollChild(frame.savedLoadoutModal.content)
  frame.savedLoadoutModal.emptyText = Frames.CreateLabel(frame.savedLoadoutModal.content, "", "GameFontHighlightSmall")
  frame.savedLoadoutModal.emptyText:SetPoint("TOPLEFT", 0, 0)
  frame.savedLoadoutModal.emptyText:SetWidth(640)
  frame.savedLoadoutModal.emptyText:SetJustifyH("LEFT")
  frame.savedLoadoutModal.savedLoadoutRows = {}

  frame.levelLabel = Frames.CreateLabel(frame.content, "Minimum Level", "GameFontNormal")
  frame.levelLabel:SetPoint("TOPLEFT", frame.classSection, "BOTTOMLEFT", 0, -24)
  frame.levelInput = Frames.CreateInput(frame.content, 48, 24)
  frame.levelInput:SetPoint("TOPLEFT", frame.levelLabel, "BOTTOMLEFT", 0, -6)
  frame.levelInput:SetMaxLetters(3)

  frame.instanceTypeLabel = Frames.CreateLabel(frame.content, "Instance Type", "GameFontNormal")
  frame.instanceTypeDropDown = Frames.CreateDropdown(frame.content, 170, function(self, level)
    for _, entry in ipairs(INSTANCE_TYPE_OPTIONS) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.label
      info.value = entry.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.instanceTypeDropDown, entry.value)
        UIDropDownMenu_SetText(frame.instanceTypeDropDown, entry.label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  frame.instanceIdLabel = Frames.CreateLabel(frame.content, "Instance ID", "GameFontNormal")
  frame.instanceIdInput = Frames.CreateInput(frame.content, 78, 24)
  frame.instanceIdInput:SetMaxLetters(10)

  frame.encounterIdLabel = Frames.CreateLabel(frame.content, "Encounter ID", "GameFontNormal")
  frame.encounterIdInput = Frames.CreateInput(frame.content, 78, 24)
  frame.encounterIdInput:SetMaxLetters(10)

  frame.equippedItemLabel = Frames.CreateLabel(frame.content, "Only Load If Item Equipped", "GameFontNormal")
  frame.equippedItemLabel:SetPoint("TOPLEFT", frame.levelInput, "BOTTOMLEFT", 0, -18)
  frame.equippedItemInput = Frames.CreateInput(frame.content, 240, 24)
  frame.equippedItemInput:SetPoint("TOPLEFT", frame.equippedItemLabel, "BOTTOMLEFT", 0, -6)
  frame.equippedItemResolved = Frames.CreateLabel(frame.content, "|cffaaaaaaNo equipped item requirement.|r", "GameFontHighlightSmall")
  frame.equippedItemResolved:SetPoint("TOPLEFT", frame.equippedItemInput, "BOTTOMLEFT", 0, -6)

  frame.saveButton = Frames.CreateButton(frame.content, "Save", 120, 22, function()
    Panel:ApplyCurrent()
  end)
  frame.saveButton:SetPoint("TOPLEFT", frame.equippedItemResolved, "BOTTOMLEFT", 0, -18)
  frame.saveButton:Hide()

  self.frame = frame

  frame.enabledCheck:SetScript("OnClick", function()
    Panel:ApplyCurrent()
  end)
  UIDropDownMenu_Initialize(frame.combatDropDown, function(self, level)
    for _, value in ipairs({ "any", "in", "out" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = CombatModeLabel(value)
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.combatDropDown, value)
        UIDropDownMenu_SetText(frame.combatDropDown, CombatModeLabel(value))
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.levelInput:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    Panel:ApplyCurrent()
  end)
  frame.levelInput:SetScript("OnEditFocusLost", function()
    Panel:ApplyCurrent()
  end)
  UIDropDownMenu_Initialize(frame.instanceTypeDropDown, function(self, level)
    for _, entry in ipairs(INSTANCE_TYPE_OPTIONS) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.label
      info.value = entry.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.instanceTypeDropDown, entry.value)
        UIDropDownMenu_SetText(frame.instanceTypeDropDown, entry.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.instanceIdInput:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    Panel:ApplyCurrent()
  end)
  frame.instanceIdInput:SetScript("OnEditFocusLost", function()
    Panel:ApplyCurrent()
  end)
  frame.encounterIdInput:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    Panel:ApplyCurrent()
  end)
  frame.encounterIdInput:SetScript("OnEditFocusLost", function()
    Panel:ApplyCurrent()
  end)
  frame.equippedItemInput:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    Panel:ApplyCurrent()
  end)
  frame.equippedItemInput:SetScript("OnEditFocusLost", function()
    Panel:ApplyCurrent()
  end)
  frame.talentEnabledCheck:SetScript("OnClick", function(selfCheck)
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      return
    end
    aura.load = aura.load or {}
    aura.load.talent = selfCheck:GetChecked() == true
    Panel:RefreshSpecSection(aura)
    Panel:ApplyCurrent()
  end)
  UIDropDownMenu_Initialize(frame.savedLoadoutModeDropDown, function(self, level)
    for _, entry in ipairs(SAVED_LOADOUT_MODE_OPTIONS) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.label
      info.value = entry.value
      info.func = function()
        SetDropdown(frame.savedLoadoutModeDropDown, entry.value, entry.label)
        Panel:ApplyCurrent()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.savedLoadoutCaptureButton:SetScript("OnClick", function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      return
    end

    aura.load = aura.load or {}
    EnsureSavedLoadoutSelections(aura.load)
    local refreshedCatalog, reason = RefreshCurrentSavedLoadoutCatalog()
    if not refreshedCatalog then
      frame.savedLoadoutHint:SetText(string.format("|cffff8888%s|r", tostring(reason)))
      return
    end
    Panel:RefreshSpecSection(aura)
    Panel:ApplyCurrent()
  end)
  frame.savedLoadoutPickerButton:SetScript("OnClick", function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then
      return
    end
    Panel:ShowSavedLoadoutPicker(aura)
  end)

  return frame
end

function Panel:Refresh(aura)
  self.suppressUpdates = true
  local featureDisabledNotice = GetFeatureDisabledNotice(aura)
  self.frame.featureDisabledNotice:SetShown(featureDisabledNotice ~= nil)
  self.frame.featureDisabledNotice.text:SetText(featureDisabledNotice
    and ("|cffffcc44Feature disabled|r\n" .. featureDisabledNotice) or "")
  self.frame.alwaysHeader:ClearAllPoints()
  if featureDisabledNotice then
    self.frame.alwaysHeader:SetPoint(
      "TOPLEFT", self.frame.featureDisabledNotice, "BOTTOMLEFT", 0, -16)
  else
    self.frame.alwaysHeader:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", 16, -20)
  end
  aura.load.classes = EnsureMap(aura.load.classes)
  aura.load.specs = EnsureMap(aura.load.specs)
  aura.load.talents = EnsureMap(aura.load.talents)
  aura.load.savedLoadoutSelections = EnsureSavedLoadoutSelections(aura.load)
  aura.load.savedLoadoutMode = NormalizeSavedLoadoutMode(aura.load.savedLoadoutMode)
  PruneSpecSelections(aura.load)
  local visibilitySelection = GetVisibilitySelection(aura.load or {})
  self.frame.enabledCheck:SetChecked(aura.enabled ~= false)
  self.frame.levelInput:SetText((aura.load.level and aura.load.level > 0) and tostring(aura.load.level) or "")
  self.frame.instanceIdInput:SetText((aura.load.instanceId and aura.load.instanceId > 0) and tostring(aura.load.instanceId) or "")
  self.frame.encounterIdInput:SetText((aura.load.encounterId and aura.load.encounterId > 0) and tostring(aura.load.encounterId) or "")
  self.frame.equippedItemInput:SetText(
    (aura.load.equippedItemId and aura.load.equippedItemId > 0) and tostring(aura.load.equippedItemId)
      or NormalizeText(aura.load.equippedItemName)
      or ""
  )
  self.frame.equippedItemResolved:SetText(GetEquippedItemResolvedText(aura.load.equippedItemId, aura.load.equippedItemName))
  UIDropDownMenu_SetSelectedValue(self.frame.combatDropDown, aura.load.combat or "any")
  UIDropDownMenu_SetText(self.frame.combatDropDown, CombatModeLabel(aura.load.combat or "any"))
  UIDropDownMenu_SetSelectedValue(self.frame.instanceTypeDropDown, aura.load.instanceType or "")
  UIDropDownMenu_SetText(self.frame.instanceTypeDropDown, GetInstanceTypeLabel(aura.load.instanceType or ""))
  UIDropDownMenu_SetSelectedValue(self.frame.savedLoadoutModeDropDown, aura.load.savedLoadoutMode or "any")
  UIDropDownMenu_SetText(self.frame.savedLoadoutModeDropDown, GetSavedLoadoutModeLabel(aura.load.savedLoadoutMode or "any"))
  for classToken, check in pairs(self.frame.classChecks) do
    check:SetChecked(aura.load.classes[classToken] == true)
    check:SetScript("OnClick", function(selfCheck)
      aura.load.classes[classToken] = selfCheck:GetChecked() == true or nil
      PruneSpecSelections(aura.load)
      ClearTalentSelections(aura.load)
      Panel:RefreshSpecSection(aura)
      Panel:ApplyCurrent()
    end)
  end
  for key, check in pairs(self.frame.visibilityChecks or {}) do
    check:SetChecked(visibilitySelection[key] == true)
  end
  self:RefreshSpecSection(aura)
  self.suppressUpdates = false
end
