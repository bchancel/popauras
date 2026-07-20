$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$toc = Join-Path $root "PopAuras.toc"
if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) {
    throw "Missing PopAuras.toc"
}

$missing = @()
Get-Content -LiteralPath $toc | ForEach-Object {
    $entry = $_.Trim()
    if ($entry -match '\.lua$' -and -not (Test-Path -LiteralPath (Join-Path $root $entry) -PathType Leaf)) {
        $missing += $entry
    }
}
if ($missing.Count -gt 0) {
    throw "TOC references missing files: $($missing -join ', ')"
}

$tocText = Get-Content -LiteralPath $toc -Raw
if ($tocText -notmatch '(?m)^## Interface:\s*120100\s*$') {
    throw "PopAuras.toc is not targeting PTR interface 120100"
}
if ($tocText -notmatch '(?m)^## Version:\s*12\.1\.1\s*$') {
    throw "PopAuras.toc version is not aligned to release 12.1.1"
}

$forbiddenPatterns = @(
    'ActionButton_ApplyCooldown',
    'GetAuraDataByIndex',
    'GetAuraDataByAuraInstanceID',
    'GetAuraDataBySlot',
    'GetBuffDataByIndex',
    'GetDebuffDataByIndex',
    'CombatLogGetCurrentEventInfo'
)
$runtimeFiles = Get-ChildItem -LiteralPath $root -Recurse -Filter *.lua
foreach ($pattern in $forbiddenPatterns) {
    $match = $runtimeFiles | Select-String -Pattern $pattern | Select-Object -First 1
    if ($match) {
        throw "Forbidden restricted-aura/cooldown path '$pattern' found at $($match.Path):$($match.LineNumber)"
    }
}

$eventsText = Get-Content -LiteralPath (Join-Path $root "Core\Events.lua") -Raw
if ($eventsText -notmatch 'pcall\(frame\.RegisterEvent') {
    throw "Core/Events.lua does not protect patch-specific event registration"
}
if ($eventsText -notmatch 'ACTIVE_PLAYER_SPECIALIZATION_CHANGED' -or $eventsText -notmatch 'ACTIVE_TALENT_GROUP_CHANGED') {
    throw "Core/Events.lua does not refresh load state after active specialization changes"
}

$safeValuesText = Get-Content -LiteralPath (Join-Path $root "Core\SafeValues.lua") -Raw
if ($safeValuesText -match 'type\(value\)\s*==\s*"boolean"\s+and\s+value\s+or\s+nil') {
    throw "SafeValues.Boolean discards legitimate false values"
}
if ($safeValuesText -notmatch 'if\s+type\(value\)\s*==\s*"boolean"\s+then\s+return\s+value') {
    throw "SafeValues.Boolean does not preserve false values explicitly"
}

$spellCooldownText = Get-Content -LiteralPath (Join-Path $root "Triggers\SpellCooldownProvider.lua") -Raw
if ($spellCooldownText -notmatch 'UPDATE_OVERRIDE_ACTIONBAR' -or $spellCooldownText -notmatch 'SPELLS_CHANGED') {
    throw "Spell cooldown provider does not cover action-bar and spellbook override changes"
}
if ($spellCooldownText -notmatch 'local outOfCharges\s*=\s*chargeStateKnown and chargeActive and cooldownActive' -or
    $spellCooldownText -notmatch 'local timerActive\s*=\s*useCharge or useSpell' -or
    $spellCooldownText -notmatch 'progressType\s*=\s*candidate\.timerActive' -or
    $spellCooldownText -match 'local active\s*=\s*useCharge or cooldownActive') {
    throw "Spell charge matching is not separated from partial-recharge timer presentation"
}
if ($spellCooldownText -notmatch 'onCooldown\s*=\s*outOfCharges or \(partiallyCharged and showCharge\)' -or
    $spellCooldownText -notmatch 'AliasCandidateScore[\s\S]*candidate\.chargeStateKnown') {
    throw "Spell charge cooldown behavior no longer preserves ready-with-charge and zero-charge semantics"
}
if ($spellCooldownText -notmatch 'FindAuraStateSource') {
    throw "Spell cooldown combat state does not use CDM tracked-buff icon sources"
}
if ($spellCooldownText -notmatch 'C_Timer\.After\(0\.1' -or
    $spellCooldownText -notmatch 'activeDurationDebug') {
    throw "Spell cooldown combat sources do not retry late CDM frame acquisition with safe diagnostics"
}
$barRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\BarRegion.lua") -Raw
if ($barRegionText -match 'local activeDurationRequested\s*=[\s\S]{0,200}state\.activeBuff\s*==\s*true' -or
    $barRegionText -notmatch 'sourceActive\s*==\s*true') {
    throw "Active Duration still gates combat presentation on restricted raw aura presence"
}
$activeDurationNativeText = Get-Content -LiteralPath (Join-Path $root "Renderers\ActiveDurationNative.lua") -Raw
if ($activeDurationNativeText -notmatch 'CustomAuraContainer|ActiveDurationAuraContainer' -or
    $activeDurationNativeText -notmatch 'SetDurationBar' -or
    $activeDurationNativeText -notmatch 'SetDurationText' -or
    $activeDurationNativeText -notmatch 'SetAuraSlotCandidateFilters') {
    throw "Active Duration native fallback is not securely owned by an exact Blizzard aura slot"
}
$nativeAurasTextForProbe = Get-Content -LiteralPath (Join-Path $root "Core\NativeAuras.lua") -Raw
if ($nativeAurasTextForProbe -notmatch 'self\.probe[\s\S]{0,300}frame:Show\(\)') {
    throw "The retained native AuraContainer capability probe is not restored before slot assignment"
}
if ($runtimeFiles | Select-String -Pattern 'SPELL_OVERRIDE_UPDATED' | Select-Object -First 1) {
    throw "Removed 12.1 event SPELL_OVERRIDE_UPDATED is still registered"
}

$nativeAurasText = Get-Content -LiteralPath (Join-Path $root "Core\NativeAuras.lua") -Raw
if ($nativeAurasText -match 'CustomAuraContainerTemplate\s*~=\s*nil') {
    throw "Native aura availability must not treat an XML template name as a Lua global"
}
if ($nativeAurasText -notmatch 'pcall\(\s*CreateFrame,\s*"AuraContainer"') {
    throw "Native aura availability does not probe the Blizzard AuraContainer object"
}

$loadEvaluatorText = Get-Content -LiteralPath (Join-Path $root "Engine\LoadEvaluator.lua") -Raw
if ($loadEvaluatorText -notmatch 'MatchesWithAncestors') {
    throw "Load evaluation does not inherit disabled or unloaded ancestor state"
}

$nativeAuraRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\NativeAuraRegion.lua") -Raw
if ($nativeAuraRegionText -notmatch 'GetAuraSpellIDs') {
    throw "Native aura filters do not expand ability IDs to their applied aura IDs"
}
if ($nativeAuraRegionText -notmatch 'local function GetPrimarySpellID\(trigger\)[\s\S]*?trigger and trigger\.spellId') {
    throw "Native aura fallback labels do not prefer the configured primary spell ID"
}
if ($nativeAuraRegionText -notmatch 'state\.loadMatched ~= false') {
    throw "Native aura rendering is not gated by effective load state"
}
if ($nativeAuraRegionText -notmatch 'SetExplicitBounds\(button\.bar') {
    throw "Native aura duration bars do not use explicit non-secret bounds"
}
if ($nativeAuraRegionText -notmatch 'SetExplicitBounds\(button\.presentation') {
    throw "Native aura text does not use an explicitly bounded presentation overlay"
}
if ($nativeAuraRegionText -notmatch 'initializeFrame\s*=\s*function\(button\) self:InitializeButton\(button\) end' -or
    $nativeAuraRegionText -match 'function Region:Update\(aura, state\)[\s\S]*?self:StyleButton\(aura\)[\s\S]*?function Region:OnTimerUpdate') {
    throw "Native AuraButtons are styled outside their safe initialization callback"
}
if ($nativeAuraRegionText -notmatch 'SetHideCountdownNumbers\(true\)') {
    throw "Native aura cooldown still exposes Blizzard's duplicate countdown numbers"
}
if ($nativeAuraRegionText -notmatch 'presentation:CreateFontString') {
    throw "Native aura text is not parented to the presentation overlay"
}
if ($nativeAuraRegionText -notmatch 'fallback\.presentation\s*=\s*CreateFrame' -or
    $nativeAuraRegionText -notmatch 'fallback\.presentation:CreateFontString') {
    throw "CDM/native fallback text is not parented to a presentation overlay"
}
if ($nativeAuraRegionText -notmatch 'fallback\.presentation:SetFrameLevel\(fallback:GetFrameLevel\(\) \+ 10\)') {
    throw "CDM/native fallback presentation does not render above its StatusBar"
}
if ($nativeAuraRegionText -match 'BaseRegion:ApplyCommonAppearance' -or $nativeAuraRegionText -match 'container:Hide\(\)') {
    throw "Native aura rendering still hides a forbidden AuraButton or one of its ancestors"
}
if ($nativeAuraRegionText -notmatch 'function Region:RefreshNativeUnit' -or $nativeAuraRegionText -notmatch 'container:UpdateAllAuras\(\)') {
    throw "Native target aura containers are not explicitly rebuilt when their unit token changes identity"
}
if ($nativeAuraRegionText -notmatch 'if not loadMatched then[\s\S]*?self\.fallback:Hide\(\)') {
    throw "Unloaded native regions can still expose their showAlways fallback"
}
if ($nativeAuraRegionText -notmatch 'function Region:SetNativeSuppressed' -or
    $nativeAuraRegionText -notmatch 'EMPTY_CANDIDATE_FILTERS' -or
    $nativeAuraRegionText -notmatch 'SetAuraSlotCandidateFilters\("popauras", EMPTY_CANDIDATE_FILTERS\)[\s\S]*?SetNativeEnabled\(false\)') {
    throw "Native slots are disabled before Blizzard securely clears their assigned AuraButton"
}
if ($nativeAuraRegionText -notmatch 'if not loadMatched then[\s\S]*?SetNativeSuppressed\(true\)') {
    throw "Talent/spec/gear unloads do not securely clear native aura slots"
}
if ($nativeAuraRegionText -notmatch 'function Region:Release\(\)[\s\S]*?self\.fallback:Hide\(\)') {
    throw "Released native regions can still expose their fallback"
}
if ($nativeAuraRegionText -notmatch 'function Region:SetLayoutVisible' -or
    $nativeAuraRegionText -notmatch 'SyncCDMSource[\s\S]*?self:SetLayoutVisible\(true\)') {
    throw "CDM/native regions do not update dynamic-group membership from public active state"
}
if ($nativeAuraRegionText -notmatch 'fallback\.countText' -or $nativeAuraRegionText -notmatch 'function Region:OnTimerUpdate') {
    throw "Native aura preview does not render stacks and animated duration state"
}
if ($nativeAuraRegionText -notmatch 'FindAuraDisplaySource' -or $nativeAuraRegionText -notmatch 'IsSecret\(auraSpellID\)') {
    throw "Secret exact auras do not fall back to a compatible CDM rendered source"
}
if ($nativeAuraRegionText -notmatch 'TriggerUsesAuraAlias' -or
    $nativeAuraRegionText -notmatch 'cdmFallbackEligible == true') {
    throw "CDM replacement is not restricted to ability-to-applied-aura relationships"
}
if ($nativeAuraRegionText -match 'GetAuraDataCached' -or $nativeAuraRegionText -match 'GetAuraSpellInstanceID') {
    throw "Native aura rendering reads CDM secret aura data instead of mirroring supported widgets"
}
if ($nativeAuraRegionText -notmatch 'hooksecurefunc\(sourceBar, "SetValue"' -or
    $nativeAuraRegionText -notmatch 'fallback\.bar:SetValue\(value\)') {
    throw "CDM aura fallback does not pass rendered bar values directly between StatusBar widgets"
}

$auraProviderText = Get-Content -LiteralPath (Join-Path $root "Triggers\AuraProvider.lua") -Raw
if ($auraProviderText -notmatch 'GetAuraSpellIDs') {
    throw "Logical aura queries do not expand ability IDs to their applied aura IDs"
}
if ($auraProviderText -match 'ShouldAurasBeSecret\(\)[^\r\n]*return\s+self\.allAuraIDs') {
    throw "Secret combat aura events still fan out to every configured aura"
}
if ($auraProviderText -notmatch 'if\s+not\s+unit\s+then\s+return\s+EMPTY') {
    throw "Unknown UNIT_AURA tokens do not fail closed"
}
if ($auraProviderText -notmatch 'nativeManaged' -or $auraProviderText -notmatch 'needsLogicalRefresh') {
    throw "Native aura bars still duplicate Blizzard UNIT_AURA evaluation and rendering"
}
if ($auraProviderText -notmatch 'function provider:HandleEvent' -or $auraProviderText -notmatch 'RefreshNativeAuraContainers') {
    throw "Aura events do not invalidate native target containers on target/death transitions"
}
if ($auraProviderText -notmatch 'event == "UNIT_AURA"[\s\S]*?RefreshNativeAuraSources') {
    throw "UNIT_AURA cannot bind CDM aura frames acquired after initial rendering"
}

$runtimeStoreText = Get-Content -LiteralPath (Join-Path $root "Engine\RuntimeStore.lua") -Raw
if ($runtimeStoreText -notmatch 'function RuntimeStore:RefreshNativeAuraContainers') {
    throw "Runtime store cannot refresh native aura containers by unit"
}
if ($runtimeStoreText -notmatch 'function RuntimeStore:RefreshNativeAuraSources') {
    throw "Runtime store cannot retry late CDM aura-source bindings"
}
if ($runtimeStoreText -notmatch 'function RuntimeStore:ScheduleGroupLayoutRefresh') {
    throw "Runtime store cannot coalesce native child visibility relayouts"
}

$spellAuraAliasesPath = Join-Path $root "Data\SpellAuraAliases.lua"
$spellAuraAliasesText = Get-Content -LiteralPath $spellAuraAliasesPath -Raw
$spellsText = Get-Content -LiteralPath (Join-Path $root "Util\Spells.lua") -Raw
$aliasLoadIndex = $tocText.IndexOf('Data\SpellAuraAliases.lua')
$spellResolverLoadIndex = $tocText.IndexOf('Util\Spells.lua')
if ($aliasLoadIndex -lt 0 -or $spellResolverLoadIndex -lt 0 -or $aliasLoadIndex -gt $spellResolverLoadIndex) {
    throw "Spell aura aliases are not loaded before the canonical spell resolver"
}
if ($spellsText -notmatch 'AURA_SPELL_ID_ALIASES\s*=\s*ns\.SpellAuraAliases') {
    throw "Canonical spell resolver does not consume the data-only aura catalogue"
}
if ($spellAuraAliasesText -notmatch '\[203720\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*203819\s*\}') {
    throw "Demon Spikes ability-to-aura migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[8921\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*164812\s*\}') {
    throw "Moonfire cast-to-debuff migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[155625\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*164812\s*\}') {
    throw "Cat Form Moonfire cast-to-debuff migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[1252871\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*164812\s*\}') {
    throw "Red Moon-to-Moonfire debuff migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[93402\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*164815\s*\}') {
    throw "Sunfire cast-to-debuff migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[1822\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*155722\s*\}') {
    throw "Rake cast-to-debuff migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[77758\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*192090\s*\}') {
    throw "Thrash cast-to-debuff migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[202345\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*279709\s*\}') {
    throw "Starlord talent-to-buff migration alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[49028\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*81256\s*\}' -or
    $spellAuraAliasesText -notmatch '\[395152\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*395296\s*\}' -or
    $spellAuraAliasesText -notmatch '\[374968\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*375234\s*\}' -or
    $spellAuraAliasesText -notmatch '\[62618\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*81782\s*\}' -or
    $spellAuraAliasesText -notmatch '\[23920\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*23920\s*,\s*385391\s*\}') {
    throw "Verified Retail 12.1 cooldown-to-player-aura catalogue is incomplete"
}
if ($spellAuraAliasesText -notmatch 'verifiedBuild\s*=\s*68745' -or
    $spellAuraAliasesText -notmatch 'verification\s*=' -or
    $spellAuraAliasesText -notmatch 'class\s*=' -or
    $spellAuraAliasesText -notmatch 'specs\s*=') {
    throw "Spell aura catalogue is missing maintenance metadata"
}
if ($spellAuraAliasesText -notmatch '\[198589\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*212800\s*\}[\s\S]*?verifiedBuild\s*=\s*68745') {
    throw "PTR-verified Blur alias is missing"
}
if ($spellAuraAliasesText -notmatch '\[115203\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*115203\s*,\s*120954\s*\}') {
    throw "Fortifying Brew does not retain its PTR-confirmed player aura ID"
}
if ($spellAuraAliasesText -notmatch '\[1241937\]\s*=\s*\{\s*auraSpellIDs\s*=\s*\{\s*1241937\s*,\s*1266696\s*\}[\s\S]*?status\s*=\s*"ptr-candidate"[\s\S]*?candidateBuild\s*=\s*68745') {
    throw "Soul Immolation correction is not explicitly marked as a PTR candidate"
}
if ($spellAuraAliasesText -match '\[(122470|58875|106898|187874)\]\s*=') {
    throw "Unapproved PTR-unverified spell aura aliases were added to the runtime catalogue"
}
if ($spellsText -notmatch 'local aliasRecord = AURA_SPELL_ID_ALIASES\[spellID\][\s\S]*?local aliases = aliasRecord and aliasRecord\.auraSpellIDs[\s\S]*?if not aliases or #aliases == 0 then[\s\S]*?return \{ spellID \}') {
    throw "Canonical aura resolver does not preserve the configured spell fallback"
}
if ($spellsText -notmatch 'function Spells:IsAuraAliasRelated') {
    throw "Aura alias relationships cannot be classified for CDM fallback selection"
}

if ($nativeAuraRegionText -notmatch 'nativeCandidateSignature' -or $nativeAuraRegionText -notmatch 'nativeFilterString') {
    throw "Native aura slots still rebuild unchanged candidate filters"
}

$auraBarListRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\AuraBarListRegion.lua") -Raw
if ($auraBarListRegionText -notmatch 'SetExplicitBounds\(button\.bar') {
    throw "Aura-list duration bars do not use explicit non-secret bounds"
}
if ($auraBarListRegionText -notmatch 'SetExplicitBounds\(button\.presentation') {
    throw "Aura-list text does not use an explicitly bounded presentation overlay"
}
if ($auraBarListRegionText -notmatch 'fontString:SetPoint\("CENTER", icon, "CENTER"') {
    throw "Aura-list ICON text anchors are not attached to the icon"
}
if ($auraBarListRegionText -notmatch 'SetHideCountdownNumbers\(true\)') {
    throw "Aura-list cooldown still exposes Blizzard's duplicate countdown numbers"
}
if ($auraBarListRegionText -notmatch 'presentation:CreateFontString') {
    throw "Aura-list text is not parented to the presentation overlay"
}
if ($auraBarListRegionText -match 'BaseRegion:ApplyCommonAppearance' -or $auraBarListRegionText -match 'container:Hide\(\)') {
    throw "Aura-list rendering still hides forbidden AuraButtons or their ancestors"
}
if ($auraBarListRegionText -notmatch 'ExpirationOnly' -or $auraBarListRegionText -notmatch 'SetAuraGroupSortMethod') {
    throw "Aura-list rendering does not enforce visual expiration ordering"
}
if ($auraBarListRegionText -match 'nativeButtons' -or
    $auraBarListRegionText -match 'function Region:Update\(aura, state\)[\s\S]*?StyleButton\(button, aura\)[\s\S]*?function Region:Release') {
    throw "Aura-list updates retain or restyle forbidden Blizzard AuraButtons"
}
if ($auraBarListRegionText -notmatch 'initializeFrame\s*=\s*function\(button\) self:InitializeNativeButton\(button\) end' -or
    $auraBarListRegionText -notmatch 'SetAuraGroupCandidateFilters\("popauras", EMPTY_CANDIDATE_FILTERS\)' -or
    $auraBarListRegionText -notmatch 'local inCombat\s*=\s*InCombatLockdown') {
    throw "Aura-list buttons are not initialized and suppressed through the combat-safe native container path"
}

$layoutsText = Get-Content -LiteralPath (Join-Path $root "Renderers\Layouts.lua") -Raw
if ($layoutsText -notmatch 'layoutVisible') {
    throw "Group layout cannot exclude disabled native aura regions without hiding forbidden frames"
}

$groupRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\GroupRegion.lua") -Raw
if ($groupRegionText -notmatch 'IsRegionLayoutVisible' -or $groupRegionText -notmatch 'loadMatched') {
    throw "Group visibility still treats unloaded native host frames as visible children"
}
if ($groupRegionText -notmatch 'function GroupRegion:RefreshChildLayout' -or
    $groupRegionText -notmatch 'CollectExistingChildren') {
    throw "Dynamic groups cannot relayout native children without rerendering them"
}

$baseRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\BaseRegion.lua") -Raw
if ($baseRegionText -notmatch 'SetParentKey' -or $baseRegionText -notmatch 'PopAurasRegion_') {
    throw "Runtime regions are not identifiable as PopAuras objects in /fstack"
}
if ($baseRegionText -match 'LibCustomGlow' -or $baseRegionText -match 'ArcGlow' -or
    $baseRegionText -match 'LibButtonGlow' -or $baseRegionText -match 'GetGlowLibrary') {
    throw "Runtime glow rendering still discovers third-party addon libraries"
}
if ($baseRegionText -notmatch 'EnsureBuiltInGlow' -or $baseRegionText -notmatch 'StartBuiltInGlow') {
    throw "Runtime glow rendering does not provide a self-contained PopAuras glow"
}
$unitFrameGlowText = Get-Content -LiteralPath (Join-Path $root "Engine\UnitFrameGlow.lua") -Raw
if ($unitFrameGlowText -match 'LibCustomGlow' -or $unitFrameGlowText -match 'ArcGlow' -or
    $unitFrameGlowText -match 'LibButtonGlow' -or $unitFrameGlowText -match 'GetGlowLibrary') {
    throw "Unit-frame glow actions still discover third-party addon libraries"
}
if ($unitFrameGlowText -notmatch 'BaseRegion' -or $baseRegionText -notmatch 'function BaseRegion:SetGlow') {
    throw "Unit-frame glow actions do not use the self-contained PopAuras glow"
}

$cooldownManagerText = Get-Content -LiteralPath (Join-Path $root "Core\CooldownManager.lua") -Raw
if ($cooldownManagerText -notmatch 'GetDirectCooldownIDsForSpellID') {
    throw "CDM visibility hiding still expands through linked spell mappings"
}
if ($cooldownManagerText -notmatch 'linkedCooldownID[\s\S]*linkedCooldownID ~= nil') {
    throw "CDM visibility hiding does not require linked mappings to resolve uniquely"
}
if ($cooldownManagerText -notmatch 'ApplyVisibilityOverrides[\s\S]*RestoreAllHiddenFrames\(\)') {
    throw "CDM visibility hiding does not release recycled frame assignments before resync"
}
if ($cooldownManagerText -notmatch 'function Manager:FindAuraStateSource' -or
    $cooldownManagerText -notmatch 'viewer == _G\.BuffIconCooldownViewer' -or
    $cooldownManagerText -notmatch 'function Manager:FindAuraDisplaySource' -or
    $cooldownManagerText -notmatch 'FindAuraSource\(self, spellIDs, requestedUnit, forceRefresh, IsAuraDisplayFrame\)') {
    throw "CDM aura state sources do not distinguish tracked icons from bar-only presentation sources"
}
if ($cooldownManagerText -notmatch 'EquipSlotEssential' -or
    $cooldownManagerText -notmatch 'FindOnUseEquipSlotFrame') {
    throw "CDM catalog does not expose known on-use equipment-slot entries"
}

$trinketProviderText = Get-Content -LiteralPath (Join-Path $root "Triggers\TrinketCooldownProvider.lua") -Raw
if ($trinketProviderText -notmatch 'INVSLOT_TRINKET1' -or
    $trinketProviderText -notmatch 'INVSLOT_TRINKET2' -or
    $trinketProviderText -notmatch 'GetInventoryItemCooldown') {
    throw "Trinket cooldown provider does not track both equipped trinket slots"
}
if ($trinketProviderText -notmatch 'GetUseAuraDisplayTime' -or
    $trinketProviderText -match 'C_UnitAuras' -or
    $trinketProviderText -match 'GetAuraData') {
    throw "Trinket active-effect glow is not using the CDM presentation boolean boundary"
}
if ($trinketProviderText -notmatch 'ignoredTrinkets' -or
    $trinketProviderText -notmatch 'entries\s*=\s*entries') {
    throw "Trinket cooldown provider does not support ignores or independent slot entries"
}

$multiStateRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\MultiStateRegion.lua") -Raw
if ($multiStateRegionText -notmatch 'GetLayoutRegions' -or
    $multiStateRegionText -notmatch 'layoutOrder') {
    throw "Independent trinket entries do not participate in group layouts"
}
if ($multiStateRegionText -notmatch 'GetCountdownFontString' -or
    $multiStateRegionText -notmatch 'trinketCountdownFontString:GetText\(\)' -or
    $multiStateRegionText -match 'GetCooldownTimes' -or
    $multiStateRegionText -match 'GetCooldownDuration') {
    throw "Trinket active-effect duration is not mirrored through CDM's presentation-only countdown text"
}
if ($runtimeStoreText -notmatch 'trinketTopSoundFile' -or
    $runtimeStoreText -notmatch 'trinketBottomSoundFile' -or
    $runtimeStoreText -notmatch 'FindStateEntry') {
    throw "Dual trinket entries do not have independent sound transitions"
}

$displayPanelText = Get-Content -LiteralPath (Join-Path $root "UI\Panels\DisplayPanel.lua") -Raw
foreach ($label in @('Trinket 1 (Top)', 'Trinket 2 (Bottom)')) {
    if ($displayPanelText -notmatch [regex]::Escape($label)) {
        throw "Dual trinket sound UI is missing '$label'"
    }
}
$defaultsText = Get-Content -LiteralPath (Join-Path $root "Data\Defaults.lua") -Raw
$schemaText = Get-Content -LiteralPath (Join-Path $root "Data\Schema.lua") -Raw
$triggerEngineText = Get-Content -LiteralPath (Join-Path $root "Engine\TriggerEngine.lua") -Raw
$barRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\BarRegion.lua") -Raw
if ($barRegionText -notmatch 'GetAuraSpellInstanceID' -or
    $barRegionText -notmatch 'C_UnitAuras\.GetAuraDuration' -or
    $barRegionText -notmatch 'Duration:BuildTimer\(durationObject, "active_buff_cdm", true\)' -or
    $barRegionText -notmatch 'FindAuraStateSource\(state\.activeBuffSpellIDs, "player", true\)') {
    throw "Spell cooldown combat presentation does not consume an opaque CDM aura DurationObject on the rendering path"
}
if ($displayPanelText -notmatch 'No Stacks Bar Color' -or
    $displayPanelText -notmatch 'noStacksBarColorEnabled' -or
    $defaultsText -notmatch 'noStacksBarColorEnabled\s*=\s*false') {
    throw "Spell Cooldown bars do not expose a saved No Stacks Bar Color option"
}
if ($spellCooldownText -notmatch 'noCharges\s*=\s*chargeStateKnown and outOfCharges' -or
    $schemaText -notmatch 'state\.noCharges\s*=\s*SafeBoolean' -or
    $triggerEngineText -notmatch '"noCharges"' -or
    $barRegionText -notmatch 'state\.noCharges\s*==\s*true') {
    throw "No Stacks Bar Color is not driven by the secret-safe zero-charge state"
}

$triggerPanelText = Get-Content -LiteralPath (Join-Path $root "UI\Panels\TriggerPanel.lua") -Raw
foreach ($label in @('Trinket Cooldown', 'Top Trinket Slot', 'Bottom Trinket Slot', 'Grow Direction', 'Glow While Active', 'Ignored Trinkets')) {
    if ($triggerPanelText -notmatch [regex]::Escape($label)) {
        throw "Trinket trigger UI is missing '$label'"
    }
}
if ($triggerPanelText -notmatch 'trinketGrowthValues' -or
    $multiStateRegionText -notmatch 'trigger\.trinketGrowth') {
    throw "Independent trinket entries do not expose or apply their growth direction"
}

$spellCastEventText = Get-Content -LiteralPath (Join-Path $root "Triggers\SpellCastEventProvider.lua") -Raw
if ($spellCastEventText -notmatch 'UNIT_SPELLCAST_SUCCEEDED' -or
    $spellCastEventText -notmatch 'unit\s*~=\s*"player"' -or
    $spellCastEventText -notmatch 'Safe:Number\(spellID\)' -or
    $spellCastEventText -notmatch 'actionEventKey\s*=\s*activeEvent\.eventKey') {
    throw "Player spell-cast event triggers are not enforcing the secret-safe event boundary"
}
if ($triggerPanelText -notmatch 'Spell Cast Event') {
    throw "Spell Cast Event is missing from the trigger editor"
}

$constantsText = Get-Content -LiteralPath (Join-Path $root "Core\Constants.lua") -Raw
$migrationText = Get-Content -LiteralPath (Join-Path $root "Data\Migration.lua") -Raw
if ($constantsText -notmatch 'DB_VERSION\s*=\s*5' -or
    $migrationText -notmatch 'aura\.kind\s*==\s*"communication"' -or
    $migrationText -notmatch 'action\.type\s*~=\s*"send_chat_message"') {
    throw "Removed Communication auras do not have a saved-variable migration"
}

$mainWindowText = Get-Content -LiteralPath (Join-Path $root "UI\MainWindow.lua") -Raw
if ($mainWindowText -notmatch 'GetAddOnMetadata' -or $mainWindowText -notmatch 'PopAuras.*version') {
    throw "Main window title does not include addon version metadata"
}
if ($mainWindowText -notmatch 'OnHide' -or $mainWindowText -notmatch 'runtime:RefreshAll\(\)') {
    throw "Closing the main window does not clear editor preview states"
}
if ($mainWindowText -notmatch 'previewAnimateCheck[\s\S]*?runtime:RefreshAuras\(\{ aura\.id \}\)') {
    throw "Preview animation changes do not refresh ancestor group layout"
}

$debugText = Get-Content -LiteralPath (Join-Path $root "Core\Debug.lua") -Raw
if ($debugText -match 'CopyToClipboard' -or
    $debugText -notmatch 'HighlightText\(\)' -or
    $debugText -notmatch 'Press Ctrl\+C to copy it') {
    throw "Export copy mode calls a protected clipboard API or lacks the restriction-safe selected-text flow"
}

$framesText = Get-Content -LiteralPath (Join-Path $root "Util\Frames.lua") -Raw
if ($framesText -notmatch 'function Frames\.ShowConfirmation' -or
    $framesText -notmatch 'StyleSuccessButton' -or
    $framesText -notmatch 'StyleDangerButton') {
    throw "Shared confirmation modal or its success/danger button styles are missing"
}

$importText = Get-Content -LiteralPath (Join-Path $root "Data\Import.lua") -Raw
$importPanelText = Get-Content -LiteralPath (Join-Path $root "UI\Panels\ImportExportPanel.lua") -Raw
if ($importText -notmatch 'name = primaryAura' -or
    $importPanelText -notmatch 'Confirm Import' -or
    $importPanelText -notmatch 'Successfully imported' -or
    $importPanelText -match 'Import Add') {
    throw "Import UI does not preview, confirm, and report the named import package"
}

$registryText = Get-Content -LiteralPath (Join-Path $root "Core\Registry.lua") -Raw
$auraTreeText = Get-Content -LiteralPath (Join-Path $root "UI\AuraTree.lua") -Raw
if ($registryText -notmatch 'function Registry:CountDescendants' -or
    $auraTreeText -notmatch 'CountDescendants' -or
    $auraTreeText -notmatch 'Deleting the group will permanently delete') {
    throw "Aura deletion does not confirm or warn about nested group descendants"
}

& (Join-Path $root "deploy.ps1") -WhatIf

Write-Host "PopAuras static verification passed." -ForegroundColor Green
