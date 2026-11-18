local root = vim.fn.tempname() .. ' history'
vim.fn.mkdir(root, 'p')
vim.cmd.cd(vim.fn.fnameescape(root))
local function git(args)
  local result = vim
    .system(vim.list_extend({ 'git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false' }, args), { text = true })
    :wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end

git { 'init', '-q' }
vim.fn.writefile({ 'first' }, 'sample.txt')
git { 'add', 'sample.txt' }
git { 'commit', '-qm', 'first' }
local first = git { 'rev-parse', 'HEAD' }
vim.fn.writefile({ 'first', 'second' }, 'sample.txt')
git { 'commit', '-qam', 'second' }
local second = git { 'rev-parse', 'HEAD' }

vim.cmd.edit 'sample.txt'
vim.cmd 'G log -p'
local log_buf = vim.api.nvim_get_current_buf()
for _, sha in ipairs { first, second } do
  local line = vim.fn.search('^commit ' .. sha, 'cw')
  assert(line ~= 0, 'missing commit in log')
  vim.api.nvim_win_set_cursor(0, { line, 9 })
  local map = vim.fn.maparg('<Space>gD', 'n', false, true)
  assert(map.callback, 'Fugitive commit mapping')
  map.callback()
  assert(
    vim.wait(5000, function()
      local view = require('diffview.lib').get_current_view()
      return view and view.cur_entry and view.cur_entry.path == 'sample.txt' and view.cur_entry.opened
    end),
    'root and subsequent commits must open with a file'
  )
  vim.cmd 'DiffviewClose'
  assert(vim.api.nvim_get_current_buf() == log_buf)
end
assert(vim.fn.search('^diff --git', 'cw') ~= 0)
vim.api.nvim_feedkeys(vim.keycode '<CR>', 'mx', false)
assert(vim.api.nvim_get_current_buf() ~= log_buf, 'native Fugitive Enter must navigate patch headers')

vim.cmd.edit 'sample.txt'
vim.api.nvim_buf_set_lines(0, 0, 0, false, { 'unsaved' })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
require('config.tasks').show_commit()
assert(
  vim.wait(5000, function()
    return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == 'commit ' .. first
  end),
  'blame must use the line from the modified buffer'
)
print 'PASS root and non-root commit diffs, native Fugitive navigation, buffer-aware blame'
vim.cmd 'qa!'
