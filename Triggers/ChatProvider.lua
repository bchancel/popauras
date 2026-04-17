local _, ns = ...

local Strings = ns.util.Strings

local provider = ns.TriggerBase:CreateProvider("chat", {
  events = {
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
  },
  alerts = {},
  alertSequence = 0,
})

local CHANNEL_BY_EVENT = {
  CHAT_MSG_WHISPER = "WHISPER",
  CHAT_MSG_SAY = "SAY",
  CHAT_MSG_YELL = "YELL",
  CHAT_MSG_PARTY = "PARTY",
  CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
  CHAT_MSG_RAID = "RAID",
  CHAT_MSG_RAID_LEADER = "RAID_LEADER",
  CHAT_MSG_RAID_WARNING = "RAID_WARNING",
  CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
  CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT_LEADER",
  CHAT_MSG_GUILD = "GUILD",
  CHAT_MSG_OFFICER = "OFFICER",
  CHAT_MSG_EMOTE = "EMOTE",
  CHAT_MSG_TEXT_EMOTE = "TEXT_EMOTE",
}

local CHANNEL_ALIASES = {
  PARTY = {
    PARTY = true,
    PARTY_LEADER = true,
  },
  RAID = {
    RAID = true,
    RAID_LEADER = true,
    RAID_WARNING = true,
  },
  INSTANCE_CHAT = {
    INSTANCE_CHAT = true,
    INSTANCE_CHAT_LEADER = true,
  },
}

local function NormalizeLower(value)
  if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then
    return nil
  end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return nil
  end
  return value:lower()
end

local function SplitList(input)
  local values = {}
  for token in tostring(input or ""):gmatch("([^,]+)") do
    token = NormalizeLower(token)
    if token then
      values[#values + 1] = token
    end
  end
  return values
end

local function GetAlertKey(auraId, triggerIndex)
  return string.format("%s:%d", tostring(auraId or ""), tonumber(triggerIndex or 0) or 0)
end

local function NormalizeSender(sender)
  local full = NormalizeLower(sender)
  local short = sender and Strings and Strings.GetSafeShortPlayerName and Strings.GetSafeShortPlayerName(sender) or nil
  short = NormalizeLower(short)
  return full, short
end

local function GetDisplaySender(sender)
  if Strings and Strings.GetSafeShortPlayerName then
    local short = Strings.GetSafeShortPlayerName(sender)
    if short then
      return short
    end
  end
  if type(sender) == "string" and not (issecretvalue and issecretvalue(sender)) and sender ~= "" then
    return sender
  end
  return "Chat"
end

local function ResolveSenderUnitId(sender)
  local fullSender, shortSender = NormalizeSender(sender)
  if not shortSender then
    return nil
  end

  if UnitExists("player") then
    local playerName = NormalizeLower(UnitName("player"))
    if playerName == shortSender then
      return "player"
    end
  end

  if IsInRaid and IsInRaid() then
    for index = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
      local unitId = "raid" .. index
      if UnitExists(unitId) then
        local unitName = NormalizeLower(UnitName(unitId))
        if unitName == shortSender or unitName == fullSender then
          return unitId
        end
      end
    end
  else
    for index = 1, 4 do
      local unitId = "party" .. index
      if UnitExists(unitId) then
        local unitName = NormalizeLower(UnitName(unitId))
        if unitName == shortSender or unitName == fullSender then
          return unitId
        end
      end
    end
  end

  return nil
end

local function TriggerMatchesChat(trigger, channel, message, sender)
  if type(trigger) ~= "table" then
    return false
  end

  local allowedChannels = {}
  if type(trigger.chatChannels) == "table" then
    for _, value in ipairs(trigger.chatChannels) do
      local normalized = tostring(value or "")
      if normalized ~= "" then
        allowedChannels[normalized] = true
      end
    end
  end
  if next(allowedChannels) == nil then
    allowedChannels[tostring(trigger.chatChannel or "WHISPER")] = true
  end

  if not allowedChannels.ANY then
    local matchesChannel = allowedChannels[channel] == true
    if not matchesChannel then
      for allowedChannel in pairs(allowedChannels) do
        local aliases = CHANNEL_ALIASES[allowedChannel]
        if aliases and aliases[channel] == true then
          matchesChannel = true
          break
        end
      end
    end
    if not matchesChannel then
      return false
    end
  end

  local phrases = SplitList(trigger.chatMessage)
  local normalizedMessage = NormalizeLower(message)
  if not normalizedMessage or #phrases == 0 then
    return false
  end

  local matchedPhrase = false
  for _, phrase in ipairs(phrases) do
    local isMatch
    if trigger.chatExact == true then
      isMatch = normalizedMessage == phrase
    else
      isMatch = normalizedMessage:find(phrase, 1, true) ~= nil
    end
    if isMatch then
      matchedPhrase = true
      break
    end
  end
  if not matchedPhrase then
    return false
  end

  local senders = SplitList(trigger.chatSource)
  if #senders == 0 then
    return true
  end

  local fullSender, shortSender = NormalizeSender(sender)
  for _, expected in ipairs(senders) do
    if expected == fullSender or expected == shortSender then
      return true
    end
  end

  return false
end

local function GetChatAuraIds()
  return ns.Registry:CollectAuraIds(function(aura)
    return ns.TriggerBase:AnyTriggerMatches(aura, "chat")
  end)
end

function provider:PruneAlerts()
  local now = GetTime()
  for key, alertSet in pairs(self.alerts) do
    if type(alertSet) ~= "table" or not ns.Registry:GetAura(alertSet.auraId) then
      self.alerts[key] = nil
    else
      for senderKey, alert in pairs(alertSet.entries or {}) do
        if type(alert) ~= "table" or (alert.expirationTime or 0) <= now then
          alertSet.entries[senderKey] = nil
        end
      end
      if next(alertSet.entries or {}) == nil then
        self.alerts[key] = nil
      end
    end
  end
end

function provider:HandleEvent(event, ...)
  local channel = CHANNEL_BY_EVENT[event]
  if not channel then
    return {}
  end

  self:PruneAlerts()

  local message, sender = ...
  local affectedAuraIds = {}
  local affectedSeen = {}
  local now = GetTime()

  for _, auraId in ipairs(GetChatAuraIds()) do
    local aura = ns.Registry:GetAura(auraId)
    if aura then
      for triggerIndex, trigger in ns.TriggerBase:IterateTriggers(aura, "chat") do
        if TriggerMatchesChat(trigger, channel, message, sender) then
          local senderName = GetDisplaySender(sender)
          local senderKey = NormalizeLower(sender) or senderName:lower()
          local safeMessage = type(message) == "string" and not (issecretvalue and issecretvalue(message)) and message or ""
          local duration = math.max(0.5, math.min(60, tonumber(trigger.chatDuration or 4) or 4))
          local alertKey = GetAlertKey(auraId, triggerIndex)
          local alertSet = self.alerts[alertKey]
          if type(alertSet) ~= "table" then
            alertSet = {
              auraId = auraId,
              triggerIndex = triggerIndex,
              entries = {},
            }
            self.alerts[alertKey] = alertSet
          end
          self.alertSequence = (tonumber(self.alertSequence or 0) or 0) + 1
          alertSet.entries[senderKey] = {
            sender = senderName,
            senderRaw = sender,
            unit = ResolveSenderUnitId(sender),
            message = safeMessage,
            channel = channel,
            startedAt = now,
            duration = duration,
            expirationTime = now + duration,
            sequence = self.alertSequence,
          }
          if not affectedSeen[auraId] then
            affectedSeen[auraId] = true
            affectedAuraIds[#affectedAuraIds + 1] = auraId
          end
        end
      end
    end
  end

  return affectedAuraIds
end

function provider:Evaluate(trigger, aura, triggerIndex)
  local auraId = aura and aura.id or nil
  if not auraId then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "chat" })
  end

  local alertSet = self.alerts[GetAlertKey(auraId, triggerIndex)]
  if not alertSet or type(alertSet.entries) ~= "table" then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "chat" })
  end

  local now = GetTime()
  local matchedUnits = {}
  local seenUnits = {}
  local newestAlert = nil
  local latestExpiration = 0
  local latestSequence = 0

  for senderKey, alert in pairs(alertSet.entries) do
    local remaining = math.max(0, (alert.expirationTime or 0) - now)
    if remaining <= 0 then
      alertSet.entries[senderKey] = nil
    else
      if not newestAlert or (tonumber(alert.sequence or 0) or 0) >= latestSequence then
        newestAlert = alert
        latestSequence = tonumber(alert.sequence or 0) or 0
      end
      latestExpiration = math.max(latestExpiration, tonumber(alert.expirationTime or 0) or 0)
      if type(alert.unit) == "string" and alert.unit ~= "" and not seenUnits[alert.unit] then
        seenUnits[alert.unit] = true
        matchedUnits[#matchedUnits + 1] = alert.unit
      end
    end
  end

  if next(alertSet.entries) == nil or not newestAlert then
    self.alerts[GetAlertKey(auraId, triggerIndex)] = nil
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "chat" })
  end

  local remaining = math.max(0, latestExpiration - now)

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    active = true,
    icon = 134400,
    name = newestAlert.sender or "Chat",
    unit = newestAlert.unit,
    matchedUnits = matchedUnits,
    duration = remaining,
    expirationTime = latestExpiration,
    progressType = "timed",
    value = remaining,
    total = remaining,
    source = "chat",
    statusText = newestAlert.channel or "CHAT",
    message = newestAlert.message or "",
    actionEventKey = latestSequence,
  })
end
