local M = {}

local tree_ops = require("editree.tree_ops")

---@alias editree.Diff DiffCreate | DiffDelete | DiffRename | DiffCopy | DiffMove

---@class DiffCreate
---@field type "create"
---@field node editree.Tree

---@class DiffDelete
---@field type "delete"
---@field node_id string
---@field node editree.Tree?

---@class DiffRename
---@field type "rename"
---@field node_id editree.Tree
---@field node editree.Tree?
---@field new_name string

---@class DiffCopy
---@field type "copy"
---@field node_id string
---@field node editree.Tree?
---@field to editree.Tree

---@class DiffMove
---@field type "move"
---@field node_id string
---@field node editree.Tree?
---@field to editree.Tree

local create_node = function(node, diffs)
	table.insert(diffs, { type = "create", node = node })
end

local delete_node = function(node_id, diffs)
	table.insert(diffs, { type = "delete", node_id = node_id })
end

local rename_node = function(node_id, new_name, diffs)
	table.insert(diffs, { type = "rename", node_id = node_id, new_name = new_name })
end

local copy_node = function(node_id, to, diffs)
	table.insert(diffs, { type = "copy", node_id = node_id, to = to })
end

local move_node = function(node_id, to, diffs)
	table.insert(diffs, { type = "move", node_id = node_id, to = to })
end

local compute_diffs
---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@param diffs editree.Diff[]
compute_diffs = function(old_tree, old_id_map, new_tree, new_id_map, diffs)
	assert(old_tree.type == "directory" and new_tree.type == "directory")

	local old_children_map = tree_ops.id_to_child_map(old_tree)
	local old_children_to_remove = {}

	for _, child in ipairs(old_tree.children) do
		local old_id = child.id
		assert(old_id, "child in old tree must have an ID")
		local old_child = old_children_map[old_id]
		assert(old_child)
		assert(#old_id_map[old_id] == 1, "old ID should only occur once")
		local present_in_new_tree, new_child = new_tree:remove_child_by_id(old_id)
		if present_in_new_tree then
			assert(new_child)
			local new_name = new_child.name
			local is_copy = #new_id_map[old_id] > #old_id_map[old_id]
			-- If there are more copies of the file than before, only mark files
			-- with a different name as copies
			if child.name ~= new_name then
				if is_copy then
					copy_node(old_id, new_child, diffs)
				else
					rename_node(old_id, new_name, diffs)
				end
				new_tree:remove_child_by_id(old_id)
			end
			if child.type == "directory" and new_child.type == "directory" then
				compute_diffs(child, old_id_map, new_child, new_id_map, diffs)
			elseif child.type ~= new_child.type then
				print("Warning: directory type changed")
			end
			old_children_to_remove[old_id] = true
		elseif vim.tbl_isempty(new_id_map[old_id]) then
			-- ID was only present in old tree => deletion
			delete_node(old_id, diffs)
			old_children_to_remove[old_id] = true
		else
			move_node(old_id, child, diffs)
			new_tree:remove_child_by_id(old_id)
		end
	end
	old_tree:remove_children_by_ids(old_children_to_remove)
end

---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@param diffs table<editree.Diff>
local compute_inserts = function(old_tree, new_tree, diffs)
	local old_id_map = tree_ops.get_recursive_id_map(old_tree)
	local new_id_map = tree_ops.get_recursive_id_map(new_tree)

	for new_id, nodes in pairs(new_id_map) do
		local new_node_count = #new_id_map[new_id]
		if new_node_count > 1 then
			-- table.insert(diff, {type='insert', node= }, value)
		end
	end
	new_tree:for_each(function(node)
		if node.id == nil and not node:is_root() then
			create_node(node, diffs)
		end
	end)
end

---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@return boolean success, string? error
local verify_trees = function(old_tree, new_tree)
	local ok = true
	new_tree:for_each(function(dir)
		-- TODO: why is this now allowed??
		if not tree_ops.contains_unique_names(dir) then
			ok = false
		end
	end, "directory")
	if not ok then
		return false, "duplicate names in new tree"
	end

	local old_id_map = tree_ops.get_recursive_id_map(old_tree)

	for new_id, _ in pairs(tree_ops.get_recursive_id_map(new_tree)) do
		if vim.tbl_isempty(old_id_map[new_id]) then
			return false, "unknown ID in new tree"
		end
	end
	return true
end

---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@return boolean success, editree.Diff[]
M.compute = function(old_tree, new_tree)
	local ok, err = verify_trees(old_tree, new_tree)
	if not ok then
		return false, err
	end

	local diffs = {}
	local old_id_map = tree_ops.get_recursive_id_map(old_tree)
	compute_diffs(old_tree, old_id_map, new_tree, tree_ops.get_recursive_id_map(new_tree), diffs)
	compute_inserts(old_tree, new_tree, diffs)
	vim.tbl_map(function(diff)
		if not diff.node then
			diff.node = old_id_map[diff.node_id]
		end
	end, diffs)
	return true, diffs
end

return M
