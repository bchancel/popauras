local _, ns = ...

local provider = ns.TriggerBase:CreateProvider("item_cooldown", {
  events = {
    "BAG_UPDATE_COOLDOWN",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_ENTERING_WORLD",
  },
})

function provider:GetAffectedAuras(event)
  if event ~= "BAG_UPDATE_COOLDOWN" then
    return true
  end

  return ns.Registry:CollectAuraIds(function(aura)
    return ns.TriggerBase:AnyTriggerMatches(aura, "item_cooldown")
  end)
end

local function SafeNumber(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  if type(value) == "number" then
    return value
  end
  return nil
end

local function IsLikelyGCD(duration)
  return type(duration) == "number" and duration > 0 and duration <= 1.6
end

local function GetItemCooldownInfo(itemId)
  if C_Item and C_Item.GetItemCooldown then
    local startTime, duration, enableCooldownTimer = C_Item.GetItemCooldown(itemId)
    if type(startTime) == "table" then
      return {
        startTime = SafeNumber(startTime.startTime),
        duration = SafeNumber(startTime.duration),
        isEnabled = startTime.isEnabled ~= false and startTime.enableCooldownTimer ~= false,
      }
    end
    return {
      startTime = SafeNumber(startTime),
      duration = SafeNumber(duration),
      isEnabled = enableCooldownTimer == true or enableCooldownTimer == 1,
    }
  end
  local start, duration, enabled = GetItemCooldown(itemId)
  return {
    startTime = SafeNumber(start),
    duration = SafeNumber(duration),
    isEnabled = enabled == 1,
  }
end

local function GetCooldownMatchMode(trigger)
  return trigger and trigger.cooldownMatch == "ready" and "ready" or "cooldown"
end

local function ShouldPersistDisplay(trigger, aura)
  if not trigger or trigger.showAlways == false then
    return false
  end
  return not (aura and type(aura.triggers) == "table" and #aura.triggers > 1)
end

function provider:Evaluate(trigger, aura)
  local itemId = tonumber(trigger.itemId or 0)
  if itemId == 0 then
    return ns.Schema.NormalizeRuntimeState({ show = false, active = false, source = "item_cooldown" })
  end

  local info = GetItemCooldownInfo(itemId)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId) or ("Item " .. itemId)
  local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemId)
  local duration = 0
  local expirationTime = 0
  local isReady = true

  local startTime = type(info) == "table" and SafeNumber(info.startTime) or nil
  local cooldownDuration = type(info) == "table" and SafeNumber(info.duration) or nil
  local isEnabled = type(info) == "table" and info.isEnabled == true

  if startTime and cooldownDuration and cooldownDuration > 0 and isEnabled then
    local candidateExpirationTime = startTime + cooldownDuration
    if not IsLikelyGCD(cooldownDuration) and candidateExpirationTime > GetTime() then
      duration = cooldownDuration
      expirationTime = candidateExpirationTime
      isReady = false
    end
  end

  local matchMode = GetCooldownMatchMode(trigger)
  local matched = (matchMode == "ready") == isReady

  return ns.Schema.NormalizeRuntimeState({
    show = ShouldPersistDisplay(trigger, aura) or matched,
    matched = matched,
    active = not isReady,
    icon = icon,
    name = name,
    duration = duration,
    expirationTime = expirationTime,
    progressType = duration > 0 and "timed" or "static",
    value = duration,
    total = duration,
    isReady = isReady,
    itemId = itemId,
    source = "item_cooldown",
    statusText = isReady and "Ready" or "Cooldown",
  })
end
