local Tree = require("editree.tree")
local diff = require("editree.diff")

describe("diff", function()
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

	it("should work for simple deletion", function()
		local old = Tree.new("root")
		local file = old:add_file("file1.txt", "001")
		local new = Tree.new("root")

		local expected = { { type = "delete", node = file:clone() } }
		assert.are_same(expected, diff.compute(old, new))
	end)

	it("should work for nested deletion", function()
		local old = Tree.new("root")
		local child = old:add_dir("child", "001")
		child:add_file("file1.txt", "002")
		local file2 = child:add_file("file2.txt", "003")

		local new = Tree.new("root")
		new:add_dir("child", "001"):add_file("file1.txt", "002")

		local expected = { { type = "delete", node = file2:clone() } }
		assert.are_same(expected, diff.compute(old, new))
	end)

	it("#kek should work for simple insertion", function()
		local old = Tree.new("root")
		local new = Tree.new("root")
		local file = new:add_file("file1.txt", nil)

		local expected = { { type = "insert", node = file, parent = old:clone() } }
		local x = diff.compute(old, new)
		-- assert.are_same(expected, x)
	end)

	it("#kek should work for simple move", function()
		local old = Tree.new("root")
		local from =  old:add_dir("child1", "001"):add_file("file1.txt", "002")
		old:add_dir("child2", "003")

		local new = Tree.new("root")
		new:add_dir("child1", "001")
		local node = new:add_dir("child2", "003"):add_file("file1.txt", "002")

		local expected = { { type = "move", node = node, from = from:clone() } }
		local x = diff.compute(old, new)
		assert.are_same(expected, x)
	end)

	it("errors on unknown ID in new tree", function()
		local old = Tree.new("root")
		local new = Tree.new("root")
		new:add_dir("child1", "001")
		assert.are_same("unknown ID in new tree", diff.compute(old, new))
	end)

	it("errors on duplicate names within same directory", function()
		local old = Tree.new("root")
		old:add_dir("child1", "001")
		local new = Tree.new("root")
		new:add_dir("child1", "001")
		new:add_dir("child1", "001")
		assert.are_same("duplicate names in new tree", diff.compute(old, new))
	end)
end)
