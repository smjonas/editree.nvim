---@class Tree
---@field name string
---@field id string
---@field type NodeType
---@field children Tree[]
local M = {}

---@enum NodeType
M.NodeType = {
	DIRECTORY = 1,
	FILE = 2,
}

---@param name string
---@param id string?
---@param type NodeType?
function M.new(name, id, type)
	assert(type == nil or type == M.NodeType.DIRECTORY or type == M.NodeType.FILE)
	local self = { name = name, id = id, type = type or M.NodeType.DIRECTORY, children = {} }
	return setmetatable(self, {
		__index = M,
		__tostring = function()
			return M.to_string(self, 0)
		end,
	})
end

---@param name string
---@param id string?
function M:add_dir(name, id)
	assert(self.type == M.NodeType.DIRECTORY)
	local dir = M.new(name, id, M.NodeType.DIRECTORY)
	table.insert(self.children, dir)
	return dir
end

---@param name string
---@param id string?
---@return Tree #the inserted file
function M:add_file(name, id)
	assert(self.type == M.NodeType.DIRECTORY, "attempting to add file to non-directory")
  local file = M.new(name, id, M.NodeType.FILE)
	table.insert(self.children, file)
  return file
end

---@return table<string, Tree>
function M:id_to_child_map()
	assert(self.type == M.NodeType.DIRECTORY, "attempting to get child of non-directory")
	return vim.iter(self.children)
		:map(function(child)
			return child.id, child
		end)
		:totable()
end

---@param id string
---@return Tree? child #the removed child if it could be removed  or nil if the child with the given ID did not exist
function M:remove_child_by_id(id)
	local idx = -1
	for i, child in ipairs(self.children) do
		if child.id == id then
			idx = i
		end
	end
  if idx == -1 then
    return nil
  end
	return table.remove(self.children, idx)
end

---@param depth integer
function M:to_string(depth)
	local is_dir = self.type == M.NodeType.DIRECTORY
	local result = (" "):rep(depth) .. self.name .. "\n"

	if is_dir then
		for _, child in ipairs(self.children) do
			result = result .. child:to_string(depth + 1)
		end
	end
	return result
end

function M:clone()
  return vim.deepcopy(self)
end

return M
