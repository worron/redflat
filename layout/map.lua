-----------------------------------------------------------------------------------------------------------------------
--                                                RedFlat map layout                                                 --
-----------------------------------------------------------------------------------------------------------------------
-- Tiling with user defined geometry
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local math = math

local beautiful = require("beautiful")
local awful = require("awful")
local naughty = require("naughty")

local redutil = require("redflat.util")
local common = require("redflat.layout.common")

local hasitem = awful.util.table.hasitem

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local map = { data = {} }
map.name = "usermap"

-- default keys
map.keys = {}
map.keys.layout = {
	{
		{ "Mod4" }, "s", function() map.swap_group() end,
		{ description = "Change placement direction for group", group = "Layout" }
	},
	{
		{ "Mod4" }, "v", function() map.new_group(true) end,
		{ description = "Create new vertical group", group = "Layout" }
	},
	{
		{ "Mod4" }, "h", function() map.new_group() end,
		{ description = "Create new horizontal group", group = "Layout" }
	},
	{
		{ "Mod4" }, "d", function() map.delete_group() end,
		{ description = "Destroy group", group = "Layout" }
	},
	{
		{ "Mod4" }, "a", function() map.set_active() end,
		{ description = "Set active group", group = "Layout" }
	},
	{
		{ "Mod4" }, "f", function() map.move_to_active() end,
		{ description = "Move focused client to active", group = "Layout" }
	},
}

map.keys.resize = {
	{
		{ "Mod4" }, "j", function() map.incfactor(nil, 0.1) end,
		{ description = "Increase window horizontal factor", group = "Resize" }
	},
	{
		{ "Mod4" }, "l", function() map.incfactor(nil, -0.1) end,
		{ description = "Decrease window horizontal factor", group = "Resize" }
	},
	{
		{ "Mod4" }, "i", function() map.incfactor(nil, 0.1, true) end,
		{ description = "Increase window vertical factor", group = "Resize" }
	},
	{
		{ "Mod4" }, "k", function() map.incfactor(nil, -0.1, true) end,
		{ description = "Decrease window vertical factor", group = "Resize" }
	},
}


map.keys.all = awful.util.table.join(map.keys.layout, map.keys.resize)

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function cut_geometry(wa, is_vertical, size)
	if is_vertical then
		-- return { x = wa.x, y = wa.y + (i - 1) * size, width = wa.width, height = size }
		local g = { x = wa.x, y = wa.y, width = wa.width, height = size }
		wa.y = wa.y + size
		return g
	else
		-- return { x = wa.x + (i - 1) * size, y = wa.y, width = size, height = wa.height }
		local g = { x = wa.x, y = wa.y, width = size, height = wa.height }
		wa.x = wa.x + size
		return g
	end
end

local function construct_itempack(cls, wa, is_vertical, parent)
	local pack = { items = {}, wa = wa, cls = { unpack(cls) }, is_vertical = is_vertical, parent = parent }

	for i, c in ipairs(cls) do
		pack.items[i] = { client = c, child = nil, factor = 1 }
	end

	function pack:set_cls(cls)
		local current = { unpack(cls) }
		for i, item in ipairs(self.items) do
			if not item.child then
				if #current > 0 then
					self.items[i].client = current[1]
					table.remove(current, 1)
				else
					self.items[i] = nil
				end
			end
		end

		for _, c in ipairs(current) do
			self.items[#self.items + 1] = { client = c, child = nil, factor = 1 }
		end
	end

	function pack:get_cls()
		local cls = {}
		for i, item in ipairs(self.items) do if not item.child then cls[#cls + 1] = item.client end end
		return cls
	end

	function pack:set_wa(wa)
		self.wa = wa
	end

	function pack:get_places()
		local n = 0
		for i, item in ipairs(self.items) do if not item.child then n = n + 1 end end
		return n
	end

	function pack:incfacror(index, df, is_vertical)
		if is_vertical == self.is_vertical then
			self.items[index].factor = math.max(self.items[index].factor + df, 0.1)
		elseif self.parent then
			for i, item in pairs(self.parent.items) do
				if item.child == self then parent:incfacror(i, df, is_vertical); break end
			end
		end
	end

	function pack:rebuild()
		local geometries = {}
		local weight = 0
		for i, item in ipairs(self.items) do weight = weight + item.factor end
		local area = awful.util.table.clone(self.wa)

		for i, item in ipairs(self.items) do
			local size = self.wa[self.is_vertical and "height" or "width"] / weight * item.factor
			local g = cut_geometry(area, self.is_vertical, size, i)
			if item.child then
				item.child:set_wa(g)
			else
				geometries[item.client] = g
			end
		end

		return geometries
	end

	return pack
end

local function construct_tree(cls, wa)
	local tree = { set = {}, cls = { unpack(cls) }, active = 1 }

	tree.set[1] = construct_itempack(cls, wa)

	function tree:get_pack(c)
		for _, pack in ipairs(self.set) do
			for i, item in ipairs(pack.items) do
				if not item.child and c == item.client then return pack, i end
			end
		end
	end

	function tree:create_group(c, is_vertical)
		local parent, index = self:get_pack(c)
		local new_pack = construct_itempack({}, {}, is_vertical, parent)

		self.set[#self.set + 1] = new_pack
		parent.items[index] = { child = new_pack, factor = 1 }
		self.active = #self.set

		awful.client.setslave(c)
	end

	function tree:delete_group(pack)
		if pack == self.set[1] then return end

		if pack.parent then
			for i, item in ipairs(pack.parent.items) do
				if item.child == pack then table.remove(pack.parent.items, i); break end
			end
		end

		local index = hasitem(self.set, pack)
		if index == self.active then self.active = 1 end
		table.remove(self.set, index)
	end

	function tree:rebuild(cls, wa)
		if cls then self.cls = cls end
		local current = { unpack(cls or self.cls) }

		for i, pack in ipairs(self.set) do
			local n = pack:get_places()
			local chunk = { unpack(current, 1, n) }
			current = { unpack(current, n + 1) }
			pack:set_cls(chunk)
		end

		if #current > 0 then
			local refill = awful.util.table.join(self.set[self.active]:get_cls(), current)
			self.set[self.active]:set_cls(refill)
		end

		local geometries = {}

		for i = #self.set, 2, -1 do
			if #self.set[i].items == 0 then tree:delete_group(self.set[i]) end
		end

		for _, pack in ipairs(self.set) do
			geometries = awful.util.table.join(geometries, pack:rebuild())
		end

		return geometries
	end

	return tree
end

-- Layout manipulation functions
-----------------------------------------------------------------------------------------------------------------------
function map.swap_group()
	local c = client.focus
	if not c then return end

	local t = c.screen.selected_tag
	local pack = map.data[t]:get_pack(c)
	pack.is_vertical = not pack.is_vertical
	t:emit_signal("property::layout")
end


function map.new_group(is_vertical)
	local c = client.focus
	if not c then return end

	local t = c.screen.selected_tag
	map.data[t]:create_group(c, is_vertical)
end


function map.delete_group()
	local c = client.focus
	if not c then return end

	local t = c.screen.selected_tag
	local pack = map.data[t]:get_pack(c)
	map.data[t]:delete_group(pack)
	t:emit_signal("property::layout")
end

function map.check_client(c)
	if c.sticky then return true end
	for _, t in ipairs(c:tags()) do
		for k, _ in pairs(map.data) do if k == t then return true end end
	end
end

function map.clean_client(c)
	for t, tree in pairs(map.data) do
		local pack, index = map.data[t]:get_pack(c)
		if pack then table.remove(pack.items, index) end
	end
end

function map.set_active(c)
	local c = c or client.focus
	if not c then return end

	local t = c.screen.selected_tag
	local pack = map.data[t]:get_pack(c)
	if pack then map.data[t].active = hasitem(map.data[t].set, pack) end
end

function map.move_to_active(c)
	local c = c or client.focus
	if not c then return end

	local t = c.screen.selected_tag
	local pack, index = map.data[t]:get_pack(c)
	if pack then
		table.remove(pack.items, index)
		awful.client.setslave(c)
	end
end

function map.incfactor(c, df, is_vertical)
	local c = c or client.focus
	if not c then return end

	local t = c.screen.selected_tag
	local pack, index = map.data[t]:get_pack(c)
	if pack then
		pack:incfacror(index, df, is_vertical)
		t:emit_signal("property::layout")
	end
end

-- Tile function
-----------------------------------------------------------------------------------------------------------------------
function map.arrange(p)
	local wa = awful.util.table.clone(p.workarea)
	local cls = p.clients
	local data = map.data
	local t = p.tag or screen[p.screen].selected_tag

	-- nothing to tile here
	if #cls == 0 then return end

	if not data[t] then data[t] = construct_tree(cls, wa) end

	p.geometries = data[t]:rebuild(cls)
end


-- Keygrabber
-----------------------------------------------------------------------------------------------------------------------
map.maingrabber = function(mod, key, event)
	for _, k in ipairs(map.keys.all) do
		if redutil.key.match_grabber(k, mod, key) then k[3](); return true end
	end
end

map.key_handler = function (mod, key, event)
	if event == "press" then return end
	if map.maingrabber(mod, key, event)     then return end
	if common.grabbers.base(mod, key, event) then return end
end


-- Redflat navigator support functions
-----------------------------------------------------------------------------------------------------------------------
function map:set_keys(layout, keys)
	local layout = layout or "all"
	if keys then
		self.keys[layout] = keys
		if layout ~= "all" then map.keys.all = awful.util.table.join(map.keys.layout, map.keys.resize) end
	end

	self.tip = awful.util.table.join(self.keys.all, common.keys.base)
end

function map.startup()
	if not map.tip then map:set_keys() end
end


-- End
-----------------------------------------------------------------------------------------------------------------------
return map
