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
  for key, alert in pairs(self.alerts) do
    if type(alert) ~= "table"
      or (alert.expirationTime or 0) <= now
      or not ns.Registry:GetAura(alert.auraId) then
      self.alerts[key] = nil
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
          local safeMessage = type(message) == "string" and not (issecretvalue and issecretvalue(message)) and message or ""
          local duration = math.max(0.5, math.min(60, tonumber(trigger.chatDuration or 4) or 4))
          self.alerts[GetAlertKey(auraId, triggerIndex)] = {
            auraId = auraId,
            triggerIndex = triggerIndex,
            sender = senderName,
            message = safeMessage,
            channel = channel,
            startedAt = now,
            duration = duration,
            expirationTime = now + duration,
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

  local alert = self.alerts[GetAlertKey(auraId, triggerIndex)]
  if not alert then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "chat" })
  end

  local remaining = math.max(0, (alert.expirationTime or 0) - GetTime())
  if remaining <= 0 then
    self.alerts[GetAlertKey(auraId, triggerIndex)] = nil
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "chat" })
  end

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    active = true,
    icon = 134400,
    name = alert.sender or "Chat",
    duration = alert.duration,
    expirationTime = alert.expirationTime,
    progressType = "timed",
    value = remaining,
    total = alert.duration,
    source = "chat",
    statusText = alert.channel or "CHAT",
    message = alert.message or "",
  })
end
