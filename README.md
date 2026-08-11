# PopAuras 12.1

PopAuras is a saved-variable-compatible aura addon for WoW Retail 12.1.

## Runtime design

- Spell cooldown decisions use Blizzard's non-secret `isActive`, `isEnabled`,
  `isOnGCD`, and `maxCharges` fields.
- Cooldown and charge visuals use `DurationObject` instances. Scalar cooldown
  setters are only used for validated, non-secret legacy values.
- Cooldown Manager IDs are catalog metadata only and are never treated as
  spell IDs or timing records.
- Aura lists are rendered by Blizzard `AuraContainer`/`AuraButton` objects.
- Hostile-NPC nameplate buffs use load-filtered native category groups with
  no aura scans. The implementation remains behind the
  `feature_nameplate_buffs` source flag for PTR testing.
- Eligible exact player-buff and enemy-target-debuff icons/bars use native
  `AuraSlot` presentation.
- Logical aura queries use `GetUnitAuraBySpellID` only for non-secret spells.
  Restricted results are represented as `availability = "unavailable"`, never
  as a missing aura.
- Secret display values remain opaque and are passed directly to Blizzard
  widgets. They are not compared, formatted, logged, or persisted.
- Player spell-cast event triggers can activate normal PopAuras regions and
  actions after a configured spell successfully casts.
- Provider events and optional runtime managers activate from the enabled saved
  configuration instead of paying every feature's cost at login.
- The full editor ships in the same release as the load-on-demand
  `PopAuras_Options` companion and is loaded by `/pa` only when needed.
- Every bar renderer shares one texture catalogue. The editor includes a
  searchable visual picker for PopAuras and installed media textures without
  redistributing third-party artwork.
- The options companion uses one compact editor design system for typography,
  controls, navigation, section rows, and scrollbars across every panel.
- Verified configured-spell to applied-aura identities live in the data-only
  `Data/SpellAuraAliases.lua` catalogue and resolve only through
  `Util/Spells.lua`; explicitly marked PTR candidates may be loaded for a
  controlled in-client test without being represented as verified.

Existing PopAuras saved variables, imports, groups, actions, conditions, load
rules, and editor panels are retained.

## Verify

Run the static API-boundary and packaging checks with:

```powershell
.\verify.ps1
```
