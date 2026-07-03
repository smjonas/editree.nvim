---@class OilAdapter
local M = {}

local tree_ops = require("editree.tree_ops")

local get_oil_url = function(root_path, rel_path)
	if rel_path == "" then
		return ("oil://%s"):format(root_path)
	end
	return ("oil://%s"):format(vim.fs.joinpath(root_path, rel_path))
end

---Returns the path of `node`'s parent, relative to the root directory ("" if the parent is root).
---@param node editree.Tree
---@return string
local get_parent_rel_path = function(node)
	if node.parent:is_root() then
		return ""
	end
	return tree_ops.get_rel_path(node.parent)
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
		-- Oil only knows "move" actions. The new name is a sibling of the renamed node.
		action.type = "move"
		action.src_url = url
		action.dest_url = get_oil_url(root_path, get_parent_rel_path(node)) .. "/" .. diff.new_name
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

---@param url string an "oil://..." url
---@return string #the "oil://..." url of the parent directory
local get_parent_url = function(url)
	local path = url:sub(#"oil://" + 1)
	return "oil://" .. vim.fs.dirname(path)
end

--- oil's mutator only updates its in-memory entry cache when performing an action; it does not
--- populate it. Since editree never opens a real oil buffer for the affected directories (unlike
--- oil's own UI, which always lists a directory before you can act on its entries), we have to
--- warm the cache ourselves for every directory a "delete" or "move" action reads an entry from,
--- otherwise oil.cache.perform_action indexes a nil directory listing and errors.
---@param url string
---@param cb fun(err: string?)
local warm_directory = function(url, cb)
	local adapter = require("oil.adapters.files")
	local cache = require("oil.cache")
	local columns = require("oil.columns")

	cache.begin_update_url(url)
	local on_entries
	on_entries = function(err, entries, fetch_more)
		if err then
			cache.end_update_url(url)
			cb(err)
			return
		end
		if entries then
			for _, entry in ipairs(entries) do
				cache.store_entry(url, entry)
			end
		end
		if fetch_more then
			vim.defer_fn(fetch_more, 4)
		else
			cache.end_update_url(url)
			cb()
		end
	end
	adapter.list(url, columns.get_supported_columns(adapter), on_entries)
end

---@param actions oil.Action[]
---@param cb fun(err: string?)
local warm_directories_for_actions = function(actions, cb)
	local urls = {}
	for _, action in ipairs(actions) do
		if action.type == "delete" then
			urls[get_parent_url(action.url)] = true
		elseif action.type == "move" then
			urls[get_parent_url(action.src_url)] = true
		end
	end

	local remaining = vim.tbl_count(urls)
	if remaining == 0 then
		cb()
		return
	end
	local first_err
	for url in pairs(urls) do
		warm_directory(url, function(err)
			first_err = first_err or err
			remaining = remaining - 1
			if remaining == 0 then
				cb(first_err)
			end
		end)
	end
end

---@param root_path string
---@param diffs editree.Diff[]
---@param return_to_view_cb fun()
M.apply_diffs = function(root_path, diffs, return_to_view_cb)
	local actions = vim.tbl_map(function(diff)
		return M.diff_to_action(root_path, diff)
	end, diffs)
	require("oil.mutator.confirmation").show(actions, true, function(confirmed)
		if not confirmed then
			return
		end
		warm_directories_for_actions(actions, vim.schedule_wrap(function(warm_err)
			if warm_err then
				vim.notify(string.format("[editree] Error reading directory: %s", warm_err), vim.log.levels.ERROR)
				return
			end
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
		end))
	end)
end

return M
