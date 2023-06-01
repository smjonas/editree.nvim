---@type editree.Tree
local M = {}

---@class editree.Tree
---@field type string
---@field name string
---@field id string
---@field parent editree.Tree?
---@field depth integer
---@field id_to_child_map fun(): table<string, editree.Tree>

---@class Directory : editree.Tree
---@field type "directory"
---@field children editree.Tree[]

---@class File : editree.Tree
---@field type "file"

local unpack = table.unpack or unpack

---@param name string
---@param id string?
---@param type "directory" | "file" | nil
function M.new(name, id, type)
	assert(type == nil or type == "directory" or type == "file")
	local self = { name = name, id = id, type = type or "directory", parent = nil, children = {}, depth = 0 }
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
---@param id string?
---@return Directory
function M:add_dir(name, id)
	assert(self.type == "directory")
	local dir = M.new(name, id, "directory")
	dir.parent = self
	dir.depth = self.depth + 1
	table.insert(self.children, dir)
	return dir
end

---@param name string
---@param id string?
---@return File
function M:add_file(name, id)
	assert(self.type == "directory", "attempting to add file to non-directory")
	local file = M.new(name, id, "file")
	file.parent = self
	file.depth = self.depth + 1
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

---@return table<string, editree.Tree>
function M:id_to_child_map()
	assert(self.type == "directory", "attempting to get child of non-directory")
	local map = {}
	for _, child in ipairs(self.children) do
		map[child.id] = child
	end
	return map
end

---@param self Directory
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

---@param self Directory
---@param ids_to_remove string[]
function M:remove_children_by_ids(ids_to_remove)
	assert(self.type == "directory")
	self.children = vim.tbl_filter(function(child)
		return not ids_to_remove[child.id]
	end, self.children)
end

---Returns a map mapping from the ID to a list of nodes with that ID.
---@param self Directory
---@param id_map table<string, list<editree.Tree>>?
---@return boolean
function M:get_recursive_id_map(id_map)
	assert(self.type == "directory")
	id_map = id_map or vim.defaulttable(function()
		return { nodes = {} }
	end)
	for _, child in ipairs(self.children) do
		if child.id then
			table.insert(id_map[child.id].nodes, child)
		end

		if child.type == "directory" then
			child:get_recursive_id_map(id_map)
		end
	end
	return id_map
end

---@param self Directory
---@return boolean
function M:contains_unique_names()
	assert(self.type == "directory")
	local saw_name = {}
	for _, child in ipairs(self.children) do
		if saw_name[child.name] then
			return false
		end
		saw_name[child.name] = true
	end
	return true
end

---Visits each node in the tree in a breadth-first manner and calls fn on every matching node.
---@param self Directory
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
	local id = (self.id and self.id .. "/ " or "") or ""
	local result = ("%s%s%s\n"):format(id, (" "):rep(depth), self.name, "\n")

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
