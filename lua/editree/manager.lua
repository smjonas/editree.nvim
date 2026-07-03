-- The buffer manager owns the editree scratch buffer: it snapshots a tree view
-- into an editable buffer with hidden IDs, and on save diffs the buffer against
-- the original tree to compute the filesystem operations to apply.

local M = {}

local id_generator = require("editree.id_generator")
local tree_formatter = require("editree.tree_formatter")
local tree_ops = require("editree.tree_ops")
local tree_parser = require("editree.tree_parser")
local oil_adapter = require("editree.oil_adapter")
local diff = require("editree.diff")

local api = vim.api

---@type integer
local bufnr
local augroup = api.nvim_create_augroup("editree", {})

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
		-- "wipe" (not "hide"): a plain :q closing the buffer's last window must tear
		-- it down completely, not leave it hidden. init.lua hooks BufWipeout to reset
		-- editree's state and discard the source tree viewer buffer whenever that
		-- happens, so state can't survive past a :q the way it did with "hide".
		bufhidden = "wipe",
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

--- Closes the editree buffer (and its window, if it isn't the last one in the tabpage).
--- Deliberately does not try to hand control back to any tree viewer buffer; that's
--- the caller's responsibility (e.g. reopening the tree viewer from scratch).
function M.close()
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		return
	end
	for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
		pcall(api.nvim_win_close, win, true)
	end
	-- bufhidden=wipe means closing the last window above may have already wiped the
	-- buffer on its own; only delete it here if it's still around.
	if api.nvim_buf_is_valid(bufnr) then
		api.nvim_buf_delete(bufnr, { force = true })
	end
	bufnr = nil
end

---@param view editree.View
---@param old_tree editree.Tree
---@return boolean ok
---@return editree.Diff[]|string diffs_or_err
---@return editree.Tree? new_tree #the freshly parsed (unmutated) tree, to become the new baseline
local calculate_tree_diff = function(view, old_tree)
	local updated_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local ok, new_tree = tree_parser.parse_tree_with_ids(updated_lines, true, view.preprocess_buf_line)
	if not ok then
		vim.notify("[editree] Found an unexpected ID in the buffer, aborting save", vim.log.levels.ERROR)
		return false, "Found an unexpected ID in the buffer, aborting save"
	end
	assert(new_tree)
	-- Need to clone because computing the diff modifies the input trees; keep the
	-- original new_tree pristine so it can become the refreshed baseline on success.
	local success, diffs = diff.compute(old_tree:clone(), new_tree:clone())
	if not success then
		return false, diffs
	end
	return true, diffs, new_tree
end

---Rewrites the buffer with fresh IDs for the given tree and marks it unmodified.
---@param view editree.View
---@param tree editree.Tree
local refresh_buffer = function(view, tree)
	id_generator.reset()
	id_generator.max_num_ids = math.max(1, tree_ops.count_nodes(tree))
	tree_ops.add_ids(tree, id_generator)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, tree_formatter.tree_to_lines(view, tree))
	vim.bo[bufnr].modified = false
end

--- Parses the buffer lines given the active view.
---@param view editree.View
---@param lines string[]
function M.init_from_view(view, lines)
	local root_path = view:get_root_path()
	local cursor_row = api.nvim_win_get_cursor(0)[1]
	ensure_buffer("editree://" .. root_path, view.syntax_name)

  lines = view:preprocess_buf_lines(lines)
	local old_tree = tree_parser.parse_tree(lines)
  -- No ID for the root node
  id_generator.reset()
  id_generator.max_num_ids = #lines - 1
	tree_ops.add_ids(old_tree, id_generator)
  local old_tree_lines = tree_formatter.tree_to_lines(view, old_tree)

	api.nvim_set_current_buf(bufnr)
	-- Switching the window's buffer above triggers fern's own drawer BufWinLeave
	-- autocmd, which clears 'winfixwidth' on this window; set it (back) to true
	-- afterwards, or 'equalalways' will resize the drawer to ~50% the next time
	-- any other window opens or closes.
	vim.wo.winfixwidth = true
	api.nvim_buf_set_lines(bufnr, 0, -1, false, old_tree_lines)

	-- Inherit the cursor position from the viewer
	api.nvim_win_set_cursor(0, { cursor_row, get_first_letter_col(lines[cursor_row]) })
	vim.bo[bufnr].modified = false
	-- setup_reformat_autocmd(view)

	api.nvim_create_autocmd("BufWriteCmd", {
		pattern = "editree://*",
		group = augroup,
		callback = function()
			local ok, diffs, new_tree = calculate_tree_diff(view, old_tree)
			if not ok then
				vim.notify(("[editree] %s"):format(diffs), vim.log.levels.ERROR)
				return
			end
			assert(new_tree)
			oil_adapter.apply_diffs(root_path, diffs, function()
				-- Keep editree open after a successful save: refresh the buffer with the
				-- new on-disk state instead of closing, so it behaves like oil.nvim.
				old_tree = new_tree
				refresh_buffer(view, old_tree)
			end)
		end,
		desc = "Write editree buffer",
	})
end

return M
