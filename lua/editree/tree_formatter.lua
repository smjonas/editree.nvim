--- Responsible for turning a tree into buffer lines.

local M = {}

---@param view editree.View
---@param tree editree.Tree
---@return string[] #the buffer lines formatted according to the view
M.tree_to_lines = function(view, tree)
  print("tree_to_lines")
	local lines = {}
	tree:for_each(function(node)
		table.insert(lines, view:tree_node_tostring(node))
	end)
  print(lines[2])
	return lines
end

return M
