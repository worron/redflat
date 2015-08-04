-----------------------------------------------------------------------------------------------------------------------
--                                             RedFlat svg icon widget                                               --
-----------------------------------------------------------------------------------------------------------------------
-- Imagebox widget modification
-- Use Gtk PixBuf API to resize svg image
-- Color setup added
-----------------------------------------------------------------------------------------------------------------------
-- Some code was taken from
------ wibox.widget.imagebox v3.5.2
------ (c) 2010 Uli Schlachter
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local string = string
local type = type
local pcall = pcall
local print = print
local math = math
local os = os

local pixbuf = require("lgi").GdkPixbuf
local cairo = require("lgi").cairo
local base = require("wibox.widget.base")
local surface = require("gears.surface")
local awful = require("awful")
local color = require("gears.color")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local svgbox = { mt = {} }

svgbox.tempdir = "/tmp/awesome/"
os.execute("mkdir -p " .. svgbox.tempdir)

-- weak table is useless here
-- TODO: implement mechanics to clear cache
local cache = setmetatable({}, { __mode = 'k' })
local tmp_counter = 0

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

-- Counter for temporary files
local function next_tmp()
	tmp_counter = (tmp_counter + 1) % 10000
	return tmp_counter
end

-- Check if given argument is SVG file
local function is_svg(args)
	return type(args) == "string" and string.match(args, "\.svg")
end

-- Check if need scale image
local function need_scale(widg, width, height)
	return (widg._image.width ~= width or widg._image.height ~= height) and widg.resize_allowed
end

-- Cache functions
local function get_cache(file, width, height)
	return cache[file .. "-" .. width .. "x" .. height]
end

local function set_cache(file, width, height, surf)
	cache[file .. "-" .. width .. "x" .. height] = surf
end

-- Create cairo surface from SVG file with given sizes
local function surface_from_svg(file, width, height)
	local surf

	-- check cache
	local cached = get_cache(file, width, height)
	if cached then return cached end
	-- naughty.notify({ text = file })

	-- generate name for temporary file
	local tempfile = svgbox.tempdir .. tostring(next_tmp()) .. ".png"

	-- load Gtk pixbuf from SVG file with wanted sizes
	-- and save resized image to temporary png file
	local buf = pixbuf.Pixbuf.new_from_file_at_scale(file, width, height, true)
	buf:savev(tempfile, "png", {}, {})

	-- load cairo surface from temporary png file
	if awful.util.file_readable(tempfile) then
		-- surf = surface.load(tempfile)
		surf = cairo.ImageSurface.create_from_png(tempfile)
		set_cache(file, width, height, surf)
		os.execute("rm " .. tempfile)
	end

	return surf
end

-- Returns a new svgbox
-----------------------------------------------------------------------------------------------------------------------
function svgbox.new(image, resize_allowed, newcolor)

	-- Create custom widget
	--------------------------------------------------------------------------------
	local widg = base.make_widget()

	-- User functions
	------------------------------------------------------------
	function widg:set_image(image_name)
		local image

		if type(image_name) == "string" then
			local success, result = pcall(surface.load, image_name)
			if not success then
				print("Error while reading '" .. image_name .. "': " .. result)
				return false
			end
			self.image_name = image_name
			image = result
		else
			image = surface.load(image_name)
		end

		if image and (image.height <= 0 or image.width <= 0) then return false end

		self._image = image
		self.is_svg = is_svg(image_name)

		self:emit_signal("widget::updated")
		return true
	end

	function widg:set_size(args)
		local args = args or {}
		self.width = args.width or self.width
		self.height = args.height or self.height
		self:emit_signal("widget::updated")
	end

	function widg:set_color(new_color)
		self.color = new_color
		self:emit_signal("widget::updated")
	end

	function widg:set_resize(allowed)
		self.resize_allowed = allowed
		self:emit_signal("widget::updated")
	end

	function widg:set_vector_resize(allowed)
		self.vector_resize_allowed = allowed
		self:emit_signal("widget::updated")
	end

	-- Fit
	------------------------------------------------------------
	function widg:fit(width, height)
		if self.width or self.height then
			return self.width or width, self.height or height
		else
			if not self._image then return 0, 0 end

			local w, h = self._image.width, self._image.height

			if self.resize_allowed or w > width or h > height then
				local aspect = math.min(width / w, height / h)
				return w * aspect, h * aspect
			end

			return w, h
		end
	end

	-- Draw
	------------------------------------------------------------
	function widg:draw(wibox, cr, width, height)
		if width == 0 or height == 0 or not self._image then return end

		cr:save()
		-- let's scale the image so that it fits into (width, height)
		if need_scale(self, width, height) then
			local w, h = self._image.width, self._image.height
			local aspect = math.min(width / w, height / h)
			if self.is_svg and self.vector_resize_allowed then
				-- for vector image
				local new_surface = surface_from_svg(self.image_name, math.floor(w * aspect), math.floor(h * aspect))
				if new_surface then self._image = new_surface end
			else
				-- for raster image
				cr:scale(aspect, aspect)
			end
		end

		-- set icon color if need
		if self.color then
			cr:set_source(color(self.color))
			cr:mask(cairo.Pattern.create_for_surface(self._image), 0, 0)
		else
			cr:set_source_surface(self._image, 0, 0)
			cr:paint()
		end

		cr:restore()
	end

	--------------------------------------------------------------------------------
	if resize_allowed ~= nil then
		widg.resize_allowed = resize_allowed
	else
		widg.resize_allowed = true
	end

	widg.color = newcolor
	widg.vector_resize_allowed = true

	if image then widg:set_image(image) end

	return widg
end

-- Config metatable to call svgbox module as function
-----------------------------------------------------------------------------------------------------------------------
function svgbox.mt:__call(...)
	return svgbox.new(...)
end

return setmetatable(svgbox, svgbox.mt)
