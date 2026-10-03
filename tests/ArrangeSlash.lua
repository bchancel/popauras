-- Standalone regression: lua tests/ArrangeSlash.lua from the repository root.
local ns = { ui = {}, db = { ui = {} } }
local combat, loadCount, createCount, startCount = false, 0, 0, 0
local messages = {}
function InCombatLockdown() return combat end
C_Timer = { After = function(_, callback) callback() end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) messages[#messages + 1] = text end }
SlashCmdList = {}
function CreateFrame()
  return {
    SetScript = function(self, event, callback) self[event] = callback end,
    RegisterEvent = function(self, event) self.registered = event end,
    UnregisterEvent = function(self) self.registered = nil end,
  }
end
local function Load(path)
  assert(loadfile((repository or ".") .. "/" .. path))("PopAuras", ns)
end
C_AddOns = {
  IsAddOnLoaded = function() return ns.ui.MainWindow ~= nil end,
  LoadAddOn = function()
    loadCount = loadCount + 1
    ns.ui.MainWindow = { Create = function(self)
      createCount = createCount + 1
      self.frame = {}
    end }
    ns.ui.ArrangeMode = { Start = function()
      assert(not combat, "Arrange must not start in combat")
      startCount = startCount + 1
    end }
    return true
  end,
}
Load("Core/OptionsLoader.lua")
Load("Core/Slash.lua")
ns.Slash:Initialize()
combat = true
SlashCmdList.POPAURAS("arrange")
assert(loadCount == 0 and createCount == 0 and startCount == 0)
assert(ns.OptionsLoader.combatFrame.registered == "PLAYER_REGEN_ENABLED")
assert(#messages == 1 and #ns.OptionsLoader.pendingCallbacks == 1)
combat = false
ns.OptionsLoader.combatFrame.OnEvent()
assert(loadCount == 1 and createCount == 1 and startCount == 1)
assert(#ns.OptionsLoader.pendingCallbacks == 0)
SlashCmdList.POPAURAS("  ARRANGE  ")
assert(loadCount == 1 and createCount == 1 and startCount == 2)
SlashCmdList.POPAURAS("help")
local hasHelp = false
for _, text in ipairs(messages) do
  if text:find("/pa arrange", 1, true) then hasHelp = true end
end
assert(hasHelp)
print("Arrange slash checks passed for cold options loading, reuse, and combat deferral.")
