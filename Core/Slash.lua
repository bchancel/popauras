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

local function OpenMainWindow(editorMode, activeTab)
  if editorMode then
    ns.db.ui.editorMode = editorMode
  end
  if activeTab then
    ns.db.ui.activeTab = activeTab
  end

  if not ns.ui.MainWindow.frame or not ns.ui.MainWindow.frame:IsShown() then
    ns.ui.MainWindow:Toggle()
  else
    ns.ui.MainWindow:RefreshSelection()
  end
end

local function EnsureDeferredOpenFrame()
  if Slash.deferredOpenFrame then
    return Slash.deferredOpenFrame
  end

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:SetScript("OnEvent", function()
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
  EnsureDeferredOpenFrame()
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

local function GetPerfReportLines()
  local lines = {}
  if ns.Profiler and ns.Profiler.GetSummaryLines then
    for _, line in ipairs(ns.Profiler:GetSummaryLines(14)) do
      lines[#lines + 1] = line
    end
  end
  lines[#lines + 1] = GetMemoryReportLine()
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

local function GetHelpLines()
  return {
    "PopAuras commands:",
    "/pa - toggle the main window",
    "/pa help - show this command list",
    "/pa debug - open the debug window",
    "/pa memory - print memory and cache stats",
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

function Slash:Initialize()
  SLASH_POPAURAS1 = "/pa"
  SLASH_POPAURAS2 = "/popauras"

  SlashCmdList.POPAURAS = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
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
      if ns.ui.MainWindow and ns.ui.MainWindow.IsOpen and not ns.ui.MainWindow:IsOpen() then
        QueueOpenAfterCombat("config", ns.db and ns.db.ui and ns.db.ui.activeTab or nil)
      else
        ns.ui.MainWindow:Toggle()
      end
    else
      ns.ui.MainWindow:Toggle()
    end
  end
end
