-- The oil adapter is responsible for parsing a tree view representation provided
-- by a supported file browser (e.g. nvim-tree) into a list of nodes (i.e. directories
-- or files). The node structure is used to determine the modifications applied to
-- the root directory.

---@class OilAdapter
local M = {}

local id_generator = require("editree.id_generator")
local tree_formatter = require("editree.tree_formatter")
local tree_ops = require("editree.tree_ops")
local tree_parser = require("editree.tree_parser")
local diff = require("editree.diff")
local api = vim.api

---@type integer
local bufnr
local augroup = api.nvim_create_augroup("editree", {})

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

---@param root_path string
---@param diffs editree.Tree[]
---@param return_to_view_cb fun()
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

---@param view editree.View
---@param old_tree editree.Tree
---@param root_path string
---@param return_to_view_cb fun()
local calculate_tree_diff_and_apply = function(view, old_tree, root_path, return_to_view_cb)
	local updated_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local ok, new_tree = tree_parser.parse_tree_with_ids(updated_lines, true, view.preprocess_buf_line)
	if not ok then
		print("Found unexpected ID")
		return
	end
	assert(new_tree)
	local diffs
	-- Need to clone because computing the diff modifies the input trees
	ok, diffs = require("editree.diff").compute(old_tree:clone(), new_tree)
	if ok then
		apply_diffs(root_path, diffs, return_to_view_cb)
	else
		print(diffs)
	end
end

--- Parses the buffer lines given the active view.
---@param view editree.View
---@param lines string[]
---@param return_to_view_cb fun()
function M.init_from_view(view, lines, return_to_view_cb)
	local root_path = view:get_root_path()
	local cursor_row = api.nvim_win_get_cursor(0)[1]
	print(view.syntax_name)
	ensure_buffer("editree://" .. root_path, view.syntax_name)

  lines = view:preprocess_buf_lines(lines)
	local old_tree = tree_parser.parse_tree(lines)
  -- No ID for the root node
  id_generator.max_num_ids = #lines - 1
	tree_ops.add_ids(old_tree, id_generator)
  local old_tree_lines = tree_formatter.tree_to_lines(view, old_tree)

	api.nvim_set_current_buf(bufnr)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, old_tree_lines)

	-- Inherit the cursor position from the viewer
	api.nvim_win_set_cursor(0, { cursor_row, get_first_letter_col(lines[cursor_row]) })
	vim.bo[bufnr].modified = false
	-- setup_reformat_autocmd(view)

	api.nvim_create_autocmd("BufWriteCmd", {
		pattern = "editree://*",
		group = augroup,
		callback = function()
			calculate_tree_diff_and_apply(view, old_tree, root_path, return_to_view_cb)
		end,
		desc = "Write editree buffer",
	})
end

return M
