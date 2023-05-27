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

---Initializes editree from the current buffer.
M.open = function()
	local filetype = vim.bo["filetype"]
	local viewer = viewers[filetype]
	if not viewer then
		vim.notify(("editree: No viewer found for filetype '%s'"):format(filetype), vim.log.levels.ERROR)
		return
	end

	viewer.set_on_enter_callback(function()
		adapter.init_from_view(viewer, vim.api.nvim_buf_get_lines(0, 0, -1, false))
	end)
end

M.close = function()
  adapter.close()
end

local setup_autocmds = function()
	viewers = require("editree.viewers")
	local filetypes = vim.iter(require("editree.viewers"))
		:map(function(_, viewer)
			return viewer.filetype
		end)
		:totable()

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = filetypes,
		callback = M.open,
		desc = "Open editree for supported filetypes",
	})
end

M.setup = function()
	local ok, _ = pcall(require, "oil.adapters.files")
	if not ok then
		vim.notify("editree: Module oil.adapters.files not found, please install oil.nvim", vim.log.levels.ERROR)
		return
	end
	adapter = require("editree.oil_adapter")
	setup_autocmds()
  require("editree.command").create_commands()
end

return M
