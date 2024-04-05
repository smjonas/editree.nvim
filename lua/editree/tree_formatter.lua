--- Responsible for turning a tree into buffer lines.

local M = {}

---@param view editree.View
---@param tree editree.Tree
---@return string[] #the buffer lines formatted according to the view
M.tree_to_lines = function(view, tree)
	print("tree_to_lines with tree:\n" .. tostring(tree))
	local lines = {}
	tree:for_each(function(node)
    print("Result of tree_to_lines: " .. view:tree_node_tostring(node) .. ", node: " .. node.type)
		table.insert(lines, view:tree_node_tostring(node))
	end)
	print("Resulting buffer lines:" .. vim.inspect(lines))
	return lines
end

return M
