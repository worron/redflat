-----------------------------------------------------------------------------------------------------------------------
--                                               RedFlat minitray                                                    --
-----------------------------------------------------------------------------------------------------------------------
-- Tray located on separate wibox
-- minitray:toggle() used to show/hide wibox
-- Widget with graphical counter to show how many apps placed in the system tray
-----------------------------------------------------------------------------------------------------------------------
-- Some code was taken from
------ minitray
------ http://awesome.naquadah.org/wiki/Minitray
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local table = table
local ipairs = ipairs

local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local timer = require("gears.timer")

local redutil = require("redflat.util")
local dotcount = require("redflat.gauge.graph.dots")
local tooltip = require("redflat.float.tooltip")


-- Initialize tables and wibox
-----------------------------------------------------------------------------------------------------------------------
local minitray = { widgets = {}, mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		dotcount     = {},
		geometry     = { height = 40 },
		set_position = nil,
		screen_gap   = 0,
		border_width = 2,
		color        = { wibox = "#202020", border = "#575757" }
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.minitray") or {})
end

-- Initialize minitray floating window
-----------------------------------------------------------------------------------------------------------------------
function minitray:init(style)

	-- Create wibox for tray
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border
	})

	self.wibox:geometry(style.geometry)

	self.geometry = style.geometry
	self.screen_gap = style.screen_gap
	self.set_position = style.set_position

	-- Create tooltip
	--------------------------------------------------------------------------------
	self.tp = tooltip({}, style.tooltip)

	-- Set tray
	--------------------------------------------------------------------------------
	local l = wibox.layout.align.horizontal()
	l:set_middle(wibox.widget.systray())
	self.wibox:set_widget(l)
end

-- Show/hide functions for wibox
-----------------------------------------------------------------------------------------------------------------------

-- Show
--------------------------------------------------------------------------------
function minitray:show()

	-- Force upsdate all widgets
	------------------------------------------------------------
	for _, w in ipairs(self.widgets) do
		w:update()
	end

	-- Set wibox size and position
	------------------------------------------------------------
	local items = awesome.systray()
	if items == 0 then items = 1 end

	self.wibox:geometry({ width = self.geometry.width or self.geometry.height * items })
	if self.set_position then
		self.wibox:geometry(self.set_position())
	else
		awful.placement.under_mouse(self.wibox)
	end
	redutil.placement.no_offscreen(self.wibox, self.screen_gap, mouse.screen.workarea)

	-- Show
	------------------------------------------------------------
	self.wibox.visible = true
end

-- Hide
--------------------------------------------------------------------------------
function minitray:hide()
	self.wibox.visible = false
end

-- Toggle
--------------------------------------------------------------------------------
function minitray:toggle()
	if self.wibox.visible then
		self:hide()
	else
		self:show()
	end
end

-- Create a new tray widget
-- @param args.timeout Update interval
-- @param style Settings for dotcount widget
-----------------------------------------------------------------------------------------------------------------------
function minitray.new(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local args = args or {}
	local timeout = args.timeout or 60

	local style = redutil.table.merge(default_style(), style or {})

	-- Initialize minitray window
	--------------------------------------------------------------------------------
	if not minitray.wibox then
		minitray:init(style)
	end

	-- Create tray widget
	--------------------------------------------------------------------------------
	local widg = dotcount(style.dotcount)
	table.insert(minitray.widgets, widg)

	-- Set tooltip
	--------------------------------------------------------------------------------
	minitray.tp:add_to_object(widg)

	-- Set update timer
	--------------------------------------------------------------------------------
	function widg:update()
		local appcount = awesome.systray()
		self:set_num(appcount)
		minitray.tp:set_text(appcount .. " apps")
	end

	local t = timer({ timeout = timeout })
	t:connect_signal("timeout", function() widg:update() end)
	t:start()
	--t:emit_signal("timeout")

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call minitray module as function
-----------------------------------------------------------------------------------------------------------------------
function minitray.mt:__call(...)
	return minitray.new(...)
end

return setmetatable(minitray, minitray.mt)
