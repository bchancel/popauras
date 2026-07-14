local _, ns = ...

local SafeValues = {}
ns.SafeValues = SafeValues

local REAL_TIME = Enum and Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime or nil

function SafeValues:IsSecret(value)
  return issecretvalue ~= nil and issecretvalue(value) == true
end

function SafeValues:Number(value)
  if self:IsSecret(value) or value == nil then
    return nil
  end
  return type(value) == "number" and value or nil
end

function SafeValues:Boolean(value)
  if self:IsSecret(value) or value == nil then
    return nil
  end
  if type(value) == "boolean" then
    return value
  end
  return nil
end

function SafeValues:String(value)
  if self:IsSecret(value) or value == nil then
    return nil
  end
  return type(value) == "string" and value or nil
end

-- Values returned by Blizzard display APIs may be secret. They may only be
-- stored transiently and passed unchanged to a widget that accepts secrets.
function SafeValues:Display(value)
  if self:IsSecret(value) then
    return value
  end
  if value == nil then return nil end
  local valueType = type(value)
  if valueType == "string" or valueType == "number" then
    return value
  end
  return nil
end

function SafeValues:Call(func, ...)
  if type(func) ~= "function" then
    return false, nil
  end
  return pcall(func, ...)
end

function SafeValues:CallMethod(object, methodName, ...)
  if object == nil then
    return false, nil
  end
  local method = object[methodName]
  if type(method) ~= "function" then
    return false, nil
  end
  return pcall(method, object, ...)
end

function SafeValues:DurationNumber(durationObject, methodName)
  if durationObject == nil then
    return nil
  end
  local ok, value
  if REAL_TIME ~= nil then
    ok, value = self:CallMethod(durationObject, methodName, REAL_TIME)
  else
    ok, value = self:CallMethod(durationObject, methodName)
  end
  if not ok then
    return nil
  end
  return self:Number(value)
end

function SafeValues:DurationHasSecrets(durationObject)
  if durationObject == nil then
    return false
  end
  local ok, result = self:CallMethod(durationObject, "HasSecretValues")
  return ok and self:Boolean(result) == true
end

function SafeValues:ShouldSpellAuraBeSecret(spellID)
  local safeSpellID = self:Number(spellID)
  if not safeSpellID or safeSpellID <= 0 then
    return false
  end
  if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
    local ok, result = pcall(C_Secrets.ShouldSpellAuraBeSecret, safeSpellID)
    if ok then
      return self:Boolean(result) == true
    end
  end
  return false
end

function SafeValues:ShouldAurasBeSecret()
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    local ok, result = pcall(C_Secrets.ShouldAurasBeSecret)
    if ok then
      return self:Boolean(result) == true
    end
  end
  return false
end

function SafeValues:ShouldSpellCooldownBeSecret(spellID)
  local safeSpellID = self:Number(spellID)
  if not safeSpellID or safeSpellID <= 0 then
    return false
  end
  if C_Secrets and C_Secrets.ShouldSpellCooldownBeSecret then
    local ok, result = pcall(C_Secrets.ShouldSpellCooldownBeSecret, safeSpellID)
    if ok then
      return self:Boolean(result) == true
    end
  end
  return false
end
