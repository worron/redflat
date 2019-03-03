-- RedFlat util submodule

local wibox = require("wibox")
local awful = require("awful")

local desktop = { build = {} }

-- Functions
-----------------------------------------------------------------------------------------------------------------------
local function sum(t, n)
	local s = 0
	local n = n or #t
	for i = 1, n do s = s + t[i] end
	return s
end

local function wposition(grid, n, workarea, dir)
	local total = sum(grid[dir])
	local full_gap = sum(grid.edge[dir])
	local gap = #grid[dir] > 1 and (workarea[dir] - total - full_gap) / (#grid[dir] - 1) or 0

	local current = sum(grid[dir], n - 1)
	local pos = grid.edge[dir][1] + (n - 1) * gap + current

	return pos
end

-- Calculate size and position for desktop widget
------------------------------------------------------------
function desktop.wgeometry(grid, place, workarea)
	return {
		x = wposition(grid, place[1], workarea, "width"),
		y = wposition(grid, place[2], workarea, "height"),
		width  = grid.width[place[1]],
		height = grid.height[place[2]]
	}
end

-- Edge constructor
------------------------------------------------------------
function desktop.edge(direction, zone)
	local edge = { area = {} }

	edge.wibox = wibox({
		bg      = "#00000000",  -- transparent without compositing manager
		opacity = 0,            -- transparent with compositing manager
		ontop   = true,
		visible = true
	})

	edge.layout = wibox.layout.fixed[direction]()
	edge.wibox:set_widget(edge.layout)

	if zone then
		for i, z in ipairs(zone) do
			edge.area[i] = wibox.container.margin(nil, 0, 0, z)
			edge.layout:add(edge.area[i])
		end
	end

	return edge
end

-- Desktop widgets pack constructor
------------------------------------------------------------
function desktop.build.static(objects, buttons)
	for _, object in ipairs(objects) do
		-- make individual wibox for each widget
		object.wibox = wibox({ type = "desktop", visible = true, bg = object.body.style.color.wibox })
		object.wibox:geometry(object.geometry)
		object.wibox:set_widget(object.body.area)

		if buttons then object.wibox:buttons(buttons) end
	end
end

function desktop.build.dynamic(objects, s, bgimage, buttons)
	local s = s or mouse.screen
	local bg = awful.util.file_readable(bgimage or "") and bgimage or nil

	-- manual layout
	local dlayout = wibox.layout.manual()
	for _, object in ipairs(objects) do dlayout:add_at(object.body.area, object.geometry) end
	if buttons then dlayout:buttons(buttons) end

	-- shared desktop wibox
	local dwibox = wibox({ type = "desktop", visible = true, bg = "#00000000", bgimage = bg })
	dwibox:geometry(s.workarea)
	dwibox:set_widget(dlayout)

	-- show widgets only for empty desktop
	local function update_desktop()
		local clients = s:get_clients()
		dwibox.visible = #clients == 0
	end

	-- better way to check visible clients?
	local client_signals = {
		"property::sticky", "property::minimized", "property::screen", "property::hidden",
		"tagged", "untagged", "list"
	}

	local tag_signals = { "property::selected", "property::activated" }

	for _, sg in ipairs(client_signals) do client.connect_signal(sg, update_desktop) end
	for _, sg in ipairs(tag_signals) do tag.connect_signal(sg, update_desktop) end
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return desktop

