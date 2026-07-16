local _, ns = ...

local Safe = ns.SafeValues
local Manager = {
  spellToCooldownIDs = nil,
  directSpellToCooldownIDs = nil,
  cooldownInfo = nil,
  onUseEquipSlotCooldownIDs = nil,
  frameCache = {},
  hiddenFrames = {},
  applyingVisibilityOverrides = false,
}
ns.CooldownManager = Manager

Manager.viewerNames = {
  "BuffIconCooldownViewer",
  "BuffBarCooldownViewer",
  "EssentialCooldownViewer",
  "UtilityCooldownViewer",
  "GroupBuffCooldownViewer",
  "SpecAgnosticEssentialCooldownViewer",
  "SpecAgnosticTrackedCooldownViewer",
}

local EMPTY = {}

local function AddUnique(list, seen, value)
  value = Safe:Number(value)
  if value and value >= 0 and not seen[value] then
    seen[value] = true
    list[#list + 1] = value
  end
end

local function GetCategories()
  local result, seen = {}, {}
  local enum = Enum and Enum.CooldownViewerCategory or nil
  if type(enum) == "table" then
    for _, value in pairs(enum) do
      AddUnique(result, seen, value)
    end
  end
  -- Fallback values preserve mapping on clients where the enum table is not
  -- enumerable. Invalid categories are isolated by pcall below.
  for value = 0, 15 do
    AddUnique(result, seen, value)
  end
  return result
end

local function AddMapping(mapping, spellID, cooldownID)
  spellID = Safe:Number(spellID)
  cooldownID = Safe:Number(cooldownID)
  if not spellID or spellID <= 0 or not cooldownID or cooldownID <= 0 then
    return
  end
  local list = mapping[spellID]
  if not list then
    list = {}
    mapping[spellID] = list
  end
  for _, existing in ipairs(list) do
    if existing == cooldownID then return end
  end
  list[#list + 1] = cooldownID
end

function Manager:BuildCatalog()
  local mapping, directMapping, infoByID, onUseEquipSlotCooldownIDs = {}, {}, {}, {}
  if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet
    or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
    self.spellToCooldownIDs = mapping
    self.directSpellToCooldownIDs = directMapping
    self.cooldownInfo = infoByID
    self.onUseEquipSlotCooldownIDs = onUseEquipSlotCooldownIDs
    return
  end

  local onUseEquipCategory = Enum and Enum.CooldownViewerCategory
    and Safe:Number(Enum.CooldownViewerCategory.EquipSlotEssential) or 7

  for _, category in ipairs(GetCategories()) do
    local okSet, cooldownIDs = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
    if okSet and not Safe:IsSecret(cooldownIDs) and type(cooldownIDs) == "table" then
      for _, cooldownID in ipairs(cooldownIDs) do
        cooldownID = Safe:Number(cooldownID)
        if cooldownID and cooldownID > 0 and not infoByID[cooldownID] then
          local okInfo, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
          if okInfo and not Safe:IsSecret(info) and type(info) == "table" then
            infoByID[cooldownID] = info
            AddMapping(mapping, info.spellID, cooldownID)
            AddMapping(mapping, info.overrideSpellID, cooldownID)
            AddMapping(directMapping, info.spellID, cooldownID)
            AddMapping(directMapping, info.overrideSpellID, cooldownID)
            for _, linkedSpellID in ipairs(type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or EMPTY) do
              AddMapping(mapping, linkedSpellID, cooldownID)
            end
            local equipSlot = Safe:Number(info.equipSlot)
            local infoCategory = Safe:Number(info.category)
            local isKnown = Safe:Boolean(info.isKnown)
            if equipSlot and equipSlot > 0 and infoCategory == onUseEquipCategory and isKnown == true then
              local slotIDs = onUseEquipSlotCooldownIDs[equipSlot]
              if not slotIDs then
                slotIDs = {}
                onUseEquipSlotCooldownIDs[equipSlot] = slotIDs
              end
              slotIDs[#slotIDs + 1] = cooldownID
            end
          end
        end
      end
    end
  end
  self.spellToCooldownIDs = mapping
  self.directSpellToCooldownIDs = directMapping
  self.cooldownInfo = infoByID
  self.onUseEquipSlotCooldownIDs = onUseEquipSlotCooldownIDs
end

function Manager:EnsureCatalog()
  if not self.spellToCooldownIDs or not self.directSpellToCooldownIDs or not self.cooldownInfo
    or not self.onUseEquipSlotCooldownIDs then
    self:BuildCatalog()
  end
end

function Manager:Invalidate()
  self.spellToCooldownIDs = nil
  self.directSpellToCooldownIDs = nil
  self.cooldownInfo = nil
  self.onUseEquipSlotCooldownIDs = nil
  self.frameCache = {}
end

function Manager:GetOnUseEquipSlotCooldownIDs(equipSlot)
  equipSlot = Safe:Number(equipSlot)
  if not equipSlot or equipSlot <= 0 then return {} end
  self:EnsureCatalog()
  local copy = {}
  for _, cooldownID in ipairs(self.onUseEquipSlotCooldownIDs[equipSlot] or EMPTY) do
    copy[#copy + 1] = cooldownID
  end
  return copy
end

function Manager:FindOnUseEquipSlotFrame(equipSlot, forceRefresh)
  equipSlot = Safe:Number(equipSlot)
  if not equipSlot or equipSlot <= 0 then return nil, nil end

  local fallbackFrame, fallbackCooldownID
  for _, cooldownID in ipairs(self:GetOnUseEquipSlotCooldownIDs(equipSlot)) do
    for _, frame in ipairs(self:FindFramesByCooldownID(cooldownID, forceRefresh)) do
      if type(frame.GetEquipSlot) == "function" and type(frame.GetCooldownFrame) == "function"
        and type(frame.IsOnCooldown) == "function" then
        local okSlot, frameSlot = pcall(frame.GetEquipSlot, frame)
        frameSlot = okSlot and Safe:Number(frameSlot) or nil
        if frameSlot == equipSlot then
          local okCooldown, cooldown = pcall(frame.GetCooldownFrame, frame)
          if okCooldown and cooldown then
            local okShown, shown = pcall(frame.IsShown, frame)
            shown = okShown and Safe:Boolean(shown) or false
            if shown == true then
              return frame, cooldownID
            end
            if not fallbackFrame then
              fallbackFrame, fallbackCooldownID = frame, cooldownID
            end
          end
        end
      end
    end
  end
  return fallbackFrame, fallbackCooldownID
end

function Manager:GetCooldownIDsForSpellID(spellID)
  spellID = Safe:Number(spellID)
  if not spellID or spellID <= 0 then return {} end
  self:EnsureCatalog()
  local source = self.spellToCooldownIDs[spellID] or EMPTY
  local copy = {}
  for _, cooldownID in ipairs(source) do copy[#copy + 1] = cooldownID end
  return copy
end

function Manager:GetDirectCooldownIDsForSpellID(spellID)
  spellID = Safe:Number(spellID)
  if not spellID or spellID <= 0 then return {} end
  self:EnsureCatalog()
  local source = self.directSpellToCooldownIDs[spellID] or EMPTY
  local copy = {}
  for _, cooldownID in ipairs(source) do copy[#copy + 1] = cooldownID end
  return copy
end

function Manager:FindCooldownIDForSpellID(spellID)
  return self:GetCooldownIDsForSpellID(spellID)[1]
end

function Manager:GetCooldownInfo(cooldownID)
  cooldownID = Safe:Number(cooldownID)
  if not cooldownID or cooldownID <= 0 then return nil end
  self:EnsureCatalog()
  return self.cooldownInfo[cooldownID]
end

function Manager:GetFrameCooldownID(frame)
  if not frame then return nil end
  local value = Safe:Number(frame.cooldownID)
  if value and value > 0 then return value end
  if type(frame.cooldownInfo) == "table" and not Safe:IsSecret(frame.cooldownInfo) then
    value = Safe:Number(frame.cooldownInfo.cooldownID)
    if value and value > 0 then return value end
  end
  if frame.Icon then return self:GetFrameCooldownID(frame.Icon) end
  return nil
end

local function CollectFrames(manager, node, cooldownID, result, visited)
  if not node or visited[node] then return end
  visited[node] = true
  if manager:GetFrameCooldownID(node) == cooldownID then
    result[#result + 1] = node
  end
  if node.GetChildren then
    for _, child in ipairs({ node:GetChildren() }) do
      CollectFrames(manager, child, cooldownID, result, visited)
    end
  end
end

function Manager:FindFramesByCooldownID(cooldownID, forceRefresh)
  cooldownID = Safe:Number(cooldownID)
  if not cooldownID or cooldownID <= 0 then return {} end
  if forceRefresh ~= true and self.frameCache[cooldownID] then
    return self.frameCache[cooldownID]
  end
  local result, visited = {}, {}
  for _, name in ipairs(self.viewerNames) do
    CollectFrames(self, _G[name], cooldownID, result, visited)
  end
  self.frameCache[cooldownID] = result
  return result
end

function Manager:FindFrameByCooldownID(cooldownID)
  return self:FindFramesByCooldownID(cooldownID)[1]
end

local function IsAuraDisplayFrame(frame)
  if not frame then return false end
  local viewer = frame.viewerFrame
  if viewer == nil or viewer ~= _G.BuffBarCooldownViewer or type(frame.GetBarFrame) ~= "function" then
    return false
  end
  local ok, bar = pcall(frame.GetBarFrame, frame)
  return ok and bar ~= nil and type(bar.SetValue) == "function"
end

local function AddCooldownIDsForSpells(manager, result, seen, spellIDs, directOnly)
  for _, spellID in ipairs(type(spellIDs) == "table" and spellIDs or EMPTY) do
    local cooldownIDs = directOnly and manager:GetDirectCooldownIDsForSpellID(spellID)
      or manager:GetCooldownIDsForSpellID(spellID)
    for _, cooldownID in ipairs(cooldownIDs) do
      if not seen[cooldownID] then
        seen[cooldownID] = true
        result[#result + 1] = cooldownID
      end
    end
  end
end

-- CDM's tracked-buff-bar frames are allowed to evaluate aura relationships
-- that remain secret to normal addon Lua. Return only Blizzard bar frames;
-- essential/utility cooldown frames can share linked spell IDs but are not
-- authoritative aura sources.
function Manager:FindAuraDisplaySource(spellIDs, requestedUnit, forceRefresh)
  local cooldownIDs, seen = {}, {}
  -- Direct relationships win. Applied/override aura IDs supplied by the spell
  -- resolver normally lead directly to the tracked buff/bar entry.
  AddCooldownIDsForSpells(self, cooldownIDs, seen, spellIDs, true)
  AddCooldownIDsForSpells(self, cooldownIDs, seen, spellIDs, false)

  local inactiveSource, inactiveCooldownID
  for _, cooldownID in ipairs(cooldownIDs) do
    for _, frame in ipairs(self:FindFramesByCooldownID(cooldownID, forceRefresh)) do
      if IsAuraDisplayFrame(frame) and type(frame.IsActive) == "function"
        and type(frame.GetAuraDataUnit) == "function"
        and type(frame.GetAuraSpellID) == "function" then
        local okActive, active = pcall(frame.IsActive, frame)
        active = okActive and Safe:Boolean(active) or nil
        if active == true then
          local okUnit, sourceUnit = pcall(frame.GetAuraDataUnit, frame)
          sourceUnit = okUnit and Safe:String(sourceUnit) or nil
          if requestedUnit == nil or sourceUnit == requestedUnit then
            return frame, cooldownID
          end
        elseif not inactiveSource then
          inactiveSource, inactiveCooldownID = frame, cooldownID
        end
      end
    end
  end
  return inactiveSource, inactiveCooldownID
end

local function SetForcedHidden(frame, hidden)
  if not frame or not frame.SetAlpha then return end
  if frame._popAurasHiddenHook ~= true then
    frame._popAurasHiddenHook = true
    hooksecurefunc(frame, "SetAlpha", function(owner, alpha)
      if owner._popAurasForceHidden == true and Safe:Number(alpha) ~= 0 and owner._popAurasApplyingAlpha ~= true then
        owner._popAurasApplyingAlpha = true
        pcall(owner.SetAlpha, owner, 0)
        owner._popAurasApplyingAlpha = false
      end
    end)
  end
  if hidden then
    if frame._popAurasOriginalAlpha == nil and frame.GetAlpha then
      frame._popAurasOriginalAlpha = frame:GetAlpha()
    end
    frame._popAurasForceHidden = true
    frame._popAurasApplyingAlpha = true
    pcall(frame.SetAlpha, frame, 0)
    frame._popAurasApplyingAlpha = false
  else
    frame._popAurasForceHidden = false
    local alpha = Safe:Number(frame._popAurasOriginalAlpha) or 1
    frame._popAurasOriginalAlpha = nil
    pcall(frame.SetAlpha, frame, alpha)
  end
end

function Manager:RestoreAllHiddenFrames()
  for cooldownID, frames in pairs(self.hiddenFrames) do
    for _, frame in ipairs(frames) do SetForcedHidden(frame, false) end
    self.hiddenFrames[cooldownID] = nil
  end
end

local function AddTriggerCooldownIDs(manager, target, trigger)
  local directIDs = {}
  local linkedIDs = {}

  local function collectSpell(spellID)
    for _, cooldownID in ipairs(manager:GetDirectCooldownIDsForSpellID(spellID)) do
      directIDs[cooldownID] = true
    end
    for _, cooldownID in ipairs(manager:GetCooldownIDsForSpellID(spellID)) do
      linkedIDs[cooldownID] = true
    end
  end
  collectSpell(trigger.spellId)
  for _, spellID in ipairs(type(trigger.spellIDs) == "table" and trigger.spellIDs or EMPTY) do collectSpell(spellID) end

  if next(directIDs) ~= nil then
    for cooldownID in pairs(directIDs) do target[cooldownID] = true end
    return
  end

  -- Linked spell IDs are semantic relationships and can point at neighboring
  -- CDM entries. Use them only when every configured ID resolves to one unique
  -- cooldown, preserving proc/aura mappings without hiding recycled neighbors.
  local linkedCooldownID
  for cooldownID in pairs(linkedIDs) do
    if linkedCooldownID ~= nil then return end
    linkedCooldownID = cooldownID
  end
  if linkedCooldownID then target[linkedCooldownID] = true end
end

local function AddTrinketCooldownIDs(manager, target, trigger, state)
  if type(state and state.entries) == "table" then
    for _, entry in ipairs(state.entries) do
      local cooldownID = entry.show == true and Safe:Number(entry.cooldownID) or nil
      if cooldownID and cooldownID > 0 then target[cooldownID] = true end
    end
    return
  end
  local equipSlots = {}
  if trigger.trinketTop ~= false then equipSlots[#equipSlots + 1] = INVSLOT_TRINKET1 or 13 end
  if trigger.trinketBottom ~= false then equipSlots[#equipSlots + 1] = INVSLOT_TRINKET2 or 14 end
  for _, equipSlot in ipairs(equipSlots) do
    for _, cooldownID in ipairs(manager:GetOnUseEquipSlotCooldownIDs(equipSlot)) do
      target[cooldownID] = true
    end
  end
end

function Manager:GetDesiredHiddenIDs()
  local desired = {}
  if not ns.Registry or not ns.runtime then return desired end
  for _, auraID in ipairs(ns.Registry:GetFlatOrder()) do
    local aura = ns.Registry:GetAura(auraID)
    local state = ns.runtime:GetState(auraID)
    local effectivelyLoaded = state and state.loadMatched ~= false
    local nativeAuraOwnsPresentation = effectivelyLoaded and aura and ns.renderers and ns.renderers.NativeAuraRegion
      and ns.renderers.NativeAuraRegion:CanHandle(aura) or false
    if aura and aura.enabled ~= false and aura.display and aura.display.hideCDMIcon == true
      and effectivelyLoaded
      and ((state and state.show == true) or nativeAuraOwnsPresentation) then
      for _, trigger in ns.TriggerBase:IterateTriggers(aura) do
        if trigger.type == "spell_cooldown" or trigger.type == "aura" then
          AddTriggerCooldownIDs(self, desired, trigger)
        elseif trigger.type == "trinket_cooldown" then
          AddTrinketCooldownIDs(self, desired, trigger, state)
        end
      end
    end
  end
  return desired
end

function Manager:ApplyVisibilityOverrides()
  if self.applyingVisibilityOverrides then return end
  self.applyingVisibilityOverrides = true
  local desired = self:GetDesiredHiddenIDs()
  -- CDM recycles frame objects between cooldown entries. Always release the
  -- previous frame assignments before resolving the current owners; otherwise
  -- a frame that used to display a hidden cooldown can remain forced invisible
  -- after Blizzard assigns it to a neighboring spell.
  self:RestoreAllHiddenFrames()

  for cooldownID in pairs(desired) do
    local frames = self:FindFramesByCooldownID(cooldownID, true)
    for _, frame in ipairs(frames) do SetForcedHidden(frame, true) end
    self.hiddenFrames[cooldownID] = frames
  end
  self.applyingVisibilityOverrides = false
end

function Manager:ScheduleVisibilityOverrideSync()
  if self.visibilitySyncPending then return end
  self.visibilitySyncPending = true
  C_Timer.After(0, function()
    self.visibilitySyncPending = false
    self:ApplyVisibilityOverrides()
  end)
end

function Manager:ScheduleAuraSourceSync()
  if self.auraSourceSyncPending then return end
  self.auraSourceSyncPending = true
  C_Timer.After(0, function()
    self.auraSourceSyncPending = false
    if ns.runtime and ns.runtime.RefreshNativeAuraContainers then
      ns.runtime:RefreshNativeAuraContainers("player")
      ns.runtime:RefreshNativeAuraContainers("target")
    end
  end)
end

function Manager:ScheduleTrinketSourceSync()
  if self.trinketSourceSyncPending then return end
  self.trinketSourceSyncPending = true
  C_Timer.After(0, function()
    self.trinketSourceSyncPending = false
    local provider = ns.providers and ns.providers.trinket_cooldown or nil
    if provider and provider.RefreshTrackedAuras then
      provider:RefreshTrackedAuras()
    end
  end)
end

function Manager:GetCooldownStateForSpellID(spellID)
  return nil, self:FindCooldownIDForSpellID(spellID)
end

function Manager:GetAuraStateForSpellID()
  return nil
end

function Manager:GetCacheStats()
  local frameCount, catalogCount = 0, 0
  for _, frames in pairs(self.frameCache) do frameCount = frameCount + #frames end
  self:EnsureCatalog()
  for _ in pairs(self.cooldownInfo) do catalogCount = catalogCount + 1 end
  return { frameCacheEntries = frameCount, auraStateEntries = 0, hookedFrameEntries = 0, catalogEntries = catalogCount }
end

function Manager:Initialize()
  self:RestoreAllHiddenFrames()
  self:Invalidate()
  self:EnsureCatalog()
  if not self.eventFrame then
    local frame = CreateFrame("Frame")
    for _, event in ipairs({
      "COOLDOWN_VIEWER_DATA_LOADED",
      "COOLDOWN_VIEWER_TABLE_HOTFIXED",
      "UPDATE_OVERRIDE_ACTIONBAR",
      "SPELLS_CHANGED",
      "PLAYER_EQUIPMENT_CHANGED",
      "PLAYER_SPECIALIZATION_CHANGED",
    }) do
      pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function()
      self:Invalidate()
      self:ScheduleVisibilityOverrideSync()
      self:ScheduleAuraSourceSync()
      self:ScheduleTrinketSourceSync()
    end)
    self.eventFrame = frame
  end
end
