local _, ns = ...

local DEFAULT_MAX_ALERTS_PER_COMBAT = 7

local provider = ns.TriggerBase:CreateProvider("death_alert", {
  events = {
    "UNIT_FLAGS",
    "UNIT_HEALTH",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
  },
  alerts = {},
  recentDeaths = {},
  observedDeathState = {},
  combatAlertCounts = {},
  inCombat = false,
})

local Strings = ns.util.Strings

local function NormalizeRole(role)
  if role == "TANK" or role == "HEALER" then
    return role
  end
  return "DAMAGER"
end

local function GetClassColor(classToken)
  local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
  if color then
    return {
      r = color.r or 1,
      g = color.g or 1,
      b = color.b or 1,
      a = 1,
    }
  end
  return { r = 1, g = 1, b = 1, a = 1 }
end

local function GetGroupUnits()
  local units = {}
  if IsInRaid() then
    local count = GetNumGroupMembers() or 0
    for index = 1, count do
      units[#units + 1] = "raid" .. tostring(index)
    end
  elseif IsInGroup() then
    units[#units + 1] = "player"
    local count = GetNumSubgroupMembers() or 0
    for index = 1, count do
      units[#units + 1] = "party" .. tostring(index)
    end
  end
  return units
end

local function BuildGroupRosterByGUID()
  local members = {}
  for _, unit in ipairs(GetGroupUnits()) do
    if UnitExists(unit) and UnitIsPlayer(unit) then
      local guid = UnitGUID(unit)
      if guid then
        local name = Strings and Strings.GetSafeUnitDisplayName and Strings.GetSafeUnitDisplayName(unit, false) or nil
        local _, classToken = UnitClass(unit)
        members[guid] = {
          unit = unit,
          guid = guid,
          name = name or UNKNOWNOBJECT,
          classToken = classToken,
          role = NormalizeRole(UnitGroupRolesAssigned(unit)),
        }
      end
    end
  end
  return members
end

local function TriggerMatchesRole(trigger, role)
  role = NormalizeRole(role)
  if role == "TANK" then
    return trigger.showTank ~= false
  elseif role == "HEALER" then
    return trigger.showHealer ~= false
  end
  return trigger.showDPS ~= false
end

local function GetRoleSound(trigger, role)
  role = NormalizeRole(role)
  if role == "TANK" then
    return trigger.soundTank or "None"
  elseif role == "HEALER" then
    return trigger.soundHealer or "None"
  end
  return trigger.soundDPS or "None"
end

local function GetAlertCap(trigger)
  local cap = tonumber(trigger and trigger.maxAlertsPerCombat)
  if cap == nil then
    cap = DEFAULT_MAX_ALERTS_PER_COMBAT
  end
  cap = math.floor(cap)
  return math.max(0, math.min(20, cap))
end

function provider:GetDeathAlertAuraIds()
  return ns.Registry:CollectAuraIds(function(aura)
    local trigger = aura and aura.triggers and aura.triggers[1]
    return trigger and trigger.type == "death_alert"
  end)
end

function provider:PruneAlerts()
  local now = GetTime()
  local activeAuraIds = {}
  local roster = BuildGroupRosterByGUID()

  for _, auraId in ipairs(self:GetDeathAlertAuraIds()) do
    activeAuraIds[auraId] = true
  end

  for auraId, alert in pairs(self.alerts) do
    if not activeAuraIds[auraId]
      or type(alert) ~= "table"
      or (alert.expirationTime or 0) <= now
      or (alert.guid and not roster[alert.guid]) then
      self.alerts[auraId] = nil
    end
  end

  for guid, deathAt in pairs(self.recentDeaths) do
    if (deathAt or 0) <= (now - 2) then
      self.recentDeaths[guid] = nil
    end
  end

  for guid in pairs(self.observedDeathState) do
    if not roster[guid] then
      self.observedDeathState[guid] = nil
    end
  end
end

function provider:SyncObservedDeathState()
  local roster = BuildGroupRosterByGUID()
  for guid in pairs(self.observedDeathState) do
    if not roster[guid] then
      self.observedDeathState[guid] = nil
    end
  end

  for guid, member in pairs(roster) do
    local unit = member and member.unit
    if unit and UnitExists(unit) then
      self.observedDeathState[guid] = UnitIsDeadOrGhost(unit) == true
    end
  end
end

function provider:HandleEvent(event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    wipe(self.alerts)
    wipe(self.recentDeaths)
    wipe(self.observedDeathState)
    wipe(self.combatAlertCounts)
    self.inCombat = InCombatLockdown and InCombatLockdown() == true or false
    self:SyncObservedDeathState()
    return self:GetDeathAlertAuraIds()
  end

  if event == "PLAYER_REGEN_DISABLED" then
    self.inCombat = true
    wipe(self.combatAlertCounts)
    return self:GetDeathAlertAuraIds()
  end

  if event == "PLAYER_REGEN_ENABLED" then
    self.inCombat = false
    wipe(self.combatAlertCounts)
    return self:GetDeathAlertAuraIds()
  end

  if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
    self:PruneAlerts()
    self:SyncObservedDeathState()
    return self:GetDeathAlertAuraIds()
  end

  if event ~= "UNIT_FLAGS" and event ~= "UNIT_HEALTH" then
    return {}
  end

  local unit = ...
  if type(unit) ~= "string" or unit == "" then
    return {}
  end

  if not UnitExists(unit) or not UnitIsPlayer(unit) then
    return {}
  end

  local destGUID = UnitGUID(unit)
  if not destGUID then
    return {}
  end

  local now = GetTime()
  if self.recentDeaths[destGUID] and (now - self.recentDeaths[destGUID]) < 0.25 then
    return {}
  end

  local roster = BuildGroupRosterByGUID()
  local member = roster[destGUID]
  if not member then
    return {}
  end

  local isDead = UnitIsDeadOrGhost(unit) == true
  local wasDead = self.observedDeathState[destGUID] == true
  self.observedDeathState[destGUID] = isDead

  if not isDead then
    return {}
  end

  if wasDead then
    return {}
  end

  self.recentDeaths[destGUID] = now
  self:PruneAlerts()

  local affectedAuraIds = {}
  for _, auraId in ipairs(self:GetDeathAlertAuraIds()) do
    local aura = ns.Registry:GetAura(auraId)
    local trigger = aura and aura.triggers and aura.triggers[1] or nil
    if trigger and TriggerMatchesRole(trigger, member.role) then
      local alertsThisCombat = tonumber(self.combatAlertCounts[auraId] or 0) or 0
      local alertCap = GetAlertCap(trigger)
      if not self.inCombat or alertCap == 0 or alertsThisCombat < alertCap then
        local duration = tonumber(trigger.alertDuration or 2) or 2
        duration = math.max(0.1, duration)
        self.alerts[auraId] = {
          guid = member.guid,
          name = member.name,
          classToken = member.classToken,
          role = member.role,
          color = GetClassColor(member.classToken),
          startedAt = now,
          duration = duration,
          expirationTime = now + duration,
        }

        local soundName = GetRoleSound(trigger, member.role)
        if ns.Interrupts and ns.Interrupts.PlaySound then
          ns.Interrupts:PlaySound(soundName)
        end

        if self.inCombat then
          self.combatAlertCounts[auraId] = alertsThisCombat + 1
        end

        affectedAuraIds[#affectedAuraIds + 1] = auraId
      end
    end
  end

  return affectedAuraIds
end

function provider:Evaluate(trigger, aura)
  local alert = aura and aura.id and self.alerts[aura.id] or nil
  if not alert then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "death_alert" })
  end

  local remaining = math.max(0, (alert.expirationTime or 0) - GetTime())
  if remaining <= 0 then
    if aura and aura.id then
      self.alerts[aura.id] = nil
    end
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "death_alert" })
  end

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    active = true,
    name = alert.name,
    duration = alert.duration,
    expirationTime = alert.expirationTime,
    progressType = "timed",
    value = remaining,
    total = alert.duration,
    source = "death_alert",
    statusText = "dead",
    color = alert.color,
    debugExtra = string.format("role=%s class=%s", tostring(alert.role or ""), tostring(alert.classToken or "")),
  })
end
