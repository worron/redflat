-----------------------------------------------------------------------------------------------------------------------
--                                             RedFlat upgrades widget                                               --
-----------------------------------------------------------------------------------------------------------------------
-- Show if system updates available using apt-get
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local table = table
local string = string
local os = os
local unpack = unpack

local beautiful = require("beautiful")
local wibox = require("wibox")
local awful = require("awful")
local timer = require("gears.timer")

local rednotify = require("redflat.float.notify")
local tooltip = require("redflat.float.tooltip")
local redutil = require("redflat.util")
local svgbox = require("redflat.gauge.svgbox")


-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local upgrades = { objects = {}, mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		wibox = {
			geometry     = { width = 400, height = 200 },
			border_width = 2,
			title_font   = "Sans 14 bold",
			tip_font     = "Sans 10",
			set_position = nil,
			icon         = {
				package = redutil.base.placeholder(),
				close   = redutil.base.placeholder({ txt = "X" }),
				daily   = redutil.base.placeholder(),
				weekly  = redutil.base.placeholder(),
				normal  = redutil.base.placeholder(),
				silent  = redutil.base.placeholder(),
			},
			height = { title = 40, state = 50, tip = 20 },
			margin = { close = { 0, 0, 0, 0 }, state = { 0, 0, 0, 0 }, title = { 0, 0, 0, 0 } },
		},
		icon        = redutil.base.placeholder(),
		notify      = {},
		firstrun    = false,
		need_notify = true,
		color       = { main = "#b1222b", icon = "#a0a0a0", wibox = "#202020", border = "#575757", gray = "#404040" }
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.upgrades") or {})
end


local STATE = setmetatable(
	{ keywords = { "NORMAL", "DAILY", "WEEKLY", "SILENT" } },
	{ __index = function(table, key)
		return awful.util.table.hasitem(table.keywords, key) or rawget(table, key)
	end }
)

local tips = {}
tips[STATE.NORMAL] = "regular notifications"
tips[STATE.DAILY]  = "postponed for a day"
tips[STATE.WEEKLY] = "postponed for a week"
tips[STATE.SILENT] = "notifications disabled"

-- Initialize notify widbox
-----------------------------------------------------------------------------------------------------------------------
function upgrades:init(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local args = args or {}
	local update_timeout = args.update_timeout or 3600
	local command = args.command or "echo 0"

	local style = redutil.table.merge(default_style(), style or {})

	self.force_notify = false
	self.style = style
	self.is_updates = false
	self.config = awful.util.getdir("cache") .. "/upgrades"

	-- Create floating wibox for upgrades widget
	--------------------------------------------------------------------------------
	self.wibox = wibox({
		ontop        = true,
		bg           = style.color.wibox,
		border_width = style.wibox.border_width,
		border_color = style.color.border
	})

	self.wibox:geometry(style.wibox.geometry)

	-- Floating widget structure
	--------------------------------------------------------------------------------

	-- main image
	local packbox = svgbox(style.wibox.icon.package, nil, style.color.icon)

	-- titlebar
	self.titlebox = wibox.widget.textbox("0 UPDATES")
	self.titlebox:set_font(style.wibox.title_font)
	self.titlebox:set_align("center")

	-- tip line
	self.tipbox = wibox.widget.textbox()
	self.tipbox:set_font(style.wibox.tip_font)
	self.tipbox:set_align("center")
	self.tipbox:set_forced_height(style.wibox.height.tip)

	-- close button
	local closebox = svgbox(style.wibox.icon.close, nil, style.color.icon)
	closebox:buttons(awful.util.table.join(awful.button({}, 1, function() self:hide() end)))

	-- Control buttons
	------------------------------------------------------------
	local statebox = {}
	local statearea = wibox.layout.flex.horizontal()
	statearea:set_forced_height(style.wibox.height.state)

	-- color update fucntions
	local function update_state()
		for k, box in pairs(statebox) do
			box:set_color(STATE[k] == self.state and style.color.main or style.color.gray)
		end
		self.tipbox:set_markup(string.format('<span color="%s">%s</span>', style.color.gray, tips[self.state]))
	end

	local function check_alert()
		local time = os.time()
		return self.is_updates and
		       (  self.state == STATE.NORMAL
		       or self.state == STATE.DAILY  and (time - self.time > 24 * 3600)
		       or self.state == STATE.WEEKLY and (time - self.time > 7 * 24 * 3600))
	end

	local function update_widget_colors()
		local is_alert = check_alert()
		local color = is_alert and style.color.main or style.color.icon
		for _, w in ipairs(upgrades.objects) do w:set_color(color) end
	end

	-- create control buttons
	for state, k in pairs(STATE.keywords) do
		statebox[k] = svgbox(style.wibox.icon[k:lower()], nil, style.color.gray)
		statebox[k]:buttons(awful.util.table.join(
			awful.button({}, 1, function()
				if self.state ~= state then
					self.state = state
					self.time = (state == STATE.DAILY or state == STATE.WEEKLY) and os.time() or 0
					update_state()
					update_widget_colors()
				end
			end)
		))

		local area = wibox.layout.align.horizontal()
		area:set_middle(statebox[k])
		area:set_expand("outside")

		statearea:add(area)
	end

	-- Setup wibox layouts
	------------------------------------------------------------
	local titlebar = wibox.widget({
		nil,
		self.titlebox,
		wibox.container.margin(closebox, unpack(style.wibox.margin.close)),
		forced_height = style.wibox.height.title,
		layout        = wibox.layout.align.horizontal
	})

	self.wibox:setup({
		wibox.container.margin(titlebar, unpack(style.wibox.margin.title)),
		{
			nil,
			{
				nil, packbox, nil,
				expand = "outside",
				layout = wibox.layout.align.horizontal
			},
			self.tipbox,
			layout = wibox.layout.align.vertical
		},
		wibox.container.margin(statearea, unpack(style.wibox.margin.state)),
		layout = wibox.layout.align.vertical
	})

	-- Start up setup
	------------------------------------------------------------
	self:load_state()
	update_state()

	-- Update info function
	--------------------------------------------------------------------------------
	local function update_count(output)
		local c = string.match(output, "(%d+)")

		self.is_updates = tonumber(c) > 0
		local is_alert = check_alert()

		if style.need_notify and (is_alert or self.force_notify) then
			rednotify:show(redutil.table.merge({ text = c .. " updates available" }, style.notify))
		end
		self.titlebox:set_text(c .." UPDATES")

		if self.tp then self.tp:set_text(c .. " updates") end
		update_widget_colors()
	end

	-- Set update timer
	--------------------------------------------------------------------------------
	self.check_updates = function()
		awful.spawn.easy_async(command, update_count)
	end

	upgrades.timer = timer({ timeout = update_timeout })
	upgrades.timer:connect_signal("timeout", function()
		self.force_notify = false
		self.check_updates()
	end)
	upgrades.timer:start()

	if style.firstrun then upgrades.timer:emit_signal("timeout") end

	-- Connect additional signals
	------------------------------------------------------------
	awesome.connect_signal("exit", function() self:save_state() end)
end

-- Create a new upgrades widget
-- @param style Table containing colors and geometry parameters for all elemets
-----------------------------------------------------------------------------------------------------------------------
function upgrades.new(style)

	if not upgrades.wibox then upgrades:init({}) end

	-- Initialize vars
	--------------------------------------------------------------------------------
	--local object = {}
	local style = redutil.table.merge(upgrades.style, style or {})

	local widg = svgbox(style.icon)
	widg:set_color(style.color.icon)
	table.insert(upgrades.objects, widg)

	-- Set tooltip
	--------------------------------------------------------------------------------
	if not upgrades.tp then
		upgrades.tp = tooltip({ objects = { widg } }, style.tooltip)
	else
		upgrades.tp:add_to_object(widg)
	end

	--------------------------------------------------------------------------------
	return widg
end

-- Show/hide upgrades wibox
-----------------------------------------------------------------------------------------------------------------------
function upgrades:show()
	if self.style.wibox.set_position then
		self.wibox:geometry(self.style.set_position())
	else
		redutil.placement.centered(self.wibox, nil, mouse.screen.workarea)
	end
	redutil.placement.no_offscreen(self.wibox, self.style.screen_gap, screen[mouse.screen].workarea)

	self.wibox.visible = true
end

function upgrades:hide()
	self.wibox.visible = false
end

function upgrades:toggle()
	if self.wibox.visible then
		self:hide()
	else
		self:show()
	end
end

-- Save/restore state between sessions
-----------------------------------------------------------------------------------------------------------------------
function upgrades:load_state()
	local info = redutil.read.file(self.config)
	if info then
		local state, time = string.match(info, "(%d)=(%d+)")
		self.state, self.time = tonumber(state), tonumber(time)
	else
		self.state = STATE.NORMAL
		self.time = 0
	end
end

function upgrades:save_state()
	local file = io.open(self.config, "w")
	file:write(string.format("%d=%d", self.state, self.time))
	file:close()
end

-- Update upgrades info for every widget
-----------------------------------------------------------------------------------------------------------------------
function upgrades:update(is_force)
	self.force_notify = is_force
	self.check_updates()
end

-- Config metatable to call upgrades module as function
-----------------------------------------------------------------------------------------------------------------------
function upgrades.mt:__call(...)
	return upgrades.new(...)
end

return setmetatable(upgrades, upgrades.mt)
