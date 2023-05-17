---@class View
---@field filetype string
---@field set_on_enter_callback fun(fun)
---@field is_file fun(string): boolean
---@field is_directory fun(string): boolean
---@field strip_patterns string[]?
---@field strip_line fun(View, string): string
---@field skip_first_line boolean

local View = {
	---@param view View
	---@param line string
	strip_line = function(view, line)
		print(#view.strip_patterns)
		for _, pattern in ipairs(view.strip_patterns or {}) do
      print(line, pattern)
			line = line:gsub(pattern, "")
      print(line)
		end
		return line
	end,
}

---@type View
local fern = setmetatable({
	filetype = "fern",
	set_on_enter_callback = function(on_enter)
		vim.fn["fern#hook#add"]("viewer:ready", function()
			on_enter()
		end, { once = 1 })
	end,
	is_file = function(file)
		return not file:match("/$")
	end,
	is_directory = function(dir)
		return dir:match("/$")
	end,
	-- strip_patterns = { "^%s*|[%-%+]?", "$" },
	strip_patterns = { "$" },
	skip_first_line = true,
}, { __index = View })

local M = {
	fern = fern,
}

return M
