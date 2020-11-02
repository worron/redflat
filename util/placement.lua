-- RedFlat util submodule

local awful = require("awful")

local placement = {}
local direction = { x = "width", y = "height" }

-- Functions
-----------------------------------------------------------------------------------------------------------------------
function placement.add_gap(geometry, gap)
	return {
		x = geometry.x + gap,
		y = geometry.y + gap,
		width = geometry.width - 2 * gap,
		height = geometry.height - 2 * gap
	}
end

function placement.no_offscreen(object, gap, area)
	local geometry = object:geometry()
	local border = object.border_width

	local screen_idx = object.screen or awful.screen.getbycoord(geometry.x, geometry.y)
	area = area or screen[screen_idx].workarea
	if gap then area = placement.add_gap(area, gap) end

	for coord, dim in pairs(direction) do
		if geometry[coord] + geometry[dim] + 2 * border > area[coord] + area[dim] then
			geometry[coord] = area[coord] + area[dim] - geometry[dim] - 2*border
		elseif geometry[coord] < area[coord] then
			geometry[coord] = area[coord]
		end
	end

	object:geometry(geometry)
end

-- make window fit screen bounds
local function control_off_screen(window, workarea)
	local wa = workarea or screen[window.screen].workarea
	local wg = window:geometry()

	if wg.width > wa.width then window:geometry({ width = wa.width, x = wa.x }) end
	if wg.height > wa.height then window:geometry({ height = wa.height, y = wa.y }) end

	placement.no_offscreen(window, nil, wa)
end

local function centered_base(is_h, is_v)
	return function(object, gap, area)
		local geometry = object:geometry()
		local new_geometry = {}

		local screen_idx = object.screen or awful.screen.getbycoord(geometry.x, geometry.y)
		area = area or screen[screen_idx].geometry
		if gap then area = placement.add_gap(area, gap) end

		if is_h then new_geometry.x = area.x + (area.width - geometry.width) / 2 - object.border_width end
		if is_v then new_geometry.y = area.y + (area.height - geometry.height) / 2 - object.border_width end

		return object:geometry(new_geometry)
	end
end

-- attempts to move the focused client to the next screen (if screen.count() > 1)
-- if a specific client is not passed via 'c', the focused client is selected
function placement.next_screen(c)
	local client_ = c or client.focus
	if not client_ then return end
	local next_idx = client_.screen.index + 1
	local next_screen = screen[ next_idx > screen.count() and 1 or next_idx ]
	if screen.count() > 1 then
		client_:move_to_screen(next_screen)
		control_off_screen(client_, next_screen.workarea)
	end
end

placement.centered = setmetatable({}, {
	__call = function(_, ...) return centered_base(true, true)(...) end
})
placement.centered.horizontal = centered_base(true, false)
placement.centered.vertical = centered_base(false, true)


-- End
-----------------------------------------------------------------------------------------------------------------------
return placement

