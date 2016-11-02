-----------------------------------------------------------------------------------------------------------------------
--                                           RedFlat prefix hotkey manager                                           --
-----------------------------------------------------------------------------------------------------------------------
-- Emacs like key compination manager
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local string = string

local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")

local redflat = require("redflat")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local prekey = {}
local rednotify = redflat.float.notify

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		notify_icon     = nil,
		geometry        = { width = 220, height = 60 },
		label_font      = "Sans 14 bold",
		border_width    = 2,
		service_hotkeys = { close = { "Escape" }, ignore = { "Super_L" }, stepback = { "BackSpace" } },
		color           = { border = "#575757", wibox = "#202020" }
	}

	return redflat.util.table.merge(style, redflat.util.check(beautiful, "float.prekey") or {})
end

-- Support functions
-----------------------------------------------------------------------------------------------------------------------
local function check_key(key, mod, item)
	if #mod ~= #item.mod then return false end
	for _, m in ipairs(item.mod) do
		if not awful.util.table.hasitem(mod, m) then return false end
	end
	return key == item.key
end

-- Main widget
-----------------------------------------------------------------------------------------------------------------------

-- Initialize prekey widget
--------------------------------------------------------------------------------
function prekey:init(style)

	-- Init vars
	------------------------------------------------------------
	self.active = nil
	self.parents = {}
	self.tip = ""

	local style = redflat.util.table.merge(default_style(), style or {})

	-- Wibox
	------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.border_width,
		border_color = style.color.border
	})
	self.wibox:geometry(style.geometry)

	self.label = wibox.widget.textbox()
	self.label:set_align("center")
	self.wibox:set_widget(self.label)

	self.label:set_font(style.label_font)

	-- Keygrabber
	------------------------------------------------------------
	self.keygrabber = function(mod, key, event)
		if event == "release" then return false
		elseif awful.util.table.hasitem(style.service_hotkeys.close,  key) then self:hide()
		elseif awful.util.table.hasitem(style.service_hotkeys.stepback, key) then self:undo()
		elseif awful.util.table.hasitem(style.service_hotkeys.ignore, key) then return true
		else
			for _, item in ipairs(self.active.items) do
				if check_key(key, mod, item) then
					if rednotify.wibox and rednotify.wibox.visible then redflat.float.notify:hide() end
					self:activate(item)
					return false
				end
			end
			rednotify:show({
				text = string.format("Key '%s' not binded", key),
				icon = style.notify_icon,
			})
			return true
		end
	end
end

-- Set current key item
--------------------------------------------------------------------------------
function prekey:activate(item)
	if not item.root then
		item.action()
		self:hide()
	else
		if #item.items == 0 then return end -- pure overcautiousness

		if not self.active then
			self.wibox.visible = true
			awful.keygrabber.run(self.keygrabber)
		else
			self.parents[#self.parents + 1] = self.active
		end

		self.active = item
		self.tip = self.tip == "" and self.active.label or self.tip .. " " .. self.active.label
		self.label:set_text(self.tip)
	end
end

-- Deactivate last key item
--------------------------------------------------------------------------------
function prekey:undo()
	if #self.parents > 0 then
		self.tip = self.tip:sub(1, - (#self.active.label + 2))
		self.label:set_text(self.tip)

		self.active = self.parents[#self.parents]
		self.parents[#self.parents] = nil
	else
		self:hide()
	end
end

-- Hide widget
--------------------------------------------------------------------------------
function prekey:hide()
	self.wibox.visible = false
	awful.keygrabber.stop(self.keygrabber)
	self.active = nil
	self.parents = {}
	self.tip = ""
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return prekey
