-- The oil adapter is responsible for parsing a tree view representation provided
-- by a supported file browser (e.g. nvim-tree) into a list of nodes (i.e. directories
-- or files). The node structure is used to determine the modifications applied to
-- the root directory.

---@class OilAdapter
local M = {}

local id_generator = require("editree.id_generator")
local stack = require("editree.stack")
local api = vim.api

---@type integer
local bufnr
local augroup = api.nvim_create_augroup("editree", {})

M._build_tree = function(view, lines, extract_id)
	lines[1] = view.read_root_line(lines[1])
	local tree = require("editree.tree").new(lines[1])
	local dir_stack = stack.new()

	local cur_dir = tree
	dir_stack:push(cur_dir)
	local cur_depth = -1

	for i = 2, #lines do
		local line = view.read_line(lines[i])
		local id
		if extract_id then
			id = extract_id(line)
			if id == false then
				return false, nil
			elseif id ~= nil then
				-- Remove leading ID
				line = line:sub(#id + 3)
			end
		end
		lines[i] = line

		-- Count number of leading whitespaces
		local depth = #line:gsub("^(%s*).*", "%1")

		-- Moving up in the tree
		if depth < cur_depth and #dir_stack > 1 then
			print(depth, cur_depth)
			for _ = 1, cur_depth - depth do
				dir_stack:pop()
			end
		end
		cur_dir = dir_stack:top()

		local name = view.parse_entry(line)

		-- Account for overindented lines (if the previous entry is a file, we should stay on the same level of the tree)
		local is_overindented = depth > cur_depth and not cur_dir:is_root() and view.is_file(cur_dir.name)
		if is_overindented then
			print("xx")
			print(cur_dir.name)
		end

		if depth == cur_depth or is_overindented then
			local parent_dir = cur_dir.parent
			local new_node = view.is_file(name) and parent_dir:add_file(name, id) or parent_dir:add_dir(name, id)
			-- Replace the top
			dir_stack[#dir_stack] = new_node
      -- Keep same depth
		elseif depth > cur_depth then -- Moving down in the tree
			local child_node = view.is_file(name) and cur_dir:add_file(name, id) or cur_dir:add_dir(name, id)
			dir_stack:push(child_node)
      cur_depth = cur_depth + 1
    else
      print(name)
    end
	end
	return true, tree
end

---@param view editree.View
---@param lines string[]
---@param ignore_invalid_ids boolean
---@return boolean success, editree.Tree? tree
M._parse_tree_with_ids = function(view, lines, ignore_invalid_ids)
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

--- Returns the updated lines after reindenting and reformatting the given lines.
---@param view editree.View
---@param lines string[]
---@return string[] lines the updated lines
M._reformat_lines = function(view, lines)
	-- Whole line is indented (including the ID), reformat it
	-- (Turn "   /001 file.txt" into "/001    file.txt")
	local new_lines = vim.iter(lines)
		:map(function(line)
			local _, _, leading_ws, id, name = line:find("^(%s+)(/%d+ )(.*)")
			if id then
				line = id .. (" "):rep(#leading_ws) .. name
			end
			return line
		end)
		:totable()

	-- Ignore invalid IDs since this tree is not used to compute the diffs
	local _, tree = M._parse_tree_with_ids(view, new_lines, false)

	-- Use the tree to reconstruct the lines
	local reformatted_lines = {}
	tree:for_each(function(entry)
		table.insert(reformatted_lines, view.tree_entry_tostring(entry))
	end)
	return reformatted_lines
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

local get_oil_url = function(root_path, rel_path)
	return ("oil://%s"):format(vim.fs.joinpath(root_path, rel_path))
end

---@param diff editree.Diff
local diff_to_action = function(root_path, diff)
	local url = get_oil_url(root_path, diff.node:get_rel_path())
	local entry_type = diff.node.type
	local action = { type = diff.type, entry_type = entry_type, url = url }

	-- Oil only knows "move" actions
	if diff.type == "rename" then
		action.type = "move"
	end

	if action.type == "move" then
		action.src_url = url
		action.dest_url = get_oil_url(root_path, diff.to:get_rel_path())
	end
	return action
end

local apply_diffs = function(root_path, diffs, return_to_view_cb)
	local actions = vim.tbl_map(function(diff)
		return diff_to_action(root_path, diff)
	end, diffs)
	require("oil.mutator.preview").show(actions, true, function(confirmed)
		if confirmed then
			require("oil.mutator").process_actions(
				actions,
				vim.schedule_wrap(function(err)
					if err then
						vim.notify(string.format("[editree] Error applying actions: %s", err), vim.log.levels.ERROR)
					else
						return_to_view_cb()
					end
				end)
			)
		end
	end)
end

local ensure_buffer = function(buf_name, syntax_name)
	local bufs = api.nvim_list_bufs()
	-- Check for an existing editree buffer
	for _, buf in ipairs(bufs) do
		if api.nvim_buf_get_name(buf) == buf_name then
			api.nvim_buf_delete(buf, { force = true })
		end
	end
	if bufnr and api.nvim_buf_is_valid(bufnr) then
		return
	end

	bufnr = api.nvim_create_buf(false, false)
	api.nvim_buf_set_name(bufnr, buf_name)
	local winid = api.nvim_get_current_win()

	local buf_opts = {
		filetype = "editree",
		bufhidden = "hide",
		modified = false,
	}
	for k, v in pairs(buf_opts) do
		api.nvim_set_option_value(k, v, { buf = bufnr })
	end
	api.nvim_set_option_value("syntax", syntax_name, { buf = bufnr })

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
		api.nvim_set_option_value(k, v, { win = winid })
	end
end

local get_first_letter_col = function(line)
	local start_pos, _ = line:find("%a")
	return start_pos - 1 or 0
end

--- Parses the buffer lines given the active view.
---@param view editree.View
---@param lines string[]
---@param return_to_view_cb fun()
function M.init_from_view(view, lines, return_to_view_cb)
	local root_path = view:get_root_path()
	local cursor_row = api.nvim_win_get_cursor(0)[1]
	ensure_buffer("editree://" .. root_path, view.syntax_name)

	local _, old_tree = M._build_tree(view, lines)
	local lines_with_ids = prepend_ids(old_tree, lines)

	api.nvim_set_current_buf(bufnr)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines_with_ids)

	-- Inherit the cursor position from the viewer
	api.nvim_win_set_cursor(0, { cursor_row, get_first_letter_col(lines[cursor_row]) })
	vim.bo[bufnr].modified = false

  -- TODO: think about when to reformat
	api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
		pattern = "editree://*",
		group = augroup,
		callback = function()
			local updated_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local formatted_lines = M._reformat_lines(view, updated_lines)
			api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted_lines)
		end,
		desc = "Reformat editree buffer",
	})

	-- Parse the modified tree buffer, generate a diff and apply the changes
	api.nvim_create_autocmd("BufWriteCmd", {
		pattern = "editree://*",
		group = augroup,
		callback = function()
			local updated_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local ok, new_tree = M._parse_tree_with_ids(view, updated_lines, true)
			if not ok then
				print("Found unexpected ID")
				return
			end
			local diffs
			-- Need to clone because computing the diff modifies the input trees
			ok, diffs = require("editree.diff").compute(old_tree:clone(), new_tree)
			if ok then
				apply_diffs(root_path, diffs, return_to_view_cb)
			else
				print(diffs)
			end
		end,
		desc = "Write editree buffer",
	})
end

-- ---@type augroup integer
-- function M:new(augroup)
-- 	api.nvim_create_autocmd("InsertEnter", {
-- 		group = augroup,
--     pattern =
-- 		callback = function()
--
-- 			print("enter")
-- 			old_tree = M.parse_tree()
-- 		end,
-- 	})
-- end
--
return M
