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
