-- Standalone Lua regression: run from the repository root with lua tests/NativeAuraRegion.lua.
local ns = { renderers = {}, util = {}, runtime = {} }
local function noop() end
local secret = setmetatable({}, {
  __tostring = function() error("secret formatted") end,
  __lt = function() error("secret compared") end,
  __add = function() error("secret arithmetic") end,
})
function issecretvalue(value) return rawequal(value, secret) end
local now = 1
function GetTime() return now end
Enum = { StatusBarInterpolation = { Immediate = 0 }, StatusBarTimerDirection = { RemainingTime = 1 } }
function hooksecurefunc(owner, key, hook)
  local original = assert(owner[key], key)
  owner[key] = function(self, ...)
    local result = original(self, ...)
    hook(self, ...)
    return result
  end
end
local methods = {}
for _, name in ipairs({ "SetAllPoints", "SetPoint", "ClearAllPoints", "SetClipsChildren", "EnableMouse",
  "SetAlpha", "SetTexture", "SetVertexColor", "SetStatusBarColor", "SetStatusBarTexture", "SetRotation",
  "SetHideCountdownNumbers", "SetDrawSwipe", "SetDrawEdge", "SetDrawBling", "SetRotatesTexture",
  "SetIcon", "SetSpellName", "SetApplicationCount", "SetDurationText", "SetDurationCooldown",
  "SetDurationBar", "SetCancelAuraButtons", "ClearSpellName", "SetParentKey" }) do
  methods[name] = function(self, ...) assert(not self.forbidden, "forbidden native mutation: " .. name) end
end
function methods:Show() self.shown = true end
function methods:Hide() assert(not self.forbidden, "forbidden native hide"); self.shown = false end
function methods:SetShown(value) self.shown = value == true end
function methods:IsShown() return self.shown end
function methods:SetSize(w,h) self.width, self.height = w,h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetFrameLevel(value) self.level = value end
function methods:GetFrameLevel() return self.level end
function methods:SetOrientation(value) self.orientation = value end
function methods:SetReverseFill(value) self.reverse = value end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:SetFormattedText(format, value) self.displayValue = value end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:GetMinMaxValues() return self.minimum, self.maximum end
function methods:SetValue(value) self.value = value; self.durationObject = nil end
function methods:GetValue() return self.value end
function methods:SetTimerDuration(object) self.durationObject = object end
function methods:SetCooldownFromDurationObject(object) self.durationObject = object end
function methods:Clear() self.durationObject = nil end
local function widget() return setmetatable({ level = 1, width = 20, height = 150, shown = false }, { __index = methods }) end
function methods:CreateTexture() return widget() end
function methods:CreateFontString() return widget() end
function CreateFrame() return widget() end
C_Spell = { GetSpellInfo = function() return { name = "Heart of the Jade Serpent", iconID = 123 } end }
C_DurationUtil = { CreateDurationTextBinding = function()
  return {
    SetToDefaults = noop, SetFormatter = noop, SetUpdateInterval = noop, SetExpiredText = noop,
    SetZeroDurationText = noop,
    SetFontString = function(self, value) self.font = value end,
    SetDuration = function(self, value) self.object = value end,
    SetEnabled = function(self, value) self.enabled = value end,
  }
end }
local function opaque() return setmetatable({}, { __index = function() error("opaque duration inspected") end }) end
local duration = opaque()
local durationCalls = 0
C_UnitAuras = { GetAuraDuration = function(unit, instanceID)
  assert(unit == "player"); assert(instanceID == 77)
  durationCalls = durationCalls + 1
  return duration
end }
ns.util.Colors = { Apply = noop }
ns.util.Fonts = { ApplyStyle = noop }
ns.util.Media = { ResolveStatusBarTexture = function() return "texture" end }
ns.util.Frames = { SetExplicitBounds = noop, ConfigureBarTextBounds = noop }
ns.renderers.BaseRegion = { CreateFrame = widget, ApplyAnchor = noop, ApplyFrameLayer = noop, CanMove = function() return false end }
ns.runtime.UnregisterTimedRegion = noop
ns.runtime.RegisterTimedRegion = noop
ns.runtime.SetNativeAuraSourceUnit = noop
local layouts = 0
ns.runtime.ScheduleGroupLayoutRefresh = function() layouts = layouts + 1 end
ns.TextResolver = { GetTimerText = function() return "preview" end }
ns.NativeAuras = {
  IsAvailable = function() return true end,
  CreateContainer = function()
    local container = widget()
    container.filterWrites = 0
    function container:SetEnabled(value)
      if value == false and self.enabled and self.assigned then error("disabled before secure clear") end
      self.enabled = value
      if value and self.filters and next(self.filters.includeSpellIDs) then
        self.assigned = true
        if self.button then self.button.forbidden = true end
      end
    end
    function container:SetAuraSlotCandidateFilters(_, filters)
      self.filterWrites = self.filterWrites + 1
      self.filters = filters
      if not next(filters.includeSpellIDs) then self.assigned = false end
    end
    function container:AddAuraSlot(_, _, options)
      self.filters = options.candidateFilters
      local button = widget()
      options.initializeFrame(button)
      self.button = button
      return button
    end
    container.SetUnit = noop
    container.SetAuraSlotFilterString = noop
    container.UpdateAllAuras = noop
    return container
  end,
}
for _, file in ipairs({ "Core/SafeValues.lua", "Data/SpellAuraAliases.lua", "Util/Spells.lua",
    "Engine/TimerPresenter.lua", "Core/CooldownManager.lua", "Renderers/NativeAuraRegion.lua" }) do
  assert(loadfile(file))("PopAuras", ns)
end
local manager = ns.CooldownManager
manager.EnsureActive = noop
manager.ScheduleVisibilityOverrideSync = noop
manager.spellToCooldownIDs = { [443421] = { 7 }, [1238904] = { 8 } }
manager.directSpellToCooldownIDs = manager.spellToCooldownIDs
manager.cooldownInfo = {}; manager.onUseEquipSlotCooldownIDs = {}
local frames = {}
BuffIconCooldownViewer = { GetChildren = function() return (table.unpack or unpack)(frames) end }
BuffBarCooldownViewer = { GetChildren = function() end }
local function source(id, bar)
  local owner = { cooldownID = id, active = false, unit = "player", instanceID = 77,
    viewerFrame = bar and BuffBarCooldownViewer or BuffIconCooldownViewer, count = widget(), bar = bar }
  function owner:IsActive() return self.active end
  function owner:SetIsActive(value) self.active = value end
  function owner:GetAuraDataUnit() return self.unit end
  function owner:GetAuraSpellID() error("renderer must not read aura spell ID") end
  function owner:GetAuraSpellInstanceID() return self.instanceID end
  function owner:GetApplicationsFontString() return self.count end
  if bar then function owner:GetBarFrame() return self.bar end
  else function owner:GetCooldownFrame() return self.count end end
  return owner
end
local aura = ACTUAL_AURA or {
  id = "jade", name = "Jade", parentId = "group", kind = "bar", text = { nameOverride = "HotJS", label = "%n" },
  position = { width = 20, height = 150 },
  display = { color = {r=0,g=1,b=1}, backgroundColor = {r=0,g=0,b=0}, orientation = "VERTICAL",
    showName = true, showTimer = true, nameRotation = 90, iconMatchBarSize = true, timerDecimals = 0 },
  triggers = { { type = "aura", unit = "player", auraType = "buff", spellId = 443421 } },
}
local Region = ns.renderers.NativeAuraRegion
assert(Region:CanHandle(aura))
local icon = source(7)
frames[1] = icon
local region = Region:New(aura)
local unavailable = { source = "aura", availability = "unavailable", show = false, active = false, loadMatched = true }
region:Update(aura, unavailable)
assert(region.cdmMode and region.nativeSuppressed and not region.fallback.shown, "inactive CDM must own presentation")
local initialFilters = region.container.filterWrites
icon:SetIsActive(true)
assert(region.fallback.shown and region.layoutVisible, "tracked icon must show the aura bar in combat")
assert(region.fallback.bar.durationObject == duration, "bar must receive opaque object")
assert(region.fallback.timerText._popAurasDurationBinding.object == duration, "text must receive opaque object")
assert(region.fallback.cooldown.durationObject == duration, "swipe must receive opaque object")
assert(region.fallback.nameText.text == "HotJS" and region.fallback.bar.orientation == "VERTICAL")
icon.count:SetText(secret)
assert(rawequal(region.fallback.countText.text, secret), "secret display text must be mirrored")
duration = opaque()
icon:SetIsActive(true)
assert(region.fallback.bar.durationObject == duration, "refresh without an active transition must update duration")
icon:SetIsActive(false)
assert(not region.fallback.shown and not region.layoutVisible)
assert(not region.fallback.timerText._popAurasDurationBinding.enabled)
assert(region.fallback.cooldown.durationObject == nil)
assert(region.container.filterWrites == initialFilters, "active transitions must not rebuild native filters")
aura.triggers[1].showAlways = true
region:Update(aura, unavailable)
assert(region.fallback.shown and region.layoutVisible)
aura.triggers[1].showAlways = false
region:Update(aura, unavailable)
icon:SetIsActive(true)
icon.unit = "target"
region:SyncCDMSource()
assert(not region.fallback.shown and not region.layoutVisible, "target mismatch must clear player presentation")
icon.unit = "player"
-- A combat-restricted instance must never be queried, and must not leave
-- both renderers disabled. Keep native duration ownership after restrictions
-- lift, avoiding repeated native/CDM handoffs on subsequent combat events.
local restricted = Region:New(aura)
restricted:Update(aura, unavailable)
icon.instanceID = secret
local previousCalls = durationCalls
restricted:SyncCDMSource()
assert(durationCalls == previousCalls, "secret instance IDs must not be queried")
assert(restricted.nativeDurationRequired and not restricted.nativeSuppressed and restricted.container.assigned,
  "restricted instance must leave the exact native aura slot enabled")
assert(restricted.layoutVisible and not restricted.fallback.shown)
icon.instanceID = 77
restricted:SyncCDMSource()
assert(restricted.nativeDurationRequired and not restricted.nativeSuppressed, "native ownership must stay stable")
restricted:Update(aura, unavailable)
assert(not restricted.nativeSuppressed, "full render must not suppress native duration again")
restricted:RefreshNativeUnit("player")
assert(not restricted.nativeSuppressed, "native refresh must retain chosen duration authority")
restricted:Release()
assert(restricted.nativeSuppressed and not restricted.container.assigned, "release must securely clear the native slot")
region:SyncCDMSource()
assert(region.fallback.shown)
-- The duration API may reject an otherwise readable instance during combat.
local denied = Region:New(aura)
denied:Update(aura, unavailable)
local getDuration = C_UnitAuras.GetAuraDuration
C_UnitAuras.GetAuraDuration = function() error("restricted aura access") end
denied:SyncCDMSource()
assert(denied.nativeDurationRequired and not denied.nativeSuppressed and denied.container.assigned,
  "duration API rejection must preserve native presentation")
C_UnitAuras.GetAuraDuration = getDuration
denied:Release()
icon.cooldownID = 99
region:SyncCDMSource()
assert(not region.fallback.shown, "recycled frame must not drive a different aura")
local replacement = source(7)
replacement.active = true
frames[1] = replacement
region:RefreshCDMSource("player")
assert(region.cdmSource == replacement and region.fallback.shown, "recycled frame cache must discover its replacement")
icon:SetIsActive(false)
assert(region.fallback.shown, "recycled source hook must not affect the replacement")
icon = replacement
local alternate = source(8)
alternate.active = true
frames[2] = alternate
icon.active = false
manager.frameCache = {}
region:RefreshCDMSource("player")
assert(region.cdmSource == alternate and region.fallback.shown, "alternate buff ID must resolve to the active tracked icon")
icon:SetIsActive(false)
assert(region.fallback.shown, "old source hook must be inert")
region:Update(aura, { loadMatched = false })
assert(not region.fallback.shown and not region.layoutVisible and region.nativeSuppressed)
alternate:SetIsActive(true)
assert(not region.fallback.shown, "unloaded source hook must be inert")
region:Update(aura, { source = "preview", name = "Preview", stacks = 3 })
assert(region.fallback.shown and region.cdmSource == nil and region.nativeSuppressed)
region:Release()
assert(not region.fallback.shown)
-- No viewer at first: native stays authoritative, then an icon acquired after
-- the initial cached miss takes over through a secure empty-filter release.
frames = {}; manager.frameCache = {}
local late = Region:New(aura)
late:Update(aura, unavailable)
assert(not late.nativeSuppressed and late.container.assigned)
frames[1] = source(7); frames[1].active = true
late:RefreshCDMSource("player")
assert(late.fallback.shown and late.nativeSuppressed and not late.container.assigned)
-- Existing bar sources retain direct secret-safe widget mirroring.
local bar = widget(); bar:SetMinMaxValues(0, secret); bar:SetValue(secret)
local barSource = source(7, bar); barSource.active = true
late:BindCDMSource(barSource, 7); late:SyncCDMSource()
assert(late.fallback.shown and rawequal(late.fallback.bar.value, secret))
bar:SetValue(secret)
assert(rawequal(late.fallback.bar.value, secret))
late:Release()
barSource:SetIsActive(true)
assert(not late.fallback.shown)
assert(layouts > 0, "CDM active changes must refresh ancestor layout")
print("Native aura CDM regressions passed (icon, bar, refresh, expiry, aliases, secrets, recycle, unload, preview, late acquisition).")
