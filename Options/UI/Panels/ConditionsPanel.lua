local _, ns = ...

local Frames = ns.util.Frames

local Panel = {}
ns.panels.ConditionsPanel = Panel

function Panel:Create(parent)
  local host, scroll, frame = Frames.CreateScrollPanel(parent, {
    contentHeight = 480,
    minimumContentWidth = 560,
    fillHeight = true,
  })

  frame.info = Frames.CreateLabel(frame, "Single threshold condition editor for V1.", "GameFontHighlight")
  frame.info:SetPoint("TOPLEFT", 16, -20)

  frame.valueLabel = Frames.CreateLabel(frame, "Seconds", "GameFontNormal")
  frame.valueLabel:SetPoint("TOPLEFT", frame.info, "BOTTOMLEFT", 0, -16)
  frame.valueInput = Frames.CreateInput(frame, 120, 24)
  frame.valueInput:SetPoint("TOPLEFT", frame.valueLabel, "BOTTOMLEFT", 0, -6)

  frame.actionLabel = Frames.CreateLabel(frame, "Action", "GameFontNormal")
  frame.actionLabel:SetPoint("TOPLEFT", frame.valueInput, "BOTTOMLEFT", 0, -16)
  frame.actionDropDown = Frames.CreateDropdown(frame, 150, function(self, level)
    for _, value in ipairs({ "color", "hide", "show", "glow", "desaturate", "text_scale" }) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = value
      info.value = value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame.actionDropDown, value)
        UIDropDownMenu_SetText(frame.actionDropDown, value)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  frame.actionDropDown:SetPoint("TOPLEFT", frame.actionLabel, "BOTTOMLEFT", -14, -4)

  frame.scaleLabel = Frames.CreateLabel(frame, "Text Scale Multiplier", "GameFontNormal")
  frame.scaleLabel:SetPoint("TOPLEFT", frame.actionDropDown, "BOTTOMLEFT", 14, -12)
  frame.scaleInput = Frames.CreateInput(frame, 120, 24)
  frame.scaleInput:SetPoint("TOPLEFT", frame.scaleLabel, "BOTTOMLEFT", 0, -6)

  frame.saveButton = Frames.CreateButton(frame, "Apply Condition", 120, 22, function()
    local aura = ns.Registry:GetAura(ns.db.ui.selectedAuraId)
    if not aura then return end
    aura.conditions[1] = {
      type = "threshold",
      operator = "<=",
      value = tonumber(frame.valueInput:GetText()) or 5,
      action = UIDropDownMenu_GetSelectedValue(frame.actionDropDown) or "color",
      scale = tonumber(frame.scaleInput:GetText()) or 1.25,
      color = { r = 1, g = 0.2, b = 0.2, a = 1 },
    }
    ns.runtime:RefreshAura(aura.id)
  end)
  frame.saveButton:SetPoint("TOPLEFT", frame.scaleInput, "BOTTOMLEFT", 0, -18)
  Frames.StylePrimaryButton(frame.saveButton)

  self.host = host
  self.scroll = scroll
  self.frame = frame
  return host
end

function Panel:Refresh(aura)
  local condition = aura.conditions and aura.conditions[1] or {}
  self.frame.valueInput:SetText(tostring(condition.value or 5))
  UIDropDownMenu_SetSelectedValue(self.frame.actionDropDown, condition.action or "color")
  UIDropDownMenu_SetText(self.frame.actionDropDown, condition.action or "color")
  self.frame.scaleInput:SetText(tostring(condition.scale or 1.25))
end
