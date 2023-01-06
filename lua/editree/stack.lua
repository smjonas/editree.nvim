local M = {}

function M:push(value)
	table.insert(self, value)
end

function M:top()
  local value = self[#self]
  assert(value, "stack is empty")
	return value
end

function M:pop()
  local value = self[#self]
  assert(value, "attempting to pop empty stack")
	table.remove(self, #self)
end

function M.new()
	return setmetatable({}, { __index = M })
end

return M
