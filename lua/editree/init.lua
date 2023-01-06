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
	strip_patterns = { "^%s*|%+?", "^%s*|%-?", "" },
	skip_first_line = true,
}

local strip_line = function(line)
	for _, prefix in ipairs(fern.strip_patterns) do
		line = line:gsub(prefix, "")
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
    line = strip_line(line)
		local stripped_line = line:gsub("^%s*(.*)", "%1")
		if depth < cur_depth then
			-- Moving up in the tree
			cur_dir = last_seen_dir_at_depth[cur_depth]
		end
		if depth <= cur_depth and #dir_stack > 1 then
			dir_stack:pop()
		end

		if fern.is_file(line) then
			dir_stack:top():add_file(stripped_line)
			-- table.insert(dir_stack:top().children, stripped_line)
			print(("Found file %s (top of stack is %s)"):format(stripped_line, dir_stack:top().name))
			print("NOW: " .. vim.inspect(dir_stack:top()))
		elseif fern.is_directory(line) then
			local dir = cur_dir:add_dir(stripped_line)
			if depth > cur_depth then
				-- Moving down in the tree
				last_seen_dir_at_depth[depth] = cur_dir
				vim.pretty_print("Set at level" .. depth .. " to " .. vim.inspect(cur_dir.name))
			end
			cur_dir = dir
			dir_stack:push(dir)
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

return M
