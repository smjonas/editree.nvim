local M = {}

local NodeType = require("editree.tree").NodeType

---@alias Diff DiffNew

---@class DiffNew
---@field type "new"
---@field name string

---@class DiffDelete
---@field type "delete"
---@field node Tree

---@class DiffRename
---@field type "rename"
---@field new_name string

---@param old_tree Tree
---@param new_tree Tree
---@param diffs table<Diff>
local compute_diffs = function(old_tree, new_tree, diffs)
	assert(old_tree.type == NodeType.DIRECTORY and new_tree.type == NodeType.DIRECTORY)
	local old_children_map = old_tree:id_to_child_map()
	local new_children_map = new_tree:id_to_child_map()
	for _, child in ipairs(old_tree.children) do
		local id = child.id
		if child.id then
      local old_child = old_tree:remove_child_by_id(id)
      assert(old_child)
			local new_child = new_tree:remove_child_by_id(id)
			if new_child then
				local new_name = new_child.name
				if old_child.name ~= new_name then
					table.insert(diffs, { type = "rename", node = child, new_name = new_name })
				end
			else
				-- ID was only present in old tree => deletion
				table.insert(diffs, { type = "delete", node = child })
			end
		end
	end
end

---@param old_tree Tree
---@param new_tree Tree
---@return Diff
M.compute = function(old_tree, new_tree)
	local diffs = {}
	compute_diffs(old_tree, new_tree, diffs)
	return diffs
end

return M
