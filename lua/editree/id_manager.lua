local M = {}

local cur_id = 1
local max_num_ids

---@param max_num_ids_ integer #the maximum number of IDs to generate
M.set_max_num_ids = function(max_num_ids_)
	max_num_ids = max_num_ids_
end

---@param id integer
---@param max_id integer
---@return string
local format_id = function(id, max_id)
	local id_str_length = math.max(3, 1 + math.floor(math.log10(max_id)))
	local cached_id_fmt = "/%0" .. string.format("%d", id_str_length) .. "d"
	return cached_id_fmt:format(id)
end

---Generates a new unique ID in ascending order
---@return string
M.get_id = function()
  assert(max_num_ids, "max_num_ids not set")
	local id = M.format_id(cur_id, max_num_ids)
	cur_id = cur_id + 1
	return id
end

return M
