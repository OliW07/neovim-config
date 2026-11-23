local source = require('config.sql_words').new()
local function items(text, suffix)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { text .. (suffix or '') })
  return source:items { bufnr = vim.api.nvim_get_current_buf(), line = text, cursor = { 1, #text } }
end
local function has(list, name)
  for _, item in ipairs(list) do
    if item.label == name then
      return true
    end
  end
  return false
end
assert(has(items 'SELECT * FROM prod.payments WH', 'WHERE'))
assert(has(items 'SELECT toDec', 'toDecimalString'))
assert(has(items 'SELECT sum(amount) AS total_paid FROM prod.payments ORDER BY total_', 'total_paid'))
assert(has(items('SELECT total_', ', sum(amount) AS total_paid FROM prod.payments'), 'total_paid'))
assert(not has(items 'SELECT 1 AS old_alias; SELECT old_', 'old_alias'))
assert(not has(items 'SELECT (SELECT 1 AS inner_alias) FROM prod.payments ORDER BY inner_', 'inner_alias'))
assert(#items "SELECT 'toDec" == 0)
assert(#items 'SELECT 1 -- toDec' == 0)
assert(#items 'SELECT /* toDec' == 0)
assert(#items 'SELECT * FROM prod.toDec' == 0)
assert(#items 'SELECT * FROM toDec' == 0)
assert(#items 'SELECT 1 AS toDec' == 0)
assert(has(items 'WITH 1 AS local_value SELECT local_', 'local_value'))
assert(has(items('WITH sum(amount) AS total_paid SELECT total_', ' FROM prod.payments'), 'total_paid'))
assert(not has(items 'WITH 1 AS old_alias SELECT old_alias; SELECT old_', 'old_alias'))
assert(not has(items 'SELECT (WITH 1 AS inner_alias SELECT inner_alias) ORDER BY inner_', 'inner_alias'))
local function signature(text)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
  local result
  source:get_signature_help({ bufnr = 0, cursor = { 1, #text } }, function(value)
    result = value
  end)
  return result
end
assert(signature('SELECT toDecimalString(').signatures[1].label == 'toDecimalString(number, scale)')
assert(signature('SELECT toDecimalString(round(x, 2), ').activeParameter == 1)
assert(signature('SELECT round(').signatures[1].label == 'round(x[, N])')
assert(signature('SELECT round(x, ').activeParameter == 1)
assert(signature("SELECT substring('a,b', ").activeParameter == 1)
assert(signature('SELECT quantile(0.9)(').activeParameter == 1)
assert(signature('SELECT arrayElement([1,2], ').activeParameter == 1)
assert(signature 'SELECT round(x); ' == nil)
assert(signature 'SELECT -- round(' == nil)
assert(signature "SELECT 'round(" == nil)
print 'PASS SQL vocabulary, alias scope, literal/comment/table exclusions'
vim.cmd 'qa!'
