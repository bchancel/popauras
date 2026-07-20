local _, ns = ...

local NativeAuras = {
  available = false,
  loadError = nil,
  createError = nil,
  probe = nil,
}
ns.NativeAuras = NativeAuras

local function DescribeError(value, fallback)
  if value == nil then return fallback end
  if issecretvalue and issecretvalue(value) then return fallback end
  return tostring(value)
end

function NativeAuras:Initialize()
  if self.initialized then return self.available end
  self.initialized = true

  if C_AddOns and C_AddOns.LoadAddOn then
    local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    if not ok then
      self.loadError = DescribeError(loaded, "Blizzard_AuraContainer could not be loaded")
    elseif loaded ~= true then
      self.loadError = DescribeError(reason, "Blizzard_AuraContainer did not load")
    end
  else
    self.loadError = "C_AddOns.LoadAddOn is unavailable"
  end

  -- XML template names are not reliable Lua globals. The supported capability
  -- test is whether Blizzard can construct the native object on this client.
  local ok, frame = pcall(
    CreateFrame,
    "AuraContainer",
    nil,
    UIParent,
    "CustomAuraContainerTemplate"
  )
  if not ok or not frame then
    self.createError = DescribeError(frame, "CustomAuraContainerTemplate could not be created")
    self.available = false
    return false
  end

  frame:Hide()
  self.probe = frame
  self.available = true
  self.loadError = nil
  return self.available
end

function NativeAuras:IsAvailable()
  if not self.initialized then self:Initialize() end
  return self.available == true
end

function NativeAuras:GetFailureReason()
  return self.createError or self.loadError or "Native aura containers are unavailable"
end

function NativeAuras:CreateContainer(parent)
  if not self:IsAvailable() then return nil, self:GetFailureReason() end

  if self.probe then
    local frame = self.probe
    self.probe = nil
    frame:SetParent(parent)
    frame:ClearAllPoints()
    -- The capability probe is hidden before it is retained. Restore it while
    -- it still has no aura slots; controllers must never Show/Hide it after a
    -- restricted AuraButton has been assigned.
    frame:Show()
    return frame
  end

  local ok, frame = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  if not ok or not frame then
    self.createError = DescribeError(frame, "CustomAuraContainerTemplate could not be created")
    return nil, self.createError
  end
  frame:Show()
  return frame
end
