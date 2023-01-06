local M = {}

local fern = {
	filetype = "fern",
	is_file = function(file)
		return not file:match("/$")
	end,
	is_directory = function(dir)
		return dir:match("/$")
	end,
	-- Remove prefixes
	strip_pattern = { "^%s*|[%-%+]?", "$" },
	skip_first_line = true,
}

local strip_line = function(line)
	for _, pattern in ipairs(fern.strip_pattern) do
		line = line:gsub(pattern, "")
	end
	return line
end

local parse_contents = function(lines)
	local tree = require("editree.tree").new(strip_line(lines[1]))
	local cur_dir = tree
	local last_seen_dir_at_depth = { [-1] = cur_dir }
	local cur_depth = -1

	local dir_stack = require("editree.stack").new()
	dir_stack:push(cur_dir)

	for i = 2, #lines do
		local line = lines[i]
		-- Count number of leading whitespaces
		local depth = #line:gsub("^(%s*).*", "%1")
		if depth < cur_depth then
			-- Moving up in the tree
			cur_dir = last_seen_dir_at_depth[cur_depth]
		end
		if depth <= cur_depth and #dir_stack > 1 then
			for _ = 1, cur_depth - depth do
				dir_stack:pop()
			end
		end

		line = strip_line(line)
		local stripped_line = line:gsub("^%s*(.*)", "%1")
		if fern.is_file(line) then
			dir_stack:top():add_file(stripped_line)
		elseif fern.is_directory(line) then
			local dir = last_seen_dir_at_depth[cur_depth]:add_dir(stripped_line)
			if depth > cur_depth then
				-- Moving down in the tree
				last_seen_dir_at_depth[depth] = cur_dir
				dir_stack:push(dir)
			end
			cur_dir = dir
		end
		cur_depth = depth
	end
	print(tree)
	return tree
end

M.parse_tree = function()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	parse_contents(lines)
end
local old_tree

local group = vim.api.nvim_create_augroup("editree", {})
vim.api.nvim_create_autocmd("InsertEnter", {
	group = group,
	callback = function()
		print("enter")
    old_tree = M.parse_tree()
	end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
	group = group,
	callback = function()
		print("leave")
    local new_tree = M.parse_tree()
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = fern.filetype,
	callback = function()
		vim.schedule(function()
			vim.bo[0].modifiable = true
		end)
	end,
})

return M
