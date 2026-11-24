local root = vim.fn.tempname() .. ' python project'
vim.fn.mkdir(root .. '/src', 'p')
root = vim.uv.fs_realpath(root)
local file = root .. '/src/hello world.py'
local venv = vim.system({ 'python3', '-m', 'venv', '--without-pip', root .. '/.venv' }):wait()
assert(venv.code == 0, venv.stderr)
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
vim.cmd.edit(vim.fn.fnameescape(file))
local source = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(source, 0, -1, false, {
  'import sys',
  'from pathlib import Path',
  'Path("result").write_text(input() + "\\n" + sys.prefix)',
})
require 'telescope'
local choice
vim.ui.select = function(items, _, select)
  assert(vim.deep_equal(items, { 'Run', 'Debug' }))
  select(choice)
end
local action_menu = vim.fn.maparg('<space>r', 'n', false, true).callback
action_menu()
assert(vim.bo.modified and vim.fn.filereadable(file) == 0, 'cancel must leave edits alone')
choice = 'Run'
action_menu()
assert(vim.bo.buftype == 'terminal', 'Python opens an interactive terminal')
local first_terminal, first_window = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
local first_exited = false
vim.api.nvim_create_autocmd('TermClose', { buffer = first_terminal, once = true, callback = function() first_exited = true end })
vim.fn.chansend(vim.b.terminal_job_id, 'hello\n')
assert(
  vim.wait(5000, function()
    return vim.fn.filereadable(root .. '/result') == 1 and vim.fn.getfsize(root .. '/result') > 0
  end),
  'Python script did not finish'
)
assert(vim.deep_equal(vim.fn.readfile(root .. '/result'), { 'hello', root .. '/.venv' }), 'project cwd and interpreter')
assert(not package.loaded.dap, 'a normal Python run should not load the debugger')
assert(vim.wait(5000, function() return first_exited end), 'first run should exit')
vim.cmd.wincmd 'p'
assert(vim.api.nvim_get_current_buf() == source)
local windows = #vim.api.nvim_tabpage_list_wins(0)
action_menu()
assert(vim.api.nvim_get_current_win() == first_window, 'reuse the exited run window')
assert(#vim.api.nvim_tabpage_list_wins(0) == windows, 'rerunning must not create a split')
assert(not vim.api.nvim_buf_is_valid(first_terminal), 'remove the old exited terminal')
local second_job = vim.b.terminal_job_id
local second_exited = false
vim.api.nvim_create_autocmd('TermClose', { buffer = 0, once = true, callback = function() second_exited = true end })
vim.fn.chansend(second_job, 'again\n')
assert(vim.wait(5000, function() return second_exited end), 'second run should exit')
assert(vim.deep_equal(vim.fn.readfile(root .. '/result'), { 'again', root .. '/.venv' }))
vim.cmd.wincmd 'p'
assert(vim.api.nvim_get_current_buf() == source)
local dap, launch = require 'dap', nil
dap.run = function(config)
  launch = config
end
choice = 'Debug'
action_menu()
assert(launch and launch.program == file and launch.cwd == root and launch.pythonPath == root .. '/.venv/bin/python')
assert(vim.deep_equal(launch, dap.configurations.python[1]()), 'F5 and the menu use the same launch settings')
vim.fn.delete(root, 'rf')
io.stdout:write 'PASS file action cancellation, interactive Python input, project virtualenv and debug launch\n'
vim.cmd 'qa!'
