local _, ns = ...

local OptionsLoader = {
  pendingCallbacks = {},
  combatNoticeShown = false,
}
ns.OptionsLoader = OptionsLoader

local COMBAT_NOTE = "|cffffff00PopAuras options will open after combat ends.|r"

local function WriteChatLine(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(message)
  else
    print(message)
  end
end

function OptionsLoader:IsLoaded()
  if ns.ui and ns.ui.MainWindow then
    return true
  end
  return C_AddOns and C_AddOns.IsAddOnLoaded
    and C_AddOns.IsAddOnLoaded("PopAuras_Options") == true
end

function OptionsLoader:EnsureLoaded()
  if ns.ui and ns.ui.MainWindow then
    return true
  end
  if InCombatLockdown and InCombatLockdown() then
    return false, "combat"
  end
  if not (C_AddOns and C_AddOns.LoadAddOn) then
    return false, "C_AddOns.LoadAddOn is unavailable"
  end

  local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, "PopAuras_Options")
  if not ok then
    return false, tostring(loaded or "options load failed")
  end
  if loaded ~= true and not self:IsLoaded() then
    return false, tostring(reason or "PopAuras_Options is disabled or missing")
  end
  if not (ns.ui and ns.ui.MainWindow) then
    return false, "PopAuras_Options loaded without registering its editor"
  end
  return true
end

function OptionsLoader:EnsureCombatFrame()
  if self.combatFrame then
    return self.combatFrame
  end
  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function()
    frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    OptionsLoader.combatNoticeShown = false
    local callbacks = OptionsLoader.pendingCallbacks
    OptionsLoader.pendingCallbacks = {}
    for _, callback in ipairs(callbacks) do
      OptionsLoader:Run(callback)
    end
  end)
  self.combatFrame = frame
  return frame
end

function OptionsLoader:Run(callback)
  if type(callback) ~= "function" then
    return false, "options callback is invalid"
  end
  if InCombatLockdown and InCombatLockdown() then
    self:EnsureCombatFrame():RegisterEvent("PLAYER_REGEN_ENABLED")
    self.pendingCallbacks[#self.pendingCallbacks + 1] = callback
    if not self.combatNoticeShown then
      self.combatNoticeShown = true
      WriteChatLine(COMBAT_NOTE)
    end
    return false, "queued"
  end

  local loaded, reason = self:EnsureLoaded()
  if not loaded then
    return false, reason
  end
  local ok, callbackError = pcall(callback)
  if not ok then
    return false, tostring(callbackError or "options callback failed")
  end
  return true
end
