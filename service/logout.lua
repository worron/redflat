-----------------------------------------------------------------------------------------------------------------------
--                                             RedFlat logout screen                                                 --
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
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
		counter_top_margin  = 200,
		label_font          = "Sans 14",
		counter_font        = "Sans 24",
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
		double_key_activation     = false,
		client_kill_timeout       = 2,
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "service.logout") or {})
end

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Gracefully closes down user-owned application processes
------------------------------------------------------------
local function gracefully_close(application)
	if application.pid then
		-- first try sending SIGTERM to the owning process
		awful.spawn.easy_async("kill -SIGTERM " .. tostring(application.pid), function(_, _, _, exitcode)
			if exitcode ~= 0 then
				-- kill might fail for root-owned process or processes with fake PIDs
				-- (e.g. firejail-wrapped processes), so try to close the client instead
				application:kill()
			end
		end)
	else
		-- no associated PID, try to close the client instead
		application:kill()
	end
end


function  logout:_close_all_apps(option)
	-- graceful exit (apps closing) may be disabled by user settings
	if not logout.style.graceful_shutdown then
		logout:hide()
		option.callback()
		return
	end

	-- apps closing
	for _, application in ipairs(client.get()) do
		-- clients owned by the same process might vanish upon the first SIGTERM
		-- during list iteration, so we only handle those which are still valid
		if application.valid then gracefully_close(application) end
	end

	-- execute the given logout option after the kill timeout
	self.countdown:start(option)
end

-- Define all available logout options to be displayed
-- maybe overwritten by user configs via logout:set_entries()
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
function logout.action.select_by_id(id)
	local new_option = logout.options[id]
	if not new_option then return end

	-- if already selected
	if new_option == logout.selected then
		-- activate button on double selection
		if logout.style.double_key_activation then new_option:execute() end
		return
	end

	new_option:select()
end

function logout.action.execute_selected()
	if not logout.selected then return end
	logout.selected:execute()
end

function logout.action.select_next()
	local target_id = logout.selected and logout.selected.id + 1 or 1
	logout.action.select_by_id(target_id)
end

function logout.action.select_prev()
	local target_id = logout.selected and logout.selected.id - 1 or 1
	logout.action.select_by_id(target_id)
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

-- Button for layout option
--------------------------------------------------------------------------------
function logout:_make_button(icon_name)
	local icon = self.style.icons[icon_name] or redutil.base.placeholder({ txt = "?" })

	local image = wibox.container.margin(svgbox(icon, nil, self.style.color.icon))
	image.margins = self.style.icon_margin

	local iconbox = wibox.container.background(image)
	iconbox.bg = self.style.color.gray
	iconbox.shape = self.style.button_shape
	iconbox.forced_width = self.style.button_size.width
	iconbox.forced_height = self.style.button_size.height

	return iconbox
end

-- Label for layout option
--------------------------------------------------------------------------------
function logout:_make_label(title)
	local label = wibox.widget.textbox(title)
	label.font = self.style.label_font
	label.align = "center"
	label.valign = "center"

	return label
end

-- Add new logout option to widget
-----------------------------------------------------------------------------------------------------------------------
function logout:add_option(id, action)

	-- creating option structure
	local option = { id = id, close_apps = action.close_apps, callback = action.callback, name = action.label }
	option.button = logout:_make_button(action.icon_name)
	option.label = logout:_make_label(action.label)

	-- logout option methods
	function option:select()
		if logout.selected then logout.selected:deselect() end
		self.button.bg = logout.style.color.main
		logout.selected = self
	end

	function option:deselect()
		if logout.selected ~= self then return end
		self.button.bg = logout.style.color.gray
		logout.selected = nil
	end

	function option:execute()
		if self.close_apps then
			logout:_close_all_apps(self)
		else
			logout:hide()
			self.callback()
		end
	end

	-- binding mouse to option visual
	option.button:connect_signal('mouse::enter', function() option:select() end)
	option.button:connect_signal('mouse::leave', function() option:deselect() end)
	option.button:connect_signal('button::release', function() option:execute() end)

	-- placing option visual to main logout widget
	local button_with_label = wibox.layout.fixed.vertical()
	button_with_label.spacing = self.style.text_margin
	button_with_label:add(option.button)
	button_with_label:add(option.label)
	self.option_layout:add(button_with_label)

	-- putting option to logout inner structure
	table.insert(self.options, option)
end

-- Main functions
-----------------------------------------------------------------------------------------------------------------------
function logout:init()

	-- Style and base layout structure
	------------------------------------------------------------
	self.style = default_style()
	self.options = {}

	-- buttons layout
	self.option_layout = wibox.layout.fixed.horizontal()
	self.option_layout.spacing = self.style.button_spacing

	-- shutdown counter label
	self.counter = wibox.widget.textbox("")
	self.counter.font = self.style.counter_font
	self.counter.align = "center"
	self.counter.valign = "top"

	-- main layout
	local base_layout = wibox.layout.stack()
	base_layout:add(wibox.container.place(self.option_layout))
	base_layout:add(wibox.container.margin(self.counter, 0, 0, self.style.counter_top_margin))

	-- Prepare all defined logout options
	------------------------------------------------------------
	for id, action in ipairs(self.entries) do self:add_option(id, action) end

	-- Create keygrabber
	------------------------------------------------------------
	self.keygrabber = function(mod, key, event)
		if event == "press" then
			for _, k in ipairs(self.keys) do
				if redutil.key.match_grabber(k, mod, key) then k[3](); return end
			end
		end
	end

	-- Main wibox
	------------------------------------------------------------
	--self.wibox = wibox({ widget = wibox.layout.stack(self.option_layout) })
	self.wibox = wibox({ widget = base_layout })
	self.wibox.type = 'splash'
	self.wibox.ontop = true
	self.wibox.bg = self.style.color.wibox
	self.wibox.fg = self.style.color.text
	self.wibox.visible = false

	self.wibox:buttons(
		gears.table.join(
			awful.button({}, 2, function() self:hide() end),
			awful.button({}, 3, function() self:hide() end)
		)
	)

	-- Graceful shutdown counter
	------------------------------------------------------------
	local countdown = {}
	-- Should this pattern be moved to theme variables?
	countdown.pattern = '<span color="%s">%s</span> in %s... Closing apps (%s left).'

	countdown.timer = gears.timer({
		timeout = 1,
		callback = function()
			if countdown.delay <= 1 then
				--logout:hide() -- do we need hide?
				countdown.callback()
				countdown:stop()
			else
				countdown.delay = countdown.delay - 1
				countdown:label(countdown.delay)
				countdown.timer:again()
			end
		end
	})

	function countdown:label(seconds)
		local active_apps = client.get() -- not sure how accurate it is
		logout.counter:set_markup(string.format(
			self.pattern,
			logout.style.color.main, self.option_name, seconds, #active_apps
		))
	end

	function countdown:start(option)
		self.option_name = option.name
		self.callback = option.callback

		self.delay = logout.style.client_kill_timeout
		self:label(self.delay)
		self.timer:start()
	end

	function countdown:stop()
		if self.timer.started then self.timer:stop() end
		logout.counter:set_text("")
	end

	self.countdown = countdown
end

-- Hide the logout screen without executing any action
--------------------------------------------------------------------------------
function logout:hide()
	awful.keygrabber.stop(self.keygrabber)
	self.countdown:stop()
	if self.selected then self.selected:deselect() end

	redtip:remove_pack()
	self.wibox.visible = false
end

-- Display the logout screen
--------------------------------------------------------------------------------
function logout:show()
	if not self.wibox then self:init() end

	self.wibox.screen = mouse.screen
	self.wibox:geometry(mouse.screen.geometry)
	self.wibox.visible = true
	self.selected = nil

	redtip:set_pack("Logout screen", self.keys, self.style.keytip.column, self.style.keytip.geometry)
	awful.keygrabber.run(self.keygrabber)
end

-- Logout widget setup methods
--------------------------------------------------------------------------------
function logout:set_keys(keys)
	self.keys = keys
end

function logout:set_entries(entries)
	self.entries = entries
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return logout
