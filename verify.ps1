$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$toc = Join-Path $root "PopAuras.toc"
$optionsRoot = Join-Path $root "Options"
$optionsToc = Join-Path $optionsRoot "PopAuras_Options.toc"
if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) {
    throw "Missing PopAuras.toc"
}
if (-not (Test-Path -LiteralPath $optionsToc -PathType Leaf)) {
    throw "Missing bundled PopAuras_Options.toc"
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

$missingOptions = @()
Get-Content -LiteralPath $optionsToc | ForEach-Object {
    $entry = $_.Trim()
    if ($entry -match '\.lua$' -and -not (Test-Path -LiteralPath (Join-Path $optionsRoot $entry) -PathType Leaf)) {
        $missingOptions += $entry
    }
}
if ($missingOptions.Count -gt 0) {
    throw "Options TOC references missing files: $($missingOptions -join ', ')"
}

$tocText = Get-Content -LiteralPath $toc -Raw
$optionsTocText = Get-Content -LiteralPath $optionsToc -Raw
if ($tocText -notmatch '(?m)^## Interface:\s*120100\s*$') {
    throw "PopAuras.toc is not targeting PTR interface 120100"
}
if ($tocText -notmatch '(?m)^## Version:\s*12\.1\.7\s*$' -or
    $optionsTocText -notmatch '(?m)^## Version:\s*12\.1\.7\s*$') {
    throw "Core and options metadata are not aligned to release 12.1.6"
}
if ($optionsTocText -notmatch '(?m)^## LoadOnDemand:\s*1\s*$' -or
    $optionsTocText -notmatch '(?m)^## Dependencies:\s*PopAuras\s*$') {
    throw "PopAuras_Options is not a load-on-demand companion of PopAuras"
}
if ($tocText -match '(?m)^UI\\.*\.lua\s*$') {
    throw "Editor Lua is still listed in the base PopAuras TOC"
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
foreach ($runtimeFile in $runtimeFiles) {
    $firstLine = Get-Content -LiteralPath $runtimeFile.FullName -TotalCount 1
    if ($firstLine -match '^(Exit code:|Wall time:|Output:|Script (completed|failed))') {
        throw "Tool transcript text was prepended to Lua source at $($runtimeFile.FullName):1"
    }
}
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
if ($nativeAuraRegionText -match 'SetExplicitBounds\(button\.cooldown' -or
    $nativeAuraRegionText -notmatch 'button\.cooldown:SetPoint\("TOPLEFT", button\.icon, "TOPLEFT"' -or
    $nativeAuraRegionText -notmatch 'button\.cooldown:SetPoint\("BOTTOMRIGHT", button\.icon, "BOTTOMRIGHT"' -or
    $nativeAuraRegionText -match 'button\.cooldown:SetShown\(' -or
    $nativeAuraRegionText -notmatch 'SetDrawSwipe\(showIconCooldown\)') {
    throw "Native aura radial cooldown artwork is not isolated to the bar icon"
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
if ($runtimeStoreText -notmatch 'local function ShouldPlaySoundForMode' -or
    $runtimeStoreText -notmatch 'if soundMode == "ready" then[\s\S]*?return ShouldPlayReadySound' -or
    $runtimeStoreText -match 'soundMode == "ready"\s*[\r\n]+\s*and ShouldPlayReadySound[\s\S]*?or ShouldPlayActivationSound') {
    throw "Ready-mode sounds can fall through to activation transitions"
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
$unitAuraListText = Get-Content -LiteralPath (Join-Path $root "Util\UnitAuraList.lua") -Raw
$auraListDefaultsText = Get-Content -LiteralPath (Join-Path $root "Data\Defaults.lua") -Raw
if ($auraBarListRegionText -notmatch 'SetExplicitBounds\(button\.bar') {
    throw "Aura-list duration bars do not use explicit non-secret bounds"
}
if ($auraBarListRegionText -notmatch 'SetExplicitBounds\(button\.presentation') {
    throw "Aura-list text does not use an explicitly bounded presentation overlay"
}
if ($auraBarListRegionText -match 'SetExplicitBounds\(button\.cooldown, button, width, height\)' -or
    $auraBarListRegionText -notmatch 'button\.cooldown:SetPoint\("TOPLEFT", button\.icon' -or
    $auraBarListRegionText -notmatch 'button\.background\s*=\s*button\.bar:CreateTexture' -or
    $auraBarListRegionText -match 'button\.background\s*=\s*button\.cooldown:CreateTexture') {
    throw "Aura-list radial cooldown artwork is not isolated to the icon from the full-row bar background"
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
if ($auraBarListRegionText -notmatch 'ExpirationOnly' -or
    $auraBarListRegionText -notmatch 'UnitAuraList:GetSortMode\(trigger\)' -or
    $auraBarListRegionText -notmatch 'sortMode\s*==\s*"longest_first"[\s\S]*?directions\.Reverse[\s\S]*?directions\.Normal' -or
    $auraBarListRegionText -notmatch 'SetAuraGroupSortMethod') {
    throw "Aura-list rendering does not delegate configurable expiration ordering to Blizzard"
}
if ($auraBarListRegionText -notmatch 'SetFlowLayoutAnchorPoint' -or
    $auraBarListRegionText -notmatch 'SetFlowLayoutGrowthDirection' -or
    $auraBarListRegionText -notmatch 'SetFlowLayoutMaximumLineSize' -or
    $auraBarListRegionText -match 'SetAuraLayout(AnchorPoint|GrowthDirection|RowWidth)' -or
    $auraBarListRegionText -notmatch 'elementSpacing\s*=\s*spacing' -or
    $auraBarListRegionText -notmatch 'lineSpacing\s*=\s*spacing') {
    throw "Aura-list rendering is not using the Retail 12.1 flow-layout API"
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
if ($auraBarListRegionText -notmatch 'button\.background\s*=\s*button\.bar:CreateTexture' -or
    $auraBarListRegionText -notmatch 'SetDurationBar\(button\.bar' -or
    $auraBarListRegionText -match 'button\.cooldown:SetShown\(display\.swipe' -or
    $auraBarListRegionText -notmatch 'SetDrawSwipe\(showIconCooldown\)') {
    throw "Aura-list backgrounds and radial swipes are not separated across Blizzard's duration bar and icon cooldown presentation"
}
if ($auraBarListRegionText -notmatch 'PresentationStyleSignature' -or
    $auraBarListRegionText -notmatch 'function Region:RetireNativeContainer[\s\S]*?self:SetNativeSuppressed\(true\)' -or
    $auraBarListRegionText -notmatch 'presentationStyleSignature\s*~=\s*buttonStyleSignature[\s\S]*?self:RetireNativeContainer\(\)') {
    throw "Aura-list swipe changes do not safely replace their one-time native presentation"
}
if ($auraBarListRegionText -notmatch 'function Region:RefreshNativeUnit' -or
    $auraBarListRegionText -notmatch 'function Region:RefreshNativeUnit[\s\S]*?self\.container:UpdateAllAuras\(\)') {
    throw "Native target aura lists are not explicitly rebuilt when their unit token changes identity"
}
if ($unitAuraListText -notmatch 'filters\.maxDuration\s*=\s*maxDuration' -or
    $unitAuraListText -notmatch 'maxFrameCount\s*=\s*maxRows\s*>\s*0\s*and\s*maxRows\s*or\s*math\.huge') {
    throw "Aura-list native duration or row-limit filters are incomplete"
}
if ($unitAuraListText -notmatch 'GetDefaultSortModeForSourceValue' -or
    $unitAuraListText -notmatch 'sourceValue\s*==\s*"player_buff"\s*and\s*"longest_first"\s*or\s*"shortest_first"' -or
    $unitAuraListText -notmatch 'function UnitAuraList:RetireCasterFilter') {
    throw "Aura-list source defaults or retired caster-filter normalization are incomplete"
}
if ($unitAuraListText -notmatch 'DEFAULT_MAX_ROWS\s*=\s*0' -or
    $unitAuraListText -notmatch 'math\.max\(0,\s*math\.min\(value,\s*MAX_MAX_ROWS\)\)' -or
    $auraListDefaultsText -notmatch 'auraListMaxRows\s*=\s*0') {
    throw "Aura-list zero-row configuration is not normalized as native unlimited"
}
if ($auraBarListRegionText -notmatch 'elseif self\.containerSignature ~= signature then[\s\S]*?self:SetNativeSuppressed\(true\)[\s\S]*?SetAuraGroupFilterString\("popauras", options\.filterString\)[\s\S]*?SetUnit\(options\.unit\)' -or
    $auraBarListRegionText -match 'if not self\.container or self\.containerSignature ~= signature then' -or
    $auraBarListRegionText -notmatch 'local maxFrameCount\s*=\s*tonumber\(options\.maxFrameCount') {
    throw "Aura-list edits do not safely reconfigure the existing native container"
}
if ($auraBarListRegionText -notmatch 'self\.loadMatched\s*=\s*state\s*and\s*state\.loadMatched\s*==\s*true' -or
    $auraBarListRegionText -notmatch 'if not self\.loadMatched then[\s\S]*?self\.layoutVisible\s*=\s*false[\s\S]*?self:SetNativeSuppressed\(true\)[\s\S]*?return') {
    throw "Aura-list native containers are not suppressed when load conditions fail"
}

$nameplateAuraRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\NameplateAuraRegion.lua") -Raw
$nameplateConstantsText = Get-Content -LiteralPath (Join-Path $root "Core\Constants.lua") -Raw
$nameplateTriggerEngineText = Get-Content -LiteralPath (Join-Path $root "Engine\TriggerEngine.lua") -Raw
$nameplateProviderText = Get-Content -LiteralPath (Join-Path $root "Triggers\AuraProvider.lua") -Raw
$nameplateLoadPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Panels\LoadPanel.lua") -Raw
$nameplateNewAuraPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\NewAuraPanel.lua") -Raw
$nameplateCreateDialogText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\CreateAuraDialog.lua") -Raw
$nameplateTriggerPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Panels\TriggerPanel.lua") -Raw
$nameplateDisplayPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Panels\DisplayPanel.lua") -Raw
$nameplateAnchorsText = Get-Content -LiteralPath (Join-Path $root "Util\Anchors.lua") -Raw
if ($tocText.IndexOf('Renderers\NameplateAuraRegion.lua') -lt 0 -or
    $nameplateConstantsText -notmatch 'feature_nameplate_buffs\s*=\s*true' -or
    $loadEvaluatorText -notmatch 'function LoadEvaluator:GetDisabledFeature\(aura\)' -or
    $loadEvaluatorText -notmatch 'trigger\.type\s*==\s*"aura"\s*and\s*trigger\.unit\s*==\s*"nameplate"' -or
    $nameplateLoadPanelText -notmatch 'GetDisabledFeature\(aura\)' -or
    $nameplateTriggerEngineText -notmatch 'NameplateBuffsEnabled\(\)\s*and\s*not wantsMultiState' -or
    $nameplateAuraRegionText -notmatch 'if not self:IsFeatureEnabled\(\) then\s*self:Release\(\)' -or
    $nameplateNewAuraPanelText -notmatch 'feature\s*=\s*"feature_nameplate_buffs"' -or
    $nameplateCreateDialogText -notmatch 'IsPresetEnabled\(preset\)' -or
    $nameplateTriggerPanelText -notmatch 'IsEnabled\("feature_nameplate_buffs"\)[\s\S]*?auraUnitValues\[#auraUnitValues \+ 1\]') {
    throw "Nameplate buff creation or runtime activation is not fully gated by its feature flag"
}
if ($nameplateAnchorsText -notmatch 'function Anchors\.GetNameplateAnchorList\(\)' -or
    $nameplateAnchorsText -notmatch 'function Anchors\.ResolveNameplatePoints\(position\)' -or
    $nameplateAnchorsText -notmatch 'TOP\s*=\s*\{\s*point\s*=\s*"BOTTOM",\s*relativePoint\s*=\s*"TOP"\s*\}' -or
    $nameplateDisplayPanelText -notmatch '"Nameplate Anchor"[\s\S]*?Anchors\.GetNameplateAnchorList' -or
    $nameplateDisplayPanelText -notmatch 'Anchors\.ApplyNameplateAnchor' -or
    $nameplateAuraRegionText -notmatch 'Anchors\.ResolveNameplatePoints\(position\)') {
    throw "Nameplate display placement is not using the dedicated anchor mapping"
}
if ($nameplateTriggerPanelText -notmatch 'Blizzard owns aura detection and presentation' -or
    $nameplateTriggerPanelText -notmatch 'Checked categories are combined with AND' -or
    $nameplateTriggerPanelText -notmatch 'nameplateFilterBox:SetShown\(isNameplateAura\)' -or
    $nameplateTriggerPanelText -notmatch 'triggerSelectLabel:SetShown\(not usesDedicatedTriggerEditor\)' -or
    $nameplateTriggerPanelText -match 'field\s*=\s*"nameplateRoleAura"' -or
    $nameplateTriggerPanelText -match 'field\s*=\s*"nameplateShowAll"' -or
    $nameplateTriggerPanelText -match 'field\s*=\s*"nameplateShowPersonal"' -or
    $nameplateAuraRegionText -match 'nameplateRoleAura|nameplateShowAll|nameplateShowPersonal') {
    throw "Nameplate category filters are missing their dedicated explained editor"
}
if ($nameplateAuraRegionText -notmatch 'NAME_PLATE_UNIT_ADDED' -or
    $nameplateAuraRegionText -notmatch 'NAME_PLATE_UNIT_REMOVED' -or
    $nameplateAuraRegionText -notmatch 'C_NamePlate\.GetNamePlateForUnit' -or
    $nameplateAuraRegionText -match 'UNIT_AURA|GetAuraDataBy|GetBuffDataBy|GetDebuffDataBy|GetChildren\(') {
    throw "Nameplate aura rendering does not use the bounded public nameplate lifecycle"
}
if ($nameplateAuraRegionText -notmatch 'SetFlowLayoutAnchorPoint' -or
    $nameplateAuraRegionText -notmatch 'SetFlowLayoutGrowthDirection' -or
    $nameplateAuraRegionText -notmatch 'SetFlowLayoutMaximumLineSize' -or
    $nameplateAuraRegionText -notmatch 'SetAuraGroupLayout' -or
    $nameplateAuraRegionText -match 'SetAuraLayout(AnchorPoint|GrowthDirection|RowWidth)' -or
    $nameplateAuraRegionText -notmatch 'elementSpacing\s*=\s*spacing') {
    throw "Nameplate aura rendering is not using the Retail 12.1 flow-layout API"
}
if ($nameplateAuraRegionText -notmatch 'CreateContainer\(UIParent\)' -or
    $nameplateAuraRegionText -match 'CreateContainer\(plate\)' -or
    $nameplateAuraRegionText -match 'container:Hide\(\)') {
    throw "Native nameplate containers inherit or hide a protected nameplate frame"
}
if ($nameplateAuraRegionText -notmatch 'initializeFrame\s*=\s*function\(button\) self:InitializeNativeButton\(button\) end' -or
    $nameplateAuraRegionText -notmatch 'SetDurationCooldown' -or
    $nameplateAuraRegionText -notmatch 'SetDurationText' -or
    $nameplateAuraRegionText -notmatch 'SetApplicationCount') {
    throw "Nameplate AuraButtons are not initialized through Blizzard presentation bindings"
}
if ($nameplateAuraRegionText -notmatch 'SetAuraGroupCandidateFilters\(GROUP_KEY, EMPTY_CANDIDATE_FILTERS\)[\s\S]*?SetEntryEnabled\(entry, false\)' -or
    $nameplateAuraRegionText -notmatch 'EMPTY_CANDIDATE_FILTERS\s*=\s*\{\s*includeDispelTypes\s*=\s*\{\s*\}\s*\}' -or
    $nameplateAuraRegionText -match 'includeSpellIDs') {
    throw "Nameplate native groups do not fail closed through supported non-identity filters"
}
if ($nameplateAuraRegionText -notmatch 'filters\.isStealable' -or
    $nameplateAuraRegionText -notmatch 'filters\.isBossAura' -or
    $nameplateAuraRegionText -notmatch 'filters\.isPriorityAura' -or
    $nameplateAuraRegionText -notmatch 'includeDispelTypes' -or
    $nameplateProviderText -notmatch 'source\s*=\s*"nameplate_aura"' -or
    $nameplateProviderText -notmatch 'unit:find\("\^nameplate%d\+\$"\)') {
    throw "Nameplate native filters or provider isolation are incomplete"
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
if ($unitFrameGlowText -notmatch 'SetUnitFrameGlow' -or
    $baseRegionText -notmatch 'function BaseRegion:SetUnitFrameGlow' -or
    $baseRegionText -notmatch 'ActionButtonSpellAlertManager' -or
    $baseRegionText -notmatch 'EnsureUnitFrameGlowHost') {
    throw "Unit-frame glow actions do not use Midnight's standard animated border with a PopAuras-owned host"
}
if ($unitFrameGlowText -notmatch 'DandersFrames_GetFrameForUnit' -or
    $unitFrameGlowText -notmatch 'EUIStandaloneUnitFramesUF' -or
    $unitFrameGlowText -notmatch 'ERFPartyHeader' -or
    $unitFrameGlowText -notmatch 'ERFFlatHeader' -or
    $unitFrameGlowText -notmatch 'ForEachFrameForUnit' -or
    $unitFrameGlowText -notmatch 'VUHDO_getUnitButtonsSafe') {
    throw "Unit-frame resolution is missing a supported third-party adapter"
}
if ($unitFrameGlowText -notmatch 'GetNonSecretBoolean' -or
    $unitFrameGlowText -notmatch 'GetNonSecretBoolean\(isShown\)' -or
    $unitFrameGlowText -notmatch 'GetNonSecretBoolean\(isVisible\)' -or
    $unitFrameGlowText -match 'isShown\s*==\s*false' -or
    $unitFrameGlowText -match 'isVisible\s*==\s*false') {
    throw "Unit-frame resolution branches on restricted visibility booleans"
}
if ($unitFrameGlowText -notmatch 'UnitExistsSafe' -or
    $unitFrameGlowText -match 'and\s+UnitExists\(' -or
    $unitFrameGlowText -match 'not\s+UnitExists\(') {
    throw "Unit-frame resolution branches directly on restricted unit-existence values"
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
if ($trinketProviderText -notmatch 'FindAuraStateSource' -or
    $trinketProviderText -notmatch 'source\.IsActive' -or
    $trinketProviderText -notmatch 'SetUseAuraDisplayTime", function\(owner, useAuraDisplayTime\)' -or
    $trinketProviderText -notmatch 'cooldownAuraDisplayState\[owner\]\s*=\s*active' -or
    $trinketProviderText -notmatch 'aura\.display\.glowWhenActive\s*==\s*true' -or
    $trinketProviderText -match 'trigger\.glowWhileActive' -or
    $trinketProviderText -match 'C_UnitAuras' -or
    $trinketProviderText -match 'GetAuraData') {
    throw "Trinket active-effect glow is not using the live CDM active/presentation boolean boundary"
}
if ($trinketProviderText -notmatch 'ignoredTrinkets' -or
    $trinketProviderText -notmatch 'entries\s*=\s*entries') {
    throw "Trinket cooldown provider does not support ignores or independent slot entries"
}

$multiStateRegionText = Get-Content -LiteralPath (Join-Path $root "Renderers\MultiStateRegion.lua") -Raw
if ($multiStateRegionText -notmatch 'display\.glowWhenActive\s*=\s*false') {
    throw "Trinket multi-state entries still allow generic cooldown-active glow"
}
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

$displayPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Panels\DisplayPanel.lua") -Raw
$triggerPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Panels\TriggerPanel.lua") -Raw
$editorDesignText = Get-Content -LiteralPath (Join-Path $optionsRoot "EditorDesign.lua") -Raw
$texturePickerText = Get-Content -LiteralPath (Join-Path $optionsRoot "TexturePicker.lua") -Raw
$mediaText = Get-Content -LiteralPath (Join-Path $root "Util\Media.lua") -Raw
foreach ($label in @('Trinket 1 (Top)', 'Trinket 2 (Bottom)')) {
    if ($displayPanelText -notmatch [regex]::Escape($label)) {
        throw "Dual trinket sound UI is missing '$label'"
    }
}
if ($displayPanelText -notmatch 'function Panel:SetActiveSection' -or
    $displayPanelText -notmatch 'frame\.sectionTabs' -or
    $displayPanelText -notmatch 'Theme\.StyleTab') {
    throw "Display configuration does not use the contained secondary tab menu"
}
if ($displayPanelText -notmatch 'frame\.summary:Hide\(\)' -or
    $displayPanelText -notmatch 'frame\.hint:Hide\(\)' -or
    $displayPanelText -notmatch 'Frames\.CreateSectionCard' -or
    $editorDesignText -notmatch 'section\.rowBands' -or
    $editorDesignText -notmatch 'string\.upper\(title') {
    throw "Display configuration is missing its unified section-card treatment"
}
if ($tocText.IndexOf('Util\Media.lua') -lt 0 -or
    $tocText.IndexOf('Util\Media.lua') -gt $tocText.IndexOf('Util\Theme.lua') -or
    $optionsTocText.IndexOf('TexturePicker.lua') -lt 0 -or
    $optionsTocText.IndexOf('TexturePicker.lua') -gt $optionsTocText.IndexOf('UI\Panels\DisplayPanel.lua')) {
    throw "The centralized media catalogue or texture picker is missing from a safe TOC position"
}
if ($mediaText -notmatch 'function Media:ResolveStatusBarTexture' -or
    $mediaText -notmatch 'function Media:GetStatusBarTextureOptions' -or
    $mediaText -notmatch 'LibSharedMedia-3\.0' -or
    $mediaText -notmatch 'EllesmereUI\\\\Media\\\\textures' -or
    $mediaText -notmatch 'blinkii-diamonds' -or
    $mediaText -notmatch 'kringel-window') {
    throw "The bar texture catalogue no longer covers built-in, EllesmereUI, and SharedMedia sources"
}
if ($texturePickerText -notmatch 'Search textures' -or
    $texturePickerText -notmatch 'row\.preview:SetTexture' -or
    $displayPanelText -notmatch 'TexturePicker:Toggle' -or
    $displayPanelText -notmatch 'GetStatusBarTextureOptions' -or
    $displayPanelText -notmatch 'dropdown\.Button:EnableMouse\(false\)' -or
    $displayPanelText -notmatch 'barTexturePickerHitBox:RegisterForClicks\("LeftButtonUp"\)') {
    throw "The Display editor no longer exposes the searchable visual texture picker"
}
$textureRenderers = @($barRegionText, $nativeAuraRegionText, $activeDurationNativeText, $auraBarListRegionText)
foreach ($rendererText in $textureRenderers) {
    if ($rendererText -notmatch 'Media:ResolveStatusBarTexture' -or
        $rendererText -match 'local function (GetTexturePath|TexturePath)') {
        throw "A bar renderer bypasses the centralized texture resolver"
    }
}
foreach ($verticalRendererText in @($barRegionText, $nativeAuraRegionText, $activeDurationNativeText)) {
    if ($verticalRendererText -notmatch 'SetRotatesTexture\([^\r\n]*==\s*"VERTICAL"\)' -or
        $verticalRendererText -match 'SetRotatesTexture\([^\r\n]*~=\s*"VERTICAL"\)') {
        throw "A vertical bar renderer uses the inverted texture-rotation rule"
    }
}
if ($displayPanelText -notmatch 'trigger\.type\s*~=\s*"death_alert"') {
    throw "Death Alert auras still expose the redundant Display sound category"
}
if ($displayPanelText -notmatch 'auraListSwipeCheck' -or
    $displayPanelText -notmatch '"Show Cooldown Swipe"' -or
    $displayPanelText -notmatch 'aura\.display\.swipe\s*=\s*frame\.auraListSwipeCheck:GetChecked\(\)\s*==\s*true') {
    throw "Buffs and Debuffs does not expose its safe native cooldown-swipe option"
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
if ($displayPanelText -notmatch 'Out-of-Stacks Color' -or
    $displayPanelText -notmatch 'noStacksBarColorEnabled' -or
    $defaultsText -notmatch 'noStacksBarColorEnabled\s*=\s*false') {
    throw "Spell Cooldown bars do not expose a saved Out-of-Stacks Color option"
}
if ($displayPanelText -notmatch 'Show cooldown while charges remain' -or
    $displayPanelText -notmatch 'CreateLabeledToggle\([\s\S]{0,100}"Show cooldown while charges remain"' -or
    $displayPanelText -notmatch 'chargeCooldownCheck:SetPoint\("TOPLEFT", 12, -516\)' -or
    $displayPanelText -notmatch 'trigger\.showChargeCooldown\s*=\s*frame\.chargeCooldownCheck:GetChecked' -or
    $triggerPanelText -match 'Show cooldown while charges remain') {
    throw "The partial-charge cooldown option is not owned exclusively by Display"
}
if ($displayPanelText -match 'showAuraWindow|Show CDM aura/proc' -or
    $triggerPanelText -match 'showAuraWindow|Show CDM aura/proc' -or
    $defaultsText -match 'showAuraWindow') {
    throw "The unused CDM aura/proc option is still exposed or initialized"
}
$loadPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Panels\LoadPanel.lua") -Raw
if ($loadPanelText -notmatch '"Instance Information"' -or
    $loadPanelText -notmatch 'GetInstanceInfo' -or
    $loadPanelText -notmatch 'C_EncounterJournal\.GetInstanceForGameMap' -or
    $loadPanelText -notmatch 'EJ_GetEncounterInfoByIndex' -or
    $loadPanelText -notmatch 'EJ_GetEncounterInfo' -or
    $loadPanelText -notmatch 'resolvedDungeonEncounterID' -or
    $loadPanelText -notmatch 'ZONE_CHANGED_NEW_AREA') {
    throw "Load configuration is missing live instance and runtime encounter ID information"
}
if ($spellCooldownText -notmatch 'noCharges\s*=\s*chargeStateKnown and outOfCharges' -or
    $schemaText -notmatch 'state\.noCharges\s*=\s*SafeBoolean' -or
    $triggerEngineText -notmatch '"noCharges"' -or
    $barRegionText -notmatch 'state\.noCharges\s*==\s*true') {
    throw "Out-of-Stacks Color is not driven by the secret-safe zero-charge state"
}

if ($triggerPanelText -notmatch 'Frames\.CreateScrollPanel' -or
    $triggerPanelText -notmatch 'contentHeight\s*=\s*1040') {
    throw "Long trigger forms are not hosted in the shared scroll panel"
}
if ($triggerPanelText -notmatch '\{\s*value\s*=\s*"shortest_first",\s*label\s*=\s*"Soonest Expiring First"\s*\}' -or
    $triggerPanelText -notmatch '\{\s*value\s*=\s*"longest_first",\s*label\s*=\s*"Longest / Permanent First"\s*\}' -or
    $triggerPanelText -notmatch '"Maximum Original Duration"' -or
    $triggerPanelText -notmatch '"Maximum Displayed Rows"' -or
    $triggerPanelText -notmatch 'Theme\.StyleSurface\(frame\.auraListSettingsBox' -or
    $triggerPanelText -match 'Target Debuff Filter|Only Mine|Mine \+ Non-Player') {
    throw "Buffs and Debuffs is missing its modern native sort/filter editor or still exposes retired caster filters"
}
foreach ($label in @('Trinket Cooldown', 'Top Trinket Slot', 'Bottom Trinket Slot', 'Grow Direction', 'Ignored Trinkets')) {
    if ($triggerPanelText -notmatch [regex]::Escape($label)) {
        throw "Trinket trigger UI is missing '$label'"
    }
}
if ($displayPanelText -notmatch '"Glow While Trinket Buff Active"' -or
    $triggerPanelText -match 'trinketGlowCheck' -or
    $defaultsText -notmatch 'trigger\.glowWhileActive\s*==\s*true[\s\S]{0,240}aura\.display\.glowWhenActive\s*=\s*true') {
    throw "Trinket active-buff glow is not owned by Display or its legacy trigger setting is not migrated"
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

$mainWindowText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\MainWindow.lua") -Raw
if ($mainWindowText -notmatch 'GetAddOnMetadata' -or
    $mainWindowText -notmatch 'sidebarBuild:SetText\(version') {
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
if ($tocText.IndexOf('Util\Theme.lua') -lt 0 -or
    $tocText.IndexOf('Util\Theme.lua') -gt $tocText.IndexOf('Util\Frames.lua')) {
    throw "Shared UI theme is not loaded before the frame helpers"
}
$themeText = Get-Content -LiteralPath (Join-Path $root "Util\Theme.lua") -Raw
if ($themeText -match 'Set(?:Normal|Pushed|Disabled|Highlight)Texture\(nil\)' -or
    $themeText -notmatch 'HideButtonStateTexture') {
    throw "Dropdown styling must hide template textures without passing nil texture assets"
}
if ($themeText -notmatch 'function Theme\.StyleVisibleDropdownMenus' -or
    $themeText -notmatch 'DropDownList' -or
    $themeText -notmatch 'InstallDropdownMenuSkin') {
    throw "Expanded dropdown menus are not using the shared PopAuras popup skin"
}
if ($framesText -notmatch 'function Frames\.CreateScrollPanel' -or
    $framesText -notmatch 'Theme\.StyleScrollFrame') {
    throw "Shared scroll-panel creation or scrollbar styling is missing"
}
if ($mainWindowText -notmatch 'SetResizable\(true\)' -or
    $mainWindowText -notmatch 'SetResizeBounds\(1100,\s*640,\s*1700,\s*1050\)' -or
    $mainWindowText -notmatch 'ns\.db\.ui\.window\.width' -or
    $mainWindowText -notmatch 'ns\.db\.ui\.window\.height') {
    throw "Main window resizing is missing bounds or persistent dimensions"
}
if ($mainWindowText -notmatch 'removeFromGroupButton' -or
    $mainWindowText -notmatch 'Registry:RemoveFromGroup\(aura\.id\)') {
    throw "Grouped aura removal is not exposed as an editor-header action"
}
if ($mainWindowText -notmatch 'addToGroupDropdown' -or
    $mainWindowText -notmatch 'Loaded Groups' -or
    $mainWindowText -notmatch 'Registry:AssignToGroup\(aura\.id,\s*groupId\)' -or
    $mainWindowText -notmatch 'Theme\.StyleDropdown\(frame\.addToGroupDropdown,\s*"success"\)') {
    throw "Standalone auras do not expose a loaded-first Add to Group header menu"
}
$toolbarText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Toolbar.lua") -Raw
$exportWindowText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\ExportWindow.lua") -Raw
if ($toolbarText -notmatch 'OpenGlobalImport\(\)' -or
    $toolbarText -notmatch 'ExportWindow:ShowAll\(\)' -or
    $toolbarText -notmatch 'CreateTransferIcon\(frame\.importButton,\s*"down"\)' -or
    $toolbarText -notmatch 'CreateTransferIcon\(frame\.exportButton,\s*"up"\)') {
    throw "Global New Aura, Import, and Export actions are not using the compact one-row toolbar flow"
}
if ($mainWindowText -notmatch 'function MainWindow:OpenGlobalImport' -or
    $mainWindowText -notmatch 'editorMode\s*=\s*"global_import"' -or
    $mainWindowText -notmatch 'selectedAuraId\s*=\s*nil') {
    throw "Global Import is still tied to the selected aura"
}
if ($exportWindowText -match 'CopyToClipboard' -or
    $exportWindowText -notmatch 'function ExportWindow:ShowAll' -or
    $exportWindowText -notmatch 'ns\.Export:Encode\(\)' -or
    $exportWindowText -notmatch 'HighlightText\(\)') {
    throw "Export All does not use the standalone restriction-safe copy window"
}
if ($optionsTocText.IndexOf('UI\ExportWindow.lua') -lt 0 -or
    $optionsTocText.IndexOf('UI\ExportWindow.lua') -gt $optionsTocText.IndexOf('UI\Toolbar.lua')) {
    throw "Standalone Export All window is not loaded before the toolbar"
}

$importText = Get-Content -LiteralPath (Join-Path $root "Data\Import.lua") -Raw
$importPanelText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\Panels\ImportExportPanel.lua") -Raw
if ($importText -notmatch 'name = primaryAura' -or
    $importPanelText -notmatch 'Confirm Import' -or
    $importPanelText -notmatch 'Successfully imported' -or
    $importPanelText -match 'Import Add') {
    throw "Import UI does not preview, confirm, and report the named import package"
}

$registryText = Get-Content -LiteralPath (Join-Path $root "Core\Registry.lua") -Raw
$auraTreeText = Get-Content -LiteralPath (Join-Path $optionsRoot "UI\AuraTree.lua") -Raw
if ($registryText -notmatch 'function Registry:CountDescendants' -or
    $auraTreeText -notmatch 'CountDescendants' -or
    $auraTreeText -notmatch 'Deleting the group will permanently delete') {
    throw "Aura deletion does not confirm or warn about nested group descendants"
}
if ($auraTreeText -notmatch '"Loaded Auras"' -or
    $auraTreeText -notmatch '"Not Loaded"' -or
    $auraTreeText -notmatch 'contentAlpha\s*=\s*isLoaded and 1 or 0\.52' -or
    $auraTreeText -notmatch 'topDottedLine:SetShown\(not isLoaded\)') {
    throw "Aura library no longer preserves the distinct loaded and unloaded treatments"
}
if ($auraTreeText -notmatch 'CreateActionIcon\(row\.duplicateButton,\s*"copy"\)' -or
    $auraTreeText -notmatch 'CreateActionIcon\(row\.deleteButton,\s*"trash"\)' -or
    $auraTreeText -notmatch 'and "\+" or "-"') {
    throw "Aura row actions are missing the modern copy, delete, or expand/collapse icon treatment"
}
if ($auraTreeText -match 'ungroupButton') {
    throw "Aura rows still expose the legacy inline remove-from-group control"
}
if ($auraTreeText -notmatch 'function BuildSortedRootAuraIds' -or
    $auraTreeText -notmatch 'loadedGroups' -or
    $auraTreeText -notmatch 'loadedStandalone' -or
    $auraTreeText -notmatch 'table\.sort\(bucket,\s*CompareAuraNames\)') {
    throw "Top-level aura rows are not sorted by load state, group status, and name"
}
if ($auraTreeText -notmatch 'row\.groupIndicator' -or
    $auraTreeText -notmatch '"groupAccent"') {
    throw "Group rows are missing the persistent vertical accent"
}
if ($auraTreeText -notmatch 'row:SetPoint\("TOPLEFT",\s*indent,\s*-yOffset\)' -or
    $auraTreeText -notmatch 'row:SetWidth\(rowWidth\)' -or
    $auraTreeText -notmatch 'row:SetSize\(272,\s*Theme\.layout\.auraRowHeight\)' -or
    $auraTreeText -notmatch 'yOffset\s*=\s*yOffset\s*\+\s*Theme\.layout\.auraRowStep') {
    throw "Aura cards are missing full-row child indentation or compact vertical spacing"
}
if ($displayPanelText -notmatch 'CreateLabeledToggle\(frame\.canvasSection, "Glow When Active"\)' -or
    $displayPanelText -notmatch 'CreateLabeledDropdown\(frame\.canvasSection, "Glow Type"' -or
    $displayPanelText -notmatch 'CreateColorSwatch\(frame\.canvasSection, "Glow Color"' -or
    $displayPanelText -notmatch 'glowWhenActiveCheck:SetPoint\("TOPLEFT", 12, -372\)' -or
    $displayPanelText -notmatch 'reverseCheck:SetPoint\("TOPLEFT", 12, -408\)' -or
    $displayPanelText -notmatch 'selectedActiveGlowStyle ~= "ACTIVE_DURATION"' -or
    $displayPanelText -notmatch 'WireColor\(frame\.activeGlowColorWrap' -or
    $displayPanelText -notmatch 'InvalidateProviderCaches\("spell_cooldown"\)' -or
    $defaultsText -notmatch 'activeGlowColor\s*=') {
    throw "Spell Cooldown bars are missing the progressive active-glow toggle, type, or color controls"
}
if ($barRegionText -notmatch 'GetActiveGlowColor\(aura\)' -or
    $barRegionText -notmatch 'SetActiveBuffBorder\([\s\S]{0,220}GetActiveGlowColor\(aura\)' -or
    $baseRegionText -notmatch 'ApplyBuiltInGlowColor' -or
    $baseRegionText -notmatch 'SetDesaturated\(true\)' -or
    $baseRegionText -notmatch 'activeGlowColor') {
    throw "Configured glow colors no longer reach both inner and outer glow renderers"
}
if ($barRegionText -notmatch 'activeGlowOverride\s*=\s*state\.activeGlowStyle == "OUTER_GLOW" and state\.activeBuff == true' -or
    $barRegionText -notmatch 'state\.activeGlowStyle == "INNER_GLOW" and state\.show and state\.activeBuff == true' -or
    $barRegionText -match 'activeDurationRequested\s*=[\s\S]{0,140}state\.active\s*==\s*true') {
    throw "Active buff appearance is incorrectly gated by the spell cooldown state"
}

$featureInventoryText = Get-Content -LiteralPath (Join-Path $root "Core\FeatureInventory.lua") -Raw
$optionsLoaderText = Get-Content -LiteralPath (Join-Path $root "Core\OptionsLoader.lua") -Raw
$cooldownManagerText = Get-Content -LiteralPath (Join-Path $root "Core\CooldownManager.lua") -Raw
$spellAlertsText = Get-Content -LiteralPath (Join-Path $root "Core\BlizzardSpellAlerts.lua") -Raw
$interruptTrackerText = Get-Content -LiteralPath (Join-Path $root "Core\InterruptTracker.lua") -Raw
$shareLinksText = Get-Content -LiteralPath (Join-Path $root "Core\ShareLinks.lua") -Raw
$pkgmetaText = Get-Content -LiteralPath (Join-Path $root ".pkgmeta") -Raw
if ($featureInventoryText -notmatch 'function FeatureInventory:BuildSnapshot' -or
    $featureInventoryText -notmatch 'aura\.enabled\s*~=\s*false' -or
    $featureInventoryText -notmatch 'function FeatureInventory:ScheduleRebuild' -or
    $registryText -notmatch 'FeatureInventory:ScheduleRebuild') {
    throw "Saved configuration is not maintaining a coalesced, enabled-feature demand inventory"
}
if ($eventsText -notmatch 'function Events:RebuildSubscriptions' -or
    $eventsText -notmatch 'frame:UnregisterEvent\(event\)' -or
    $eventsText -notmatch 'snapshot\.providerTypes' -or
    $eventsText -notmatch 'snapshot\.loadEvents') {
    throw "The central event router is no longer demand-driven"
}
if ($cooldownManagerText -notmatch 'function Manager:EnsureActive' -or
    $spellAlertsText -notmatch 'function Manager:EnsureActive' -or
    $interruptTrackerText -notmatch 'function Tracker:EnsureInitialized' -or
    $featureInventoryText -notmatch 'NativeAuras:EnsureActive') {
    throw "An optional runtime manager is missing its activation-only lifecycle"
}
if ($interruptTrackerText -notmatch 'ArmCorrelationDriver\s*=\s*function' -or
    $interruptTrackerText -notmatch 'selfFrame:SetScript\("OnUpdate",\s*nil\)' -or
    $shareLinksText -notmatch 'sendPump:Show\(\)' -or
    $shareLinksText -notmatch 'frame:Hide\(\)') {
    throw "A transient OnUpdate driver no longer self-disarms"
}
if ($loadPanelText -notmatch 'SetInstanceInfoEventsEnabled\(true\)' -or
    $loadPanelText -notmatch 'SetInstanceInfoEventsEnabled\(false\)' -or
    $loadPanelText -notmatch 'UnregisterAllEvents\(\)') {
    throw "The Load editor panel keeps instance events registered while hidden"
}
if ($optionsLoaderText -notmatch 'C_AddOns\.LoadAddOn,\s*"PopAuras_Options"' -or
    $optionsLoaderText -notmatch 'PLAYER_REGEN_ENABLED' -or
    $pkgmetaText -notmatch '(?m)^\s*PopAuras/Options:\s*PopAuras_Options\s*$' -or
    $tocText -match '(?m)^Util\\SoundPicker\.lua\s*$') {
    throw "The editor is not packaged and loaded as a combat-safe companion addon"
}
if ($optionsTocText.IndexOf('Bootstrap.lua') -lt 0 -or
    $optionsTocText.IndexOf('Bootstrap.lua') -gt $optionsTocText.IndexOf('EditorDesign.lua') -or
    $optionsTocText.IndexOf('Ready.lua') -lt $optionsTocText.IndexOf('UI\MainWindow.lua')) {
    throw "PopAuras_Options namespace or readiness files are in an unsafe load order"
}
if ($themeText -notmatch 'Theme\.typography' -or
    $themeText -notmatch 'Theme\.layout' -or
    $themeText -notmatch 'function Theme\.ApplyTypography' -or
    $themeText -notmatch 'function Theme\.PixelSetSize') {
    throw "The shared editor typography, layout, or pixel-alignment tokens are missing"
}
foreach ($builder in @('CreateSectionCard', 'CreateLabeledInput', 'CreateLabeledDropdown', 'CreateColorSwatch', 'CreateFieldRow', 'CreateTwoColumnRow')) {
    if ($editorDesignText -notmatch ("function Frames\." + [regex]::Escape($builder))) {
        throw "Editor design builder '$builder' is missing"
    }
}
$directEditorFontCall = Get-ChildItem -LiteralPath (Join-Path $optionsRoot "UI") -Recurse -Filter *.lua |
    Select-String -Pattern 'Fonts\.Apply|:SetFont\(' | Select-Object -First 1
if ($directEditorFontCall) {
    throw "Editor typography bypasses Theme.ApplyTypography at $($directEditorFontCall.Path):$($directEditorFontCall.LineNumber)"
}

function Get-TocLuaByteCount {
    param([string]$TocPath, [string]$BasePath)
    $total = 0L
    Get-Content -LiteralPath $TocPath | ForEach-Object {
        $entry = $_.Trim()
        if ($entry -match '\.lua$') {
            $total += (Get-Item -LiteralPath (Join-Path $BasePath $entry)).Length
        }
    }
    return $total
}
$baseLuaBytes = Get-TocLuaByteCount -TocPath $toc -BasePath $root
$optionsLuaBytes = Get-TocLuaByteCount -TocPath $optionsToc -BasePath $optionsRoot
if (($optionsLuaBytes / ($baseLuaBytes + $optionsLuaBytes)) -lt 0.405) {
    throw "The load-on-demand editor split defers less than the audited 40.5% startup target"
}

& (Join-Path $root "deploy.ps1") -WhatIf

Write-Host "PopAuras static verification passed." -ForegroundColor Green
