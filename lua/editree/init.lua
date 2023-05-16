local M = {}

-- Configurable:
-- action used to enter / construct editree buffer (default: FileType)
-- action to save changes (default: BufWrite)
-- (action to delete tmp buffer and restore original tree view)

---@type OilAdapter
local adapter

local group = vim.api.nvim_create_augroup("editree", {})

local setup_autocmds = function()
	vim.iter(require("editree.viewers")):map(function(viewer)
		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = viewer.filetype,
			callback = function()
        local x = vim.api.nvim_buf_get_name(0)
        print(x)
				adapter.init_from_view(viewer, vim.api.nvim_buf_get_lines(0, 0, -1, false))
			end,
		})
	end)
end

M.setup = function()
  adapter = require("editree.oil_adapter")
	setup_autocmds()
end

return M
