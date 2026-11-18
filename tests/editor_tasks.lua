vim.opt.rtp:prepend(vim.fn.getcwd())
require 'config.options'
require 'config.autocmds'
local messages = {}
vim.notify = function(text)
  messages[#messages + 1] = text
end
local tasks = require 'config.tasks'
local root = vim.fn.tempname() .. ' project with spaces'
vim.fn.mkdir(root .. '/build', 'p')
vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, root .. '/build/my program')
vim.fn.setfperm(root .. '/build/my program', 'rwxr-xr-x')
local exe = tasks.executables { root, root .. '/build', root .. '/build' }
assert(#exe == 1 and exe[1]:match 'my program$', 'discover executable files, deduplicate, exclude directories')
vim.fn.writefile({ 'all:', '\t@sleep 0.15', '\t@touch completed' }, root .. '/Makefile')
local done, tick = false, false
vim.defer_fn(function()
  tick = true
end, 30)
assert(tasks.run({ 'make', '-j' .. tasks.jobs() }, root, function()
  done = true
end))
assert(not tasks.run({ 'make' }, root, function()
  error 'duplicate build'
end))
assert(not done, 'build must return without blocking')
assert(vim.wait(2000, function()
  return done
end))
assert(tick and vim.fn.filereadable(root .. '/completed') == 1, 'UI timer should run during build')
local failed = false
tasks.run({ 'sh', '-c', 'echo test.c:2: error: failed >&2; exit 1' }, root, function()
  failed = true
end)
assert(vim.wait(2000, function()
  return #vim.fn.getqflist() > 0
end))
assert(not failed and vim.iter(vim.fn.getqflist()):any(function(item)
  return item.lnum == 2 and vim.api.nvim_buf_get_name(item.bufnr):sub(-6) == 'test.c'
end), 'failed build preserves diagnostics')
vim.fn.setqflist({}, 'r', { items = { { filename = 'one', lnum = 1, text = 'first' }, { filename = 'two', lnum = 2, text = 'second' } } })
vim.cmd 'copen'
vim.fn.maparg('dd', 'n', false, true).callback()
assert(#vim.fn.getqflist() == 1 and vim.fn.getqflist()[1].text == 'second', 'quickfix deletion')
vim.cmd 'cclose'
vim.fn.setloclist(0, {}, 'r', { items = { { filename = 'local-one', lnum = 1 }, { filename = 'local-two', lnum = 2 } } })
vim.cmd 'lopen'
vim.fn.maparg('dd', 'n', false, true).callback()
assert(#vim.fn.getloclist(0) == 1 and #vim.fn.getqflist() == 1, 'location list deletion must not edit quickfix')
local other = vim.fn.tempname()
vim.fn.mkdir(other .. '/src', 'p')
vim.cmd.cd(vim.fn.fnameescape(other))
vim.cmd.edit(vim.fn.fnameescape(root .. '/outside.c'))
local called = false
local system = vim.system
vim.system = function()
  called = true
end
tasks.format_project()
vim.system = system
assert(not called and messages[#messages]:find('Git project'), 'formatting outside Git must stop before enumerating files')

local choices = 0
vim.ui.select = function(items, _, select)
  choices = choices + 1
  select(items[1])
end
tasks.make('select')
assert(choices == 1, 'Make executable selection should be available without building')
local state = vim.fn.stdpath 'state' .. '/make-targets/' .. vim.fn.sha256(vim.fs.root(0, 'Makefile'))
assert(vim.fn.readfile(state)[1]:match 'my program$', 'persist executable for this project only')
vim.fn.delete(other, 'rf')
vim.fn.delete(root, 'rf')
print 'PASS asynchronous build, executable discovery, duplicate jobs, build errors, quickfix and location lists'
vim.cmd 'qa!'
