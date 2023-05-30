local M = {}

-- Configurable:
-- action used to enter / construct editree buffer (default: FileType)
-- action to save changes (default: BufWrite)
-- (action to delete tmp buffer and restore original tree view)

---@type OilAdapter
local adapter

---@type table<string, View>
local viewers

local group = vim.api.nvim_create_augroup("editree", {})
local initialized = false

--- The number of the buffer editree was opened from
local prev_buffer

---Initializes editree for the current buffer
M.open = function()
	local filetype = vim.bo["filetype"]
	local viewer = viewers[filetype]
	if not viewer then
		vim.notify(("editree: No viewer found for filetype '%s'"):format(filetype), vim.log.levels.ERROR)
		return
	end

  prev_buffer = vim.api.nvim_get_current_buf()
	adapter.init_from_view(viewer, vim.api.nvim_buf_get_lines(0, 0, -1, false))
	initialized = true
end

M.close = function()
	if initialized and vim.api.nvim_buf_is_valid(prev_buffer) then
		vim.cmd.buf(prev_buffer)
	end
	initialized = false
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
		vim.notify("editree: Module oil.adapters.files not found, please install oil.nvim", vim.log.levels.ERROR)
		return
	end
	adapter = require("editree.oil_adapter")
	viewers = require("editree.viewers")
	require("editree.command").create_commands()
end

return M
