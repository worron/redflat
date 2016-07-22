-----------------------------------------------------------------------------------------------------------------------
--                                        RedFlat brightness control widget                                          --
-----------------------------------------------------------------------------------------------------------------------
-- Brightness control using xbacklight
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
local brightness = {}

local defaults = { down = false, step = 2 }

-- Change brightness level
-----------------------------------------------------------------------------------------------------------------------
function brightness:change(args)
	local args = redutil.table.merge(defaults, args or {})
	if args.step > 0 then
		if args.down then
			asyncshell.request("xbacklight -dec " .. args.step, function(_) self:update_info() end)
		else
			asyncshell.request("xbacklight -inc " .. args.step, function(_) self:update_info() end)
		end
	end
end

-- Update brightness level info
-----------------------------------------------------------------------------------------------------------------------
function brightness:update_info()
	local b = awful.util.pread("xbacklight -get")
	rednotify:show({
		value = b/100,
		text = string.format('%.0f', b) .. "%",
		icon = beautiful.float.brightness.notify_icon
	})
end

-----------------------------------------------------------------------------------------------------------------------
return brightness
