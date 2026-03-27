local _, ns = ...

local Frames = ns.util.Frames

local Panel = {}
ns.panels.ImportExportPanel = Panel

function Panel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()
  if frame.SetClipsChildren then
    frame:SetClipsChildren(true)
  end

  local function StylePanelButton(button, accent)
    Frames.StyleSecondaryButton(button)
    if accent then
      button:SetBackdropColor(0.09, 0.28, 0.48, 0.96)
      button:SetBackdropBorderColor(0.20, 0.52, 0.82, 1)
    end
  end

  frame.desc = Frames.CreateLabel(frame, "Paste a PopAuras import string here. Export actions use the copy window or a share link. Exporting a selected group includes its child auras.", "GameFontHighlight")
  frame.desc:SetPoint("TOPLEFT", 16, -20)

  frame.boxHolder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.boxHolder:SetPoint("TOPLEFT", frame.desc, "BOTTOMLEFT", 0, -12)
  frame.boxHolder:SetSize(760, 320)
  if frame.boxHolder.SetClipsChildren then
    frame.boxHolder:SetClipsChildren(true)
  end
  frame.boxHolder:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.boxHolder:SetBackdropColor(0.05, 0.07, 0.10, 0.92)
  frame.boxHolder:SetBackdropBorderColor(0.25, 0.33, 0.45, 1)

  frame.scroll = CreateFrame("ScrollFrame", nil, frame.boxHolder, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 8, -8)
  frame.scroll:SetPoint("BOTTOMRIGHT", -30, 8)

  frame.box = CreateFrame("EditBox", nil, frame.scroll, "InputBoxTemplate")
  frame.box:SetMultiLine(true)
  frame.box:SetWidth(714)
  frame.box:SetPoint("TOPLEFT", 0, 0)
  frame.box:SetAutoFocus(false)
  frame.box:SetTextInsets(8, 8, 8, 8)
  frame.box:SetFontObject(ChatFontNormal)
  frame.boxMeasure = frame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
  frame.boxMeasure:SetWidth(698)
  frame.boxMeasure:SetJustifyH("LEFT")
  frame.boxMeasure:SetJustifyV("TOP")
  frame.boxMeasure:Hide()
  frame.box:SetScript("OnEscapePressed", function(selfBox)
    selfBox:ClearFocus()
  end)
  frame.box:SetScript("OnTextChanged", function(selfBox)
    local insetLeft, insetRight, insetTop, insetBottom = selfBox:GetTextInsets()
    local contentWidth = math.max(32, (selfBox:GetWidth() or 714) - (insetLeft or 0) - (insetRight or 0))
    frame.boxMeasure:SetWidth(contentWidth)
    frame.boxMeasure:SetText(selfBox:GetText() ~= "" and selfBox:GetText() or " ")
    local contentHeight = math.max(304, math.ceil((frame.boxMeasure:GetStringHeight() or 0) + (insetTop or 0) + (insetBottom or 0) + 12))
    selfBox:SetHeight(contentHeight)
  end)
  frame.scroll:SetScrollChild(frame.box)
  frame.box:SetHeight(304)

  frame.exportClipboardButton = Frames.CreateButton(frame, "Export to Clipboard", 150, 22, function()
    local selected = ns.db.ui.selectedAuraId
    if not selected then return end
    local encoded = ns.Export:Encode({ selected })
    if ns.Debug and ns.Debug.ShowSnapshot then
      ns.Debug:ShowSnapshot("PopAuras Export", { encoded }, true)
    else
      frame.box:SetText(encoded)
      frame.box:SetFocus()
      frame.box:HighlightText()
    end
  end)
  frame.exportClipboardButton:SetPoint("TOPLEFT", frame.boxHolder, "BOTTOMLEFT", 0, -12)
  StylePanelButton(frame.exportClipboardButton)

  frame.createLinkButton = Frames.CreateButton(frame, "Create Link", 120, 22, function()
    if not (ns.ShareLinks and ns.ShareLinks.CreateLinkForSelection) then
      print("|cffff4444PopAuras:|r Share links are not available.")
      return
    end
    local ok, err = ns.ShareLinks:CreateLinkForSelection()
    if not ok and err then
      print("|cffff4444PopAuras:|r " .. tostring(err))
    end
  end)
  frame.createLinkButton:SetPoint("LEFT", frame.exportClipboardButton, "RIGHT", 8, 0)
  StylePanelButton(frame.createLinkButton, true)

  frame.importButton = Frames.CreateButton(frame, "Import Add", 100, 22, function()
    local ok, err = ns.Import:Apply(frame.box:GetText(), false)
    if not ok then
      print("|cffff4444PopAuras:|r " .. tostring(err))
    end
  end)
  frame.importButton:SetPoint("LEFT", frame.createLinkButton, "RIGHT", 16, 0)
  StylePanelButton(frame.importButton)

  frame.replaceButton = Frames.CreateButton(frame, "Import Replace", 120, 22, function()
    local ok, err = ns.Import:Apply(frame.box:GetText(), true)
    if not ok then
      print("|cffff4444PopAuras:|r " .. tostring(err))
    end
  end)
  frame.replaceButton:SetPoint("LEFT", frame.importButton, "RIGHT", 8, 0)
  StylePanelButton(frame.replaceButton)

  self.frame = frame
  return frame
end

function Panel:SetImportText(text, selectAll)
  if not self.frame or not self.frame.box then
    return
  end
  self.frame.box:SetText(text or "")
  self.frame.box:SetFocus()
  if selectAll ~= false then
    self.frame.box:HighlightText()
  end
end

function Panel:Refresh(aura)
end
