---@class editree.Tree
local M = {}

---@class editree.Tree
---@field type string
---@field name string
---@field id string?
---@field parent editree.Tree?
---@field depth integer
---@field id_to_child_map fun(): table<string, editree.Tree>

---@class editree.Directory : editree.Tree
---@field type "directory"
---@field children editree.Tree[]

---@class editree.File : editree.Tree
---@field type "file"

local unpack = table.unpack or unpack

---@param name string
---@param type "directory" | "file" | nil
function M.new(name, type)
	assert(type == nil or type == "directory" or type == "file")
	local self = { name = name, type = type or "directory", parent = nil, children = {}, depth = 0 }
	return setmetatable(self, {
		__index = M,
		__tostring = function()
			-- Remove last "\n"
			return M.to_string(self, 0):sub(1, -2)
		end,
	})
end

function M:is_root()
	return self.parent == nil
end

---@param name string
---@param id string? optional ID associated with this directory, used in tests
---@return editree.Directory
function M:add_dir(name, id)
	assert(self.type == "directory")
	local dir = M.new(name, "directory")
	dir.parent = self
	dir.depth = self.depth + 1
  dir.id = id
	table.insert(self.children, dir)
	return dir
end

---@param name string
---@param id string? optional ID associated with this file, used in tests
---@return editree.File
function M:add_file(name, id)
	assert(self.type == "directory", "attempting to add file to non-directory")
	local file = M.new(name, "file")
	file.parent = self
	file.depth = self.depth + 1
  file.id = id
	table.insert(self.children, file)
	return file
end

---Returns the path relative to the root directory
---@return string
function M:get_rel_path()
	local parts = {}
	local node = self
	while not node:is_root() do
		table.insert(parts, node.name)
		node = node.parent
	end
	parts = vim.iter(parts):rev():totable()
	return vim.fs.joinpath((table.unpack or unpack)(parts))
end

-- TODO: move complex operations to separate class
---@param self editree.Tree
---@param id string
---@return editree.Tree? child #the removed child if it could be removed or nil if the child with the given ID did not exist
function M:remove_child_by_id(id)
	assert(self.type == "directory")
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

---@param self editree.Tree
---@param ids_to_remove string[]
function M:remove_children_by_ids(ids_to_remove)
	assert(self.type == "directory")
	self.children = vim.tbl_filter(function(child)
		return not ids_to_remove[child.id]
	end, self.children)
end

---@todo: swap arguments for better readability
---Visits each node in the tree in a breadth-first manner and calls fn on every matching node.
---@param self editree.Tree
---@param type "directory" | "file" | nil
---@param fn fun(editree.Tree)
function M:for_each(fn, type)
	assert(self.type == "directory")
	if self:is_root() and (type == nil or self.type == type) then
		fn(self)
	end
	for _, child in ipairs(self.children) do
		if type == nil or child.type == type then
			fn(child)
		end
		if child.type == "directory" then
			child:for_each(fn, type)
		end
	end
end

---@param depth integer
function M:to_string(depth)
	local is_dir = self.type == "directory"
  local suffix = is_dir and "/" or ""
	local result = ("%s%s%s\n"):format((" "):rep(depth), self.name, suffix)

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
