local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

local Toolbar = {}
ns.ui.Toolbar = Toolbar

local function AddIconLine(icon, width, height, x, y, rotation)
  local line = icon:CreateTexture(nil, "ARTWORK")
  line:SetTexture("Interface\\Buttons\\WHITE8x8")
  line:SetSize(width, height)
  line:SetPoint("CENTER", icon, "CENTER", x or 0, y or 0)
  if rotation and line.SetRotation then
    line:SetRotation(rotation)
  end
  icon.lines[#icon.lines + 1] = line
end

local function CreateTransferIcon(button, direction)
  local icon = CreateFrame("Frame", nil, button)
  icon:SetSize(16, 16)
  icon:SetPoint("LEFT", 8, 0)
  icon.lines = {}
  local sign = direction == "up" and 1 or -1
  AddIconLine(icon, 2, 9, 0, -sign)
  AddIconLine(icon, 2, 7, -3, sign * 3, -math.rad(45) * sign)
  AddIconLine(icon, 2, 7, 3, sign * 3, math.rad(45) * sign)
  for _, line in ipairs(icon.lines) do
    Theme.SetTexture(line, "textAccent")
  end
  button.Text:ClearAllPoints()
  button.Text:SetPoint("CENTER", 8, 0)
  return icon
end

local function StylePrimaryButton(button)
  Frames.StylePrimaryButton(button)
end

local function StyleSecondaryButton(button)
  Frames.StyleSecondaryButton(button)
end

-- A single compact row that sits at the bottom of the sidebar: one accent
-- action (New Aura) and three quiet ghost actions.
local TOOLBAR_BUTTON_HEIGHT = 26

function Toolbar:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(TOOLBAR_BUTTON_HEIGHT + 4)

  frame.newButton = Frames.CreateButton(frame, "+ New Aura", 88, TOOLBAR_BUTTON_HEIGHT, function()
    ns.ui.MainWindow:OpenNewAuraPicker()
  end)
  frame.newButton:SetPoint("LEFT", 0, 0)
  frame.newButton:SetWidth(88)
  StylePrimaryButton(frame.newButton)
  Theme.ApplyTypography(frame.newButton:GetFontString(), "controlSmall")

  frame.arrangeButton = Frames.CreateButton(frame, "Arrange", 66, TOOLBAR_BUTTON_HEIGHT, function()
    ns.ui.ArrangeMode:Start()
  end)
  frame.arrangeButton:SetPoint("LEFT", frame.newButton, "RIGHT", 4, 0)
  Theme.StyleButton(frame.arrangeButton, "ghost")
  Theme.ApplyTypography(frame.arrangeButton:GetFontString(), "caption")

  frame.importButton = Frames.CreateButton(frame, "Import", 70, TOOLBAR_BUTTON_HEIGHT, function()
    ns.ui.MainWindow:OpenGlobalImport()
  end)
  frame.importButton:SetPoint("LEFT", frame.arrangeButton, "RIGHT", 2, 0)
  frame.importButton:SetWidth(70)
  Theme.StyleButton(frame.importButton, "ghost")
  Theme.ApplyTypography(frame.importButton:GetFontString(), "caption")
  CreateTransferIcon(frame.importButton, "down")

  frame.exportButton = Frames.CreateButton(frame, "Export", 70, TOOLBAR_BUTTON_HEIGHT, function()
    if ns.ui.ExportWindow then
      ns.ui.ExportWindow:ShowAll()
    end
  end)
  frame.exportButton:SetPoint("LEFT", frame.importButton, "RIGHT", 2, 0)
  frame.exportButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  Theme.StyleButton(frame.exportButton, "ghost")
  Theme.ApplyTypography(frame.exportButton:GetFontString(), "caption")
  CreateTransferIcon(frame.exportButton, "up")

  frame.contextLabel = frame:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.contextLabel, "caption", "OUTLINE")
  frame.contextLabel:SetPoint("RIGHT", 0, 0)
  frame.contextLabel:SetText("MIDNIGHT  •  RETAIL 12.1")
  Theme.SetText(frame.contextLabel, "textMuted")
  frame.contextLabel:Hide()

  frame.divider = Theme.CreateAccentLine(frame, 1, "border")
  frame.divider:SetPoint("TOPLEFT", 0, 4)
  frame.divider:SetPoint("TOPRIGHT", 0, 4)

  self.frame = frame
  return frame
end
