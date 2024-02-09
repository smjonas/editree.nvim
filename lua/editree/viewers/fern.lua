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

function Fern:set_on_enter_callback(on_enter)
    vim.fn["fern#hook#add"]("viewer:ready", function()
        on_enter()
    end, { once = 1 })
end

function Fern:read_line(line)
    return line:gsub("$", "")
end

function Fern:read_root_line(line)
    return self.read_line(line)
end

function Fern:is_file(file)
    return not file:match("/$")
end

function Fern:is_directory(dir)
    return dir:match("/$")
end

function Fern:parse_entry(line)
    return strip_patterns({
        "^%s+",
        "%s+$",
        vim.pesc(get_symbol("leaf")),
        vim.pesc(get_symbol("collapsed")),
        vim.pesc(get_symbol("expanded")),
        -- Also remove whitespace after the fern symbols
        "^%s+",
    }, line)
end

function Fern:tree_entry_tostring(entry)
    if entry:is_root() then
        return entry.name
    end
    local padding = (" "):rep(entry.depth - 1)
    local symbol
    if entry.type == "directory" then
        symbol = vim.tbl_isempty(entry.children) and get_symbol("collapsed") or get_symbol("expanded")
    elseif entry.type == "file" then
        symbol = get_symbol("leaf")
    else
        error("Unknown entry type: " .. entry.type)
    end
    return ("/%s %s%s%s"):format(entry.id, padding, symbol, entry.name)
end

function Fern:get_root_path()
    local helper = vim.fn["fern#helper#new"]()
    return helper.fern.root._path
end

return Fern
