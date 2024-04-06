local tree_parser = require("editree.tree_parser")
local utils = require("tests.utils")
local split_lines = utils.split_lines

describe("tree parser should parse", function()
  it("nested tree", function()
    local lines = [[
root/
 folder1/
  file1.txt
  file2.txt
  subfolder1/
   subfile1.txt
 folder2/
  file3.txt
 file4.txt]]

    local tree = tree_parser.parse_tree(split_lines(lines))
    assert.are_same(lines, tostring(tree))
  end)
end)
