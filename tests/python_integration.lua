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
vim.fn.chansend(vim.b.terminal_job_id, 'hello\n')
assert(
  vim.wait(5000, function()
    return vim.fn.filereadable(root .. '/result') == 1 and vim.fn.getfsize(root .. '/result') > 0
  end),
  'Python script did not finish'
)
assert(vim.deep_equal(vim.fn.readfile(root .. '/result'), { 'hello', root .. '/.venv' }), 'project cwd and interpreter')
assert(not package.loaded.dap, 'a normal Python run should not load the debugger')
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
