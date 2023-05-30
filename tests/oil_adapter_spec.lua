local adapter = require("editree.oil_adapter")
local viewers = require("editree.viewers")
local fern = viewers.fern

local unwrap = function(...)
	local ok, result = ...
	if ok then
		return result
	else
		assert(false, "failed to unwrap result " .. result)
	end
end

local split_lines = function(lines)
	return vim.split(lines, "\n", {})
end

local strip_ids = function(lines)
	local max_id_len = math.max(3, 1 + math.floor(math.log10(#lines)))
	return vim.iter(split_lines(lines)):map(function(line) end):totable()
end

describe("oil adapter", function()
	describe("should parse", function()
		it("fern tree", function()
			local lines = [[
root
|+ dir/
|  file.txt
|- dir2/
 |  file2.txt]]
			local expected = [[
root
 dir/
 file.txt
 dir2/
  file2.txt]]

			local tree = unwrap(adapter._build_tree(fern, split_lines(lines)))
			assert.are_same(expected, tostring(tree))
		end)
	end)
end)
