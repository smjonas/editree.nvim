local M = {}

-- Configurable:
-- action used to enter / construct editree buffer (default: FileType)
-- action to save changes (default: BufWrite)
-- (action to delete tmp buffer and restore original tree view)

---@type OilAdapter
local adapter

local group = vim.api.nvim_create_augroup("editree", {})

local setup_autocmds = function()
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
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "FernHighlight",
		callback = function()
			vim.schedule(function()
				-- vim.print(vim.api.nvim_buf_line_count(0))
			end)
		end,
	})
end

M.setup = function()
	adapter = require("editree.oil_adapter")
	setup_autocmds()
end

return M
