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

-- In fugitive's :G log (and commit buffers), <CR> on a commit hash opens that
-- commit in Diffview's split view against its parent instead of the inline
-- patch. Anything else falls through to fugitive's own <CR>.
local function commit_under_cursor()
  local word = vim.fn.expand '<cword>'
  if not word:match '^%x+$' or #word < 7 then
    word = vim.api.nvim_get_current_line():match '^commit (%x+)' or ''
  end
  if #word < 7 then
    return nil
  end
  local root = vim.fn.FugitiveWorkTree()
  local sha = vim.fn.systemlist { 'git', '-C', root, 'rev-parse', '--verify', '--quiet', word .. '^{commit}' }[1]
  if vim.v.shell_error ~= 0 or not sha then
    return nil
  end
  return sha, root
end

local function open_commit_diff(sha, root)
  -- A root commit has no parent, so diff it against git's empty tree.
  vim.fn.system { 'git', '-C', root, 'rev-parse', '--verify', '--quiet', sha .. '^' }
  local range = vim.v.shell_error == 0 and (sha .. '^!') or ('4b825dc642cb6eb9c060e54bf8b4c69280fdd7ec..' .. sha)
  vim.cmd(('DiffviewOpen -C=%s %s'):format(vim.fn.fnameescape(root), range))
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'git',
  group = vim.api.nvim_create_augroup('git-log-diffview', { clear = true }),
  desc = 'Open commits from :G log in Diffview',
  callback = function(ev)
    -- Fugitive may (re)map <CR> after FileType, so install ours afterwards.
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      local fallback = vim.fn.maparg('<CR>', 'n', false, true)
      if fallback.desc == 'Open commit in Diffview' then
        return
      end
      vim.keymap.set('n', '<CR>', function()
        local sha, root = commit_under_cursor()
        if sha then
          vim.schedule(function()
            open_commit_diff(sha, root)
          end)
          return ''
        end
        if fallback.callback then
          fallback.callback()
          return ''
        end
        return vim.api.nvim_replace_termcodes(fallback.rhs or '<CR>', true, true, true)
      end, { buffer = ev.buf, expr = true, silent = true, desc = 'Open commit in Diffview' })
    end)
  end,
})
