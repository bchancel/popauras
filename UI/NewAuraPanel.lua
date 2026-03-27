local _, ns = ...

local Frames = ns.util.Frames
local Fonts = ns.util.Fonts

local NewAuraPanel = {}
ns.ui.NewAuraPanel = NewAuraPanel

local GRID_COLUMNS = 3
local TILE_WIDTH = 238
local TILE_HEIGHT = 210
local TILE_GAP_X = 18
local TILE_GAP_Y = 22

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
    kind = "interrupt_tracker",
    title = "Interrupt Tracker",
    description = "Track party interrupt cooldowns with BliZzi-compatible sharing, sounds, and filters.",
    accent = { 0.90, 0.78, 0.12 },
    art = "interrupt",
  },
}

local function CreateArtHost(parent)
  local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  host:SetSize(120, 96)
  host:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  host:SetBackdropColor(0.07, 0.09, 0.13, 0.94)
  host:SetBackdropBorderColor(0.20, 0.26, 0.36, 1)
  return host
end

local function BuildIconArt(host)
  local plate = CreateFrame("Frame", nil, host, "BackdropTemplate")
  plate:SetSize(78, 78)
  plate:SetPoint("CENTER")
  plate:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  plate:SetBackdropColor(0.12, 0.04, 0.05, 0.98)
  plate:SetBackdropBorderColor(0.40, 0.40, 0.45, 1)

  local question = plate:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(question, 40, "OUTLINE")
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
    row:SetSize(92, 12)
    row:SetPoint("TOP", 0, -12 - ((index - 1) * 16))
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
    fill:SetWidth(66 + ((index % 2 == 0) and 8 or 0))
  end
end

local function BuildGroupArt(host)
  local frame = CreateFrame("Frame", nil, host, "BackdropTemplate")
  frame:SetSize(82, 82)
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
    { -14, 56 },
    { 8, 46 },
    { 30, 38 },
  }

  for index, rowInfo in ipairs(rows) do
    local row = CreateFrame("Frame", nil, host, "BackdropTemplate")
    row:SetSize(rowInfo[2], 18)
    row:SetPoint("CENTER", rowInfo[1], 20 - ((index - 1) * 26))
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row:SetBackdropColor(0.10, 0.38, 0.72, 0.96)
    row:SetBackdropBorderColor(0.18, 0.72, 1.0, 1)
  end

  local arrow = host:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(arrow, 26, "OUTLINE")
  arrow:SetPoint("CENTER", 0, 8)
  arrow:SetText(">>")
  arrow:SetTextColor(0.28, 0.96, 0.22)
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
    ns.ui.CreateAuraDialog:Show(option.kind)
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
  tile.art:SetPoint("TOP", 0, -18)
  BuildArt(tile.art, option.art)

  tile.title = tile:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(tile.title, 16, "OUTLINE")
  tile.title:SetPoint("TOP", tile.art, "BOTTOM", 0, -14)
  tile.title:SetText(option.title)

  tile.desc = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tile.desc:SetPoint("TOPLEFT", 16, -148)
  tile.desc:SetPoint("TOPRIGHT", -16, -148)
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

  frame.summary = Frames.CreateLabel(frame, "Choose an aura type to start building.", "GameFontNormalLarge")
  frame.summary:SetPoint("TOPLEFT", 18, -20)
  Fonts.Apply(frame.summary, 18, "OUTLINE")
  frame.summary:SetTextColor(0.92, 0.95, 1)

  frame.hint = Frames.CreateLabel(frame, "Pick a base layout first, then give it a name in the create dialog.", "GameFontHighlight")
  frame.hint:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -6)
  frame.hint:SetTextColor(0.76, 0.82, 0.92)

  frame.tiles = {}
  for index, option in ipairs(auraOptions) do
    local tile = CreateTile(frame, option)
    local column = (index - 1) % GRID_COLUMNS
    local row = math.floor((index - 1) / GRID_COLUMNS)
    tile:SetPoint(
      "TOPLEFT",
      18 + (column * (TILE_WIDTH + TILE_GAP_X)),
      -72 - (row * (TILE_HEIGHT + TILE_GAP_Y))
    )
    frame.tiles[index] = tile
  end

  frame.placeholder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.placeholder:SetSize(TILE_WIDTH, TILE_HEIGHT)
  frame.placeholder:SetPoint("TOPLEFT", 18 + (2 * (TILE_WIDTH + TILE_GAP_X)), -72 - (TILE_HEIGHT + TILE_GAP_Y))
  frame.placeholder:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.placeholder:SetBackdropColor(0.05, 0.07, 0.10, 0.72)
  frame.placeholder:SetBackdropBorderColor(0.18, 0.22, 0.28, 0.9)

  frame.placeholderLabel = frame.placeholder:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(frame.placeholderLabel, 15, "OUTLINE")
  frame.placeholderLabel:SetPoint("CENTER", 0, 10)
  frame.placeholderLabel:SetText("More Types Soon")
  frame.placeholderLabel:SetTextColor(0.84, 0.88, 0.95)

  frame.placeholderHint = frame.placeholder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.placeholderHint:SetPoint("TOPLEFT", 16, -108)
  frame.placeholderHint:SetPoint("TOPRIGHT", -16, -108)
  frame.placeholderHint:SetJustifyH("CENTER")
  frame.placeholderHint:SetText("This grid is ready for additional aura types as we expand the catalog.")
  frame.placeholderHint:SetTextColor(0.66, 0.72, 0.82)

  self.frame = frame
  return frame
end

function NewAuraPanel:Refresh()
end
