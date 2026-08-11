local _, ns = ...

local Media = {
  sharedMedia = nil,
  callbackRegistered = false,
  revision = 0,
}
ns.util.Media = Media

local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local BUILTIN = {
  FLAT = { label = "Flat", path = FLAT_TEXTURE },
  GLAZE = { label = "Glaze", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
  BLIZZARD = { label = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
  CAST = { label = "Blizzard", path = "Interface\\TargetingFrame\\UI-StatusBar" },
}
local BUILTIN_ORDER = { "FLAT", "GLAZE", "BLIZZARD" }

-- These files remain owned by the installed UI addon. PopAuras references
-- their installed paths only and does not redistribute third-party artwork.
local ELLESMERE_PATH = "Interface\\AddOns\\EllesmereUI\\Media\\textures\\"
local ELLESMERE = {
  { key = "none", label = "None", file = nil },
  { key = "melli", label = "Melli (ElvUI)", file = "melli.tga" },
  { key = "atrocity", label = "Atrocity", file = "atrocity.tga" },
  { key = "fade", label = "Fade", file = "fade.tga" },
  { key = "fade-right", label = "Fade Right", file = "fade-right.tga" },
  { key = "thin-line-top", label = "Thin Line Top", file = "thin-line-top.tga" },
  { key = "thin-line-bottom", label = "Thin Line Bottom", file = "thin-line-bottom.tga" },
  { key = "beautiful", label = "Beautiful", file = "beautiful.tga" },
  { key = "plating", label = "Plating", file = "plating.tga" },
  { key = "divide", label = "Divide", file = "divide.tga" },
  { key = "glass", label = "Glass", file = "glass.tga" },
  { key = "gradient-lr", label = "Gradient Right", file = "gradient-lr.tga" },
  { key = "gradient-rl", label = "Gradient Left", file = "gradient-rl.tga" },
  { key = "gradient-bt", label = "Gradient Up", file = "gradient-bt.tga" },
  { key = "gradient-tb", label = "Gradient Down", file = "gradient-tb.tga" },
  { key = "matte", label = "Matte", file = "matte.tga" },
  { key = "sheer", label = "Sheer", file = "sheer.tga" },
  { key = "blinkii-diamonds", label = "Blinkii Diamonds", file = "blinkii-diamonds.tga" },
  { key = "kringel-window", label = "Kringel Window", file = "kringel-window.tga" },
}

local ellesmereByKey = {}
for _, entry in ipairs(ELLESMERE) do
  ellesmereByKey[entry.key] = entry
end

local function IsAddonInstalled(addonName)
  local metadataGetter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  if metadataGetter then
    local ok, title = pcall(metadataGetter, addonName, "Title")
    if ok and title then return true end
  end
  if C_AddOns and C_AddOns.GetAddOnInfo then
    local ok, name = pcall(C_AddOns.GetAddOnInfo, addonName)
    if ok and name then return true end
  end
  if GetAddOnInfo then
    local ok, name = pcall(GetAddOnInfo, addonName)
    if ok and name then return true end
  end
  return false
end

local function IsSafeTextureValue(value)
  return type(value) == "string" and value ~= ""
    and not (issecretvalue and issecretvalue(value))
end

function Media:IsEllesmereAvailable()
  if self.ellesmereAvailable == nil then
    self.ellesmereAvailable = IsAddonInstalled("EllesmereUI")
  end
  return self.ellesmereAvailable == true
end

function Media:OnSharedMediaRegistered(_, mediaType)
  if mediaType == "statusbar" then
    self.revision = self.revision + 1
    if ns.util.TexturePicker then ns.util.TexturePicker:RefreshIfOpen() end
  end
end

function Media:WatchForSharedMedia()
  if self.loaderFrame then return end
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function(selfFrame)
    if Media:EnsureSharedMedia(false) then
      selfFrame:UnregisterAllEvents()
      Media.loaderFrame = nil
      Media.revision = Media.revision + 1
      if ns.runtime and ns.runtime.RefreshAll then ns.runtime:RefreshAll() end
      if ns.util.TexturePicker then ns.util.TexturePicker:RefreshIfOpen() end
    end
  end)
  self.loaderFrame = frame
end

function Media:EnsureSharedMedia(allowLoad)
  local libStub = _G.LibStub
  local sharedMedia = libStub and libStub("LibSharedMedia-3.0", true) or nil
  if not sharedMedia and allowLoad and C_AddOns and C_AddOns.LoadAddOn then
    local loaded = C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("LibSharedMedia-3.0")
    if not loaded and not InCombatLockdown() and IsAddonInstalled("LibSharedMedia-3.0") then
      pcall(C_AddOns.LoadAddOn, "LibSharedMedia-3.0")
      libStub = _G.LibStub
      sharedMedia = libStub and libStub("LibSharedMedia-3.0", true) or nil
    end
  end

  if sharedMedia then
    self.sharedMedia = sharedMedia
    if not self.callbackRegistered and sharedMedia.RegisterCallback then
      self.callbackRegistered = pcall(
        sharedMedia.RegisterCallback,
        self,
        "LibSharedMedia_Registered",
        "OnSharedMediaRegistered"
      )
    end
  elseif allowLoad then
    self:WatchForSharedMedia()
  end
  return self.sharedMedia
end

function Media:ResolveStatusBarTexture(value)
  if not IsSafeTextureValue(value) or value == "DEFAULT" then
    return FLAT_TEXTURE
  end
  if value == "Interface\\TARGETINGFRAME\\UI-StatusBar"
      or value == "Interface\\TargetingFrame\\UI-StatusBar" then
    return FLAT_TEXTURE
  end

  local builtin = BUILTIN[value]
  if builtin then return builtin.path end

  local ellesmereKey = value:match("^eui:(.+)$")
  if ellesmereKey then
    local entry = ellesmereByKey[ellesmereKey]
    if self:IsEllesmereAvailable() and entry then
      return entry.file and (ELLESMERE_PATH .. entry.file) or FLAT_TEXTURE
    end
    return FLAT_TEXTURE
  end

  local sharedMediaKey = value:match("^sm:(.+)$")
  if sharedMediaKey then
    local sharedMedia = self:EnsureSharedMedia(false)
    if sharedMedia and sharedMedia.Fetch then
      local ok, path = pcall(sharedMedia.Fetch, sharedMedia, "statusbar", sharedMediaKey, true)
      if ok and IsSafeTextureValue(path) then return path end
    end
    return FLAT_TEXTURE
  end

  -- Direct texture paths from older profiles remain supported.
  return value
end

function Media:GetStatusBarTextureOptions(allowLoad)
  local options = {}
  for _, key in ipairs(BUILTIN_ORDER) do
    local entry = BUILTIN[key]
    options[#options + 1] = {
      value = key,
      label = entry.label,
      path = entry.path,
      sourceLabel = "PopAuras",
    }
  end

  if self:IsEllesmereAvailable() then
    for _, entry in ipairs(ELLESMERE) do
      options[#options + 1] = {
        value = "eui:" .. entry.key,
        label = entry.label,
        path = entry.file and (ELLESMERE_PATH .. entry.file) or FLAT_TEXTURE,
        sourceLabel = "Installed UI",
      }
    end
  end

  local sharedMedia = self:EnsureSharedMedia(allowLoad == true)
  if sharedMedia and sharedMedia.List and sharedMedia.Fetch then
    local ok, names = pcall(sharedMedia.List, sharedMedia, "statusbar")
    if ok and type(names) == "table" then
      local sorted = {}
      for _, name in ipairs(names) do
        if IsSafeTextureValue(name) then sorted[#sorted + 1] = name end
      end
      table.sort(sorted, function(left, right) return left:lower() < right:lower() end)
      for _, name in ipairs(sorted) do
        local fetched, path = pcall(sharedMedia.Fetch, sharedMedia, "statusbar", name, true)
        if fetched and IsSafeTextureValue(path) then
          options[#options + 1] = {
            value = "sm:" .. name,
            label = name,
            path = path,
            sourceLabel = "SharedMedia",
          }
        end
      end
    end
  end
  return options
end

function Media:GetRevision()
  return self.revision
end
