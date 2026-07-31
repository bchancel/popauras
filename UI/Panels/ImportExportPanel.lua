local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

local Panel = {}
ns.panels.ImportExportPanel = Panel

function Panel:Create(parent)
  local host, scroll, frame = Frames.CreateScrollPanel(parent, {
    contentHeight = 560,
    minimumContentWidth = 650,
    fillHeight = true,
  })
  if frame.SetClipsChildren then
    frame:SetClipsChildren(true)
  end

  local function StylePanelButton(button, accent)
    if accent then
      Frames.StylePrimaryButton(button)
      return
    end
    Frames.StyleSecondaryButton(button)
  end

  frame.desc = Frames.CreateLabel(frame, "Paste a PopAuras import string here. Export actions use the copy window or Send Aura. Exporting a selected group includes its child auras.", "GameFontHighlight")
  frame.desc:SetPoint("TOPLEFT", 16, -20)

  frame.boxHolder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.boxHolder:SetPoint("TOPLEFT", frame.desc, "BOTTOMLEFT", 0, -12)
  frame.boxHolder:SetSize(760, 320)
  if frame.boxHolder.SetClipsChildren then
    frame.boxHolder:SetClipsChildren(true)
  end
  Theme.StyleSurface(frame.boxHolder, "canvas", "border")

  frame.scroll = CreateFrame("ScrollFrame", nil, frame.boxHolder, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 8, -8)
  frame.scroll:SetPoint("BOTTOMRIGHT", -30, 8)
  Theme.StyleScrollFrame(frame.scroll)

  frame.box = CreateFrame("EditBox", nil, frame.scroll)
  frame.box:SetMultiLine(true)
  frame.box:SetWidth(714)
  frame.box:SetPoint("TOPLEFT", 0, 0)
  frame.box:SetAutoFocus(false)
  frame.box:EnableMouse(true)
  frame.box:EnableKeyboard(true)
  frame.box:SetMaxLetters(0)
  frame.box:SetTextInsets(8, 8, 8, 8)
  frame.box:SetFontObject(ChatFontNormal)
  frame.box:SetJustifyH("LEFT")
  frame.box:SetJustifyV("TOP")
  frame.box:SetScript("OnMouseUp", function(selfBox)
    selfBox:SetFocus()
  end)
  frame.box:SetScript("OnEditFocusGained", function(selfBox)
    selfBox:HighlightText(0, 0)
  end)
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

  frame.exportClipboardButton = Frames.CreateButton(frame, "Export for Copy", 150, 22, function()
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

  frame.sendTargetInput = Frames.CreateInput(frame, 170, 22)
  frame.sendTargetInput:SetPoint("LEFT", frame.exportClipboardButton, "RIGHT", 12, 0)
  frame.sendTargetInput:SetAutoFocus(false)
  frame.sendTargetLabel = Frames.CreateLabel(frame, "Send To", "GameFontNormalSmall")
  frame.sendTargetLabel:SetPoint("BOTTOMLEFT", frame.sendTargetInput, "TOPLEFT", 0, 4)

  frame.createLinkButton = Frames.CreateButton(frame, "Send Aura", 100, 22, function()
    if not (ns.ShareLinks and ns.ShareLinks.SendSelection) then
      print("|cffff4444PopAuras:|r Aura sharing is not available.")
      return
    end
    local ok, err = ns.ShareLinks:SendSelection(frame.sendTargetInput:GetText())
    if not ok and err then
      print("|cffff4444PopAuras:|r " .. tostring(err))
    end
  end)
  frame.createLinkButton:SetPoint("LEFT", frame.sendTargetInput, "RIGHT", 8, 0)
  StylePanelButton(frame.createLinkButton, true)

  frame.importButton = Frames.CreateButton(frame, "Import", 100, 22, function()
    local importText = frame.box:GetText()
    local preview, previewError = ns.Import:Preview(importText)
    if not preview then
      print("|cffff4444PopAuras:|r " .. tostring(previewError))
      return
    end

    local importName = preview.name ~= "" and preview.name or "PopAuras package"
    Frames.ShowConfirmation({
      title = "Confirm Import",
      message = string.format("Are you sure you want to import \"%s\"?", importName),
      acceptText = "Yes",
      cancelText = "No",
      acceptStyle = "success",
      cancelStyle = "danger",
      onAccept = function()
        local ok, importError = ns.Import:Apply(importText, false)
        if not ok then
          print("|cffff4444PopAuras:|r " .. tostring(importError))
          return
        end
        print(string.format("|cff66ccffPopAuras:|r |cff66ff88Successfully imported \"%s\".|r", importName))
      end,
    })
  end)
  frame.importButton:SetPoint("LEFT", frame.createLinkButton, "RIGHT", 16, 0)
  Frames.StyleSuccessButton(frame.importButton)

  self.host = host
  self.scroll = scroll
  self.frame = frame

  frame.sendTargetInput:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    if frame.createLinkButton and frame.createLinkButton.Click then
      frame.createLinkButton:Click()
    end
  end)
  frame.sendTargetInput:SetScript("OnEscapePressed", function(selfInput)
    selfInput:ClearFocus()
  end)
  return host
end

function Panel:SetImportText(text, selectAll)
  if not self.frame or not self.frame.box then
    return
  end
  self.frame.box:SetText(text or "")
  self.frame.box:EnableMouse(true)
  self.frame.box:EnableKeyboard(true)
  self.frame.box:SetFocus()
  if selectAll ~= false then
    self.frame.box:HighlightText()
  else
    self.frame.box:SetCursorPosition(strlen(text or ""))
  end
end

function Panel:Refresh(aura)
  local hasSelection = aura ~= nil
  self.frame.desc:SetText(hasSelection
    and "Paste a PopAuras import string here. Exporting the selected group includes its child auras."
    or "Paste a PopAuras export string here, review the package name, then confirm the import.")
  self.frame.exportClipboardButton:SetShown(hasSelection)
  self.frame.sendTargetInput:SetShown(hasSelection)
  self.frame.sendTargetLabel:SetShown(hasSelection)
  self.frame.createLinkButton:SetShown(hasSelection)
  self.frame.importButton:ClearAllPoints()
  if hasSelection then
    self.frame.importButton:SetPoint("LEFT", self.frame.createLinkButton, "RIGHT", 16, 0)
  else
    self.frame.importButton:SetPoint("TOPLEFT", self.frame.boxHolder, "BOTTOMLEFT", 0, -12)
  end
end
