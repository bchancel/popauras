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
    kind = "private_aura_frame",
    title = "Private Aura Frame",
    description = "Anchor DBM-style private aura icons for yourself or your co-tank with a compact growth layout.",
    accent = { 0.22, 0.70, 0.96 },
    art = "private_aura",
  },
  {
    kind = "aura_bar_list",
    title = "Buffs and Debuffs",
    description = "Render player or target buffs and debuffs as a growing list of timed bars instead of icons.",
    accent = { 0.22, 0.78, 0.66 },
    art = "aura_bars",
  },
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
    art = "text_aura",
  },
  {
    kind = "text",
    preset = "death_alert_text",
    title = "Death Alert",
    description = "Show class-colored text when someone in your party or raid dies, with role filters and sounds.",
    accent = { 0.58, 0.24, 0.82 },
    art = "death_alert",
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
  glow:SetSize(14, 22)
  glow:SetPoint("LEFT", 6, 0)
  glow:SetVertexColor(1, 0.58, 0.14, 0.92)

  local barFrame = CreateFrame("Frame", nil, host, "BackdropTemplate")
  barFrame:SetSize(74, 18)
  barFrame:SetPoint("LEFT", glow, "RIGHT", 3, 0)
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
  fill:SetWidth(62)
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

local function BuildTextAuraArt(host)
  local label = host:CreateFontString(nil, "OVERLAY")
  Fonts.Apply(label, 36, "OUTLINE")
  label:SetPoint("CENTER", 0, 2)
  label:SetText("Abc")
  label:SetTextColor(0.82, 0.72, 0.98)
end

local function BuildDeathAlertArt(host)
  local skullFrame = CreateFrame("Frame", nil, host, "BackdropTemplate")
  skullFrame:SetSize(38, 42)
  skullFrame:SetPoint("CENTER", 0, 2)
  skullFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  skullFrame:SetBackdropColor(0.18, 0.06, 0.10, 0.98)
  skullFrame:SetBackdropBorderColor(0.52, 0.18, 0.30, 1)

  local leftEye = skullFrame:CreateTexture(nil, "ARTWORK")
  leftEye:SetTexture("Interface\\Buttons\\WHITE8x8")
  leftEye:SetSize(8, 8)
  leftEye:SetPoint("CENTER", -8, 6)
  leftEye:SetVertexColor(0.92, 0.20, 0.20, 1)

  local rightEye = skullFrame:CreateTexture(nil, "ARTWORK")
  rightEye:SetTexture("Interface\\Buttons\\WHITE8x8")
  rightEye:SetSize(8, 8)
  rightEye:SetPoint("CENTER", 8, 6)
  rightEye:SetVertexColor(0.92, 0.20, 0.20, 1)

  local jaw = skullFrame:CreateTexture(nil, "ARTWORK")
  jaw:SetTexture("Interface\\Buttons\\WHITE8x8")
  jaw:SetSize(20, 4)
  jaw:SetPoint("CENTER", 0, -10)
  jaw:SetVertexColor(0.68, 0.22, 0.30, 0.90)

  local crossV = host:CreateTexture(nil, "OVERLAY")
  crossV:SetTexture("Interface\\Buttons\\WHITE8x8")
  crossV:SetSize(4, 56)
  crossV:SetPoint("CENTER", 0, 0)
  crossV:SetVertexColor(0.58, 0.20, 0.28, 0.35)

  local crossH = host:CreateTexture(nil, "OVERLAY")
  crossH:SetTexture("Interface\\Buttons\\WHITE8x8")
  crossH:SetSize(56, 4)
  crossH:SetPoint("CENTER", 0, 0)
  crossH:SetVertexColor(0.58, 0.20, 0.28, 0.35)
end

local function BuildPrivateAuraArt(host)
  for index = 1, 3 do
    local slot = CreateFrame("Frame", nil, host, "BackdropTemplate")
    slot:SetSize(20, 20)
    slot:SetPoint("LEFT", 8 + ((index - 1) * 26), 0)
    slot:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    slot:SetBackdropColor(0.08, 0.13, 0.18, 0.98)
    slot:SetBackdropBorderColor(0.32, 0.70, 0.96, 1)

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture("Interface\\Icons\\spell_shadow_mindtwisting")
  end
end

local function BuildAuraBarsArt(host)
  for index = 1, 3 do
    local row = CreateFrame("Frame", nil, host, "BackdropTemplate")
    row:SetSize(84, 12)
    row:SetPoint("TOP", 0, -8 - ((index - 1) * 18))
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    row:SetBackdropColor(0.08, 0.10, 0.12, 0.96)
    row:SetBackdropBorderColor(0.20, 0.26, 0.32, 1)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(12, 12)
    icon:SetPoint("RIGHT", row, "LEFT", -4, 0)
    icon:SetTexture("Interface\\Icons\\spell_holy_renew")

    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    fill:SetVertexColor(0.22, 0.78, 0.66, 1)
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMLEFT", 2, 2)
    fill:SetWidth(58 - ((index - 1) * 10))
  end
end

local function BuildArt(host, art)
  if art == "private_aura" then
    BuildPrivateAuraArt(host)
  elseif art == "aura_bars" then
    BuildAuraBarsArt(host)
  elseif art == "icon" then
    BuildIconArt(host)
  elseif art == "bar" then
    BuildBarArt(host)
  elseif art == "interrupt" then
    BuildInterruptArt(host)
  elseif art == "group" then
    BuildGroupArt(host)
  elseif art == "text_aura" then
    BuildTextAuraArt(host)
  elseif art == "death_alert" then
    BuildDeathAlertArt(host)
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
    ns.ui.CreateAuraDialog:Show(option.kind, option.preset)
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
