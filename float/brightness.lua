-----------------------------------------------------------------------------------------------------------------------
--                                        RedFlat brightness control widget                                          --
-----------------------------------------------------------------------------------------------------------------------
-- Brightness control using xbacklight or other tools
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local string = string
local awful = require("awful")
local beautiful = require("beautiful")

local rednotify = require("redflat.float.notify")
local redutil = require("redflat.util")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local brightness = {}

-- brightness control tools
brightness.variants = {}

brightness.variants.xbacklight = {
	increase = "xbacklight -inc %s", -- command to increase brightness
	decrease = "xbacklight -dec %s", -- command to decrease brightness
	update = "xbacklight -get", -- command to get current brightness (use only if increase/decrease doesn't return it)
}

--brightness.variants.script = {
--	increase = "~/.config/awesome/scripts/brightness.py --inc=%s",
--	decrease = "~/.config/awesome/scripts/brightness.py --dec=%s",
--}

-- Generate default theme and other settings
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		notify = {},
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "float.brightness") or {})
end

local default_args = { down = false, step = 2 }
brightness.default_variant = brightness.variants.xbacklight


-- Change brightness level
-----------------------------------------------------------------------------------------------------------------------

-- Parse command output and show brightness notification by result
------------------------------------------------------------
function brightness._notify_from_output(output)
	if not brightness.style then brightness.style = default_style() end

	rednotify:show(redutil.table.merge(
		{ value = output / 100, text = string.format('%.0f', output) .. "%" },
		brightness.style.notify
	))
end

-- Change brightness
------------------------------------------------------------
function brightness:change(args, variant)
	args = redutil.table.merge(default_args, args or {})
	variant = variant or brightness.default_variant

	local command_pattern = args.down and variant.decrease or variant.increase
	local command = string.format(command_pattern, args.step)

	local handler = self:build_change_handler(variant)
	awful.spawn.easy_async_with_shell(command, handler)
end

-- Build brightness change callback function depending on brightness tool
------------------------------------------------------------
function brightness:build_change_handler(variant)
	if variant.update then
		return function() self:notify_from_command(variant.update) end
	else
		return self._notify_from_output
	end
end

-- Show current brightness
------------------------------------------------------------
function brightness:notify_from_command(command)
	awful.spawn.easy_async(command, self._notify_from_output)
end

-- DEPRECATED! Change brightness with xbacklight tool
------------------------------------------------------------
function brightness:change_with_xbacklight(args)
	self:change(args, self.variants.xbacklight)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return brightness
