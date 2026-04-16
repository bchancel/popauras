local _, ns = ...

local Items = {}
ns.util.Items = Items

local EQUIPMENT_SLOTS = {
  INVSLOT_HEAD or 1,
  INVSLOT_NECK or 2,
  INVSLOT_SHOULDER or 3,
  INVSLOT_CHEST or 5,
  INVSLOT_WAIST or 6,
  INVSLOT_LEGS or 7,
  INVSLOT_FEET or 8,
  INVSLOT_WRIST or 9,
  INVSLOT_HAND or 10,
  INVSLOT_FINGER1 or 11,
  INVSLOT_FINGER2 or 12,
  INVSLOT_TRINKET1 or 13,
  INVSLOT_TRINKET2 or 14,
  INVSLOT_BACK or 15,
  INVSLOT_MAINHAND or 16,
  INVSLOT_OFFHAND or 17,
}

local nameToIdCache = {}
local idToNameCache = {}

local function NormalizeText(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function ParseItemID(link)
  if type(link) ~= "string" then
    return nil
  end
  local itemId = tonumber(link:match("item:(%d+)") or "") or 0
  if itemId > 0 then
    return itemId
  end
  return nil
end

local function RememberResolvedItem(itemId, itemName)
  itemId = tonumber(itemId or 0) or 0
  itemName = NormalizeText(itemName)
  if itemId <= 0 or itemName == "" then
    return
  end

  idToNameCache[itemId] = itemName
  nameToIdCache[string.lower(itemName)] = itemId
end

local function ResolveCachedItemByName(itemName)
  itemName = NormalizeText(itemName)
  if itemName == "" then
    return 0, ""
  end

  local lowerName = string.lower(itemName)
  local cachedId = tonumber(nameToIdCache[lowerName] or 0) or 0
  if cachedId > 0 then
    return cachedId, idToNameCache[cachedId] or itemName
  end

  if GetItemInfo then
    local resolvedName, itemLink = GetItemInfo(itemName)
    local itemId = ParseItemID(itemLink)
    if itemId and itemId > 0 then
      RememberResolvedItem(itemId, resolvedName or itemName)
      return itemId, resolvedName or itemName
    end
  end

  return 0, itemName
end

function Items.NormalizeText(value)
  return NormalizeText(value)
end

function Items:GetItemName(itemId)
  itemId = tonumber(itemId or 0) or 0
  if itemId <= 0 then
    return nil
  end

  local cached = idToNameCache[itemId]
  if cached and cached ~= "" then
    return cached
  end

  local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId) or nil
  if type(itemName) == "string" and itemName ~= "" then
    RememberResolvedItem(itemId, itemName)
    return itemName
  end

  return nil
end

function Items:FindEquippedItemByName(itemName)
  itemName = NormalizeText(itemName)
  if itemName == "" then
    return 0, ""
  end

  local needle = string.lower(itemName)
  for _, slotId in ipairs(EQUIPMENT_SLOTS) do
    local itemId = GetInventoryItemID and GetInventoryItemID("player", slotId) or nil
    itemId = tonumber(itemId or 0) or 0
    if itemId > 0 then
      local equippedName = self:GetItemName(itemId)
      if equippedName and string.lower(equippedName) == needle then
        return itemId, equippedName
      end
    end
  end

  return 0, itemName
end

function Items:IsEquippedItemByName(itemName)
  local itemId = self:FindEquippedItemByName(itemName)
  return (tonumber(itemId or 0) or 0) > 0
end

function Items:ResolveItemReference(itemId, itemName)
  itemId = tonumber(itemId or 0) or 0
  itemName = NormalizeText(itemName)

  if itemId > 0 then
    local resolvedName = self:GetItemName(itemId) or itemName
    return itemId, resolvedName
  end

  if itemName == "" then
    return 0, ""
  end

  local resolvedId, resolvedName = ResolveCachedItemByName(itemName)
  if resolvedId > 0 then
    return resolvedId, resolvedName
  end

  return self:FindEquippedItemByName(itemName)
end

function Items:ResolveInput(input)
  input = NormalizeText(input)
  if input == "" then
    return 0, ""
  end

  local numeric = tonumber(input)
  if numeric then
    local itemId = math.max(0, math.floor(numeric + 0.5))
    return itemId, self:GetItemName(itemId)
  end

  local resolvedId, resolvedName = self:ResolveItemReference(0, input)
  if resolvedId > 0 then
    return resolvedId, resolvedName
  end

  return 0, input
end
