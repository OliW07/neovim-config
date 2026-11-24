local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
root = vim.uv.fs_realpath(root)
local file = root .. '/example.py'
vim.fn.writefile({ 'print("hello")' }, file)
vim.cmd.edit(vim.fn.fnameescape(file))
local source = vim.api.nvim_get_current_buf()
local dap = require 'dap'
local launch
dap.run = function(config) launch = config end
local function later(ms, fn)
  vim.defer_fn(function()
    local ok, err = pcall(fn)
    if not ok then print(err); vim.cmd 'cquit 1' end
  end, ms)
end
local action = vim.fn.maparg('<space>r', 'n', false, true).callback
assert(not package.loaded.telescope, 'test must start before Telescope is loaded')
action()
later(300, function()
  assert(vim.bo.filetype == 'TelescopePrompt', 'first run menu should open the Telescope dropdown')
  require('telescope.actions').close(vim.api.nvim_get_current_buf())
end)
later(600, function()
  assert(vim.api.nvim_get_current_buf() == source and not launch, 'cancel state: ' .. vim.inspect({ current = vim.api.nvim_get_current_buf(), source = source, ft = vim.bo.filetype, launch = launch, mode = vim.api.nvim_get_mode().mode }))
  action()
end)
later(900, function()
  assert(vim.bo.filetype == 'TelescopePrompt')
  local actions = require 'telescope.actions'
  local prompt = vim.api.nvim_get_current_buf()
  actions.move_selection_next(prompt)
  actions.select_default(prompt)
end)
later(1400, function()
  assert(launch and launch.program == file, 'selecting the second item should start Debug')
  vim.fn.delete(root, 'rf')
  print 'PASS fresh run dropdown, cancellation and selection'
  vim.cmd 'qa!'
end)
