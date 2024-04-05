--- Turning a view into a tree.

local M = {}

local Stack = require("editree.stack")
local Tree = require("editree.tree")

local is_file = function(name)
	return not name:match("/$")
end

---@return string
local clean_node_name = function(name)
	local result, _ = name:gsub("/", "")
	return result
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
	local name, _ = line:sub(depth + 1)
	if is_file(name) then
		parent_dir:add_file(clean_node_name(name))
	else
		local new_dir = parent_dir:add_dir(clean_node_name(name))
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
	lines[1], _ = lines[1]:gsub("/", "")
	local tree = Tree.new(lines[1])
	local dir_stack = Stack.new()

	local cur_dir = tree
	dir_stack:push(cur_dir)

	for i = 2, #lines do
		cur_dir = visit_line(lines[i], dir_stack)
	end
	return tree
end

local remove_blank_lines = function(lines)
	return vim.tbl_filter(function(line)
		return not line:match("^%s*$")
	end, lines)
end

---@param line string
---@param ignore_invalid_id boolean
---@param max_id number
---@return string?
local function try_extract_id(line, ignore_invalid_id, max_id)
	local _, _, id = line:find("^/(%d+) ")
	if id then
		if not ignore_invalid_id and tonumber(id) > max_id or tonumber(id) == 0 then
			-- Unexpected ID
			return nil
		end
	end
  return id
end

---@param lines string[]
---@param ignore_invalid_ids boolean
---@return boolean success, editree.Tree? tree
M.parse_tree_with_ids = function(lines, ignore_invalid_ids)
	lines = remove_blank_lines(lines)
	local max_id = #lines

	lines[1], _ = lines[1]:gsub("/", "")
	local tree = Tree.new(lines[1])
	local dir_stack = Stack.new()

	local cur_dir = tree
	dir_stack:push(cur_dir)

	for i = 2, #lines do
		local id = try_extract_id(lines[i], ignore_invalid_ids, max_id)
		if not id and not ignore_invalid_ids then
			return false, nil
		end
		cur_dir = visit_line(lines[i], dir_stack)
	end
	return true, tree
end

return M
