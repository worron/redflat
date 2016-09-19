-----------------------------------------------------------------------------------------------------------------------
--                                           RedFlat quick laucnher widget                                           --
-----------------------------------------------------------------------------------------------------------------------
-- Quick app launch or switch
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local table = table
local unpack = unpack
local string = string
local io = io
local os = os

local awful = require("awful")
local redflat = require("redflat")
local beautiful = require("beautiful")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local qlaunch = { hotkeys = {}, history = {}, store = {} }
local swpack = { apps = {}, menu = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		sw_type    = "menu",
		switcher   = { apps = {}, menu = { width = 800 } },
		configfile = os.getenv("HOME") .. "/.cache/awesome/applist",
	}

	return redflat.util.table.merge(style, redflat.util.check(beautiful, "float.qlaunch") or {})
end


-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function get_clients(app)
	local clients = {}
	for _, c in ipairs(client.get()) do
		if c.class:lower() == app then table.insert(clients, c) end
	end
	return clients
end

local function focus_and_raise(c)
	if c.minimized then c.minimized = false end
	if not c:isvisible() then awful.tag.viewmore(c:tags(), c.screen) end

	client.focus = c
	c:raise()
end

local function build_filter(app)
	return function(c)
		return c.class:lower() == app
	end
end

local function format_key(key)
	local nk = key:match("#(%d+)")
	return nk and (tonumber(nk) - 9) or key
end

function is_file_exists(file)
	local f = io.open(file, "r")
	if f then f:close(); return true else return false end
end

-- redflat appswitcher
function swpack.apps:init(style)
	self.widget = redflat.float.appswitcher
	self.widget:init()
end

function swpack.apps:activate(app, clist)
	self.widget:show({ filter = build_filter(app) })
end

-- redflat menu switcher
function swpack.menu:init(style)
	self.style = style
end

function swpack.menu:activate(app, clist)
	local items = {}
	for _, c in ipairs(clist) do
		local client_tags = ""
		for _, t in ipairs(c:tags()) do client_tags = client_tags .. " " .. string.upper(t.name) end
		table.insert(items, { string.format("[%s ] %s", client_tags, c.name), function() focus_and_raise(c) end })
	end

	self.widget = redflat.menu({ theme = self.style, items = items })
	redflat.util.placement.centered(self.widget.wibox, nil, screen[mouse.screen].workarea)
	self.widget:show({ coords = self.widget.wibox:geometry() })

	collectgarbage() -- FIX THIS !!!
end


-- Initialize widget
-----------------------------------------------------------------------------------------------------------------------
function qlaunch:init(args, style)
	local args = args or {}
	local keys = args.keys or {}
	local switchmod = args.switchmod or { "Mod1" }
	local setupmod = args.setupmod or { "Mod1", "Control" }
	local runmod = args.runmod or { "Mod1", "Shift" }

	local style = redflat.util.table.merge(default_style(), style or {})
	self.configfile = style.configfile

	self:load_config(keys)

	self.switcher = swpack[style.sw_type]
	self.switcher:init(style.switcher[style.sw_type])

	local tk = {}
	for key, data in pairs(self.store) do
		table.insert(tk, awful.key(switchmod, key, function() self:run_or_raise(key) end))
		table.insert(tk, awful.key(setupmod, key, function() self:set_new_app(key) end))
		table.insert(tk, awful.key(runmod, key, function() self:run_or_raise(key, true) end))
	end
	self.hotkeys = awful.util.table.join(unpack(tk))

	client.connect_signal("focus", function(c) self:set_last(c) end)
	awesome.connect_signal("exit", function() self:save_config() end)
end

function qlaunch:run_or_raise(key, forced_run)
	local app = self.store[key].app
	if app == "" then return end

	local clients = get_clients(app)
	local cnum = #clients

	if cnum == 0 or forced_run then
		if self.store[key].run ~= "" then awful.util.spawn_with_shell(self.store[key].run) end
	elseif cnum == 1 then
		focus_and_raise(clients[1])
	else
		if awful.util.table.hasitem(clients, client.focus) then
			self.switcher:activate(app, clients)
		else
			local last = awful.util.table.hasitem(clients, self.history[app])
			if last then
				focus_and_raise(self.history[app])
			else
				focus_and_raise(clients[1])
			end
		end
	end
end

function qlaunch:set_new_app(key)
	if not client.focus then return end
	local run_command = awful.util.pread(string.format("tr '\\0' ' ' < /proc/%s/cmdline", client.focus.pid))
	self.store[key] = { app = client.focus.class:lower(), run = run_command }
	naughty.notify({text=string.format("%s now binded with '%s'", client.focus.class, format_key(key))})
end

function qlaunch:set_last(c)
	for _, data in pairs(self.store) do
		if c.class:lower() == data.app then
			self.history[data.app] = c
			break
		end
	end
end

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
