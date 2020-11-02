-----------------------------------------------------------------------------------------------------------------------
--                                         RedFlat client menu widget                                               --
-----------------------------------------------------------------------------------------------------------------------
-- Custom float widget that provides client actions like the tasklist's window
-- menu but may be used outside of the tasklist context on any client. Useful
-- for titlebar click action or other custom client-related keybindings for
-- faster access of client actions without traveling to the tasklist.
-----------------------------------------------------------------------------------------------------------------------
-- Authored by M4he
-- Some code was taken from
------ redflat.widget.tasklist
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local ipairs = ipairs
local table = table
local math = math

local beautiful = require("beautiful")
local awful = require("awful")
local wibox = require("wibox")

local redutil = require("redflat.util")
local separator = require("redflat.gauge.separator")
local redmenu = require("redflat.menu")
local svgbox = require("redflat.gauge.svgbox")

-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local clientmenu = { mt = {}, }

local last = {
	client      = nil,
	screen      = mouse.screen,
	tag_screen  = mouse.screen
}

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		icon                 = { unknown = redutil.base.placeholder(),
		                         minimize = redutil.base.placeholder(),
		                         close = redutil.base.placeholder(),
		                         tag = redutil.base.placeholder({ txt = "■" }),
		                         switch_screen = redutil.base.placeholder() },
		micon                = { blank = redutil.base.placeholder({ txt = " " }),
		                         check = redutil.base.placeholder({ txt = "+" }) },
		layout_icon          = { unknown = redutil.base.placeholder() },
		actionline           = { height = 28, center_button_width = 50 },
		stateline            = { height = 35 },
		tagline              = { height = 30, spacing = 10, rows = 1 },
		state_iconsize       = { width = 20, height = 20 },
		action_iconsize      = { width = 18, height = 18 },
		tag_iconsize         = { width = 16, height = 16 },
		separator            = { marginh = { 3, 3, 5, 5 }, marginv = { 3, 3, 3, 3 } },
		tagmenu              = { icon_margin = { 2, 2, 2, 2 } },
		hide_action          = { move = true,
		                         add = false,
		                         min = true,
		                         floating = false,
		                         sticky = false,
		                         ontop = false,
		                         below = false,
		                         maximized = false },
		enable_screen_switch = false,
		enable_tagline       = false,
		tagline_mod_key      = "Mod4",
		color                = { main = "#b1222b", icon = "#a0a0a0", gray = "#404040", highlight = "#eeeeee" },
	}
	style.menu = {
		ricon_margin = { 2, 2, 2, 2 },
		hide_timeout = 1,
		select_first = false,
		nohide       = true
	}

	return redutil.table.merge(style, redutil.table.check(beautiful, "float.clientmenu") or {})
end

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Function to build item list for submenu
--------------------------------------------------------------------------------
local function tagmenu_items(action, style)
	local items = {}
	for _, t in ipairs(last.screen.tags) do
		if not awful.tag.getproperty(t, "hide") then
			table.insert(
				items,
				{ t.name, function() action(t) end, style.micon.blank, style.micon.blank }
			)
		end
	end
	return items
end

-- Function to rebuild the submenu entries according to current screen's tags
--------------------------------------------------------------------------------
local function tagmenu_rebuild(menu, submenu_index, style)
	for _, index in ipairs(submenu_index) do
			local new_items
			if index == 1 then
				new_items = tagmenu_items(clientmenu.movemenu_action, style)
			else
				new_items = tagmenu_items(clientmenu.addmenu_action, style)
			end
			menu.items[index].child:replace_items(new_items)
	end
end

-- Function to update tag submenu icons
--------------------------------------------------------------------------------
local function tagmenu_update(c, menu, submenu_index, style)
	-- if the screen has changed (and thus the tags) since the last time the
	-- tagmenu was built, rebuild it first
	if last.tag_screen ~= mouse.screen then
		tagmenu_rebuild(menu, submenu_index, style)
		last.tag_screen = mouse.screen
	end
	for k, t in ipairs(last.screen.tags) do
		if not awful.tag.getproperty(t, "hide") then

			-- set layout icon for every tag
			local l = awful.layout.getname(awful.tag.getproperty(t, "layout"))

			local check_icon = style.micon.blank
			if c then
				local client_tags = c:tags()
				check_icon = awful.util.table.hasitem(client_tags, t) and style.micon.check or check_icon
			end

			for _, index in ipairs(submenu_index) do
				local submenu = menu.items[index].child
				if submenu.items[k].icon then
					submenu.items[k].icon:set_image(style.layout_icon[l] or style.layout_icon.unknown)
				end

				-- set "checked" icon if tag active for given client
				-- otherwise set empty icon
				if c then
					if submenu.items[k].right_icon then
						submenu.items[k].right_icon:set_image(check_icon)
					end
				end

				-- update position of any visible submenu
				if submenu.wibox.visible then submenu:show() end
			end
		end
	end
end

-- Function to construct menu line with state icons
--------------------------------------------------------------------------------
local function state_line_construct(state_icons, setup_layout, style)
	local stateboxes = {}

	for i, v in ipairs(state_icons) do
		-- create widget
		stateboxes[i] = svgbox(v.icon)
		stateboxes[i]:set_forced_width(style.state_iconsize.width)
		stateboxes[i]:set_forced_height(style.state_iconsize.height)

		-- set widget in line
		local l = wibox.layout.align.horizontal()
		l:set_expand("outside")
		l:set_second(stateboxes[i])
		setup_layout:add(l)

		-- set mouse action
		stateboxes[i]:buttons(awful.util.table.join(awful.button({}, 1,
			function()
				v.action()
				stateboxes[i]:set_color(v.indicator(last.client) and style.color.main or style.color.gray)
			end
		)))
	end

	return stateboxes
end

-- Function to construct menu line with action icons (minimize, close)
--------------------------------------------------------------------------------
local function action_line_construct(setup_layout, style)
	local sep = separator.vertical(style.separator)

	local function actionbox_construct(icon, action)
		local iconbox = svgbox(icon, nil, style.color.icon)
		iconbox:set_forced_width(style.action_iconsize.width)
		iconbox:set_forced_height(style.action_iconsize.height)

		-- center iconbox both vertically and horizontally
		local vert_wrapper = wibox.layout.align.vertical()
		vert_wrapper:set_second(iconbox)
		vert_wrapper:set_expand("outside")
		local horiz_wrapper = wibox.layout.align.horizontal()
		horiz_wrapper:set_second(vert_wrapper)
		horiz_wrapper:set_expand("outside")

		-- wrap into a background container to allow bg color change of area
		local actionbox = wibox.container.background(horiz_wrapper)

		-- set mouse action
		actionbox:buttons(awful.util.table.join(awful.button({}, 1,
			function()
				action()
			end
		)))
		actionbox:connect_signal("mouse::enter",
			function()
				iconbox:set_color(style.color.highlight)
				actionbox.bg = style.color.main
			end
		)
		actionbox:connect_signal("mouse::leave",
			function()
				iconbox:set_color(style.color.icon)
				actionbox.bg = nil
			end
		)
		return actionbox
	end

	-- minimize button
	local minimize_box = actionbox_construct(
		style.icon.minimize,
		function()
			last.client.minimized = not last.client.minimized
			if style.hide_action["min"] then clientmenu.menu:hide() end
		end
	)
	setup_layout:set_first(minimize_box)

	-- center element (either switch screen button or separator only)
	if style.enable_screen_switch and screen.count() > 1 then
		local inner = wibox.layout.align.horizontal()

		-- switch screen button
		local switch_screen_button = actionbox_construct(
			style.icon.switch_screen,
			function()
				redutil.placement.next_screen(last.client)
				clientmenu.menu:hide()
			end
		)
		-- button surrounded by separators
		inner:set_first(sep)
		inner:set_second(switch_screen_button)
		inner:set_third(sep)
		inner:set_forced_width(style.actionline.center_button_width)

		setup_layout:set_second(inner)
	else
		-- separator only
		setup_layout:set_second(sep)
	end

	-- close button
	local close_box = actionbox_construct(
		style.icon.close,
		function()
			last.client:kill()
			clientmenu.menu:hide()
		end
	)
	setup_layout:set_third(close_box)
end

-- Function to construct menu line with tag switches (for style.enable_tagline)
-----------------------------------------------------------------------------------
local function tag_line_construct(setup_layout, style)
	local tagboxes = {}
	setup_layout:reset()

	-- calculate number of tag mark per line
	local columns = math.ceil(#last.screen.tags / style.tagline.rows)
	setup_layout.forced_num_cols = columns

	-- setup tag marks
	for i, t in ipairs(last.screen.tags) do
		if not awful.tag.getproperty(t, "hide") then

			tagboxes[i] = svgbox(style.icon.tag)
			tagboxes[i]:set_forced_width(style.tag_iconsize.width)
			tagboxes[i]:set_forced_height(style.tag_iconsize.height)

			-- set widget in line
			local l = wibox.layout.align.horizontal()
			l:set_expand("outside")
			l:set_second(tagboxes[i])
			setup_layout:add(l)

			-- set mouse action
			tagboxes[i]:buttons(awful.util.table.join(
				awful.button({}, 1,
					function()
						last.client:move_to_tag(t)
						awful.layout.arrange(t.screen)
						clientmenu.hide_check("move")
					end
				),
				awful.button({ style.tagline_mod_key }, 1,
					function()
						last.client:move_to_tag(t)
						awful.layout.arrange(t.screen)
						clientmenu.hide_check("move")
						t:view_only()
					end
				),
				awful.button({}, 2,
					function()
						last.client:move_to_tag(t)
						awful.layout.arrange(t.screen)
						clientmenu.hide_check("move")
						t:view_only()
					end
				),
				awful.button({}, 3,
					function()
						last.client:toggle_tag(t)
						awful.layout.arrange(t.screen)
						clientmenu.hide_check("add")
					end
				)
			))
		end
	end

	return tagboxes
end

-- Calculate menu position
--------------------------------------------------------------------------------
local function coords_calc(menu)
	local coords = mouse.coords()
	coords.x = coords.x - menu.wibox.width / 2 - menu.wibox.border_width

	return coords
end

-- Initialize window menu widget
-----------------------------------------------------------------------------------------------------------------------
function clientmenu:init()
	local style = self._prebuilt_style or default_style()

	self.hide_check = function(action)
		if style.hide_action[action] then self.menu:hide() end
	end

	-- Create array of state icons
	-- associate every icon with action and state indicator
	--------------------------------------------------------------------------------
	local function icon_table_generator_prop(property)
		return {
			icon      = style.icon[property] or style.icon.unknown,
			action    = function() last.client[property] = not last.client[property]; self.hide_check(property) end,
			indicator = function(c) return c[property] end
		}
	end

	local state_icons = {
		icon_table_generator_prop("floating"),
		icon_table_generator_prop("sticky"),
		icon_table_generator_prop("ontop"),
		icon_table_generator_prop("below"),
		icon_table_generator_prop("maximized"),
	}

	-- Construct menu
	--------------------------------------------------------------------------------

	-- Window action line construction
	------------------------------------------------------------

	local actionline_horizontal = wibox.layout.align.horizontal()
	actionline_horizontal:set_expand("outside")
	local actionline = wibox.container.constraint(actionline_horizontal, "exact", nil, style.actionline.height)
	action_line_construct(actionline_horizontal, style)

	-- Window state line construction
	------------------------------------------------------------

	-- layouts
	local stateline_horizontal = wibox.layout.flex.horizontal()
	local stateline_vertical = wibox.layout.align.vertical()
	stateline_vertical:set_second(stateline_horizontal)
	stateline_vertical:set_expand("outside")
	local stateline = wibox.container.constraint(stateline_vertical, "exact", nil, style.stateline.height)

	-- set all state icons in line
	local stateboxes = state_line_construct(state_icons, stateline_horizontal, style)

	-- update function for state icons
	local function stateboxes_update(c, icons, boxes)
		for i, v in ipairs(icons) do
			boxes[i]:set_color(v.indicator(c) and style.color.main or style.color.gray)
		end
	end

	-- Separators config
	------------------------------------------------------------
	local menusep = { widget = separator.horizontal(style.separator) }

	-- menu item actions
	self.movemenu_action = function(t)
		last.client:move_to_tag(t); awful.layout.arrange(t.screen); self.hide_check("move")
	end

	self.addmenu_action = function(t)
		last.client:toggle_tag(t); awful.layout.arrange(t.screen); self.hide_check("add")
	end

	local menu_items = {}
	table.insert(menu_items, { widget = actionline, focus = true })
	table.insert(menu_items, menusep)
	if style.enable_tagline then
		-- Construct visual tag representations in a menu line
		self.tagline_container = wibox.layout.grid()
		self.tagline_container.forced_num_rows = style.tagline.rows
		self.tagline_container.spacing = style.tagline.spacing
		self.tagline_container.expand = true

		local tagline_vertical = wibox.layout.align.vertical()
		tagline_vertical:set_second(self.tagline_container)
		tagline_vertical:set_expand("outside")

		self.tagboxes = tag_line_construct(self.tagline_container, style)
		local tagline = wibox.container.constraint(tagline_vertical, "exact", nil, style.tagline.height)
		table.insert(menu_items, { widget = tagline, focus = true })
	else
		-- Construct tag submenus ("move" and "add")
		local movemenu_items = tagmenu_items(self.movemenu_action, style)
		local addmenu_items  = tagmenu_items(self.addmenu_action, style)
		table.insert(menu_items, { "Move to tag", { items = movemenu_items, theme = style.tagmenu } })
		table.insert(menu_items, { "Add to tag",  { items = addmenu_items,  theme = style.tagmenu } })
	end
	table.insert(menu_items, menusep)
	table.insert(menu_items, { widget = stateline, focus = true })


	-- Create menu
	------------------------------------------------------------
	self.menu = redmenu({
		theme = style.menu,
		items = menu_items
	})

	-- Widget update functions
	--------------------------------------------------------------------------------
	function self:update(c)
		if self.menu.wibox.visible then
			stateboxes_update(c, state_icons, stateboxes)
			if style.enable_tagline then
				self:tagline_update(c, style)
			else
				tagmenu_update(c, self.menu, { 1, 2 }, style)
			end
		end
	end

	-- Signals setup
	--------------------------------------------------------------------------------
	local client_signals = {
		"property::ontop", "property::floating", "property::below", "property::maximized",
		"tagged", "untagged"  -- refresh tagmenu when client's tags change
	}
	for _, sg in ipairs(client_signals) do
		client.connect_signal(sg, function() self:update(last.client) end)
	end
end

-- Function to rebuild the tag line entirely if screen and tags have changed
--------------------------------------------------------------------------------
function clientmenu:tagline_rebuild(style)
	self.tagboxes = tag_line_construct(self.tagline_container, style)
end

-- Function to update the tag line's icon states
--------------------------------------------------------------------------------
function clientmenu:tagline_update(c, style)
	if last.tag_screen ~= mouse.screen then
		self:tagline_rebuild(style)
		last.tag_screen = mouse.screen
	end
	for k, t in ipairs(last.screen.tags) do
		if not awful.tag.getproperty(t, "hide") then

			local icon_color = style.color.gray
			if c then
				local client_tags = c:tags()
				icon_color = awful.util.table.hasitem(client_tags, t) and style.color.main or icon_color
			end

			self.tagboxes[k]:set_color(icon_color)
		end
	end
end

-- Style setup
--------------------------------------------------------------------------------
function clientmenu:set_style(style)
	self._prebuilt_style = redutil.table.merge(default_style(), style or {})
end

-- Show window menu widget
-----------------------------------------------------------------------------------------------------------------------
function clientmenu:show(c)

	-- init menu if needed
	if not self.menu then self:init() end

	-- toggle menu
	if self.menu.wibox.visible and c == last.client and mouse.screen == last.screen  then
		self.menu:hide()
	else
		last.client = c
		last.screen = mouse.screen
		self.menu:show({ coords = coords_calc(self.menu) })

		if self.menu.hidetimer.started then self.menu.hidetimer:stop() end
		self:update(c)
	end
end

return setmetatable(clientmenu, clientmenu.mt)
