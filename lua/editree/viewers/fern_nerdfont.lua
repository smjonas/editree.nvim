local base = require("editree.viewers")
local Fern = require("editree.viewers.fern")
local strip_patterns = base.strip_patterns

local get_option = function(option_name)
  return ("fern#renderer#nerdfont#%s"):format(option_name)
end

---@class editree.View.fern_nerdfont : editree.View.fern

---@type editree.View.fern_nerdfont
local FernNerdfont = {}
FernNerdfont = setmetatable({}, { __index = Fern })

function FernNerdfont:read_root_line(line)
    local padding = get_option("root_symbol") == "" and "" or get_option("padding")
    local prefix = get_option("root_leading") .. get_option("root_symbol") .. padding
    return strip_patterns({ "^" .. prefix, "$" }, line)
end

function FernNerdfont:parse_entry(line)
    -- "." removes the nerdfont icon
    return strip_patterns({ "^%s*.", "%s*$" }, line)
end

function FernNerdfont:tree_entry_tostring(entry)
    return "todo"
end

return FernNerdfont
