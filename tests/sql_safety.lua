vim.opt.rtp:prepend(vim.fn.getcwd())
local sql, words = require 'config.sql', require 'config.sql_words'
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.bo.filetype = 'typescript'
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep('x ', 50000) })
local original_context = words.context
words.context = function()
  error 'SQL must not inspect non-SQL completions'
end
local items = { { label = 'value' } }
assert(sql.completions({ bufnr = buf, cursor = { 1, 100000 } }, items) == items)
words.context = original_context
vim.bo.filetype = 'sql'
local line = "SELECT * FROM prod.events WHERE event = 'unknown"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
assert(#sql.completions({ bufnr = buf, line = line, cursor = { 1, #line } }, items) == 0, 'unsupported literals suppress schema vocabulary')
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
local text = string.rep('SELECT 1;\n', 10000) .. 'SELECT * FROM prod.events WHERE event'
local lines = vim.split(text, '\n')
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
local ctx = { bufnr = buf, line = lines[#lines], cursor = { #lines, #lines[#lines] } }
local started = vim.uv.hrtime()
sql.completions(ctx, items)
local elapsed = (vim.uv.hrtime() - started) / 1e6
assert(elapsed < 1000, 'completion must not regress to quadratic scanning: ' .. elapsed .. 'ms')
local a = words.context(ctx)
local b = words.context(ctx)
assert(a == b, 'unchanged buffers should share tokenization')
print(('PASS non-SQL bypass, literal context, dialects, validator cancellation, large-file guard, shared scan (%.1fms)'):format(elapsed))
vim.cmd 'qa!'
