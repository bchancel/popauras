local _, ns = ...

local Colors = {}
ns.util.Colors = Colors

function Colors.Copy(color)
  color = color or { r = 1, g = 1, b = 1, a = 1 }
  return { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = color.a == nil and 1 or color.a }
end

function Colors.Apply(target, color)
  color = color or { r = 1, g = 1, b = 1, a = 1 }
  target:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a == nil and 1 or color.a)
end
