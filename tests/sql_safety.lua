vim.opt.rtp:prepend(vim.fn.getcwd())
local sql = require 'config.sql'
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.bo.filetype = 'sql'
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.postgres.sql')
assert(sql.dialect(buf) == 'postgres', 'suffix selects the validator and LSP dialect')
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.sql')
local original_system, calls, killed = vim.system, 0, 0
vim.system = function()
  calls = calls + 1
  return {
    kill = function()
      killed = killed + 1
    end,
  }
end
local diagnostics = require 'config.sql_diagnostics'
diagnostics.check(buf)
diagnostics.check(buf)
assert(calls == 2 and killed == 1, 'new diagnostics must cancel their predecessor')
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep('x', 1024 * 1024 + 1) })
diagnostics.check(buf)
assert(calls == 2 and killed == 2, 'growing beyond the size limit cancels and skips diagnostics')
vim.system = original_system
print 'PASS SQL dialects, validator cancellation, large-file guard'
vim.cmd 'qa!'
