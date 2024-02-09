local M = {}

local Stack = require("editree.stack")
local Tree = require("editree.tree")

local is_file = function(name)
	return not name:match("/$")
end

---@param line string
---@param dir_stack editree.Stack
---@return editree.Directory, integer
local visit_line = function(line, dir_stack)
	-- Count number of leading whitespaces
	local depth = #line:gsub("^(%s*).*", "%1")

	while #dir_stack > 0 and depth <= dir_stack:top().depth do
		dir_stack:pop()
	end

	local parent_dir = dir_stack:top()
  local name = line:sub(depth + 1)
	if is_file(name) then
		parent_dir:add_file(name)
	else
		local new_dir = parent_dir:add_dir(name)
		dir_stack:push(new_dir)
	end
	return parent_dir, depth
end

-- Parses a tree given in the text-based format
-- (the number of leading whitespace determines the depth):
-- root/
--  folder1/
--   file1.txt
--   file2.txt
--   subfolder1/
--    subfile1.txt
--   folder2/
--    file3.txt
--   file4.txt
--
---@param lines string[]
---@return editree.Tree
M.parse_tree = function(lines)
	local tree = Tree.new(lines[1])
	local dir_stack = Stack.new()

	local cur_dir = tree
	dir_stack:push(cur_dir)

	for i = 2, #lines do
		cur_dir = visit_line(lines[i], dir_stack)
	end
	return tree
end

---@param view editree.View
---@param lines string[]
---@param ignore_invalid_ids boolean
---@return boolean success, editree.Tree? tree
M.parse_tree_with_ids = function(view, lines, ignore_invalid_ids)
	-- Remove blank lines
	lines = vim.iter(lines)
		:filter(function(line)
			return not line:find("^%s*$")
		end)
		:totable()

	local max_id = #lines
	local ok, tree = M._build_tree(view, lines, function(line)
		local _, _, id = line:find("^/(%d+) ")
		if id then
			if not ignore_invalid_ids and tonumber(id) > max_id or tonumber(id) == 0 then
				-- Unexpected ID
				return false
			end
		end
		return id
	end)
	return ok, tree
end

return M
