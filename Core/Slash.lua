local _, ns = ...

local Slash = {}
ns.Slash = Slash
local PERF_OVERLAY_UPDATE_INTERVAL = 0.2
local COMBAT_OPEN_NOTE = "|cffffff00PopAuras will open after combat ends.|r"

local function WriteChatLine(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(message)
    return
  end
  print(message)
end

local function WriteChatLines(lines)
  for _, line in ipairs(lines or {}) do
    WriteChatLine(line)
  end
end

local function OpenMainWindow(editorMode, activeTab, toggle)
  if ns.OptionsLoader and ns.OptionsLoader.EnsureLoaded then
    local loaded, reason = ns.OptionsLoader:EnsureLoaded()
    if not loaded then
      WriteChatLine(string.format("|cffff4444PopAuras:|r Could not load options: %s", tostring(reason)))
      return false
    end
  end
  if editorMode then
    ns.db.ui.editorMode = editorMode
  end
  if activeTab then
    ns.db.ui.activeTab = activeTab
  end

  if toggle then
    ns.ui.MainWindow:Toggle()
  elseif not ns.ui.MainWindow.frame or not ns.ui.MainWindow.frame:IsShown() then
    ns.ui.MainWindow:Toggle()
  else
    ns.ui.MainWindow:RefreshSelection()
  end
  return true
end

local function EnsureDeferredOpenFrame()
  if Slash.deferredOpenFrame then
    return Slash.deferredOpenFrame
  end

  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function()
    frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local pending = Slash.pendingOpenRequest
    if not pending then
      return
    end
    Slash.pendingOpenRequest = nil
    Slash.pendingOpenNoteShown = false
    OpenMainWindow(pending.editorMode or "config", pending.activeTab)
  end)
  Slash.deferredOpenFrame = frame
  return frame
end

local function QueueOpenAfterCombat(editorMode, activeTab)
  EnsureDeferredOpenFrame():RegisterEvent("PLAYER_REGEN_ENABLED")
  Slash.pendingOpenRequest = {
    editorMode = editorMode or "config",
    activeTab = activeTab,
  }
  if not Slash.pendingOpenNoteShown then
    Slash.pendingOpenNoteShown = true
    WriteChatLine(COMBAT_OPEN_NOTE)
  end
end

local function GetMemoryReportLine()
  if UpdateAddOnMemoryUsage then
    UpdateAddOnMemoryUsage()
  end

  local runtimeStats = ns.runtime and ns.runtime.GetMemoryStats and ns.runtime:GetMemoryStats() or {}
  local cooldownStats = ns.CooldownManager and ns.CooldownManager.GetCacheStats and ns.CooldownManager:GetCacheStats() or {}
  local addonMemoryKB = GetAddOnMemoryUsage and GetAddOnMemoryUsage(ns.name) or 0

  return string.format(
    "PopAuras: %.1f KB | auras=%d states=%d regions=%d timed=%d targetCache=%d learnedDurations=%d talentClasses=%d cooldownFrameCache=%d cooldownAuraCache=%d hookedFrames=%d",
    tonumber(addonMemoryKB or 0) or 0,
    tonumber(runtimeStats.auraCount or 0) or 0,
    tonumber(runtimeStats.stateCount or 0) or 0,
    tonumber(runtimeStats.regionCount or 0) or 0,
    tonumber(runtimeStats.timedRegionCount or 0) or 0,
    tonumber(runtimeStats.targetCacheEntries or 0) or 0,
    tonumber(runtimeStats.learnedDurationCount or 0) or 0,
    tonumber(runtimeStats.talentCatalogClasses or 0) or 0,
    tonumber(cooldownStats.frameCacheEntries or 0) or 0,
    tonumber(cooldownStats.auraStateEntries or 0) or 0,
    tonumber(cooldownStats.hookedFrameEntries or 0) or 0
  )
end

local function YesNo(value)
  return value == true and "yes" or "no"
end

local function GetArchitectureReportLine()
  local snapshot = ns.FeatureInventory and ns.FeatureInventory:GetSnapshot() or {}
  local eventStats = ns.Events and ns.Events.GetSubscriptionStats and ns.Events:GetSubscriptionStats() or {}
  local optionsLoaded = false
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    optionsLoaded = C_AddOns.IsAddOnLoaded("PopAuras_Options") == true
  end

  return string.format(
    "Architecture: configured=%d providers=%d events=%d unitTrackers=%d | native=%s cdm=%s alerts=%s interrupts=%s watchers=%d correlation=%s sharePump=%s options=%s",
    tonumber(snapshot.configuredAuraCount or 0) or 0,
    tonumber(eventStats.activeProviderTypes or snapshot.providerTypeCount or 0) or 0,
    tonumber(eventStats.registeredEvents or 0) or 0,
    tonumber(eventStats.unitTrackers or 0) or 0,
    YesNo(ns.NativeAuras and ns.NativeAuras.IsActive and ns.NativeAuras:IsActive()),
    YesNo(ns.CooldownManager and ns.CooldownManager.IsActive and ns.CooldownManager:IsActive()),
    YesNo(ns.BlizzardSpellAlerts and ns.BlizzardSpellAlerts.IsActive and ns.BlizzardSpellAlerts:IsActive()),
    YesNo(ns.InterruptTracker and ns.InterruptTracker.IsActive and ns.InterruptTracker:IsActive()),
    tonumber(ns.InterruptTracker and ns.InterruptTracker.GetWatcherCount
      and ns.InterruptTracker:GetWatcherCount() or 0) or 0,
    YesNo(ns.InterruptTracker and ns.InterruptTracker.IsCorrelationDriverArmed
      and ns.InterruptTracker:IsCorrelationDriverArmed()),
    YesNo(ns.ShareLinks and ns.ShareLinks.sendPump and ns.ShareLinks.sendPump:IsShown()),
    YesNo(optionsLoaded)
  )
end

local function GetPerfReportLines()
  local lines = {}
  if ns.Profiler and ns.Profiler.GetSummaryLines then
    for _, line in ipairs(ns.Profiler:GetSummaryLines(14)) do
      lines[#lines + 1] = line
    end
  end
  lines[#lines + 1] = GetMemoryReportLine()
  lines[#lines + 1] = GetArchitectureReportLine()
  return lines
end

local function ShowPerfDebugReport(lines)
  if ns.Debug and ns.Debug.ShowSnapshot then
    ns.Debug:ShowSnapshot("PopAuras Perf Report", lines, true)
    return
  end

  if ns.Debug and ns.Debug.Log then
    ns.Debug:Clear()
    for _, line in ipairs(lines or {}) do
      ns.Debug:Log("Perf", line)
    end
    if ns.Debug.ToggleWindow then
      ns.Debug:ToggleWindow()
    end
  end
end

local function ShowLiveDebugWindow()
  if not (ns.Debug and ns.Debug.CreateWindow) then
    return
  end

  local frame = ns.Debug:CreateWindow()
  if ns.Debug.ResumeLive then
    ns.Debug:ResumeLive()
  end
  if not frame:IsShown() then
    frame:Show()
  end
  if ns.Debug.RefreshWindow then
    ns.Debug:RefreshWindow()
  end
end

local function GetHelpLines()
  return {
    "PopAuras commands:",
    "/pa - toggle the main window",
    "/pa help - show this command list",
    "/pa debug - open the debug window",
    "/pa memory - print memory and cache stats",
    "/pa cddebug <spell id|exact name> - watch one cooldown with targeted debug logging",
    "/pa cddebug now|show|status|off - snapshot, open history, check status, or stop watching",
    "/pa perf - toggle the on-screen perf button",
    "/pa perf start - start perf capture",
    "/pa perf stop - stop perf capture, print report, and open a copyable debug report",
    "/pa perf report - print the current perf report",
    "/pa perf reset - clear perf samples",
    "/pa export - open the import/export tab",
    "/pa import - open the import/export tab",
    "/pa version - show local version, or scan group versions when in a party/raid",
  }
end

local function FormatCaptureSeconds()
  local startedAt = ns.Profiler and ns.Profiler.startedAt or 0
  local now = GetTime and GetTime() or 0
  return string.format("%.1fs", math.max(0, now - (startedAt or 0)))
end

local function StartPerfCapture()
  if ns.Profiler and ns.Profiler.Start then
    ns.Profiler:Start()
    WriteChatLine("PopAuras perf capture started. Reproduce the stutter, then run /pa perf stop.")
  end
end

local function StopPerfCapture()
  if ns.Profiler and ns.Profiler.Stop and ns.Profiler.GetSummaryLines then
    ns.Profiler:Stop()
    local lines = GetPerfReportLines()
    WriteChatLines(lines)
    ShowPerfDebugReport(lines)
  end
end

local function StylePerfButton(button, isRunning)
  if not button then
    return
  end

  if isRunning then
    button:SetBackdropColor(0.34, 0.10, 0.10, 0.98)
    button:SetBackdropBorderColor(0.78, 0.28, 0.22, 1)
    if button.Text then
      button.Text:SetTextColor(1, 0.94, 0.90)
    end
  else
    button:SetBackdropColor(0.10, 0.22, 0.12, 0.98)
    button:SetBackdropBorderColor(0.25, 0.66, 0.32, 1)
    if button.Text then
      button.Text:SetTextColor(0.92, 1, 0.92)
    end
  end
end

local function RefreshPerfOverlay()
  local frame = Slash.perfOverlay
  if not frame then
    return
  end

  local running = ns.Profiler and ns.Profiler.IsEnabled and ns.Profiler:IsEnabled() or false
  if frame.button then
    if running then
      frame.button:SetText("Stop Performance Analysis: " .. FormatCaptureSeconds())
    else
      frame.button:SetText("PopAuras Performance: Start")
    end
    StylePerfButton(frame.button, running)
  end

  if frame.subtitle then
    if running then
      frame.subtitle:SetText("Capture is running. Click the button again to stop and open a copyable report.")
    else
      frame.subtitle:SetText("Click to clear old samples and start a fresh capture. Drag the frame to move it.")
    end
  end
end

local function EnsurePerfOverlay()
  if Slash.perfOverlay then
    return Slash.perfOverlay
  end

  local frame = CreateFrame("Frame", "PopAurasPerfOverlay", UIParent, "BackdropTemplate")
  frame:SetSize(460, 120)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -170)
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.05, 0.07, 0.10, 0.96)
  frame:SetBackdropBorderColor(0.26, 0.32, 0.40, 1)
  frame:Hide()
  ns.util.Frames.MakeMovable(frame)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", 0, -12)
  frame.title:SetText("PopAuras Performance")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
  frame.subtitle:SetWidth(420)
  frame.subtitle:SetJustifyH("CENTER")
  frame.subtitle:SetTextColor(0.82, 0.88, 0.96)

  frame.button = ns.util.Frames.CreateButton(frame, "PopAuras Performance: Start", 400, 52, function()
    if ns.Profiler and ns.Profiler.IsEnabled and ns.Profiler:IsEnabled() then
      StopPerfCapture()
    else
      StartPerfCapture()
    end
    RefreshPerfOverlay()
  end)
  frame.button:SetPoint("BOTTOM", 0, 16)
  if frame.button.Text then
    ns.util.Fonts.Apply(frame.button.Text, 16, "OUTLINE")
  end

  frame.elapsedSinceUpdate = 0
  frame:SetScript("OnShow", function(self)
    self.elapsedSinceUpdate = 0
    RefreshPerfOverlay()
  end)
  frame:SetScript("OnUpdate", function(self, elapsed)
    if not (ns.Profiler and ns.Profiler.IsEnabled and ns.Profiler:IsEnabled()) then
      return
    end
    self.elapsedSinceUpdate = (self.elapsedSinceUpdate or 0) + (elapsed or 0)
    if self.elapsedSinceUpdate < PERF_OVERLAY_UPDATE_INTERVAL then
      return
    end
    self.elapsedSinceUpdate = 0
    RefreshPerfOverlay()
  end)

  Slash.perfOverlay = frame
  RefreshPerfOverlay()
  return frame
end

local function TogglePerfOverlay()
  local frame = EnsurePerfOverlay()
  if frame:IsShown() then
    frame:Hide()
  else
    RefreshPerfOverlay()
    frame:Show()
  end
end

local function HandleSlashCommand(msg)
  local rawMsg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  msg = rawMsg:lower()
  if msg == "debug" then
    if ns.Debug and ns.Debug.ToggleWindow then
      ns.Debug:ToggleWindow()
    end
    return
  end
  if msg == "memory" then
    WriteChatLine(GetMemoryReportLine())
    return
  end
  if msg == "help" then
    WriteChatLines(GetHelpLines())
    return
  end
  if msg == "cddebug" or msg:find("^cddebug%s") then
    local provider = ns.providers and ns.providers.spell_cooldown or nil
    if not provider then
      WriteChatLine("Spell cooldown debug is unavailable right now.")
      return
    end

    local command = msg:match("^cddebug%s*(.-)%s*$") or ""
    local rawCommand = rawMsg:match("^cddebug%s*(.-)%s*$") or ""
    if command == "" or command == "status" then
      if provider.GetCooldownDebugStatusLine then
        WriteChatLine(provider:GetCooldownDebugStatusLine())
      end
      return
    end
    if command == "off" or command == "stop" or command == "clear" then
      if provider.ClearCooldownDebugSpell then
        provider:ClearCooldownDebugSpell()
      end
      WriteChatLine("Cooldown debug watch stopped.")
      return
    end
    if command == "show" or command == "report" then
      if provider.ShowCooldownDebugHistory then
        provider:ShowCooldownDebugHistory()
      end
      return
    end
    if command == "now" or command == "snapshot" then
      if provider.CaptureCooldownDebugSnapshot and provider:CaptureCooldownDebugSnapshot("manual_snapshot") then
        WriteChatLine("Captured a cooldown debug snapshot.")
      else
        WriteChatLine("Enable cooldown debug first with /pa cddebug <spell id|exact name>.")
      end
      return
    end

    local spellId, resolveError = nil, nil
    if provider.ResolveCooldownDebugSpellID then
      spellId, resolveError = provider:ResolveCooldownDebugSpellID(rawCommand)
    end
    if type(spellId) ~= "number" or spellId <= 0 then
      WriteChatLine(resolveError or "Unable to resolve that cooldown spell. Use the numeric spell ID if needed.")
      return
    end

    if ns.Debug and ns.Debug.Clear then
      ns.Debug:Clear()
    end
    ShowLiveDebugWindow()
    if provider.SetCooldownDebugSpell then
      provider:SetCooldownDebugSpell(spellId)
    end
    WriteChatLine(string.format(
      "Watching cooldown debug for %s. Reproduce the issue, then use /pa cddebug show.",
      (provider.GetCooldownDebugSpellLabel and provider:GetCooldownDebugSpellLabel()) or tostring(spellId)
    ))
    return
  end
  if msg == "perf" or msg:find("^perf%s") then
    local command = msg:match("^perf%s*(.-)%s*$") or ""
    if command == "" then
      TogglePerfOverlay()
      return
    end
    if command == "start" or command == "on" then
      StartPerfCapture()
      RefreshPerfOverlay()
      return
    end
    if command == "stop" or command == "off" then
      StopPerfCapture()
      RefreshPerfOverlay()
      return
    end
    if command == "reset" then
      if ns.Profiler and ns.Profiler.Reset then
        ns.Profiler:Reset()
        WriteChatLine("PopAuras perf data reset.")
      end
      RefreshPerfOverlay()
      return
    end
    if command == "report" then
      WriteChatLines(GetPerfReportLines())
      return
    end
    WriteChatLine("Usage: /pa perf | start | stop | report | reset")
    return
  end
  if msg == "version" or msg == "ver" then
    if ns.VersionCheck then
      ns.VersionCheck:StartCheck()
    end
    return
  end
  if msg == "export" or msg == "import" then
    if InCombatLockdown and InCombatLockdown() then
      QueueOpenAfterCombat("config", "import_export")
    else
      OpenMainWindow("config", "import_export")
    end
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    if ns.ui.MainWindow and ns.ui.MainWindow.IsOpen and ns.ui.MainWindow:IsOpen() then
      ns.ui.MainWindow:Toggle()
    else
      QueueOpenAfterCombat("config", ns.db and ns.db.ui and ns.db.ui.activeTab or nil)
    end
  else
    OpenMainWindow("config", ns.db and ns.db.ui and ns.db.ui.activeTab or nil, true)
  end
end

function Slash:Initialize()
  SLASH_POPAURAS1 = "/pa"
  SLASH_POPAURAS2 = "/popauras"

  SlashCmdList.POPAURAS = function(msg)
    C_Timer.After(0, function()
      HandleSlashCommand(msg)
    end)
  end
end
