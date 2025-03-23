-----------------------------------------------------------------------------------------------------------------------
--                                   RedFlat pulseaudio volume control widget                                        --
-----------------------------------------------------------------------------------------------------------------------
-- Indicate and change volume level using pactl
-----------------------------------------------------------------------------------------------------------------------
-- Some code was taken from
------ Pulseaudio volume control
------ https://github.com/orofarne/pulseaudio-awesome/blob/master/pulseaudio.lua
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local math = math
local table = table
local tonumber = tonumber
local string = string
local setmetatable = setmetatable
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local naughty = require("naughty")

local tooltip = require("redflat.float.tooltip")
local audio = require("redflat.gauge.audio.blue")
local rednotify = require("redflat.float.notify")
local redutil = require("redflat.util")


-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local pulse = { widgets = {}, mt = {} }
pulse.startup_time = 4

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		notify      = {},
		widget      = audio.new,
		audio       = {}
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.pulse") or {})
end

local change_volume_default_args = {
	down        = false,
	step        = 5, -- percentage
	show_notify = false
}

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function get_default_sink(args)
	args = args or {}
	local type_ = args.type or "sink"

	local cmd = string.format("pactl get-default-%s", type_)
	local output = redutil.read.output(cmd)
	local def_sink = string.match(output, "(.+)\r?\n")

	return def_sink
end

-- Change volume level
-----------------------------------------------------------------------------------------------------------------------
function pulse:change_volume(args)

	-- initialize vars
	args = redutil.table.merge(change_volume_default_args, args or {})
	local diff = args.down and -args.step or args.step

	-- get current volume
	local current_volume = self:get_volume()
	local new_volume = current_volume + diff

	if new_volume > 100 then
		new_volume = 100
	elseif new_volume < 0 then
		new_volume = 0
	end

	-- set new volume
	awful.spawn(string.format("pactl set-%s-volume %s %s%%", self._type, self._sink, new_volume))

	-- show notify if need
	if args.show_notify then
		rednotify:show(redutil.table.merge({ value = new_volume / 100, text = new_volume .. "%" }, self._style.notify))
	end

	-- update widgets value
	self:set_value(new_volume / 100)
	self._tooltip:set_text(new_volume .. "%")
end

-- Toggle mute
-----------------------------------------------------------------------------------------------------------------------
function pulse:mute()
	if not self._type or not self._sink then return end

	self:set_pa_mute(not self:is_pa_muted())
end


-- Get mute
-----------------------------------------------------------------------------------------------------------------------
function pulse:is_pa_muted()
	local mute_info = redutil.read.output(string.format("pactl get-%s-mute %s", self._type, self._sink))
	return string.find(mute_info, "yes")
end


-- Set mute
-----------------------------------------------------------------------------------------------------------------------
function pulse:set_pa_mute(is_mute)
	local mute_str = is_mute and "yes" or "no"
	awful.spawn(string.format("pactl set-%s-mute %s %s", self._type, self._sink, mute_str))
	self:set_mute(is_mute)
end


-- Get volume level in percentage
-----------------------------------------------------------------------------------------------------------------------
function pulse:get_volume(args)
	args = args or {}

	if args.sink_update then
		self._sink = get_default_sink({ type = self._type })
	end

	if not self._type or not self._sink then return 0 end

	local cmd = string.format("pactl get-%s-volume %s", self._type, self._sink)
	local output = redutil.read.output(cmd)
	local volume_percentage = string.match(output, "(%d+)%%")

	return tonumber(volume_percentage)
end

-- Update volume level info
-----------------------------------------------------------------------------------------------------------------------
function pulse:update_volume(args)
	args = args or {}
	if args.sink_update then
		self._sink = get_default_sink({ type = self._type })
	end
	if not self._type or not self._sink then return end

	-- initialize vars
	local volume = self:get_volume()

	-- update widgets value
	self:set_value(volume / 100)
	self._tooltip:set_text(volume .. "%")
end


-- Update pa info
-----------------------------------------------------------------------------------------------------------------------
function pulse:update_state(args)
	self:update_volume(args)
	self:update_mute(args)
end


-- Update mute state
-----------------------------------------------------------------------------------------------------------------------
function pulse:update_mute(args)
	args = args or {}
	if args.sink_update then
		self._sink = get_default_sink({ type = self._type })
	end
	if not self._type or not self._sink then return end

	-- initialize vars
	local is_muted = self:is_pa_muted()

	-- update widgets value
	self:set_mute(is_muted)
end

-- Create a new pulse widget
-- @param timeout Update interval
-----------------------------------------------------------------------------------------------------------------------
function pulse.new(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	style = redutil.table.merge(default_style(), style or {})

	args = args or {}
	local timeout = args.timeout or 5
	local autoupdate = args.autoupdate or false

	-- create widget
	--------------------------------------------------------------------------------
	local widg = style.widget(style.audio)
	gears.table.crush(widg, pulse, true) -- dangerous since widget have own methods, but let it be by now

	widg._type = args.type or "sink"
	widg._sink = args.sink
	widg._style = style

	table.insert(pulse.widgets, widg)

	-- Set tooltip
	--------------------------------------------------------------------------------
	widg._tooltip = tooltip({ objects = { widg } }, style.tooltip)

	-- Set update timer
	--------------------------------------------------------------------------------
	if autoupdate then
		local t = gears.timer({ timeout = timeout })
		t:connect_signal("timeout", function() widg:update_state({ sink_update = true }) end)
		t:start()
	end

	-- Set startup timer
	-- This is workaround if module activated bofore pulseaudio servise start
	--------------------------------------------------------------------------------
	if not widg._sink then
		local st = gears.timer({ timeout = 1 })
		local counter = 0
		st:connect_signal("timeout", function()
			counter = counter + 1
			widg._sink = get_default_sink({ type = widg._type })
			if widg._sink then widg:update_state() end
			if counter > pulse.startup_time or widg._sink then st:stop() end
		end)
		st:start()
	else
		widg:update_state()
	end

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call pulse module as function
-----------------------------------------------------------------------------------------------------------------------
function pulse.mt:__call(...)
	return pulse.new(...)
end

return setmetatable(pulse, pulse.mt)
