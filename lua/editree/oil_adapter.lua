---@class OilAdapter
local M = {}

local tree_ops = require("editree.tree_ops")

local get_oil_url = function(root_path, rel_path)
	return ("oil://%s"):format(vim.fs.joinpath(root_path, rel_path))
end

---@param root_path string
---@param diff editree.Diff
---@return oil.Action
M.diff_to_action = function(root_path, diff)
	local node = diff.node
	local url = get_oil_url(root_path, tree_ops.get_rel_path(node))
	local entry_type = node.type
	local action = { type = diff.type, entry_type = entry_type }

	if diff.type == "rename" then
		-- Oil only knows "move" actions
		action.type = "move"
		action.src_url = url
		action.dest_url = get_oil_url(root_path, diff.new_name)
	elseif diff.type == "move" then
		action.src_url = url
		action.dest_url = get_oil_url(root_path, tree_ops.get_rel_path(diff.to))
  elseif diff.type == "copy" then
		action.src_url = url
		action.dest_url = get_oil_url(root_path, tree_ops.get_rel_path(diff.to))
	elseif diff.type == "create" or diff.type == "delete" then
		action.url = url
	end
	return action
end

---@param root_path string
---@param diffs editree.Diff[]
---@param return_to_view_cb fun()
M.apply_diffs = function(root_path, diffs, return_to_view_cb)
	local actions = vim.tbl_map(function(diff)
		return M.diff_to_action(root_path, diff)
	end, diffs)
	require("oil.mutator.preview").show(actions, true, function(confirmed)
		if confirmed then
			require("oil.mutator").process_actions(
				actions,
				vim.schedule_wrap(function(err)
					if err then
						vim.notify(string.format("[editree] Error applying actions: %s", err), vim.log.levels.ERROR)
					else
						return_to_view_cb()
					end
				end)
			)
		end
	end)
end

return M
