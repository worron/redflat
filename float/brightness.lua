-----------------------------------------------------------------------------------------------------------------------
--                                        RedFlat brightness control widget                                          --
-----------------------------------------------------------------------------------------------------------------------
-- Brightness control using xbacklight
-- or using gnome/unity settings daemon
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local string = string
local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")

local rednotify = require("redflat.float.notify")
local redutil = require("redflat.util")
local asyncshell = require("redflat.asyncshell")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local brightness = { dbus_correction = 1}

local defaults = { down = false, step = 2 }

local gsd_set = "SetPercentage uint32:%d"
local gsd_get = "GetPercentage"
local gsd_command = 'dbus-send --session --print-reply --dest="org.gnome.SettingsDaemon" '
                    .. '/org/gnome/SettingsDaemon/Power '
                    .. 'org.gnome.SettingsDaemon.Power.Screen.'

-- Change brightness level
-----------------------------------------------------------------------------------------------------------------------

-- Change with xbacklight
------------------------------------------------------------
function brightness:change(args)
	local args = redutil.table.merge(defaults, args or {})

	if args.down then
		asyncshell.request("xbacklight -dec " .. args.step, self.info_with_xbacklight)
	else
		asyncshell.request("xbacklight -inc " .. args.step, self.info_with_xbacklight)
	end
end

-- Change with dbus-send and gnome/unity settings daemon
------------------------------------------------------------
function brightness:change_with_gsd(args)
	local args = redutil.table.merge(defaults, args or {})

	-- correction because of strange dbus output rounding
	local dbus_output = awful.util.pread(gsd_command .. gsd_get)
	local brightness_level = string.match(dbus_output, "uint32%s(%d+)") + self.dbus_correction

	-- increase/decrease
	brightness_level = args.down and (brightness_level - args.step) or (brightness_level + args.step)

	-- 1 .. 99 only because of correction bug
	if     brightness_level > 99 then brightness_level = 99
	elseif brightness_level < 1  then brightness_level = 1
	end

	-- set and show
	awful.util.spawn_with_shell(gsd_command .. string.format(gsd_set, brightness_level))
	self.info_with_gsd(brightness_level)
end

-- Update brightness level info
-----------------------------------------------------------------------------------------------------------------------

-- Update from xbacklight
------------------------------------------------------------
function brightness.info_with_xbacklight()
	local brightness_level = awful.util.pread("xbacklight -get")

	rednotify:show({
		value = brightness_level / 100,
		text = string.format('%.0f', brightness_level) .. "%",
		icon = beautiful.float.brightness.notify_icon
	})
end

-- Update from dbus-send and gnome/unity settings daemon
------------------------------------------------------------
function brightness.info_with_gsd(brightness_level)
	if not brightness_level then
		local brightness_level = string.match(awful.util.pread(gsd_command .. gsd_get), "uint32%s(%d+)")
	end

	rednotify:show({
		value = brightness_level / 100,
		text = brightness_level .. "%",
		icon = beautiful.float.brightness.notify_icon
	})
end

-----------------------------------------------------------------------------------------------------------------------
return brightness
