-----------------------------------------------------------------------------------------------------------------------
--                                        RedFlat floating window manager                                            --
-----------------------------------------------------------------------------------------------------------------------
-- Widget to control single flating window size and posioning
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local unpack = unpack or table.unpack

local beautiful = require("beautiful")
local awful     = require("awful")
local wibox     = require("wibox")

local rednotify = require("redflat.float.notify")
local redutil   = require("redflat.util")
local redtip    = require("redflat.float.hotkeys")
local svgbox    = require("redflat.gauge.svgbox")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local control = {}

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		geometry      = { width = 400, height = 60 },
		border_width  = 2,
		font          = "Sans 14",
		set_position  = nil,
		notify        = {},
		keytip        = { geometry = { width = 600 } },
		shape         = nil,
		steps         = { 1, 10, 20, 50 },
		default_step  = 2,
		is_resizing   = false,
		onscreen      = true,
		margin        = { icon = { onscreen = { 10, 10, 2, 2 }, mode = { 10, 10, 2, 2 } } },
		icon          = {
			move     = redutil.base.placeholder({ txt = "M" }),
			resize   = redutil.base.placeholder({ txt = "R" }),
			onscreen = redutil.base.placeholder({ txt = "X" }),
		},
		color         = { border = "#575757", text = "#aaaaaa", main = "#b1222b", wibox = "#202020",
		                  gray = "#575757", icon = "#a0a0a0" },
	}

	return redutil.table.merge(style, redutil.table.check(beautiful, "float.bartip") or {})
end

-- key bindings
control.keys = {}
control.keys.control = {
	{
		{ "Mod4" }, "c", function() control:center() end,
		{ description = "Put window at the center", group = "Window control" }
	},
	{
		{ "Mod4" }, "q", function() control:resize() end,
		{ description = "Increase window size", group = "Window control" }
	},
	{
		{ "Mod4" }, "a", function() control:resize(true) end,
		{ description = "Decrease window size", group = "Window control" }
	},
	{
		{ "Mod4" }, "l", function() control:direction_action("right") end,
		{ description = "Move/resize window to right", group = "Window control" }
	},
	{
		{ "Mod4" }, "j", function() control:direction_action("left") end,
		{ description = "Move/resize window to left", group = "Window control" }
	},
	{
		{ "Mod4" }, "k", function() control:direction_action("bottom") end,
		{ description = "Move/resize window to bottom", group = "Window control" }
	},
	{
		{ "Mod4" }, "i", function() control:direction_action("top") end,
		{ description = "Move/resize window to top", group = "Window control" }
	},
	{
		{ "Mod4" }, "n", function() control:switch_mode() end,
		{ description = "Switch moving/resizing mode", group = "Mode" }
	},
	{
		{ "Mod4" }, "s", function() control:switch_onscreen() end,
		{ description = "Switch off screen check", group = "Mode" }
	},
}
control.keys.action = {
	{
		{ "Mod4" }, "Super_L", function() control:hide() end,
		{ description = "Close top list widget", group = "Action" }
	},
	{
		{ "Mod4" }, "F1", function() redtip:show() end,
		{ description = "Show hotkeys helper", group = "Action" }
	},
}

control.keys.all = awful.util.table.join(control.keys.control, control.keys.action)

control._fake_keys = {
	{
		{}, "N", nil,
		{ description = "Select move/resize step", group = "Mode",
		  keyset = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } }
	},
}


-- Support function
-----------------------------------------------------------------------------------------------------------------------
local function control_off_screen(window)
	local wa = screen[mouse.screen].workarea
	local newg = window:geometry()

	if newg.width > wa.width then window:geometry({ width = wa.width, x = wa.x }) end
	if newg.height > wa.height then window:geometry({ height = wa.height, y = wa.y }) end

	redutil.placement.no_offscreen(window, nil, wa)
end

-- Initialize widget
-----------------------------------------------------------------------------------------------------------------------
function control:init()

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = default_style()
	self.style = style
	self.client = nil
	self.step = style.steps[style.default_step]

	self.is_resizing = style.is_resizing
	self.onscreen = style.onscreen

	-- Create floating wibox for top widget
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border,
		shape        = style.shape
	})

	self.wibox:geometry(style.geometry)

	-- Widget layout setup
	--------------------------------------------------------------------------------
	self.label = wibox.widget.textbox()
	self.label:set_align("center")
	self.label:set_font(style.font)

	self.onscreen_icon = svgbox(self.style.icon.onscreen)
	self.onscreen_icon:set_color(self.onscreen and self.style.color.main or self.style.color.icon)

	self.mode_icon = svgbox(self.is_resizing and self.style.icon.resize or self.style.icon.move)
	self.mode_icon:set_color(self.style.color.icon)

	self.wibox:setup({
		wibox.container.margin(self.onscreen_icon, unpack(self.style.margin.icon.onscreen)),
		self.label,
		wibox.container.margin(self.mode_icon, unpack(self.style.margin.icon.mode)),
		layout = wibox.layout.align.horizontal
	})

	-- Keygrabber
	--------------------------------------------------------------------------------
	self.keygrabber = function(mod, key, event)
		if event == "release" then
			for _, k in ipairs(self.keys.action) do
				if redutil.key.match_grabber(k, mod, key) then k[3](); return end
			end
		else
			for _, k in ipairs(self.keys.all) do
				if redutil.key.match_grabber(k, mod, key) then k[3](); return end
			end
			if string.match("123456789", key) then self:choose_step(tonumber(key)) end
		end
	end

	-- First run actions
	--------------------------------------------------------------------------------
	self:set_keys()
end

-- Window control
-----------------------------------------------------------------------------------------------------------------------

-- Put at center of screen
--------------------------------------------------------------------------------
function control:center()
	if not self.client then return end
	redutil.placement.centered(self.client, nil, mouse.screen.workarea)

	if self.onscreen then control_off_screen(self.client) end
	self:update()
end

-- Change window size
--------------------------------------------------------------------------------
function control:resize(is_shrinking)
	if not self.client then return end

	local g = self.client:geometry()
	local d = self.step * (is_shrinking and -1 or 1)

	self.client:geometry({ x = g.x - d, y = g.y - d, width = g.width + 2 * d, height = g.height + 2 * d })
	if self.onscreen then control_off_screen(self.client) end
	self:update()
end


-- Move/resize by direction
--------------------------------------------------------------------------------
function control:direction_action(direction)
	if not self.client then return end

	local g = self.client:geometry()

	if self.is_resizing then
		if direction == "left" then
			self.client:geometry({ x = g.x + self.step, width = g.width - 2 * self.step  })
		elseif direction == "right" then
			self.client:geometry({ x = g.x - self.step, width = g.width + 2 * self.step  })
		elseif direction == "top" then
			self.client:geometry({ y = g.y - self.step, height = g.height + 2 * self.step  })
		elseif direction == "bottom" then
			self.client:geometry({ y = g.y + self.step, height = g.height - 2 * self.step  })
		end
	else
		local d = self.step * ((direction == "left" or direction == "top") and -1 or 1)

		if direction == "left" or direction == "right" then
			self.client:geometry({ x = g.x + d })
		else
			self.client:geometry({ y = g.y + d })
		end
	end

	if self.onscreen then control_off_screen(self.client) end
	self:update()
end


-- Widget actions
-----------------------------------------------------------------------------------------------------------------------

-- Update
--------------------------------------------------------------------------------
function control:update()
	if not self.client then return end

	local g = self.client:geometry()
	local size_label = string.format("%sx%s", g.width, g.height)

	self.label:set_markup(string.format(
		'<span color="%s">%s</span><span color="%s"> [%d]</span>',
		self.style.color.text, size_label, self.style.color.gray, self.step
	))
end

-- Select move/resize step by index
--------------------------------------------------------------------------------
function control:choose_step(index)
	if self.style.steps[index] then self.step = self.style.steps[index] end
	self:update()
end

-- Switch move/resize mode
--------------------------------------------------------------------------------
function control:switch_mode()
	self.is_resizing = not self.is_resizing
	self.mode_icon:set_image(self.is_resizing and self.style.icon.resize or self.style.icon.move)
end

-- Switch onscreen mode
--------------------------------------------------------------------------------
function control:switch_onscreen()
	self.onscreen = not self.onscreen
	self.onscreen_icon:set_color(self.onscreen and self.style.color.main or self.style.color.icon)

	if self.onscreen then
		control_off_screen(self.client)
		self:update()
	end
end

-- Show
--------------------------------------------------------------------------------
function control:show()
	if not self.wibox then self:init() end

	if not self.wibox.visible then
		-- check if focused client floating
		local is_floating = client.focus and client.focus.floating

		if not is_floating then
			rednotify:show(redutil.table.merge({ text = "No floating window focused" }, self.style.notify))
			return
		end
		self.client = client.focus

		-- show widget
		if self.style.set_position then
			self.style.set_position(self.wibox)
		else
			redutil.placement.centered(self.wibox, nil, mouse.screen.workarea)
		end
		redutil.placement.no_offscreen(self.wibox, self.style.screen_gap, screen[mouse.screen].workarea)

		self:update()
		self.wibox.visible = true
		awful.keygrabber.run(self.keygrabber)
		redtip:set_pack(
			"Floating window", self.tip, self.style.keytip.column, self.style.keytip.geometry,
			function() self:hide() end
		)
	end
end

-- Hide
--------------------------------------------------------------------------------
function control:hide()
	self.wibox.visible = false
	awful.keygrabber.stop(self.keygrabber)
	redtip:remove_pack()
	self.client = nil
end

-- Set user hotkeys
-----------------------------------------------------------------------------------------------------------------------
function control:set_keys(keys, layout)
	layout = layout or "all"
	if keys then
		self.keys[layout] = keys
		if layout ~= "all" then self.keys.all = awful.util.table.join(self.keys.control, self.keys.action) end
	end

	self.tip = awful.util.table.join(self.keys.all, self._fake_keys)
end


-- End
-----------------------------------------------------------------------------------------------------------------------
return control
