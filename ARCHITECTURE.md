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
