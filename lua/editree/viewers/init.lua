---@class editree.View
---@field syntax_name string the name of the syntax to use for the editree buffer
---@field set_on_enter_callback fun(self: editree.View, fun)
---@field read_line fun(self: editree.View, string): boolean
---@field read_root_line fun(self: editree.View, string): boolean
---@field is_file fun(self: editree.View, string): boolean
---@field is_directory fun(self: editree.View, string): boolean
---@field parse_entry fun(self: editree.View, string): string
---@field tree_entry_tostring fun(self: editree.View, Tree): string
---@field get_root_path fun(self: editree.View): string
---@field _symbol fun(self: editree.View, string): string

local M = {}

---@param patterns string[]
---@param line string
M.strip_patterns = function(patterns, line)
	for _, pattern in ipairs(patterns) do
		line = line:gsub(pattern, "")
	end
	return line
end

M.from_filetype = function(filetype)
	if filetype == "fern" then
		local fern = require("editree.viewers.fern")
		local fern_nerdfont = require("editree.viewers.fern_nerdfont")
		return vim.g["fern#renderer"] == "nerdfont" and fern_nerdfont or fern
	end
end

return M
