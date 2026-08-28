vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  group = vim.api.nvim_create_augroup('markdown-settings', { clear = true }),
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { 'en_us' }
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = 'i'
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'rst',
  group = vim.api.nvim_create_augroup('rst-settings', { clear = true }),
  desc = 'Make gf follow toctree/doc paths in reStructuredText',
  callback = function()
    vim.opt_local.suffixesadd:append('.rst')
    vim.opt_local.path:append('.')
  end,
})

local numbergroup = vim.api.nvim_create_augroup('numbertoggle', { clear = true })
vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'InsertLeave', 'WinEnter' }, {
  pattern = '*',
  group = numbergroup,
  callback = function()
    if vim.opt.number:get() and vim.api.nvim_get_mode().mode ~= 'i' then
      vim.opt.relativenumber = true
    end
  end,
})
vim.api.nvim_create_autocmd({ 'BufLeave', 'FocusLost', 'InsertEnter', 'WinLeave' }, {
  pattern = '*',
  group = numbergroup,
  callback = function()
    if vim.opt.number:get() then
      vim.opt.relativenumber = false
    end
  end,
})
