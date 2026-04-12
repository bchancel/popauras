local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts

local NewAuraPanel = {}
ns.ui.NewAuraPanel = NewAuraPanel

local GRID_COLUMNS = 3
local GRID_ROWS = 3
local TILE_WIDTH = 224
local TILE_HEIGHT = 154
local TILE_GAP_X = 16
local TILE_GAP_Y = 14
local TILE_LEFT_MARGIN = 18
local TILE_TOP_OFFSET = 72

local auraOptions = {
  {
    kind = "dynamic_group",
    title = "Dynamic Group",
    description = "Automatically arrange child auras with growth, spacing, and sorting rules.",
    accent = { 0.16, 0.78, 0.34 },
    art = "dynamic",
  },
  {
    kind = "group",
    title = "Group",
    description = "Create a fixed container for related auras that you position as a unit.",
    accent = { 0.82, 0.66, 0.18 },
    art = "group",
  },
  {
    kind = "bar",
    title = "Bar Aura",
    description = "Show a timed status bar for cooldowns, buffs, debuffs, casts, or manual timers.",
    accent = { 0.96, 0.44, 0.18 },
    art = "bar",
  },
  {
    kind = "icon",
    title = "Icon Aura",
    description = "Display a single icon with optional timer text, stacks, glow, and cooldown swipe.",
    accent = { 0.88, 0.20, 0.20 },
    art = "icon",
  },
  {
    kind = "text",
    preset = "text",
    title = "Text Aura",
    description = "Display configurable text with custom font, color, anchor, and trigger-driven values.",
    accent = { 0.72, 0.30, 0.92 },
    art = "text",
  },
  {
    kind = "text",
    preset = "death_alert_text",
    title = "Death Alert",
    description = "Show class-colored text when someone in your party or raid dies, with role filters and sounds.",
    accent = { 0.58, 0.24, 0.82 },
    art = "text",
  },
  {
    kind = "interrupt_tracker",
    title = "Interrupt Tracker",
    description = "Track party interrupt cooldowns with sharing, sounds, and sound/role filters.",
    accent = { 0.90, 0.78, 0.12 },
    art = "interrupt",
  },
}

local function CreateArtHost(parent)
  local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  host:SetSize(104, 70)
  host:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  host:SetBackdropColor(0.07, 0.09, 0.13, 0.94)
  host:SetBackdropBorderColor(0.20, 0.26, 0.36, 1)
  return host
end

local function CreatePlaceholderTile(parent)
  local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  tile:SetSize(TILE_WIDTH, TILE_HEIGHT)
  tile:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  tile:SetBackdropColor(0.05, 0.07, 0.10, 0.78)
  tile:SetBackdropBorderColor(0.18, 0.22, 0.28, 0.92)

  tile.accentLine = tile:CreateTexture(nil, "ARTWORK")
  tile.accentLine:SetTexture("Interface\\Buttons\\WHITE8x8")
  tile.accentLine:SetVertexColor(0.34, 0.40, 0.48, 0.95)
  tile.accentLine:SetPoint("TOPLEFT", 0, -1)
  tile.accentLine:SetPoint("TOPRIGHT", 0, -1)
  tile.accentLine:SetHeight(2)

  tile.art = CreateArtHost(tile)
  tile.art:SetPoint("TOP", 0, -14)
  tile.art:SetAlpha(0.85)

  local plus = tile.art:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(plus, 32, "OUTLINE")
  plus:SetPoint("CENTER", 0, 2)
  plus:SetText("+")
  plus:SetTextColor(0.62, 0.68, 0.78)

  tile.title = tile:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(tile.title, 14, "OUTLINE")
  tile.title:SetPoint("TOPLEFT", 12, -96)
  tile.title:SetPoint("TOPRIGHT", -12, -96)
  tile.title:SetJustifyH("CENTER")
  tile.title:SetText("Coming Soon")
  tile.title:SetTextColor(0.82, 0.87, 0.94)

  tile.desc = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tile.desc:SetPoint("TOPLEFT", tile.title, "BOTTOMLEFT", 0, -10)
  tile.desc:SetPoint("TOPRIGHT", tile.title, "BOTTOMRIGHT", 0, -10)
  tile.desc:SetJustifyH("CENTER")
  tile.desc:SetJustifyV("TOP")
  tile.desc:SetText("Reserved for future aura types as the catalog grows.")
  tile.desc:SetTextColor(0.60, 0.68, 0.78)

  return tile
end

local function GetTilePoint(index)
  local column = (index - 1) % GRID_COLUMNS
  local row = math.floor((index - 1) / GRID_COLUMNS)
  return "TOPLEFT", TILE_LEFT_MARGIN + (column * (TILE_WIDTH + TILE_GAP_X)), -TILE_TOP_OFFSET - (row * (TILE_HEIGHT + TILE_GAP_Y))
end

local function BuildIconArt(host)
  local plate = CreateFrame("Frame", nil, host, "BackdropTemplate")
  plate:SetSize(62, 62)
  plate:SetPoint("CENTER")
  plate:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  plate:SetBackdropColor(0.12, 0.04, 0.05, 0.98)
  plate:SetBackdropBorderColor(0.40, 0.40, 0.45, 1)

  local question = plate:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(question, 32, "OUTLINE")
  question:SetPoint("CENTER")
  question:SetText("?")
  question:SetTextColor(0.98, 0.20, 0.16)
end

local function BuildBarArt(host)
  local glow = host:CreateTexture(nil, "ARTWORK")
  glow:SetTexture("Interface\\Buttons\\WHITE8x8")
  glow:SetSize(16, 24)
  glow:SetPoint("LEFT", 16, 0)
  glow:SetVertexColor(1, 0.58, 0.14, 0.92)

  local barFrame = CreateFrame("Frame", nil, host, "BackdropTemplate")
  barFrame:SetSize(90, 18)
  barFrame:SetPoint("LEFT", glow, "RIGHT", 4, 0)
  barFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  barFrame:SetBackdropColor(0.09, 0.07, 0.07, 0.96)
  barFrame:SetBackdropBorderColor(0.38, 0.38, 0.42, 1)

  local fill = barFrame:CreateTexture(nil, "ARTWORK")
  fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  fill:SetVertexColor(0.92, 0.22, 0.16, 1)
  fill:SetPoint("TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMLEFT", 2, 2)
  fill:SetWidth(78)
end

local function BuildInterruptArt(host)
  local colors = {
    { 0.96, 0.84, 0.10 },
    { 0.16, 0.62, 0.98 },
    { 0.24, 0.88, 0.18 },
    { 0.98, 0.58, 0.16 },
    { 0.92, 0.18, 0.58 },
  }

  for index, color in ipairs(colors) do
    local row = CreateFrame("Frame", nil, host, "BackdropTemplate")
    row:SetSize(84, 9)
    row:SetPoint("TOP", 0, -8 - ((index - 1) * 12))
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row:SetBackdropColor(0.06, 0.08, 0.10, 0.96)
    row:SetBackdropBorderColor(0.28, 0.30, 0.34, 1)

    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    fill:SetVertexColor(color[1], color[2], color[3], 1)
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMLEFT", 2, 2)
    fill:SetWidth(58 + ((index % 2 == 0) and 6 or 0))
  end
end

local function BuildGroupArt(host)
  local frame = CreateFrame("Frame", nil, host, "BackdropTemplate")
  frame:SetSize(70, 70)
  frame:SetPoint("CENTER")
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.05, 0.06, 0.08, 0.98)
  frame:SetBackdropBorderColor(0.44, 0.44, 0.48, 1)

  local pieces = {
    { 10, -12, 18, 18, 0.82, 0.68, 0.18 },
    { 32, -32, 18, 18, 0.56, 0.26, 0.92 },
    { 52, -16, 14, 24, 0.88, 0.88, 0.88 },
  }

  for _, piece in ipairs(pieces) do
    local block = frame:CreateTexture(nil, "ARTWORK")
    block:SetTexture("Interface\\Buttons\\WHITE8x8")
    block:SetPoint("TOPLEFT", piece[1], piece[2])
    block:SetSize(piece[3], piece[4])
    block:SetVertexColor(piece[5], piece[6], piece[7], 1)
  end
end

local function BuildDynamicArt(host)
  local rows = {
    { -12, 52 },
    { 6, 42 },
    { 24, 34 },
  }

  for index, rowInfo in ipairs(rows) do
    local row = CreateFrame("Frame", nil, host, "BackdropTemplate")
    row:SetSize(rowInfo[2], 14)
    row:SetPoint("CENTER", rowInfo[1], 14 - ((index - 1) * 20))
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row:SetBackdropColor(0.10, 0.38, 0.72, 0.96)
    row:SetBackdropBorderColor(0.18, 0.72, 1.0, 1)
  end

  local arrow = host:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(arrow, 22, "OUTLINE")
  arrow:SetPoint("CENTER", 0, 6)
  arrow:SetText(">>")
  arrow:SetTextColor(0.28, 0.96, 0.22)
end

local function BuildTextArt(host)
  local shadow = host:CreateTexture(nil, "BACKGROUND")
  shadow:SetTexture("Interface\\Buttons\\WHITE8x8")
  shadow:SetSize(50, 58)
  shadow:SetPoint("CENTER", 4, -2)
  shadow:SetVertexColor(0, 0, 0, 0.30)

  local stoneTop = CreateFrame("Frame", nil, host, "BackdropTemplate")
  stoneTop:SetSize(38, 16)
  stoneTop:SetPoint("CENTER", 0, 12)
  stoneTop:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  stoneTop:SetBackdropColor(0.44, 0.46, 0.52, 0.98)
  stoneTop:SetBackdropBorderColor(0.71, 0.74, 0.80, 1)

  local stoneBody = CreateFrame("Frame", nil, host, "BackdropTemplate")
  stoneBody:SetSize(46, 34)
  stoneBody:SetPoint("TOP", stoneTop, "BOTTOM", 0, -2)
  stoneBody:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  stoneBody:SetBackdropColor(0.34, 0.36, 0.41, 0.98)
  stoneBody:SetBackdropBorderColor(0.66, 0.69, 0.75, 1)

  local stoneInset = stoneBody:CreateTexture(nil, "ARTWORK")
  stoneInset:SetTexture("Interface\\Buttons\\WHITE8x8")
  stoneInset:SetPoint("TOPLEFT", 4, -4)
  stoneInset:SetPoint("BOTTOMRIGHT", -4, 4)
  stoneInset:SetVertexColor(0.22, 0.24, 0.28, 0.88)

  local base = CreateFrame("Frame", nil, host, "BackdropTemplate")
  base:SetSize(56, 8)
  base:SetPoint("TOP", stoneBody, "BOTTOM", 0, -4)
  base:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  base:SetBackdropColor(0.26, 0.28, 0.32, 0.98)
  base:SetBackdropBorderColor(0.54, 0.57, 0.63, 1)

  local crossVert = stoneBody:CreateTexture(nil, "OVERLAY")
  crossVert:SetTexture("Interface\\Buttons\\WHITE8x8")
  crossVert:SetSize(4, 14)
  crossVert:SetPoint("TOP", stoneInset, "TOP", 0, -8)
  crossVert:SetVertexColor(0.76, 0.80, 0.86, 0.90)

  local crossHorz = stoneBody:CreateTexture(nil, "OVERLAY")
  crossHorz:SetTexture("Interface\\Buttons\\WHITE8x8")
  crossHorz:SetSize(14, 4)
  crossHorz:SetPoint("TOP", crossVert, "TOP", 0, -4)
  crossHorz:SetVertexColor(0.76, 0.80, 0.86, 0.90)

  local crack = stoneBody:CreateTexture(nil, "OVERLAY")
  crack:SetTexture("Interface\\Buttons\\WHITE8x8")
  crack:SetSize(3, 12)
  crack:SetPoint("BOTTOM", stoneInset, "BOTTOM", 5, 7)
  crack:SetRotation(math.rad(24))
  crack:SetVertexColor(0.12, 0.13, 0.16, 0.95)

  local moss = host:CreateTexture(nil, "ARTWORK")
  moss:SetTexture("Interface\\Buttons\\WHITE8x8")
  moss:SetSize(16, 4)
  moss:SetPoint("TOPLEFT", base, "BOTTOMLEFT", 6, -2)
  moss:SetVertexColor(0.28, 0.48, 0.22, 0.90)
end

local function BuildArt(host, art)
  if art == "icon" then
    BuildIconArt(host)
  elseif art == "bar" then
    BuildBarArt(host)
  elseif art == "interrupt" then
    BuildInterruptArt(host)
  elseif art == "group" then
    BuildGroupArt(host)
  elseif art == "text" then
    BuildTextArt(host)
  else
    BuildDynamicArt(host)
  end
end

local function StyleTile(tile, hovered)
  local accent = tile.accent or { 0.18, 0.52, 0.88 }
  if hovered then
    tile:SetBackdropColor(0.10, 0.14, 0.22, 0.98)
    tile:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
    tile.title:SetTextColor(1, 0.92, 0.30)
  else
    tile:SetBackdropColor(0.07, 0.09, 0.13, 0.96)
    tile:SetBackdropBorderColor(0.22, 0.28, 0.36, 1)
    tile.title:SetTextColor(0.95, 0.97, 1)
  end
end

local function CreateTile(parent, option)
  local tile = CreateFrame("Button", nil, parent, "BackdropTemplate")
  tile:SetSize(TILE_WIDTH, TILE_HEIGHT)
  tile:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  tile:SetScript("OnClick", function()
    ns.ui.CreateAuraDialog:Show(option.preset or option.kind)
  end)
  tile:SetScript("OnEnter", function(self)
    StyleTile(self, true)
  end)
  tile:SetScript("OnLeave", function(self)
    StyleTile(self, false)
  end)

  tile.accent = option.accent

  tile.accentLine = tile:CreateTexture(nil, "ARTWORK")
  tile.accentLine:SetTexture("Interface\\Buttons\\WHITE8x8")
  tile.accentLine:SetVertexColor(option.accent[1], option.accent[2], option.accent[3], 1)
  tile.accentLine:SetPoint("TOPLEFT", 0, -1)
  tile.accentLine:SetPoint("TOPRIGHT", 0, -1)
  tile.accentLine:SetHeight(2)

  tile.art = CreateArtHost(tile)
  tile.art:SetPoint("TOP", 0, -14)
  BuildArt(tile.art, option.art)

  tile.title = tile:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(tile.title, 16, "OUTLINE")
  tile.title:SetPoint("TOPLEFT", 10, -94)
  tile.title:SetPoint("TOPRIGHT", -10, -94)
  tile.title:SetJustifyH("CENTER")
  tile.title:SetText(option.title)

  tile.desc = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tile.desc:SetPoint("TOPLEFT", tile.title, "BOTTOMLEFT", 0, -8)
  tile.desc:SetPoint("TOPRIGHT", tile.title, "BOTTOMRIGHT", 0, -8)
  tile.desc:SetJustifyH("CENTER")
  tile.desc:SetJustifyV("TOP")
  tile.desc:SetText(option.description)
  tile.desc:SetTextColor(0.76, 0.82, 0.92)

  StyleTile(tile, false)
  return tile
end

function NewAuraPanel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints()

  frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.scroll:SetPoint("TOPLEFT", 0, 0)
  frame.scroll:SetPoint("BOTTOMRIGHT", -28, 0)

  frame.content = CreateFrame("Frame", nil, frame.scroll)
  frame.scroll:SetScrollChild(frame.content)

  local contentWidth = (GRID_COLUMNS * TILE_WIDTH) + ((GRID_COLUMNS - 1) * TILE_GAP_X) + (TILE_LEFT_MARGIN * 2)
  local contentHeight = TILE_TOP_OFFSET + (GRID_ROWS * TILE_HEIGHT) + ((GRID_ROWS - 1) * TILE_GAP_Y) + 24
  frame.content:SetSize(contentWidth, contentHeight)

  frame.summary = Frames.CreateLabel(frame.content, "Choose an aura type to start building.", "GameFontNormalLarge")
  frame.summary:SetPoint("TOPLEFT", 18, -20)
  Fonts.Apply(frame.summary, 18, "OUTLINE")
  frame.summary:SetTextColor(0.92, 0.95, 1)

  frame.hint = Frames.CreateLabel(frame.content, "Pick a base layout first, then give it a name in the create dialog.", "GameFontHighlight")
  frame.hint:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -6)
  frame.hint:SetTextColor(0.76, 0.82, 0.92)

  frame.tiles = {}
  for index, option in ipairs(auraOptions) do
    local tile = CreateTile(frame.content, option)
    tile:SetPoint(GetTilePoint(index))
    frame.tiles[index] = tile
  end

  frame.placeholders = {}
  for index = #auraOptions + 1, (GRID_COLUMNS * GRID_ROWS) do
    local tile = CreatePlaceholderTile(frame.content)
    tile:SetPoint(GetTilePoint(index))
    frame.placeholders[#frame.placeholders + 1] = tile
  end

  self.frame = frame
  return frame
end

function NewAuraPanel:Refresh()
  if self.frame and self.frame.scroll and self.frame.scroll.SetVerticalScroll then
    self.frame.scroll:SetVerticalScroll(0)
  end
end
