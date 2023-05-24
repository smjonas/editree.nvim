---@class View
---@field set_on_enter_callback fun(fun)
---@field is_file fun(string): boolean
---@field is_directory fun(string): boolean
---@field parse_entry fun(string): string
---@field format_entry fun(Tree): string
---@field skip_first_line boolean
---@field get_root_path fun(): string

---@param strip_patterns string[]
---@param line string
local strip_line = function(strip_patterns, line)
	for _, pattern in ipairs(strip_patterns) do
		line = line:gsub(pattern, "")
	end
	return line
end

-- local View = {
-- 	---@param view View
-- 	---@param line string
-- 	strip_line = function(strip_patterns, line)
-- 		for _, pattern in ipairs(strip_patterns) do
-- 			line = line:gsub(pattern, "")
-- 		end
-- 		return line
-- 	end,
-- }

---@type View
local fern = {
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
	strip_line = function(line)
		return line:gsub("$", "")
	end,
	parse_entry = function(line)
		return strip_line({ "^|[%-%+]?" }, line)
	end,
  format_entry = function(entry)

    if entry:is_root() then
      return entry.name
    end
    local padding = (" "):rep(entry.depth)
    local symbol
    if entry.type == "directory" then
      symbol = vim.tbl_isempty(entry.children) and "|+ " or "|- "
    elseif entry.type == "file" then
      symbol = "|  "
    else
      assert(false, "Unknown entry type: " .. entry.type)
    end
    return padding .. symbol .. entry.name
  end,
	skip_first_line = true,
	get_root_path = function()
		local helper = vim.fn["fern#helper#new"]()
		return helper.fern.root._path
	end,
}
fern = setmetatable(fern, { __index = View })

local M = {
	fern = fern,
}

---@type table<string, View>
return M
