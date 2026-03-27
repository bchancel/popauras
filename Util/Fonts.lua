local _, ns = ...

local Fonts = {}
ns.util.Fonts = Fonts

Fonts.styles = {
  FRIZQT = { file = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", outline = "" },
  FRIZQT_OUTLINE = { file = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", outline = "OUTLINE" },
  FRIZQT_THICK = { file = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", outline = "THICKOUTLINE" },
  MORPHEUS = { file = "Fonts\\MORPHEUS.TTF", outline = "" },
  SKURRI = { file = "Fonts\\skurri.ttf", outline = "" },
}

function Fonts.Apply(fontString, size, outline, fontFile)
  if not fontString then
    return
  end
  local file = fontFile or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  fontString:SetFont(file, size or 12, outline or "")
end

function Fonts.ApplyStyle(fontString, styleKey, size)
  local style = Fonts.styles[styleKey or "FRIZQT_OUTLINE"] or Fonts.styles.FRIZQT_OUTLINE
  Fonts.Apply(fontString, size, style.outline, style.file)
end
