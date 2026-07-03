# editree.nvim
:construction: This plugin is still in early stages of development :construction:

A Neovim plugin that combines the power of `oil.nvim` with the aesthetics of your favorite tree viewer.
`Editree` allows you to edit your filetree like a regular Vim buffer to perform filesystem operations in an intuitive way.

## Requirements
- Neovim nightly
- A supported tree viewer plugin: currently, only [fern.vim](https://github.com/lambdalisue/fern.vim) is supported
- [oil.nvim](https://github.com/stevearc/oil.nvim)

## Installation

Install using your favorite package manager and call the setup function. Here's an example for lazy.nvim:

```lua
{
  "smjonas/editree.nvim",
  -- `opts` (even an empty table) makes lazy.nvim call require("editree").setup(opts) for you.
  -- Passing `config = {}` instead does NOT call setup() and will leave editree non-functional.
  opts = {},
  dependencies = {
    -- You can also extract your config for oil.nvim or your tree viewer into separate files,
    -- lazy.nvim will load the config from there.
    { "stevearc/oil.nvim", opts = {} },
    "lambdalisue/fern.vim",
  }
}
```

<details>
  <summary>packer.nvim</summary>

```lua
require("packer").startup(function(use)
  use {
    "smjonas/editree.nvim",
    config = function()
      require("editree").setup()
    end,
    requires = {
      {
        "stevearc/oil.nvim",
        config = function()
          require("oil").setup()
        end,
      },
      { "lambdalisue/fern.vim" },
    },
  }
end)
```
</details>

## Quick start
To get started, first open a supported tree viewer such as `fern.vim` from your current file / directory.
Then use the `:Editree open` command to open `editree` in the current buffer. To modify the filesystem, simply modify the lines in the buffer, then save the buffer.
You will be prompted to confirm the filesystem operations before they are executed.

Note that `:Editree open` only works while a supported tree viewer buffer (e.g. `fern`) is focused; it looks at the current buffer's filetype to find the matching viewer.

Saving the buffer applies the changes and refreshes it in place (like `oil.nvim`); it does not close editree. Use `:Editree close` (or your toggle keymap) to leave editree when you're done.

`Editree` does not override existing keymappings in the tree viewer. Instead, it is recommended to create a single keymap that opens the tree viewer (if needed) and toggles `editree` mode in one step.
For example, the following mapping opens `fern.vim` on the current file's directory and enters `editree` as soon as `fern` is ready, or toggles `editree` if you're already inside a `fern` / `editree` buffer:

```lua
local function toggle_editree()
  local editree = require("editree")
  local ft = vim.bo.filetype
  if ft == "editree" then
    editree.close()
  elseif ft == "fern" then
    editree.toggle()
  else
    -- Not in a tree viewer yet: open fern as a sidebar ("drawer") on the current
    -- file's directory, then enter editree as soon as fern is ready. Without
    -- -drawer, fern (and therefore editree) would take up the whole window.
    -- fern's drawer defaults to 30 columns (see :h g:fern#drawer_width); adjust
    -- -width=N below (or set vim.g["fern#drawer_width"] globally) to taste.
    vim.fn["fern#hook#add"]("viewer:ready", function()
      vim.schedule(editree.open)
    end, { once = 1 })
    -- Wrapped in pcall: fern's own -reveal cursor-positioning logic can throw
    -- (e.g. E5555 "Invalid cursor line") on a stale/mismatched buffer; don't let
    -- that surface as a raw error in your keymap. If this triggers often, try
    -- dropping "-reveal=%".
    local ok, err = pcall(vim.cmd, "Fern %:h -reveal=% -drawer -width=30")
    if not ok then
      vim.notify("[editree] fern failed to open: " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

vim.keymap.set("n", "<F1>", toggle_editree, { desc = "Toggle editree" })
```
