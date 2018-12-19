-----------------------------------------------------------------------------------------------------------------------
--                                       RedFlat desktop progressbar widget                                          --
-----------------------------------------------------------------------------------------------------------------------
-- Dashed horizontal progress bar
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
local progressbar = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		maxm        = 1,
		width       = nil,
		height      = nil,
		chunk       = { gap = 5, width = 5 },
		autoscale   = false,
		color       = { main = "#b1222b", gray = "#404040" }
	}

	return redutil.table.merge(style, redutil.table.check(beautiful, "desktop.common.progressbar") or {})
end

-- Cairo drawing functions
-----------------------------------------------------------------------------------------------------------------------

local function draw_progressbar(cr, width, height, gap, first_point, last_point, fill_color)
	cr:set_source(color(fill_color))
	for i = first_point, last_point do
		cr:rectangle((i - 1) * (width + gap), 0, width, height)
	end
	cr:fill()
end

-- Create a new progressbar widget
-- @param style.chunk Table containing dash parameters
-- @param style.color.main Main color
-- @param style.width Widget width (optional)
-- @param style.height Widget height (optional)
-- @param style.autoscale Scaling received values, true by default
-- @param style.maxm Scaling value if autoscale = false
-----------------------------------------------------------------------------------------------------------------------
function progressbar.new(style)

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
	local widg = wibox.widget.base.make_widget()

	function widg:set_value(x)
		if style.autoscale then
			if x > maxm then maxm = x end
		end

		local cx = x / maxm
		if cx > 1 then cx = 1 end
		data.value = cx
		self:emit_signal("widget::updated")
	end

	function widg:fit(_, width, height)
		return style.width or width, style.height or height
	end

	-- Draw function
	------------------------------------------------------------
	function widg:draw(_, cr, width, height)

		-- progressbar
		local barnum = math.floor((width + style.chunk.gap) / (style.chunk.width + style.chunk.gap))
		local real_gap = style.chunk.gap + (width - (barnum - 1) * (style.chunk.width + style.chunk.gap)
		                 - style.chunk.width) / (barnum - 1)
		local point = math.ceil(barnum * data.value)

		draw_progressbar(cr, style.chunk.width, height, real_gap, 1, point, style.color.main)
		draw_progressbar(cr, style.chunk.width, height, real_gap, point + 1, barnum, style.color.gray)
	end
	--------------------------------------------------------------------------------

	return widg
end

-- Config metatable to call progressbar module as function
-----------------------------------------------------------------------------------------------------------------------
function progressbar.mt:__call(...)
	return progressbar.new(...)
end

return setmetatable(progressbar, progressbar.mt)
