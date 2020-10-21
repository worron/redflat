-----------------------------------------------------------------------------------------------------------------------
--                                             RedFlat logout screen                                                 --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local beautiful = require("beautiful")

local redutil = require("redflat.util")
local redtip = require("redflat.float.hotkeys")
local svgbox = require("redflat.gauge.svgbox")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local logout = { entries = {}, action = {}, keys = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		button_size         = { width = 128, height = 128 },
		icon_margin         = 16,
		text_margin         = 12,
		button_spacing      = 48,
		button_shape        = gears.shape.rectangle,
		color               = { wibox = "#202020", text = "#a0a0a0", icon = "#a0a0a0",
		                        gray = "#575757", main = "#b1222b" },
		icons               = {
			poweroff = redutil.base.placeholder({ txt = "↯" }),
			reboot   = redutil.base.placeholder({ txt = "⊛" }),
			suspend  = redutil.base.placeholder({ txt = "⊖" }),
			lock     = redutil.base.placeholder({ txt = "⊙" }),
			logout   = redutil.base.placeholder({ txt = "←" }),
		},
		keytip                    = { geometry = { width = 400 } },
		graceful_shutdown         = true,
		show_timeout_notification = true,
		double_click_activation   = false,
		client_kill_timeout       = 2,
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "service.logout") or {})
end

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Gracefully closes down user-owned application processes
------------------------------------------------------------
local graceful_shutdown = function(timeout, callback, show_notification)
	if show_notification then
		naughty.notify({ title = "Closing session ...",
		                 text = "Session will be terminated in " .. tostring(timeout) .. " seconds!" })
	end
	for _, c in ipairs(client.get()) do
		-- clients owned by the same process might vanish upon the first SIGTERM
		-- during list iteration, so we only handle those which are still valid
		if c.valid then
			if c.pid then
				-- first try sending SIGTERM to the owning process
				awful.spawn.easy_async("kill -SIGTERM " .. tostring(c.pid), function(_, _, _, exitcode)
					if exitcode ~= 0 then
						-- kill might fail for root-owned process or processes with fake PIDs
						-- (e.g. firejail-wrapped processes), so try to close the client instead
						c:kill()
					end
				end)
			else
				-- no associated PID, try to close the client instead
				c:kill()
			end
		end
	end
	-- execute the given logout action after the kill timeout
	gears.timer({ timeout = timeout, autostart = true, single_shot = true, callback = callback })
end

-- Define all available logout options to be displayed
-- maybe overriden by user configs via logout:set_entries()
-- order specified will determine order of the displayed buttons
-----------------------------------------------------------------------------------------------------------------------
logout.entries = {
	{   -- Logout
		callback   = function() awesome.quit() end,
		icon_name  = 'logout',
		label      = 'Logout',
		close_apps = true,
	},
	{   -- Lock screen
		callback   = function() awful.spawn.with_shell("sleep 0.5 && xscreensaver-command -l") end,
		icon_name  = 'lock',
		label      = 'Lock',
		close_apps = false,
	},
	{   -- Shutdown
		callback   = function() awful.spawn.with_shell("systemctl poweroff") end,
		icon_name  = 'poweroff',
		label      = 'Shutdown',
		close_apps = true,
	},
	{   -- Suspend
		callback   = function() awful.spawn.with_shell("systemctl suspend") end,
		icon_name  = 'suspend',
		label      = 'Sleep',
		close_apps = false,
	},
	{   -- Reboot
		callback   = function() awful.spawn.with_shell("systemctl reboot") end,
		icon_name  = 'reboot',
		label      = 'Restart',
		close_apps = true,
	},
}

-- Logout screen control functions
-----------------------------------------------------------------------------------------------------------------------
function logout.action.select_by_id(num)
	local option = logout.options[num]
	if not option then return end

	-- activate button on double selection
	if logout.style.double_click_activation and num == logout.selected then
		logout.action.execute_selected()
		return
	end

	-- highlight selected button
	if logout.selected then
		logout:deselect_option(logout.selected)
	end

	option.button.select()
	logout.selected = num
end

function logout.action.execute_by_id(num)
	local option = logout.options[num]
	if not option then return end
	option.action()
end

function logout.action.execute_selected()
	local option = logout.options[logout.selected]
	if not option then return end
	option.action()
end

function logout.action.select_next()
	local target_id = logout.selected and logout.selected + 1 or 1
	logout.action.select_by_id(target_id)
end

function logout.action.select_prev()
	local target_option = logout.selected and logout.selected - 1 or 1
	logout.action.select_by_id(target_option)
end

function logout.action.hide()
	logout:hide()
end

-- Logout screen keygrabber keybindings
--------------------------------------------------------------------------------
logout.keys = {
	{
		{ }, "Escape", logout.action.hide,
		{ description = "Close the logout screen", group = "Action" }
	},
	{
		{ "Mod4" }, "Left", logout.action.select_prev,
		{ description = "Select previous option", group = "Selection" }
	},
	{
		{ "Mod4" }, "Right", logout.action.select_next,
		{ description = "Select next option", group = "Selection" }
	},
	{
		{ }, "Return", logout.action.execute_selected,
		{ description = "Execute selected option", group = "Action" }
	},
	{
		{ "Mod4" }, "F1", function() redtip:show() end,
		{ description = "Show hotkeys helper", group = "Action" }
	},
	{ -- fake keys for redtip
		{ }, "1..9", nil,
		{ description = "Select option by number", group = "Selection",
		  keyset = { "1", "2", "3", "4", "5", "6", "7", "8", "9" } }
	}
}
-- add number shortcuts for the ordered options
for i = 1, 9 do
	table.insert(logout.keys, {
		{ }, tostring(i), function()
			logout.action.select_by_id(i)
		end,
		{ } -- don't show in redtip
	})
end

-- Logout screen UI build functions
-----------------------------------------------------------------------------------------------------------------------

-- Returns a styled button for a logout action
--------------------------------------------------------------------------------
local make_button_widget = function(icon, name, style)

	local label = wibox.widget.textbox(name)
	label.font = beautiful.fonts.mtitle
	label.align = "center"
	label.valign = "center"

	local image = wibox.container.margin(svgbox(icon, nil, style.color.icon))
	image.margins = style.icon_margin

	local iconbox = wibox.container.background(image)
	iconbox.bg = style.color.gray
	iconbox.shape = style.button_shape
	iconbox.forced_width = style.button_size.width
	iconbox.forced_height = style.button_size.height

	local widget_with_label = wibox.layout.fixed.vertical()
	widget_with_label.spacing = style.text_margin
	widget_with_label:add(iconbox)
	widget_with_label:add(label)

	widget_with_label.select = function()
		iconbox.bg = style.color.main
	end

	widget_with_label.deselect = function()
		iconbox.bg = style.color.gray
	end

	return widget_with_label
end

-- Returns a table containing the button widget
-- and action function for a logout action
--------------------------------------------------------------------------------
function logout:build_option(name, icon, callback, do_close_apps)
	return {
		button = make_button_widget(icon, name, self.style),
		action = function()
			logout:hide()
			if do_close_apps and self.style.graceful_shutdown then
				graceful_shutdown(self.style.client_kill_timeout, callback, self.style.show_timeout_notification)
			else
				callback()
			end
		end
	}
end

-- Main functions
-----------------------------------------------------------------------------------------------------------------------
function logout:init()

	-- Style
	------------------------------------------------------------
	self.style = default_style()
	self.options = {}

	-- Prepare all defined logout options
	------------------------------------------------------------
	for _, action in ipairs(logout.entries) do
		local label = action.label
		local icon = self.style.icons[action.icon_name]
		local callback = action.callback
		local do_close_apps = action.close_apps
		table.insert(self.options, logout:build_option(label, icon, callback, do_close_apps))
	end

	self.keygrabber = function(mod, key, event)
		if event == "press" then
			for _, k in ipairs(logout.keys) do
				if redutil.key.match_grabber(k, mod, key) then k[3](); return end
			end
		end
	end

	local layout = wibox.layout.fixed.horizontal()
	layout.spacing = self.style.button_spacing
	for idx, option in ipairs(self.options) do
		local iconbox = option.button:get_all_children()[1]
		iconbox:connect_signal('mouse::enter', function() logout.action.select_by_id(idx) end)
		iconbox:connect_signal('mouse::leave', function() logout:deselect_option(idx) end)
		option.button:connect_signal('button::release', function() logout.action.execute_by_id(idx) end)
		layout:add(option.button)
	end

	self.wibox = wibox({ widget = wibox.container.place(layout) })
	self.wibox.type = 'splash'
	self.wibox.ontop = true
	self.wibox.bg = self.style.color.wibox
	self.wibox.fg = self.style.color.text
	self.wibox.visible = false

	self.wibox:buttons(
		gears.table.join(
			awful.button({}, 2, function()
				self:hide()
			end),
			awful.button({}, 3, function()
				self:hide()
			end)
		)
	)
end

-- Deselect option with the given index and remove its highlight
--------------------------------------------------------------------------------
function logout:deselect_option(num)
	local option = self.options[num]
	if not option then return end
	if self.selected == num then self.selected = nil end
	option.button.deselect()
end

-- Hide the logout screen without executing any action
--------------------------------------------------------------------------------
function logout:hide()
	awful.keygrabber.stop(self.keygrabber)
	for idx = 1, #self.options do
		self:deselect_option(idx)
	end
	redtip:remove_pack()
	self.wibox.visible = false
end

-- Display the logout screen
--------------------------------------------------------------------------------
function logout:show()
	if not self.wibox then self:init() end
	local s = mouse.screen
	self.wibox.screen  = s
	self.wibox.height  = s.geometry.height
	self.wibox.width   = s.geometry.width
	self.wibox.x       = s.geometry.x
	self.wibox.y       = s.geometry.y
	self.wibox.visible = true
	self.selected = nil
	redtip:set_pack("Logout screen", self.keys, self.style.keytip.column, self.style.keytip.geometry)
	awful.keygrabber.run(self.keygrabber)
end

function logout:set_keys(keys)
	self.keys = keys
end

function logout:set_entries(entries)
	self.entries = entries
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return logout
