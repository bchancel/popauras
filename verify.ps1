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
if ($tocText -notmatch '(?m)^## Version:\s*12\.1\.0\s*$') {
    throw "PopAuras.toc version is not aligned to 12.1.0"
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
if ($spellCooldownText -notmatch 'UPDATE_OVERRIDE_ACTIONBAR' -or $spellCooldownText -notmatch 'SPELL_OVERRIDE_UPDATED') {
    throw "Spell cooldown provider does not cover both 12.0 and 12.1 override events"
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

$spellsText = Get-Content -LiteralPath (Join-Path $root "Util\Spells.lua") -Raw
if ($spellsText -notmatch '\[203720\]\s*=\s*\{\s*203819\s*\}') {
    throw "Demon Spikes ability-to-aura migration alias is missing"
}
if ($spellsText -notmatch '\[8921\]\s*=\s*\{\s*164812\s*\}') {
    throw "Moonfire cast-to-debuff migration alias is missing"
}
if ($spellsText -notmatch '\[155625\]\s*=\s*\{\s*164812\s*\}') {
    throw "Cat Form Moonfire cast-to-debuff migration alias is missing"
}
if ($spellsText -notmatch '\[1252871\]\s*=\s*\{\s*164812\s*\}') {
    throw "Red Moon-to-Moonfire debuff migration alias is missing"
}
if ($spellsText -notmatch '\[93402\]\s*=\s*\{\s*164815\s*\}') {
    throw "Sunfire cast-to-debuff migration alias is missing"
}
if ($spellsText -notmatch '\[1822\]\s*=\s*\{\s*155722\s*\}') {
    throw "Rake cast-to-debuff migration alias is missing"
}
if ($spellsText -notmatch '\[77758\]\s*=\s*\{\s*192090\s*\}') {
    throw "Thrash cast-to-debuff migration alias is missing"
}
if ($spellsText -notmatch '\[202345\]\s*=\s*\{\s*279709\s*\}') {
    throw "Starlord talent-to-buff migration alias is missing"
}
if ($spellsText -notmatch 'local aliases = AURA_SPELL_ID_ALIASES\[spellID\][\s\S]*?if not aliases then[\s\S]*?return \{ spellID \}') {
    throw "Known aura aliases still mix cast IDs into Blizzard's exact aura candidate filter"
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
if ($cooldownManagerText -notmatch 'function Manager:FindAuraDisplaySource' -or
    $cooldownManagerText -notmatch 'viewer ~= _G\.BuffBarCooldownViewer') {
    throw "CDM aura source selection is not restricted to tracked buff-bar frames"
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

& (Join-Path $root "deploy.ps1") -WhatIf

Write-Host "PopAuras static verification passed." -ForegroundColor Green
