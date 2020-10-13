-----------------------------------------------------------------------------------------------------------------------
--                                             RedFlat calendar widget                                               --
-----------------------------------------------------------------------------------------------------------------------
-- A stylable widget wrapping wibox.widget.calendar
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local unpack = unpack or table.unpack

local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local timer = require("gears.timer")

local lgi = require("lgi")
local Pango = lgi.Pango
local PangoCairo = lgi.PangoCairo
local DateTime = lgi.GLib.DateTime
local TimeZone = lgi.GLib.TimeZone

local redutil = require("redflat.util")
local svgbox = require("redflat.gauge.svgbox")
local separator = require("redflat.gauge.separator")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local calendar = {}

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		geometry                  = { width = 340, height = 420 },
		margin                    = { 20, 20, 20, 15 },
		controls_margin           = { 0, 0, 0, 4 },
		calendar_item_margin      = { 2, 5, 2, 2 },
		spacing                   = { separator = 28, datetime = 5, controls = 5, calendar = 8 },
		controls_icon_size        = { width = 24, height = 24 },
		separator                 = {},
		border_width              = 2,
		color                     = { border = "#575757", wibox = "#202020", icon = "#a0a0a0",
		                              main = "#b1222b", highlight = "#202020",
		                              gray = "#575757", text = "#a0a0a0" },
		days                      = { weeknumber = { fg = "#575757", bg = "transparent" },
		                              weekday    = { fg = "#575757", bg = "transparent" },
		                              weekend    = { fg = "#a0a0a0", bg = "#333333" },
		                              today      = { fg = "#a0a0a0", bg = "#b1222b" },
		                              day        = { fg = "#a0a0a0", bg = "transparent" },
		                              default    = { fg = "white",   bg = "transparent" } },
		fonts                     = { clock           = "Sans 24",
		                              date            = "Sans 15",
		                              week_numbers    = "Sans 12",
		                              weekdays_header = "Sans 11",
		                              days            = "Sans 12",
		                              default         = "Sans 10",
		                              focus           = "Sans 14 Bold",
		                              controls        = "Sans 13" },
		icon                      = { next   = redutil.base.placeholder({ txt = "►" }),
		                              prev   = redutil.base.placeholder({ txt = "◄" }), },
		clock_format              = "%H:%M",
		date_format               = "%A, %d. %B",
		clock_refresh_seconds     = 60,
		weeks_start_sunday        = false,
		show_week_numbers         = true,
		show_weekday_header       = true,
		long_weekdays             = false,
		weekday_name_replacements = {},
		screen_gap                = 0,
		set_position              = nil,
		shape                     = nil,
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "float.calendar") or {})
end

-- Initialize calendar widget
-----------------------------------------------------------------------------------------------------------------------
function calendar:init()
	local style = default_style()
	self.style = style

	-- Initialize the current date
	--------------------------------------------------------------------------------
	local current_date = os.date('*t')
	self.date = {
		year  = current_date.year,
		month = current_date.month,
		day   = current_date.day
	}

	-- Factory function to produce clickable buttons with icons and hover effect
	--------------------------------------------------------------------------------
	local function make_control_button(icon, action)
		local button = svgbox(icon, nil, style.color.icon)
		button:set_forced_width(style.controls_icon_size.width)
		button:set_forced_height(style.controls_icon_size.height)
		local marginbox = wibox.container.margin(button, unpack(style.controls_margin))
		local wrapper = wibox.container.background(marginbox)
		wrapper.svgbox = button

		wrapper:connect_signal("mouse::enter", function(w)
			w:set_bg(style.color.main)
			w.svgbox:set_color(style.color.highlight)
		end)
		wrapper:connect_signal("mouse::leave", function(w)
			w:set_bg("transparent")
			w.svgbox:set_color(style.color.icon)
		end)

		wrapper:buttons(awful.util.table.join(awful.button({}, 1, action)))
		return wrapper
	end

	-- Estimate the required space width of a given text using a given font
	--------------------------------------------------------------------------------
	local function get_text_width_for_font(text, font)
		local ctx = PangoCairo.font_map_get_default():create_context()
		local layout = Pango.Layout.new(ctx)
		layout.text = text
		layout:set_font_description(beautiful.get_font(font))
		local _, logical = layout:get_pixel_extents()
		return logical.width
	end

	-- Callback function to be passed as 'fn_embed' to wibox.widget.calendar.month,
	-- called on each calendar element allowing to modify its style and layout
	--------------------------------------------------------------------------------
	local function decorate_calendar_cell(widget, flag, date)

		if flag == "month" then
			-- 'month' is the grid layout of the calendar wibox itself
			-- we remove the first row from it which contains the month and year headers
			widget.spacing = style.spacing.calendar
			widget:remove_row(1)
			widget:set_forced_num_rows(widget.forced_num_rows - 1)
			if not style.show_weekday_header then
				-- remove the next row as well (the weekday header) if disabled
				widget:remove_row(1)
				widget:set_forced_num_rows(widget.forced_num_rows - 1)
			end
			return widget
		end

		-- ignore headers for styling (they are removed anyway)
		if flag == "header" or flag == "monthheader" then return widget end

		-- only display the focus marker if month and year match the current date
		if flag == "focus" then
			local now = os.date('*t')
			if now.year ~= date.year or now.month ~= date.month then
				flag = "normal"
			end
		end

		local font, bg, fg
		if flag == "weeknumber" then
			-- left side week numbers
			font = style.fonts.week_numbers
			fg = style.days.weeknumber.fg
			bg = style.days.weeknumber.bg
			widget:set_align("left")
		elseif flag == "weekday" then
			-- textual weekday headers
			font = style.fonts.weekdays_header
			fg = style.days.weekday.fg
			bg = style.days.weekday.bg
			if style.weekday_name_replacements[widget.text] ~= nil then
				widget.text = style.weekday_name_replacements[widget.text]
			end
		elseif flag == "focus" then
			-- today
			font = style.fonts.focus
			fg = style.days.today.fg
			bg = style.days.today.bg
		elseif flag == "normal" then
			font = style.fonts.days
			if date.wday == 1 or date.wday == 7 then
				-- separate styling for weekends
				fg = style.days.weekend.fg
				bg = style.days.weekend.bg
			else
				-- normal weekdays
				fg = style.days.day.fg
				bg = style.days.day.bg
			end
		else
			-- fallback style, do not know if it ever necessary
			font = style.fonts.default
			fg = style.days.default.fg
			bg = style.days.default.bg
		end

		-- style each calendar cell
	    widget:set_font(font)
	    widget:set_markup('<span color="' .. fg .. '">' .. widget.text .. '</span>')
		local widget_container = wibox.container.margin(widget, unpack(style.calendar_item_margin))
		local widget_background = wibox.container.background(
			widget_container,
			bg
		)
	    return widget_background
	end

	-- Create calendar widget
	--------------------------------------------------------------------------------
	self.calendar = wibox.widget {
		date          = self.date,
		font          = style.fonts.days,
		week_numbers  = style.show_week_numbers,
		long_weekdays = style.long_weekdays,
		start_sunday  = style.weeks_start_sunday,
		widget        = wibox.widget.calendar.month,
		fn_embed      = decorate_calendar_cell,
	}

	-- Prepare month and year labels for the date controls
	--------------------------------------------------------------------------------
	self.month_label = wibox.widget.textbox()
	self.month_label.align = "center"
	self.month_label.font = style.fonts.controls

	self.year_label = wibox.widget.textbox()
	self.year_label.align = "center"
	self.year_label.font = style.fonts.controls

	self.update_controls = function()
		local month = os.date("%B", os.time{
			year = self.date.year,
			month = self.date.month,
			day = self.date.day}
		)
		local year = string.format("%s", self.date.year)
		self.month_label:set_markup('<span color="' .. style.color.text .. '">' .. month .. '</span>')
		self.year_label:set_markup('<span color="' .. style.color.text .. '">' .. year .. '</span>')
	end
	self:update_controls()

	-- Create clock and date display
	--------------------------------------------------------------------------------
	local datetime_panel = wibox.layout.fixed.vertical()
	datetime_panel.spacing = style.spacing.datetime

	self.clock_label = wibox.widget.textbox()
	self.clock_label.align = "left"
	self.clock_label.font = style.fonts.clock
	datetime_panel:add(self.clock_label)

	self.date_label = wibox.widget.textbox()
	self.date_label.align = "left"
	self.date_label.font = style.fonts.date
	datetime_panel:add(self.date_label)

	self.update_datetime = function()
		local now = DateTime.new_now(TimeZone.new_local())
		local date = now:format(style.date_format)
		local time = now:format(style.clock_format)
		self.clock_label:set_markup('<span color="' .. style.color.text .. '">' .. time .. '</span>')
		self.date_label:set_markup('<span color="' .. style.color.gray .. '">' .. date .. '</span>')
	end

	self.update_datetime_timer = timer({ timeout = style.clock_refresh_seconds })
	self.update_datetime_timer:connect_signal("timeout", function() self:update_datetime() end)
	self.update_datetime_timer:emit_signal("timeout")

	-- Create button panel for month and year controls and labels
	--------------------------------------------------------------------------------
	local controls_panel = wibox.layout.align.horizontal()

	local year_control = wibox.layout.fixed.horizontal()
	local year_width = get_text_width_for_font(" 9999 ", style.fonts.controls)
	year_control.fill_space = false
	year_control.spacing = style.spacing.controls
	year_control:add(make_control_button(style.icon.prev, function() self:switch_year(-1) end))
	year_control:add(wibox.container.constraint(self.year_label, "exact", year_width, nil))
	year_control:add(make_control_button(style.icon.next, function() self:switch_year(1) end))
	controls_panel:set_right(year_control)

	local month_control = wibox.layout.fixed.horizontal()
	local month_width = get_text_width_for_font(" September ", style.fonts.controls)
	month_control.fill_space = false
	month_control.spacing = style.spacing.controls
	month_control:add(make_control_button(style.icon.prev, function() self:switch_month(-1) end))
	month_control:add(wibox.container.constraint(self.month_label, "exact", month_width, nil))
	month_control:add(make_control_button(style.icon.next, function() self:switch_month(1) end))
	controls_panel:set_left(month_control)

	local layout_separator = separator.horizontal(style.separator)

	local layout = wibox.layout.fixed.vertical()
	layout.spacing_widget = layout_separator
	layout.spacing = style.spacing.separator
	layout:add(datetime_panel)
	layout:add(self.calendar)
	layout:add(controls_panel)

	-- Create floating wibox for calendar
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border,
		shape        = style.shape
	})
	self.wibox:set_widget(wibox.container.margin(layout, unpack(style.margin)))
	self.wibox:geometry(style.geometry)
end

function calendar:show_date(year, month, day)
	local current_date = os.date('*t')
	self.date.year = year or current_date.year
	self.date.month = month or current_date.month
	self.date.day = day or current_date.day
	self.calendar:set_date({
		year = self.date.year,
		month = self.date.month,
		day = self.date.day
	})
	self:update_controls()
end

function calendar:switch_month(offset)
	local month = self.date.month + offset
	local year = self.date.year
	while month > 12 do
		month = month - 12
		year = year + 1
	end
	while month < 1 do
		month = month + 12
		year = year - 1
	end
	self:show_date(year, month)
end

function calendar:switch_year(offset)
	local year = self.date.year + offset
	self:show_date(year, self.date.month)
end

-- Show calendar widget or hide if visible
-----------------------------------------------------------------------------------------------------------------------
function calendar:show(geometry)
	if not self.wibox then self:init() end
	if not self.wibox.visible then
		self:show_date()

		if geometry then
			self.wibox:geometry(geometry)
		elseif self.style.set_position then
			self.style.set_position(self.wibox)
		else
			awful.placement.under_mouse(self.wibox)
		end
		redutil.placement.no_offscreen(self.wibox, self.style.screen_gap, screen[mouse.screen].workarea)

		self.wibox.visible = true
		self.update_datetime_timer:start()
		self.update_datetime_timer:emit_signal("timeout")
	else
		self:hide()
	end
end

-- Hide calendar widget
-----------------------------------------------------------------------------------------------------------------------
function calendar:hide()
	if self.update_datetime_timer.started then self.update_datetime_timer:stop() end
	self.wibox.visible = false
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return calendar
