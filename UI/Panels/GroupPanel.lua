local _, ns = ...

local Frames = ns.util.Frames

local Panel = {}
ns.panels.GroupPanel = Panel

function Panel:Create(parent)
  local host, scroll, frame = Frames.CreateScrollPanel(parent, {
    contentHeight = 480,
    minimumContentWidth = 560,
    fillHeight = true,
  })

  frame.info = Frames.CreateLabel(frame, "Static and dynamic groups preserve manual child order in V1.", "GameFontHighlight")
  frame.info:SetPoint("TOPLEFT", 16, -20)

  frame.upButton = Frames.CreateButton(frame, "Move Up", 100, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if aura and aura.parentId then
      local parent = ns.Registry:GetAura(aura.parentId)
      local idx = ns.util.Tables.IndexOf(parent.children, aura.id)
      if idx and idx > 1 then
        parent.children[idx], parent.children[idx - 1] = parent.children[idx - 1], parent.children[idx]
        ns.runtime:RefreshAll()
        ns.ui.MainWindow:Refresh()
      end
    end
  end)
  frame.upButton:SetPoint("TOPLEFT", frame.info, "BOTTOMLEFT", 0, -18)

  frame.downButton = Frames.CreateButton(frame, "Move Down", 100, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if aura and aura.parentId then
      local parent = ns.Registry:GetAura(aura.parentId)
      local idx = ns.util.Tables.IndexOf(parent.children, aura.id)
      if idx and idx < #parent.children then
        parent.children[idx], parent.children[idx + 1] = parent.children[idx + 1], parent.children[idx]
        ns.runtime:RefreshAll()
        ns.ui.MainWindow:Refresh()
      end
    end
  end)
  frame.downButton:SetPoint("LEFT", frame.upButton, "RIGHT", 8, 0)

  self.host = host
  self.scroll = scroll
  self.frame = frame
  return host
end

function Panel:Refresh(aura)
  local isChild = aura.parentId ~= nil
  self.frame.upButton:SetEnabled(isChild)
  self.frame.downButton:SetEnabled(isChild)
end
