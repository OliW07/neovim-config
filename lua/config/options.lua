vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

vim.o.number = true
vim.o.mouse = 'a'
vim.o.showmode = false

vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

vim.o.breakindent = true
vim.o.foldlevel = 0
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.softtabstop = 4
vim.o.undofile = true

if vim.env.SUDO_USER then
  local root_dir = '/root/.cache/nvim'
  vim.fn.mkdir(root_dir .. '/swap', 'p')
  vim.fn.mkdir(root_dir .. '/backup', 'p')
  vim.fn.mkdir(root_dir .. '/undo', 'p')
  vim.opt.directory = root_dir .. '/swap'
  vim.opt.backupdir = root_dir .. '/backup'
  vim.opt.undodir = root_dir .. '/undo'
end

vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.o.confirm = true
vim.opt.fillchars:append { eob = ' ' }

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('indent-folding', { clear = true }),
  callback = function()
    if vim.bo.buftype == '' then
      vim.opt_local.foldmethod = 'indent'
    end
  end,
})
