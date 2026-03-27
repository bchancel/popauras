local _, ns = ...

local Tracker = {}
ns.InterruptTracker = Tracker

local PREFIX = "BliZziIT"
local HEADER = "B1"
local SEPARATOR = ";"

Tracker.members = {}
Tracker.revision = 0

local function SafeShortName(name)
  if not name or name == "" then
    return nil
  end
  if Ambiguate then
    return Ambiguate(name, "short")
  end
  return name
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
  local name = SafeShortName(UnitName("player"))
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
      local name = SafeShortName(UnitName(unit))
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

  local sent = false
  if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME) then
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, "PARTY")
    sent = ok == true and result == 0
  end

  if sent then
    return
  end

  for index = 1, 4 do
    local unit = "party" .. index
    if UnitExists(unit) and UnitIsPlayer(unit) then
      local name, realm = UnitFullName(unit)
      if name then
        local target = realm and realm ~= "" and (name .. "-" .. realm) or name
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, "WHISPER", target)
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
    if unit == "player" then
      self:HandlePlayerKick(spellID)
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
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
  frame:SetScript("OnEvent", function(_, event, ...)
    Tracker:HandleEvent(event, ...)
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
