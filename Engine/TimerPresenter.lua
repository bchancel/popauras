local _, ns = ...

local Presenter = {}
ns.TimerPresenter = Presenter

function Presenter:AttachCompletion(cooldown, auraID)
  if not cooldown or not auraID then return end
  cooldown._popAurasCompletionAuraID = auraID
  if cooldown._popAurasCompletionHooked == true then return end
  cooldown._popAurasCompletionHooked = true
  cooldown:HookScript("OnCooldownDone", function(owner)
    local id = owner._popAurasCompletionAuraID
    if id and ns.runtime then ns.runtime:RefreshAura(id) end
  end)
end
function Presenter:SetCompletionTimer(cooldown, durationObject, auraID)
  if not cooldown or not durationObject or not cooldown.SetCooldownFromDurationObject then return false end
  self:AttachCompletion(cooldown, auraID)
  local ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, durationObject, true)
  return ok
end

function Presenter:BindText(fontString, durationObject, options)
  if not fontString or not durationObject or not C_DurationUtil or not C_DurationUtil.CreateDurationTextBinding then
    return false
  end
  local binding = fontString._popAurasDurationBinding
  if not binding then
    binding = C_DurationUtil.CreateDurationTextBinding()
    fontString._popAurasDurationBinding = binding
  else
    binding:SetToDefaults()
  end
  options = options or {}
  if options.formatter then binding:SetFormatter(options.formatter) end
  if options.updateInterval then binding:SetUpdateInterval(options.updateInterval) end
  binding:SetExpiredText(options.expiredText or "")
  binding:SetZeroDurationText(options.zeroDurationText or "")
  binding:SetFontString(fontString)
  binding:SetDuration(durationObject)
  binding:SetEnabled(true)
  return true
end

function Presenter:UnbindText(fontString)
  local binding = fontString and fontString._popAurasDurationBinding or nil
  if binding then binding:SetEnabled(false) end
end
