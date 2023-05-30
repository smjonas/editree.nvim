-- The oil adapter is responsible for parsing a tree view representation provided
-- by a supported file browser (e.g. nvim-tree) into a list of nodes (i.e. directories
-- or files). The node structures are used to determine the modifications applied
-- to the root directory.

-- Insert enter: init from view

---@class OilAdapter
local M = {}

local id_generator = require("editree.id_generator")
local stack = require("editree.stack")

---@type integer
local bufnr

M._build_tree = function(view, lines, transform_line)
	lines[1] = view.read_line(lines[1])
	local tree = require("editree.tree").new(lines[1])
	local dir_stack = stack.new()

	local cur_dir = tree
	dir_stack:push(cur_dir)
	local cur_depth = -1

	for i = 2, #lines do
		local line = view.read_line(lines[i])
		line = not transform_line and line or transform_line(line)
		if line == false then
			return false, nil
		end

		-- Count number of leading whitespaces
		local depth = #line:gsub("^(%s*).*", "%1")
		-- Moving up in the tree
		if depth < cur_depth and #dir_stack > 1 then
			for _ = 1, cur_depth - depth do
				dir_stack:pop()
			end
		end
		cur_dir = dir_stack:top()

		local name = view.parse_entry(line)

		if depth == cur_depth then
			local parent_dir = cur_dir.parent
			local new_node = view.is_file(name) and parent_dir:add_file(name) or parent_dir:add_dir(name)
			-- Replace the top
			dir_stack[#dir_stack] = new_node
			print(tree)
		elseif depth > cur_depth then -- Moving down in the tree
			local child_node = view.is_file(name) and cur_dir:add_file(name) or cur_dir:add_dir(name)
			dir_stack:push(child_node)
		end
		cur_depth = depth
	end
	return true, tree
end

---@param view View
---@param lines string[]
---@return boolean success, Tree? tree
local parse_tree_with_ids = function(view, lines)
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
			if tonumber(id) > max_id or tonumber(id) == 0 then
				-- Unexpected ID
				return false
			end
			-- Remove leading ID
			line = line:sub(#id + 3)
		end
		return line
	end)
	return ok, tree
end

---@param diff 0
local diff_to_action = function(root_path, diff)
	if not diff.node then
		vim.print(diff)
	end
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
	-- actions = {
	-- 	{
	-- 		type = "create",
	-- 		entry_type = "file",
	-- 		url = "oil:///home/jonas/.config/nvim/lua/plugins/new.txt",
	-- 	},
	-- }

	require("oil.mutator.preview").show(actions, true, function(confirmed)
		if confirmed then
			require("oil.mutator").process_actions(
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

---Adds IDs to each node in the tree as well as at the beginning of each line.
local prepend_ids = function(tree, lines)
	-- No ID for the root node
	id_generator.max_num_ids = #lines - 1

	local i = 2
	tree:for_each(function(node)
		if not node:is_root() then
			local id = id_generator.get_id()
			node.id = id
			lines[i] = ("/%s %s"):format(id, lines[i])
			i = i + 1
		end
	end)
	assert(i - 1 == #lines, "Number of IDs does not match number of lines")
	return lines
end

--- Parses the buffer lines given the active view.
---@param view View
---@param lines string[]
---@return Tree
function M.init_from_view(view, lines)
	if true then
		print(view.parse_entry("|  test.txt"))
		-- return
	end

	local root_path = view:get_root_path()
	local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
	ensure_buffer("editree://" .. root_path, view.syntax_name)

	local _, tree = M._build_tree(view, lines)
	print(tree)
	local lines_with_ids = prepend_ids(tree, lines)

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
			vim.print("NEW TREE " .. print(modified_tree))
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
				-- vim.print(tree, modified_tree)
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
