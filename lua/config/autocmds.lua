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
    vim.opt_local.spell = false
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = 'i'
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'rst',
  group = vim.api.nvim_create_augroup('rst-settings', { clear = true }),
  desc = 'Make gf follow toctree/doc paths in reStructuredText',
  callback = function()
    vim.opt_local.suffixesadd:append '.rst'
    vim.opt_local.path:append '.'
  end,
})

local numbergroup = vim.api.nvim_create_augroup('numbertoggle', { clear = true })
vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'InsertLeave', 'WinEnter' }, {
  pattern = '*',
  group = numbergroup,
  callback = function()
    if vim.opt.number:get() and vim.api.nvim_get_mode().mode ~= 'i' then
      vim.opt_local.relativenumber = true
    end
  end,
})
vim.api.nvim_create_autocmd({ 'BufLeave', 'FocusLost', 'InsertEnter', 'WinLeave' }, {
  pattern = '*',
  group = numbergroup,
  callback = function()
    if vim.opt.number:get() then
      vim.opt_local.relativenumber = false
    end
  end,
})

-- Quickfix and location lists own their buffers; update the list API only.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  group = vim.api.nvim_create_augroup('quickfix-edit', { clear = true }),
  callback = function(event)
    vim.keymap.set('n', 'dd', function()
      local idx = vim.fn.line '.'
      local location = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].loclist == 1
      local list = location and vim.fn.getloclist(0) or vim.fn.getqflist()
      if idx > #list then
        return
      end
      table.remove(list, idx)
      local info = { items = list, idx = math.min(idx, #list) }
      if location then
        vim.fn.setloclist(0, {}, 'r', info)
      else
        vim.fn.setqflist({}, 'r', info)
      end
    end, { buffer = event.buf, desc = 'Delete list entry' })
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('indent-folding', { clear = true }),
  callback = function(event)
    if vim.bo[event.buf].buftype == '' then
      vim.opt_local.foldmethod = require('config.buffer').large(event.buf) and 'manual' or 'indent'
    end
  end,
})

-- Keep Fugitive's native Enter mapping for navigating files and patch hunks.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'git',
  group = vim.api.nvim_create_augroup('git-log-diffview', { clear = true }),
  callback = function(event)
    if vim.fn.exists '*FugitiveWorkTree' ~= 1 then
      return
    end
    local root = vim.fn.FugitiveWorkTree(event.buf)
    if root == '' then
      return
    end
    vim.keymap.set('n', '<leader>gD', function()
      local word = vim.fn.expand '<cword>'
      if not word:match '^%x+$' or #word < 7 then
        word = vim.api.nvim_get_current_line():match '^commit (%x+)' or ''
      end
      if #word < 7 then
        return vim.notify 'Place the cursor on a commit hash'
      end
      local commits = vim.fn.systemlist { 'git', '-C', root, 'rev-list', '--parents', '-n1', word, '--' }
      if vim.v.shell_error ~= 0 or not commits[1] then
        return vim.notify 'No matching commit'
      end
      local revisions = vim.split(commits[1], ' ', { plain = true })
      local parent = revisions[2]
      if not parent then
        parent = vim.fn.systemlist({ 'git', '-C', root, 'hash-object', '-t', 'tree', '--stdin' }, '')[1]
        if vim.v.shell_error ~= 0 or not parent then
          return vim.notify('Could not resolve the empty tree', vim.log.levels.ERROR)
        end
      end
      require('diffview').open { '-C=' .. root, parent .. '..' .. revisions[1] }
    end, { buffer = event.buf, desc = 'Open commit in Diffview' })
  end,
})
