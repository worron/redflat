-----------------------------------------------------------------------------------------------------------------------
--                                             RedFlat corners widget                                                --
-----------------------------------------------------------------------------------------------------------------------
-- Vertical progress indicator with custom shape
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local math = math
local wibox = require("wibox")
local color = require("gears.color")
local beautiful = require("beautiful")

local redutil = require("redflat.util")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local indicator = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		chunk     = { num = 10, line = 5, height = 10 },
		maxm      = 1,
		width     = nil,
		height    = nil,
		autoscale = false,
		shape     = "corner",
		color     = { main = "#b1222b", gray = "#404040" }
	}

	return redutil.table.merge(style, redutil.table.check(beautiful, "desktop.common.bar.shaped") or {})
end

-- Cairo drawing functions
-----------------------------------------------------------------------------------------------------------------------

local function draw_corner(cr, width, height, gap, first_point, last_point, fill_color, style)
	cr:set_source(color(fill_color))
	for i = first_point, last_point do
		cr:move_to(0, height - (i - 1) * (style.chunk.line + gap))
		cr:rel_line_to(width / 2, - style.chunk.height)
		cr:rel_line_to(width / 2, style.chunk.height)
		cr:rel_line_to(- style.chunk.line, 0)
		cr:rel_line_to(- width / 2 + style.chunk.line, - style.chunk.height + style.chunk.line)
		cr:rel_line_to(- width / 2 + style.chunk.line, style.chunk.height - style.chunk.line)
		cr:close_path()
	end
	cr:fill()
end

local function draw_line(cr, width, height, dy, first_point, last_point, fill_color, style)
	cr:set_source(color(fill_color))
	for i = first_point, last_point do
		cr:rectangle(0, height - (i - 1) * dy, width, - style.chunk.line)
	end
	cr:fill()
end

-- Create a new indicator widget
-- @param style.chunk Table containing number and sizes for progress bar chunks
-- @param style.color Main color
-- @param style.width Widget width (optional)
-- @param style.height Widget height (optional)
-- @param style.autoscale Scaling received values, true by default
-- @param style.maxm Scaling value if autoscale = false
-----------------------------------------------------------------------------------------------------------------------
function indicator.new(style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = redutil.table.merge(default_style(), style or {})
	local maxm = style.maxm

	-- updating values
	local data = {
		value = 0
	}

	-- Create custom widget
	--------------------------------------------------------------------------------
	local shapewidg = wibox.widget.base.make_widget()

	function shapewidg:set_value(x)
		if style.autoscale then
			if x > maxm then maxm = x end
		end
		local cx = x / maxm
		if cx > 1 then cx = 1 end
		data.value = cx
		self:emit_signal("widget::updated")
	end

	function shapewidg:fit(_, width, height)
		return style.width  or width, style.height or height
	end

	-- Draw function
	------------------------------------------------------------
	function shapewidg:draw(_, cr, width, height)
		local point = math.ceil(style.chunk.num * data.value)
		if style.shape == "plain" then
			local line_gap = style.chunk.line + (height - style.chunk.line * style.chunk.num)/(style.chunk.num - 1)
			draw_line(cr, width, height, line_gap, 1, point, style.color.main, style)
			draw_line(cr, width, height, line_gap, point + 1, style.chunk.num, style.color.gray, style)
		elseif style.shape == "corner" then
			local corner_gap = (height - (style.chunk.num - 1) * style.chunk.line - style.chunk.height)
			                   / (style.chunk.num - 1)
			draw_corner(cr, width, height, corner_gap, 1, point, style.color.main, style)
			draw_corner(cr, width, height, corner_gap, point + 1, style.chunk.num, style.color.gray, style)
		end
	end

	--------------------------------------------------------------------------------
	return shapewidg
end

-- Config metatable to call indicator module as function
-----------------------------------------------------------------------------------------------------------------------
function indicator.mt:__call(...)
	return indicator.new(...)
end

return setmetatable(indicator, indicator.mt)
