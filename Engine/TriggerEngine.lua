local _, ns = ...

local TriggerEngine = {}
ns.TriggerEngine = TriggerEngine

function TriggerEngine:GetProvider(triggerType)
  return ns.providers[triggerType]
end

local function ProfileStart(bucket)
  if ns.Profiler and ns.Profiler.IsEnabled and ns.Profiler:IsEnabled() then
    return ns.Profiler:Begin(bucket)
  end
  return nil
end

local function ProfileFinish(bucket, startedAt)
  if startedAt and ns.Profiler and ns.Profiler.Finish then
    ns.Profiler:Finish(bucket, startedAt)
  end
end

local function MergeStates(base, nextState, op)
  if not nextState then
    return base
  end

  if not base then
    return ns.Schema.NormalizeRuntimeState(nextState)
  end

  if op == "AND" then
    base.matched = base.matched and nextState.matched
    base.show = base.show and nextState.show
    base.active = base.active and nextState.active
    if not base.icon and nextState.icon then base.icon = nextState.icon end
    if (base.name == nil or base.name == "") and nextState.name ~= "" then base.name = nextState.name end
    if (base.statusText == nil or base.statusText == "") and nextState.statusText ~= "" then
      base.statusText = nextState.statusText
    end
    if (base.message == nil or base.message == "") and nextState.message ~= "" then
      base.message = nextState.message
    end
    if nextState.durationObject then
      base.durationObject = nextState.durationObject
    end
    if nextState.auraInstanceID ~= nil then
      base.auraInstanceID = nextState.auraInstanceID
    end
    if nextState.durationObject or (nextState.duration and nextState.duration > 0) then
      base.duration = nextState.duration
      base.expirationTime = nextState.expirationTime
      base.progressType = nextState.progressType
      base.value = nextState.value
      base.total = nextState.total
    end
    return base
  end

  if not base.matched and nextState.matched then
    return ns.Schema.NormalizeRuntimeState(nextState)
  end

  return base
end

function TriggerEngine:EvaluateAura(aura)
  if aura.kind == "group" or aura.kind == "dynamic_group" or aura.kind == "interrupt_tracker" then
    return ns.Schema.NormalizeRuntimeState({
      show = true,
      active = true,
      name = aura.name,
      source = aura.kind,
    })
  end

  local auraBucket = ns.Profiler and ns.Profiler.GetAuraBucket and ns.Profiler:GetAuraBucket("eval_aura", aura) or nil
  local auraProfile = ProfileStart(auraBucket)
  local op = aura.triggerOp or "AND"
  local enabledTriggerCount = 0
  local resolved = op == "OR" and ns.Schema.NormalizeRuntimeState({ show = false, active = false }) or nil
  for index, trigger in ipairs(aura.triggers or {}) do
    if trigger.enabled ~= false and trigger.type then
      enabledTriggerCount = enabledTriggerCount + 1
      local provider = self:GetProvider(trigger.type)
      if provider and provider.Evaluate then
        local providerBucket = string.format("provider_eval:%s", tostring(provider.key or trigger.type or "unknown"))
        local providerProfile = ProfileStart(providerBucket)
        local evaluated = provider:Evaluate(trigger, aura, index)
        ProfileFinish(providerBucket, providerProfile)
        resolved = MergeStates(resolved, evaluated, op)
        if ns.Debug and ns.Debug.LogTrigger then
          ns.Debug:LogTrigger(aura, trigger, evaluated, evaluated and evaluated.debugExtra)
        end
      end
    end
  end

  resolved = resolved or ns.Schema.NormalizeRuntimeState({ show = false, active = false })
  if enabledTriggerCount > 1 then
    resolved.show = resolved.matched == true
  end
  if resolved.name == "" then
    resolved.name = aura.name
  end
  if not resolved.icon and aura.display and aura.display.iconTexture then
    resolved.icon = aura.display.iconTexture
  end
  ProfileFinish(auraBucket, auraProfile)
  return resolved
end

function TriggerEngine:BuildPreviewState(aura)
  local now = GetTime()
  local warriorColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARRIOR or nil
  if aura.kind == "group" or aura.kind == "dynamic_group" or aura.kind == "interrupt_tracker" then
    return ns.Schema.NormalizeRuntimeState({
      show = true,
      active = true,
      name = aura.name,
      statusText = aura.kind == "interrupt_tracker" and "Interrupt Tracker Preview"
        or aura.kind == "dynamic_group" and "Dynamic Group Preview"
        or "Group Preview",
      source = "preview",
    })
  end

  if aura.kind == "aura_bar_list" then
    return ns.Schema.NormalizeRuntimeState({
      show = true,
      active = true,
      icon = 134400,
      name = aura.name,
      stacks = 2,
      duration = 18,
      expirationTime = now + 18,
      progressType = "timed",
      value = 18,
      total = 18,
      source = "preview",
      statusText = "Buffs and Debuffs Preview",
    })
  end

  return ns.Schema.NormalizeRuntimeState({
    show = true,
    active = true,
    icon = 134400,
    name = aura.kind == "text" and "Kahyl" or aura.name,
    stacks = aura.kind == "icon" and 3 or 0,
    duration = aura.kind == "text" and 2 or 12,
    expirationTime = now + (aura.kind == "text" and 2 or 12),
    progressType = "timed",
    value = aura.kind == "text" and 2 or 12,
    total = aura.kind == "text" and 2 or 12,
    isReady = false,
    isUsable = true,
    source = "preview",
    statusText = aura.kind == "text" and "dead" or (aura.kind == "bar" and "Preview Bar" or "Preview Icon"),
    color = aura.kind == "text" and {
      r = (warriorColor and warriorColor.r) or 0.78,
      g = (warriorColor and warriorColor.g) or 0.61,
      b = (warriorColor and warriorColor.b) or 0.43,
      a = 1,
    } or nil,
  })
end

ns.Render = ns.Render or {}

function ns.Render:CreateRegion(aura)
  if aura.kind == "icon" then
    return ns.renderers.IconRegion:New(aura)
  elseif aura.kind == "bar" then
    return ns.renderers.BarRegion:New(aura)
  elseif aura.kind == "aura_bar_list" then
    return ns.renderers.AuraBarListRegion:New(aura)
  elseif aura.kind == "text" then
    return ns.renderers.TextRegion:New(aura)
  elseif aura.kind == "interrupt_tracker" then
    return ns.renderers.InterruptTrackerRegion:New(aura)
  elseif aura.kind == "dynamic_group" then
    return ns.renderers.DynamicGroupRegion:New(aura)
  end
  return ns.renderers.GroupRegion:New(aura)
end

function ns.Render:RenderAura(aura, state)
  local renderBucket = string.format("render:%s", tostring(aura and aura.kind or "unknown"))
  local renderProfile = ProfileStart(renderBucket)
  local region = ns.runtime:GetRegionByAuraId(aura.id)
  if not region then
    region = self:CreateRegion(aura)
    ns.runtime:SetRegion(aura.id, region)
  end
  region:Update(aura, state or ns.runtime:GetPresentation(aura.id) or ns.Schema.NormalizeRuntimeState())
  ProfileFinish(renderBucket, renderProfile)
end
