"""Run with Python and lupa installed; uses Lua 5.1 and a bounded WoW UI mock."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
load_lua = LuaRuntime(unpack_returned_tuples=True)
load_lua.globals().repository = ROOT.as_posix()
load_lua.execute((ROOT / "tests/LoadEvaluator.lua").read_text(encoding="utf-8-sig"))
slash_lua = LuaRuntime(unpack_returned_tuples=True)
slash_lua.globals().repository = ROOT.as_posix()
slash_lua.execute((ROOT / "tests/ArrangeSlash.lua").read_text(encoding="utf-8-sig"))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().repository = ROOT.as_posix()
lua.execute(r'''
unpack = unpack or table.unpack
local factors = {
  CENTER={.5,.5}, TOP={.5,1}, BOTTOM={.5,0}, LEFT={0,.5}, RIGHT={1,.5},
  TOPLEFT={0,1}, TOPRIGHT={1,1}, BOTTOMLEFT={0,0}, BOTTOMRIGHT={1,0},
}
local Frame = {}
Frame.__index = Frame
function Frame:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:GetLeft()
  if not self.anchor then return self.left or 0 end
  local a = self.anchor
  local target = a[2]
  return (target:GetLeft() * target:GetEffectiveScale()
    + target:GetWidth() * factors[a[3]][1] * target:GetEffectiveScale()) / self:GetEffectiveScale()
    - self.width * factors[a[1]][1] + a[4]
end
function Frame:GetBottom()
  if not self.anchor then return self.bottom or 0 end
  local a = self.anchor
  local target = a[2]
  return (target:GetBottom() * target:GetEffectiveScale()
    + target:GetHeight() * factors[a[3]][2] * target:GetEffectiveScale()) / self:GetEffectiveScale()
    - self.height * factors[a[1]][2] + a[5]
end
function Frame:SetPoint(point, target, relativePoint, x, y)
  if type(target) == 'number' then x, y, target, relativePoint = target, relativePoint, self.parent, point end
  if not target then target = self.parent; relativePoint = point end
  self.anchor = {point, target, relativePoint or point, x or 0, y or 0}
end
function Frame:GetPoint() return unpack(self.anchor) end
function Frame:ClearAllPoints() self.anchor = nil end
function Frame:SetSize(w, h)
  local changed = w ~= self.width or h ~= self.height
  self.width, self.height = w, h
  if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, w, h) end
end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:SetScale(scale) self.scale = scale end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:EnableMouse(enabled) self.mouseEnabled = enabled end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetAllPoints(target)
  target = target or self.parent
  self:SetSize(target:GetWidth(), target:GetHeight())
  self:SetPoint('CENTER', target, 'CENTER', 0, 0)
end
function Frame:SetScript(event, callback) self.scripts[event] = callback end
function Frame:HookScript(event, callback)
  local old = self.scripts[event]
  self.scripts[event] = function(...) if old then old(...) end; callback(...) end
end
function Frame:Show() self.shown = true end
function Frame:Hide()
  local wasShown = self.shown
  self.shown = false
  if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsForbidden() return self.forbidden == true end
function Frame:IsMouseOver() return self.mouseOver == true end
function Frame:SetFrameLevel(value) self.level = value end
function Frame:GetFrameLevel() return self.level end
function Frame:SetText(value) self.text = value end
function Frame:SetTextColor(...) self.textColor = {...} end
function Frame:SetColorTexture(...) self.color = {...} end
function Frame:SetTexture(path) self.texture = path end
function Frame:SetRotation(rotation) self.rotation = rotation end
function Frame:SetBackdropBorderColor(...) self.borderColor = {...} end
function Frame:SetChecked(checked) self.checked = checked end
function Frame:GetChecked() return self.checked end
function Frame:GetText() return self.text or '' end
function Frame:HasFocus() return self.focused == true end
function Frame:ClearFocus() self.focused = false end
function Frame:SetPropagateKeyboardInput(value) self.propagates = value end
function Frame:RegisterEvent(value) self.events[value] = true end
function Frame:SetParentKey(value) self.parentKey = value end
for _, method in ipairs({'SetFrameStrata','SetMovable','EnableKeyboard','RegisterForDrag','SetClampedToScreen',
  'SetJustifyH','SetWordWrap','SetBackdrop','SetBackdropColor'}) do
  Frame[method] = function() end
end
function CreateFrame(_, name, parent)
  local frame = setmetatable({width=100,height=32,scale=1,parent=parent,shown=true,level=0,scripts={},events={}}, Frame)
  if name then _G[name] = frame end
  return frame
end
function Frame:CreateTexture() return CreateFrame('Texture', nil, self) end
function Frame:CreateFontString() return CreateFrame('FontString', nil, self) end
UIParent = CreateFrame('Frame')
UIParent:SetSize(1920,1080)
UIParent:SetScale(.75)
PlayerFrame = CreateFrame('Frame', nil, UIParent)
PlayerFrame:SetSize(300,100)
PlayerFrame:SetScale(.6)
PlayerFrame:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',100,80)
TargetFrame = CreateFrame('Frame', nil, UIParent)
TargetFrame.forbidden = true
TargetFrame.GetLeft = function() error('forbidden target accessed') end
local secret = {}
function issecretvalue(value) return value == secret end
local combat, shift, cursorX, cursorY = false, false, 0, 0
function InCombatLockdown() return combat end
function IsShiftKeyDown() return shift end
function GetCursorPosition() return cursorX,cursorY end
local timers = {}
C_Timer = {After=function(_,callback) timers[#timers+1]=callback end}
local function RunTimers()
  local pending=timers; timers={}
  for _,callback in ipairs(pending) do callback() end
end
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
local ns = {ui={},util={},renderers={},runtime={},db={ui={},auras={},order={}}}
local function Load(path) assert(loadfile(repository..'/'..path))('PopAuras',ns) end
Load('Core/SafeValues.lua')
Load('Util/Tables.lua')
Load('Util/Anchors.lua')
ns.util.Theme = {
  StyleSurface=function(frame,_,border) frame.border=border end,
  StyleButton=function() end, ApplyTypography=function() end, SetText=function() end,
}
ns.util.Frames = {
  CreateLabel=function(parent,text) local f=CreateFrame('FontString',nil,parent); f:SetText(text); return f end,
  CreateButton=function(parent,text,w,h,click)
    local f=CreateFrame('Button',nil,parent); f:SetSize(w,h); f:SetText(text)
    f.GetFontString=function() return f end; f:SetScript('OnClick',click); return f
  end,
  CreateInput=function(parent,w,h) local f=CreateFrame('EditBox',nil,parent); f:SetSize(w,h); return f end,
  CreateCheckbox=function(parent,text)
    local f=CreateFrame('CheckButton',nil,parent)
    f.Text=CreateFrame('FontString',nil,f); f.Text:SetText(text); return f
  end,
  CreateSettingsPopover=function(options)
    local f=CreateFrame('Frame',nil,UIParent); f:Hide(); f.options=options
    f.Refresh=function() end; f.ShowFor=function(self) self:Show() end; return f
  end,
}
ns.Registry = {
  GetAura=function(_,id) return ns.db.auras[id] end,
  GetOrder=function() return ns.db.order end,
  IterateGroups=function()
    local id
    return function()
      repeat id=next(ns.db.auras,id) until not id or ns.db.auras[id].kind=='group' or ns.db.auras[id].kind=='dynamic_group'
      if id then return id, ns.db.auras[id] end
    end
  end,
}
Load('Engine/LoadEvaluator.lua')
local loadChecks=0
ns.LoadEvaluator.Matches=function(_,a) loadChecks=loadChecks+1; return a.loadMatched~=false end
ns.renderers.NameplateAuraRegion = {CanHandle=function(_,aura) return aura and aura.nameplate end}
Load('Renderers/BaseRegion.lua')
local regions = {}
function ns.runtime:GetRegionByAuraId(id) return regions[id] end
function ns.runtime:RefreshAll()
  for id,region in pairs(regions) do ns.renderers.BaseRegion:ApplyAnchor(ns.db.auras[id],region.frame) end
end
ns.ui.MainWindow = {
  frame=CreateFrame('Frame',nil,UIParent), RefreshSelection=function() end,
}
ns.ui.MainWindow.frame:SetScript('OnHide',function() ns.runtime:RefreshAll() end)
local function Aura(id,kind,parent,target)
  local aura={id=id,name=id,kind=kind,parentId=parent,children={},display={width=200,height=50},
    position={point='CENTER',relativePoint='CENTER',relativeTo=target or 'UIParent',x=13,y=-7,width=200,height=50}}
  ns.db.auras[id]=aura
  local frame=CreateFrame('Frame',nil,UIParent)
  regions[id]={frame=frame}
  if parent then
    local children=ns.db.auras[parent].children; children[#children+1]=id
  else ns.db.order[#ns.db.order+1]=id end
  ns.renderers.BaseRegion:ApplyAnchor(aura,frame)
  return aura
end
local group=Aura('group','group')
local child=Aura('child','bar','group')
local nested=Aura('nested','group','group')
local aura=Aura('aura','icon')
local linked=Aura('linked','group',nil,'group')
local dynamic=Aura('dynamic','dynamic_group'); dynamic.display.growth='RIGHT'
local unloadedGroup=Aura('unloadedGroup','group'); unloadedGroup.loadMatched=false
local unloadedAura=Aura('unloadedAura','bar'); unloadedAura.loadMatched=false
local linkedChild=Aura('linkedChild','icon','linked')
local dynamicChild=Aura('dynamicChild','bar','dynamic')
local unloadedChild=Aura('unloadedChild','icon','unloadedGroup')
local plate=Aura('plate','icon'); plate.nameplate=true
Load('Options/UI/ArrangeMode.lua')
local arrange=ns.ui.ArrangeMode
local function Near(a,b) assert(math.abs(a-b)<.00001, tostring(a)..' != '..tostring(b)) end
local function Center(frame)
  return frame:GetLeft()+frame:GetWidth()/2,frame:GetBottom()+frame:GetHeight()/2
end

-- Top-level handles only, including inactive auras; no saved writes on entry.
arrange:Start()
assert(arrange:IsActive() and not ns.ui.MainWindow.frame:IsShown())
assert(arrange.movers.group and arrange.movers.aura and arrange.movers.linked)
assert(arrange.loadedOnly and arrange.frame.loadedOnlyCheck:GetChecked())
assert(not arrange.movers.unloadedGroup:IsShown() and not arrange.movers.unloadedAura:IsShown())
assert(arrange.movers.aura:IsShown()) -- An inactive trigger still matches its Load rules.
assert(not arrange.movers.child and not arrange.movers.nested and not arrange.movers.plate)
assert(aura.position.x==13 and aura.position.y==-7)
assert(not arrange:CanAnchorTo('group','group'))
assert(not arrange:CanAnchorTo('group','child'))
assert(not arrange:CanAnchorTo('group','nested'))
assert(not arrange:CanAnchorTo('group','linked'))
assert(arrange:CanAnchorTo('aura','group'))

-- Anchor conversion preserves the visible rectangle across scaled external frames.
local beforeX,beforeY=Center(arrange.movers.aura)
assert(arrange:ChangeAnchor('aura',{relativeTo='PlayerFrame',point='TOPLEFT',relativePoint='BOTTOMRIGHT'}))
local afterX,afterY=Center(arrange.movers.aura)
Near(beforeX,afterX); Near(beforeY,afterY)
assert(aura.position.relativeTo=='UIParent')
assert(arrange.pending.aura.relativeTo=='PlayerFrame')
assert(not arrange:ChangeAnchor('aura',{relativeTo='TargetFrame'}))
assert(arrange.pending.aura.relativeTo=='PlayerFrame')

-- Pending coordinates survive a normal renderer refresh; cancel restores the original.
arrange:SetOffset('aura',40,60)
ns.runtime:RefreshAll()
assert(regions.aura.frame.anchor[4]==40 and regions.aura.frame.anchor[5]==60)
assert(aura.position.x==13)
arrange:Finish(false,true)
assert(not arrange:IsActive() and ns.ui.MainWindow.frame:IsShown())
assert(aura.position.x==13 and regions.aura.frame.anchor[4]==13)
assert(not next(arrange.pending))

-- Drag snapping is centered on the screen grid; Shift bypasses snapping.
arrange:Start()
local mover=arrange.movers.aura
cursorX,cursorY=500,400
arrange:BeginDrag(mover)
cursorX,cursorY=523,433
arrange:UpdateDrag()
local x,y=Center(mover)
Near((x-960)/20,math.floor((x-960)/20+.5))
Near((y-540)/20,math.floor((y-540)/20+.5))
assert(aura.position.x==13)
shift=true; cursorX,cursorY=526,439
arrange:UpdateDrag()
Near(arrange.pending.aura.x,13+26/.75)
Near(arrange.pending.aura.y,-7+39/.75)
arrange:StopDrag(); assert(not mover.scripts.OnUpdate)
shift=false
local oldX=arrange.pending.aura.x
arrange:Nudge(1,0); Near(arrange.pending.aura.x,oldX+1)
shift=true; arrange:Nudge(0,1); shift=false
assert(arrange.pending.aura.y>-7+39/.75)
local savedX,savedY=arrange.pending.aura.x,arrange.pending.aura.y
arrange:Finish(true,false)
Near(aura.position.x,savedX); Near(aura.position.y,savedY)
assert(not ns.ui.MainWindow.frame:IsShown())

-- Linked roots follow a moving group. Membership and child offsets stay intact.
arrange:Start()
local lx,ly=Center(arrange.movers.linked)
arrange:SetOffset('group',113,93)
local mx,my=Center(arrange.movers.linked)
Near(mx-lx,100); Near(my-ly,100)
assert(child.parentId=='group' and child.position.x==13)
arrange:Finish(false,false)

-- Reset affects the selected position only; Configure saves and selects its editor.
arrange:Start()
arrange:SetOffset('group',20,30)
arrange:SetOffset('aura',100,200)
arrange.movers.aura.resetButton.scripts.OnClick()
Near(arrange.pending.aura.x,aura.position.x)
assert(not arrange.dirty.aura and arrange.dirty.group)
arrange.movers.group.configButton.scripts.OnClick()
assert(group.position.x==20 and ns.db.ui.selectedAuraId=='group')
assert(ns.db.ui.editorMode=='config' and ns.db.ui.activeTab=='display')
assert(ns.ui.MainWindow.frame:IsShown())

-- Combat, logout, and external hiding always discard unsaved changes and idle drivers.
for _,event in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_LOGOUT','hide'}) do
  arrange:Start(); arrange:SetOffset('aura',999,999)
  if event=='PLAYER_REGEN_DISABLED' then combat=true end
  if event=='hide' then arrange.frame:Hide() else arrange.frame.scripts.OnEvent(arrange.frame,event) end
  assert(not arrange:IsActive() and aura.position.x==savedX)
  assert(not arrange.movers.aura.scripts.OnUpdate)
  combat=false
end
combat=true; arrange:Start(); assert(not arrange:IsActive()); combat=false

-- Opaque geometry is rejected before arithmetic and never saved.
arrange:Start()
assert(not arrange:SetOffset('aura',secret,20))
assert(not arrange:SetOffset('aura',0/0,20))
assert(not arrange:SetOffset('aura',math.huge,20))
local oldGetWidth=regions.aura.frame.GetWidth
regions.aura.frame.GetWidth=function() return secret end
arrange:SyncMover('aura')
assert(arrange.movers.aura:GetWidth()==aura.position.width)
regions.aura.frame.GetWidth=oldGetWidth
arrange:Finish(false,false)

-- Keyboard input reaches text editors; Escape closes anchor controls first.
arrange:Start()
arrange:Select(arrange.movers.aura)
local keyboard=arrange.frame.scripts.OnKeyDown
local keyX=arrange.pending.aura.x
keyboard(arrange.frame,'RIGHT')
Near(arrange.pending.aura.x,keyX+1)
assert(not arrange.frame.propagates)
arrange.frame.spacing.focused=true
keyboard(arrange.frame,'LEFT')
Near(arrange.pending.aura.x,keyX+1)
assert(arrange.frame.propagates)
arrange.frame.spacing.focused=false
arrange:ShowAnchors(arrange.movers.aura)
keyboard(arrange.frame,'ESCAPE')
assert(arrange:IsActive() and not arrange.anchorPopover:IsShown())
keyboard(arrange.frame,'ESCAPE')
assert(not arrange:IsActive() and ns.ui.MainWindow.frame:IsShown())

-- Collapsed controls hide their hit area; hover/focus keeps controls accessible.
arrange:Start()
local bar,controls=arrange.frame.bar,arrange.frame.toolbarControls
local function FinishFade()
  if controls.scripts.OnUpdate then controls.scripts.OnUpdate(controls,1) end
end
assert(bar:GetWidth()==86 and bar:GetHeight()==34 and controls:GetWidth()==518)
assert(controls:IsShown())
RunTimers(); FinishFade()
assert(not controls:IsShown() and not controls.scripts.OnUpdate)
bar.mouseOver=true; bar.scripts.OnEnter(bar); FinishFade()
assert(controls:IsShown() and controls:GetAlpha()==1)
bar.mouseOver=false; controls.mouseOver=true; bar.scripts.OnLeave(bar)
RunTimers(); FinishFade(); assert(controls:IsShown())
controls.mouseOver=false; arrange.frame.spacing.focused=true
controls.scripts.OnLeave(controls); RunTimers(); assert(controls:IsShown())
arrange.frame.spacing.focused=false
arrange.frame.spacing.scripts.OnEditFocusLost(arrange.frame.spacing)
RunTimers(); FinishFade(); assert(not controls:IsShown())

-- Reentering before the delayed collapse invalidates the pending callback.
bar.scripts.OnEnter(bar); FinishFade()
bar.scripts.OnLeave(bar)
bar.scripts.OnEnter(bar); RunTimers(); FinishFade()
assert(controls:IsShown())

-- Pin holds the controls open, but even pinned controls yield during aura drags.
arrange.frame.pinButton.scripts.OnClick(); RunTimers(); FinishFade()
assert(arrange.toolbarPinned and controls:IsShown())
arrange:BeginDrag(arrange.movers.aura)
assert(not controls:IsShown() and not bar.mouseEnabled)
arrange:StopDrag()
assert(controls:IsShown() and bar.mouseEnabled)
arrange.frame.pinButton.scripts.OnClick(); RunTimers(); FinishFade()
assert(not arrange.toolbarPinned and not controls:IsShown())

-- Dragging the toolbar is independent of aura positioning and survives reentry.
local originalAuraX=aura.position.x
arrange:BeginToolbarDrag()
assert(bar.moving and arrange.toolbarDragging and controls:IsShown())
bar:SetPoint('CENTER',UIParent,'CENTER',150,-200)
arrange:StopToolbarDrag()
assert(not bar.moving and not arrange.toolbarDragging)
Near(arrange.toolbarPosition.x,150); Near(arrange.toolbarPosition.y,-200)
assert(aura.position.x==originalAuraX)
arrange:Finish(false,false); RunTimers()
assert(not controls:IsShown() and not controls.scripts.OnUpdate)
arrange:Start()
local toolbarX,toolbarY=Center(bar)
Near(toolbarX,960+150); Near(toolbarY,540-200)

-- At the right edge controls open to the left; resizing preserves toolbar scale.
arrange:BeginToolbarDrag()
bar:SetPoint('CENTER',UIParent,'CENTER',800,0)
arrange:StopToolbarDrag()
assert(controls.anchor[1]=='RIGHT' and controls.anchor[3]=='LEFT')
UIParent:SetSize(400,600)
arrange.frame.scripts.OnEvent(arrange.frame,'DISPLAY_SIZE_CHANGED')
Near(bar.scale,(400-24)/608)
UIParent:SetSize(1920,1080)
arrange:Finish(false,false); RunTimers()
assert(not controls:IsShown() and not controls.scripts.OnUpdate)

-- Turning Loaded Only off reveals grey unloaded handles without losing edits.
arrange:Start()
local filter=arrange.frame.loadedOnlyCheck
filter:SetChecked(false); filter.scripts.OnClick(filter)
local unloaded=arrange.movers.unloadedGroup
assert(not arrange.loadedOnly and unloaded:IsShown() and arrange.movers.unloadedAura:IsShown())
assert(unloaded.fill.color[1]>arrange.movers.group.fill.color[1])
Near(unloaded.fill.color[1],.3)
unloaded.scripts.OnEnter(unloaded)
Near(unloaded.fill.color[1],.3) -- Hover preserves its distinct grey treatment.
arrange:Select(unloaded)
arrange:SetOffset('unloadedGroup',177,88)
filter:SetChecked(true); filter.scripts.OnClick(filter)
assert(not unloaded:IsShown() and not arrange.selected)
assert(arrange.pending.unloadedGroup.x==177 and arrange.dirty.unloadedGroup)
filter:SetChecked(false); filter.scripts.OnClick(filter)
assert(unloaded:IsShown() and arrange.pending.unloadedGroup.x==177)
assert(unloaded.coordinates:GetText():find('Unloaded'))
arrange:Finish(true,false)
assert(unloadedGroup.position.x==177 and unloadedGroup.position.y==88)

-- Compact, non-interactive corner markers distinguish regular/dynamic groups.
arrange:Start()
local regular=arrange.movers.group.groupMarker
assert(regular:IsShown() and regular.letter:IsShown() and regular.letter:GetText()=='G')
assert(regular.anchor[1]=='TOPLEFT' and regular.anchor[3]=='TOPLEFT')
assert(regular:GetWidth()==14 and regular:GetHeight()==14 and not regular.mouseEnabled)
assert(regular.letter.textColor[2]>regular.letter.textColor[1])
assert(not regular.arrow[1]:IsShown() and not arrange.movers.aura.groupMarker:IsShown())
local marker=arrange.movers.dynamic.groupMarker
assert(marker:IsShown() and not marker.letter:IsShown())
for direction,angle in pairs({DOWN=0,UP=math.pi,RIGHT=math.pi/2,LEFT=-math.pi/2}) do
  dynamic.display.growth=direction; arrange:SyncMover('dynamic')
  assert(marker.arrow[1]:IsShown())
  Near(marker.arrow[1].rotation,angle)
end

-- Real load-event dispatch updates the filter; UNIT_AURA does not scan handles.
Load('Core/Events.lua')
ns.Events.providersByEvent={}
filter:SetChecked(true); filter.scripts.OnClick(filter)
unloadedGroup.loadMatched=true
ns.Events:DispatchEvent('PLAYER_LEVEL_UP')
assert(unloaded:IsShown() and unloaded.loaded)
Near(unloaded.fill.color[1],.035)
arrange:Select(unloaded); arrange:BeginDrag(unloaded)
unloadedGroup.loadMatched=false
ns.Events:DispatchEvent('PLAYER_LEVEL_UP')
assert(not unloaded:IsShown() and not arrange.selected and not arrange.drag)
assert(not unloaded.scripts.OnUpdate)
local beforeLoadChecks=loadChecks
ns.Events:DispatchEvent('UNIT_AURA','player')
assert(loadChecks==beforeLoadChecks)
assert(ns.LoadEvaluator:MatchesWithAncestors(child))
group.loadMatched=false
assert(not ns.LoadEvaluator:MatchesWithAncestors(child))
group.loadMatched=true

-- A group with no loaded children leaves Loaded Only, and one child suffices.
dynamicChild.loadMatched=false
ns.Events:DispatchEvent('PLAYER_LEVEL_UP')
assert(not arrange.movers.dynamic:IsShown() and not arrange.movers.dynamic.loaded)
filter:SetChecked(false); filter.scripts.OnClick(filter)
assert(arrange.movers.dynamic:IsShown())
Near(arrange.movers.dynamic.fill.color[1],.3)
filter:SetChecked(true); filter.scripts.OnClick(filter)
local otherDynamicChild=Aura('otherDynamicChild','bar','dynamic')
ns.Events:DispatchEvent('PLAYER_LEVEL_UP')
assert(arrange.movers.dynamic:IsShown() and arrange.movers.dynamic.loaded)
assert(not ns.LoadEvaluator:MatchesWithAncestors(dynamicChild))
assert(ns.LoadEvaluator:MatchesWithAncestors(otherDynamicChild))
arrange:Finish(false,false)
print('Arrange behavior checks passed, including mixed group loading, filtering, corner markers, and load-event updates.')
''')

for source in ROOT.rglob("*.lua"):
    if ".git" not in source.parts:
        lua.execute("assert(loadstring(...))", source.read_text(encoding="utf-8-sig"))
print("All Lua files compile with Lua 5.1.")
