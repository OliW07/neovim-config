local root = vim.fn.tempname() .. ' cmake project'
vim.fn.mkdir(root .. '/src', 'p')
root = vim.uv.fs_realpath(root)
vim.fn.writefile({
  'cmake_minimum_required(VERSION 3.15)',
  'project(ConfigSmoke LANGUAGES C)',
  'add_subdirectory(src)',
  'add_custom_target(marker ALL COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/built")',
}, root .. '/CMakeLists.txt')
vim.fn.writefile({ 'add_executable(sample main.c)' }, root .. '/src/CMakeLists.txt')
local file = root .. '/src/main.c'
vim.fn.writefile({ '#include <stdio.h>', 'int main(void) { return 1; }' }, file)
local unrelated = vim.fn.tempname()
vim.cmd.edit(unrelated)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved' })
vim.cmd.edit(vim.fn.fnameescape(file))
vim.api.nvim_buf_set_lines(0, 1, -1, false, { 'int main(void) { return fclose(fopen("ran", "w")); }' })
require('lazy').load { plugins = { 'cmake-tools.nvim' } }
require 'telescope'
local choice = 'Run'
vim.ui.select = function(items, opts, select)
  if opts.prompt:match '^Action for ' then
    assert(vim.deep_equal(items, { 'Build', 'Run', 'Debug' }))
    return select(choice)
  end
  for i, item in ipairs(items) do
    if type(item) == 'table' and item.short == 'Debug' then
      return select(item, i)
    end
  end
  select(items[1], 1)
end
local action_menu = vim.fn.maparg('<space>r', 'n', false, true).callback
action_menu()
assert(
  vim.wait(15000, function()
    return vim.fn.filereadable(root .. '/build/src/ran') == 1
  end, 50),
  'Run must configure, compile and launch the target on the first invocation'
)
assert(vim.fn.getcwd() == root, 'CMake commands use the parent project cwd')
assert(vim.fn.readfile(file)[2]:find 'fclose', 'save modified project inputs')
assert(vim.fn.filereadable(unrelated) == 0, 'CMake must leave unrelated buffers unsaved')
vim.cmd.edit(vim.fn.fnameescape(root .. '/CMakeLists.txt'))
choice = 'Build'
action_menu()
assert(
  vim.wait(10000, function()
    return vim.fn.filereadable(root .. '/build/built') == 1
  end, 50),
  'Build action in CMakeLists.txt must build the project'
)
vim.cmd('tcd ' .. vim.fn.fnameescape(vim.fn.stdpath 'config'))
vim.fn.delete(root, 'rf')
io.stdout:write 'PASS file actions configure, run and build a nested CMake project with spaces in its path\n'
vim.cmd 'qa!'
