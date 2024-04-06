local base = require("editree.viewers")
local strip_patterns = base.strip_patterns

local get_symbol = function(symbol_name)
	local symbol = vim.g[("fern#renderer#default#%s_symbol"):format(symbol_name)]
	assert(symbol, "fern symbol not found: " .. symbol_name)
	return symbol
end

---@class editree.View.fern : editree.View

---@type editree.View.fern
local Fern = {}
Fern = setmetatable({}, { __index = base })

Fern.syntax_name = "editree_fern"

function Fern:set_on_enter_callback(on_enter)
	vim.fn["fern#hook#add"]("viewer:ready", function()
		on_enter()
	end, { once = 1 })
end

function Fern:is_file(file)
	return not file:match("/$")
end

function Fern:is_directory(dir)
	return dir:match("/$")
end

function Fern:tree_node_tostring(node)
	if node:is_root() then
		return node.name
	end
	local padding = (" "):rep(node.depth - 1)
	local symbol
	if node.type == "directory" then
		symbol = vim.tbl_isempty(node.children) and get_symbol("collapsed") or get_symbol("expanded")
	elseif node.type == "file" then
		symbol = get_symbol("leaf")
	else
		error("Unknown entry type: " .. node.type)
	end
	local suffix = node.type == "directory" and "/" or ""
	return ("/%s %s%s%s%s"):format(node.id, padding, symbol, node.name, suffix)
end

function Fern:get_root_path()
	local helper = vim.fn["fern#helper#new"]()
	return helper.fern.root._path
end

function Fern.preprocess_buf_line(line, line_nr)
	-- Root line
	if line_nr == 1 then
		return strip_patterns({ "$" }, line)
	end
	local stripped = strip_patterns({
		vim.pesc(get_symbol("leaf")),
		vim.pesc(get_symbol("collapsed")),
		vim.pesc(get_symbol("expanded")),
		-- This invisible character is present at the end of each line in a fern buffer
		"$",
	}, line)
	-- Prepend a space for correct indentation
	return " " .. stripped
end

function Fern:preprocess_buf_lines(lines)
	return vim.tbl_map(function(line)
		return Fern.preprocess_buf_line(line)
	end, lines)
end

return Fern
