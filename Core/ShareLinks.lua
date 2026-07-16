local _, ns = ...

local ShareLinks = {}
ns.ShareLinks = ShareLinks

local Strings = ns.util.Strings
local Frames = ns.util.Frames

local LINK_TYPE = "popauras"
local ADDON_PREFIX = "PopAurasShare"
local CHUNK_SIZE = 190
local CACHE_TTL = 600
local OFFER_POPUP_KEY = "POPAURAS_SHARE_OFFER"
local SEND_INTERVAL = 0.02

ShareLinks.outgoing = ShareLinks.outgoing or {}
ShareLinks.incoming = ShareLinks.incoming or {}
ShareLinks.pending = ShareLinks.pending or {}
ShareLinks.offers = ShareLinks.offers or {}
ShareLinks.sendQueue = ShareLinks.sendQueue or {}

local function DebugLog(message)
  if ns.Debug and ns.Debug.Log then
    ns.Debug:Log("Share", message)
  end
end

local function WriteChatLine(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(message)
    return
  end
  print(message)
end

local function GetPlayerFullName()
  local name, realm = nil, nil
  if Strings and Strings.GetSafeUnitNameParts then
    name, realm = Strings.GetSafeUnitNameParts("player")
  end
  if not name then
    return "Unknown"
  end
  realm = type(realm) == "string" and realm:gsub("%s+", "") or ""
  if realm ~= "" then
    return string.format("%s-%s", name, realm)
  end
  return name
end

local function NormalizePlayerName(value)
  if value ~= nil and Strings and Strings.IsSafeString and not Strings.IsSafeString(value) then
    return ""
  end
  local playerRealm = tostring(GetRealmName and GetRealmName() or ""):gsub("%s+", "")
  local name, realm = tostring(value or ""):match("^([^%-]+)%-(.+)$")
  if name and realm then
    return string.format("%s-%s", name, tostring(realm):gsub("%s+", ""))
  end
  if tostring(value or "") ~= "" and playerRealm ~= "" then
    return string.format("%s-%s", tostring(value), playerRealm)
  end
  return tostring(value or "")
end

local function SanitizeLinkLabel(value)
  local label = tostring(value or "Aura")
  label = label:gsub("|", ""):gsub("[%c%[%]]", "")
  if #label > 40 then
    label = label:sub(1, 37) .. "..."
  end
  if label == "" then
    label = "Aura"
  end
  return label
end

local function BuildShareKey()
  return string.format("%d%04d", time(), math.random(1000, 9999))
end

local function BuildLink(owner, shareKey, auraName)
  return string.format("|cff66ccff|H%s:%s:%s|h[PopAuras-%s]|h|r", LINK_TYPE, tostring(owner), tostring(shareKey), SanitizeLinkLabel(auraName))
end

local function BuildReceiveKey(owner, shareKey)
  return string.format("%s:%s", NormalizePlayerName(owner), tostring(shareKey or ""))
end

local function SendAddonWhisper(target, message)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return false
  end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, ADDON_PREFIX, message, "WHISPER", target)
  return ok == true and result == 0
end

local function PruneCacheTable(cache)
  local now = GetTime()
  for key, entry in pairs(cache or {}) do
    if type(entry) ~= "table" or (entry.expiresAt and entry.expiresAt < now) then
      cache[key] = nil
    end
  end
end

local function CountReceivedParts(parts, total)
  local count = 0
  for index = 1, total do
    if parts and parts[index] ~= nil then
      count = count + 1
    end
  end
  return count
end

local function ComputePayloadChecksum(text)
  local hash = 5381
  for index = 1, #(text or "") do
    hash = ((hash * 33) + string.byte(text, index)) % 4294967291
  end
  return string.format("%08x", hash)
end

function ShareLinks:EnsureTransferFrame()
  if self.transferFrame then
    return self.transferFrame
  end

  local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame:SetSize(340, 82)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.05, 0.07, 0.10, 0.96)
  frame:SetBackdropBorderColor(0.25, 0.33, 0.45, 1)
  frame:Hide()
  if Frames and Frames.MakeMovable then
    Frames.MakeMovable(frame)
  end
  frame:SetScript("OnUpdate", function(selfFrame)
    if selfFrame.hideAt and GetTime() >= selfFrame.hideAt then
      selfFrame.hideAt = nil
      selfFrame:Hide()
    end
  end)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("TOPLEFT", 14, -10)
  frame.title:SetJustifyH("LEFT")

  frame.detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.detail:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
  frame.detail:SetPoint("TOPRIGHT", -14, -30)
  frame.detail:SetJustifyH("LEFT")

  frame.bar = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
  frame.bar:SetPoint("TOPLEFT", frame.detail, "BOTTOMLEFT", 0, -10)
  frame.bar:SetPoint("TOPRIGHT", -14, -46)
  frame.bar:SetHeight(16)
  frame.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  frame.bar:SetMinMaxValues(0, 1)
  frame.bar:SetValue(0)
  frame.bar:SetStatusBarColor(0.06, 0.50, 0.90, 0.95)
  frame.bar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame.bar:SetBackdropColor(0.08, 0.10, 0.15, 0.98)
  frame.bar:SetBackdropBorderColor(0.24, 0.30, 0.40, 1)

  frame.count = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.count:SetPoint("CENTER")

  self.transferFrame = frame
  return frame
end

function ShareLinks:UpdateTransferProgress(title, detail, current, total, completed)
  local frame = self:EnsureTransferFrame()
  total = math.max(1, tonumber(total or 0) or 1)
  current = math.max(0, math.min(total, tonumber(current or 0) or 0))
  frame.title:SetText(title or "Aura Transfer")
  frame.detail:SetText(detail or "")
  frame.bar:SetMinMaxValues(0, total)
  frame.bar:SetValue(current)
  frame.count:SetText(completed and "Complete" or string.format("%d / %d", current, total))
  frame.hideAt = completed and (GetTime() + 1.5) or nil
  frame:Show()
end

function ShareLinks:QueueOutgoingTransfer(target, shareKey, encoded, auraName)
  if type(encoded) ~= "string" or encoded == "" then
    return false
  end

  local totalParts = math.max(1, math.ceil(#encoded / CHUNK_SIZE))
  self.sendQueue[#self.sendQueue + 1] = {
    target = target,
    shareKey = shareKey,
    encoded = encoded,
    totalParts = totalParts,
    nextIndex = 1,
    started = false,
    byteLength = #encoded,
    checksum = ComputePayloadChecksum(encoded),
    auraName = auraName or "Aura",
  }
  DebugLog(string.format("Queue outgoing key=%s target=%s aura=%s bytes=%d parts=%d checksum=%s",
    tostring(shareKey),
    tostring(target or ""),
    tostring(auraName or "Aura"),
    #encoded,
    totalParts,
    tostring(ComputePayloadChecksum(encoded))))
  self:EnsureSendPump()
  self:UpdateTransferProgress("Queued Aura Transfer",
    string.format("%s -> %s", tostring(auraName or "Aura"), tostring(target or "player")),
    0,
    totalParts,
    false)
  return true
end

function ShareLinks:ProcessSendQueue()
  local transfer = self.sendQueue[1]
  if not transfer then
    return
  end

  local index = transfer.nextIndex or 1
  local totalParts = transfer.totalParts or 1
  if transfer.started ~= true then
    local startMessage = string.format("STA\t%s\t%d\t%d\t%s\t%s",
      tostring(transfer.shareKey),
      totalParts,
      tonumber(transfer.byteLength or #transfer.encoded) or #transfer.encoded,
      tostring(transfer.checksum or ""),
      SanitizeLinkLabel(transfer.auraName))
    if not SendAddonWhisper(transfer.target, startMessage) then
      WriteChatLine(string.format("|cffff4444PopAuras:|r Aura transfer to %s failed before data send.",
        tostring(transfer.target or "player")))
      self:UpdateTransferProgress("Aura Transfer Failed",
        string.format("%s -> %s", tostring(transfer.auraName or "Aura"), tostring(transfer.target or "player")),
        0,
        totalParts,
        true)
      table.remove(self.sendQueue, 1)
      return
    end
    transfer.started = true
    self:UpdateTransferProgress("Sending Aura",
      string.format("%s -> %s", tostring(transfer.auraName or "Aura"), tostring(transfer.target or "player")),
      0,
      totalParts,
      false)
    return
  end

  local chunk = transfer.encoded:sub(((index - 1) * CHUNK_SIZE) + 1, index * CHUNK_SIZE)
  local message = string.format("DAT\t%s\t%d\t%d\t%s", tostring(transfer.shareKey), index, totalParts, chunk)
  if not SendAddonWhisper(transfer.target, message) then
    WriteChatLine(string.format("|cffff4444PopAuras:|r Aura transfer to %s failed on chunk %d/%d.",
      tostring(transfer.target or "player"),
      index,
      totalParts))
    self:UpdateTransferProgress("Aura Transfer Failed",
      string.format("%s -> %s", tostring(transfer.auraName or "Aura"), tostring(transfer.target or "player")),
      math.max(0, index - 1),
      totalParts,
      true)
    table.remove(self.sendQueue, 1)
    return
  end

  self:UpdateTransferProgress("Sending Aura",
    string.format("%s -> %s", tostring(transfer.auraName or "Aura"), tostring(transfer.target or "player")),
    index,
    totalParts,
    false)

  if index >= totalParts then
    WriteChatLine(string.format("|cff66ccffPopAuras:|r Finished sending %s to %s (%d part%s).",
      tostring(transfer.auraName or "Aura"),
      tostring(transfer.target or "player"),
      totalParts,
      totalParts == 1 and "" or "s"))
    self:UpdateTransferProgress("Aura Transfer Complete",
      string.format("%s -> %s", tostring(transfer.auraName or "Aura"), tostring(transfer.target or "player")),
      totalParts,
      totalParts,
      true)
    table.remove(self.sendQueue, 1)
    return
  end

  transfer.nextIndex = index + 1
end

function ShareLinks:EnsureSendPump()
  if self.sendPump then
    return
  end

  local frame = CreateFrame("Frame")
  local accumulated = 0
  frame:SetScript("OnUpdate", function(_, elapsed)
    accumulated = accumulated + elapsed
    if accumulated < SEND_INTERVAL then
      return
    end
    accumulated = 0
    ShareLinks:ProcessSendQueue()
  end)
  self.sendPump = frame
end

local function ShowImportString(encoded, owner)
  if type(encoded) ~= "string" or encoded == "" then
    return
  end

  ns.db.ui.editorMode = "config"
  ns.db.ui.activeTab = "import_export"

  if ns.ui.MainWindow then
    if not ns.ui.MainWindow.frame then
      ns.ui.MainWindow:Create()
    end
    if ns.ui.MainWindow.frame and not ns.ui.MainWindow.frame:IsShown() then
      ns.ui.MainWindow.frame:Show()
    end
    if ns.ui.MainWindow.Refresh then
      ns.ui.MainWindow:Refresh()
    end
  end

  local panel = ns.panels and ns.panels.ImportExportPanel or nil
  if panel and panel.SetImportText then
    panel:SetImportText(encoded, true)
  end

  WriteChatLine(string.format("|cff66ccffPopAuras:|r Loaded shared import%s. Review it on the Import/Export tab, then choose Import.",
    owner and owner ~= "" and (" from " .. owner) or ""))
end

local function ApplySharedImport(encoded, owner)
  local ok, err = ns.Import:Apply(encoded, false)
  if not ok then
    WriteChatLine(string.format("|cffff4444PopAuras:|r Failed to import shared aura%s: %s",
      owner and owner ~= "" and (" from " .. owner) or "",
      tostring(err)))
    ShowImportString(encoded, owner)
    return false
  end

  WriteChatLine(string.format("|cff66ccffPopAuras:|r Imported shared aura%s.",
    owner and owner ~= "" and (" from " .. owner) or ""))
  return true
end

local function SendChunkedExport(target, shareKey, encoded)
  return ShareLinks:QueueOutgoingTransfer(target, shareKey, encoded)
end

local function GetWhisperTargets(scope)
  scope = tostring(scope or "")
  local upper = scope:upper()
  local targets = {}
  local seen = {}

  local function addTarget(unit)
    local target = unit and NormalizePlayerName(Strings and Strings.GetSafeUnitDisplayName and Strings.GetSafeUnitDisplayName(unit, true) or "")
    if target ~= "" and target ~= NormalizePlayerName(GetPlayerFullName()) and not seen[target] then
      seen[target] = true
      targets[#targets + 1] = target
    end
  end

  if upper == "PARTY" then
    for index = 1, 4 do
      if UnitExists("party" .. index) and UnitIsPlayer("party" .. index) then
        addTarget("party" .. index)
      end
    end
    return targets
  end

  if upper == "RAID" then
    for index = 1, 40 do
      local unit = "raid" .. index
      if UnitExists(unit) and UnitIsPlayer(unit) then
        addTarget(unit)
      end
    end
    return targets
  end

  local normalized = NormalizePlayerName(scope)
  if normalized ~= "" then
    targets[1] = normalized
  end
  return targets
end

function ShareLinks:SendSelection(targetText)
  if InCombatLockdown and InCombatLockdown() then
    return false, "Aura sharing is only available out of combat."
  end

  local selectedAuraId = ns.db.ui.selectedAuraId
  if not selectedAuraId then
    return false, "No aura selected."
  end

  local aura = ns.Registry and ns.Registry.GetAura and ns.Registry:GetAura(selectedAuraId) or nil
  if not aura then
    return false, "Selected aura was not found."
  end

  local targets = GetWhisperTargets(targetText)
  if #targets == 0 then
    return false, "Enter a player name, or use PARTY / RAID."
  end

  local encoded = ns.Export and ns.Export.Encode and ns.Export:Encode({ selectedAuraId }) or nil
  if type(encoded) ~= "string" or encoded == "" then
    return false, "Failed to build the export string."
  end

  PruneCacheTable(self.outgoing)
  local shareKey = BuildShareKey()
  self.outgoing[shareKey] = {
    encoded = encoded,
    auraName = aura.name,
    expiresAt = GetTime() + CACHE_TTL,
  }

  local sentCount = 0
  for _, target in ipairs(targets) do
    local message = string.format("OFFER\t%s\t%s", tostring(shareKey), SanitizeLinkLabel(aura.name))
    if SendAddonWhisper(target, message) then
      sentCount = sentCount + 1
    end
  end

  if sentCount == 0 then
    return false, "Unable to send the aura offer."
  end

  WriteChatLine(string.format("|cff66ccffPopAuras:|r Sent %s to %d recipient%s. They will receive an accept popup.",
    tostring(aura.name or "Aura"),
    sentCount,
    sentCount == 1 and "" or "s"))
  return true
end

function ShareLinks:ShowOfferPrompt(sender, shareKey, auraName)
  local offerKey = BuildReceiveKey(sender, shareKey)
  self.offers[offerKey] = {
    sender = sender,
    shareKey = shareKey,
    auraName = auraName,
    expiresAt = GetTime() + CACHE_TTL,
  }

  if not StaticPopupDialogs then
    WriteChatLine(string.format("|cff66ccffPopAuras:|r %s wants to send you %s. Open the Import/Export tab if the transfer arrives.",
      tostring(sender or "Someone"),
      tostring(auraName or "an aura")))
    return
  end

  StaticPopup_Show(OFFER_POPUP_KEY, tostring(sender or "Someone"), tostring(auraName or "Aura"), offerKey)
end

function ShareLinks:AcceptOffer(offerKey)
  local offer = offerKey and self.offers and self.offers[offerKey] or nil
  if not offer then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    WriteChatLine("|cffff4444PopAuras:|r Accept aura sharing out of combat.")
    return
  end
  if offer.sender and offer.shareKey then
    local receiveKey = BuildReceiveKey(offer.sender, offer.shareKey)
    self.pending[receiveKey] = self.pending[receiveKey] or {
      parts = {},
      auraName = offer.auraName,
      expiresAt = GetTime() + CACHE_TTL,
    }
    SendAddonWhisper(offer.sender, string.format("ACCEPT\t%s", tostring(offer.shareKey)))
    WriteChatLine(string.format("|cff66ccffPopAuras:|r Accepting shared aura from %s...", tostring(offer.sender)))
  end
  self.offers[offerKey] = nil
end

function ShareLinks:CreateLinkForSelection()
  local selectedAuraId = ns.db.ui.selectedAuraId
  if not selectedAuraId then
    return false, "No aura selected."
  end

  local aura = ns.Registry and ns.Registry.GetAura and ns.Registry:GetAura(selectedAuraId) or nil
  if not aura then
    return false, "Selected aura was not found."
  end

  local encoded = ns.Export and ns.Export.Encode and ns.Export:Encode({ selectedAuraId }) or nil
  if type(encoded) ~= "string" or encoded == "" then
    return false, "Failed to build the export string."
  end

  PruneCacheTable(self.outgoing)
  local shareKey = BuildShareKey()
  local owner = GetPlayerFullName()
  self.outgoing[shareKey] = {
    encoded = encoded,
    auraName = aura.name,
    expiresAt = GetTime() + CACHE_TTL,
  }

  local hyperlink = BuildLink(owner, shareKey, aura.name)
  if ChatEdit_InsertLink and ChatEdit_InsertLink(hyperlink) then
    WriteChatLine(string.format("|cff66ccffPopAuras:|r Inserted a share link for %s into chat.", tostring(aura.name or "Aura")))
    return true
  end

  if ChatFrame_OpenChat then
    ChatFrame_OpenChat(hyperlink)
    WriteChatLine(string.format("|cff66ccffPopAuras:|r Opened chat with a share link for %s.", tostring(aura.name or "Aura")))
    return true
  end

  return false, "Open a chat edit box and try Create Link again."
end

function ShareLinks:HandleLinkClick(linkData)
  if type(linkData) ~= "string" or linkData == "" then
    return false
  end

  local owner, shareKey = linkData:match("^([^:]+):(.+)$")
  if not owner or not shareKey then
    return false
  end
  owner = NormalizePlayerName(owner)

  local playerName = GetPlayerFullName()
  PruneCacheTable(self.outgoing)
  PruneCacheTable(self.incoming)
  PruneCacheTable(self.pending)

  local localShare = self.outgoing[shareKey]
  if owner == playerName and localShare and localShare.encoded then
    ShowImportString(localShare.encoded, owner)
    return true
  end

  local receiveKey = BuildReceiveKey(owner, shareKey)
  local received = self.incoming[receiveKey]
  if received and received.encoded then
    ShowImportString(received.encoded, owner)
    return true
  end

  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    WriteChatLine("|cffff4444PopAuras:|r Chat link sharing is unavailable on this client.")
    return true
  end

  local now = GetTime()
  local pending = self.pending[receiveKey]
  if pending and (pending.requestedAt or 0) + 1 > now then
    return true
  end

  self.pending[receiveKey] = self.pending[receiveKey] or {
    parts = {},
    auraName = "Shared Aura",
    expiresAt = now + CACHE_TTL,
  }
  self.pending[receiveKey].requestedAt = now
  self.pending[receiveKey].expiresAt = now + CACHE_TTL

  C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "REQ\t" .. tostring(shareKey), "WHISPER", owner)
  WriteChatLine(string.format("|cff66ccffPopAuras:|r Requesting shared aura from %s...", tostring(owner)))
  return true
end

function ShareLinks:HandleAddonMessage(message, sender)
  if type(message) ~= "string" or message == "" then
    return
  end
  sender = NormalizePlayerName(sender)

  local command, payload = message:match("^([^\t]+)\t?(.*)$")
  if command == "OFFER" then
    local shareKey, auraName = payload:match("^([^\t]+)\t?(.*)$")
    if shareKey and shareKey ~= "" and sender and sender ~= "" then
      self:ShowOfferPrompt(sender, shareKey, auraName)
    end
    return
  end

  if command == "STA" then
    local shareKey, totalText, lengthText, checksum, auraName = payload:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t?(.*)$")
    local total = tonumber(totalText or 0) or 0
    local expectedLength = tonumber(lengthText or 0) or 0
    if not shareKey or shareKey == "" or total <= 0 or expectedLength <= 0 then
      return
    end
    local receiveKey = BuildReceiveKey(sender, shareKey)
    local pending = self.pending[receiveKey] or {
      parts = {},
      expiresAt = GetTime() + CACHE_TTL,
    }
    pending.total = total
    pending.expectedLength = expectedLength
    pending.checksum = checksum or ""
    pending.auraName = auraName ~= "" and auraName or pending.auraName or "Shared Aura"
    pending.expiresAt = GetTime() + CACHE_TTL
    self.pending[receiveKey] = pending
    DebugLog(string.format("Receive start key=%s sender=%s aura=%s parts=%d expectedBytes=%d checksum=%s",
      tostring(shareKey),
      tostring(sender or ""),
      tostring(pending.auraName or "Shared Aura"),
      total,
      expectedLength,
      tostring(checksum or "")))
    self:UpdateTransferProgress("Receiving Aura",
      string.format("%s <- %s", tostring(pending.auraName or "Shared Aura"), tostring(sender or "player")),
      CountReceivedParts(pending.parts, total),
      total,
      false)
    return
  end

  if command == "ACCEPT" then
    local shareKey = payload
    local outgoing = shareKey and self.outgoing[shareKey] or nil
    if outgoing and outgoing.encoded and sender and sender ~= "" then
      local totalParts = math.max(1, math.ceil(#outgoing.encoded / CHUNK_SIZE))
      WriteChatLine(string.format("|cff66ccffPopAuras:|r Sending %s to %s (%d part%s)...",
        tostring(outgoing.auraName or "Aura"),
        tostring(sender),
        totalParts,
        totalParts == 1 and "" or "s"))
      self:QueueOutgoingTransfer(sender, shareKey, outgoing.encoded, outgoing.auraName)
    end
    return
  end

  if command == "REQ" then
    local shareKey = payload
    local outgoing = shareKey and self.outgoing[shareKey] or nil
    if outgoing and outgoing.encoded and sender and sender ~= "" then
      local totalParts = math.max(1, math.ceil(#outgoing.encoded / CHUNK_SIZE))
      WriteChatLine(string.format("|cff66ccffPopAuras:|r Sending %s to %s (%d part%s)...",
        tostring(outgoing.auraName or "Aura"),
        tostring(sender),
        totalParts,
        totalParts == 1 and "" or "s"))
      self:QueueOutgoingTransfer(sender, shareKey, outgoing.encoded, outgoing.auraName)
    end
    return
  end

  if command ~= "DAT" then
    return
  end

  local shareKey, indexText, totalText, chunk = payload:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(.*)$")
  local index = tonumber(indexText or 0) or 0
  local total = tonumber(totalText or 0) or 0
  if not shareKey or shareKey == "" or index <= 0 or total <= 0 then
    return
  end

  local receiveKey = BuildReceiveKey(sender, shareKey)
  local now = GetTime()
  local pending = self.pending[receiveKey] or {
    parts = {},
    expiresAt = now + CACHE_TTL,
  }
  pending.parts = pending.parts or {}
  pending.parts[index] = chunk or ""
  pending.total = total
  pending.expiresAt = now + CACHE_TTL
  self.pending[receiveKey] = pending
  if index == 1 or index == total or (index % 10) == 0 then
    DebugLog(string.format("Receive chunk key=%s sender=%s part=%d/%d chunkBytes=%d",
      tostring(shareKey),
      tostring(sender or ""),
      index,
      total,
      #(chunk or "")))
  end
  self:UpdateTransferProgress("Receiving Aura",
    string.format("%s <- %s", tostring(pending.auraName or "Shared Aura"), tostring(sender or "player")),
    CountReceivedParts(pending.parts, total),
    total,
    false)

  for partIndex = 1, total do
    if pending.parts[partIndex] == nil then
      return
    end
  end

  local fragments = {}
  for partIndex = 1, total do
    fragments[#fragments + 1] = pending.parts[partIndex]
  end

  local encoded = table.concat(fragments)
  local expectedLength = tonumber(pending.expectedLength or 0) or 0
  if expectedLength > 0 and #encoded ~= expectedLength then
    self.pending[receiveKey] = nil
    DebugLog(string.format("Receive failed length-mismatch key=%s sender=%s actual=%d expected=%d",
      tostring(shareKey),
      tostring(sender or ""),
      #encoded,
      expectedLength))
    WriteChatLine(string.format("|cffff4444PopAuras:|r Shared aura from %s was incomplete (%d / %d bytes). Please resend it.",
      tostring(sender or "player"),
      #encoded,
      expectedLength))
    self:UpdateTransferProgress("Aura Transfer Failed",
      string.format("%s <- %s", tostring(pending.auraName or "Shared Aura"), tostring(sender or "player")),
      CountReceivedParts(pending.parts, total),
      total,
      true)
    return
  end
  local checksum = pending.checksum or ""
  if checksum ~= "" and ComputePayloadChecksum(encoded) ~= checksum then
    self.pending[receiveKey] = nil
    DebugLog(string.format("Receive failed checksum-mismatch key=%s sender=%s actual=%s expected=%s bytes=%d",
      tostring(shareKey),
      tostring(sender or ""),
      tostring(ComputePayloadChecksum(encoded)),
      tostring(checksum),
      #encoded))
    WriteChatLine(string.format("|cffff4444PopAuras:|r Shared aura from %s was corrupted in transit. Please resend it.",
      tostring(sender or "player")))
    self:UpdateTransferProgress("Aura Transfer Failed",
      string.format("%s <- %s", tostring(pending.auraName or "Shared Aura"), tostring(sender or "player")),
      CountReceivedParts(pending.parts, total),
      total,
      true)
    return
  end
  self.pending[receiveKey] = nil
  self.incoming[receiveKey] = {
    encoded = encoded,
    expiresAt = now + CACHE_TTL,
  }
  DebugLog(string.format("Receive complete key=%s sender=%s bytes=%d checksum=%s",
    tostring(shareKey),
    tostring(sender or ""),
    #encoded,
    tostring(ComputePayloadChecksum(encoded))))
  self:UpdateTransferProgress("Aura Received",
    string.format("%s <- %s", tostring(pending.auraName or "Shared Aura"), tostring(sender or "player")),
    total,
    total,
    true)
  ApplySharedImport(encoded, sender)
end

function ShareLinks:Initialize()
  if self.initialized then
    return
  end
  self.initialized = true

  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
  end

  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("CHAT_MSG_ADDON")
  eventFrame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event ~= "CHAT_MSG_ADDON" or prefix ~= ADDON_PREFIX then
      return
    end
    ShareLinks:HandleAddonMessage(message, sender)
  end)
  self.frame = eventFrame

  if StaticPopupDialogs and not StaticPopupDialogs[OFFER_POPUP_KEY] then
    StaticPopupDialogs[OFFER_POPUP_KEY] = {
      text = "%s wants to send you a PopAuras aura:\n%s\n\nAccept the transfer?",
      button1 = ACCEPT,
      button2 = CANCEL,
      OnAccept = function(popup)
        ShareLinks:AcceptOffer(popup and popup.data)
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end

  if not self.setItemRefHooked and hooksecurefunc then
    hooksecurefunc("SetItemRef", function(link)
      local linkType, linkData = tostring(link or ""):match("^([^:]+):(.+)$")
      if linkType ~= LINK_TYPE then
        return
      end

      if ItemRefTooltip and ItemRefTooltip.Hide then
        ItemRefTooltip:Hide()
      end
      ShareLinks:HandleLinkClick(linkData)
    end)
    self.setItemRefHooked = true
  end
end
