local M = {}

---@param lines string
M.split_lines = function(lines)
	return vim.split(lines, "\n", {})
end

M.unwrap = function(...)
	local ok, result = ...
	if ok then
		return result
	else
		assert(false, "could not unwrap result, error: " .. result)
	end
end

return M
