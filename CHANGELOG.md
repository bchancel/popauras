# v12.1.6
- Added architecture and performance counters to `/pa perf report`
- Split the configuration editor into the bundled, load-on-demand `PopAuras_Options` addon
- Reduced startup and idle overhead by loading only the components and events required by enabled auras
- Added a searchable visual bar texture picker with built-in and installed media textures

# v12.1.5
- Simplified UI Options
- Removed unsupported nameplate buff filtering options
- Instance and Encounter Information available on the Load Tab

# v12.1.4
- Expanded support for third-party unit and raid frames

# v12.1.3
- Reskinned the configuration UI for a cleaner, more fluid experience
- Added resizable windows and standardized scrollable panels
- Added the Nameplate Aura type
- Improved aura grouping, organization, and navigation
- Improved Player and Target buff/debuff tracking
- Streamlined Import and Export workflows

# v12.1.1
- Added a player-only successful spell-cast event trigger for instant abilities such as Darkness
- Changed Glow When Active on Spell Cooldown bars into selectable None, Inner Glow, Outer Glow, and Active Duration effects; Active Duration uses a bright yellow buff timer before returning to the cooldown
- Added the verified Retail 12.1 all-spec cooldown-to-player-aura catalogue in a maintainable data-only file while retaining one canonical resolver
- Fixed Active Duration in combat by accepting CDM tracked-buff icon sources and passing their opaque Blizzard aura `DurationObject` directly to presentation widgets
- Added late CDM frame acquisition retries and secret-safe Active Duration diagnostics for combat-only failures
- Added an exact Blizzard AuraContainer overlay for Active Duration bars, covering abilities such as Soul Immolation that have no instantiated CDM frame

# v12.1.0
- Re-write for retail version 12.1.0 utilizing new AuraButton styling
- Adjusting version number to keep in pace with wow retail version it was designed for
- Added a CDM-backed Trinket Cooldown trigger with independent top/bottom slot entries, active-effect glow, and item name/ID ignores for transforming trinkets
- Reduced combat aura and item-cooldown refresh fan-out while retaining native Blizzard aura rendering
- Fixed native bar/icon previews so duration, stacks, visibility, and ancestor group layout update and animate correctly
- Made export copying restriction-safe, added confirmed green imports with chat feedback, and added descendant-aware deletion confirmations
- Added an optional No Stacks Bar Color for Spell Cooldown bars when no usable charges remain
- Canonicalized known cast-to-aura mappings so Blizzard's exact native filters receive applied aura IDs rather than mixed cast and aura IDs
- Rebuild native target aura state on target identity and death/flags transitions without reintroducing broad UNIT_AURA scans

# v0.4.6
- Reworked CDM-backed spell cooldown handling to prefer authoritative CDM / Blizzard active-state signals, improving reset, refund, and secret-safe timing reliability
- Fixed CDM frame rebind / cache invalidation issues that could leave cooldown bars stale or trigger recursive overflow errors on login
- Added an explicit spell cooldown option to show a CDM aura/proc window only when no real cooldown is active
- Improved the cooldown debug window so it can be moved independently, minimized during combat, and uses a smaller default and minimized footprint
- Interrupt tracker click announces now prepare the chat line instead of calling protected chat-send APIs directly, avoiding `ADDON_ACTION_BLOCKED` errors

# v0.4.5
- Death Alert now listens for `UNIT_DIED` instead of `UNIT_HEALTH`, reducing noisy health-event refreshes while still using `UNIT_FLAGS` for follow-up state cleanup
- Fixed a Death Alert secret-GUID / Midnight taint error when handling death events

# v0.4.4
- Improved talent loadout selector to support multiple selected layouts across specs and characters

# v0.4.3
- Fixed issue with hidden controller auras and Blizzard spell alert suppression setup
- Added ability to load based on saved talent loadout
- Added ability to suppress Blizzard spell alerts

# v0.4.2
- Improved spell cooldowns when CDM fails to give stack data

# v0.4.1
- Player buff icons and aura list rows can now right-click to cancel buffs
- Improved aura and unit handling for secret-value / Blizzard AuraUtil edge cases

# v0.3.11
- Fixed CDM-backed spell cooldown bars getting stuck on stale timers when Cooldown Manager already showed the spell as ready
- Reduced spell cooldown overhead during `SPELL_UPDATE_COOLDOWN` and `SPELL_UPDATE_CHARGES` 

# v0.3.10
- Trigger Type switching in the Trigger tab no longer gets stuck behind stale options when cycling between trigger types
- Added a "Cast By Me" filter for aura triggers so you can track your own buffs on target, party/raid, and nameplate units

# v0.3.9
- Fixed exported/imported icon auras sometimes restoring at the generic 220 width instead of icon size
- Shared aura imports now apply automatically after accepting the transfer
- Import/Export tab no longer shows the "Import Replace" button
- Improved unit frame glow support for Blizzard frames and custom frame addons
- Added debug logging for Glow Unit Frame actions when trigger debug is enabled
- Chat glow alerts can now handle multiple matching senders at the same time and glow all matched units
- Added lightweight unit frame lookup caching to reduce repeated glow scan cost

# v0.3.8
- Main `/pa` configuration window now recenters when reopened
- Removed the config window drag clamp so it can be moved off-screen freely
- Fixed icon auras showing on screen when "Show Aura Icon" is off but unit frame glow is enabled
- Chat triggers can now watch multiple channels at once
- Chat trigger channel groups now treat Party/Party Leader, Raid/Raid Leader/Raid Warning, and Instance/Instance Leader as shared selections
- Simplified chat trigger channel options by removing duplicate leader-only checkboxes
- Reworked chat trigger layout to fit cleanly in the Trigger panel
- Added an "Exact Match" option for chat trigger text matching

# v0.3.7
- Version bump

# v0.3.6
- Aura and item triggers can now accept item names instead of requiring item IDs
- Load conditions can resolve "Only load if item equipped" by item name
- Copied auras are less likely to stay hidden from stale class/spec/talent load filters
- Raid frame auras got a dedicated display section with icon size, anchor, offset, glow, duration, and stack options
- Reduced raid frame aura overhead by narrowing aura refreshes and reusing raid frame icon widgets
- Ready item/spell cooldown icons no longer show `0.0` while off cooldown
- Aura timing now prefers the live aura timer over CDM timing when both exist
- Updated interrupt tracker compatibility for current Retail interrupt data and talent-based cooldown adjustments
- Aura list rows in the config window now show green outlines for preview-enabled auras and red outlines for debug-enabled auras

# v0.3.4
- Show aura icons on raid frames for group/party triggers ("Show on Raid Frames" option)
- Icon auras can hide the center-screen icon while still showing on raid frames
- `/pa version` command -- shows local version solo, scans group versions in party/raid
- Hide "Match Bar Size" option for icon auras
- Fix raid frame overlay icon rendering

# v0.3.3
- Text Aura and Death Alert get distinct tile art in New Aura panel
- Bar Aura art no longer extends outside its tile box
- Consolidated class, spec, and talent filters under a single collapsible Class Filter section
- Fixed overlap between Manual Cooldown and Always Show in Spell Cooldown trigger
- Fixed Text Aura appending "dead" to output

# v0.3.1
- Cleanup configuration frames
- Add Actions tab for glowing unit frames
- Cleanup overlap on display tab
- Fix issue that would cause a spell cooldown ready in a multi-trigger aura to not display

# v0.3.0
- Initial experimental release
# v12.1.0

- Restores migrated Demon Spikes aura bars by expanding the spellbook ability
  ID (`203720`) to the active buff ID (`203819`) for both logical queries and
  Blizzard native aura-container filters.
- Adds a centralized explicit aura-alias path for abilities whose applied aura
  uses a different spell ID, without broad unit-aura scanning.
- Aligns the public PopAuras version with the supported Retail client version.
- Restricts combat `UNIT_AURA` refreshes to the affected unit instead of
  reevaluating every configured aura when aura values are secret.
- Avoids resetting unchanged native aura filters, which previously forced
  Blizzard to clear and rebuild candidate sets on every aura event.
- Keeps multi-ID ready-state labels tied to the configured primary spell ID.
- Lets native aura containers handle their own `UNIT_AURA` updates unless an
  aura has actions, conditions, sounds, debugging, or raid-frame consumers.
- Caches the item-cooldown aura index so frequent bag cooldown events do not
  repeatedly scan the complete saved-aura registry.
- Restores CDM hiding through linked spell relationships only when the mapping
  resolves to one unambiguous cooldown entry.
- Maps the PTR Moonfire and Sunfire cast IDs to their combat-log-confirmed
  periodic debuff IDs for native target-aura filtering.

# 1.0.6-rewrite

- Prevents a WoW client assertion crash caused by requesting every child of
  `UIParent` while resolving party or raid unit frames.
- Resolves Blizzard party and compact raid frames through their owned frame
  pools and traversal callbacks, with bounded adapters for supported third-party
  unit-frame addons.

# 1.0.5-rewrite

- Prevents CDM hide hooks from following Blizzard-recycled frames onto nearby
  cooldown icons.
- Restricts CDM hiding to direct spell and override mappings rather than every
  semantically linked cooldown entry.

# 1.0.4-rewrite

- Prevents unloaded groups from treating always-shown native aura host frames
  as visible children and drawing stale group backgrounds.
- Adds PopAuras parent keys to runtime regions and native aura containers for
  clear `/fstack` identification.

# 1.0.3-rewrite

- Sorts aura bar lists strictly by expiration, with permanent and long-running
  auras visually above the next buffs or debuffs to expire.

# 1.0.2-rewrite

- Parents native aura text to the high-level presentation overlay so duration,
  name, and stack text remain visible above the duration bar fill.

# 1.0.1-rewrite

- Adds a visible build marker to the `/pa` header for PTR verification.
- Hides Blizzard's duplicate native cooldown countdown on aura bars and gives
  horizontal aura names an explicit text box beside the PopAuras timer.

# 1.0.0-rewrite

- Targets Retail interface 12.1.0 (`120100`).
- Replaces broad aura scanning and combat-log inference with Blizzard native
  AuraContainer/AuraButton presentation and non-secret spell-ID queries.
- Replaces cooldown frame interception and GCD-duration heuristics with
  structured cooldown state, charge state, and DurationObject rendering.
- Adds explicit unavailable state for restricted logical aura data.
- Splits Cooldown Manager handling into catalog metadata and visual ownership.
- Adds standalone deploy and verification scripts.
