-----------------------------------------------------------------------------------------------------------------------
--                                                  RedFlat tooltip                                                  --
-----------------------------------------------------------------------------------------------------------------------
-- Simple wrapper around awful.tooltip v4.0
-- Just to be able set appearance arguments by beautiful themes

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local awful = require("awful")
local beautiful = require("beautiful")

local redutil = require("redflat.util")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local tooltip = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		margin_leftright = 5,
		margin_topbottom = 3,
	}
	return redutil.table.merge(style, redutil.check(beautiful, "float.tooltip") or {})
end

-- Create a new tooltip
-----------------------------------------------------------------------------------------------------------------------
function tooltip.new(args, style)
	local args = args or {}
	local style = redutil.table.merge(default_style(), style or {})

	for k, v in pairs(style) do
		if not args[k] then args[k] = v end
	end

	return awful.tooltip(args)
end

-- Config metatable to call tooltip module as function
-----------------------------------------------------------------------------------------------------------------------
function tooltip.mt:__call(...)
	return tooltip.new(...)
end

return setmetatable(tooltip, tooltip.mt)
