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
  if ns.CooldownManager and ns.CooldownManager.Initialize then
    ns.CooldownManager:Initialize()
  end
  if ns.InterruptTracker and ns.InterruptTracker.Initialize then
    ns.InterruptTracker:Initialize()
  end
  if ns.ShareLinks and ns.ShareLinks.Initialize then
    ns.ShareLinks:Initialize()
  end
  ns.Events:Initialize()
  ns.Slash:Initialize()
  ns.runtime:RefreshAll()
end)
