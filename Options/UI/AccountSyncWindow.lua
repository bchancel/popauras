local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

local Window = {}
ns.ui.AccountSyncWindow = Window

local function CreateShell(name, width, height, titleText)
  local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  frame:SetSize(width, height)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(2200)
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  Theme.StyleSurface(frame, "canvas", "borderStrong")
  frame:Hide()

  frame.header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.header:SetPoint("TOPLEFT", 1, -1)
  frame.header:SetPoint("TOPRIGHT", -1, -1)
  frame.header:SetHeight(46)
  frame.header:EnableMouse(true)
  frame.header:RegisterForDrag("LeftButton")
  Theme.StyleSurface(frame.header, "surfaceRaised", "border")
  frame.header:SetScript("OnDragStart", function() frame:StartMoving() end)
  frame.header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

  frame.title = frame.header:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.title, "sectionTitle")
  Theme.SetText(frame.title, "text")
  frame.title:SetPoint("LEFT", 16, 0)
  frame.title:SetText(titleText)

  frame.closeButton = Frames.CreateButton(frame.header, "x", 28, 26, function()
    frame:Hide()
  end)
  frame.closeButton:SetPoint("RIGHT", -9, 0)
  Theme.StyleButton(frame.closeButton, "ghost")
  return frame
end

function Window:CreateTargetPrompt()
  if self.targetFrame then
    return self.targetFrame
  end
  local frame = CreateShell("PopAurasAccountSyncTarget", 520, 230, "Account Sync")

  frame.instructions = Frames.CreateLabel(
    frame,
    "Enter the online character to compare PopAuras collections with.",
    "GameFontHighlight")
  frame.instructions:SetPoint("TOPLEFT", 20, -70)
  frame.instructions:SetWidth(480)
  Theme.SetText(frame.instructions, "textSecondary")

  frame.nameLabel = Frames.CreateLabel(frame, "Player Name-Realm", "GameFontNormal")
  frame.nameLabel:SetPoint("TOPLEFT", 20, -108)
  Theme.SetText(frame.nameLabel, "text")

  frame.nameInput = Frames.CreateInput(frame, 310, 26)
  frame.nameInput:SetPoint("TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, -7)
  frame.nameInput:SetAutoFocus(false)

  frame.sendButton = Frames.CreateButton(frame, "Send Request", 136, 28, function()
    local ok, result = ns.AccountSync:RequestSync(frame.nameInput:GetText())
    if ok then
      frame.status:SetText("|cff66dd99Request sent. Waiting for approval...|r")
    else
      frame.status:SetText("|cffff7777" .. tostring(result or "Unable to send request.") .. "|r")
    end
  end)
  frame.sendButton:SetPoint("LEFT", frame.nameInput, "RIGHT", 14, 0)
  Frames.StylePrimaryButton(frame.sendButton)

  frame.status = Frames.CreateLabel(frame, "", "GameFontHighlightSmall")
  frame.status:SetPoint("TOPLEFT", frame.nameInput, "BOTTOMLEFT", 0, -12)
  frame.status:SetWidth(470)
  Theme.SetText(frame.status, "textMuted")

  frame.nameInput:SetScript("OnEnterPressed", function()
    frame.sendButton:Click()
  end)
  frame.nameInput:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  frame:SetScript("OnShow", function()
    frame.status:SetText("")
    frame.nameInput:SetFocus()
    frame.nameInput:HighlightText()
    frame:Raise()
  end)
  frame:SetScript("OnHide", function()
    frame.nameInput:ClearFocus()
  end)

  self.targetFrame = frame
  return frame
end

local function CreateListPanel(parent, titleText, x)
  local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", x, -128)
  panel:SetSize(500, 452)
  Theme.StyleSurface(panel, "canvasAlt", "border")

  panel.title = Frames.CreateLabel(panel, titleText, "GameFontNormal", "controlEmphasis")
  panel.title:SetPoint("TOPLEFT", 14, -12)
  panel.title:SetWidth(466)
  Theme.SetText(panel.title, "navigation")

  panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  panel.scroll:SetPoint("TOPLEFT", 10, -42)
  panel.scroll:SetPoint("BOTTOMRIGHT", -28, 10)
  Theme.StyleScrollFrame(panel.scroll)

  panel.content = CreateFrame("Frame", nil, panel.scroll)
  panel.content:SetSize(450, 380)
  panel.scroll:SetScrollChild(panel.content)
  panel.rows = {}
  return panel
end

local function KindLabel(kind)
  if kind == "group" then
    return "Group"
  elseif kind == "dynamic_group" then
    return "Dynamic Group"
  end
  return tostring(kind or "Aura"):gsub("_", " "):gsub("^%l", string.upper)
end

local function EnsureLeftRow(panel, index)
  local row = panel.rows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel.content, "BackdropTemplate")
  row:SetSize(446, 34)
  Theme.StyleSurface(row, index % 2 == 0 and "surface" or "canvasAlt", "transparent")
  row.check = Frames.CreateCheckbox(row, "")
  row.check:SetPoint("LEFT", 6, 0)
  row.label = row:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(row.label, "controlSmall")
  Theme.SetText(row.label, "text")
  row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
  row.label:SetWidth(392)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  panel.rows[index] = row
  return row
end

local function EnsureRightRow(panel, index)
  local row = panel.rows[index]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, panel.content, "BackdropTemplate")
  row:SetSize(446, 34)
  Theme.StyleSurface(row, index % 2 == 0 and "surface" or "canvasAlt", "transparent")
  row.label = row:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(row.label, "controlSmall")
  Theme.SetText(row.label, "text")
  row.label:SetPoint("LEFT", 12, 0)
  row.label:SetWidth(420)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  panel.rows[index] = row
  return row
end

function Window:CreateComparison()
  if self.compareFrame then
    return self.compareFrame
  end
  local frame = CreateShell("PopAurasAccountSyncComparison", 1050, 650, "Account Sync Comparison")

  frame.summary = Frames.CreateLabel(frame, "", "GameFontHighlight")
  frame.summary:SetPoint("TOPLEFT", 20, -64)
  frame.summary:SetWidth(1010)
  frame.summary:SetJustifyH("LEFT")
  Theme.SetText(frame.summary, "textSecondary")

  frame.selectAllButton = Frames.CreateButton(frame, "Select All", 100, 28, function()
    for _, row in ipairs(frame.leftPanel.rows) do
      if row:IsShown() and row.check then
        row.check:SetChecked(true)
      end
    end
  end)
  frame.selectAllButton:SetPoint("TOPLEFT", 20, -94)
  Frames.StyleSecondaryButton(frame.selectAllButton)

  frame.selectNoneButton = Frames.CreateButton(frame, "Select None", 100, 28, function()
    for _, row in ipairs(frame.leftPanel.rows) do
      if row.check then
        row.check:SetChecked(false)
      end
    end
  end)
  frame.selectNoneButton:SetPoint("LEFT", frame.selectAllButton, "RIGHT", 8, 0)
  Frames.StyleSecondaryButton(frame.selectNoneButton)

  frame.syncButton = Frames.CreateButton(frame, "Sync Selected", 126, 28, function()
    local selected = {}
    for _, row in ipairs(frame.leftPanel.rows) do
      if row:IsShown() and row.check and row.check:GetChecked() == true and row.auraId then
        selected[row.auraId] = true
      end
    end
    local ok, result = ns.AccountSync:ImportSelected(frame.sessionId, selected)
    if ok then
      frame.status:SetText(string.format("|cff66dd99Requested %d selected aura%s...|r",
        tonumber(result or 0), tonumber(result or 0) == 1 and "" or "s"))
      frame.syncButton:SetEnabled(false)
    else
      frame.status:SetText("|cffff7777" .. tostring(result or "Sync failed.") .. "|r")
    end
  end)
  frame.syncButton:SetPoint("LEFT", frame.selectNoneButton, "RIGHT", 8, 0)
  Frames.StylePrimaryButton(frame.syncButton)

  frame.leftPanel = CreateListPanel(frame, "Available from remote account", 20)
  frame.rightPanel = CreateListPanel(frame, "Your auras missing remotely", 530)

  frame.status = Frames.CreateLabel(frame, "", "GameFontHighlightSmall")
  frame.status:SetPoint("BOTTOMLEFT", 20, 22)
  frame.status:SetWidth(1010)
  Theme.SetText(frame.status, "textMuted")

  frame:SetScript("OnShow", function() frame:Raise() end)
  self.compareFrame = frame
  return frame
end

local function RenderMissingLocal(panel, entries)
  for _, row in ipairs(panel.rows) do
    row:Hide()
  end
  for index, entry in ipairs(entries or {}) do
    local row = EnsureLeftRow(panel, index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * 36))
    row.auraId = entry.id
    row.check:SetChecked(false)
    row.label:SetText(string.format("[%s] %s", KindLabel(entry.kind), entry.path))
    row:Show()
  end
  if #(entries or {}) == 0 then
    local row = EnsureLeftRow(panel, 1)
    row.auraId = nil
    row.check:Hide()
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", 12, 0)
    row.label:SetText("No missing auras.")
    row:Show()
  else
    for index = 1, #entries do
      panel.rows[index].check:Show()
      panel.rows[index].label:ClearAllPoints()
      panel.rows[index].label:SetPoint("LEFT", panel.rows[index].check, "RIGHT", 4, 0)
    end
  end
  panel.content:SetHeight(math.max(380, math.max(1, #(entries or {})) * 36))
  panel.scroll:SetVerticalScroll(0)
end

local function RenderMissingRemote(panel, entries)
  for _, row in ipairs(panel.rows) do
    row:Hide()
  end
  local source = entries or {}
  if #source == 0 then
    source = { { path = "No missing auras.", kind = "status" } }
  end
  for index, entry in ipairs(source) do
    local row = EnsureRightRow(panel, index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * 36))
    row.label:SetText(entry.kind == "status"
      and entry.path
      or string.format("[%s] %s", KindLabel(entry.kind), entry.path))
    row:Show()
  end
  panel.content:SetHeight(math.max(380, #source * 36))
  panel.scroll:SetVerticalScroll(0)
end

function Window:ShowTargetPrompt()
  local frame = self:CreateTargetPrompt()
  frame:Show()
end

function Window:ShowSession(session)
  local frame = self:CreateComparison()
  local comparison = session.comparison or {}
  frame.sessionId = session.id
  frame.title:SetText("Account Sync: " .. tostring(session.target or "Player"))
  frame.summary:SetText(string.format(
    "%d available from %s  |  %d of yours missing remotely  |  %d matching IDs differ (not overwritten)",
    #(comparison.missingLocal or {}),
    tostring(session.target or "remote"),
    #(comparison.missingRemote or {}),
    #(comparison.changed or {})))
  frame.leftPanel.title:SetText("Available from " .. tostring(session.target or "remote"))
  frame.rightPanel.title:SetText("Your auras missing from " .. tostring(session.target or "remote"))
  frame.status:SetText(session.lastStatus or
    "Select the missing auras you want to copy. Required parent groups are included automatically.")
  RenderMissingLocal(frame.leftPanel, comparison.missingLocal)
  RenderMissingRemote(frame.rightPanel, comparison.missingRemote)
  frame.syncButton:SetEnabled(#(comparison.missingLocal or {}) > 0)
  frame:Show()
end
