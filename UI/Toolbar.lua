local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts

local Toolbar = {}
ns.ui.Toolbar = Toolbar

local function StylePrimaryButton(button)
  Frames.StylePrimaryButton(button)
end

local function StyleSecondaryButton(button)
  Frames.StyleSecondaryButton(button)
end

function Toolbar:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(40)

  frame.newButton = Frames.CreateButton(frame, "New Aura +", 136, 28, function()
    ns.ui.MainWindow:OpenNewAuraPicker()
  end)
  frame.newButton:SetPoint("LEFT", 0, 0)
  StylePrimaryButton(frame.newButton)

  frame.importButton = Frames.CreateButton(frame, "Import", 86, 24, function()
    ns.db.ui.editorMode = "config"
    ns.db.ui.activeTab = "import_export"
    ns.ui.MainWindow:RefreshSelection()
  end)
  frame.importButton:SetPoint("LEFT", frame.newButton, "RIGHT", 16, 0)
  StyleSecondaryButton(frame.importButton)

  frame.exportButton = Frames.CreateButton(frame, "Export", 86, 24, function()
    ns.db.ui.editorMode = "config"
    ns.db.ui.activeTab = "import_export"
    ns.ui.MainWindow:RefreshSelection()
  end)
  frame.exportButton:SetPoint("LEFT", frame.importButton, "RIGHT", 6, 0)
  StyleSecondaryButton(frame.exportButton)

  frame.divider = frame:CreateTexture(nil, "BORDER")
  frame.divider:SetTexture("Interface\\Buttons\\WHITE8x8")
  frame.divider:SetVertexColor(0.20, 0.36, 0.60, 0.8)
  frame.divider:SetPoint("BOTTOMLEFT", 0, -4)
  frame.divider:SetPoint("BOTTOMRIGHT", 0, -4)
  frame.divider:SetHeight(1)

  self.frame = frame
  return frame
end
