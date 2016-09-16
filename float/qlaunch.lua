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

local awful = require("awful")
local redflat = require("redflat")
local beautiful = require("beautiful")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local qlaunch = { hotkeys = {}, history = {} }
local swpack = { apps = {}, menu = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		sw_type  = "menu",
		switcher = { apps = {}, menu = { width = 800 } },
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
	local modkeys = args.modkeys or { "Mod1" }
	self.apps = args.apps or {}

	local style = redflat.util.table.merge(default_style(), style or {})
	self.switcher = swpack[style.sw_type]
	self.switcher:init(style.switcher[style.sw_type])

	for app, data in pairs(self.apps) do
		self.hotkeys = awful.util.table.join(
			self.hotkeys, awful.key(modkeys, data.key, function() self:run_or_raise(app) end)
		)
	end

	client.connect_signal("focus", function(c) self:set_last(c) end)
end

function qlaunch:run_or_raise(app)
	local clients = get_clients(app)
	local cnum = #clients

	if cnum == 0 then
		awful.util.spawn_with_shell(self.apps[app].run)
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

function qlaunch:set_last(c)
	for app, _ in pairs(self.apps) do
		if c.class:lower() == app then
			self.history[app] = c
			break
		end
	end
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return qlaunch
