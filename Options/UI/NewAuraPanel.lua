local _, ns = ...

local Frames = ns.util.Frames
local Theme = ns.util.Theme

-- "Create a New Aura" picker. Types are grouped into categories and shown as
-- flat tiles on alternating row bands, each with one monochrome glyph from the
-- shared UiType* set (neutral at rest, accent on hover, bright when selected).
-- Choosing a tile opens CreateAuraDialog; creation behaviour is unchanged.
local NewAuraPanel = {}
ns.ui.NewAuraPanel = NewAuraPanel

local COLUMNS = 3
local TILE_HEIGHT = 76
local GLYPH_BOX = 44
local GLYPH_SIZE = 28
local CATEGORY_HEADER_HEIGHT = 32
local CATEGORY_GAP = 14
local CONTENT_TOP = 10

local categories = {
  {
    title = "Containers",
    note = "hold and arrange other auras",
    options = {
      {
        kind = "dynamic_group",
        title = "Dynamic Group",
        description = "Automatically arrange child auras with growth, spacing, and sorting rules.",
        glyph = "UiTypeDynamic",
      },
      {
        kind = "group",
        title = "Group",
        description = "A fixed container for related auras that you position as a unit.",
        glyph = "UiTypeGroup",
      },
    },
  },
  {
    title = "Displays",
    note = "one element driven by triggers",
    options = {
      {
        kind = "icon",
        title = "Icon Aura",
        description = "A single icon with optional timer text, stacks, glow, and cooldown swipe.",
        glyph = "UiTypeIcon",
      },
      {
        kind = "bar",
        title = "Bar Aura",
        description = "A timed status bar for cooldowns, buffs, debuffs, casts, or manual timers.",
        glyph = "UiTypeBar",
      },
      {
        kind = "text",
        preset = "text",
        title = "Text Aura",
        description = "Configurable text with custom font, color, anchor, and trigger-driven values.",
        glyph = "UiTypeText",
      },
    },
  },
  {
    title = "Trackers",
    note = "ready-made, preconfigured",
    options = {
      {
        kind = "text",
        preset = "death_alert_text",
        title = "Death Alert",
        description = "Class-colored text when someone in your party or raid dies, with role filters and sounds.",
        glyph = "UiTypeDeath",
      },
      {
        kind = "interrupt_tracker",
        title = "Interrupt Tracker",
        description = "Party interrupt cooldowns with sharing, sounds, and role filters.",
        glyph = "UiTypeInterrupt",
      },
      {
        kind = "aura_bar_list",
        title = "Buffs and Debuffs",
        description = "Player or target buffs and debuffs as a growing list of timed bars.",
        glyph = "UiTypeAuraBars",
      },
      {
        kind = "icon",
        preset = "nameplate_buffs",
        feature = "feature_nameplate_buffs",
        title = "Nameplate Buffs",
        description = "Blizzard-owned, category-filtered buff icons above hostile NPC nameplates.",
        glyph = "UiTypeNameplate",
      },
    },
  },
}

local function IsOptionEnabled(option)
  return not option.feature
    or (ns.Features and ns.Features:IsEnabled(option.feature) == true)
end

local function StyleTile(tile)
  local selected = NewAuraPanel.selectedTile == tile
  local hovered = tile._popAurasHovered == true
  if selected then
    Theme.SetTexture(tile.background, "accentSoft")
    Theme.SetTexture(tile.glyph, "accentBright")
    Theme.SetText(tile.title, "accentBright")
    Theme.SetBackdrop(tile.glyphBox, "accentSoft", "accent")
  elseif hovered then
    Theme.SetTexture(tile.background, "surfaceHover")
    Theme.SetTexture(tile.glyph, "accent")
    Theme.SetText(tile.title, "text")
    Theme.SetBackdrop(tile.glyphBox, "surfaceRaised", "borderStrong")
  else
    Theme.SetTexture(tile.background, tile.bandColor or "rowOdd")
    Theme.SetTexture(tile.glyph, "textSecondary")
    Theme.SetText(tile.title, "text")
    Theme.SetBackdrop(tile.glyphBox, "surfaceRaised", "border")
  end
  tile.accentBar:SetShown(selected or hovered)
  tile.chevron:SetShown(hovered and not selected)
end

function NewAuraPanel:SelectTile(tile)
  local previous = self.selectedTile
  self.selectedTile = tile
  if previous and previous ~= tile then
    StyleTile(previous)
  end
  if tile then
    StyleTile(tile)
  end
end

function NewAuraPanel:OpenOption(tile)
  if not tile or not tile.option then
    return
  end
  self:SelectTile(tile)
  local option = tile.option
  ns.ui.CreateAuraDialog:Show(option.kind, option.preset, {
    title = option.title,
    category = tile.categoryTitle,
    description = option.description,
    glyph = option.glyph,
    onHide = function()
      if NewAuraPanel.selectedTile == tile then
        NewAuraPanel:SelectTile(nil)
        StyleTile(tile)
      end
    end,
  })
end

local function CreateTile(parent, option, categoryTitle)
  local tile = CreateFrame("Button", nil, parent)
  tile:SetHeight(TILE_HEIGHT)
  tile.option = option
  tile.categoryTitle = categoryTitle

  tile.background = tile:CreateTexture(nil, "BACKGROUND")
  tile.background:SetAllPoints()
  tile.background:SetTexture("Interface\\Buttons\\WHITE8x8")

  tile.divider = tile:CreateTexture(nil, "BORDER")
  tile.divider:SetTexture("Interface\\Buttons\\WHITE8x8")
  tile.divider:SetPoint("TOPLEFT", 0, 0)
  tile.divider:SetPoint("BOTTOMLEFT", 0, 0)
  tile.divider:SetWidth(1)
  Theme.SetTexture(tile.divider, "canvas")

  tile.accentBar = tile:CreateTexture(nil, "ARTWORK")
  tile.accentBar:SetTexture("Interface\\Buttons\\WHITE8x8")
  tile.accentBar:SetPoint("TOPLEFT", 0, 0)
  tile.accentBar:SetPoint("BOTTOMLEFT", 0, 0)
  tile.accentBar:SetWidth(2)
  Theme.SetTexture(tile.accentBar, "accent")
  tile.accentBar:Hide()

  tile.glyphBox = CreateFrame("Frame", nil, tile, "BackdropTemplate")
  tile.glyphBox:SetSize(GLYPH_BOX, GLYPH_BOX)
  tile.glyphBox:SetPoint("LEFT", 16, 0)
  tile.glyph = tile.glyphBox:CreateTexture(nil, "ARTWORK")
  tile.glyph:SetSize(GLYPH_SIZE, GLYPH_SIZE)
  tile.glyph:SetPoint("CENTER")
  tile.glyph:SetTexture(Frames.UI_ICON_PATH .. option.glyph)

  tile.chevron = tile:CreateTexture(nil, "ARTWORK")
  tile.chevron:SetTexture(Frames.UI_ICON_PATH .. "UiChevron")
  tile.chevron:SetSize(12, 12)
  tile.chevron:SetPoint("RIGHT", -12, 0)
  tile.chevron:SetRotation(math.pi / 2)
  Theme.SetTexture(tile.chevron, "textMuted")
  tile.chevron:Hide()

  tile.title = tile:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(tile.title, "controlEmphasis")
  tile.title:SetPoint("TOPLEFT", tile.glyphBox, "TOPRIGHT", 14, -2)
  tile.title:SetPoint("RIGHT", tile, "RIGHT", -28, 0)
  tile.title:SetJustifyH("LEFT")
  tile.title:SetWordWrap(false)
  tile.title:SetText(option.title)

  tile.desc = tile:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(tile.desc, "bodySmall")
  tile.desc:SetPoint("TOPLEFT", tile.title, "BOTTOMLEFT", 0, -4)
  tile.desc:SetPoint("RIGHT", tile, "RIGHT", -28, 0)
  tile.desc:SetJustifyH("LEFT")
  tile.desc:SetJustifyV("TOP")
  tile.desc:SetWordWrap(true)
  if tile.desc.SetMaxLines then
    tile.desc:SetMaxLines(2)
  end
  tile.desc:SetText(option.description)
  Theme.SetText(tile.desc, "textMuted")

  tile:SetScript("OnClick", function(self)
    NewAuraPanel:OpenOption(self)
  end)
  tile:SetScript("OnEnter", function(self)
    self._popAurasHovered = true
    StyleTile(self)
  end)
  tile:SetScript("OnLeave", function(self)
    self._popAurasHovered = false
    StyleTile(self)
  end)
  StyleTile(tile)
  return tile
end

local function CreateCategoryHeader(parent, category)
  local header = CreateFrame("Frame", nil, parent)
  header:SetHeight(CATEGORY_HEADER_HEIGHT)
  header.title = header:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(header.title, "controlSmall")
  header.title:SetPoint("LEFT", 0, 0)
  header.title:SetText(string.upper(category.title))
  Theme.SetText(header.title, "navigation")
  header.note = header:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(header.note, "caption")
  header.note:SetPoint("LEFT", header.title, "RIGHT", 10, 0)
  header.note:SetText(category.note)
  Theme.SetText(header.note, "textMuted")
  return header
end

local function Matches(option, categoryTitle, query)
  if query == "" then
    return true
  end
  local haystack = string.lower(option.title .. " " .. option.description .. " " .. categoryTitle)
  return haystack:find(query, 1, true) ~= nil
end

function NewAuraPanel:Layout()
  local frame = self.frame
  if not frame then
    return
  end
  local width = math.floor(frame.scroll:GetWidth() or 0)
  if width < 300 then
    width = 720
  end
  frame.content:SetWidth(width)
  local tileWidth = math.floor(width / COLUMNS)
  local query = string.lower(frame.filter and frame.filter.input:GetText() or "")
  query = query:gsub("^%s+", ""):gsub("%s+$", "")

  local y = -CONTENT_TOP
  local anyVisible = false
  for _, section in ipairs(frame.sections) do
    local visibleTiles = {}
    for _, tile in ipairs(section.tiles) do
      local show = Matches(tile.option, section.category.title, query)
      tile:SetShown(show)
      if show then
        visibleTiles[#visibleTiles + 1] = tile
      end
    end
    section.header:SetShown(#visibleTiles > 0)
    if #visibleTiles > 0 then
      anyVisible = true
      section.header:ClearAllPoints()
      section.header:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, y)
      section.header:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", 0, y)
      y = y - CATEGORY_HEADER_HEIGHT
      for index, tile in ipairs(visibleTiles) do
        local row = math.floor((index - 1) / COLUMNS)
        local column = (index - 1) % COLUMNS
        tile.bandColor = row % 2 == 0 and "rowOdd" or "rowEven"
        tile.divider:SetShown(column > 0)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", frame.content, "TOPLEFT", column * tileWidth, y - (row * TILE_HEIGHT))
        tile:SetWidth(column == COLUMNS - 1 and (width - (column * tileWidth)) or tileWidth)
        StyleTile(tile)
      end
      y = y - (math.ceil(#visibleTiles / COLUMNS) * TILE_HEIGHT) - CATEGORY_GAP
    end
  end

  frame.empty:SetShown(not anyVisible)
  frame.empty:ClearAllPoints()
  frame.empty:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -CONTENT_TOP - 8)
  frame.content:SetHeight(math.max(1, -y + 8))
end

function NewAuraPanel:FirstVisibleTile()
  for _, section in ipairs(self.frame and self.frame.sections or {}) do
    for _, tile in ipairs(section.tiles) do
      if tile:IsShown() then
        return tile
      end
    end
  end
  return nil
end

local function CreateFilter(panel, host)
  local filter = CreateFrame("Frame", "PopAurasNewAuraFilter", host)
  filter:SetSize(220, 26)
  filter.input = Frames.CreateInput(filter, 220, 26)
  filter.input:SetAllPoints()
  filter.input:SetTextInsets(26, 8, 0, 0)
  filter.icon = filter:CreateTexture(nil, "OVERLAY")
  filter.icon:SetTexture(Frames.UI_ICON_PATH .. "UiSearch")
  filter.icon:SetSize(12, 12)
  filter.icon:SetPoint("LEFT", 9, 0)
  Theme.SetTexture(filter.icon, "textSecondary")
  filter.placeholder = filter:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(filter.placeholder, "bodySmall")
  filter.placeholder:SetPoint("LEFT", 26, 0)
  filter.placeholder:SetText("Filter aura types")
  Theme.SetText(filter.placeholder, "textSecondary")

  filter.input:SetScript("OnTextChanged", function(selfInput)
    filter.placeholder:SetShown((selfInput:GetText() or "") == "" and not selfInput:HasFocus())
    panel:Layout()
  end)
  filter.input:HookScript("OnEditFocusGained", function()
    filter.placeholder:Hide()
  end)
  filter.input:HookScript("OnEditFocusLost", function(selfInput)
    filter.placeholder:SetShown((selfInput:GetText() or "") == "")
  end)
  filter.input:SetScript("OnEnterPressed", function(selfInput)
    selfInput:ClearFocus()
    panel:OpenOption(panel:FirstVisibleTile())
  end)
  filter.input:SetScript("OnEscapePressed", function(selfInput)
    selfInput:SetText("")
    selfInput:ClearFocus()
  end)
  return filter
end

function NewAuraPanel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 0, 0)
  frame.scroll:SetPoint("BOTTOMRIGHT", -20, 0)
  Theme.StyleScrollFrame(frame.scroll)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.content:SetSize(720, 400)
  frame.scroll:SetScrollChild(frame.content)

  frame.sections = {}
  for _, category in ipairs(categories) do
    local section = { category = category, tiles = {} }
    section.header = CreateCategoryHeader(frame.content, category)
    for _, option in ipairs(category.options) do
      if IsOptionEnabled(option) then
        section.tiles[#section.tiles + 1] = CreateTile(frame.content, option, category.title)
      end
    end
    frame.sections[#frame.sections + 1] = section
  end

  frame.empty = frame.content:CreateFontString(nil, "OVERLAY")
  Theme.ApplyTypography(frame.empty, "body")
  frame.empty:SetText("No aura types match that filter.")
  Theme.SetText(frame.empty, "textMuted")
  frame.empty:Hide()

  -- The filter lives in the editor header (where settings search sits in other
  -- modes) and follows this panel's visibility.
  local mainFrame = ns.ui.MainWindow and ns.ui.MainWindow.frame
  local host = mainFrame and mainFrame.editor or parent
  frame.filter = CreateFilter(self, host)
  if mainFrame and mainFrame.closeButton then
    frame.filter:SetPoint("RIGHT", mainFrame.closeButton, "LEFT", -12, 0)
  else
    frame.filter:SetPoint("TOPRIGHT", host, "TOPRIGHT", -56, -16)
  end

  frame:SetScript("OnSizeChanged", function()
    NewAuraPanel:Layout()
  end)
  frame:SetScript("OnShow", function()
    frame.filter:Show()
    NewAuraPanel:Layout()
    NewAuraPanel:ResetScroll()
  end)
  frame:SetScript("OnHide", function()
    frame.filter:Hide()
    if ns.ui.CreateAuraDialog and ns.ui.CreateAuraDialog.frame then
      ns.ui.CreateAuraDialog.frame:Hide()
    end
  end)

  self.frame = frame
  self:Layout()
  return frame
end

-- Reset now and again next frame: on first show the scroll range is not known
-- until layout completes, which left the page scrolled part-way down.
function NewAuraPanel:ResetScroll()
  local frame = self.frame
  if not frame or not frame.scroll then
    return
  end
  frame.scroll:SetVerticalScroll(0)
  C_Timer.After(0, function()
    if frame:IsShown() then
      NewAuraPanel:Layout()
      frame.scroll:SetVerticalScroll(0)
    end
  end)
end

function NewAuraPanel:Refresh()
  self:Layout()
  self:ResetScroll()
end
