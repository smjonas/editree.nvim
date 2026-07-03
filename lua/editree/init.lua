local M = {}


-- Configurable:
-- action used to enter / construct editree buffer (default: FileType)
-- action to save changes (default: BufWrite)
-- (action to delete tmp buffer and restore original tree view)

local manager

---@type table<string, editree.View>
local viewers

local initialized = false

--- The tree viewer buffer (e.g. fern) editree was opened from. Wiped once the editree
--- buffer goes away, since viewers like fern remember internal state (e.g. cursor
--- position) per buffer that can go stale once the tree has been edited, causing
--- errors on a later reopen.
local source_bufnr

--- Resets editree's state and discards the tree viewer buffer it was opened from.
--- Hooked to the editree buffer's own teardown (see M.open) so it runs no matter how
--- the buffer goes away -- via M.close(), :bdelete, or plain :q -- instead of only
--- when callers go through editree's own close path.
local cleanup = function()
	if source_bufnr and vim.api.nvim_buf_is_valid(source_bufnr) then
		pcall(vim.api.nvim_buf_delete, source_bufnr, { force = true })
	end
	source_bufnr = nil
	initialized = false
end

---Initializes editree for the current buffer
M.open = function()
	if not manager or not viewers then
		vim.notify("[editree] Not set up yet, call require('editree').setup() first", vim.log.levels.ERROR)
		return
	end
	local filetype = vim.bo["filetype"]
	local viewer = viewers.from_filetype(filetype)
	if not viewer then
		vim.notify(("[editree] No viewer found for filetype '%s'"):format(filetype), vim.log.levels.ERROR)
		return
	end

	source_bufnr = vim.api.nvim_get_current_buf()
	manager.init_from_view(viewer, vim.api.nvim_buf_get_lines(0, 0, -1, false))
	initialized = true

	-- bufhidden=wipe on the editree buffer (see manager.lua) means it is wiped as
	-- soon as its last window closes, however that happens; run cleanup() then.
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = vim.api.nvim_get_current_buf(),
		once = true,
		callback = cleanup,
	})
end

--- Closes the editree buffer and its window, and discards the tree viewer buffer it
--- was opened from. Does not try to return to or refresh that tree viewer; reopen it
--- fresh (e.g. via your keymap) to browse again.
M.close = function()
	if initialized then
		manager.close()
	end
	cleanup()
end

M.toggle = function()
	if initialized then
		M.close()
	else
		M.open()
	end
end

M.setup = function()
	local ok, _ = pcall(require, "oil.adapters.files")
	if not ok then
		vim.notify("[editree] Module oil.adapters.files not found, please install oil.nvim", vim.log.levels.ERROR)
		return
	end
	manager = require("editree.manager")
	viewers = require("editree.viewers")
	require("editree.command").create_commands()
end

return M
