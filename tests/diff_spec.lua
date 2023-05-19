local Tree = require("editree.tree")
local NodeType = Tree.NodeType
local diff = require("editree.diff")

it("should work for simple rename", function()
	local old = Tree.new("root")
	local file = old:add_file("file.txt", "001")
	local new = Tree.new("root")
	local renamed_file = new:add_file("renamed_file.txt", "001")

	local expected = { { type = "rename", node = file:clone(), new_name = renamed_file.name } }
	assert.are_same(expected, diff.compute(old, new))
end)

it("should work for simple deletion", function()
	local old = Tree.new("root")
	local file = old:add_file("file1.txt", "001")
	local new = Tree.new("root")

	local expected = { { type = "delete", node = file:clone() } }
	assert.are_same(expected, diff.compute(old, new))
end)
