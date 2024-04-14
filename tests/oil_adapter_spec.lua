local Tree = require("editree.tree")
local oil_adapter = require("editree.oil_adapter")

local unwrap = require("tests.utils").unwrap

describe("oil adapter", function()
	it("should convert create diff", function()
		local root_path = "root_path"
		local node = Tree.new("root"):add_dir("node")
		local diff = { type = "create", node = node }
		local expected = { type = "create", entry_type = "directory", url = "oil://root_path/node" }
		local actual = oil_adapter.diff_to_action(root_path, diff)
		assert.are_same(expected, actual)
	end)

	it("should convert delete diff", function()
		local root_path = "root_path"
		local node = Tree.new("root"):add_dir("node", "001")
		local diff = { type = "delete", node = node }
		local expected = { type = "delete", entry_type = "directory", url = "oil://root_path/node" }
		local actual = oil_adapter.diff_to_action(root_path, diff)
		assert.are_same(expected, actual)
	end)

	it("should convert rename diff", function()
		local root_path = "root_path"
		local node = Tree.new("root"):add_dir("old_name", "001")
		local diff = { type = "rename", node = node, new_name = "new_name" }
		local expected = {
			type = "move",
			entry_type = "directory",
			src_url = "oil://root_path/old_name",
			dest_url = "oil://root_path/new_name",
		}
		local actual = oil_adapter.diff_to_action(root_path, diff)
		assert.are_same(expected, actual)
	end)

	it("should convert copy diff", function()
		local root_path = "root_path"
		local root = Tree.new("root")
		local node = root:add_dir("node_name", "001")
		local copied_node = root:add_dir("copy_name", "001")
		local diff = { type = "copy", node = node, to = copied_node }
		local expected = {
			type = "copy",
			entry_type = "directory",
			src_url = "oil://root_path/node_name",
			dest_url = "oil://root_path/copy_name",
		}
		local actual = oil_adapter.diff_to_action(root_path, diff)
		assert.are_same(expected, actual)
	end)

	it("should convert move diff", function()
		local root_path = "root_path"
		local root = Tree.new("root")
		local dir1 = root:add_dir("dir1", "001")
		local dir2 = root:add_dir("dir2", "003")
		local node = dir1:add_file("old_name.txt", "002")
		local copied_node = dir2:add_file("new_name.txt", "002")
		local diff = { type = "move", node = node, to = copied_node }
		local expected = {
			type = "move",
			entry_type = "file",
			src_url = "oil://root_path/dir1/old_name.txt",
			dest_url = "oil://root_path/dir2/new_name.txt",
		}
		local actual = oil_adapter.diff_to_action(root_path, diff)
		assert.are_same(expected, actual)
	end)
end)
