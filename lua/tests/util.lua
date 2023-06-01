local M = {}

M.unwrap = function(...)
	local ok, result = ...
	if ok then
		return result
	else
		assert(false, "could not unwrap result, error: " .. result)
	end
end

return M
