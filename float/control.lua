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
		margin        = { icon = { title = { 10, 10, 2, 2 }, state = { 10, 10, 2, 2 } } },
		icon          = {
			unknown  = redutil.base.placeholder({ txt = "?" }),
			title  = redutil.base.placeholder({ txt = "?" }),
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
		{ description = "Select nove/resize step", group = "Mode",
		  keyset = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } }
	},
}

-- Initialize widget
-----------------------------------------------------------------------------------------------------------------------
function control:init()

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = default_style()
	self.style = style
	self.client = nil
	self.step = style.steps[style.default_step]

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

	local title_icon = svgbox(self.style.icon.title)
	title_icon:set_color(self.style.color.icon)

	self.state_icon = svgbox()

	--self.wibox:set_widget(self.label)
	self.wibox:setup({
		wibox.container.margin(title_icon, unpack(self.style.margin.icon.title)),
		self.label,
		wibox.container.margin(self.state_icon, unpack(self.style.margin.icon.state)),
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
end

-- Change window size
--------------------------------------------------------------------------------
function control:resize(is_shrinking)
	if not self.client then return end

	local g = self.client:geometry()
	local d = self.step * (is_shrinking and -1 or 1)

	self.client:geometry({ x = g.x - d, y = g.y - d, width = g.width + 2 * d, height = g.height + 2 * d })
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
	--
	self.label:set_markup(string.format(
		'<span color="%s">%s</span><span color="%s">[%d]</span>',
		self.style.color.text, size_label, self.style.color.gray, self.step
	))
end

-- Select move/resize step by index
--------------------------------------------------------------------------------
function control:choose_step(index)
	if self.style.steps[index] then self.step = self.style.steps[index] end
	self:update()
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
			"Titlebar", self.tip, self.style.keytip.column, self.style.keytip.geometry,
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
