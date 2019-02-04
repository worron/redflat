-----------------------------------------------------------------------------------------------------------------------
--                                       Red Flat calendar desktop widget                                            --
-----------------------------------------------------------------------------------------------------------------------
-- Multi monitoring widget
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local os = os
local string = string
local setmetatable = setmetatable

local wibox = require("wibox")
local beautiful = require("beautiful")
local color = require("gears.color")
local timer = require("gears.timer")

local redutil = require("redflat.util")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local calendar = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		label       = { gap = 12, font = { font = "Sans", size = 18, face = 1, slant = 0 }, sep = "-" },
		mark        = { height = 20, width = 40, dx = 10, line = 4 },
		color       = { main = "#b1222b", wibox = "#161616", gray = "#404040", bg = "#161616" }
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "desktop.calendar") or {})
end

local default_geometry = { width = 120, height = 720, x = 0, y = 0 }
local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function is_leap_year(year)
	return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

-- Drawing function
-----------------------------------------------------------------------------------------------------------------------
local function daymarks(style)

	-- Create custom widget
	--------------------------------------------------------------------------------
	local widg = wibox.widget.base.make_widget()

	widg._data = {
		days = 31,
		marks = 31,
		today = 1,
		label = "01-01",
		weekend = { 6, 0 }
	}

	-- User functions
	------------------------------------------------------------
	function widg:update_data()
		local date = os.date('*t')
		local first_week_day = os.date('%w', os.time({ year = date.year, month = date.month, day = 1 }))

		self._data.today = date.day
		self._data.days = date.month == 2 and is_leap_year(date.year) and 29 or days_in_month[date.month]
		self._data.weekend = { (7 - first_week_day) % 7, (8 - first_week_day) % 7 }
		self._data.label = string.format("%.2d%s%.2d", date.day, style.label.sep, date.month)

		self:emit_signal("widget::updated")
	end

	-- Fit
	------------------------------------------------------------
	function widg:fit(_, width, height)
		return width, height
	end

	-- Draw
	------------------------------------------------------------
	function widg:draw(_, cr, width, height)

		-- main draw
		local gap = (height - self._data.days * style.mark.height) / (self._data.days - 1)
		local label_x = width - style.mark.width - style.mark.dx - style.label.gap
		cr:set_line_width(style.mark.line)

		for i = 1, self._data.days do
			-- calendar marks
			local id = i % 7
			local is_weekend = id == self._data.weekend[1] or id == self._data.weekend[2]

			cr:set_source(color(is_weekend and style.color.main or style.color.gray))
			cr:move_to(width, (style.mark.height + gap) * (i - 1))
			cr:rel_line_to(0, style.mark.height)
			cr:rel_line_to(-style.mark.width, 0)
			cr:rel_line_to(-style.mark.dx, -style.mark.height / 2)
			cr:rel_line_to(style.mark.dx, -style.mark.height / 2)
			cr:close_path()
			cr:fill()

			if i == self._data.today then
				-- today label
				cr:set_source(color(style.color.main))
				local coord_y = ((style.mark.height + gap) * (i - 1)) + style.mark.height / 2
				redutil.cairo.set_font(cr, style.label.font)

				local ext = cr:text_extents(self._data.label)
				cr:move_to(label_x - (ext.width + 2 * ext.x_bearing), coord_y - (ext.height/2 + ext.y_bearing))
				cr:show_text(self._data.label)
			end
		end
	end

	--------------------------------------------------------------------------------
	return widg
end


-- Create a new widget
-----------------------------------------------------------------------------------------------------------------------
function calendar.new(args, geometry, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local dwidget = {}
	local args = args or {}
	local geometry = redutil.table.merge(default_geometry, geometry or {})
	local style = redutil.table.merge(default_style(), style or {})
	local timeout = args.timeout or 300

	-- Create wibox
	--------------------------------------------------------------------------------
	dwidget.wibox = wibox({ type = "desktop", visible = true, bg = style.color.wibox })
	dwidget.wibox:geometry(geometry)

	-- Create calendar widget
	--------------------------------------------------------------------------------
	dwidget.calendar = daymarks(style)
	dwidget.wibox:set_widget(dwidget.calendar)

	-- Set update timer
	--------------------------------------------------------------------------------
	local t = timer({ timeout = timeout })
	t:connect_signal("timeout", function () dwidget.calendar:update_data() end)
	t:start()
	t:emit_signal("timeout")

	--------------------------------------------------------------------------------
	return dwidget
end

-- Config metatable to call module as function
-----------------------------------------------------------------------------------------------------------------------
function calendar.mt:__call(...)
	return calendar.new(...)
end

return setmetatable(calendar, calendar.mt)
