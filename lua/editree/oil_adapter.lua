-- The oil adapter is responsible for parsing a tree view representation provided
-- by a supported file browser (e.g. nvim-tree) into a list of nodes (i.e. directories
-- or files). The node structures are used to determine the modifications applied
-- to the root directory.

-- Insert enter: init from view

---@class OilAdapter
local M = {}

local id_generator = require("editree.id_generator")
local stack = require("editree.stack")
local oil_mutator = require("oil.mutator")
local oil_preview = require("oil.mutator.preview")

---@type integer
local bufnr

---@param view View
---@param lines string[] is modified by this function (with IDs prepended)
---@return Tree tree, string[] updated_lines the constructed tree, the updated lines with IDs added at the beginning of each node
local parse_tree = function(view, lines)
	lines[1] = view.strip_line(lines[1])
	local tree = require("editree.tree").new(lines[1])
	local cur_dir = tree
	local last_seen_dir_at_depth = { [-1] = cur_dir }
	local cur_depth = -1

	id_generator.max_num_ids = #lines - 1
	local dir_stack = stack.new()
	dir_stack:push(cur_dir)

	for i = 2, #lines do
		local line = lines[i]
		local id = id_generator.get_id()

		-- Count number of leading whitespaces
		local depth = #line:gsub("^(%s*).*", "%1")
		if depth < cur_depth then
			-- Moving up in the tree
			cur_dir = last_seen_dir_at_depth[cur_depth]
		end
		if depth <= cur_depth and #dir_stack > 1 then
			for _ = 1, cur_depth - depth do
				dir_stack:pop()
			end
		end

		lines[i] = ("/%s %s"):format(id, view.strip_line(line))
		local name = view.parse_entry(line)
		-- local stripped_line = line:gsub("^%s*(.*)", "%1")

		if view.is_file(name) then
			dir_stack:top():add_file(name, id)
		elseif view.is_directory(name) then
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
	return tree, lines
end

---@param view View
---@param lines string[]
---@return boolean success, Tree? tree
local parse_tree_with_ids = function(view, lines)
	-- Remove blank lines
	lines = vim.iter(lines)
		:filter(function(line)
			return line:find("^%s*$")
		end)
		:totable()

	-- lines[1] = view:strip_line(lines[1])
	local tree = require("editree.tree").new(lines[1])
	local cur_dir = tree
	local last_seen_dir_at_depth = { [-1] = cur_dir }
	local cur_depth = -1

	local dir_stack = stack.new()
	dir_stack:push(cur_dir)
	local max_id = #lines

	for i = 2, #lines do
		local line = lines[i]

		local _, _, id = line:find("^/(%d+) ")
		if id then
			if tonumber(id) > max_id or tonumber(id) == 0 then
				-- Unexpected ID
				return false, nil
			end
			-- Remove leading ID
			line = line:sub(#id + 2)
		end

		-- Count number of leading whitespaces
		local depth = #line:gsub("^(%s*).*", "%1")

		if depth < cur_depth then
			-- Moving up in the tree
			cur_dir = last_seen_dir_at_depth[cur_depth]
		end
		if depth <= cur_depth and #dir_stack > 1 then
			for _ = 1, cur_depth - depth do
				dir_stack:pop()
			end
		end

		-- Remove leading whitespaces and other patterns
		line = line:gsub("^%s*", "")
		-- line = view:strip_line(line)

		if view.is_file(line) then
			dir_stack:top():add_file(line, id)
		elseif view.is_directory(line) then
			local dir = last_seen_dir_at_depth[cur_depth]:add_dir(line, id)
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
	return true, tree
end

---@param diff Diff
local diff_to_action = function(root_path, diff)
	local url = ("oil://%s"):format(vim.fs.joinpath(root_path, diff.node:get_rel_path()))
	local entry_type = diff.node.type
	-- if diff.type == "create" then
	return { type = "create", url = url, entry_type = entry_type }
	-- end
end

local apply_diffs = function(root_path, diffs)
	local actions = vim.tbl_map(function(diff)
		return diff_to_action(root_path, diff)
	end, diffs)
	vim.print(actions)
	actions = {
		{
			type = "create",
			entry_type = "file",
			url = "oil:///home/jonas/.config/nvim/lua/plugins/new.txt",
		},
	}

	oil_preview.show(actions, true, function(confirmed)
		if confirmed then
			oil_mutator.process_actions(
				actions,
				vim.schedule_wrap(function(err)
					if err then
						vim.notify(string.format("[editree] Error applying actions: %s", err), vim.log.levels.ERROR)
					end
					print("TODO: rerender")
				end)
			)
		end
	end)
end

local ensure_buffer = function(buf_name, syntax_name)
	local bufs = vim.api.nvim_list_bufs()
	-- Check for an existing editree buffer
	for _, buf in ipairs(bufs) do
		if vim.api.nvim_buf_get_name(buf) == buf_name then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	bufnr = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(bufnr, buf_name)
	local winid = vim.api.nvim_get_current_win()

	local buf_opts = {
		filetype = "editree",
		bufhidden = "hide",
		modified = false,
	}
	for k, v in pairs(buf_opts) do
		vim.api.nvim_set_option_value(k, v, { buf = bufnr })
	end
	vim.api.nvim_set_option_value("syntax", syntax_name, { buf = bufnr })

	local win_opts = {
		wrap = false,
		cursorcolumn = false,
		foldcolumn = "0",
		spell = false,
		list = false,
		conceallevel = 3,
		concealcursor = "n",
	}
	for k, v in pairs(win_opts) do
		vim.api.nvim_set_option_value(k, v, { win = winid })
	end
end

local get_first_letter_col = function(line)
	local start_pos, _ = line:find("%a")
	return start_pos - 1 or 0
end

--- Parses the buffer lines given the active view.
---@param view View
---@param lines string[]
---@return Tree
function M.init_from_view(view, lines)
	local root_path = view:get_root_path()
	local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
	ensure_buffer("editree://" .. root_path, view.syntax_name)

	local tree, lines_with_ids = parse_tree(view, lines)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines_with_ids)

	-- Inherit the cursor position from the viewer
	vim.api.nvim_win_set_cursor(0, { cursor_row, get_first_letter_col(lines[cursor_row]) })
	vim.bo[bufnr].modified = false

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		pattern = "editree://*",
		callback = function()
			local updated_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local ok, modified_tree = parse_tree_with_ids(view, updated_lines)
			if not ok then
				print("Found unexpected ID")
				return
			end
			assert(modified_tree)
			local diff
			-- Need to clone because computing the diff modifies the input trees
			ok, diff = require("editree.diff").compute(tree:clone(), modified_tree:clone())
			if ok then
				apply_diffs(root_path, diff)
				vim.print(tree, modified_tree)
				vim.print(diffs)
			else
				print(diff)
			end
		end,
		desc = "Write editree buffer",
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
