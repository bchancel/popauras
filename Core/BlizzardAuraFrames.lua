local _, ns = ...

local Manager = {}
ns.BlizzardAuraFrames = Manager

Manager.frameStates = Manager.frameStates or {}

local function EnsureFrameState(self, frame)
  local state = self.frameStates[frame]
  if type(state) ~= "table" then
    state = {}
    self.frameStates[frame] = state
  end
  return state
end

local function CaptureFrameState(frame, state)
  if state.originalAlpha == nil and frame.GetAlpha then
    state.originalAlpha = frame:GetAlpha()
  end
  if state.originalMouseEnabled == nil and frame.IsMouseEnabled then
    state.originalMouseEnabled = frame:IsMouseEnabled()
  end
end

local function ApplyFrameHidden(self, frame, hidden)
  if type(frame) ~= "table" then
    return
  end

  local state = EnsureFrameState(self, frame)
  if state.hidden == hidden then
    return
  end

  if hidden then
    CaptureFrameState(frame, state)
    if frame.SetAlpha then
      pcall(frame.SetAlpha, frame, 0)
    end
    if frame.EnableMouse then
      pcall(frame.EnableMouse, frame, false)
    end
  else
    if frame.SetAlpha then
      pcall(frame.SetAlpha, frame, state.originalAlpha ~= nil and state.originalAlpha or 1)
    end
    if frame.EnableMouse then
      pcall(frame.EnableMouse, frame, state.originalMouseEnabled ~= false)
    end
    state.originalAlpha = nil
    state.originalMouseEnabled = nil
  end

  state.hidden = hidden
end

local function AddFrame(target, seen, frame)
  if type(frame) ~= "table" or seen[frame] then
    return
  end
  seen[frame] = true
  target[#target + 1] = frame
end

function Manager:GetSectionFrames(section)
  local frames = {}
  local seen = {}

  if section == "buffs" then
    AddFrame(frames, seen, _G.TemporaryEnchantFrame)
    AddFrame(frames, seen, _G.BuffFrame)
    AddFrame(frames, seen, _G.BuffFrame and _G.BuffFrame.AuraContainer)
  elseif section == "debuffs" then
    AddFrame(frames, seen, _G.DebuffFrame)
    AddFrame(frames, seen, _G.DebuffFrame and _G.DebuffFrame.AuraContainer)
  end

  return frames
end

function Manager:GetDesiredState()
  local hideBuffs = false
  local hideDebuffs = false

  if not (ns.Registry and ns.Registry.GetFlatOrder and ns.Registry.GetAura and ns.runtime and ns.runtime.GetState) then
    return hideBuffs, hideDebuffs
  end

  for _, auraId in ipairs(ns.Registry:GetFlatOrder() or {}) do
    local aura = ns.Registry:GetAura(auraId)
    local state = ns.runtime:GetState(auraId)

    if aura and aura.enabled ~= false and type(aura.triggers) == "table"
        and type(state) == "table" and state.show == true and state.source ~= "preview" then
      for _, trigger in ipairs(aura.triggers) do
        if trigger and trigger.enabled ~= false and trigger.type == "aura_list" then
          local sourceValue = ns.util.UnitAuraList and ns.util.UnitAuraList.GetSourceValue
            and ns.util.UnitAuraList:GetSourceValue(trigger)
            or nil
          if sourceValue == "player_buff" and trigger.hideBlizzardBuffs == true then
            hideBuffs = true
          elseif sourceValue == "player_debuff" and trigger.hideBlizzardDebuffs == true then
            hideDebuffs = true
          end
        end

        if hideBuffs and hideDebuffs then
          return true, true
        end
      end
    end
  end

  return hideBuffs, hideDebuffs
end

function Manager:Sync()
  local hideBuffs, hideDebuffs = self:GetDesiredState()

  for _, frame in ipairs(self:GetSectionFrames("buffs")) do
    ApplyFrameHidden(self, frame, hideBuffs)
  end

  for _, frame in ipairs(self:GetSectionFrames("debuffs")) do
    ApplyFrameHidden(self, frame, hideDebuffs)
  end
end

function Manager:Initialize()
  self.frameStates = self.frameStates or {}
end
