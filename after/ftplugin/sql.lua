vim.b.db = vim.b.db or 'lumin:'
vim.keymap.set('n', '<leader>kq', '<Cmd>%DB<CR>', { buffer = true, desc = 'Run SQL buffer' })
vim.keymap.set('x', '<leader>kq', ':<C-u>0DB<CR>', { buffer = true, desc = 'Run selected SQL' })
