local M = {}

local cur_id = 1
---@type integer #the maximum number of IDs to generate
M.max_num_ids = nil

---@param id integer
---@param max_id integer
---@return string
local format_id = function(id, max_id)
	local id_str_length = math.max(3, 1 + math.floor(math.log10(max_id)))
	local cached_id_fmt = "%0" .. string.format("%d", id_str_length) .. "d"
	return cached_id_fmt:format(id)
end

---Generates a new unique ID in ascending order
---@return string
M.get_id = function()
	assert(M.max_num_ids, "max_num_ids not set")
	local id = format_id(cur_id, M.max_num_ids)
	cur_id = cur_id + 1
	return id
end

return M
