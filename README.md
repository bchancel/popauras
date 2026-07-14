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
- Eligible exact player-buff and enemy-target-debuff icons/bars use native
  `AuraSlot` presentation.
- Logical aura queries use `GetUnitAuraBySpellID` only for non-secret spells.
  Restricted results are represented as `availability = "unavailable"`, never
  as a missing aura.
- Secret display values remain opaque and are passed directly to Blizzard
  widgets. They are not compared, formatted, logged, or persisted.

Existing PopAuras saved variables, imports, groups, actions, conditions, load
rules, and editor panels are retained.

## Verify

Run the static API-boundary and packaging checks with:

```powershell
.\verify.ps1
```
