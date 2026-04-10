local _, ns = ...

local Frames = ns.util.Frames

local Panel = {}
ns.panels.LoadPanel = Panel

local CLASS_SPECS = {
  DEATHKNIGHT = { className = "Death Knight", specs = { "Blood", "Frost", "Unholy" } },
  DEMONHUNTER = { className = "Demon Hunter", specs = { "Havoc", "Vengeance" } },
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

local CLASS_ORDER = {
  "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK",
  "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

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
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function FindEquippedItemByName(itemName)
  local needle = string.lower(NormalizeText(itemName))
  if needle == "" then
    return 0, nil
  end

  for _, slotId in ipairs(EQUIPMENT_SLOTS) do
    local itemId = GetInventoryItemID and GetInventoryItemID("player", slotId) or nil
    if itemId and itemId > 0 then
      local equippedName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId) or nil
      if equippedName and string.lower(equippedName) == needle then
        return itemId, equippedName
      end
    end
  end

  return 0, nil
end

local function GetEquippedItemResolvedText(itemId, itemName)
  itemId = tonumber(itemId or 0) or 0
  itemName = NormalizeText(itemName)

  if itemId > 0 then
    local resolvedName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId) or itemName
    if resolvedName ~= "" then
      return string.format("|cff88ff88Equipped Item:|r %s (%d)", resolvedName, itemId)
    end
    return string.format("|cff88ff88Equipped Item ID:|r %d", itemId)
  end

  if itemName ~= "" then
    return string.format("|cff88ff88Equipped Item Name:|r %s", itemName)
  end

  return "|cffaaaaaaNo equipped item requirement.|r"
end

local function ResolveItemFilterInput(input)
  input = NormalizeText(input)
  if input == "" then
    return 0, ""
  end

  local numeric = tonumber(input)
  if numeric then
    return math.floor(numeric + 0.5), ""
  end

  local itemId = FindEquippedItemByName(input)
  return itemId or 0, input
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
  aura.enabled = self.frame.enabledCheck:GetChecked() == true
  aura.load.combat = UIDropDownMenu_GetSelectedValue(self.frame.combatDropDown) or "any"
  for classToken, check in pairs(self.frame.classChecks) do
    aura.load.classes[classToken] = check:GetChecked() == true or nil
  end
  for key, check in pairs(self.frame.visibilityChecks or {}) do
    aura.load.visibility[key] = check:GetChecked() == true
  end
  aura.load.talent = self.frame.talentEnabledCheck:GetChecked() == true
  aura.load.level = math.max(0, math.floor((tonumber(self.frame.levelInput:GetText()) or 0) + 0.5))
  aura.load.instanceType = UIDropDownMenu_GetSelectedValue(self.frame.instanceTypeDropDown) or ""
  aura.load.instanceId = math.max(0, math.floor((tonumber(self.frame.instanceIdInput:GetText()) or 0) + 0.5))
  aura.load.encounterId = math.max(0, math.floor((tonumber(self.frame.encounterIdInput:GetText()) or 0) + 0.5))
  local equippedItemId, equippedItemName = ResolveItemFilterInput(self.frame.equippedItemInput:GetText())
  aura.load.equippedItemId = equippedItemId or 0
  aura.load.equippedItemName = equippedItemName or ""
  self.frame.levelInput:SetText(aura.load.level > 0 and tostring(aura.load.level) or "")
  self.frame.instanceIdInput:SetText(aura.load.instanceId > 0 and tostring(aura.load.instanceId) or "")
  self.frame.encounterIdInput:SetText(aura.load.encounterId > 0 and tostring(aura.load.encounterId) or "")
  self.frame.equippedItemInput:SetText(aura.load.equippedItemId > 0 and tostring(aura.load.equippedItemId) or aura.load.equippedItemName or "")
  self.frame.equippedItemResolved:SetText(GetEquippedItemResolvedText(aura.load.equippedItemId, aura.load.equippedItemName))
  ns.runtime:RefreshAura(aura.id)
end

function Panel:RefreshSpecSection(aura)
  local load = aura.load or {}
  load.classes = EnsureMap(load.classes)
  load.specs = EnsureMap(load.specs)
  load.talents = EnsureMap(load.talents)

  local hasClasses = false
  local classCollapsed = self.frame.collapsedSections and self.frame.collapsedSections.class == true
  local specCollapsed = self.frame.collapsedSections and self.frame.collapsedSections.spec == true
  local anchor = self.frame.classSection

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

  local index = 0
  for _, classToken in ipairs(CLASS_ORDER) do
    if load.classes[classToken] then
      hasClasses = true
      local info = CLASS_SPECS[classToken]
      for specIndex, specName in ipairs(info.specs) do
        index = index + 1
        local check = self.frame.specChecks[index]
        if not check then
          check = Frames.CreateCheckbox(self.frame.content, "")
          self.frame.specChecks[index] = check
        end
        check:ClearAllPoints()
        check:SetPoint("TOPLEFT", self.frame.specHeader, "BOTTOMLEFT", 0, -8 - ((index - 1) * 24))
        local key = classToken .. ":" .. specIndex
        check.Text:SetText(string.format("%s: %s", info.className, specName))
        check:SetChecked(load.specs[key] == true)
        check:SetScript("OnClick", function(selfCheck)
          load.specs[key] = selfCheck:GetChecked() == true or nil
          Panel:RefreshSpecSection(aura)
          Panel:ApplyCurrent()
        end)
        check:SetShown(not specCollapsed)
      end
    end
  end

  self.frame.specHeader:SetShown(hasClasses)
  self.frame.specToggle:SetShown(hasClasses)
  self.frame.specHeader:ClearAllPoints()
  self.frame.specHeader:SetPoint(
    "TOPLEFT",
    classCollapsed and self.frame.classHeader or self.frame.classSection,
    "BOTTOMLEFT",
    0,
    -18
  )
  self.frame.specHeader:SetText(hasClasses and "Spec Filter" or "")
  self.frame.specToggle:ClearAllPoints()
  self.frame.specToggle:SetPoint("LEFT", self.frame.specHeader, "RIGHT", 8, 0)
  SetCollapseButtonText(self.frame.specToggle, specCollapsed)

  local specAnchor = classCollapsed and self.frame.classHeader or self.frame.classSection
  if hasClasses then
    specAnchor = specCollapsed and self.frame.specHeader or (self.frame.specChecks[index] or self.frame.specHeader)
  end
  self:RefreshTalentSection(aura, specAnchor)
end

function Panel:RefreshTalentSection(aura, topAnchor)
  local load = aura.load or {}
  load.talents = EnsureMap(load.talents)

  HideTalentListWidgets(self.frame)

  self.frame.visibilityHeader:ClearAllPoints()
  self.frame.visibilityHeader:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -24)
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

  self.frame.talentHeader:SetShown(true)
  self.frame.talentEnabledCheck:SetShown(true)
  self.frame.talentEnabledCheck:SetChecked(load.talent == true)
  self.frame.talentHeader:ClearAllPoints()
  self.frame.talentHeader:SetPoint("TOPLEFT", self.frame.equippedItemResolved, "BOTTOMLEFT", 0, -24)
  self.frame.talentEnabledCheck:ClearAllPoints()
  self.frame.talentEnabledCheck:SetPoint("TOPLEFT", self.frame.talentHeader, "BOTTOMLEFT", 0, -8)
  self.frame.talentPickerButton:ClearAllPoints()
  self.frame.talentPickerButton:SetPoint("TOPLEFT", self.frame.talentEnabledCheck, "BOTTOMLEFT", 26, -6)

  local anchor = self.frame.talentEnabledCheck
  local contentHeight = 0

  if load.talent == true then
    local groups, reason = BuildTalentOptions(load)
    self.frame.talentHint:ClearAllPoints()
    self.frame.talentHint:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    if not groups or #groups == 0 then
      self.frame.talentHint:SetText("|cffaaaaaa" .. tostring(reason or "No talent options available.") .. "|r")
      self.frame.talentHint:Show()
      self.frame.talentPickerButton:Hide()
      anchor = self.frame.talentHint
      contentHeight = 34
    else
      local selectedNames = GetSelectedTalentNames(groups, load)
      local selectedCount = #selectedNames
      local summaryText = selectedCount > 0 and table.concat(selectedNames, ", ") or "No talents selected."
      self.frame.talentHint:SetText(string.format("|cffaaaaaa%s|r", summaryText))
      self.frame.talentHint:Show()
      self.frame.talentPickerButton:Show()
      self.frame.talentPickerButton:SetText("Choose Talents")
      self.frame.talentPickerButton:SetScript("OnClick", function()
        Panel:ShowTalentPicker(aura, groups)
      end)
      anchor = self.frame.talentPickerButton
      self.frame.talentHint:ClearAllPoints()
      self.frame.talentHint:SetPoint("TOPLEFT", self.frame.talentPickerButton, "BOTTOMLEFT", 0, -8)
      contentHeight = 56
    end
  else
    self.frame.talentHint:Hide()
    self.frame.talentPickerButton:Hide()
  end

  self.frame.saveButton:ClearAllPoints()
  self.frame.saveButton:SetPoint("TOPLEFT", (self.frame.talentHint:IsShown() and self.frame.talentHint or self.frame.talentEnabledCheck), "BOTTOMLEFT", 0, -18)

  local selectedSpecCount = 0
  for _, classToken in ipairs(CLASS_ORDER) do
    if load.classes[classToken] then
      selectedSpecCount = selectedSpecCount + #(CLASS_SPECS[classToken].specs or {})
    end
  end
  local classHeight = (self.frame.collapsedSections and self.frame.collapsedSections.class == true) and 0 or (math.ceil(#CLASS_ORDER / 2) * 24)
  local specHeight = (self.frame.collapsedSections and self.frame.collapsedSections.spec == true) and 0 or (selectedSpecCount * 24)
  self.frame.content:SetHeight(math.max(980, 640 + classHeight + specHeight + contentHeight))
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

  return frame
end

function Panel:Refresh(aura)
  self.suppressUpdates = true
  aura.load.classes = EnsureMap(aura.load.classes)
  aura.load.specs = EnsureMap(aura.load.specs)
  aura.load.talents = EnsureMap(aura.load.talents)
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
  for classToken, check in pairs(self.frame.classChecks) do
    check:SetChecked(aura.load.classes[classToken] == true)
    check:SetScript("OnClick", function(selfCheck)
      aura.load.classes[classToken] = selfCheck:GetChecked() == true or nil
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
