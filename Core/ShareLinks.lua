local _, ns = ...

local ShareLinks = {}
ns.ShareLinks = ShareLinks

local Strings = ns.util.Strings

local LINK_TYPE = "popauras"
local ADDON_PREFIX = "PopAurasShare"
local CHUNK_SIZE = 180
local CACHE_TTL = 600
local OFFER_POPUP_KEY = "POPAURAS_SHARE_OFFER"

ShareLinks.outgoing = ShareLinks.outgoing or {}
ShareLinks.incoming = ShareLinks.incoming or {}
ShareLinks.pending = ShareLinks.pending or {}
ShareLinks.offers = ShareLinks.offers or {}

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

  WriteChatLine(string.format("|cff66ccffPopAuras:|r Loaded shared import%s. Review it on the Import/Export tab, then choose Import Add or Import Replace.",
    owner and owner ~= "" and (" from " .. owner) or ""))
end

local function SendChunkedExport(target, shareKey, encoded)
  local totalParts = math.max(1, math.ceil(#encoded / CHUNK_SIZE))
  for index = 1, totalParts do
    local chunk = encoded:sub(((index - 1) * CHUNK_SIZE) + 1, index * CHUNK_SIZE)
    local message = string.format("DAT\t%s\t%d\t%d\t%s", tostring(shareKey), index, totalParts, chunk)
    if not SendAddonWhisper(target, message) then
      return false
    end
  end
  return true
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

  if command == "ACCEPT" then
    local shareKey = payload
    local outgoing = shareKey and self.outgoing[shareKey] or nil
    if outgoing and outgoing.encoded and sender and sender ~= "" then
      SendChunkedExport(sender, shareKey, outgoing.encoded)
    end
    return
  end

  if command == "REQ" then
    local shareKey = payload
    local outgoing = shareKey and self.outgoing[shareKey] or nil
    if outgoing and outgoing.encoded and sender and sender ~= "" then
      SendChunkedExport(sender, shareKey, outgoing.encoded)
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
  self.pending[receiveKey] = nil
  self.incoming[receiveKey] = {
    encoded = encoded,
    expiresAt = now + CACHE_TTL,
  }
  ShowImportString(encoded, sender)
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
