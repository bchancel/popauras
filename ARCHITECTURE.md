# Architecture boundaries

## Semantic state

Only non-secret values may influence logic. `Data/Schema.lua` normalizes every
provider result into explicit `timer`, `count`, and `availability` records.

## Presentation state

Duration objects and Blizzard display strings are opaque presentation values.
They may be handed to compatible widgets but must not be converted or used for
control flow.

## Aura restrictions

Blizzard owns restricted aura presence, ordering, duration, count, tooltips,
and cancellation through AuraContainer objects. PopAuras styles the child
widgets during `initializeFrame` but never inspects button visibility or aura
records.

Exact spell-ID slots are used only where Blizzard permits that filter:
helpful auras on assistable units and harmful auras on non-assistable units.
Unsupported restricted logical configurations remain unavailable rather than
guessing.

### Hostile nameplate buff groups

Creation and runtime activation require
`ns.Features.feature_nameplate_buffs` in `Core/Constants.lua`. The switch is
currently enabled for PTR testing so it can be disabled without discarding
saved nameplate configurations.

Nameplate buff displays use one Blizzard `AuraGroup` per active PopAuras
display and visible hostile NPC nameplate. PopAuras listens only for the public
nameplate added/removed lifecycle; the native container receives `UNIT_AURA`
and owns matching, ordering, icon, count, duration, and visibility.

The native container is created under `UIParent` and anchored to the public
nameplate frame. It must not be parented to the nameplate itself: protected or
forbidden nameplate ownership can taint the template's secure `OnUpdate`
handler during creation.

These displays accept only Blizzard's non-identity category filters, such as
stealable, Magic dispel type, boss/role/priority classification, and nameplate
metadata flags. Categories within one display are AND. Separate displays are
the supported way to express OR, with the understood possibility that an aura
matching both displays appears twice. `All Buffs` omits category filters and an
empty category selection fails closed.

Exact spell IDs are not supported for hostile helpful auras. Blizzard skips
identity filters for that relationship, including an empty spell-ID allowlist,
so secure shutdown uses an empty dispel-type allowlist before disabling the
container. Native buttons are styled only in the group's initialization
callback and are never inspected or restyled after assignment.

## Spell cooldown to applied-aura mappings

A spell's cast/spellbook ID often differs from the helpful aura ID it applies
to the player. This matters for Spell Cooldown bars that use **Glow When
Active**, especially the **Active Duration** style: the configured cooldown
must be associated with its applied player aura before PopAuras can determine
that the effect is active.

### Canonical mapping and consumers

- The canonical cast-to-aura catalogue lives in the data-only
  `Data/SpellAuraAliases.lua` file and is loaded immediately before
  `Util/Spells.lua`. The configured spell remains the user-facing identity;
  `GetAuraSpellIDs` is the single resolver that expands it to the possible
  applied-aura IDs.
- Native Aura candidate filters, CDM matching/hiding, and active-buff
  presentation must all use this same expansion. Do not add a one-off lookup
  in a renderer or provider.
- Catalogue entries contain only identity and maintenance metadata. Cooldowns
  remain authoritative Blizzard API data because talents, charges, and
  hotfixes can change them independently of spell-to-aura identity.

### Active Duration lookup order

1. Resolve the configured cooldown spell through `GetAuraSpellIDs`.
2. Prefer an exact player-aura ID lookup. If it yields a usable Blizzard
   duration object, send that object directly to the timer/cooldown widget.
   It is presentation data only: never inspect, compare, format, cache, or
   persist secret duration fields.
3. For Active Duration cooldown bars, create an exact helpful-player slot in
   Blizzard's `CustomAuraContainer`. Its private AuraButton drives the overlay
   status bar and timer directly, so the active aura replaces the cooldown even
   when no CDM item frame has been instantiated. The addon must configure and
   style those widgets only during the slot initialization callback; it must
   never inspect the resulting restricted button or infer visibility from it.
4. If that native slot is unavailable and the aura's raw duration is restricted
   (normally in combat), find the linked CDM tracked-buff icon or bar source. Use only its public
   `IsActive()` state for logic. If its public aura-instance ID is non-secret,
   request Blizzard's real aura `DurationObject` and pass that opaque object
   directly to the PopAuras widgets. Otherwise, a tracked-buff bar may mirror
   its `SetMinMaxValues`/`SetValue` calls and visible duration text. Do not read
   or retain numeric/secret timing values from either source. Because Blizzard
   may acquire a tracked-buff frame after the cast event, an empty cached frame
   lookup receives one forced late-binding lookup and a bounded post-cast
   retry. Do not require the raw aura-presence result before asking that exact
   CDM source: combat can make the former unavailable while the source's public
   `IsActive()` remains authoritative.
5. If neither authoritative source is available, retain normal cooldown
   presentation. Do not infer that a buff is present from a spell name,
   cooldown state, or a unit-wide aura scan.

The current implementation is split between
`Triggers/SpellCooldownProvider.lua` (identity, active state, safe duration
source selection) and `Renderers/BarRegion.lua` (direct duration-object use
or CDM source-bar mirroring). This separation is deliberate: semantic state
must stay non-secret, while duration display stays on the rendering path.

### Mapping admission checklist

Normally add an alias only after verifying the actual applied player aura ID
on the 12.1 client. Useful evidence includes PTR `/fstack` / CDM inspection,
spell-data references, or a controlled in-game test. Record the configured
cast ID, applied player aura ID(s), class/spec, and the patch/source used for
verification. A deliberately loaded test exception must be marked
`status = "ptr-candidate"` with its candidate build and must not be described
as verified. Test each mapping out of combat and in combat, confirming that
Active Duration is yellow while the buff is active and returns to the spell
cooldown afterward.

Do not map target-only or ambiguous effects until their player-side aura
identity is confirmed. For example, Demon Spikes (`203720` to `203819`) and
Blur (`198589` to `212800`) are verified mappings. Soul Immolation currently
retains both `1241937` and CDM-linked `1266696` as an explicitly marked PTR
candidate. Touch of Karma has multiple related spell IDs and needs player-side
verification before mapping.

For future all-spec passes, enumerate each class/spec's on-use spell cooldowns,
keep only those that apply a helpful effect to the player, then verify and add
the resulting alias through the canonical catalogue. Uncertain candidates stay
out of the loaded data file until verified unless a specific candidate is
explicitly approved for PTR testing and marked as provisional. This avoids
broad aura scans and preserves the Midnight secret-value boundary.
