# Arrange icons

Original artwork created with the built-in imagegen tool. The attached examples
were inspiration for familiar symbols; no stock artwork was copied into the addon.

The bundled textures are uncompressed 64x64, 32-bit RGBA TGA files. Transparent
padding and the generated alpha channel are preserved when reducing the artwork.
Arrange displays each texture at 18x18 inside a 24x24 click target.

- `ArrangeAnchor.tga`: anchor and position settings.
- `ArrangeCenter.tga`: move to the screen center.
- `ArrangeReset.tga`: restore the position from before entering Arrange.
- `ArrangeConfigure.tga`: save the layout and open Display options.

## Prompt set

Each initial generation requested one centered, simple flat monochrome white
glyph on a transparent alpha background, with bold geometry for an 18-pixel UI
control, generous padding, and no tile, checkerboard, text, watermark, gradient,
shadow, border, or glow. The subjects were:

- Anchor: a compact traditional nautical anchor, open round eye, vertical stem,
  horizontal crossbar, and symmetric curved flukes.
- Center: four short diagonal arrows pointing inward toward a small central dot,
  with transparent separation.
- Reset: a thick clockwise circular arrow with an upper-right gap and clear
  arrowhead, with no center symbol.
- Configure: a symmetric eight-tooth gear with a large transparent central hole.

The selected silhouettes were refined with this final shared edit prompt:

> Edit this UI glyph into a perfectly clean, flat solid CYAN icon, HEX #40BDF2,
> on a genuinely transparent alpha background. Preserve its simple silhouette
> and centered composition. Remove all the white material and stray specks from
> outside the intended shape. The CYAN silhouette must have uniform color,
> crisp smooth vector edges with no texture. No white, no other colors, no glow,
> no shadows, no border, no background tile or checkerboard. This is a tiny
> production 18-pixel glyph for the PopAuras dark UI, so clarity is essential.

The final prompts also required a completely empty, transparent anchor eye,
gaps between the center arrows and dot, space inside and outside the reset
arrow, and gear center, respectively.

# Editor UI glyphs

Generated procedurally (signed-distance shapes, 4x4 supersampled) as flat
white glyphs on transparent alpha, in the same 64x64 uncompressed 32-bit RGBA
TGA format. They are tinted in code with `SetVertexColor`.

- `UiEye.tga`: header Preview Animation toggle.
- `UiBug.tga`: header Debug Trigger toggle.
- `UiMore.tga`: the aura row actions (...) button.
- `UiGrip.tga`: six-dot drag grip shown on hovered or selected aura rows.
- `UiSearch.tga`: settings search box.
- `UiPill.tga` (64x32): rounded switch track and three-slice chip background.
- `UiKnob.tga` (32x32): round switch knob and slider thumb.
- `UiChevron.tga`: dropdown arrow.
- `UiRing.tga`: sidebar brand mark ring.
- `UiGroup.tga`: group glyph in the aura list.

## Aura-type glyphs (New Aura picker and create dialog)

Same format and grid: 64px canvas, drawing area 6-58, 4.5px outlines, 7px
solid strokes, round ends. Generated with signed-distance shapes.

- `UiTypeDynamic.tga`: Dynamic Group (stacked bars, growth arrow).
- `UiTypeGroup.tga`: Group (corner brackets around two squares).
- `UiTypeIcon.tga`: Icon Aura (frame with a cooldown sweep).
- `UiTypeBar.tga`: Bar Aura (bar with fill and spark).
- `UiTypeText.tga`: Text Aura (heavy T on a baseline).
- `UiTypeDeath.tga`: Death Alert (skull).
- `UiTypeInterrupt.tga`: Interrupt Tracker (bolt splitting a cast bar).
- `UiTypeAuraBars.tga`: Buffs and Debuffs (icon and bar rows).
- `UiTypeNameplate.tga`: Nameplate Buffs (icons above a nameplate).
