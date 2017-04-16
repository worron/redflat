-----------------------------------------------------------------------------------------------------------------------
--                                               RedFlat time stamp                                                  --
-----------------------------------------------------------------------------------------------------------------------
-- Make time stamp on every awesome exit or restart
-- It still working if user config was broken and default rc loaded
-- Time stamp may be useful for making diffrence between awesome wm first run or restart
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local tonumber = tonumber
local io = io
local os = os

local awful = require("awful")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local timestamp = {}

timestamp.path = "/tmp/awesome-stamp"
timestamp.timeout = 5
-- timestamp.bin = "~/awesome4/bin/awesome-client" -- !!! fix this on after final migration !!!
timestamp.bin = "awesome-client"

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local awful = require("awful")
local redutil = require("redflat.util")

-- Stamp functions
-----------------------------------------------------------------------------------------------------------------------

-- make time stamp
function timestamp.make()
	local file = io.open(timestamp.path, "w")
	file:write(os.time())
	file:close()
end

-- get time stamp
function timestamp.get()
	res = redutil.read.file(timestamp.path)
	if res then return tonumber(res) end
end

-- check if it is first start
function timestamp.is_startup()
	local stamp = timestamp.get()
	return not stamp or (os.time() - stamp) > timestamp.timeout
end

-- Connect exit signal on module initialization
-----------------------------------------------------------------------------------------------------------------------
awesome.connect_signal("exit",
	function()
		timestamp.make()
		awful.spawn.with_shell(
			string.format("sleep 2 && %s ", timestamp.bin)
			.. [["if timestamp == nil then timestamp = require('redflat.timestamp') end"]]
		)
	end
)

-----------------------------------------------------------------------------------------------------------------------
return timestamp
