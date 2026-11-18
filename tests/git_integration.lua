local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
root = vim.uv.fs_realpath(root)
local function git(...)
  local cmd = { 'git', '-C', root }
  vim.list_extend(cmd, { ... })
  local result = vim.system(cmd, { text = true }):wait()
  assert(result.code == 0, result.stderr)
end
git('init', '-q')
git('config', 'user.name', 'Editor Test')
git('config', 'user.email', 'editor-test@example.invalid')
vim.fn.writefile({ 'base' }, root .. '/sample.txt')
git('add', 'sample.txt')
git('-c', 'commit.gpgsign=false', 'commit', '-qm', 'base')
vim.fn.writefile({ 'base', 'change' }, root .. '/sample.txt')
git('-c', 'commit.gpgsign=false', 'commit', '-qam', 'change')
vim.cmd.cd(root)
vim.fn.writefile({ 'sample.txt' }, root .. '/link.txt')
vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/link.txt'))
vim.fn.maparg('gf', 'n', false, true).callback()
assert(vim.api.nvim_buf_get_name(0) == root .. '/sample.txt', 'gf must retain ordinary file navigation')
vim.cmd 'DiffviewOpen HEAD~1..HEAD'
local lib = require 'diffview.lib'
assert(
  vim.wait(5000, function()
    local view = lib.get_current_view()
    return view and view.cur_entry and view.cur_entry.path == 'sample.txt'
  end, 20),
  'local Git diff must open without PR-review hooks'
)
assert(not package.loaded['config.review'])
vim.cmd 'Qm'
assert(#vim.api.nvim_list_tabpages() == 1 and #vim.api.nvim_list_wins() == 1, 'Qm must clean up Diffview')
assert(vim.bo.filetype == 'oil', 'Qm must preserve the file browser')
assert(not package.loaded['config.review'])
vim.fn.delete(root, 'rf')
print 'PASS local Git Diffview and Qm cleanup without machine-specific review tooling'
vim.cmd 'qa!'
