local M = {}

local valid_commands = {
	"open",
	"close",
}

M.create_commands = function()
	vim.api.nvim_create_user_command("Editree", function(result)
		if vim.tbl_contains(valid_commands, result.args) then
			require("editree")[result.args]()
		else
			vim.notify(('editree: Invalid command "%s"'):format(result.args), vim.log.levels.ERROR)
		end
	end, {
		nargs = "*",
		complete = function(arglead, _, _)
			-- Only complete arguments that start with arglead
			return vim.tbl_filter(function(arg)
				return arg:match("^" .. arglead)
			end, valid_commands)
		end,
	})
end

return M
