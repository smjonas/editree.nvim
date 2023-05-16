-- The oil adapter is responsible for parsing a tree view representation provided
-- by a supported file browser (e.g. nvim-tree) into a list of nodes (i.e. directories
-- or files). The node structures are used to determine the modifications applied
-- to the root directory.

-- Insert enter: init from view

---@class OilAdapter
local M = {}

---@type integer
local bufnr

local ensure_buffer = function()
	if bufnr then
		return
	end
	bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].filetype = "editree"
	vim.bo[bufnr].bufhidden = "wipe"
end

---@param view View
---@param lines string[] is modified by this function (with IDs prepended)
---@return Tree tree, string[] updated_lines the constructed tree, the updated lines with IDs added at the beginning of each node
local parse_tree = function(view, lines)
	local tree = require("editree.tree").new(lines[1])
	local cur_dir = tree
	local last_seen_dir_at_depth = { [-1] = cur_dir }
	local cur_depth = -1

	local id_manager = require("editree.id_manager")
	id_manager.set_max_num_ids(#lines - 1)
	local dir_stack = require("editree.stack").new()
	dir_stack:push(cur_dir)

	for i = 2, #lines do
		local line = lines[i]
		local id = id_manager.get_id()
		lines[i] = id .. line

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

--- Parses the buffer lines given the active view.
---@param view View
---@param lines string[]
---@return Tree
function M.init_from_view(view, lines)
	ensure_buffer()
  local tree, updated_lines = parse_tree(view, lines)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, updated_lines)
  vim.print(updated_lines)
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
