local _, ns = ...

local BaseRegion = ns.renderers.BaseRegion
local Layouts = ns.renderers.Layouts

local MultiStateRegion = {}
ns.renderers.MultiStateRegion = MultiStateRegion

local function ShallowCopy(source)
  local copy = {}
  for key, value in pairs(type(source) == "table" and source or {}) do
    copy[key] = value
  end
  return copy
end

local function FindTrinketTrigger(aura)
  for _, trigger in ns.TriggerBase:IterateTriggers(aura, "trinket_cooldown") do
    return trigger
  end
  return nil
end

local function BuildPreviewEntries(aura, state)
  local trigger = FindTrinketTrigger(aura)
  local entries = {}
  local function add(key, name)
    local entry = ShallowCopy(state)
    entry.key = key
    entry.name = name
    entry.statusText = "Preview"
    entries[#entries + 1] = entry
  end
  if trigger and trigger.trinketTop ~= false then
    add("trinket_slot_13", "Top Trinket Slot")
  end
  if trigger and trigger.trinketBottom ~= false then
    add("trinket_slot_14", "Bottom Trinket Slot")
  end
  return entries
end

local function CreateChildRegion(aura)
  if aura.kind == "bar" then
    return ns.renderers.BarRegion:New(aura)
  elseif aura.kind == "text" then
    return ns.renderers.TextRegion:New(aura)
  end
  return ns.renderers.IconRegion:New(aura)
end

local function BuildChildAura(aura, key)
  local display = ns.util.Tables.DeepCopy(aura.display or {})
  display.showOnRaidFrames = false
  -- A trinket entry's generic active state means "on cooldown". Its glow is
  -- supplied explicitly by TrinketCooldownProvider while the CDM aura source
  -- is active, so the generic display glow must not also consume that state.
  display.glowWhenActive = false
  return {
    id = aura.id,
    regionKey = tostring(aura.id) .. "_" .. tostring(key),
    name = aura.name,
    kind = aura.kind,
    parentId = aura.parentId or "__multi_state",
    display = display,
    position = aura.position or {},
    text = aura.text or {},
  }
end

local function BuildLayoutAura(aura)
  local layoutAura = ShallowCopy(aura)
  layoutAura.display = ns.util.Tables.DeepCopy(aura.display or {})
  local trigger = FindTrinketTrigger(aura)
  layoutAura.display.growth = trigger and trigger.trinketGrowth or "DOWN"
  return layoutAura
end

local function ReleaseChild(child)
  if not child then return end
  if child.Release then
    child:Release()
  else
    BaseRegion.Release(child)
  end
end

local function GetEntries(aura, state)
  if type(state.entries) == "table" then
    return state.entries
  end
  if state.source == "preview" then
    return BuildPreviewEntries(aura, state)
  end
  return { state }
end

local function IsTimedState(state, now)
  if not state or state.show ~= true then return false end
  if state.trinketEffectActive == true then return true end
  if state.durationObject then return true end
  return state.progressType == "timed" and (state.expirationTime or 0) > now
end

local function HasBaseTimer(state, now)
  if not state or state.show ~= true then return false end
  if state.durationObject then return true end
  return state.progressType == "timed" and (state.expirationTime or 0) > now
end

local function FindTrinketCountdownFontString(entry)
  if not entry or entry.trinketEffectActive ~= true then
    return nil
  end
  local manager = ns.CooldownManager
  if not manager or not manager.FindOnUseEquipSlotFrame then
    return nil
  end
  local frame = manager:FindOnUseEquipSlotFrame(entry.equipSlot, false)
  if not frame or type(frame.GetCooldownFrame) ~= "function" then
    return nil
  end
  local cooldown = frame:GetCooldownFrame()
  if not cooldown or type(cooldown.GetCountdownFontString) ~= "function" then
    return nil
  end
  return cooldown:GetCountdownFontString()
end

local function UpdateTrinketCountdownMirror(child, entry)
  child.trinketCountdownFontString = FindTrinketCountdownFontString(entry)
  if child.trinketCountdownFontString and child.timerText then
    -- CDM's timing values are restricted in Midnight. Keep the value on the
    -- presentation path by copying its rendered text directly to our widget.
    child.timerText:SetText(child.trinketCountdownFontString:GetText())
  end
end

local function RefreshTrinketCountdownMirror(child)
  if child and child.trinketCountdownFontString and child.timerText then
    child.timerText:SetText(child.trinketCountdownFontString:GetText())
    return true
  end
  return false
end

function MultiStateRegion:New(aura)
  local instance = setmetatable({}, { __index = self })
  instance.isMultiStateRegion = true
  instance.frame = BaseRegion:CreateFrame(aura)
  instance.childrenByKey = {}
  instance.activeChildren = {}
  return instance
end

function MultiStateRegion:GetLayoutRegions()
  -- Keep the entries as one layout island when this aura belongs to a group.
  -- PopAuras owns their internal direction while the parent group positions
  -- the island alongside its other children.
  return { self }
end

function MultiStateRegion:Update(aura, state)
  self.currentAura = aura
  self.currentState = state
  BaseRegion:ApplyAnchor(aura, self.frame)
  BaseRegion:ApplyFrameLayer(aura, self.frame)

  local activeKeys = {}
  local children = {}
  local visibleSignature = {}
  local now = GetTime()
  local hasTimedChild = false
  local entries = GetEntries(aura, state)
  local propagateGlow = state.glow == true
  if propagateGlow then
    for _, entry in ipairs(entries) do
      if entry.glow == true then
        propagateGlow = false
        break
      end
    end
  end

  for index, entry in ipairs(entries) do
    local key = tostring(entry.key or ("entry_" .. tostring(index)))
    activeKeys[key] = true
    local child = self.childrenByKey[key]
    if not child then
      child = CreateChildRegion(BuildChildAura(aura, key))
      self.childrenByKey[key] = child
    end

    local childState = ShallowCopy(entry)
    childState.show = state.show == true and entry.show == true
    childState.loadMatched = state.loadMatched
    if state.color then childState.color = state.color end
    if state.desaturate == true then childState.desaturate = true end
    if propagateGlow then childState.glow = true end
    local childAura = BuildChildAura(aura, key)
    child:Update(childAura, childState)
    UpdateTrinketCountdownMirror(child, childState)
    child.layoutVisible = childState.show == true and child.frame:IsShown()
    child.layoutOrder = index
    children[#children + 1] = child
    visibleSignature[#visibleSignature + 1] = table.concat({
      key,
      child.layoutVisible and "1" or "0",
      tostring(child.frame:GetWidth() or 0),
      tostring(child.frame:GetHeight() or 0),
      tostring(aura.position and aura.position.x or 0),
      tostring(aura.position and aura.position.y or 0),
    }, ":")
    hasTimedChild = hasTimedChild or IsTimedState(childState, now)
  end

  for key, child in pairs(self.childrenByKey) do
    if not activeKeys[key] then
      ReleaseChild(child)
      self.childrenByKey[key] = nil
    end
  end

  self.activeChildren = children
  local anyVisible = false
  for _, child in ipairs(children) do
    if child.layoutVisible == true then
      anyVisible = true
      break
    end
  end
  self.layoutVisible = anyVisible

  BaseRegion:ApplyCommonAppearance(aura, self.frame, {
    show = anyVisible,
    active = false,
    glow = false,
  })
  local layoutAura = BuildLayoutAura(aura)
  Layouts.ApplyGroupLayout(layoutAura, self.frame, children)

  local signature = table.concat(visibleSignature, "|") .. "|growth:" .. tostring(layoutAura.display.growth)
  if aura.parentId and signature ~= self._layoutSignature and ns.runtime.ScheduleGroupLayoutRefresh then
    ns.runtime:ScheduleGroupLayoutRefresh(aura.parentId)
  end
  self._layoutSignature = signature

  if hasTimedChild then
    ns.runtime:RegisterTimedRegion(aura.id, self)
  else
    ns.runtime:UnregisterTimedRegion(aura.id)
  end
end

function MultiStateRegion:OnTimerUpdate(now)
  local snapshot = {}
  for index, child in ipairs(self.activeChildren or {}) do snapshot[index] = child end
  for _, child in ipairs(snapshot) do
    if child.OnTimerUpdate and HasBaseTimer(child.currentState, now) then
      child:OnTimerUpdate(now)
    end
    RefreshTrinketCountdownMirror(child)
  end

  for _, child in ipairs(self.activeChildren or {}) do
    if IsTimedState(child.currentState, now) then
      return true
    end
  end
  return false
end

function MultiStateRegion:Release()
  for key, child in pairs(self.childrenByKey or {}) do
    ReleaseChild(child)
    self.childrenByKey[key] = nil
  end
  BaseRegion.Release(self)
end
