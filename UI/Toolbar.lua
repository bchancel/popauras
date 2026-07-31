local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts
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

function Toolbar:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(52)

  frame.newButton = Frames.CreateButton(frame, "+  New Aura", 140, 36, function()
    ns.ui.MainWindow:OpenNewAuraPicker()
  end)
  frame.newButton:SetPoint("TOPLEFT", 0, 0)
  frame.newButton:SetWidth(140)
  StylePrimaryButton(frame.newButton)
  Fonts.Apply(frame.newButton:GetFontString(), 12, "")

  frame.importButton = Frames.CreateButton(frame, "Import", 74, 36, function()
    ns.ui.MainWindow:OpenGlobalImport()
  end)
  frame.importButton:SetPoint("TOPLEFT", frame.newButton, "TOPRIGHT", 6, 0)
  frame.importButton:SetWidth(74)
  StyleSecondaryButton(frame.importButton)
  Fonts.Apply(frame.importButton:GetFontString(), 10, "")
  CreateTransferIcon(frame.importButton, "down")

  frame.exportButton = Frames.CreateButton(frame, "Export", 74, 36, function()
    if ns.ui.ExportWindow then
      ns.ui.ExportWindow:ShowAll()
    end
  end)
  frame.exportButton:SetPoint("TOPLEFT", frame.importButton, "TOPRIGHT", 6, 0)
  frame.exportButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  StyleSecondaryButton(frame.exportButton)
  Fonts.Apply(frame.exportButton:GetFontString(), 10, "")
  CreateTransferIcon(frame.exportButton, "up")

  frame.contextLabel = frame:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.contextLabel, 10, "OUTLINE")
  frame.contextLabel:SetPoint("RIGHT", 0, 0)
  frame.contextLabel:SetText("MIDNIGHT  •  RETAIL 12.1")
  Theme.SetText(frame.contextLabel, "textMuted")
  frame.contextLabel:Hide()

  frame.divider = Theme.CreateAccentLine(frame, 1, "borderStrong")
  frame.divider:SetPoint("BOTTOMLEFT", 0, 0)
  frame.divider:SetPoint("BOTTOMRIGHT", 0, 0)

  self.frame = frame
  return frame
end
