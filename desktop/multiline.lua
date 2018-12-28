-----------------------------------------------------------------------------------------------------------------------
--                                         RedFlat dashpack desktop widget                                           --
-----------------------------------------------------------------------------------------------------------------------
-- Multi monitoring widget
-- Several lines with progressbar, label and text
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local string = string
local unpack = unpack

local wibox = require("wibox")
local beautiful = require("beautiful")
local timer = require("gears.timer")

local redutil = require("redflat.util")
local svgbox = require("redflat.gauge.svgbox")
local lines = require("redflat.desktop.common.pack.lines")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local dashpack = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		icon      = { image = nil, margin = { 0, 0, 0, 0 } },
		lines     = {},
		digit_num = 3,
		unit      = { { "B", -1 }, { "KB", 1024 }, { "MB", 1024^2 }, { "GB", 1024^3 } },
		color     = { main = "#b1222b", wibox = "#161616", gray = "#404040" }
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "desktop.multiline") or {})
end

local default_geometry = { width = 200, height = 100, x = 100, y = 100 }
local default_args = { names = {}, textadd = "", timeout = 60, sensors = {} }

-- Create a new widget
-----------------------------------------------------------------------------------------------------------------------
function dashpack.new(args, geometry, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local dwidget = {}
	local args = redutil.table.merge(default_args, args or {})
	local geometry = redutil.table.merge(default_geometry, geometry or {})
	local style = redutil.table.merge(default_style(), style or {})

	-- Create wibox
	--------------------------------------------------------------------------------
	dwidget.wibox = wibox({ type = "desktop", visible = true, bg = style.color.wibox })
	dwidget.wibox:geometry(geometry)

	-- initialize progressbar lines
	local lines_style = redutil.table.merge(style.lines, { color = style.color })
	local pack = lines(#args.sensors, lines_style)

	-- add icon if needed
	if style.icon.image then
		dwidget.icon = svgbox(style.icon.image)
		dwidget.icon:set_color(style.color.gray)

		local align = wibox.layout.align.horizontal()
		align:set_middle(pack.layout)
		align:set_left(wibox.container.margin(dwidget.icon, unpack(style.icon.margin)))
		dwidget.wibox:set_widget(align)
	else
		dwidget.wibox:set_widget(pack.layout)
	end

	for i, name in ipairs(args.names) do
		pack:set_label(string.upper(name), i)
	end

	-- Update info function
	--------------------------------------------------------------------------------
	local function update()
		local ico_alert = false
		for i, sens in ipairs(args.sensors) do
			local state = sens.meter_function(sens.args)
			local alert = sens.crit and state[1] > sens.crit
			local text_color = alert and style.color.main or style.color.gray

			ico_alert = ico_alert or alert
			pack:set_values(state[1] / sens.maxm, i)
			pack:set_label_color(text_color, i)

			if style.lines.show_text or style.lines.show_tooltip then
				pack:set_text(redutil.text.dformat(state[2] or state[1], style.unit, style.digit_num), i)
				pack:set_text_color(text_color, i)
			end
		end

		if style.icon.image then
			dwidget.icon:set_color(ico_alert and style.color.main or style.color.gray)
		end
	end

	-- Set update timer
	--------------------------------------------------------------------------------
	local t = timer({ timeout = args.timeout })
	t:connect_signal("timeout", update)
	t:start()
	t:emit_signal("timeout")

	--------------------------------------------------------------------------------
	return dwidget
end

-- Config metatable to call module as function
-----------------------------------------------------------------------------------------------------------------------
function dashpack.mt:__call(...)
	return dashpack.new(...)
end

return setmetatable(dashpack, dashpack.mt)
