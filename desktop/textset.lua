-----------------------------------------------------------------------------------------------------------------------
--                                             RedFlat desktop text widget                                           --
-----------------------------------------------------------------------------------------------------------------------
-- Advanced text widget
-----------------------------------------------------------------------------------------------------------------------

local setmetatable = setmetatable
local textbox = require("wibox.widget.textbox")
local beautiful = require("beautiful")

local lgi = require("lgi")
local Pango = lgi.Pango

local redutil = require("redflat.util")
local asyncshell = require("redflat.asyncshell")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local textset = { mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		font  = "Sans 12",
		spacing = 0,
		color = { gray = "#525252" }
	}
	return redutil.table.merge(style, redutil.check(beautiful, "desktop.textset") or {})
end

-- Create a textset widget. It draws the time it is in a textbox.
-- @param format The time format. Default is " %a %b %d, %H:%M ".
-- @param timeout How often update the time. Default is 60.
-- @return A textbox widget
-----------------------------------------------------------------------------------------------------------------------
function textset.new(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local args = args or {}
	local funcarg = args.arg or {}
	local timeout = args.timeout or { 60 }
	local actions = args.actions or {}
	local style = redutil.table.merge(default_style(), style or {})

	-- Create widget
	--------------------------------------------------------------------------------
	local widg = textbox()
	widg:set_font(style.font)
	widg:set_valign("top")
	widg._layout:set_justify(true)
	widg._layout:set_spacing(Pango.units_from_double(style.spacing))

	-- !!! dirty fix for original awesome textbox v3.5.6 to avoid cutting edges !!!
	local edge_fix = 5 -- px

	function widg:draw(wibox, cr, width, height)
		cr:update_layout(self._layout)

		self._layout.width = Pango.units_from_double(width - 2 * edge_fix)
		self._layout.height = Pango.units_from_double(height)

		local ink, logical = self._layout:get_pixel_extents()
		local offset = 0

		if     self._valign == "center" then offset = (height - logical.height) / 2
		elseif self._valign == "bottom" then offset = height - logical.height end

		cr:move_to(edge_fix, offset)
		cr:show_layout(self._layout)
	end

	-- data setup
	local data = {}
	local timers = {}
	for i = 1, #actions do data[i] = "" end

	-- update info function
	local function update()
		local state = ""
		for _, txt in ipairs(data) do state = state .. txt end
		widg:set_markup(string.format('<span color="%s">%s</span>', style.color.gray, state))
	end

	-- Set update timers
	--------------------------------------------------------------------------------
	for i, action in ipairs(actions) do
		timers[i] = timer({ timeout = timeout[i] or timeout[1] })
		if args.acync then
			timers[i]:connect_signal("timeout", function()
				asyncshell.request(args.acync[i], function(o) data[i] = action(o); update() end, timeout[i])
			end)
		else
			timers[i]:connect_signal("timeout", function()
				data[i] = action(funcarg[i])
				update()
			end)
		end
		timers[i]:start()
		timers[i]:emit_signal("timeout")
	end

	--------------------------------------------------------------------------------
	return widg
end

-- Config metatable to call textset module as function
-----------------------------------------------------------------------------------------------------------------------
function textset.mt:__call(...)
	return textset.new(...)
end

return setmetatable(textset, textset.mt)
