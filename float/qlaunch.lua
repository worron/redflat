-----------------------------------------------------------------------------------------------------------------------
--                                           RedFlat quick laucnher widget                                           --
-----------------------------------------------------------------------------------------------------------------------
-- Quick application launch or switch
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local table = table
local unpack = unpack
local string = string
local math = math
local io = io
local os = os

local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local color = require("gears.color")

local redflat = require("redflat")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local qlaunch = { hotkeys = {}, history = {}, store = {} }

local code_to_pressed, pressed_to_code = {}, {}
for i = 1, 10 do
	local pressed = tostring(i % 10)
	local code = "#" .. tostring(i + 9)
	code_to_pressed[code]    = pressed
	pressed_to_code[pressed] = code
end

local sw = redflat.float.appswitcher
local TPI = math.pi * 2

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		df_icon         = nil,
		no_icon         = nil,
		icons           = {},
		notify_icon     = nil,
		geometry        = { width = 1200, height = 180 },
		border_margin   = { 20, 20, 10, 10 },
		appline         = { iwidth = 160, im = { 10, 10, 5, 5 }, igap = { 0, 0, 10, 10 }, lheight = 30 },
		state           = { gap = 4, radius = 3, size = 10, height = 20, width = 20 },
		configfile      = os.getenv("HOME") .. "/.cache/awesome/applist",
		label_font      = "Sans 12",
		border_width    = 2,
		service_hotkeys = { close = { "Escape" }, switch = { "Return" }},
		color           = { border = "#575757", text = "#aaaaaa", main = "#b1222b", urgent = "#32882d",
		                    wibox  = "#202020", icon = "#a0a0a0", bg   = "#161616", gray   = "#575757" }
	}

	return redflat.util.table.merge(style, redflat.util.check(beautiful, "float.qlaunch") or {})
end


-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Get list of clients with given class
------------------------------------------------------------
local function get_clients(app)
	local clients = {}
	for _, c in ipairs(client.get()) do
		if c.class:lower() == app then table.insert(clients, c) end
	end
	return clients
end

-- Set focus on given client
------------------------------------------------------------
local function focus_and_raise(c)
	if c.minimized then c.minimized = false end
	if not c:isvisible() then awful.tag.viewmore(c:tags(), c.screen) end

	client.focus = c
	c:raise()
end

-- Build filter for clients with given class
------------------------------------------------------------
local function build_filter(app)
	return function(c)
		return c.class:lower() == app
	end
end

-- Translate pressed key to keycode for numeric keys
------------------------------------------------------------
local function format_key(key, reverse)
	local kset = reverse and pressed_to_code or code_to_pressed
	return kset[key] and kset[key] or key
end

-- Check if file exist
------------------------------------------------------------
function is_file_exists(file)
	local f = io.open(file, "r")
	if f then f:close(); return true else return false end
end

-- Widget construction functions
-----------------------------------------------------------------------------------------------------------------------

-- Build application state indicator
--------------------------------------------------------------------------------
function build_state_indicator(style)

	-- Initialize vars
	------------------------------------------------------------
	local widg = wibox.widget.base.make_widget()

	local dx = style.state.size + style.state.gap
	local ds = style.state.size - style.state.radius
	local r  = style.state.radius

	-- updating values
	local data = {
		state = {},
		height = style.state.height or nil,
		width = style.state.width or nil
	}

	-- User functions
	------------------------------------------------------------
	function widg:setup(clist)
		data.state = {}
		for _, c in ipairs(clist) do
			table.insert(data.state, { focused = client.focus == c, urgent = c.urgent, minimized = c.minimized })
		end
		self:emit_signal("widget::updated")
	end

	-- Fit
	------------------------------------------------------------
	widg.fit = function(widg, width, height)
		return data.width or width, data.height or height
	end

	-- Draw
	------------------------------------------------------------
	widg.draw = function(widg, wibox, cr, width, height)
		local n = #data.state
		local x0 = (width - n * style.state.size - (n - 1) * style.state.gap) / 2
		local y0 = (height - style.state.size) / 2

		for i = 1, n do
			cr:set_source(color(
				data.state[i].focused   and style.color.main   or
				data.state[i].urgent    and style.color.urgent or
				data.state[i].minimized and style.color.gray   or style.color.icon
			))
			-- draw rounded rectangle
			cr:arc(x0 + (i -1) * dx + ds, y0 + r,  r, -TPI / 4, 0)
			cr:arc(x0 + (i -1) * dx + ds, y0 + ds, r, 0, TPI / 4)
			cr:arc(x0 + (i -1) * dx + r,  y0 + ds, r, TPI / 4, TPI / 2)
			cr:arc(x0 + (i -1) * dx + r,  y0 + r,  r, TPI / 2, 3 * TPI / 4)
			cr:fill()
		end
	end

	------------------------------------------------------------
	return widg
end

-- Build icon with label item
--------------------------------------------------------------------------------
local function build_item(key, style)
	local widg = {}

	-- Label
	------------------------------------------------------------
	local label = wibox.widget.textbox()
	local label_constraint = wibox.layout.constraint(label, "exact", nil, style.appline.lheight)
	label:set_markup(string.format('<span color="%s">%s</span>', style.color.text, format_key(key)))
	label:set_align("center")
	label:set_font(style.label_font)

	widg.background = wibox.widget.background(label_constraint, style.color.bg)

	-- Icon
	------------------------------------------------------------
	widg.svgbox = redflat.gauge.svgbox()
	local icon_align = wibox.layout.align.horizontal()
	local icon_constraint = wibox.layout.constraint(icon_align, "exact", style.appline.iwidth, nil)
	icon_align:set_middle(widg.svgbox)

	-- State
	------------------------------------------------------------
	widg.state = build_state_indicator(style)

	-- Layout setup
	------------------------------------------------------------
	widg.layout = wibox.layout.align.vertical()
	widg.layout:set_top(widg.state)
	widg.layout:set_middle(wibox.layout.margin(icon_constraint, unpack(style.appline.igap)))
	widg.layout:set_bottom(widg.background)

	------------------------------------------------------------
	return widg
end

-- Build widget with application list
--------------------------------------------------------------------------------
local function build_switcher(keys, style)

	-- Init vars
	------------------------------------------------------------
	local widg = { items = {}, selected = nil }
	local middle_layout = wibox.layout.fixed.horizontal()

	widg.layout = wibox.layout.align.horizontal()

	-- Sorted keys
	------------------------------------------------------------
	local sk = {}
	for k in pairs(keys) do table.insert(sk, k) end
	table.sort(sk)

	-- Build icon row
	------------------------------------------------------------
	for _, key in ipairs(sk) do
		widg.items[key] = build_item(key, style)
		middle_layout:add(wibox.layout.margin(widg.items[key].layout, unpack(style.appline.im)))
	end

	widg.layout:set_middle(wibox.layout.margin(middle_layout, unpack(style.border_margin)))

	-- Winget functions
	------------------------------------------------------------
	function widg:update(store, idb)
		self.selected = nil
		for key, data in pairs(store) do
			local icon = data.app == "" and style.no_icon or idb[data.app] or style.df_icon
			self.items[key].svgbox:set_image(icon)
			self.items[key].svgbox:set_color(style.color.icon)
		end
	end

	function widg:set_state(store)
		for k, item in pairs(self.items) do
			local clist = get_clients(store[k].app)
			item.state:setup(clist)
		end
	end

	function widg:reset()
		if self.selected then self.items[self.selected].background:set_bg(style.color.bg) end
		self.selected = nil
	end

	function widg:check_key(store, key)
		local key = format_key(key, true)
		if self.items[key] then
			if self.selected then self.items[self.selected].background:set_bg(style.color.bg) end
			self.items[key].background:set_bg(style.color.main)
			self.selected = key
		end
	end

	------------------------------------------------------------
	return widg
end

-- Main widget
-----------------------------------------------------------------------------------------------------------------------

-- Build widget
--------------------------------------------------------------------------------
function qlaunch:init(args, style)

	-- Init vars
	------------------------------------------------------------
	local args = args or {}
	local keys = args.keys or {}
	local switchmod = args.switchmod or { "Mod1" }
	local setupmod = args.setupmod or { "Mod1", "Control" }
	local runmod = args.runmod or { "Mod1", "Shift" }

	local style = redflat.util.table.merge(default_style(), style or {})
	self.configfile = style.configfile
	self.icon_db = redflat.service.dfparser.icon_list(style.icons)
	self.notify_icon = style.notify_icon

	self:load_config(keys)

	-- Wibox
	------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border
	})
	self.wibox:geometry(style.geometry)
	redflat.util.placement.centered(self.wibox, nil, screen[mouse.screen].workarea)

	-- Switcher widget
	------------------------------------------------------------
	self.switcher = build_switcher(self.store, style)
	self.switcher:update(self.store, self.icon_db)

	self.wibox:set_widget(self.switcher.layout)

	-- Keygrabber
	------------------------------------------------------------
	self.keygrabber = function(mod, key, event)
		if event == "press" then return false
		elseif awful.util.table.hasitem(style.service_hotkeys.close,  key) then self:hide(true)
		elseif awful.util.table.hasitem(style.service_hotkeys.switch, key) then self:hide()
		else
			self.switcher:check_key(self.store, key)
			return false
		end
	end

	-- Build hotkeys
	------------------------------------------------------------
	local tk = {}
	for key, data in pairs(self.store) do
		table.insert(tk, awful.key(switchmod, key, nil, function() self:run_or_raise(key) end))
		table.insert(tk, awful.key(setupmod, key, function() self:set_new_app(key) end))
		table.insert(tk, awful.key(runmod, key, function() self:run_or_raise(key, true) end))
	end
	self.hotkeys = awful.util.table.join(unpack(tk))

	-- Connect additional signals
	------------------------------------------------------------
	client.connect_signal("focus", function(c) self:set_last(c) end)
	awesome.connect_signal("exit", function() self:save_config() end)
end

-- Widget show/hide
--------------------------------------------------------------------------------
function qlaunch:show()
	self.switcher:set_state(self.store)
	self.wibox.visible = true
	awful.keygrabber.run(self.keygrabber)
end

function qlaunch:hide(dryrun)
	self.wibox.visible = false
	awful.keygrabber.stop(self.keygrabber)

	if self.switcher.selected and not dryrun then
		self:run_or_raise(self.switcher.selected)
	end

	self.switcher:reset()
end

-- Switch to app
--------------------------------------------------------------------------------
function qlaunch:run_or_raise(key, forced_run)
	local app = self.store[key].app
	if app == "" then return end

	local clients = get_clients(app)
	local cnum = #clients

	if cnum == 0 or forced_run then
		-- open new application
		if self.store[key].run ~= "" then awful.util.spawn_with_shell(self.store[key].run) end
	elseif cnum == 1 then
		-- switch to sole app
		focus_and_raise(clients[1])
	else
		if awful.util.table.hasitem(clients, client.focus) then
			-- run selection widget if wanted app focused
			sw:show({ filter = build_filter(app), noaction = true })
		else
			-- switch to last focused if availible or first in list otherwise
			local last = awful.util.table.hasitem(clients, self.history[app])
			if last then
				focus_and_raise(self.history[app])
			else
				focus_and_raise(clients[1])
			end
		end
	end
end

-- Bind new application to given hotkey
--------------------------------------------------------------------------------
function qlaunch:set_new_app(key)
	if client.focus then
		local run_command = awful.util.pread(string.format("tr '\\0' ' ' < /proc/%s/cmdline", client.focus.pid))
		self.store[key] = { app = client.focus.class:lower(), run = run_command }
		redflat.float.notify:show({
			text = string.format("%s binded with '%s'", client.focus.class, format_key(key)),
			icon = self.notify_icon,
		})
	else
		self.store[key] = { app = "", run = "" }
		redflat.float.notify:show({
			text = string.format("'%s' key unbinded", format_key(key)),
			icon = self.notify_icon,
		})
	end

	self.switcher:update(self.store, self.icon_db)
end

-- Save information about last focused client in widget store
--------------------------------------------------------------------------------
function qlaunch:set_last(c)
	if not c.class then return end
	for _, data in pairs(self.store) do
		if c.class:lower() == data.app then
			self.history[data.app] = c
			break
		end
	end
end

-- Application list save/load
--------------------------------------------------------------------------------
function qlaunch:load_config(default_keys)
	if is_file_exists(self.configfile) then
		for line in io.lines(self.configfile) do
			local key, app, run = string.match(line, "key=(.+);app=(.*);run=(.*);")
			self.store[key] = { app = app, run = run }
		end
	else
		self.store = default_keys
	end
end

function qlaunch:save_config()
	local file = io.open(self.configfile, "w+")
	for key, data in pairs(self.store) do
		file:write(string.format("key=%s;app=%s;run=%s;\n", key, data.app, data.run))
	end
	file:close()
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return qlaunch
