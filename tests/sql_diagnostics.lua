vim.opt.rtp:prepend(vim.fn.getcwd())
local validator = require 'config.sql_diagnostics'
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
local function check(text, expected)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  validator.check(buf)
  assert(
    vim.wait(5000, function()
      return #vim.diagnostic.get(buf, { namespace = validator.namespace }) == expected
    end, 20),
    'unexpected diagnostics for ' .. text
  )
end
check('SELECT (1 + )', 1)
check(
  'WITH (total_charged - total_refunded) AS total_paid, sum(amount_refunded) AS total_refunded, sum(amount) AS total_charged SELECT customer, count() AS charge_count, toDecimalString(round(total_paid / 100, 2), 2) AS total_paid_usd FROM prod.stg_stripe_charges FINAL WHERE paid = 1 GROUP BY customer ORDER BY total_paid DESC LIMIT 10',
  0
)
check("SELECT 'unterminated", 1)
check('SELECT 1;', 0)
-- An obsolete parser response must not overwrite diagnostics for a newer edit.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'SELECT (1 + )' })
validator.check(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'SELECT 1' })
validator.check(buf)
vim.wait(600, function()
  return false
end, 20)
assert(#vim.diagnostic.get(buf, { namespace = validator.namespace }) == 0)
print 'ClickHouse diagnostics: valid dialect, invalid expression, token error, clearing, stale results OK'
vim.cmd 'qa!'
