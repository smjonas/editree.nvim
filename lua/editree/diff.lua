local M = {}

---@alias editree.Diff DiffCreate | DiffDelete | DiffRename | DiffCopy | DiffMove

---@class DiffCreate
---@field type "create"
---@field node editree.Tree

---@class DiffDelete
---@field type "delete"
---@field node editree.Tree

---@class DiffRename
---@field type "rename"
---@field node editree.Tree
---@field new_name string

---@class DiffCopy
---@field type "copy"
---@field node editree.Tree
---@field to editree.Tree

---@class DiffMove
---@field type "move"
---@field node editree.Tree
---@field to editree.Tree

local compute_diffs
---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@param diffs table<editree.Diff>
compute_diffs = function(old_tree, old_id_map, new_tree, new_id_map, diffs)
	assert(old_tree.type == "directory" and new_tree.type == "directory")

	local old_children_map = old_tree:id_to_child_map()
	local old_children_to_remove = {}

	for _, child in ipairs(old_tree.children) do
		local id = child.id
		assert(id, "child in old tree must have an ID")
		local old_child = old_children_map[id]
		assert(old_child)
		assert(#old_id_map[id].nodes == 1, "old ID should only occur once")
		local new_child = new_tree:remove_child_by_id(id)
		if new_child then
			local new_name = new_child.name
			local is_copy = #new_id_map[id].nodes > #old_id_map[id].nodes
			-- If there are more copies of the file than before, only mark files
			-- with a different name as copies
			if child.name ~= new_name then
				if is_copy then
					table.insert(diffs, { type = "copy", node = child, to = new_child })
					new_tree:remove_child_by_id(id)
				else
					table.insert(diffs, { type = "rename", node = child, new_name = new_name })
					new_tree:remove_child_by_id(id)
				end
			end
			if child.type == "directory" and new_child.type == "directory" then
				compute_diffs(child, old_id_map, new_child, new_id_map, diffs)
			elseif child.type ~= new_child.type then
				print("Warning: directory type changed")
			end
			old_children_to_remove[id] = true
		elseif vim.tbl_isempty(new_id_map[id].nodes) then
			-- ID was only present in old tree => deletion
			table.insert(diffs, { type = "delete", node = child })
			old_children_to_remove[id] = true
		else
			table.insert(diffs, { type = "move", node = old_id_map[id].nodes[1], to = child })
			new_tree:remove_child_by_id(id)
		end
	end
	old_tree:remove_children_by_ids(old_children_to_remove)
end

---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@param diffs table<editree.Diff>
local compute_inserts = function(old_tree, new_tree, diffs)
	local old_id_map = old_tree:get_recursive_id_map()
	local new_id_map = new_tree:get_recursive_id_map()

	for new_id, nodes in pairs(new_id_map) do
		local new_node_count = #new_id_map[new_id].nodes
		if new_node_count > 1 then
			-- table.insert(diff, {type='insert', node= }, value)
		end
	end
	new_tree:for_each(function(node)
		if node.id == nil and not node:is_root() then
			table.insert(diffs, { type = "create", node = node })
		end
	end)
end

---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@return boolean success, string? error
local verify_trees = function(old_tree, new_tree)
	local ok = true
	new_tree:for_each(function(dir)
		if not dir:contains_unique_names() then
			ok = false
		end
	end, "directory")
	if not ok then
		return false, "duplicate names in new tree"
	end

	local old_id_map = old_tree:get_recursive_id_map()

	for new_id, _ in pairs(new_tree:get_recursive_id_map()) do
		if vim.tbl_isempty(old_id_map[new_id].nodes) then
			return false, "unknown ID in new tree"
		end
	end
	return true
end

---@param old_tree editree.Tree
---@param new_tree editree.Tree
---@return boolean success, any
M.compute = function(old_tree, new_tree)
	local diffs = {}

	local ok, err = verify_trees(old_tree, new_tree)
	if not ok then
		return false, err
	end
	compute_diffs(old_tree, old_tree:get_recursive_id_map(), new_tree, new_tree:get_recursive_id_map(), diffs)
	compute_inserts(old_tree, new_tree, diffs)
	return true, diffs
end

return M

---@class oil.CreateAction
---@field type "create"
---@field url string
---@field entry_type oil.EntryType
---@field link nil|string


