local M = {}

local Type = {
	DIRECTORY = 1,
	FILE = 2,
}

function M.new(name, type)
	assert(type == nil or type == Type.DIRECTORY or type == Type.FILE)
	local self = { name = name, type = type or Type.DIRECTORY, children = {} }
	return setmetatable(self, {
		__index = M,
		__tostring = function()
			return M.to_string(self, 0)
		end,
	})
end

function M:add_dir(name)
	assert(self.type == Type.DIRECTORY)
	local dir = M.new(name)
	table.insert(self.children, dir)
	return dir
end

function M:add_file(name)
	assert(self.type == Type.DIRECTORY, "attempting to add file to non-directory")
	table.insert(self.children, M.new(name, Type.FILE))
end

function M:to_string(depth)
	local is_dir = self.type == Type.DIRECTORY
	local result = (" "):rep(depth) .. self.name .. "\n"

	if is_dir then
		for _, child in ipairs(self.children) do
			result = result .. child:to_string(depth + 1)
		end
	end
	return result
end

return M
