local _, optionsNamespace = ...

local coreNamespace = _G.PopAuras
assert(type(coreNamespace) == "table", "PopAuras_Options requires PopAuras")

setmetatable(optionsNamespace, {
  __index = coreNamespace,
})

rawset(optionsNamespace, "core", coreNamespace)
