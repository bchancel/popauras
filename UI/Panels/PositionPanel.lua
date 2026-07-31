local _, ns = ...

local Frames = ns.util.Frames
local Anchors = ns.util.Anchors

local Panel = {}
ns.panels.PositionPanel = Panel

function Panel:Create(parent)
  local host, scroll, frame = Frames.CreateScrollPanel(parent, {
    contentHeight = 480,
    minimumContentWidth = 560,
    fillHeight = true,
  })

  frame.xLabel = Frames.CreateLabel(frame, "X", "GameFontNormal")
  frame.xLabel:SetPoint("TOPLEFT", 16, -20)
  frame.xInput = Frames.CreateInput(frame, 80, 24)
  frame.xInput:SetPoint("TOPLEFT", frame.xLabel, "BOTTOMLEFT", 0, -6)

  frame.yLabel = Frames.CreateLabel(frame, "Y", "GameFontNormal")
  frame.yLabel:SetPoint("LEFT", frame.xInput, "RIGHT", 24, 30)
  frame.yInput = Frames.CreateInput(frame, 80, 24)
  frame.yInput:SetPoint("TOPLEFT", frame.yLabel, "BOTTOMLEFT", 0, -6)

  frame.anchorLabel = Frames.CreateLabel(frame, "Anchor Target", "GameFontNormal")
  frame.anchorLabel:SetPoint("TOPLEFT", frame.xInput, "BOTTOMLEFT", 0, -16)
  frame.anchorDropDown = Frames.CreateDropdown(frame, 180, function(self, level)
    for _, entry in ipairs(Anchors.GetTargetList()) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.label
      info.value = entry.key
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.anchorDropDown, entry.key)
        UIDropDownMenu_SetText(frame.anchorDropDown, entry.label)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.anchorDropDown:SetPoint("TOPLEFT", frame.anchorLabel, "BOTTOMLEFT", -14, -4)

  frame.saveButton = Frames.CreateButton(frame, "Apply Position", 120, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then return end
    aura.position.x = tonumber(frame.xInput:GetText()) or aura.position.x
    aura.position.y = tonumber(frame.yInput:GetText()) or aura.position.y
    aura.position.relativeTo = UIDropDownMenu_GetSelectedValue(frame.anchorDropDown) or "UIParent"
    ns.runtime:RefreshAura(aura.id)
  end)
  frame.saveButton:SetPoint("TOPLEFT", frame.anchorDropDown, "BOTTOMLEFT", 14, -18)
  Frames.StylePrimaryButton(frame.saveButton)

  self.host = host
  self.scroll = scroll
  self.frame = frame
  return host
end

function Panel:Refresh(aura)
  self.frame.xInput:SetText(tostring(aura.position.x or 0))
  self.frame.yInput:SetText(tostring(aura.position.y or 0))
  UIDropDownMenu_SetSelectedValue(self.frame.anchorDropDown, aura.position.relativeTo or "UIParent")
  UIDropDownMenu_SetText(self.frame.anchorDropDown, aura.position.relativeTo or "UIParent")
end
