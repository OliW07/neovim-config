# Neovim Configuration Guide

## Directory Structure

```
lua/
├── config/
│   ├── options.lua    # General editor options
│   ├── keymaps.lua    # Keybindings
│   └── autocmds.lua   # Autocommands
└── plugins/
    ├── lsp.lua        # LSP, completion, formatting
    ├── ui.lua         # Telescope, themes, UI plugins
    ├── tools.lua      # Debugger, CMake, linting
    └── editor.lua     # Treesitter, autopairs, git, etc.
```


Add new plugins to the appropriate file in `lua/plugins/`:
Keymaps are in `lua/config/keymaps.lua`:
LSP servers are configured in `lua/plugins/lsp.lua`:
Install language servers with Mason: `:Mason`

### Leader Key

Leader is `<space>`. Common patterns:
- `<leader>s` - Search
- `<leader>t` - Toggle
- `<leader>g` - Git
- `<leader>c` - CMake
- `<leader>h` - Help/Git hunk

## Useful stuff

- `:Lazy` - Plugin manager UI
- `:Mason` - LSP/DAP installer
- `:checkhealth` - Troubleshooting
- `:Telescope` commands - Search (`<leader>sf`, `<leader>sg`, etc.)
