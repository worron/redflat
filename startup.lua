-----------------------------------------------------------------------------------------------------------------------
--                                              RedFlat startup check                                                --
-----------------------------------------------------------------------------------------------------------------------
-- Save exit reason to file
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local io = io

local redutil = require("redflat.util")

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local startup = {}

startup.path = "/tmp/awesome-exit-reason"
startup.bin  = "awesome-client"

local REASON = { RESTART = "restart", EXIT =  "exit" }

-- Stamp functions
-----------------------------------------------------------------------------------------------------------------------

-- save restart reason
function startup.stamp(reason_restart)
	local file = io.open(startup.path, "w")
	file:write(reason_restart)
	file:close()
end

-- check if it is first start
function startup.is_startup()
	local reason = redutil.read.file(startup.path)
	return not reason or reason == REASON.EXIT
end

function startup:activate()
	awesome.connect_signal("exit",
	   function(is_restart) startup.stamp(is_restart and REASON.RESTART or REASON.EXIT) end
	)
end

-----------------------------------------------------------------------------------------------------------------------
return startup
