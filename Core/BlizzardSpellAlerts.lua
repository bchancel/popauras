local _, ns = ...

local Manager = {}
ns.BlizzardSpellAlerts = Manager

Manager.suppressedSpellIDs = Manager.suppressedSpellIDs or {}

local ACTION_BUTTON_PREFIXES = {
  { prefix = "ActionButton", count = 12 },
  { prefix = "MultiBarBottomLeftButton", count = 12 },
  { prefix = "MultiBarBottomRightButton", count = 12 },
  { prefix = "MultiBarRightButton", count = 12 },
  { prefix = "MultiBarLeftButton", count = 12 },
  { prefix = "OverrideActionBarButton", count = 6 },
  { prefix = "PossessButton", count = 2 },
  { prefix = "PetActionButton", count = 10 },
  { prefix = "StanceButton", count = 10 },
}

local function SafeSpellID(value)
  if value == nil then
    return 0
  end
  if issecretvalue and issecretvalue(value) then
    return 0
  end
  if type(value) == "number" then
    return value
  end
  return tonumber(value or 0) or 0
end

local function ResolveConfiguredSpellID(display)
  if type(display) ~= "table" then
    return 0
  end

  local spellID = SafeSpellID(display.blizzardSpellAlertSpellId)
  if spellID ~= 0 then
    return spellID
  end

  local spellName = ns.util.Spells and ns.util.Spells.NormalizeText
    and ns.util.Spells:NormalizeText(display.blizzardSpellAlertSpellName)
    or tostring(display.blizzardSpellAlertSpellName or "")
  if spellName == "" or not (ns.util.Spells and ns.util.Spells.ResolveSpellReference) then
    return 0
  end

  local resolvedSpellID, resolvedSpellName = ns.util.Spells:ResolveSpellReference(spellName)
  resolvedSpellID = SafeSpellID(resolvedSpellID)
  if resolvedSpellID > 0 then
    display.blizzardSpellAlertSpellId = resolvedSpellID
    if type(resolvedSpellName) == "string" and resolvedSpellName ~= "" then
      display.blizzardSpellAlertSpellName = resolvedSpellName
    end
  end
  return resolvedSpellID
end

local function LearnSpellID(spellID)
  spellID = SafeSpellID(spellID)
  if spellID <= 0 or not (ns.util.Spells and ns.util.Spells.RememberResolvedSpell) then
    return
  end

  local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil
  if type(spellName) == "string" and spellName ~= "" then
    ns.util.Spells:RememberResolvedSpell(spellID, spellName)
  end
end

local function LearnOverlayNode(node, visited)
  if not node or visited[node] then
    return
  end
  visited[node] = true

  LearnSpellID(node.spellID or node.spellId)

  if node.GetChildren then
    for _, child in ipairs({ node:GetChildren() }) do
      LearnOverlayNode(child, visited)
    end
  end
end

local function LearnVisibleOverlays()
  local frame = _G.SpellActivationOverlayFrame
  if not frame then
    return
  end

  local visited = {}
  if type(frame.activeOverlays) == "table" then
    for _, overlay in pairs(frame.activeOverlays) do
      LearnOverlayNode(overlay, visited)
    end
  end
  if type(frame.overlays) == "table" then
    for _, overlay in pairs(frame.overlays) do
      LearnOverlayNode(overlay, visited)
    end
  end
  LearnOverlayNode(frame, visited)
end

local function VisitOverlayNode(node, spellID, visited)
  if not node or visited[node] then
    return false
  end
  visited[node] = true

  local hidden = false
  local nodeSpellID = SafeSpellID(node.spellID or node.spellId)
  if nodeSpellID == spellID and node.Hide then
    pcall(node.Hide, node)
    hidden = true
  end

  if node.GetChildren then
    for _, child in ipairs({ node:GetChildren() }) do
      if VisitOverlayNode(child, spellID, visited) then
        hidden = true
      end
    end
  end

  return hidden
end

local function HideSpellActivationOverlay(spellID)
  spellID = SafeSpellID(spellID)
  if spellID == 0 then
    return false
  end

  local frame = _G.SpellActivationOverlayFrame
  local hidden = false

  if SpellActivationOverlay_HideOverlays then
    local ok = pcall(SpellActivationOverlay_HideOverlays, frame, spellID)
    if not ok then
      ok = pcall(SpellActivationOverlay_HideOverlays, spellID)
    end
    hidden = ok or hidden
  end

  if frame then
    local visited = {}
    if type(frame.activeOverlays) == "table" then
      for _, overlay in pairs(frame.activeOverlays) do
        if VisitOverlayNode(overlay, spellID, visited) then
          hidden = true
        end
      end
    end
    if type(frame.overlays) == "table" then
      for _, overlay in pairs(frame.overlays) do
        if VisitOverlayNode(overlay, spellID, visited) then
          hidden = true
        end
      end
    end
    if VisitOverlayNode(frame, spellID, visited) then
      hidden = true
    end
  end

  return hidden
end

local function IterateActionButtons(callback)
  for _, entry in ipairs(ACTION_BUTTON_PREFIXES) do
    for index = 1, entry.count do
      local button = _G[entry.prefix .. tostring(index)]
      if button then
        callback(button)
      end
    end
  end
end

local function ResolveActionButtonSpellID(button)
  if not button then
    return 0
  end

  local directSpellID = SafeSpellID(button.spellID or button.spellId)
  if directSpellID > 0 then
    return directSpellID
  end

  local actionSlot = SafeSpellID(button.action)
  if actionSlot > 0 and GetActionInfo then
    local actionType, actionID = GetActionInfo(actionSlot)
    if actionType == "spell" or actionType == "companion" then
      return SafeSpellID(actionID)
    end
  end

  return 0
end

local function HideActionButtonGlows(spellID)
  spellID = SafeSpellID(spellID)
  if spellID <= 0 or not ActionButton_HideOverlayGlow then
    return false
  end

  local hidden = false
  IterateActionButtons(function(button)
    if ResolveActionButtonSpellID(button) == spellID and button.spellActivationAlert then
      pcall(ActionButton_HideOverlayGlow, button)
      hidden = true
    end
  end)

  return hidden
end

function Manager:SuppressSpellAlert(spellID)
  spellID = SafeSpellID(spellID)
  if spellID == 0 then
    return false
  end

  LearnSpellID(spellID)

  local hiddenOverlay = HideSpellActivationOverlay(spellID)
  local hiddenGlow = HideActionButtonGlows(spellID)
  return hiddenOverlay or hiddenGlow
end

function Manager:GetDesiredSpellIDs()
  local desired = {}

  if not (ns.Registry and ns.Registry.GetFlatOrder and ns.Registry.GetAura and ns.LoadEvaluator and ns.LoadEvaluator.Matches) then
    return desired
  end

  for _, auraId in ipairs(ns.Registry:GetFlatOrder() or {}) do
    local aura = ns.Registry:GetAura(auraId)
    if aura and aura.enabled ~= false and aura.display and aura.display.hideBlizzardSpellAlert == true
        and ns.LoadEvaluator:Matches(aura) == true then
      local spellID = ResolveConfiguredSpellID(aura.display)
      if spellID ~= 0 then
        desired[spellID] = true
      end
    end
  end

  return desired
end

function Manager:QueueSuppress(spellID)
  spellID = SafeSpellID(spellID)
  if spellID == 0 then
    return
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if self.suppressedSpellIDs and self.suppressedSpellIDs[spellID] then
        self:SuppressSpellAlert(spellID)
      end
    end)
    return
  end

  if self.suppressedSpellIDs and self.suppressedSpellIDs[spellID] then
    self:SuppressSpellAlert(spellID)
  end
end

function Manager:Sync()
  LearnVisibleOverlays()
  self.suppressedSpellIDs = self:GetDesiredSpellIDs()
  for spellID in pairs(self.suppressedSpellIDs or {}) do
    self:SuppressSpellAlert(spellID)
  end
end

function Manager:Initialize()
  self.suppressedSpellIDs = self.suppressedSpellIDs or {}
  if self.eventFrame then
    return
  end

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
  frame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
  frame:SetScript("OnEvent", function(_, _, spellID)
    spellID = SafeSpellID(spellID)
    if spellID ~= 0 then
      LearnSpellID(spellID)
      self.suppressedSpellIDs = self:GetDesiredSpellIDs()
    end
    if spellID ~= 0 and self.suppressedSpellIDs and self.suppressedSpellIDs[spellID] then
      self:QueueSuppress(spellID)
    end
  end)
  self.eventFrame = frame
end
