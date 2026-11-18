vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.o.number = true
vim.o.mouse = 'a'
vim.o.laststatus = 3

-- Use the system clipboard for default yanks and pastes from startup.
vim.opt.clipboard = 'unnamedplus'

vim.o.breakindent = true
vim.o.foldlevel = 0
-- Default indent is 4 spaces. Per-buffer values come from .editorconfig
-- (built in) and guess-indent when the file/project already uses 2 spaces.
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.softtabstop = -1
vim.g.editorconfig = true
vim.o.undofile = true

vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '  ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.cursorlineopt = 'number'
vim.o.scrolloff = 10
vim.o.confirm = true
vim.opt.fillchars:append { eob = ' ' }
