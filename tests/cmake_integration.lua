vim.ui.select = function(items, _, select)
  select(items[1], 1)
end
local root = vim.fn.tempname() .. ' cmake project'
vim.fn.mkdir(root .. '/src', 'p')
root = vim.uv.fs_realpath(root)
vim.fn.writefile({
  'cmake_minimum_required(VERSION 3.15)',
  'project(ConfigSmoke NONE)',
  'add_subdirectory(src)',
  'add_custom_target(marker ALL COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/built")',
}, root .. '/CMakeLists.txt')
vim.fn.writefile(
  { 'if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)', '  message(FATAL_ERROR "Configure from the parent")', 'endif()' },
  root .. '/src/CMakeLists.txt'
)
vim.fn.writefile({ 'fixture' }, root .. '/src/sample.txt')
local unrelated = vim.fn.tempname()
vim.cmd.edit(unrelated)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved' })
vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/src/sample.txt'))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'project edit' })
require('config.tasks').cmake 'CMakeGenerate'
assert(
  vim.wait(10000, function()
    return vim.fn.filereadable(root .. '/build/CMakeCache.txt') == 1
  end, 50),
  'configure nested project'
)
-- Wait for the plugin to finish reading the CMake file API response.
assert(
  vim.wait(5000, function()
    local targets = require('cmake-tools').get_build_targets()
    return targets and type(targets.data) == 'table' and targets.data.targets and #targets.data.targets > 0
  end, 50),
  'load generated CMake targets: ' .. vim.inspect(require('cmake-tools').get_build_targets())
)
assert(
  vim.wait(5000, function()
    local job = require('cmake-tools.quickfix').job
    return not job or job.is_shutdown
  end, 50),
  'configure process completes'
)
vim.ui.select = function(items, _, select)
  select(items[1], 1)
end
require('config.tasks').cmake 'CMakeBuild'
assert(
  vim.wait(10000, function()
    return vim.fn.filereadable(root .. '/build/built') == 1
  end, 50),
  'build selected CMake project'
)
assert(vim.fn.getcwd() == root, 'CMake commands use project cwd, not startup cwd')
assert(vim.fn.readfile(root .. '/src/sample.txt')[1] == 'project edit', 'save modified project inputs')
assert(vim.fn.filereadable(unrelated) == 0, 'CMake must leave unrelated buffers unsaved')
vim.cmd('tcd ' .. vim.fn.fnameescape(vim.fn.stdpath 'config'))
vim.fn.delete(root, 'rf')
io.stdout:write 'PASS real CMake configure and build from nested file with spaces in project path\n'
vim.cmd 'qa!'
