local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("trinket_cooldown", {
  events = {
    "BAG_UPDATE_COOLDOWN",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "UNIT_AURA",
    "COOLDOWN_VIEWER_DATA_LOADED",
    "COOLDOWN_VIEWER_TABLE_HOTFIXED",
  },
  unitEvents = {
    UNIT_AURA = { "player" },
  },
})

local Safe = ns.SafeValues
local Spells = ns.util.Spells
local TOP_TRINKET_SLOT = INVSLOT_TRINKET1 or 13
local BOTTOM_TRINKET_SLOT = INVSLOT_TRINKET2 or 14

provider.cooldownAuraDisplayState = setmetatable({}, { __mode = "k" })

local function SafeNumber(value)
  return Safe:Number(value)
end

local function SafeBoolean(value)
  return Safe:Boolean(value)
end

local function Trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetTrackedAuraIds(self)
  if not self._cachedAuraIds then
    self._cachedAuraIds = ns.Registry:CollectAuraIds(function(aura)
      return ns.TriggerBase:AnyTriggerMatches(aura, "trinket_cooldown")
    end)
  end
  return self._cachedAuraIds
end

function provider:GetAffectedAuras(event, unit)
  if event == "UNIT_AURA" and unit ~= "player" then
    return false
  end
  return GetTrackedAuraIds(self)
end

function provider:RefreshTrackedAuras()
  if ns.runtime then
    ns.runtime:RefreshAuras(GetTrackedAuraIds(self))
  end
end

function provider:ScheduleRefresh()
  if self._refreshPending then return end
  self._refreshPending = true
  C_Timer.After(0, function()
    self._refreshPending = false
    self:RefreshTrackedAuras()
  end)
end

local function BuildIgnoreSet(value)
  local ids, names = {}, {}
  for token in tostring(value or ""):gmatch("[^,;\r\n]+") do
    token = Trim(token)
    if token ~= "" then
      local itemID = tonumber(token)
      if itemID and itemID > 0 then
        ids[itemID] = true
      else
        names[token:lower()] = true
      end
    end
  end
  return ids, names
end

local function GetEquippedItemID(equipSlot)
  if not GetInventoryItemID then return nil end
  local ok, itemID = pcall(GetInventoryItemID, "player", equipSlot)
  itemID = ok and SafeNumber(itemID) or nil
  return itemID and itemID > 0 and itemID or nil
end

local function GetEquippedItemName(itemID)
  if not itemID then return "" end
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
  return Safe:String(name) or ""
end

local function GetEquippedItemIcon(equipSlot, itemID)
  if GetInventoryItemTexture then
    local ok, icon = pcall(GetInventoryItemTexture, "player", equipSlot)
    icon = ok and (SafeNumber(icon) or Safe:String(icon)) or nil
    if icon then return icon end
  end
  if itemID and C_Item and C_Item.GetItemIconByID then
    return SafeNumber(C_Item.GetItemIconByID(itemID))
  end
  return nil
end

local function GetInventoryCooldown(equipSlot)
  if not GetInventoryItemCooldown then
    return 0, 0, false
  end
  local ok, startTime, duration, enabled = pcall(GetInventoryItemCooldown, "player", equipSlot)
  if not ok then
    return 0, 0, false
  end
  startTime = SafeNumber(startTime)
  duration = SafeNumber(duration)
  local enabledNumber = SafeNumber(enabled)
  local enabledBoolean = enabledNumber == nil and SafeBoolean(enabled) or nil
  if not startTime or not duration or (enabledNumber == nil and enabledBoolean == nil) then
    return 0, 0, false
  end
  return startTime, duration, enabledNumber ~= nil and enabledNumber ~= 0 or enabledBoolean == true
end

local function IsIgnored(itemID, itemName, ignoredIDs, ignoredNames)
  if itemID and ignoredIDs[itemID] then return true end
  return itemName ~= "" and ignoredNames[itemName:lower()] == true
end

local function GetCooldownMatchMode(trigger)
  return trigger and trigger.cooldownMatch == "ready" and "ready" or "cooldown"
end

local function ShouldPersistDisplay(trigger, aura)
  if not trigger or trigger.showAlways == false then
    return false
  end
  return not (aura and type(aura.triggers) == "table" and #aura.triggers > 1)
end

function provider:WatchCooldownFrame(cooldown)
  if not cooldown or cooldown._popAurasTrinketWatch == true or not hooksecurefunc
    or type(cooldown.SetUseAuraDisplayTime) ~= "function" then
    return
  end
  cooldown._popAurasTrinketWatch = true
  hooksecurefunc(cooldown, "SetUseAuraDisplayTime", function(owner, useAuraDisplayTime)
    local active = SafeBoolean(useAuraDisplayTime)
    if active ~= nil then
      provider.cooldownAuraDisplayState[owner] = active
    end
    provider:ScheduleRefresh()
  end)
end

local function AddUniqueSpellID(target, seen, value)
  local spellID = SafeNumber(value)
  if not spellID or spellID <= 0 or seen[spellID] then return end
  seen[spellID] = true
  target[#target + 1] = spellID
end

local function AddRelatedSpellIDs(target, seen, value)
  local spellID = SafeNumber(value)
  if not spellID or spellID <= 0 then return end
  AddUniqueSpellID(target, seen, spellID)
  if Spells and Spells.GetAuraSpellIDs then
    for _, auraSpellID in ipairs(Spells:GetAuraSpellIDs(spellID)) do
      AddUniqueSpellID(target, seen, auraSpellID)
    end
  end
end

local function GetTrinketAuraSpellIDs(manager, cooldownIDs)
  local result, seen = {}, {}
  if not manager or not manager.GetCooldownInfo then return result end
  for _, cooldownID in ipairs(cooldownIDs or {}) do
    local info = manager:GetCooldownInfo(cooldownID)
    if type(info) == "table" and not Safe:IsSecret(info) then
      AddRelatedSpellIDs(result, seen, info.spellID)
      AddRelatedSpellIDs(result, seen, info.overrideSpellID)
      local linkedSpellIDs = info.linkedSpellIDs
      if type(linkedSpellIDs) == "table" and not Safe:IsSecret(linkedSpellIDs) then
        for _, linkedSpellID in ipairs(linkedSpellIDs) do
          AddRelatedSpellIDs(result, seen, linkedSpellID)
        end
      end
    end
  end
  return result
end

local function ReadCDMAuraActive(manager, spellIDs)
  if not manager or not manager.FindAuraStateSource or #spellIDs == 0 then
    return nil, "cdm-aura-unavailable"
  end
  local source = manager:FindAuraStateSource(spellIDs, "player", false)
  if not source or type(source.IsActive) ~= "function" then
    return nil, "cdm-aura-missing"
  end
  local ok, active = pcall(source.IsActive, source)
  active = ok and SafeBoolean(active) or nil
  if active ~= nil then
    return active, "cdm-aura"
  end
  return nil, "cdm-aura-restricted"
end

local function ReadCooldownAuraPresentation(frame, cooldown)
  local signals = {
    { value = cooldown and provider.cooldownAuraDisplayState[cooldown], source = "aura-display-hook" },
    { value = frame and frame.cooldownUseAuraDisplayTime, source = "frame-aura-display" },
    { value = cooldown and cooldown.cooldownUseAuraDisplayTime, source = "cooldown-aura-display" },
    { value = frame and frame.wasSetFromAura, source = "frame-aura-source" },
  }
  for _, signal in ipairs(signals) do
    local active = SafeBoolean(signal.value)
    if active == true then
      return true, signal.source
    end
  end

  local auraInstanceID = frame and SafeNumber(frame.auraInstanceID) or nil
  if auraInstanceID and auraInstanceID > 0 then
    return true, "frame-aura-instance"
  end

  for _, signal in ipairs(signals) do
    local active = SafeBoolean(signal.value)
    if active == false then
      return false, signal.source
    end
  end

  if cooldown and type(cooldown.GetUseAuraDisplayTime) == "function" then
    local ok, active = pcall(cooldown.GetUseAuraDisplayTime, cooldown)
    active = ok and SafeBoolean(active) or nil
    if active ~= nil then
      return active, "legacy-aura-display"
    end
  end

  return nil, "aura-display-unavailable"
end

local function ResolveTrinketEffectActive(manager, spellIDs, frame, cooldown)
  -- Prefer the public active-state boolean on Blizzard's tracked buff source.
  -- If that source is absent, use the Cooldown widget's presentation toggle;
  -- its hook captures the non-secret boolean without reading aura records.
  local cdmActive, cdmSource = ReadCDMAuraActive(manager, spellIDs)
  if cdmActive ~= nil then return cdmActive, true, cdmSource end

  local presentationActive, presentationSource = ReadCooldownAuraPresentation(frame, cooldown)
  if presentationActive ~= nil then
    return presentationActive, true, presentationSource
  end

  return false, false, cdmSource .. "+" .. presentationSource
end

function provider:FindCDMFrame(equipSlot)
  local manager = ns.CooldownManager
  if not manager or not manager.FindOnUseEquipSlotFrame then
    return nil, nil
  end

  local frame, cooldownID = manager:FindOnUseEquipSlotFrame(equipSlot, false)
  if frame then return frame, cooldownID end

  self._frameRetryAt = self._frameRetryAt or {}
  local now = GetTime()
  if now >= (self._frameRetryAt[equipSlot] or 0) then
    self._frameRetryAt[equipSlot] = now + 1
    return manager:FindOnUseEquipSlotFrame(equipSlot, true)
  end
  return nil, nil
end

local function BuildUnavailableEntry(equipSlot, slotLabel, itemID, itemName, icon, statusText)
  return ns.Schema.NormalizeRuntimeState({
    key = "trinket_slot_" .. tostring(equipSlot),
    equipSlot = equipSlot,
    show = false,
    matched = false,
    active = false,
    icon = icon,
    name = itemName ~= "" and itemName or slotLabel,
    itemId = itemID,
    isReady = false,
    source = "trinket_cooldown",
    availability = "unavailable",
    statusText = statusText,
  })
end

function provider:BuildSlotEntry(trigger, aura, equipSlot, slotLabel, ignoredIDs, ignoredNames)
  local itemID = GetEquippedItemID(equipSlot)
  local itemName = GetEquippedItemName(itemID)
  local icon = GetEquippedItemIcon(equipSlot, itemID)
  if not itemID then
    return BuildUnavailableEntry(equipSlot, slotLabel, nil, "", icon, "Empty slot")
  end
  if IsIgnored(itemID, itemName, ignoredIDs, ignoredNames) then
    return BuildUnavailableEntry(equipSlot, slotLabel, itemID, itemName, icon, "Ignored")
  end

  local manager = ns.CooldownManager
  local cooldownIDs = manager and manager.GetOnUseEquipSlotCooldownIDs
    and manager:GetOnUseEquipSlotCooldownIDs(equipSlot) or {}
  if #cooldownIDs == 0 then
    return BuildUnavailableEntry(equipSlot, slotLabel, itemID, itemName, icon, "Not an on-use trinket")
  end

  local startTime, duration, enabled = GetInventoryCooldown(equipSlot)
  local expirationTime = 0
  local numericOnCooldown = false
  if enabled and duration > 0 then
    local candidateExpiration = startTime + duration
    if candidateExpiration > GetTime() then
      expirationTime = candidateExpiration
      numericOnCooldown = true
    end
  end

  local frame, cooldownID = self:FindCDMFrame(equipSlot)
  local cdmOnCooldown
  local cooldown
  if frame then
    local okActive, active = pcall(frame.IsOnCooldown, frame)
    cdmOnCooldown = okActive and SafeBoolean(active) or nil
    local okCooldown, resolvedCooldown = pcall(frame.GetCooldownFrame, frame)
    if okCooldown and resolvedCooldown then
      cooldown = resolvedCooldown
      self:WatchCooldownFrame(cooldown)
    end
  end
  local auraSpellIDs = GetTrinketAuraSpellIDs(manager, cooldownIDs)
  local effectActive, effectKnown, effectSource = ResolveTrinketEffectActive(
    manager, auraSpellIDs, frame, cooldown)
  local glowEnabled = aura and aura.display and aura.display.glowWhenActive == true

  local onCooldown = cdmOnCooldown
  if onCooldown == nil then
    onCooldown = numericOnCooldown
  end
  local isReady = not onCooldown
  local matched = (GetCooldownMatchMode(trigger) == "ready") == isReady
  local show = ShouldPersistDisplay(trigger, aura) or matched

  return ns.Schema.NormalizeRuntimeState({
    key = "trinket_slot_" .. tostring(equipSlot),
    equipSlot = equipSlot,
    cooldownID = cooldownID or cooldownIDs[1],
    show = show,
    matched = matched,
    active = onCooldown,
    icon = icon,
    name = itemName ~= "" and itemName or ("Item " .. tostring(itemID)),
    duration = numericOnCooldown and duration or 0,
    expirationTime = numericOnCooldown and expirationTime or 0,
    progressType = numericOnCooldown and "timed" or "static",
    value = numericOnCooldown and duration or 0,
    total = numericOnCooldown and duration or 0,
    isReady = isReady,
    isEnabled = enabled,
    itemId = itemID,
    source = "trinket_cooldown",
    availability = "available",
    trinketEffectActive = effectActive,
    glow = glowEnabled and effectActive,
    statusText = effectActive and "Active" or (isReady and "Ready" or "Cooldown"),
    debugExtra = string.format(
      "slot=%d effect=%s known=%s signal=%s displayGlow=%s auraIDs=%d frame=%s",
      equipSlot, tostring(effectActive), tostring(effectKnown), tostring(effectSource),
      tostring(glowEnabled), #auraSpellIDs, tostring(frame ~= nil)),
  })
end

local function CopyEntryPresentation(target, entry)
  for key, value in pairs(entry or {}) do
    if key ~= "entries" then target[key] = value end
  end
end

function provider:Evaluate(trigger, aura)
  local ignoredIDs, ignoredNames = BuildIgnoreSet(trigger.ignoredTrinkets)
  local entries = {}
  if trigger.trinketTop ~= false then
    entries[#entries + 1] = self:BuildSlotEntry(trigger, aura, TOP_TRINKET_SLOT, "Top Trinket Slot", ignoredIDs, ignoredNames)
  end
  if trigger.trinketBottom ~= false then
    entries[#entries + 1] = self:BuildSlotEntry(trigger, aura, BOTTOM_TRINKET_SLOT, "Bottom Trinket Slot", ignoredIDs, ignoredNames)
  end

  local presentation
  local matched, show, active, anyAvailable, allReady = false, false, false, false, true
  local earliestExpiration
  for _, entry in ipairs(entries) do
    if not presentation or (entry.show == true and presentation.show ~= true)
      or (entry.availability == "available" and presentation.availability ~= "available") then
      presentation = entry
    end
    matched = matched or entry.matched == true
    show = show or entry.show == true
    active = active or entry.active == true
    if entry.availability == "available" then
      anyAvailable = true
      allReady = allReady and entry.isReady == true
    end
    if entry.progressType == "timed" and entry.expirationTime > GetTime()
      and (not earliestExpiration or entry.expirationTime < earliestExpiration) then
      earliestExpiration = entry.expirationTime
    end
  end

  local state = {}
  if presentation then CopyEntryPresentation(state, presentation) end
  state.entries = entries
  state.show = show
  state.matched = matched
  state.active = active
  state.isReady = anyAvailable and allReady
  state.source = "trinket_cooldown"
  state.availability = anyAvailable and "available" or "unavailable"
  if earliestExpiration then
    state.progressType = "timed"
    state.expirationTime = earliestExpiration
    state.duration = math.max(0, earliestExpiration - GetTime())
    state.value = state.duration
    state.total = state.duration
  end
  return ns.Schema.NormalizeRuntimeState(state)
end
