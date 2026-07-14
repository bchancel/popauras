local _, ns = ...

local Bootstrap = CreateFrame("Frame")

Bootstrap:RegisterEvent("ADDON_LOADED")
Bootstrap:SetScript("OnEvent", function(_, event, addonName)
  if event ~= "ADDON_LOADED" or addonName ~= ns.name then
    return
  end

  Bootstrap:UnregisterEvent("ADDON_LOADED")
  if math and math.randomseed then
    math.randomseed(math.floor((GetTimePreciseSec() or GetTime()) * 1000))
  end

  ns.SavedVariables:Initialize()
  if ns.NativeAuras and ns.NativeAuras.Initialize then
    ns.NativeAuras:Initialize()
  end
  ns.Events:Initialize()
  if ns.CooldownManager and ns.CooldownManager.Initialize then
    ns.CooldownManager:Initialize()
  end
  if ns.BlizzardAuraFrames and ns.BlizzardAuraFrames.Initialize then
    ns.BlizzardAuraFrames:Initialize()
  end
  if ns.BlizzardSpellAlerts and ns.BlizzardSpellAlerts.Initialize then
    ns.BlizzardSpellAlerts:Initialize()
  end
  if ns.InterruptTracker and ns.InterruptTracker.Initialize then
    ns.InterruptTracker:Initialize()
  end
  ns.Slash:Initialize()
  ns.runtime:RefreshAll()
  if ns.ShareLinks and ns.ShareLinks.Initialize then
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        ns.ShareLinks:Initialize()
      end)
    else
      ns.ShareLinks:Initialize()
    end
  end
end)
