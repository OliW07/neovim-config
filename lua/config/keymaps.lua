vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open buffer diagnostic location list' })
vim.keymap.set('n', '<leader>Q', function()
  vim.diagnostic.open_float { border = 'rounded', source = 'if_many' }
end, { desc = 'Show diagnostic float' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to upper window' })

vim.keymap.set('n', '<S-h>', '<C-w><C-h>', { desc = 'Move focus to left window' })
vim.keymap.set('n', '<S-l>', '<C-w><C-l>', { desc = 'Move focus to right window' })
vim.keymap.set('n', '<S-j>', '<C-w><C-j>', { desc = 'Move focus to lower window' })
vim.keymap.set('n', '<S-k>', '<C-w><C-k>', { desc = 'Move focus to upper window' })

vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w><C-h>', { desc = 'Move focus to left window' })
vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w><C-l>', { desc = 'Move focus to right window' })
vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w><C-j>', { desc = 'Move focus to lower window' })
vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w><C-k>', { desc = 'Move focus to upper window' })

vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and center' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center' })

vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next search result centered' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Prev search result centered' })

vim.keymap.set('n', '<leader>mp', '<cmd>MarkdownPreviewToggle<CR>', { desc = 'Markdown preview toggle' })
vim.keymap.set('n', '<leader>mz', '<cmd>ZenMode<CR>', { desc = 'Markdown zen mode' })
vim.keymap.set('n', '<leader>me', '<cmd>Pencil<CR>', { desc = 'Markdown edit mode' })
vim.keymap.set('n', '<leader>mn', '<cmd>noautocmd MarkdownPreviewStop<CR>', { desc = 'Markdown stop preview' })

vim.keymap.set({ 'n', 'x' }, '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set('n', '<leader>Y', function()
  local path = vim.fn.expand '%:p'
  path = path:gsub('^%a[%w.+-]*://', '')
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path)
end, { desc = 'Yank absolute file path' })
vim.keymap.set({ 'n', 'x' }, '<leader>p', '"+p', { desc = 'Paste from system clipboard' })
vim.keymap.set('n', '<leader>d', '"_d', { desc = 'Delete without yank' })
vim.keymap.set('n', '<leader>D', '"_D', { desc = 'Delete line without yank' })

vim.keymap.set('n', 'gp', '`[v`]', { desc = 'Select last pasted' })

vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save buffer' })
vim.keymap.set('n', '<leader>bd', '<cmd>bd<CR>', { desc = 'Delete buffer' })

vim.keymap.set('n', '<leader>ff', function()
  require('telescope.builtin').find_files()
end, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', function()
  require('telescope.builtin').live_grep()
end, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', function()
  require('telescope.builtin').buffers()
end, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', function()
  require('telescope.builtin').help_tags()
end, { desc = 'Help tags' })
vim.keymap.set('n', '<leader>fr', function()
  require('telescope.builtin').resume()
end, { desc = 'Resume last search' })
vim.keymap.set('n', '<leader>fc', function()
  require('telescope.builtin').colorscheme()
end, { desc = 'Find colorschemes' })

vim.keymap.set('n', '<leader>so', '<cmd>source<CR>', { desc = 'Source current buffer' })

vim.keymap.set('n', '<leader>gb', function()
  require('gitsigns').blame_line()
end, { desc = 'Git blame line' })

vim.keymap.set('n', '<leader>gS', function()
  require('config.tasks').show_commit()
end, { desc = 'Git show commit for current line' })

-- Git hunk operations (gitsigns)
vim.keymap.set('n', '<leader>hs', function()
  require('gitsigns').stage_hunk()
end, { desc = 'Stage hunk' })
vim.keymap.set('n', '<leader>hr', function()
  require('gitsigns').reset_hunk()
end, { desc = 'Reset hunk' })
vim.keymap.set('n', '<leader>hp', function()
  require('gitsigns').preview_hunk()
end, { desc = 'Preview hunk' })
vim.keymap.set('n', '<leader>hu', function()
  require('gitsigns').undo_stage_hunk()
end, { desc = 'Undo stage hunk' })
vim.keymap.set('n', '<leader>hd', function()
  require('gitsigns').diffthis()
end, { desc = 'Diff this file' })
vim.keymap.set('v', '<leader>hs', function()
  require('gitsigns').stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
end, { desc = 'Stage hunk' })
vim.keymap.set('v', '<leader>hr', function()
  require('gitsigns').reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
end, { desc = 'Reset hunk' })

-- Git operations (fugitive)
vim.keymap.set('n', '<leader>gs', '<cmd>G<CR>', { desc = 'Git status' })
vim.keymap.set('n', '<leader>gl', '<cmd>G log<CR>', { desc = 'Git log' })
vim.keymap.set('n', '<leader>gc', '<cmd>Git commit<CR>', { desc = 'Git commit' })
vim.keymap.set('n', '<leader>gp', '<cmd>Git pull<CR>', { desc = 'Git pull' })
vim.keymap.set('n', '<leader>gP', '<cmd>Git push<CR>', { desc = 'Git push' })
vim.keymap.set('n', '<leader>gF', '<cmd>Git fetch<CR>', { desc = 'Git fetch' })

-- Build tasks load on demand and never block the editor.
for key, action in pairs { mb = 'build', mr = 'run', md = 'debug' } do
  vim.keymap.set('n', '<leader>' .. key, function()
    require('config.tasks').make(action ~= 'build' and action or nil)
  end, { desc = 'Make ' .. action })
end
vim.keymap.set('n', '<leader>F', function()
  require('config.tasks').format_project()
end, { desc = 'Format C/C++ project' })

-- :qm is :qa without leaving Neovim -- one Oil window stays. :qm! discards.
local function quit_most(bang)
  if not bang then
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
        vim.notify('No write since last change (:qm! to discard)', vim.log.levels.ERROR)
        return
      end
    end
  end

  pcall(vim.cmd.DiffviewClose)
  local ok_review, review = pcall(require, 'config.review')
  if ok_review then
    review.current = nil
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= '' then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  if #vim.api.nvim_list_tabpages() > 1 then
    pcall(vim.cmd, 'tabonly!')
  end
  if #vim.api.nvim_tabpage_list_wins(0) > 1 then
    pcall(vim.cmd, 'only!')
  end

  local keep
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'oil' then
      keep = buf
      break
    end
  end
  if keep then
    vim.api.nvim_set_current_buf(keep)
  else
    local ok_oil, oil = pcall(require, 'oil')
    if ok_oil then
      oil.open()
      keep = vim.api.nvim_get_current_buf()
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= keep and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

vim.api.nvim_create_user_command('Qm', function(opts)
  quit_most(opts.bang)
end, { bang = true, desc = 'Quit all windows except the file tree' })
vim.cmd [[cnoreabbrev <expr> qm (getcmdtype() == ':' && getcmdline() ==# 'qm') ? 'Qm' : 'qm']]
