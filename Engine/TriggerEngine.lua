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

local PRESENTATION_FIELDS = {
  "icon", "name", "statusText", "message", "durationObject", "duration",
  "expirationTime", "progressType", "value", "total", "timer", "count",
  "stacks", "maxStacks", "stackText", "stackDisplayValue", "hasStackDisplayValue",
  "unit", "matchedUnits", "unitStates", "auraInstanceID", "helpful", "auraIndex",
  "spellId", "itemId", "source", "availability", "isReady", "isEnabled",
  "isUsable", "noCharges", "activeBuff", "activeBuffGlow", "activeGlowStyle", "activeBuffDurationObject", "activeBuffDuration", "activeBuffExpirationTime", "activeBuffSpellIDs", "color", "desaturate", "glow", "entries", "actionEventKey", "debugExtra",
}

local function PresentationScore(state)
  if not state then return -1 end
  local score = state.availability == "available" and 100 or 0
  if state.active == true then score = score + 50 end
  if state.durationObject then score = score + 25 end
  if state.icon then score = score + 10 end
  if state.name and state.name ~= "" then score = score + 5 end
  return score
end

local function CopyPresentation(target, source)
  for _, field in ipairs(PRESENTATION_FIELDS) do target[field] = source[field] end
end

local function MergeStates(base, nextState, op)
  if not nextState then
    return base
  end
  nextState = ns.Schema.NormalizeRuntimeState(nextState)

  if not base then
    nextState._presentationScore = PresentationScore(nextState)
    return nextState
  end

  if op == "AND" then
    local baseScore = base._presentationScore or PresentationScore(base)
    local nextScore = PresentationScore(nextState)
    local combinedMatched = base.matched and nextState.matched
    local combinedShow = base.show and nextState.show
    local combinedActive = base.active and nextState.active
    if nextScore > baseScore then
      CopyPresentation(base, nextState)
      base._presentationScore = nextScore
    else
      base._presentationScore = baseScore
    end
    base.matched = combinedMatched
    base.show = combinedShow
    base.active = combinedActive
    return base
  end

  if not base.matched and nextState.matched then
    nextState._presentationScore = PresentationScore(nextState)
    return nextState
  end

  if not base.matched and PresentationScore(nextState) > (base._presentationScore or PresentationScore(base)) then
    local show, matched, active = base.show, base.matched, base.active
    CopyPresentation(base, nextState)
    base.show, base.matched, base.active = show, matched, active
    base._presentationScore = PresentationScore(nextState)
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
  resolved._presentationScore = nil
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
    stacks = (aura.kind == "icon" or aura.kind == "bar") and 3 or 0,
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

local function AuraUsesMultiStateRegion(aura)
  if not aura or aura.kind == "group" or aura.kind == "dynamic_group" or aura.kind == "interrupt_tracker" then
    return false
  end
  return ns.TriggerBase:AnyTriggerMatches(aura, "trinket_cooldown") == true
end

function ns.Render:CreateRegion(aura, wantsMultiState)
  if wantsMultiState and ns.renderers.MultiStateRegion then
    return ns.renderers.MultiStateRegion:New(aura)
  elseif ns.renderers.NativeAuraRegion and ns.renderers.NativeAuraRegion:CanHandle(aura) then
    return ns.renderers.NativeAuraRegion:New(aura)
  elseif aura.kind == "icon" then
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
  local wantsMultiState = AuraUsesMultiStateRegion(aura)
  local wantsNativeAura = not wantsMultiState
    and ns.renderers.NativeAuraRegion and ns.renderers.NativeAuraRegion:CanHandle(aura) or false
  if region and ((region.isNativeAuraRegion == true) ~= wantsNativeAura
    or (region.isMultiStateRegion == true) ~= wantsMultiState) then
    if region.Release then region:Release() elseif region.frame then region.frame:Hide() end
    region = nil
  end
  if not region then
    region = self:CreateRegion(aura, wantsMultiState)
    ns.runtime:SetRegion(aura.id, region)
  end
  local presentation = state or ns.runtime:GetPresentation(aura.id) or ns.Schema.NormalizeRuntimeState()
  region:Update(aura, presentation)
  local cooldownProvider = ns.providers and ns.providers.spell_cooldown or nil
  if cooldownProvider and cooldownProvider.LogCooldownRenderDebug then
    cooldownProvider:LogCooldownRenderDebug(aura, presentation, region, "render:update")
  end
  ProfileFinish(renderBucket, renderProfile)
end
