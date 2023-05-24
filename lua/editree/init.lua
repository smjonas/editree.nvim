local M = {}

-- Configurable:
-- action used to enter / construct editree buffer (default: FileType)
-- action to save changes (default: BufWrite)
-- (action to delete tmp buffer and restore original tree view)

---@type OilAdapter
local adapter

local group = vim.api.nvim_create_augroup("editree", {})

local setup_autocmds = function(oil_files)
	local viewers = require("editree.viewers")
	local filetypes = vim.iter(require("editree.viewers"))
		:map(function(_, viewer)
			return viewer.filetype
		end)
		:totable()

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = filetypes,
		callback = function(event)
			local viewer = viewers[event.match]
			viewer.set_on_enter_callback(function()
				adapter.init_from_view(viewer, vim.api.nvim_buf_get_lines(0, 0, -1, false))
			end)
		end,
		desc = "Initialize editree buffer for supported filetypes",
	})
end

M.setup = function()
	local ok, _ = pcall(require, "oil.adapters.files")
	if not ok then
		vim.notify("editree.nvim: module oil.adapters.files not found, please install oil.nvim", vim.log.levels.ERROR)
    return
	end
	adapter = require("editree.oil_adapter")
	setup_autocmds()
end

return M
