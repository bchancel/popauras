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

local function ResolveObservedInterruptSpellID(memberName, rawSpellID)
  local resolvedSpellID = nil
  if rawSpellID ~= nil and not (issecretvalue and issecretvalue(rawSpellID)) then
    resolvedSpellID = ns.Interrupts and ns.Interrupts.ResolveSpellID and ns.Interrupts:ResolveSpellID(rawSpellID) or nil
  end
  if resolvedSpellID then
    return resolvedSpellID
  end

  local member = memberName and Tracker.members and Tracker.members[memberName] or nil
  local memberSpellID = tonumber(member and member.spellID or 0) or 0
  if memberSpellID > 0 then
    return memberSpellID
  end

  local classToken = member and member.class or nil
  local group = classToken and ns.Interrupts and ns.Interrupts.CLASS_FILTER_LOOKUP and ns.Interrupts.CLASS_FILTER_LOOKUP[classToken] or nil
  local fallback = group and group.spells and group.spells[1] or nil
  return fallback and fallback.id or nil
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
  local changed = CopyEntry(member, {
    class = info and info.class or classToken,
    spellID = info and info.spellID or nil,
    baseCd = info and info.cd or nil,
    isLocal = true,
  })
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
        if CopyEntry(member, { class = classToken, isLocal = false }) then
          changed = true
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
  if member.pendingKick == true and member.spellID == resolvedSpellID and math.abs(now - (tonumber(member.lastKickAt or 0) or 0)) <= 0.35 then
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
  freshest.consumed = true

  for index = 1, #auras do
    local auraSignal = auras[index]
    if auraSignal.unit == freshest.unit and math.abs((freshest.at or 0) - (auraSignal.at or 0)) <= AURA_SUPPRESS_WINDOW then
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
      if member and CopyEntry(member, {
        class = classToken,
        spellID = spellID,
        baseCd = ResolveBaseCooldown(spellID, baseCd),
        isLocal = false,
      }) then
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
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local unit = ...
    if not unit or unit == "player" then
      self:RefreshLocalPlayer()
      C_Timer.After(0.2, function()
        Tracker:BroadcastHello()
      end)
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
  frame:RegisterEvent("SPELLS_CHANGED")
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
    local spellID = tonumber(member.spellID or 0) or 0
    if spellID > 0 and not (type(disabledSpells) == "table" and disabledSpells[spellID] == true) then
      local spellInfo = ns.Interrupts and ns.Interrupts.GetSpellInfo and ns.Interrupts:GetSpellInfo(spellID) or nil
      local remaining = math.max(0, (member.cdEnd or 0) - now)
      entries[#entries + 1] = {
        name = name,
        class = member.class,
        isLocal = member.isLocal == true or name == self.playerName,
        spellID = spellID,
        baseCd = tonumber(member.baseCd or (spellInfo and spellInfo.cd) or 0) or 0,
        cdEnd = member.cdEnd or 0,
        remaining = remaining,
        isReady = remaining <= 0.05,
        pendingKick = member.pendingKick == true,
        kickResult = member.kickResult,
        icon = spellInfo and spellInfo.icon or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)) or 134400,
        label = spellInfo and spellInfo.label or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or "Interrupt",
      }
    end
  end

  local sortOrder = aura and aura.interrupt and aura.interrupt.sortOrder or "CD_ASC"
  table.sort(entries, function(left, right)
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
