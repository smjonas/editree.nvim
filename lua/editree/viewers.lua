---@class View
---@field syntax_name string the name of the syntax to use for the editree buffer
---@field set_on_enter_callback fun(fun)
---@field is_file fun(string): boolean
---@field is_directory fun(string): boolean
---@field parse_entry fun(string): string
---@field format_entry fun(Tree): string
---@field get_root_path fun(): string
---@field _symbol fun(string): string

---@type table<string, View>
local M = {}

---@param patterns string[]
---@param line string
local strip_patterns = function(patterns, line)
	for _, pattern in ipairs(patterns) do
		line = line:gsub(pattern, "")
	end
	return line
end

---@type View
local fern = {}
fern = {
	syntax_name = "editree_fern",
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
	read_line = function(line)
		return line:gsub("$", "")
	end,
	_symbol = function(symbol_name)
		return vim.g[("fern#renderer#default#%s_symbol"):format(symbol_name)]
	end,
	parse_entry = function(line)
		return strip_patterns(
			{ "^%s*", "%s*$", fern._symbol("leaf"), fern._symbol("collapsed"), fern._symbol("expanded") },
			line
		)
	end,
	-- TODO: format entry on change
	format_entry = function(entry)
		if entry:is_root() then
			return entry.name
		end
		local padding = (" "):rep(entry.depth)
		local symbol
		if entry.type == "directory" then
			symbol = vim.tbl_isempty(entry.children) and fern._symbol("collapsed") or fern._symbol("expanded")
		elseif entry.type == "file" then
			symbol = fern._symbol("leaf")
		else
			assert(false, "Unknown entry type: " .. entry.type)
		end
		return padding .. symbol .. entry.name
	end,
	get_root_path = function()
		local helper = vim.fn["fern#helper#new"]()
		return helper.fern.root._path
	end,
}

local fern_nerdfont = {}
fern_nerdfont = {
	syntax_name = "editree_fern_nerdfont",
	_option = function(option_name)
		return ("fern#renderer#nerdfont#%s"):format(option_name)
	end,
	read_root_line = function(line)
		local padding = fern_nerdfont._option("root_symbol") == "" and "" or fern_nerdfont._option("padding")
		local prefix = fern_nerdfont._option("root_leading") .. fern_nerdfont._option("root_symbol") .. padding
		return strip_patterns({ "^" .. prefix, "$" }, line)
	end,
	read_line = function(line)
		return line:gsub("$", "")
	end,
	parse_entry = function(line)
		-- "." removes the nerdfont icon
		return strip_patterns({ "^%s*.", "%s*$" }, line)
	end,
	format_entry = function(entry)
		return "todo"
	end,
	get_root_path = function()
		local helper = vim.fn["fern#helper#new"]()
		return helper.fern.root._path
	end,
}
fern_nerdfont = setmetatable(fern_nerdfont, { __index = fern })

M.from_filetype = function(filetype)
	if filetype == "fern" then
		return vim.g["fern#renderer"] == "nerdfont" and fern_nerdfont or fern
		-- return fern
	end
end

return M
