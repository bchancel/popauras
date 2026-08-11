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
  local featureSnapshot = ns.FeatureInventory and ns.FeatureInventory:Rebuild(false) or nil
  if featureSnapshot and featureSnapshot.needsNativeAuras
      and ns.NativeAuras and ns.NativeAuras.EnsureActive then
    ns.NativeAuras:EnsureActive()
  end
  ns.Events:Initialize(featureSnapshot)
  if featureSnapshot and featureSnapshot.needsCooldownManager
      and ns.CooldownManager and ns.CooldownManager.EnsureActive then
    ns.CooldownManager:EnsureActive(true)
  end
  if ns.BlizzardAuraFrames and ns.BlizzardAuraFrames.Initialize then
    ns.BlizzardAuraFrames:Initialize()
  end
  if featureSnapshot and featureSnapshot.needsSpellAlerts
      and ns.BlizzardSpellAlerts and ns.BlizzardSpellAlerts.EnsureActive then
    ns.BlizzardSpellAlerts:EnsureActive(true)
  end
  if featureSnapshot and featureSnapshot.needsInterruptTracker
      and ns.InterruptTracker and ns.InterruptTracker.EnsureInitialized then
    ns.InterruptTracker:EnsureInitialized(true)
  end
  if featureSnapshot and featureSnapshot.needsSharedMedia and ns.util.Media then
    ns.util.Media:EnsureSharedMedia(true)
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
