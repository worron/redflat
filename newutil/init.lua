-----------------------------------------------------------------------------------------------------------------------
--                                                   RedFlat library                                                 --
-----------------------------------------------------------------------------------------------------------------------

local wrequire(table, key)
	local module = rawget(table, key)
	return module or require(table._NAME .. '.' .. key)
end

local setmetatable = setmetatable

local lib = { _NAME = "redflat.newutil" }

return setmetatable(lib, { __index = wrequire })
