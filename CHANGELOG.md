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
