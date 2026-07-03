-- Minimal init used to run the test suite headlessly via plenary.nvim's busted
-- implementation, since the specs use real `vim.*` APIs and can't run under plain busted.
-- Usage: nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/"

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

local function find_plenary()
	if vim.env.PLENARY_DIR and vim.uv.fs_stat(vim.env.PLENARY_DIR) then
		return vim.env.PLENARY_DIR
	end
	local candidates = {
		vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
		vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim",
		vim.fn.stdpath("data") .. "/site/pack/packer/opt/plenary.nvim",
		vim.fn.stdpath("data") .. "/plugged/plenary.nvim",
	}
	for _, dir in ipairs(candidates) do
		if vim.uv.fs_stat(dir) then
			return dir
		end
	end
	return nil
end

local plenary_dir = find_plenary()
if not plenary_dir then
	error(
		"[editree] Could not find plenary.nvim. Install it or set the PLENARY_DIR "
			.. "environment variable to its location before running the tests."
	)
end
vim.opt.runtimepath:prepend(plenary_dir)

vim.cmd("runtime plugin/plenary.vim")
