-- RedFlat util submodule

local io = io
local assert = assert

local read = {}

-- Functions
-----------------------------------------------------------------------------------------------------------------------
function read.file(path)
	local file = io.open(path)

	if file then
		output = file:read("*a")
		file:close()
	else
		return nil
	end

	return output
end

function read.output(cmd)
	local file = assert(io.popen(cmd, 'r'))
	local output = file:read('*all')
	file:close()

	return output
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return read
