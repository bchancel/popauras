local _, ns = ...

local Tracker = {}
ns.InterruptTracker = Tracker

local Strings = ns.util.Strings

local PREFIX = "BliZziIT"
local HEADER = "B1"
local SEPARATOR = ";"

Tracker.members = {}
Tracker.revision = 0

local recentCasts = {}
local signalTape = {}
local signalSeq = 0
local needsCorrelation = false
local lastCorrelateAt = 0

local SIGNAL_RETENTION = 0.35
local CORRELATE_INTERVAL = 0.04
local MATCH_WINDOW = 0.055
local AURA_SUPPRESS_WINDOW = 0.028
local INTERRUPT_CLUSTER_WINDOW = 0.018
local OWN_PLAYER_INTERRUPT_PROTECT_WINDOW = 0.30
local PARTY_INTERRUPT_MAX_RANGE = 35
local INSPECT_TIMEOUT_SECONDS = 1.5

local SAFE_CLASS_FALLBACKS = {
  DEATHKNIGHT = true,
  DEMONHUNTER = true,
  EVOKER = true,
  MAGE = true,
  ROGUE = true,
  WARRIOR = true,
}

local function SafeShortName(name)
  if Strings and Strings.GetSafeShortPlayerName then
    return Strings.GetSafeShortPlayerName(name)
  end
  if issecretvalue and issecretvalue(name) then
    return nil
  end
  if type(name) ~= "string" then
    return nil
  end
  if name == "" then
    return nil
  end
  if Ambiguate then
    local shortName = Ambiguate(name, "short")
    if issecretvalue and issecretvalue(shortName) then
      return nil
    end
    if type(shortName) ~= "string" or shortName == "" then
      return nil
    end
    return shortName
  end
  return name
end

local function GetSafeUnitShortName(unit)
  if Strings and Strings.GetSafeUnitDisplayName then
    return Strings.GetSafeUnitDisplayName(unit, false)
  end
  return SafeShortName(UnitName(unit))
end

local function GetSafeWhisperTarget(unit)
  if Strings and Strings.GetSafeUnitDisplayName then
    return Strings.GetSafeUnitDisplayName(unit, true)
  end

  local name, realm = UnitFullName and UnitFullName(unit)
  if issecretvalue and (issecretvalue(name) or issecretvalue(realm)) then
    return nil
  end
  if type(name) ~= "string" then
    return nil
  end
  if name == "" then
    return nil
  end
  if type(realm) == "string" and realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

local function PushSignal(kind, unit)
  signalSeq = signalSeq + 1
  signalTape[#signalTape + 1] = {
    seq = signalSeq,
    kind = kind,
    unit = unit,
    at = GetTime(),
    consumed = false,
  }
  needsCorrelation = true
end

local function PruneSignalTape(now)
  local keepFrom = now - SIGNAL_RETENTION
  local kept = {}
  for index = 1, #signalTape do
    local signal = signalTape[index]
    if signal and signal.at and signal.at >= keepFrom then
      kept[#kept + 1] = signal
    end
  end
  signalTape = kept
end

local function ResolveCastOwnerUnit(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil
  end
  if unit == "player" or unit == "pet" then
    return "player"
  end
  local partyIndex = unit:match("^partypet(%d+)$")
  if partyIndex then
    return "party" .. partyIndex
  end
  if unit:match("^party%d+$") then
    return unit
  end
  return nil
end

local function ResolveObservedMemberName(unit)
  local ownerUnit = ResolveCastOwnerUnit(unit)
  if not ownerUnit then
    return nil, nil
  end
  if ownerUnit == "player" then
    return Tracker.playerName, ownerUnit
  end
  return GetSafeUnitShortName(ownerUnit), ownerUnit
end

local function FindPartyUnitByGuid(guid)
  if type(guid) ~= "string" or guid == "" then
    return nil
  end
  for index = 1, 4 do
    local unit = "party" .. index
    if UnitExists(unit) and UnitGUID(unit) == guid then
      return unit
    end
  end
  return nil
end

local function GetSafeClassFallbackInterrupt(classToken)
  if not (classToken and SAFE_CLASS_FALLBACKS[classToken]) then
    return nil
  end
  return ns.Interrupts and ns.Interrupts.GetInterruptForClass and ns.Interrupts:GetInterruptForClass(classToken) or nil
end

local function GetTrackedSpellID(member)
  local spellID = tonumber(member and member.spellID or 0) or 0
  if spellID > 0 then
    return spellID
  end
  local fallback = GetSafeClassFallbackInterrupt(member and member.class or nil)
  return fallback and fallback.spellID or nil
end

local function ResetMemberCooldownState(member)
  if type(member) ~= "table" then
    return false
  end

  local changed = false
  if (tonumber(member.cdEnd or 0) or 0) ~= 0 then
    member.cdEnd = 0
    changed = true
  end
  if member.pendingKick ~= false then
    member.pendingKick = false
    changed = true
  end
  if member.pendingToken ~= nil then
    member.pendingToken = nil
    changed = true
  end
  if member.kickResult ~= nil then
    member.kickResult = nil
    changed = true
  end
  return changed
end

local function GetSafeInspectSpecID(unit)
  if type(unit) ~= "string" or unit == "" or not (GetInspectSpecialization and UnitExists and UnitExists(unit)) then
    return nil
  end

  local ok, specID = pcall(GetInspectSpecialization, unit)
  specID = tonumber(specID or 0) or 0
  if not ok or specID <= 0 then
    return nil
  end
  return specID
end

local function ApplyInterruptInfoToMember(member, info, specID)
  if type(member) ~= "table" or type(info) ~= "table" then
    return false
  end

  local changed = false
  if specID ~= nil and member.specID ~= specID then
    member.specID = specID
    changed = true
  end
  if member.noInterrupt ~= nil then
    member.noInterrupt = nil
    changed = true
  end
  if member.class ~= info.class then
    member.class = info.class
    changed = true
  end
  if member.spellID ~= info.spellID then
    member.spellID = info.spellID
    changed = true
    if ResetMemberCooldownState(member) then
      changed = true
    end
  end
  if member.baseCd ~= info.cd then
    member.baseCd = info.cd
    changed = true
  end
  return changed
end

local function ApplyNoInterruptToMember(member, specID)
  if type(member) ~= "table" then
    return false
  end

  local changed = false
  if specID ~= nil and member.specID ~= specID then
    member.specID = specID
    changed = true
  end
  if member.noInterrupt ~= true then
    member.noInterrupt = true
    changed = true
  end
  if member.spellID ~= nil then
    member.spellID = nil
    changed = true
  end
  if member.baseCd ~= nil then
    member.baseCd = nil
    changed = true
  end
  if ResetMemberCooldownState(member) then
    changed = true
  end
  return changed
end

local function RefreshMemberInterruptFromUnit(member, unit, classToken)
  local specID = GetSafeInspectSpecID(unit)
  if specID then
    local specInfo = ns.Interrupts and ns.Interrupts.GetInterruptForSpec and ns.Interrupts:GetInterruptForSpec(specID) or nil
    if specInfo then
      return ApplyInterruptInfoToMember(member, specInfo, specID)
    end
    if ns.Interrupts and ns.Interrupts.SPEC_NO_INTERRUPT and ns.Interrupts.SPEC_NO_INTERRUPT[specID] then
      return ApplyNoInterruptToMember(member, specID)
    end
  end

  local fallback = GetSafeClassFallbackInterrupt(classToken)
  if fallback and (tonumber(member.spellID or 0) or 0) <= 0 and member.noInterrupt ~= true then
    return ApplyInterruptInfoToMember(member, fallback, specID)
  end

  return false
end

local function GetLiveCooldownEnd(spellID)
  if not (spellID and C_Spell and C_Spell.GetSpellCooldown) then
    return nil
  end

  local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
  if not ok or type(info) ~= "table" then
    return nil
  end

  local startTime = info.startTime
  local duration = info.duration
  local isActive = info.isActive
  if issecretvalue and (issecretvalue(startTime) or issecretvalue(duration) or issecretvalue(isActive)) then
    return nil
  end

  startTime = tonumber(startTime or 0) or 0
  duration = tonumber(duration or 0) or 0
  if startTime <= 0 or duration <= 0 then
    return nil
  end
  if isActive ~= nil and isActive ~= true then
    return nil
  end

  return startTime + duration
end

local function ResolveObservedInterruptSpellID(memberName, rawSpellID)
  local resolvedSpellID = nil
  if rawSpellID ~= nil and not (issecretvalue and issecretvalue(rawSpellID)) then
    resolvedSpellID = ns.Interrupts and ns.Interrupts.ResolveSpellID and ns.Interrupts:ResolveSpellID(rawSpellID) or nil
  end
  if resolvedSpellID then
    return resolvedSpellID
  end

  local member = memberName and Tracker.members and Tracker.members[memberName] or nil
  local memberSpellID = tonumber(GetTrackedSpellID(member) or 0) or 0
  if memberSpellID > 0 then
    local cdEnd = tonumber(member and member.cdEnd or 0) or 0
    if cdEnd > (GetTime() + 0.05) then
      return nil
    end
    return memberSpellID
  end

  local fallback = GetSafeClassFallbackInterrupt(member and member.class or nil)
  return fallback and fallback.spellID or nil
end

local function CopyEntry(target, source)
  local changed = false
  for key, value in pairs(source) do
    if target[key] ~= value then
      target[key] = value
      changed = true
    end
  end
  return changed
end

local function BuildMessage(...)
  return table.concat({ HEADER, ... }, SEPARATOR)
end

local function ResolveBaseCooldown(spellID, fallback)
  local info = ns.Interrupts and ns.Interrupts.GetSpellInfo and ns.Interrupts:GetSpellInfo(spellID) or nil
  return tonumber(fallback or (info and info.cd) or 0) or 0
end

local function QueueTrackerRefresh()
  if Tracker.refreshQueued == true or not (C_Timer and C_Timer.After) then
    return
  end

  Tracker.refreshQueued = true
  C_Timer.After(0, function()
    Tracker.refreshQueued = false
    if not (ns.Registry and ns.Registry.CollectAuraIds and ns.runtime and ns.runtime.RefreshAuras) then
      return
    end

    local auraIds = ns.Registry:CollectAuraIds(function(aura)
      return aura.kind == "interrupt_tracker"
    end)
    if #auraIds > 0 then
      ns.runtime:RefreshAuras(auraIds)
    end
  end)
end

function Tracker:MarkDirty()
  self.revision = (self.revision or 0) + 1
  QueueTrackerRefresh()
end

function Tracker:GetRevision()
  return self.revision or 0
end

function Tracker:GetOrCreateMember(name)
  if not name then
    return nil
  end
  self.members[name] = self.members[name] or { name = name, cdEnd = 0 }
  return self.members[name]
end

function Tracker:RemoveMember(name)
  if name and self.members[name] then
    self.members[name] = nil
    self:MarkDirty()
  end
end

function Tracker:RefreshLocalPlayer()
  local name = GetSafeUnitShortName("player")
  local info = ns.Interrupts and ns.Interrupts.GetPlayerInterrupt and ns.Interrupts:GetPlayerInterrupt() or nil
  local _, classToken = UnitClass("player")
  self.playerName = name
  self.playerGuid = UnitGUID("player")
  self.playerClass = classToken
  self.playerSpellID = info and info.spellID or nil
  self.playerBaseCd = info and info.cd or nil

  if not name then
    return
  end

  local member = self:GetOrCreateMember(name)
  local changed = false
  local nextClass = info and info.class or classToken
  local nextSpellID = info and info.spellID or nil
  local nextBaseCd = info and info.cd or nil

  if member.class ~= nextClass then
    member.class = nextClass
    changed = true
  end
  if member.spellID ~= nextSpellID then
    member.spellID = nextSpellID
    changed = true
    if ResetMemberCooldownState(member) then
      changed = true
    end
  end
  if member.baseCd ~= nextBaseCd then
    member.baseCd = nextBaseCd
    changed = true
  end
  if member.isLocal ~= true then
    member.isLocal = true
    changed = true
  end
  if member.orderIndex ~= 1 then
    member.orderIndex = 1
    changed = true
  end
  if member.specID ~= nil then
    member.specID = nil
    changed = true
  end
  if member.noInterrupt ~= nil then
    member.noInterrupt = nil
    changed = true
  end

  if nextSpellID == nil then
    if ResetMemberCooldownState(member) then
      changed = true
    end
  end

  if changed then
    self:MarkDirty()
  end
end

function Tracker:RefreshGroupRoster()
  local keep = {}
  local changed = false

  if self.playerName then
    keep[self.playerName] = true
  end

  for index = 1, 4 do
    local unit = "party" .. index
    if UnitExists(unit) then
      local name = GetSafeUnitShortName(unit)
      if name then
        keep[name] = true
        local _, classToken = UnitClass(unit)
        local member = self:GetOrCreateMember(name)
        if CopyEntry(member, { class = classToken, isLocal = false, orderIndex = index + 1 }) then
          changed = true
        end
        if RefreshMemberInterruptFromUnit(member, unit, classToken) then
          changed = true
        elseif member.specID == nil and not GetTrackedSpellID(member) then
          self:EnqueueInspectUnit(unit)
        end
      end
    end
  end

  for name in pairs(self.members) do
    if not keep[name] then
      self.members[name] = nil
      changed = true
    end
  end

  if changed then
    self:MarkDirty()
  end
end

function Tracker:ProcessInspectQueue()
  if self.inspectPendingGuid or not (NotifyInspect and CanInspect) then
    return
  end

  self.inspectQueue = self.inspectQueue or {}
  self.inspectQueuedGuids = self.inspectQueuedGuids or {}

  while #self.inspectQueue > 0 do
    local guid = table.remove(self.inspectQueue, 1)
    self.inspectQueuedGuids[guid] = nil

    local unit = FindPartyUnitByGuid(guid)
    if unit and CanInspect(unit) then
      local ok = pcall(NotifyInspect, unit)
      if not ok then
        if ClearInspectPlayer then
          pcall(ClearInspectPlayer)
        end
      else
        self.inspectPendingGuid = guid
        self.inspectPendingUnit = unit

        if C_Timer and C_Timer.After then
          C_Timer.After(INSPECT_TIMEOUT_SECONDS, function()
            if Tracker.inspectPendingGuid ~= guid then
              return
            end
            Tracker.inspectPendingGuid = nil
            Tracker.inspectPendingUnit = nil
            if ClearInspectPlayer then
              pcall(ClearInspectPlayer)
            end
            Tracker:ProcessInspectQueue()
          end)
        end
        return
      end
    end
  end
end

function Tracker:EnqueueInspectUnit(unit)
  if type(unit) ~= "string" or not unit:match("^party%d+$") or not (NotifyInspect and CanInspect) then
    return
  end
  if not UnitExists(unit) or not UnitIsPlayer(unit) or not CanInspect(unit) then
    return
  end

  local guid = UnitGUID(unit)
  if type(guid) ~= "string" or guid == "" or guid == self.playerGuid then
    return
  end

  self.inspectQueue = self.inspectQueue or {}
  self.inspectQueuedGuids = self.inspectQueuedGuids or {}

  if self.inspectPendingGuid == guid or self.inspectQueuedGuids[guid] == true then
    return
  end

  self.inspectQueuedGuids[guid] = true
  self.inspectQueue[#self.inspectQueue + 1] = guid
  self:ProcessInspectQueue()
end

function Tracker:HandleInspectReady(guid)
  if type(guid) ~= "string" or guid == "" or guid ~= self.inspectPendingGuid then
    return
  end

  local changed = false
  local unit = FindPartyUnitByGuid(guid) or self.inspectPendingUnit
  if unit and UnitExists(unit) then
    local name = GetSafeUnitShortName(unit)
    local _, classToken = UnitClass(unit)
    local member = name and self:GetOrCreateMember(name) or nil
    if member then
      local orderIndex = tonumber(unit:match("^party(%d+)$") or 0) or 0
      if CopyEntry(member, {
        class = classToken,
        isLocal = false,
        orderIndex = orderIndex > 0 and (orderIndex + 1) or member.orderIndex,
      }) then
        changed = true
      end
      if RefreshMemberInterruptFromUnit(member, unit, classToken) then
        changed = true
      end
    end
  end

  self.inspectPendingGuid = nil
  self.inspectPendingUnit = nil
  if ClearInspectPlayer then
    pcall(ClearInspectPlayer)
  end
  if changed then
    self:MarkDirty()
  end
  self:ProcessInspectQueue()
end

function Tracker:Transmit(payload)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return
  end

  local function TrySend(channel, target)
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, channel, target)
    return ok == true and result == 0
  end

  local inHome = IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME) or false
  local inInstance = IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or false

  if inInstance and TrySend("INSTANCE_CHAT") then
    return
  end
  if (inHome or inInstance) and TrySend("PARTY") then
    return
  end

  for index = 1, 4 do
    local unit = "party" .. index
    if UnitExists(unit) and UnitIsPlayer(unit) then
      local target = GetSafeWhisperTarget(unit)
      if target then
        TrySend("WHISPER", target)
      end
    end
  end
end

function Tracker:BroadcastHello()
  self:RefreshLocalPlayer()
  if not (self.playerName and self.playerClass and self.playerSpellID and self.playerBaseCd) then
    return
  end
  self:Transmit(BuildMessage("HELLO", self.playerClass, self.playerSpellID, self.playerBaseCd))
end

function Tracker:SchedulePendingTimeout(name, token, delaySeconds, fallbackResult, broadcastCommand)
  C_Timer.After(delaySeconds, function()
    local member = Tracker.members and Tracker.members[name] or nil
    if not member or member.pendingToken ~= token or member.pendingKick ~= true then
      return
    end

    member.pendingKick = false
    if fallbackResult then
      member.kickResult = fallbackResult
    end
    Tracker:MarkDirty()

    if broadcastCommand then
      Tracker:Transmit(BuildMessage(broadcastCommand))
    end
  end)
end

function Tracker:HandleKick(name, spellID, baseCd, isLocal)
  local member = self:GetOrCreateMember(name)
  if not member then
    return
  end

  local resolvedSpellID = ns.Interrupts and ns.Interrupts.ResolveSpellID and ns.Interrupts:ResolveSpellID(spellID) or spellID
  if not resolvedSpellID then
    resolvedSpellID = tonumber(spellID or 0) or 0
  end
  if resolvedSpellID <= 0 then
    return
  end

  local cooldown = ResolveBaseCooldown(resolvedSpellID, baseCd)
  local now = GetTime()
  if member.spellID == resolvedSpellID and math.abs(now - (tonumber(member.lastKickAt or 0) or 0)) <= 0.35 then
    return
  end
  local token = string.format("%s:%0.3f", tostring(name), now)

  local changed = CopyEntry(member, {
    spellID = resolvedSpellID,
    baseCd = cooldown,
    cdEnd = now + cooldown,
    lastKickAt = now,
    pendingKick = true,
    pendingToken = token,
    kickResult = nil,
  })

  if changed then
    self:MarkDirty()
  end

  if isLocal then
    self:SchedulePendingTimeout(name, token, 0.6, "failed", "FAILKICK")
  else
    self:SchedulePendingTimeout(name, token, 1.1, nil, nil)
  end
end

function Tracker:ApplyKickResult(name, result)
  local member = name and self.members and self.members[name] or nil
  if not member then
    return
  end

  local changed = false
  if member.pendingKick ~= false then
    member.pendingKick = false
    changed = true
  end
  if member.kickResult ~= result then
    member.kickResult = result
    changed = true
  end
  if changed then
    self:MarkDirty()
  end
end

function Tracker:HandleObservedKick(unit)
  local memberName, ownerUnit = ResolveObservedMemberName(unit)
  if not memberName or not ownerUnit then
    return
  end

  if ownerUnit == "player" then
    local member = self.members and self.members[memberName] or nil
    local lastKickAt = tonumber(member and member.lastKickAt or 0) or 0
    if member and member.pendingKick == true and lastKickAt > 0 and (GetTime() - lastKickAt) <= 1.0 then
      self:ApplyKickResult(memberName, "success")
      self:Transmit(BuildMessage("SUCCESSKICK"))
    end
    return
  end

  local cast = recentCasts[memberName]
  local spellID = cast and cast.spellID or nil
  if not spellID or math.abs(GetTime() - (tonumber(cast and cast.t or 0) or 0)) > 1.0 then
    return
  end

  local member = self:GetOrCreateMember(memberName)
  if member and member.pendingKick == true then
    self:ApplyKickResult(memberName, "success")
    return
  end

  local baseCd = ResolveBaseCooldown(spellID, member and member.baseCd)
  self:HandleKick(memberName, spellID, baseCd, false)
  self:ApplyKickResult(memberName, "success")
end

local function ResolveDistanceBetweenUnits(sourceUnit, targetUnit)
  if not (UnitPosition and type(sourceUnit) == "string" and type(targetUnit) == "string") then
    return nil
  end

  local targetX, targetY, _, targetMap = UnitPosition(targetUnit)
  if not targetX or not targetY or not targetMap then
    return nil
  end

  local sourceX, sourceY, _, sourceMap = UnitPosition(sourceUnit)
  if not sourceX or not sourceY or sourceMap ~= targetMap then
    return nil
  end

  local dx = targetX - sourceX
  local dy = targetY - sourceY
  return math.sqrt((dx * dx) + (dy * dy))
end

local function IsMemberInterruptOffCooldown(member, now)
  local cdEnd = tonumber(member and member.cdEnd or 0) or 0
  return cdEnd <= 0 or cdEnd <= ((tonumber(now or 0) or 0) + 0.05)
end

local function PickClosestHeuristicCandidate(candidates)
  if type(candidates) ~= "table" or #candidates == 0 then
    return nil
  end
  if #candidates == 1 then
    return candidates[1]
  end

  local bestKnown = nil
  local bestDistance = nil
  local fallback = nil
  for _, candidate in ipairs(candidates) do
    if candidate.dist ~= nil then
      if not bestKnown or candidate.dist < bestDistance then
        bestKnown = candidate
        bestDistance = candidate.dist
      end
    elseif fallback == nil then
      fallback = candidate
    end
  end

  return bestKnown or fallback
end

function Tracker:TryHeuristicKickAttribution(unit)
  if type(unit) ~= "string" or not unit:match("^nameplate") then
    return
  end

  local now = GetTime()
  local playerMember = self.playerName and self.members and self.members[self.playerName] or nil
  local playerLastKickAt = tonumber(playerMember and playerMember.lastKickAt or 0) or 0
  if UnitExists and UnitExists("target")
    and UnitIsUnit and UnitIsUnit("target", unit)
    and playerMember and playerMember.pendingKick == true
    and playerLastKickAt > 0
    and (now - playerLastKickAt) < OWN_PLAYER_INTERRUPT_PROTECT_WINDOW
  then
    return
  end

  local candidates = {}
  for index = 1, 4 do
    local partyUnit = "party" .. index
    if UnitExists(partyUnit) then
      local memberName = GetSafeUnitShortName(partyUnit)
      local member = memberName and self.members and self.members[memberName] or nil
      local spellID = GetTrackedSpellID(member)
      if memberName and member and spellID and IsMemberInterruptOffCooldown(member, now) then
        local distance = ResolveDistanceBetweenUnits(partyUnit, unit)
        local targetMatches = UnitExists(partyUnit .. "target")
          and UnitIsUnit
          and UnitIsUnit(partyUnit .. "target", unit)
          or false
        candidates[#candidates + 1] = {
          unit = partyUnit,
          name = memberName,
          spellID = spellID,
          targetMatches = targetMatches == true,
          dist = distance,
          inRange = distance == nil or distance <= PARTY_INTERRUPT_MAX_RANGE,
        }
      end
    end
  end

  if #candidates == 0 then
    return
  end

  local targetingSet = {}
  local inRangeSet = {}
  for _, candidate in ipairs(candidates) do
    if candidate.targetMatches then
      targetingSet[#targetingSet + 1] = candidate
    end
    if candidate.inRange then
      inRangeSet[#inRangeSet + 1] = candidate
    end
  end

  local winner = nil
  if #targetingSet == 1 then
    winner = targetingSet[1]
  elseif #targetingSet > 1 then
    winner = PickClosestHeuristicCandidate(targetingSet)
  elseif #inRangeSet == 1 then
    winner = inRangeSet[1]
  elseif #inRangeSet > 1 then
    winner = PickClosestHeuristicCandidate(inRangeSet)
  elseif #candidates == 1 then
    winner = candidates[1]
  end

  if not winner then
    return
  end

  recentCasts[winner.name] = { t = now, spellID = winner.spellID }

  local member = self:GetOrCreateMember(winner.name)
  if member and member.pendingKick == true then
    self:ApplyKickResult(winner.name, "success")
    return
  end

  local baseCd = ResolveBaseCooldown(winner.spellID, member and member.baseCd)
  self:HandleKick(winner.name, winner.spellID, baseCd, false)
  self:ApplyKickResult(winner.name, "success")
end

local function CorrelateSignals()
  local now = GetTime()
  if not needsCorrelation or (now - lastCorrelateAt) < CORRELATE_INTERVAL then
    return
  end
  lastCorrelateAt = now
  PruneSignalTape(now)

  local casts = {}
  local interrupts = {}
  local auras = {}

  for index = 1, #signalTape do
    local signal = signalTape[index]
    if signal and signal.consumed ~= true then
      if signal.kind == "cast" then
        casts[#casts + 1] = signal
      elseif signal.kind == "interrupt" then
        interrupts[#interrupts + 1] = signal
      elseif signal.kind == "aura" then
        auras[#auras + 1] = signal
      end
    end
  end

  if #casts == 0 or #interrupts == 0 then
    needsCorrelation = false
    return
  end

  table.sort(interrupts, function(left, right)
    return (left.at or 0) < (right.at or 0)
  end)
  local freshest = interrupts[#interrupts]

  local clustered = 0
  for index = 1, #interrupts do
    local interruptSignal = interrupts[index]
    if math.abs((interruptSignal.at or 0) - (freshest.at or 0)) <= INTERRUPT_CLUSTER_WINDOW then
      clustered = clustered + 1
    end
  end
  if clustered > 1 then
    for index = 1, #interrupts do
      interrupts[index].consumed = true
    end
    needsCorrelation = false
    return
  end

  for index = 1, #auras do
    local auraSignal = auras[index]
    if auraSignal.unit == freshest.unit and math.abs((freshest.at or 0) - (auraSignal.at or 0)) <= AURA_SUPPRESS_WINDOW then
      freshest.consumed = true
      needsCorrelation = false
      return
    end
  end

  local bestCast = nil
  local bestDiff = math.huge
  for index = 1, #casts do
    local castSignal = casts[index]
    local diff = math.abs((freshest.at or 0) - (castSignal.at or 0))
    if diff <= MATCH_WINDOW and diff < bestDiff then
      bestDiff = diff
      bestCast = castSignal
    end
  end

  freshest.consumed = true
  if bestCast then
    bestCast.consumed = true
    Tracker:HandleObservedKick(bestCast.unit)
  end

  needsCorrelation = false
end

function Tracker:HandleMessage(prefix, message, sender)
  if prefix ~= PREFIX or type(message) ~= "string" then
    return
  end

  local shortName = SafeShortName(sender)
  if not shortName or shortName == self.playerName then
    return
  end

  local parts = { strsplit(SEPARATOR, message) }
  if parts[1] ~= HEADER then
    return
  end

  local command = parts[2]
  if command == "HELLO" then
    local classToken = parts[3]
    local spellID = tonumber(parts[4] or 0) or 0
    local baseCd = tonumber(parts[5] or 0) or 0
    if classToken and spellID > 0 then
      local member = self:GetOrCreateMember(shortName)
      local changed = false
      if member and CopyEntry(member, {
        class = classToken,
        spellID = spellID,
        baseCd = ResolveBaseCooldown(spellID, baseCd),
        isLocal = false,
      }) then
        changed = true
      end
      if member and member.noInterrupt ~= nil then
        member.noInterrupt = nil
        changed = true
      end
      if changed then
        self:MarkDirty()
      end
    end
  elseif command == "KICK" then
    local spellID = tonumber(parts[3] or 0) or 0
    local baseCd = tonumber(parts[4] or 0) or 0
    if spellID > 0 then
      self:HandleKick(shortName, spellID, baseCd, false)
    end
  elseif command == "FAILKICK" then
    self:ApplyKickResult(shortName, "failed")
  elseif command == "SUCCESSKICK" then
    self:ApplyKickResult(shortName, "success")
  end
end

function Tracker:HandleMobInterrupted(unit)
  if not (C_Timer and C_Timer.After) then
    return
  end

  C_Timer.After(0, function()
    local playerName = Tracker.playerName
    local member = playerName and Tracker.members and Tracker.members[playerName] or nil
    local now = GetTime()
    if not member or member.pendingKick ~= true then
      return
    end

    local lastKickAt = tonumber(member.lastKickAt or 0) or 0
    if lastKickAt <= 0 or (now - lastKickAt) > 1.0 then
      return
    end

    Tracker:ApplyKickResult(playerName, "success")
    Tracker:Transmit(BuildMessage("SUCCESSKICK"))
  end)
end

function Tracker:HandlePlayerKick(spellID)
  local resolvedSpellID = ns.Interrupts and ns.Interrupts.ResolveSpellID and ns.Interrupts:ResolveSpellID(spellID) or nil
  if not resolvedSpellID or not self.playerName then
    return
  end
  local baseCd = ResolveBaseCooldown(resolvedSpellID, self.playerBaseCd)
  self:HandleKick(self.playerName, resolvedSpellID, baseCd, true)
  self:Transmit(BuildMessage("KICK", resolvedSpellID, baseCd))
end

function Tracker:HandleEvent(event, ...)
  if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
    local prefix, message, _, sender = ...
    self:HandleMessage(prefix, message, sender)
  elseif event == "INSPECT_READY" then
    local guid = ...
    self:HandleInspectReady(guid)
  elseif event == "GROUP_ROSTER_UPDATE" then
    self:RefreshGroupRoster()
    C_Timer.After(1, function()
      Tracker:BroadcastHello()
    end)
  elseif event == "PLAYER_ENTERING_WORLD" then
    self:RefreshLocalPlayer()
    self:RefreshGroupRoster()
    C_Timer.After(1, function()
      Tracker:BroadcastHello()
    end)
  elseif event == "SPELLS_CHANGED" then
    self:RefreshLocalPlayer()
    C_Timer.After(0.2, function()
      Tracker:BroadcastHello()
    end)
  elseif event == "ACTIVE_COMBAT_CONFIG_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
    self:RefreshLocalPlayer()
    C_Timer.After(0.2, function()
      Tracker:BroadcastHello()
    end)
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if not unit or unit == "player" then
      self:RefreshLocalPlayer()
      C_Timer.After(0.2, function()
        Tracker:BroadcastHello()
      end)
    else
      local ownerUnit = ResolveCastOwnerUnit(unit) or unit
      if type(ownerUnit) == "string" and ownerUnit:match("^party%d+$") and UnitExists(ownerUnit) then
        local name = GetSafeUnitShortName(ownerUnit)
        local _, classToken = UnitClass(ownerUnit)
        local member = name and self:GetOrCreateMember(name) or nil
        local changed = false
        if member then
          local orderIndex = tonumber(ownerUnit:match("^party(%d+)$") or 0) or 0
          if CopyEntry(member, {
            class = classToken,
            isLocal = false,
            orderIndex = orderIndex > 0 and (orderIndex + 1) or member.orderIndex,
          }) then
            changed = true
          end
          if RefreshMemberInterruptFromUnit(member, ownerUnit, classToken) then
            changed = true
          elseif member.specID == nil and not GetTrackedSpellID(member) then
            self:EnqueueInspectUnit(ownerUnit)
          end
        end
        if changed then
          self:MarkDirty()
        end
      end
    end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    local memberName, ownerUnit = ResolveObservedMemberName(unit)
    local resolvedSpellID = ResolveObservedInterruptSpellID(memberName, spellID)
    if unit == "player" then
      if resolvedSpellID and self.playerName then
        recentCasts[self.playerName] = { t = GetTime(), spellID = resolvedSpellID }
        PushSignal("cast", unit)
      end
      self:HandlePlayerKick(spellID)
    elseif ownerUnit and ownerUnit ~= "player" and memberName and resolvedSpellID then
      recentCasts[memberName] = { t = GetTime(), spellID = resolvedSpellID }
      PushSignal("cast", unit)
    end
  elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
    local unit = ...
    if type(unit) == "string" and unit:match("^nameplate") then
      PushSignal("interrupt", unit)
      self:TryHeuristicKickAttribution(unit)
    end
  elseif event == "UNIT_AURA" then
    local unit = ...
    if type(unit) == "string" and unit:match("^nameplate") then
      PushSignal("aura", unit)
    end
  end
end

function Tracker:InitializeMobWatchers()
  if self.mobFrame or self.nameplateFrames then
    return
  end

  local mobFrame = CreateFrame("Frame")
  mobFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "focus")
  mobFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target", "focus")
  for index = 1, 5 do
    mobFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "boss" .. index)
    mobFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "boss" .. index)
  end
  mobFrame:SetScript("OnEvent", function(_, _, unit)
    Tracker:HandleMobInterrupted(unit)
  end)
  self.mobFrame = mobFrame

  self.nameplateFrames = {}
  for index = 1, 40 do
    local unit = "nameplate" .. index
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    frame:SetScript("OnEvent", function(_, _, eventUnit)
      Tracker:HandleMobInterrupted(eventUnit)
    end)
    self.nameplateFrames[unit] = frame
  end
end

function Tracker:InitializeEventFrame()
  if self.eventFrame then
    return
  end

  self.members = self.members or {}
  self.revision = self.revision or 0

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("INSPECT_READY")
  frame:RegisterEvent("SPELLS_CHANGED")
  frame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
  frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
  frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  frame:RegisterEvent("UNIT_AURA")
  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
  frame:SetScript("OnEvent", function(_, event, ...)
    Tracker:HandleEvent(event, ...)
  end)
  frame:SetScript("OnUpdate", function()
    if needsCorrelation then
      CorrelateSignals()
    end
  end)

  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  end

  self.eventFrame = frame
  self:InitializeMobWatchers()
  self:RefreshLocalPlayer()
  self:RefreshGroupRoster()
  C_Timer.After(0.2, function()
    Tracker:BroadcastHello()
  end)
end

function Tracker:Initialize()
  if self.eventFrame then
    return
  end

  if not (IsLoggedIn and IsLoggedIn()) then
    if self.startupFrame then
      return
    end

    local startupFrame = CreateFrame("Frame")
    startupFrame:RegisterEvent("PLAYER_LOGIN")
    startupFrame:SetScript("OnEvent", function()
      startupFrame:UnregisterEvent("PLAYER_LOGIN")
      Tracker.startupFrame = nil
      Tracker:InitializeEventFrame()
    end)
    self.startupFrame = startupFrame
    return
  end

  self:InitializeEventFrame()
end

function Tracker:GetEntries(aura)
  local now = GetTime()
  local disabledSpells = aura and aura.interrupt and aura.interrupt.disabledSpells or nil
  local entries = {}

  for name, member in pairs(self.members or {}) do
    local spellID = tonumber(GetTrackedSpellID(member) or 0) or 0
    if spellID > 0 and not (type(disabledSpells) == "table" and disabledSpells[spellID] == true) then
      local spellInfo = ns.Interrupts and ns.Interrupts.GetSpellInfo and ns.Interrupts:GetSpellInfo(spellID) or nil
      local isLocal = member.isLocal == true or name == self.playerName
      local cdEnd = tonumber(member.cdEnd or 0) or 0
      if isLocal then
        local liveCdEnd = GetLiveCooldownEnd(spellID)
        if liveCdEnd and liveCdEnd > now then
          cdEnd = liveCdEnd
        end
      end
      local remaining = math.max(0, cdEnd - now)
      entries[#entries + 1] = {
        name = name,
        class = member.class,
        isLocal = isLocal,
        spellID = spellID,
        baseCd = tonumber(member.baseCd or (spellInfo and spellInfo.cd) or 0) or 0,
        cdEnd = cdEnd,
        remaining = remaining,
        isReady = remaining <= 0.05,
        pendingKick = member.pendingKick == true,
        kickResult = member.kickResult,
        orderIndex = tonumber(member.orderIndex or 999) or 999,
        icon = spellInfo and spellInfo.icon or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)) or 134400,
        label = spellInfo and spellInfo.label or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or "Interrupt",
      }
    end
  end

  local sortOrder = aura and aura.interrupt and aura.interrupt.sortOrder or "NONE"
  table.sort(entries, function(left, right)
    if sortOrder == "NONE" then
      if left.orderIndex ~= right.orderIndex then
        return left.orderIndex < right.orderIndex
      end
      return left.name < right.name
    end
    if sortOrder == "CD_DESC" then
      if left.remaining == right.remaining then
        return left.name < right.name
      end
      return left.remaining > right.remaining
    end
    if left.remaining == right.remaining then
      return left.name < right.name
    end
    return left.remaining < right.remaining
  end)

  return entries
end
