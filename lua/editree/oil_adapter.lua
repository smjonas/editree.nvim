-- The oil adapter is responsible for parsing a tree view representation provided
-- by a supported file browser (e.g. nvim-tree) into a list of nodes (i.e. directories
-- or files). The node structures are used to determine the modifications applied
-- to the root directory.

-- Insert enter: init from view

---@class OilAdapter
local M = {}

---@type integer
local bufnr

---@param view View
---@param lines string[] is modified by this function (with IDs prepended)
---@return Tree tree, string[] updated_lines the constructed tree, the updated lines with IDs added at the beginning of each node
local parse_tree = function(view, lines)
	lines[1] = view:strip_line(lines[1])
	local tree = require("editree.tree").new(lines[1])
	local cur_dir = tree
	local last_seen_dir_at_depth = { [-1] = cur_dir }
	local cur_depth = -1

	local id_generator = require("editree.id_generator")
	id_generator.set_max_num_ids(#lines - 1)
	local dir_stack = require("editree.stack").new()
	dir_stack:push(cur_dir)

	for i = 2, #lines do
		local line = lines[i]
		local id = id_generator.get_id()
		lines[i] = ("%s %s"):format(id, view:strip_line(line))

		-- Count number of leading whitespaces
		local depth = #line:gsub("^(%s*)", "%1")
		if depth < cur_depth then
			-- Moving up in the tree
			cur_dir = last_seen_dir_at_depth[cur_depth]
		end
		if depth <= cur_depth and #dir_stack > 1 then
			for _ = 1, cur_depth - depth do
				dir_stack:pop()
			end
		end

		local stripped_line = line:gsub("^%s*(.*)", "%1")
		if view.is_file(line) then
			dir_stack:top():add_file(stripped_line, id)
		elseif view.is_directory(line) then
			local dir = last_seen_dir_at_depth[cur_depth]:add_dir(stripped_line, id)
			if depth > cur_depth then
				-- Moving down in the tree
				last_seen_dir_at_depth[depth] = cur_dir
				dir_stack:push(dir)
			end
			cur_dir = dir
		else
			assert("Line is neither file nor directory")
		end
		cur_depth = depth
	end
	return tree, lines
end

---@param view View
---@param lines string[]
---@return Tree? tree the constructed tree or nil if there were errors (e.g. unexpected IDs)
local parse_tree_with_ids = function(view, lines)
	lines[1] = view:strip_line(lines[1])
	local tree = require("editree.tree").new(lines[1])
	local cur_dir = tree
	local last_seen_dir_at_depth = { [-1] = cur_dir }
	local cur_depth = -1

	local dir_stack = require("editree.stack").new()
	dir_stack:push(cur_dir)
	local max_id = #lines

	for i = 2, #lines do
		local line = lines[i]
		local _, _, id = line:find("^(%d+)/ .+")
		if id then
			if tonumber(id) > max_id or tonumber(id) == 0 then
				-- Unexpected ID
				return nil
			end
			-- Remove leading ID
			line = line:sub(#id + 3)
		end

		-- Count number of leading whitespaces
		local depth = #line:gsub("^(%s*)", "%1")
		if depth < cur_depth then
			-- Moving up in the tree
			cur_dir = last_seen_dir_at_depth[cur_depth]
		end
		if depth <= cur_depth and #dir_stack > 1 then
			for _ = 1, cur_depth - depth do
				dir_stack:pop()
			end
		end

		local name = line:gsub("^%s*(.*)", "%1")
		if view.is_file(line) then
			dir_stack:top():add_file(name, id)
		elseif view.is_directory(line) then
			local dir = last_seen_dir_at_depth[cur_depth]:add_dir(name, id)
			if depth > cur_depth then
				-- Moving down in the tree
				last_seen_dir_at_depth[depth] = cur_dir
				dir_stack:push(dir)
			end
			cur_dir = dir
		else
			assert("Line is neither file nor directory")
		end
		cur_depth = depth
	end
	return tree
end

local compare_trees = function(old_tree, new_tree)

end

---@param view View
local ensure_buffer = function(view)
	if bufnr then
		return
	end
	bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].filetype = "editree"
	vim.bo[bufnr].bufhidden = "wipe"
end

--- Parses the buffer lines given the active view.
---@param view View
---@param lines string[]
---@param on_diff fun(Tree)
---@return Tree
function M.init_from_view(view, lines, on_diff)
	ensure_buffer(view)
	local tree, lines_with_ids = parse_tree(view, lines)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines_with_ids)

	vim.api.nvim_create_autocmd("BufWrite", {
		buffer = bufnr,
		callback = function()
			local updated_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local modified_tree = parse_tree_with_ids(view, updated_lines)
      local diff = compute_diff(tree, modified_tree)
			on_diff(diff)
		end,
		description = "Write editree buffer",
	})

	return tree
end

-- ---@type augroup integer
-- function M:new(augroup)
-- 	vim.api.nvim_create_autocmd("InsertEnter", {
-- 		group = augroup,
--     pattern =
-- 		callback = function()
-- 			print("enter")
-- 			old_tree = M.parse_tree()
-- 		end,
-- 	})
-- end
--
return M
