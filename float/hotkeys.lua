-----------------------------------------------------------------------------------------------------------------------
--                                          RedFlat hotkeys helper widget                                            --
-----------------------------------------------------------------------------------------------------------------------
-- Widget with list of hotkeys
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local type = type
local math = math

local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local timer = require("gears.timer")

local redflat = require("redflat")
local redutil = require("redflat.util")
local separator = require("redflat.gauge.separator")


-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local hotkeys = { keypack = {}, lastkey = nil, cache = {}, boxes = {} }
local hasitem = awful.util.table.hasitem

-- key bindings
hotkeys.keys = { close = { "Super_L", "Escape" } }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		geometry      = { width = 800, height = 600 },
		border_margin = { 10, 10, 10, 10 },
		tspace        = 5,
		border_width  = 2,
		ltimeout      = 0.05,
		font          = "Sans 12",
		-- keysfont      = "Sans bold 12",
		titlefont     = "Sans bold 14",
		color         = { border = "#575757", text = "#aaaaaa", main = "#b1222b", wibox = "#202020",
		                  gray = "#575757" }
	}

	return redutil.table.merge(style, redutil.check(beautiful, "float.hotkeys") or {})
end

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Parse raw key table
--------------------------------------------------------------------------------
local function parse(rawkeys, columns)
	local keys = {}
	local columns = columns or 1
	local rk = { unpack(rawkeys) }
	local p = math.floor(#rawkeys / columns)

	-- dirty trick for sorting
	local sp = {}
	for _, v in ipairs(rk) do
		if not hasitem(sp, v[#v].group) then table.insert(sp, v[#v].group) end
	end
	table.sort(rk, function(a, b) return hasitem(sp, a[#a].group) < hasitem(sp, b[#b].group) end)

	-- split keys to columns
	for i = 1, columns do
		keys[i] = {}
		local chunk = { unpack(rk, 1, p) }
		rk = { unpack(rk, p + 1) }

		for _, v in ipairs(chunk) do
			local data = v[#v]
			table.insert(keys[i], {
				mod = v[1],
				key = v[2],
				description = data.description,
				group = data.group,
				keyset = data.keyset or { v[2] },
			})
		end
	end

	return keys
end

-- Form hotkeys helper text
--------------------------------------------------------------------------------
local function build_tip(pack, style, keypressed)
	local text = {}

	for i, column in ipairs(pack) do
		local coltxt = ""
		local group = nil

		for _, key in ipairs(column) do
			if key.group ~= group then
				group = key.group
				coltxt = coltxt ..  string.format(
					'\n<span font="%s" color="%s">%s</span>\n', style.titlefont, style.color.gray, group
				)
			end

			local line = key.key

			if #key.mod > 0 then
				local modtext = ""

				for i, v in ipairs(key.mod) do
					modtext = i > 1 and modtext .. " + " .. v or v
				end

				line = modtext .. " " .. line
			end

			local clr = keypressed and hasitem(key.keyset, keypressed) and style.color.main or style.color.text
			line = string.format(
				'<span font="%s" color="%s"><b>%s</b> %s</span>', style.font, clr, line, key.description
			)
			coltxt = coltxt .. line .. "\n"
		end
		text[i] = coltxt
	end

	return text
end

-- Initialize widget
-----------------------------------------------------------------------------------------------------------------------
function hotkeys:init()

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = default_style()
	self.style = style

	local bm = style.border_margin

	-- Create floating wibox for top widget
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border
	})

	self.wibox:geometry(style.geometry)

	-- Widget layout setup
	--------------------------------------------------------------------------------
	self.layout = wibox.layout.flex.horizontal()

	self.title = wibox.widget.textbox("Title")
	self.title:set_align("center")
	self.title:set_font(style.titlefont)

	self.wibox:setup({
		{
			{
				self.title,
				{
					text = "Press any key to highlight tip, Escape for exit",
					align = "center",
					widget = wibox.widget.textbox
				},
				redflat.gauge.separator.horizontal(),
				spacing = style.tspace,
				layout = wibox.layout.fixed.vertical,
			},
			self.layout,
			layout = wibox.layout.align.vertical,
		},
		left = bm[1], right = bm[2], top = bm[3], bottom = bm[4],
		layout = wibox.container.margin,
	})

	-- Highlight timer
	--------------------------------------------------------------------------------
	local ltimer = timer({ timeout = style.ltimeout })
	ltimer:connect_signal("timeout",
		function()
			ltimer:stop()
			self:highlight()
		end
	)

	-- Keygrabber
	--------------------------------------------------------------------------------
	self.keygrabber = function(mod, key, event)
		if hasitem(self.keys.close, key) and event == "release" then
			self:hide()
			return false
		end

		self.lastkey = event == "press" and key or nil
		ltimer:again()
	end

end


-- Keypack managment
-----------------------------------------------------------------------------------------------------------------------

-- Set new keypack
--------------------------------------------------------------------------------
function hotkeys:set_pack(name, pack, columns, geometry)
	if not self.wibox then self:init() end

	if not self.cache[name] then self.cache[name] = parse(pack, columns) end
	table.insert(self.keypack, { name = name, pack = self.cache[name], geometry = geometry or self.style.geometry })
	self.wibox:geometry(self.keypack[#self.keypack].geometry)
	self.title:set_text(name .. " hotkeys")
	self:highlight()
end

-- Remove current keypack
--------------------------------------------------------------------------------
function hotkeys:remove_pack()
	table.remove(self.keypack)
	self.title:set_text(self.keypack[#self.keypack].name .. " hotkeys")
	self.wibox:geometry(self.keypack[#self.keypack].geometry)
	self:highlight()
end

-- Highlight key tip
--------------------------------------------------------------------------------
function hotkeys:highlight()
	local tip = build_tip(self.keypack[#self.keypack].pack, self.style, self.lastkey)

	self.layout:reset()
	for i, column in ipairs(tip) do
		if not self.boxes[i] then -- TODO: weak table?
			self.boxes[i] = wibox.widget.textbox()
			self.boxes[i]:set_valign("top")
		end

		self.boxes[i]:set_markup(column)
		self.layout:add(self.boxes[i])
	end
end


-- Show/hide widget
-----------------------------------------------------------------------------------------------------------------------

-- show
function hotkeys:show()
	if not self.wibox then self:init() end

	if not self.wibox.visible then
		redutil.placement.centered(self.wibox, nil, mouse.screen.workarea)
		self.wibox.visible = true
		awful.keygrabber.run(self.keygrabber)
	-- else
	-- 	self:hide()
	end
end

-- hide
function hotkeys:hide()
	self.wibox.visible = false
	self.lastkey = nil
	self:highlight()
	awful.keygrabber.stop(self.keygrabber)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return hotkeys
