vim.opt.rtp:prepend(vim.fn.getcwd())
local calls = {}
package.loaded.lint = {
  linters = { cppcheck = { cmd = 'sh', args = {} }, staticcheck = { cmd = 'sh' }, ruff = { cmd = 'sh' } },
  try_lint = function(names, opts)
    calls[#calls + 1] = { buf = vim.api.nvim_get_current_buf(), names = names, cwd = opts.cwd }
  end,
}
require('config.lint').setup()
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/.git', 'p')
vim.fn.mkdir(root .. '/package', 'p')
root = vim.uv.fs_realpath(root)
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, root .. '/file.py')
vim.bo[buf].filetype = 'python'
vim.api.nvim_set_current_buf(buf)
local function fire(event)
  vim.api.nvim_exec_autocmds(event, { buffer = buf })
end
fire 'BufWritePost'
fire 'InsertLeave'
assert(
  vim.wait(500, function()
    return #calls == 1
  end),
  'debounced lint'
)
fire 'BufEnter'
fire 'InsertLeave'
vim.wait(250, function()
  return false
end)
assert(#calls == 1, 'unchanged buffers should not relint on navigation or insert exit')
vim.bo[buf].buftype = 'nowrite'
fire 'InsertLeave'
vim.wait(250, function()
  return false
end)
assert(#calls == 1, 'review scratch must not be linted')
vim.bo[buf].buftype = ''
vim.api.nvim_buf_set_name(buf, root .. '/package/main.go')
vim.bo[buf].filetype = 'go'
fire 'BufReadPost'
fire 'InsertLeave'
vim.wait(250, function()
  return false
end)
assert(#calls == 1, 'package staticcheck only runs on save')
fire 'BufWritePost'
assert(vim.wait(500, function()
  return #calls == 2
end))
assert(calls[2].cwd == root .. '/package' and calls[2].names[1] == 'staticcheck')
assert(package.loaded.lint.linters.staticcheck.append_fname == false)
vim.bo[buf].filetype = 'cpp'
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved C++' })
fire 'InsertLeave'
vim.wait(250, function()
  return false
end)
assert(#calls == 2, 'disk-based cppcheck must not lint stale text on insert exit')
fire 'BufWritePost'
assert(vim.wait(500, function()
  return #calls == 3
end))
vim.fn.delete(root, 'rf')
print 'PASS debounced lint, unchanged buffers, scratch exclusion, Go package cwd and save-only checks'
vim.cmd 'qa!'
