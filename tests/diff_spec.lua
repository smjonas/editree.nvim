local Tree = require("editree.tree")
local diff = require("editree.diff")

local unwrap = require("tests.utils").unwrap

describe("diff", function()
	it("works for simple rename", function()
		local old = Tree.new("root")
		old:add_file("file.txt", "001")
		local new = Tree.new("root")
		new:add_file("renamed_file.txt", "001")

		local expected = { { type = "rename", node_id = "001", new_name = "renamed_file.txt" } }
		local actual = unwrap(diff.compute(old, new))
		assert.are_same(expected, actual)
	end)

	it("works for simple deletion", function()
		local old = Tree.new("root")
		old:add_file("file1.txt", "001")
		local new = Tree.new("root")

		local expected = { { type = "delete", node_id = "001" } }
		local actual = unwrap(diff.compute(old, new))
		assert.are_same(expected, actual)
	end)

	it("works for nested deletion", function()
		local old = Tree.new("root")
		local child = old:add_dir("child", "001")
		child:add_file("file1.txt", "002")
		child:add_file("file2.txt", "003")

		local new = Tree.new("root")
		new:add_dir("child", "001"):add_file("file1.txt", "002")

		local expected = { { type = "delete", node_id = "003" } }
		local actual = unwrap(diff.compute(old, new))
		assert.are_same(expected, actual)
	end)

	it("works for simple creation", function()
		local old = Tree.new("root")
		local new = Tree.new("root")
		local file = new:add_file("file1.txt", nil)

		local expected = { { type = "create", node = file } }
		local actual = unwrap(diff.compute(old, new))
		assert.are_same(expected, actual)
	end)

	it("works for creation with existing directory", function()
		local old = Tree.new("root")
		old:add_dir("dir", "001")
		old:add_file("file1.txt", "002")

		local new = Tree.new("root")
		new:add_dir("dir", "001")
		new:add_file("file1.txt", "002")
		local file = new:add_file("file2.txt")

		local expected = { { type = "create", node = file } }
		local actual = unwrap(diff.compute(old, new))
		assert.are_same(expected, actual)
	end)

	it("works for simple copy", function()
		local old = Tree.new("root")
		old:add_file("file1.txt", "001")

		local new = Tree.new("root")
		new:add_file("file1.txt", "001")
		-- Has the same ID as the existing file
		local to = new:add_file("file2.txt", "001")

		local actual = unwrap(diff.compute(old, new))
    assert.are_same(1, #actual)
    actual = actual[1]
		assert.are_same("copy", actual.type)
		assert.are_same("001", actual.node_id)
		assert.are_same(to, actual.to)
	end)

	it("works for simple move", function()
		local old = Tree.new("root")
		old:add_dir("child1", "001"):add_file("file1.txt", "002")
		old:add_dir("child2", "003")

		local new = Tree.new("root")
		new:add_dir("child1", "001")
		local to = new:add_dir("child2", "003"):add_file("file1.txt", "002")

		local actual = unwrap(diff.compute(old, new))
    assert.are_same(1, #actual)
    actual = actual[1]
		assert.are_same("move", actual.type)
		assert.are_same("002", actual.node_id)
		assert.are_same(to.id, "002")
		assert.are_same(to.name, "file1.txt")
		assert.are_same(to.parent.id, "003")
	end)

	it("errors on unknown ID in new tree", function()
		local old = Tree.new("root")
		local new = Tree.new("root")
		new:add_dir("child1", "001")
		local ok, err = diff.compute(old, new)
		assert.is_false(ok)
		assert.are_same("unknown ID in new tree", err)
	end)

	it("errors on duplicate names within same directory", function()
		local old = Tree.new("root")
		old:add_dir("child1", "001")
		local new = Tree.new("root")
		new:add_dir("child1", "001")
		new:add_dir("child1", "001")
		local ok, err = diff.compute(old, new)
		assert.is_false(ok)
		assert.are_same("duplicate names in new tree", err)
	end)
end)
