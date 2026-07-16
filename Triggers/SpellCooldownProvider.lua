local _, ns = ...

local Safe = ns.SafeValues
local Duration = ns.Duration

local provider = ns.TriggerBase:CreateProvider("spell_cooldown", {
  events = {
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "SPELL_UPDATE_USES",
    "UNIT_SPELLCAST_SUCCEEDED",
    "COOLDOWN_VIEWER_DATA_LOADED",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "PLAYER_TALENT_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    "PLAYER_ENTERING_WORLD",
  },
  manualTimers = {},
})

local EMPTY = {}

local function AddUnique(target, seen, value)
  value = Safe:Number(value)
  if value and value > 0 and not seen[value] then
    seen[value] = true
    target[#target + 1] = value
  end
end

local function GetConfiguredSpellIDs(trigger)
  local result, seen = {}, {}
  for _, value in ipairs(type(trigger and trigger.spellIDs) == "table" and trigger.spellIDs or EMPTY) do
    AddUnique(result, seen, value)
  end
  AddUnique(result, seen, trigger and trigger.spellId)
  return result
end

local function GetSpellInfo(spellID)
  if not C_Spell or not C_Spell.GetSpellInfo then
    return nil
  end
  local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
  if not ok or Safe:IsSecret(info) or type(info) ~= "table" then
    return nil
  end
  return info
end

local function GetNameAndIcon(spellID, auraConfig)
  local info = GetSpellInfo(spellID)
  local name = info and Safe:String(info.name) or nil
  local icon = info and Safe:Number(info.iconID) or nil
  return name or (auraConfig and auraConfig.name) or "Spell Cooldown", icon
end

local function GetAPISpellIDs(spellID)
  local result, seen = {}, {}
  AddUnique(result, seen, spellID)

  if C_Spell and C_Spell.GetOverrideSpell then
    local ok, overrideSpellID = pcall(C_Spell.GetOverrideSpell, spellID)
    if ok then
      AddUnique(result, seen, overrideSpellID)
    end
  end

  local manager = ns.CooldownManager
  if manager and manager.GetCooldownIDsForSpellID and manager.GetCooldownInfo then
    for _, cooldownID in ipairs(manager:GetCooldownIDsForSpellID(spellID)) do
      local info = manager:GetCooldownInfo(cooldownID)
      if type(info) == "table" and not Safe:IsSecret(info) then
        AddUnique(result, seen, info.spellID)
        AddUnique(result, seen, info.overrideSpellID)
        for _, linkedSpellID in ipairs(type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or EMPTY) do
          AddUnique(result, seen, linkedSpellID)
        end
      end
    end
  end
  return result
end

local function ReadCooldown(spellID)
  if not C_Spell or not C_Spell.GetSpellCooldown then
    return nil
  end
  local ok, cooldown = pcall(C_Spell.GetSpellCooldown, spellID)
  if not ok or Safe:IsSecret(cooldown) or type(cooldown) ~= "table" then
    return nil
  end
  return {
    active = Safe:Boolean(cooldown.isActive) == true,
    enabled = Safe:Boolean(cooldown.isEnabled) ~= false,
    onGCD = Safe:Boolean(cooldown.isOnGCD) == true,
    startTime = Safe:Number(cooldown.startTime),
    duration = Safe:Number(cooldown.duration),
  }
end

local function ReadCharges(spellID)
  if not C_Spell or not C_Spell.GetSpellCharges then
    return nil
  end
  local ok, charges = pcall(C_Spell.GetSpellCharges, spellID)
  if not ok or Safe:IsSecret(charges) or type(charges) ~= "table" then
    return nil
  end
  return {
    current = Safe:Number(charges.currentCharges),
    max = Safe:Number(charges.maxCharges),
    active = Safe:Boolean(charges.isActive) == true,
    startTime = Safe:Number(charges.cooldownStartTime),
    duration = Safe:Number(charges.cooldownDuration),
  }
end

local function GetCooldownDurationObject(spellID)
  if not C_Spell or not C_Spell.GetSpellCooldownDuration then
    return nil
  end
  local ok, object = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
  return ok and object or nil
end

local function GetChargeDurationObject(spellID)
  if not C_Spell or not C_Spell.GetSpellChargeDuration then
    return nil
  end
  local ok, object = pcall(C_Spell.GetSpellChargeDuration, spellID)
  return ok and object or nil
end

local function GetDisplayCount(spellID)
  if not C_Spell or not C_Spell.GetSpellDisplayCount then
    return nil, false
  end
  local ok, value = pcall(C_Spell.GetSpellDisplayCount, spellID)
  if not ok then
    return nil, false
  end
  return Safe:Display(value), true
end

local function GetUsable(spellID)
  if not C_Spell or not C_Spell.IsSpellUsable then
    return true
  end
  local ok, usable = pcall(C_Spell.IsSpellUsable, spellID)
  if not ok then
    return true
  end
  local safe = Safe:Boolean(usable)
  return safe == nil or safe
end

local function BuildManualTimer(spellID, timer)
  if type(timer) ~= "table" then
    return nil
  end
  local expirationTime = Safe:Number(timer.expirationTime)
  local duration = Safe:Number(timer.duration)
  if not expirationTime or not duration or duration <= 0 or expirationTime <= GetTime() then
    provider.manualTimers[spellID] = nil
    return nil
  end
  local object = Duration:CreateFromEnd(expirationTime, duration)
  return {
    active = true,
    timerActive = true,
    enabled = true,
    ready = false,
    onGCD = false,
    timer = Duration:BuildTimer(object, "manual", true),
    duration = duration,
    expirationTime = expirationTime,
    source = "manual",
  }
end

local function ReadCandidate(configuredSpellID, apiSpellID, trigger)
  local cooldown = ReadCooldown(apiSpellID)
  local charges = ReadCharges(apiSpellID)
  if not cooldown and not charges then
    return BuildManualTimer(configuredSpellID, provider.manualTimers[configuredSpellID])
  end

  local cooldownActive = cooldown and cooldown.active and not cooldown.onGCD or false
  local currentCharges = charges and charges.current or nil
  local maxCharges = charges and charges.max or nil
  local hasCharges = maxCharges and maxCharges > 1 or false
  local chargeStateKnown = hasCharges and charges ~= nil
  local chargeCountKnown = chargeStateKnown and currentCharges ~= nil
  local chargeActive = chargeStateKnown and charges.active or false
  local outOfCharges = chargeStateKnown and chargeActive and cooldownActive
  local partiallyCharged = chargeStateKnown and chargeActive and not cooldownActive
  if chargeCountKnown then
    outOfCharges = currentCharges <= 0
    partiallyCharged = currentCharges > 0 and currentCharges < maxCharges
  end

  -- Blizzard keeps charge isActive and spell-cooldown isActive non-secret even
  -- when the exact current charge count is restricted. Together they identify
  -- full, partially recharging, and out-of-charges states without inspecting a
  -- secret count. Showing partial recharge is itself an On Cooldown match;
  -- showAlways remains the independent placeholder override.
  local showCharge = trigger.showChargeCooldown ~= false
  local onCooldown
  local ready
  if chargeStateKnown then
    onCooldown = outOfCharges or (partiallyCharged and showCharge)
    ready = not outOfCharges
  else
    onCooldown = cooldownActive
    ready = not onCooldown
  end

  local useCharge = chargeActive and (outOfCharges or (partiallyCharged and showCharge))
  local useSpell = not useCharge and cooldownActive and (not chargeStateKnown or outOfCharges)
  local timerActive = useCharge or useSpell
  local durationObject
  if useCharge then
    durationObject = GetChargeDurationObject(apiSpellID)
  elseif useSpell then
    durationObject = GetCooldownDurationObject(apiSpellID)
  end
  local timer = Duration:BuildTimer(durationObject, useCharge and "charges" or "spell", timerActive)
  local timing = useCharge and charges or (useSpell and cooldown or nil)

  if timer.duration == nil and timing and timing.duration and timing.duration > 0 then
    timer.duration = timing.duration
  end
  if timer.expirationTime == nil and timing and timing.startTime and timer.duration then
    timer.expirationTime = timing.startTime + timer.duration
  end

  -- A zero-span object cannot drive presentation. Known zero charges still
  -- remain an On Cooldown match even if Blizzard supplies no usable timer.
  if timer.zero then
    timerActive = false
    timer.active = false
    timer.object = nil
    if not (chargeStateKnown and outOfCharges) then
      onCooldown = false
      ready = true
    end
  end

  if not timerActive and not chargeStateKnown then
    local manual = BuildManualTimer(configuredSpellID, provider.manualTimers[configuredSpellID])
    if manual then
      return manual
    end
  elseif timerActive then
    provider.manualTimers[configuredSpellID] = nil
  end

  return {
    configuredSpellID = configuredSpellID,
    spellID = apiSpellID,
    active = onCooldown,
    timerActive = timerActive,
    enabled = cooldown == nil or cooldown.enabled,
    ready = ready,
    usable = GetUsable(apiSpellID),
    timer = timer,
    currentCharges = currentCharges,
    maxCharges = maxCharges,
    chargeStateKnown = chargeStateKnown,
    noCharges = chargeStateKnown and outOfCharges or false,
    source = (useCharge or chargeStateKnown) and "charges" or "spell_cooldown",
  }
end

local function CandidateScore(candidate)
  if not candidate then
    return -1
  end
  local score = candidate.active and 100 or 0
  if candidate.timerActive then score = score + 50 end
  if candidate.timer and candidate.timer.object then score = score + 20 end
  if candidate.timer and candidate.timer.expirationTime then score = score + 10 end
  if candidate.enabled then score = score + 2 end
  if candidate.usable then score = score + 1 end
  return score
end

local function AliasCandidateScore(candidate)
  local score = CandidateScore(candidate)
  if candidate and candidate.chargeStateKnown then
    score = score + 200
  end
  return score
end

local function SelectCandidate(trigger)
  local best, bestScore
  for _, configuredSpellID in ipairs(GetConfiguredSpellIDs(trigger)) do
    local aliasBest, aliasBestScore
    for _, apiSpellID in ipairs(GetAPISpellIDs(configuredSpellID)) do
      local candidate = ReadCandidate(configuredSpellID, apiSpellID, trigger)
      local score = AliasCandidateScore(candidate)
      if aliasBest == nil or score > aliasBestScore then
        aliasBest, aliasBestScore = candidate, score
      end
    end
    local score = CandidateScore(aliasBest)
    if best == nil or score > bestScore then
      best, bestScore = aliasBest, score
    end
  end
  return best
end

local function ShouldPersistDisplay(trigger, auraConfig)
  return trigger.showAlways ~= false
    and not (auraConfig and type(auraConfig.triggers) == "table" and #auraConfig.triggers > 1)
end

function provider:Evaluate(trigger, auraConfig)
  local configured = GetConfiguredSpellIDs(trigger)
  if #configured == 0 then
    return ns.Schema.NormalizeRuntimeState({
      show = false,
      matched = false,
      active = false,
      source = "spell_cooldown",
      availability = "unavailable",
      statusText = "No spell configured",
    })
  end

  local candidate = SelectCandidate(trigger)
  local primarySpellID = candidate and candidate.spellID or configured[1]
  local name, icon = GetNameAndIcon(primarySpellID, auraConfig)
  if not candidate then
    return ns.Schema.NormalizeRuntimeState({
      show = ShouldPersistDisplay(trigger, auraConfig),
      matched = false,
      active = false,
      isReady = false,
      name = name,
      icon = icon,
      spellId = primarySpellID,
      source = "spell_cooldown",
      availability = "unavailable",
      statusText = "Cooldown unavailable",
    })
  end

  local matchReady = trigger.cooldownMatch == "ready"
  local matched = matchReady and candidate.ready == true or candidate.active == true
  local show = matched or ShouldPersistDisplay(trigger, auraConfig)
  local timer = candidate.timer or {}
  local duration = Safe:Number(timer.duration) or 0
  local expirationTime = Safe:Number(timer.expirationTime) or 0
  local displayCount, hasDisplayCount = GetDisplayCount(primarySpellID)

  return ns.Schema.NormalizeRuntimeState({
    show = show,
    matched = matched,
    active = candidate.active == true,
    isReady = candidate.ready == true,
    isEnabled = candidate.enabled ~= false,
    isUsable = candidate.usable ~= false,
    desaturate = candidate.usable == false or candidate.enabled == false,
    name = name,
    icon = icon,
    spellId = primarySpellID,
    stacks = candidate.currentCharges or 0,
    maxStacks = candidate.maxCharges,
    noCharges = candidate.noCharges == true,
    stackDisplayValue = displayCount,
    hasStackDisplayValue = hasDisplayCount,
    duration = duration,
    expirationTime = expirationTime,
    durationObject = timer.object,
    timer = timer,
    progressType = candidate.timerActive and "timed" or "static",
    value = duration,
    total = duration,
    source = candidate.source,
    availability = "available",
    statusText = candidate.ready and "Ready" or "On Cooldown",
    debugExtra = string.format("configured=%d api=%d source=%s timer=%s charges=%s/%s opaque=%s",
      configured[1], primarySpellID, tostring(candidate.source), tostring(candidate.timerActive == true),
      tostring(candidate.currentCharges), tostring(candidate.maxCharges), tostring(timer.opaque == true)),
  })
end

function provider:RebuildIndex()
  local bySpellID, all = {}, {}
  for _, auraId in ipairs(ns.Registry:GetFlatOrder()) do
    local aura = ns.Registry:GetAura(auraId)
    for _, trigger in ns.TriggerBase:IterateTriggers(aura, "spell_cooldown") do
      all[#all + 1] = auraId
      for _, spellID in ipairs(GetConfiguredSpellIDs(trigger)) do
        bySpellID[spellID] = bySpellID[spellID] or {}
        bySpellID[spellID][#bySpellID[spellID] + 1] = auraId
      end
    end
  end
  self.indexBySpellID = bySpellID
  self.allAuraIDs = all
end

function provider:InvalidateCaches()
  self.indexBySpellID = nil
  self.allAuraIDs = nil
end

function provider:GetAffectedAurasForSpellIDs(spellIDs)
  if not self.indexBySpellID then
    self:RebuildIndex()
  end
  local result, seen = {}, {}
  for _, spellID in ipairs(spellIDs or EMPTY) do
    spellID = Safe:Number(spellID)
    for _, auraId in ipairs(spellID and self.indexBySpellID[spellID] or EMPTY) do
      if not seen[auraId] then
        seen[auraId] = true
        result[#result + 1] = auraId
      end
    end
  end
  return result
end

function provider:HandleEvent(event, ...)
  if event == "COOLDOWN_VIEWER_DATA_LOADED" or event == "UPDATE_OVERRIDE_ACTIONBAR"
    or event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
    if ns.CooldownManager and ns.CooldownManager.Invalidate then
      ns.CooldownManager:Invalidate()
    end
    self.indexBySpellID = nil
    self.allAuraIDs = nil
    return true
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if Safe:String(unit) ~= "player" then
      return {}
    end
    spellID = Safe:Number(spellID)
    if not spellID then
      return {}
    end
    if not self.indexBySpellID then self:RebuildIndex() end
    for _, auraId in ipairs(self.indexBySpellID[spellID] or EMPTY) do
      local aura = ns.Registry:GetAura(auraId)
      for _, trigger in ns.TriggerBase:IterateTriggers(aura, "spell_cooldown") do
        local manual = Safe:Number(trigger.manualCooldown)
        if manual and manual > 0 then
          self.manualTimers[spellID] = { duration = manual, expirationTime = GetTime() + manual }
        end
      end
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if ns.runtime then ns.runtime:RefreshAuras(self:GetAffectedAurasForSpellIDs({ spellID })) end
      end)
    end
    return self:GetAffectedAurasForSpellIDs({ spellID })
  end

  local spellIDs = {}
  for index = 1, select("#", ...) do
    local value = Safe:Number(select(index, ...))
    if value and value > 0 then
      spellIDs[#spellIDs + 1] = value
    end
  end
  if #spellIDs > 0 then
    return self:GetAffectedAurasForSpellIDs(spellIDs)
  end
  if not self.allAuraIDs then self:RebuildIndex() end
  return self.allAuraIDs
end

function provider:GetAffectedAuras(event, ...)
  return self:HandleEvent(event, ...)
end

function provider:LogCooldownRenderDebug(aura, state, _, eventName, extra)
  if not aura or not state or not ns.Debug or not ns.Debug.LogTrigger then
    return
  end
  local _, trigger = ns.TriggerBase:AnyTriggerMatches(aura, "spell_cooldown")
  if trigger and trigger.debug == true then
    ns.Debug:LogTrigger(aura, trigger, state, string.format("%s %s", tostring(eventName or "render"), tostring(extra or "")))
  end
end

function provider:ResolveCooldownDebugSpellID(value)
  local numeric = tonumber(value)
  if numeric and numeric > 0 then return numeric end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, value)
    if ok and not Safe:IsSecret(info) and type(info) == "table" then
      local spellID = Safe:Number(info.spellID)
      if spellID and spellID > 0 then return spellID end
    end
  end
  return nil, "Unable to resolve that spell. Use its numeric spell ID."
end

function provider:SetCooldownDebugSpell(spellID)
  self.debugSpellID = Safe:Number(spellID)
  self.debugHistory = {}
  self:CaptureCooldownDebugSnapshot("watch_started")
end

function provider:ClearCooldownDebugSpell()
  self.debugSpellID = nil
  self.debugHistory = {}
end

function provider:GetCooldownDebugSpellLabel()
  if not self.debugSpellID then return "none" end
  local name = GetNameAndIcon(self.debugSpellID)
  return string.format("%s (%d)", tostring(name), self.debugSpellID)
end

function provider:GetCooldownDebugStatusLine()
  if not self.debugSpellID then return "Cooldown debug watch is off." end
  return string.format("Watching %s; snapshots=%d", self:GetCooldownDebugSpellLabel(), #(self.debugHistory or EMPTY))
end

function provider:CaptureCooldownDebugSnapshot(reason)
  if not self.debugSpellID then return false end
  local candidate = ReadCandidate(self.debugSpellID, self.debugSpellID, { showChargeCooldown = true })
  local timer = candidate and candidate.timer or {}
  local line = string.format("%s spell=%d active=%s timer=%s ready=%s enabled=%s charges=%s/%s source=%s duration=%s expiration=%s object=%s opaque=%s",
    tostring(reason or "snapshot"), self.debugSpellID,
    tostring(candidate and candidate.active == true), tostring(candidate and candidate.timerActive == true),
    tostring(candidate and candidate.ready == true),
    tostring(candidate and candidate.enabled ~= false),
    tostring(candidate and candidate.currentCharges or ""), tostring(candidate and candidate.maxCharges or ""),
    tostring(candidate and candidate.source or "none"),
    tostring(timer.duration or ""), tostring(timer.expirationTime or ""),
    tostring(timer.object ~= nil), tostring(timer.opaque == true))
  self.debugHistory = self.debugHistory or {}
  self.debugHistory[#self.debugHistory + 1] = line
  if #self.debugHistory > 100 then table.remove(self.debugHistory, 1) end
  if ns.Debug then ns.Debug:Log("Cooldown", line) end
  return true
end

function provider:ShowCooldownDebugHistory()
  if not self.debugSpellID then return end
  if ns.Debug and ns.Debug.ShowSnapshot then
    ns.Debug:ShowSnapshot("Cooldown: " .. self:GetCooldownDebugSpellLabel(), self.debugHistory or {}, false)
  end
end
