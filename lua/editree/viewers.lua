---@class View
---@field filetype string
---@field is_file fun(string): boolean
---@field is_directory fun(string): boolean
---@field strip_patterns string[]?
---@field skip_first_line boolean

---@type View
local fern = {
	filetype = "fern",
	is_file = function(file)
		return not file:match("/$")
	end,
	is_directory = function(dir)
		return dir:match("/$")
	end,
	strip_patterns = { "^%s*|[%-%+]?", "$" },
	skip_first_line = true,
}

return {
	fern,
}
