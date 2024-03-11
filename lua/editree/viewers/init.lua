---@class editree.View
---@field _symbol fun(self: editree.View, string): string
---@field get_root_path fun(self: editree.View): string
---@field is_directory fun(self: editree.View, string): boolean
---@field is_file fun(self: editree.View, string): boolean
---@field parse_entry fun(self: editree.View, string): string
---@field preprocess_buf_lines fun(self: editree.View, lines: string[]): string[]
---@field read_line fun(self: editree.View, string): boolean
---@field read_root_line fun(self: editree.View, string): boolean
---@field set_on_enter_callback fun(self: editree.View, fun)
---@field syntax_name string the name of the syntax to use for the editree buffer
---@field tree_node_tostring fun(self: editree.View, tree: editree.Tree): string

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
