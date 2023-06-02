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
  config = {},
  dependencies = {
    -- You can also extract your config for oil.nvim or your tree viewer into separate files,
    -- lazy.nvim will load the config from there.
    { "stevearc/oil.nvim", config = {} },
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
Then use the `:Editree open` or `:Editree open` command to open `editree` in the current buffer. To modify the filesystem, simply modify the lines in the buffer, then save the buffer.
You will be prompted to confirm the filesystem operations before they are executed.

`Editree` does not override existing keymappings in the tree viewer. Instead, it is recommended to create a keymap that enters / exits "`editree` mode".
For example, you could use the following mapping to toggle `editree` when pressing the <kbd>F1</kbd> key:

```lua
vim.keymap.set("n", "<F1>", "Editree toggle", { desc = "Toggle editree" })
```
