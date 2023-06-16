local adapter = require("editree.oil_adapter")
local viewers = require("editree.viewers")
local fern = viewers.from_filetype("fern")

local unwrap = require("tests.util").unwrap

local split_lines = function(lines)
	return vim.split(lines, "\n", {})
end

describe("oil adapter", function()
	setup(function()
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

		it("fern tree with IDs", function()
			local lines = [[
root
/002 |+ dir/
/003 |  file.txt
/004 |- dir2/
/005  |  file2.txt]]
			local expected = [[
root
002/  dir/
003/  file.txt
004/  dir2/
005/   file2.txt]]

			local tree = unwrap(adapter._parse_tree_with_ids(fern, split_lines(lines)))
			assert.are_same(expected, tostring(tree))
		end)
	end)

	describe("should reformat", function()
		it("when whole line is overindented", function()
			local lines = [[
	root
	      /002 |  file.txt
	]]
			local expected = [[
	root
	 file.txt
	     ]]

			local tree = unwrap(adapter._build_tree(fern, split_lines(lines)))
			-- local actual =
			-- assert.are
		end)
	end)
end)
