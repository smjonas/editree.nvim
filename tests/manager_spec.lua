local tree_parser = require("editree.tree_parser")
local viewers = require("editree.viewers")
local fern = viewers.from_filetype("fern")

local unwrap = require("tests.utils").unwrap

local split_lines = function(lines)
	return vim.split(lines, "\n", {})
end

describe("manager", function()
	before_each(function()
		-- Initialize global fern variables
		local symbols = {
			leaf = "|  ",
			collapsed = "|+ ",
			expanded = "|- ",
		}
		for symbol_name, symbol in pairs(symbols) do
			vim.g[("fern#renderer#default#%s_symbol"):format(symbol_name)] = symbol
		end
	end)

	describe("should parse", function()
		it("fern tree", function()
			local lines = [[
root
|+ dir/
|  file1.txt
|- dir2/
 |  file3.txt]]

			local expected = [[
root/
 dir/
 file1.txt
 dir2/
  file3.txt]]

			local processed = fern:preprocess_buf_lines(split_lines(lines))
			local tree = tree_parser.parse_tree(processed)
			assert.are_same(expected, tostring(tree))
		end)

		it("fern tree with IDs", function()
			local lines = [[
root
/002 |+ dir/
/003 |  file.txt
/004 |- dir2/
/005  |  file2.txt]]

			local expected = [[
root/
 dir/
 file.txt
 dir2/
  file2.txt]]

			local tree = unwrap(tree_parser.parse_tree_with_ids(split_lines(lines), true, fern.preprocess_buf_line))
			assert.are_same(expected, tostring(tree))
		end)
	end)
end)
