-----------------------------------------------------------------------------------------------------------------------
--                                           RedFlat quick laucnher widget                                           --
-----------------------------------------------------------------------------------------------------------------------
-- Quick app launch or switch
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local table = table
local unpack = unpack

local awful = require("awful")
local redflat = require("redflat")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local qlaunch = { hotkeys = {}, history = {} }
local sw = redflat.float.appswitcher

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

-- Initialize widget
-----------------------------------------------------------------------------------------------------------------------
function qlaunch:init(args)
	local args = args or {}
	local modkeys = args.modkeys or { "Mod1" }
	self.apps = args.apps or {}

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
			sw:show({ filter = build_filter(app) })
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
