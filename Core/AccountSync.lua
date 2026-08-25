local _, ns = ...

local AccountSync = {}
ns.AccountSync = AccountSync

local Strings = ns.util.Strings
local Tables = ns.util.Tables

local ADDON_PREFIX = "PopAurasSync"
local PROTOCOL_VERSION = 2
local SESSION_TTL = 600
local REQUEST_POPUP_KEY = "POPAURAS_ACCOUNT_SYNC_REQUEST"

AccountSync.sessions = AccountSync.sessions or {}

local function WriteChatLine(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(message)
  else
    print(message)
  end
end

local function NormalizePlayerName(value)
  if value ~= nil and Strings and Strings.IsSafeString and not Strings.IsSafeString(value) then
    return ""
  end
  value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return ""
  end
  local name, realm = value:match("^([^%-]+)%-(.+)$")
  if not name then
    name = value
    realm = tostring(GetRealmName and GetRealmName() or "")
  end
  realm = tostring(realm or ""):gsub("%s+", "")
  name = tostring(name or ""):gsub("%s+", "")
  if name == "" then
    return ""
  end
  return realm ~= "" and string.format("%s-%s", name, realm) or name
end

local function PlayerKey(value)
  return NormalizePlayerName(value):lower()
end

local function GetPlayerFullName()
  local name, realm
  if Strings and Strings.GetSafeUnitNameParts then
    name, realm = Strings.GetSafeUnitNameParts("player")
  end
  if not name then
    return ""
  end
  return NormalizePlayerName(string.format("%s-%s", name, realm or ""))
end

local function SendWhisper(target, message)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return false
  end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, ADDON_PREFIX, message, "WHISPER", target)
  return ok == true and result == 0
end

local function NewSessionId()
  return string.format("%d%04d", time(), math.random(1000, 9999))
end

local function GetIgnoredPlayers()
  ns.db.sharing = type(ns.db.sharing) == "table" and ns.db.sharing or {}
  ns.db.sharing.ignoredPlayers = type(ns.db.sharing.ignoredPlayers) == "table"
    and ns.db.sharing.ignoredPlayers or {}
  return ns.db.sharing.ignoredPlayers
end

function AccountSync:NormalizePlayerName(value)
  return NormalizePlayerName(value)
end

function AccountSync:IsIgnored(value)
  local key = PlayerKey(value)
  return key ~= "" and GetIgnoredPlayers()[key] == true
end

function AccountSync:IgnorePlayer(value)
  local normalized = NormalizePlayerName(value)
  local key = normalized:lower()
  if key == "" then
    return false, "Enter a player as Name-Realm."
  end
  if key == PlayerKey(GetPlayerFullName()) then
    return false, "You cannot ignore your own character."
  end
  GetIgnoredPlayers()[key] = true
  return true, normalized
end

function AccountSync:UnignorePlayer(value)
  local normalized = NormalizePlayerName(value)
  local key = normalized:lower()
  if key == "" then
    return false, "Enter a player as Name-Realm."
  end
  local existed = GetIgnoredPlayers()[key] == true
  GetIgnoredPlayers()[key] = nil
  return existed, normalized
end

function AccountSync:GetIgnoredPlayerNames()
  local names = {}
  for name, ignored in pairs(GetIgnoredPlayers()) do
    if ignored == true then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

function AccountSync:IsSyncTransferKey(shareKey)
  return type(shareKey) == "string" and shareKey:match("^SYNC[MPR]_[%w]+") ~= nil
end

local function ManifestAuraName(aura, auraId)
  return tostring((aura and aura.n) or auraId)
end

local function BuildPath(manifest, auraId)
  local parts = {}
  local seen = {}
  local cursorId = auraId
  while cursorId and not seen[cursorId] do
    seen[cursorId] = true
    local aura = manifest and manifest.auras and manifest.auras[cursorId] or nil
    if not aura then
      break
    end
    table.insert(parts, 1, ManifestAuraName(aura, cursorId))
    cursorId = aura.p
  end
  return table.concat(parts, " > ")
end

local function BuildEntry(manifest, auraId)
  local aura = manifest and manifest.auras and manifest.auras[auraId] or {}
  return {
    id = auraId,
    name = ManifestAuraName(aura, auraId),
    kind = tostring(aura.k or "aura"),
    parentId = aura.p,
    path = BuildPath(manifest, auraId),
  }
end

function AccountSync:BuildManifest()
  local payload = ns.Export:BuildPayload()
  local manifest = {
    syncManifest = PROTOCOL_VERSION,
    auras = {},
    order = {},
  }
  for _, auraId in ipairs(payload.order or {}) do
    local aura = payload.auras and payload.auras[auraId] or nil
    if aura then
      manifest.auras[auraId] = {
        n = tostring(aura.name or auraId),
        k = tostring(aura.kind or "aura"),
        p = aura.parentId,
        h = ns.Export:GetPayloadAuraFingerprint(payload, auraId),
      }
      manifest.order[#manifest.order + 1] = auraId
    end
  end
  return manifest
end

function AccountSync:BuildComparison(session)
  if not session or type(session.remoteManifest) ~= "table" then
    return nil
  end
  local localManifest = self:BuildManifest()
  local remoteManifest = session.remoteManifest
  local comparison = {
    missingLocal = {},
    missingRemote = {},
    changed = {},
  }

  for _, auraId in ipairs(remoteManifest.order or {}) do
    local remoteAura = remoteManifest.auras and remoteManifest.auras[auraId] or nil
    local localAura = localManifest.auras and localManifest.auras[auraId] or nil
    if remoteAura then
      if not localAura then
        comparison.missingLocal[#comparison.missingLocal + 1] = BuildEntry(remoteManifest, auraId)
      elseif tostring(localAura.h or "") ~= tostring(remoteAura.h or "") then
        comparison.changed[#comparison.changed + 1] = BuildEntry(remoteManifest, auraId)
      end
    end
  end

  for _, auraId in ipairs(localManifest.order or {}) do
    if localManifest.auras and localManifest.auras[auraId]
        and not (remoteManifest.auras and remoteManifest.auras[auraId]) then
      comparison.missingRemote[#comparison.missingRemote + 1] = BuildEntry(localManifest, auraId)
    end
  end

  session.localManifest = localManifest
  session.comparison = comparison
  return comparison
end

function AccountSync:GetSession(sessionId)
  local session = self.sessions[sessionId]
  if session and (session.expiresAt or 0) >= GetTime() then
    return session
  end
  self.sessions[sessionId] = nil
  return nil
end

function AccountSync:OpenComparison(session)
  if not session then
    return
  end
  local loaded, reason = ns.OptionsLoader:EnsureLoaded()
  if not loaded then
    WriteChatLine(string.format("|cffff4444PopAuras:|r Could not open account sync: %s", tostring(reason)))
    return
  end
  if ns.ui and ns.ui.AccountSyncWindow and ns.ui.AccountSyncWindow.ShowSession then
    ns.ui.AccountSyncWindow:ShowSession(session)
  end
end

local function QueueSyncPayload(target, shareKey, payload, label)
  local encoded = ns.Export:EncodePayload(payload)
  if type(encoded) ~= "string" or encoded == "" then
    return false
  end
  return ns.ShareLinks:QueueOutgoingTransfer(target, shareKey, encoded, label)
end

function AccountSync:SendManifest(session)
  if not session or self:IsIgnored(session.target) then
    return false
  end
  session.expiresAt = GetTime() + SESSION_TTL
  return QueueSyncPayload(
    session.target,
    "SYNCM_" .. tostring(session.id),
    self:BuildManifest(),
    "Account Sync Manifest")
end

function AccountSync:RequestSync(targetText)
  if InCombatLockdown and InCombatLockdown() then
    return false, "Account sync is only available out of combat."
  end
  local target = NormalizePlayerName(targetText)
  if target == "" then
    return false, "Enter a player as Name-Realm."
  end
  if PlayerKey(target) == PlayerKey(GetPlayerFullName()) then
    return false, "Choose another character."
  end
  if self:IsIgnored(target) then
    return false, target .. " is on your PopAuras ignore list."
  end

  local sessionId = NewSessionId()
  self.sessions[sessionId] = {
    id = sessionId,
    target = target,
    initiator = true,
    status = "requested",
    expiresAt = GetTime() + SESSION_TTL,
    pendingRequests = {},
  }
  if not SendWhisper(target, string.format("REQ\t%s\t%d", sessionId, PROTOCOL_VERSION)) then
    self.sessions[sessionId] = nil
    return false, "Unable to send the account-sync request."
  end
  WriteChatLine(string.format("|cff66ccffPopAuras:|r Account-sync request sent to %s.", target))
  return true, sessionId
end

function AccountSync:OpenTargetPrompt()
  if InCombatLockdown and InCombatLockdown() then
    return false, "Account sync is only available out of combat."
  end
  local loaded, reason = ns.OptionsLoader:EnsureLoaded()
  if not loaded then
    return false, reason
  end
  if not (ns.ui and ns.ui.AccountSyncWindow and ns.ui.AccountSyncWindow.ShowTargetPrompt) then
    return false, "Account-sync window is unavailable."
  end
  ns.ui.AccountSyncWindow:ShowTargetPrompt()
  return true
end

function AccountSync:AcceptRequest(requestKey)
  local session = requestKey and self.sessions[requestKey] or nil
  if not session then
    return
  end
  session.status = "accepted"
  session.pendingRequests = session.pendingRequests or {}
  session.expiresAt = GetTime() + SESSION_TTL
  SendWhisper(session.target, string.format("YES\t%s\t%d", session.id, PROTOCOL_VERSION))
  self:SendManifest(session)
end

function AccountSync:DeclineRequest(requestKey)
  local session = requestKey and self.sessions[requestKey] or nil
  if not session then
    return
  end
  SendWhisper(session.target, "NO\t" .. tostring(session.id))
  self.sessions[requestKey] = nil
end

function AccountSync:IgnoreRequest(requestKey)
  local session = requestKey and self.sessions[requestKey] or nil
  if not session then
    return
  end
  self:IgnorePlayer(session.target)
  SendWhisper(session.target, "NO\t" .. tostring(session.id))
  self.sessions[requestKey] = nil
  WriteChatLine(string.format("|cff66ccffPopAuras:|r Ignoring all shares from %s.", session.target))
end

function AccountSync:ShowRequestPrompt(session)
  if not StaticPopupDialogs then
    self:DeclineRequest(session and session.id)
    return
  end
  StaticPopup_Show(REQUEST_POPUP_KEY, tostring(session.target), nil, session.id)
end

local function AddDescendants(payload, auraId, selected)
  if selected[auraId] then
    return
  end
  selected[auraId] = true
  local aura = payload.auras and payload.auras[auraId] or nil
  for _, childId in ipairs(aura and aura.children or {}) do
    AddDescendants(payload, childId, selected)
  end
end

local function AddAncestors(payload, auraId, selected)
  local aura = payload.auras and payload.auras[auraId] or nil
  local parentId = aura and aura.parentId or nil
  while parentId and payload.auras and payload.auras[parentId] do
    selected[parentId] = true
    parentId = payload.auras[parentId].parentId
  end
end

local function BuildSelectedPayload(requestedIds)
  local payload = ns.Export:BuildPayload()
  local selected = {}
  for _, auraId in ipairs(requestedIds or {}) do
    if payload.auras and payload.auras[auraId] then
      AddDescendants(payload, auraId, selected)
      AddAncestors(payload, auraId, selected)
    end
  end

  local subset = {
    version = payload.version or ns.Constants.EXPORT_VERSION,
    exportedAt = time(),
    auras = {},
    order = {},
  }
  for _, auraId in ipairs(payload.order or {}) do
    if selected[auraId] and payload.auras[auraId] then
      local copy = Tables.DeepCopy(payload.auras[auraId])
      if type(copy.children) == "table" then
        local includedChildren = {}
        for _, childId in ipairs(copy.children) do
          if selected[childId] then
            includedChildren[#includedChildren + 1] = childId
          end
        end
        copy.children = includedChildren
      end
      subset.auras[auraId] = copy
      subset.order[#subset.order + 1] = auraId
    end
  end
  return subset
end

function AccountSync:HandleSnapshot(sender, shareKey, encoded)
  local transferType, sessionId, requestId =
    tostring(shareKey or ""):match("^SYNC([MPR])_([%w]+)_?([%w]*)$")
  local session = sessionId and self:GetSession(sessionId) or nil
  if not transferType or not session
      or PlayerKey(session.target) ~= PlayerKey(sender) or self:IsIgnored(sender) then
    return true
  end

  local payload, err = ns.Import:Decode(encoded)
  if not payload then
    WriteChatLine(string.format("|cffff4444PopAuras:|r Could not read %s's sync data: %s",
      tostring(sender), tostring(err)))
    return true
  end
  session.expiresAt = GetTime() + SESSION_TTL

  if transferType == "M" then
    if tonumber(payload.syncManifest) ~= PROTOCOL_VERSION
        or type(payload.auras) ~= "table" or type(payload.order) ~= "table" then
      return true
    end
    session.remoteManifest = payload
    session.status = "ready"
    self:BuildComparison(session)
    self:OpenComparison(session)
    return true
  end

  if transferType == "R" then
    if tonumber(payload.syncRequest) ~= PROTOCOL_VERSION or type(payload.requestedIds) ~= "table" then
      return true
    end
    local selectedPayload = BuildSelectedPayload(payload.requestedIds)
    QueueSyncPayload(
      session.target,
      string.format("SYNCP_%s_%s", session.id, tostring(requestId)),
      selectedPayload,
      "Selected Account Sync Auras")
    return true
  end

  session.pendingRequests = session.pendingRequests or {}
  if requestId == "" or not session.pendingRequests[requestId] then
    return true
  end
  session.pendingRequests[requestId] = nil
  local missingPayload = {
    version = payload.version or ns.Constants.EXPORT_VERSION,
    exportedAt = time(),
    auras = {},
    order = {},
  }
  for _, auraId in ipairs(payload.order or {}) do
    if payload.auras and payload.auras[auraId] and not ns.Registry:GetAura(auraId) then
      local copy = Tables.DeepCopy(payload.auras[auraId])
      if type(copy.children) == "table" then
        local missingChildren = {}
        for _, childId in ipairs(copy.children) do
          if payload.auras[childId] and not ns.Registry:GetAura(childId) then
            missingChildren[#missingChildren + 1] = childId
          end
        end
        copy.children = missingChildren
      end
      missingPayload.auras[auraId] = copy
      missingPayload.order[#missingPayload.order + 1] = auraId
    end
  end
  local importedCount = #missingPayload.order
  if importedCount == 0 then
    session.lastStatus = "Those auras are already present."
    self:BuildComparison(session)
    self:OpenComparison(session)
    return true
  end
  local ok, result = ns.Import:Apply(ns.Export:EncodePayload(missingPayload), false)
  if not ok then
    WriteChatLine(string.format("|cffff4444PopAuras:|r Selected sync import failed: %s", tostring(result)))
    return true
  end
  session.lastStatus = string.format("Imported %d aura%s.", importedCount, importedCount == 1 and "" or "s")
  self:BuildComparison(session)
  self:OpenComparison(session)
  self:SendManifest(session)
  return true
end

function AccountSync:ImportSelected(sessionId, requestedIds)
  if InCombatLockdown and InCombatLockdown() then
    return false, "Sync imports are only available out of combat."
  end
  local session = self:GetSession(sessionId)
  if not session or type(session.remoteManifest) ~= "table" then
    return false, "The account-sync session expired."
  end

  local ids = {}
  for _, auraId in ipairs(session.remoteManifest.order or {}) do
    if requestedIds and requestedIds[auraId] == true and not ns.Registry:GetAura(auraId) then
      ids[#ids + 1] = auraId
    end
  end
  if #ids == 0 then
    return false, "Select at least one missing aura."
  end

  local requestId = NewSessionId()
  session.pendingRequests = session.pendingRequests or {}
  session.pendingRequests[requestId] = true
  session.lastStatus = string.format("Requesting %d selected aura%s...", #ids, #ids == 1 and "" or "s")
  local queued = QueueSyncPayload(
    session.target,
    string.format("SYNCR_%s_%s", session.id, requestId),
    {
      syncRequest = PROTOCOL_VERSION,
      requestedIds = ids,
    },
    "Account Sync Selection")
  if not queued then
    session.pendingRequests[requestId] = nil
    return false, "Unable to request the selected auras."
  end
  return true, #ids
end
function AccountSync:HandleAddonMessage(message, sender)
  if type(message) ~= "string" or message == "" then
    return
  end
  sender = NormalizePlayerName(sender)
  local command, payload = message:match("^([^\t]+)\t?(.*)$")
  if command == "REQ" then
    if self:IsIgnored(sender) then
      return
    end
    local sessionId, versionText = payload:match("^([^\t]+)\t?(.*)$")
    if not sessionId or tonumber(versionText) ~= PROTOCOL_VERSION then
      return
    end
    local session = {
      id = sessionId,
      target = sender,
      initiator = false,
      status = "pending",
      expiresAt = GetTime() + SESSION_TTL,
      pendingRequests = {},
    }
    self.sessions[sessionId] = session
    self:ShowRequestPrompt(session)
    return
  end

  local sessionId = payload:match("^([^\t]+)")
  local session = sessionId and self:GetSession(sessionId) or nil
  if not session or PlayerKey(session.target) ~= PlayerKey(sender) then
    return
  end
  if command == "YES" then
    session.status = "accepted"
    self:SendManifest(session)
  elseif command == "NO" then
    self.sessions[sessionId] = nil
    WriteChatLine(string.format("|cff66ccffPopAuras:|r %s declined the account-sync request.", sender))
  end
end

function AccountSync:Initialize()
  if self.initialized then
    return
  end
  self.initialized = true
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
  end
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == ADDON_PREFIX then
      AccountSync:HandleAddonMessage(message, sender)
    end
  end)
  self.frame = frame

  if StaticPopupDialogs and not StaticPopupDialogs[REQUEST_POPUP_KEY] then
    StaticPopupDialogs[REQUEST_POPUP_KEY] = {
      text = "%s would like to initiate a PopAuras account sync.",
      button1 = YES,
      button2 = NO,
      button3 = "Ignore",
      OnAccept = function(popup)
        AccountSync:AcceptRequest(popup and popup.data)
      end,
      OnCancel = function(popup)
        AccountSync:DeclineRequest(popup and popup.data)
      end,
      OnAlt = function(popup)
        AccountSync:IgnoreRequest(popup and popup.data)
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end
end
