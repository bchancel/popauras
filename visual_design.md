# Visual Design

A brief reference for the PopAuras editor look and feel, written so other
applications can reproduce it. The style follows EllesmereUI's configuration
window: calm dark neutrals, one accent colour, flat forms on alternating bands,
and quiet controls that only show their extra affordances on hover.

## Principles

- **One accent.** A single teal marks "on", "selected" and "focus". Everything
  else is neutral. Never add a second accent hue for decoration or per-category
  colour coding.
- **Flat over boxed.** Settings sit on continuous row bands, not nested cards.
  Use a border only when it explains a real object (a text field, a preview, a
  popup).
- **Quiet until needed.** Secondary actions (row menus, drag grips) appear on
  hover or for the selected item. Advanced settings live behind a gear popover.
- **Dense but legible.** Two settings per row, short labels on the left, the
  control on the right. Explanations are one-line subtitles under the setting
  they describe, not paragraphs under a section.
- **Show the result.** A live preview of the thing being edited sits in the
  header and updates as settings change.

## Colour tokens

Dark-only. Neutrals carry a slight blue-green bias toward the accent.

| Token | Hex | Use |
|---|---|---|
| canvas | `#0D1116` | Main window and editor background |
| canvasAlt | `#0A0E11` | Sidebar, popups, preview stage |
| rowOdd / rowEven | `#0F1419` / `#13191E` | Alternating setting bands |
| surface / surfaceHover | `#11171C` / `#1B242A` | Idle and hovered interactive surfaces |
| control | `#131C22` | Inputs and dropdowns |
| border / borderStrong | `#262F36` / `#344047` | Hairlines, dividers, outlines |
| accent | `#0CD29D` | On state, selection bar, tab underline, slider fill |
| accentBright | `#54EDC2` | Accent text and hover on accent elements |
| accentSoft | `#073328` | Selected row or chip fill |
| text | `#F2F5F7` | Primary text |
| textSecondary | `#C2C9CF` | Labels and secondary text |
| textMuted | `#858F96` | Hints, subtitles, placeholders |
| sectionTitle | `#8F99A1` | Uppercase section headings |
| danger | `#E0585E` | Destructive actions only |
| switchTrackOff / knobOff | `#2E373D` / `#9EA6AB` | Off state of switches |

## Typography

- One condensed UI face. Expressway when available, otherwise Arial Narrow (on
  the web, Barlow Semi Condensed for headings and Inter for body is a close
  match).
- Scale: window title 22–24, section title 12–13 uppercase, control 13,
  small control 12, caption 11, micro 9.
- Section titles are uppercase, muted, and followed by a hairline that runs to
  the edge.

## Layout

- **Sidebar** (fixed width): brand mark (accent ring with a short monogram),
  filter box, the item list, and one compact row of global actions at the
  bottom with the status and version line below it.
- **Header**: title, one-line subtitle, a soft accent gradient fading from the
  top-left, small icon tools at the top right (with tooltips), and the live
  preview box on the right.
- **Tabs**: plain text labels on the header's bottom edge; the active tab gets a
  2px accent underline. A settings search box sits at the right end of the tab
  row.
- **Content**: sections stack from their real heights. Each row is one band
  holding two settings with a 1px divider between them.

## Components

- **Pill switch**: 38×20 rounded track, 14px round knob. On: accent track,
  white knob. Off: dark track, grey knob. Slides in about 90ms. Dims to 40%
  when disabled.
- **Chip**: pill-shaped multi-select option (24px tall). Selected: accent
  outline, soft accent fill, accent text. Idle: neutral outline. Chips wrap in
  a flowing row.
- **Slider**: 4px track, accent fill, round white thumb, with a small numeric
  box beside it.
- **Dropdown and input**: flat `control` fill, 1px border that turns accent on
  hover or focus, chevron glyph for dropdowns.
- **Icon button**: 30×30 square, monochrome glyph. Toggles turn accent when
  active. Ghost variant has no fill until hovered.
- **Gear popover**: opens beside its row with that setting's advanced options on
  its own small bands; closes on outside click or Escape.
- **List rows**: flat, with an icon, a name and a one-line kind label.
  - Hover adds a soft wash.
  - Selected rows get a soft accent fill and a 3px accent bar on the left.
  - Unavailable or unloaded items dim and desaturate instead of changing colour.
  - A six-dot grip (on hover or selection) signals drag-to-reorder.
  - A single ⋯ button, or a right-click, opens a labelled action menu, with
    destructive items last and in danger red.
- **Scrollbars**: hairline track, slim muted thumb, no step arrows.
- **Type picker**: choices grouped under quiet category titles, shown as flat
  tiles three to a row on alternating bands. Each tile has a glyph in a small
  raised box, a left-aligned title and a two-line description. Hover adds a
  wash, a 2px accent bar and an accent glyph. The selected tile gets the soft
  accent fill. A filter box in the header narrows the list.
- **Create dialog**: the chosen type's glyph in an accent box, an uppercase
  category label above the type name, a one-line description, then a labelled
  name field with focus. Escape cancels, Enter creates.
- **Search results**: a small popup list. Each result shows a muted breadcrumb
  ("Display · Icon") above the setting name. Choosing one scrolls to the setting
  and briefly flashes its band.

## Iconography

Monochrome white glyphs on transparency, tinted in code (neutral at rest,
accent when active). Bold, simple geometry on a shared grid with generous
padding, designed to read at 12–18px. No multicolour illustrations.

Type glyphs share one grid: 64px canvas, drawing area 6–58, 4.5px outlines,
7px solid strokes, round ends and 2–4px corner radius. Each depicts the thing
it creates (stacked bars with a growth arrow, an icon frame with a cooldown
sweep, a bar with a spark, a heavy "T", a skull, a bolt splitting a cast bar).

## In PopAuras

The tokens live in `Util/Theme.lua` (`Theme.colors`, `Theme.typography`,
switch and scrollbar styling). Builders for chips, pills, icon buttons and
popovers are in `Options/EditorDesign.lua`, and the glyph textures are in
`Options/Media/Icons/` (see its README).
