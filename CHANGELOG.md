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
