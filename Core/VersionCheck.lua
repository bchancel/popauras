local _, ns = ...

local VersionCheck = {}
ns.VersionCheck = VersionCheck

local ADDON_MSG_PREFIX = "PopAurasVer"
local COLLECT_TIMEOUT = 3
local VERSION_UNKNOWN = "Not installed"

local function GetLocalVersion()
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(ns.name, "Version") or "?"
  end
  if GetAddOnMetadata then
    return GetAddOnMetadata(ns.name, "Version") or "?"
  end
  return "?"
end

local function WriteChatLine(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(message)
    return
  end
  print(message)
end

local function GetGroupUnitTokens()
  local units = {}
  if IsInRaid and IsInRaid() then
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, count do
      units[#units + 1] = "raid" .. i
    end
  elseif IsInGroup and IsInGroup() then
    units[#units + 1] = "player"
    local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    for i = 1, count do
      units[#units + 1] = "party" .. i
    end
  end
  return units
end

local function GetUnitDisplayName(unit)
  if not unit or not UnitExists or not UnitExists(unit) then
    return nil
  end
  local name = UnitName(unit)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if issecretvalue and issecretvalue(name) then
    return nil
  end
  return name
end

do
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)
  end

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:SetScript("OnEvent", function(_, event, prefix, message, _, sender)
    if event ~= "CHAT_MSG_ADDON" or prefix ~= ADDON_MSG_PREFIX then
      return
    end
    VersionCheck:HandleMessage(message, sender)
  end)
  VersionCheck.frame = frame
end

function VersionCheck:HandleMessage(message, sender)
  if not message or not sender then
    return
  end

  local msgType, payload = message:match("^(%S+)%s*(.*)")
  if not msgType then
    return
  end

  if msgType == "REQ" then
    local version = GetLocalVersion()
    local channel = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
      C_ChatInfo.SendAddonMessage(ADDON_MSG_PREFIX, "VER " .. version, channel)
    end
    return
  end

  if msgType == "VER" then
    local version = payload ~= "" and payload or "?"
    if self.collecting then
      local short = sender:match("^([^%-]+)") or sender
      self.responses[short] = version
    end
    return
  end
end

function VersionCheck:StartCheck()
  local localVersion = GetLocalVersion()

  if not (IsInGroup and IsInGroup()) then
    WriteChatLine(string.format("|cff6699ffPopAuras|r version: |cffffffff%s|r", localVersion))
    return
  end

  self.collecting = true
  self.responses = {}

  local playerName = GetUnitDisplayName("player")
  if playerName then
    self.responses[playerName] = localVersion
  end

  local channel = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(ADDON_MSG_PREFIX, "REQ", channel)
  end

  WriteChatLine("|cff6699ffPopAuras|r version check... collecting responses.")

  C_Timer.After(COLLECT_TIMEOUT, function()
    self:FinishCheck()
  end)
end

function VersionCheck:FinishCheck()
  self.collecting = false

  local units = GetGroupUnitTokens()
  local lines = { "|cff6699ffPopAuras|r group version report:" }

  for _, unit in ipairs(units) do
    local name = GetUnitDisplayName(unit)
    if name then
      local short = name:match("^([^%-]+)") or name
      local version = self.responses[short]
      if version then
        lines[#lines + 1] = string.format("  |cffffffff%s|r - |cff00ff00%s|r", short, version)
      else
        lines[#lines + 1] = string.format("  |cffffffff%s|r - |cffff6666%s|r", short, VERSION_UNKNOWN)
      end
    end
  end

  for _, line in ipairs(lines) do
    WriteChatLine(line)
  end

  self.responses = {}
end
