---@class Tree
---@field name string
---@field id string
---@field type NodeType
---@field children Tree[]
local M = {}

---@enum NodeType
local NodeType = {
	DIRECTORY = 1,
	FILE = 2,
}

---@param name string
---@param id string?
---@param type NodeType?
function M.new(name, id, type)
	assert(type == nil or type == NodeType.DIRECTORY or type == NodeType.FILE)
	local self = { name = name, id = id, type = type or NodeType.DIRECTORY, children = {} }
	return setmetatable(self, {
		__index = M,
		__tostring = function()
			return M.to_string(self, 0)
		end,
	})
end

---@param name string
---@param id string
function M:add_dir(name, id)
	assert(self.type == NodeType.DIRECTORY)
	local dir = M.new(name, id, NodeType.DIRECTORY)
	table.insert(self.children, dir)
	return dir
end

---@param name string
---@param id string
function M:add_file(name, id)
	assert(self.type == NodeType.DIRECTORY, "attempting to add file to non-directory")
	table.insert(self.children, M.new(name, id, NodeType.FILE))
end

---@param depth integer
function M:to_string(depth)
	local is_dir = self.type == NodeType.DIRECTORY
	local result = (" "):rep(depth) .. self.name .. "\n"

	if is_dir then
		for _, child in ipairs(self.children) do
			result = result .. child:to_string(depth + 1)
		end
	end
	return result
end

return M
