local _, ns = ...

-- Canonical configured-spell to applied-aura relationships. This file is
-- intentionally data-only: cooldowns remain authoritative Blizzard API data,
-- while Util/Spells.lua remains the single public resolver for these records.
--
-- verifiedBuild refers to the Retail 12.1.0 game-data build used to confirm
-- the relationship. A deliberately loaded PTR test entry instead carries
-- status = "ptr-candidate" and candidateBuild; it must not be treated as
-- verified until its player-side aura is confirmed in-client.
ns.SpellAuraAliases = {
  -- Death Knight
  [49028] = {
    auraSpellIDs = { 81256 },
    name = "Dancing Rune Weapon",
    class = "DEATHKNIGHT",
    specs = { "BLOOD" },
    verifiedBuild = 68745,
    verification = "12.1 CDM active/tracked pair; self defensive aura",
  },
  [43265] = {
    auraSpellIDs = { 43265, 188290 },
    name = "Death and Decay",
    class = "DEATHKNIGHT",
    specs = { "BLOOD", "UNHOLY" },
    verifiedBuild = 68745,
    verification = "12.1 CDM tracked-bar link; player aura while inside the area",
  },
  [51052] = {
    auraSpellIDs = { 145629 },
    name = "Anti-Magic Zone",
    class = "DEATHKNIGHT",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; caster-inclusive ally-area aura",
  },
  [1263824] = {
    auraSpellIDs = { 1263861 },
    name = "Consumption",
    class = "DEATHKNIGHT",
    specs = { "BLOOD" },
    verifiedBuild = 68745,
    verification = "12.1 CDM tracked-buff link; self aura",
  },

  -- Demon Hunter
  [1241937] = {
    auraSpellIDs = { 1241937, 1266696 },
    name = "Soul Immolation",
    class = "DEMONHUNTER",
    specs = { "DEVOURER" },
    status = "ptr-candidate",
    candidateBuild = 68745,
    verification = "PTR correction candidate: retain the base self-aura ID alongside the 12.1 CDM tracked-buff link",
  },
  [191427] = {
    auraSpellIDs = { 162264 },
    name = "Metamorphosis",
    class = "DEMONHUNTER",
    specs = { "HAVOC" },
    verifiedBuild = 68745,
    verification = "12.1 CDM active/tracked link; self transformation aura",
  },
  [196718] = {
    auraSpellIDs = { 209426 },
    name = "Darkness",
    class = "DEMONHUNTER",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; caster-inclusive ally-area aura",
  },
  [203720] = {
    auraSpellIDs = { 203819 },
    name = "Demon Spikes",
    class = "DEMONHUNTER",
    specs = { "VENGEANCE" },
    verifiedBuild = 68745,
    verification = "Existing verified mapping; 12.1 CDM tracked-bar link",
  },
  [206803] = {
    auraSpellIDs = { 206804 },
    name = "Rain from Above",
    class = "DEMONHUNTER",
    specs = { "HAVOC" },
    verifiedBuild = 68745,
    verification = "12.1 PvP talent CDM link; self aura",
  },
  [258920] = {
    auraSpellIDs = { 258920, 427912, 427913, 427914, 427915 },
    name = "Immolation Aura",
    class = "DEMONHUNTER",
    specs = { "HAVOC", "VENGEANCE" },
    verifiedBuild = 68745,
    verification = "12.1 CDM base and variant self-aura links",
  },
  [198589] = {
    auraSpellIDs = { 212800 },
    name = "Blur",
    class = "DEMONHUNTER",
    specs = { "HAVOC", "DEVOURER" },
    verifiedBuild = 68745,
    verification = "12.1 spell-data link; Active Duration confirmed in-client on PTR",
  },

  -- Druid
  [8921] = {
    auraSpellIDs = { 164812 },
    name = "Moonfire",
    class = "DRUID",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "Existing verified cast-to-periodic-debuff mapping",
  },
  [155625] = {
    auraSpellIDs = { 164812 },
    name = "Moonfire (Cat Form)",
    class = "DRUID",
    specs = { "FERAL" },
    verifiedBuild = 68745,
    verification = "Existing verified cast-to-periodic-debuff mapping",
  },
  [1252871] = {
    auraSpellIDs = { 164812 },
    name = "Red Moon",
    class = "DRUID",
    specs = { "BALANCE" },
    verifiedBuild = 68745,
    verification = "Existing verified ability-to-Moonfire mapping",
  },
  [93402] = {
    auraSpellIDs = { 164815 },
    name = "Sunfire",
    class = "DRUID",
    specs = { "BALANCE" },
    verifiedBuild = 68745,
    verification = "Existing verified cast-to-periodic-debuff mapping",
  },
  [1822] = {
    auraSpellIDs = { 155722 },
    name = "Rake",
    class = "DRUID",
    specs = { "FERAL" },
    verifiedBuild = 68745,
    verification = "Existing verified cast-to-periodic-debuff mapping",
  },
  [77758] = {
    auraSpellIDs = { 192090 },
    name = "Thrash",
    class = "DRUID",
    specs = { "GUARDIAN" },
    verifiedBuild = 68745,
    verification = "Existing verified cast-to-stacking-debuff mapping",
  },
  [202345] = {
    auraSpellIDs = { 279709 },
    name = "Starlord",
    class = "DRUID",
    specs = { "BALANCE" },
    verifiedBuild = 68745,
    verification = "Existing verified talent-to-stacking-buff mapping",
  },
  [50334] = {
    auraSpellIDs = { 50334, 102558 },
    name = "Berserk",
    class = "DRUID",
    specs = { "GUARDIAN" },
    verifiedBuild = 68745,
    verification = "12.1 CDM base and Incarnation self-aura variants",
  },
  [33891] = {
    auraSpellIDs = { 117679 },
    name = "Incarnation: Tree of Life",
    class = "DRUID",
    specs = { "RESTORATION" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; self transformation aura",
  },
  [5215] = {
    auraSpellIDs = { 5215, 102547 },
    name = "Prowl",
    class = "DRUID",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 Feral CDM link; base retained for other specs",
  },
  [61336] = {
    auraSpellIDs = { 61336, 50322 },
    name = "Survival Instincts",
    class = "DRUID",
    specs = { "FERAL", "GUARDIAN" },
    verifiedBuild = 68745,
    verification = "12.1 Feral CDM link; Guardian base aura retained",
  },

  -- Evoker
  [395152] = {
    auraSpellIDs = { 395296 },
    name = "Ebon Might",
    class = "EVOKER",
    specs = { "AUGMENTATION" },
    verifiedBuild = 68745,
    verification = "Blizzard EbonMightSelfAuraSpellID and 12.1 CDM tracked pair",
  },
  [370537] = {
    auraSpellIDs = { 370537, 370562 },
    name = "Stasis",
    class = "EVOKER",
    specs = { "PRESERVATION" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; storing and ready self-aura phases",
  },
  [406732] = {
    auraSpellIDs = { 406732, 406789 },
    name = "Spatial Paradox",
    class = "EVOKER",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM group link; caster and healer receive the effect",
  },
  [374968] = {
    auraSpellIDs = { 375234 },
    name = "Time Spiral",
    class = "EVOKER",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM class-specific link; 375234 is the Evoker aura",
  },

  -- Hunter
  [186257] = {
    auraSpellIDs = { 186257, 186258 },
    name = "Aspect of the Cheetah",
    class = "HUNTER",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; initial and secondary movement phases",
  },

  -- Mage
  [342245] = {
    auraSpellIDs = { 342246 },
    name = "Alter Time",
    class = "MAGE",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM active/tracked pair; self aura",
  },
  [365350] = {
    auraSpellIDs = { 365362 },
    name = "Arcane Surge",
    class = "MAGE",
    specs = { "ARCANE" },
    verifiedBuild = 68745,
    verification = "12.1 CDM active/tracked-bar link; self aura",
  },
  [66] = {
    auraSpellIDs = { 66, 32612, 110960 },
    name = "Invisibility",
    class = "MAGE",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM normal and Greater Invisibility self-aura links",
  },

  -- Monk
  [115203] = {
    auraSpellIDs = { 115203, 120954 },
    name = "Fortifying Brew",
    class = "MONK",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "PTR confirms player aura 115203; 12.1 CDM-linked 120954 retained as a fallback source",
  },

  -- Paladin
  [190784] = {
    auraSpellIDs = {
      221883, 221885, 221886, 221887,
      254471, 254472, 254473, 254474,
      276111, 276112, 294133, 363608, 453804,
    },
    name = "Divine Steed",
    class = "PALADIN",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM mount/appearance-dependent self-aura links",
  },
  [31884] = {
    auraSpellIDs = { 31884, 454351 },
    name = "Avenging Wrath",
    class = "PALADIN",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 Retribution CDM link; Holy/Protection base aura retained",
  },

  -- Priest
  [121536] = {
    auraSpellIDs = { 121557 },
    name = "Angelic Feather",
    class = "PRIEST",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM tracked-buff link; movement aura on feather pickup",
  },
  [356085] = {
    auraSpellIDs = { 355897, 355898 },
    name = "Inner Light and Shadow",
    class = "PRIEST",
    specs = { "DISCIPLINE" },
    verifiedBuild = 68745,
    verification = "12.1 CDM links both selectable self auras",
  },
  [64843] = {
    auraSpellIDs = { 64843, 64844 },
    name = "Divine Hymn",
    class = "PRIEST",
    specs = { "HOLY" },
    verifiedBuild = 68745,
    verification = "12.1 CDM group link; channel and caster-inclusive buff phases",
  },
  [62618] = {
    auraSpellIDs = { 81782 },
    name = "Power Word: Barrier",
    class = "PRIEST",
    specs = { "DISCIPLINE" },
    verifiedBuild = 68745,
    verification = "12.1 SpellEffect ally-area damage-reduction aura",
  },
  [228260] = {
    auraSpellIDs = { 228264 },
    name = "Voidform",
    class = "PRIEST",
    specs = { "SHADOW" },
    verifiedBuild = 68745,
    verification = "12.1 CDM active/tracked-bar pair; self transformation aura",
  },

  -- Rogue
  [1214909] = {
    auraSpellIDs = { 1214909, 1214933, 1214934, 1214935, 1214937 },
    name = "Roll the Bones",
    class = "ROGUE",
    specs = { "OUTLAW" },
    verifiedBuild = 68745,
    verification = "12.1 CDM tracked-bar links all four self-buff outcomes",
  },
  [185313] = {
    auraSpellIDs = { 185313, 185422 },
    name = "Shadow Dance",
    class = "ROGUE",
    specs = { "SUBTLETY" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; configured and linked self-aura phases",
  },
  [57934] = {
    auraSpellIDs = { 57934, 59628 },
    name = "Tricks of the Trade",
    class = "ROGUE",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM caster-side threat-transfer aura link",
  },

  -- Shaman
  [114050] = {
    auraSpellIDs = { 1219480 },
    name = "Ascendance",
    class = "SHAMAN",
    specs = { "ELEMENTAL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; Elemental self transformation aura",
  },
  [384352] = {
    auraSpellIDs = { 466772 },
    name = "Doom Winds",
    class = "SHAMAN",
    specs = { "ENHANCEMENT" },
    verifiedBuild = 68745,
    verification = "12.1 CDM active/tracked link; self offensive aura",
  },
  [192077] = {
    auraSpellIDs = { 192082 },
    name = "Wind Rush Totem",
    class = "SHAMAN",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM utility/tracked pair; caster-inclusive movement aura",
  },
  [98008] = {
    auraSpellIDs = { 325174 },
    name = "Spirit Link Totem",
    class = "SHAMAN",
    specs = { "RESTORATION" },
    verifiedBuild = 68745,
    verification = "12.1 CDM group link; player aura while inside the area",
  },

  -- Warlock
  [442726] = {
    auraSpellIDs = { 442726, 430014 },
    name = "Malevolence",
    class = "WARLOCK",
    specs = { "AFFLICTION", "DESTRUCTION" },
    verifiedBuild = 68745,
    verification = "12.1 Destruction CDM link; Affliction base self aura retained",
  },

  -- Warrior
  [97462] = {
    auraSpellIDs = { 97463 },
    name = "Rallying Cry",
    class = "WARRIOR",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM link; caster-inclusive group health aura",
  },
  [2565] = {
    auraSpellIDs = { 132404 },
    name = "Shield Block",
    class = "WARRIOR",
    specs = { "PROTECTION" },
    verifiedBuild = 68745,
    verification = "12.1 CDM tracked-bar link; self defensive aura",
  },
  [23920] = {
    auraSpellIDs = { 23920, 385391 },
    name = "Spell Reflection",
    class = "WARRIOR",
    specs = { "ALL" },
    verifiedBuild = 68745,
    verification = "12.1 CDM tracked pair; reflection and magic-reduction self auras",
  },
}
