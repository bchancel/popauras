local _, ns = ...

local ShareLinks = {}
ns.ShareLinks = ShareLinks

local LINK_TYPE = "popauras"
local ADDON_PREFIX = "PopAurasShare"
local CHUNK_SIZE = 180
local CACHE_TTL = 600

ShareLinks.outgoing = ShareLinks.outgoing or {}
ShareLinks.incoming = ShareLinks.incoming or {}
ShareLinks.pending = ShareLinks.pending or {}

local function WriteChatLine(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(message)
    return
  end
  print(message)
end

local function GetPlayerFullName()
  local name, realm = UnitFullName and UnitFullName("player")
  if not name or name == "" then
    name = UnitName and UnitName("player") or "Unknown"
  end
  realm = tostring(realm or ""):gsub("%s+", "")
  if realm ~= "" then
    return string.format("%s-%s", name, realm)
  end
  return tostring(name)
end

local function NormalizePlayerName(value)
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
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
    return false
  end

  local totalParts = math.max(1, math.ceil(#encoded / CHUNK_SIZE))
  for index = 1, totalParts do
    local chunk = encoded:sub(((index - 1) * CHUNK_SIZE) + 1, index * CHUNK_SIZE)
    local message = string.format("DAT\t%s\t%d\t%d\t%s", tostring(shareKey), index, totalParts, chunk)
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, "WHISPER", target)
  end
  return true
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

  if not self.originalSetItemRef then
    self.originalSetItemRef = SetItemRef
    SetItemRef = function(link, text, button, chatFrame)
      local linkType, linkData = tostring(link or ""):match("^([^:]+):(.+)$")
      if linkType == LINK_TYPE and ShareLinks:HandleLinkClick(linkData) then
        return
      end
      if ShareLinks.originalSetItemRef then
        return ShareLinks.originalSetItemRef(link, text, button, chatFrame)
      end
    end
  end
end
