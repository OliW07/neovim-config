local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/.git', 'p')
vim.fn.writefile({
  'CREATE TABLE prod.payments (amount Int64) ENGINE = MergeTree ORDER BY amount;',
  'CREATE TABLE analytics.events (type String, `string_properties.name` Array(String)) ENGINE = MergeTree ORDER BY type;',
}, root .. '/schema.sql')
vim.fn.writefile({ vim.json.encode { tables = { ['prod.payments'] = { status = { 'accountCreated' } } } } }, root .. '/sql-values.json')
vim.cmd('edit ' .. root .. '/query.sql')
assert(vim.wait(5000, function()
  local c = vim.lsp.get_clients({ bufnr = 0, name = 'sql_schema' })[1]
  return c and c._sql_schema
end, 20))
local cmp = require 'blink.cmp'
local cases = {
  { "SELECT * FROM system.columns WHERE table = 'ymen", 't', 'payments', "SELECT * FROM system.columns WHERE table = 'payments" },
  { 'SELECT type, string_propertie', 's', 'analytics.events.string_properties.name', 'SELECT type, string_properties.name' },
  { "SELECT * FROM system.tables WHERE name = 'YMEN", 'T', 'payments', "SELECT * FROM system.tables WHERE name = 'payments" },
  { 'SELECT * FROM prod.ymen', 't', 'payments', 'SELECT * FROM prod.payments' },
  { 'SELECT * FROM ymen', 't', 'prod.payments', 'SELECT * FROM prod.payments' },
  { 'SELECT * FROM prod.payments p WHERE p.moun', 't', 'amount', 'SELECT * FROM prod.payments p WHERE p.amount' },
  { "SELECT * FROM prod.payments WHERE status = 'Creat", 'e', 'accountCreated', "SELECT * FROM prod.payments WHERE status = 'accountCreated" },
  { 'WITH 1 AS local_value SELECT cal_valu', 'e', 'local_value', 'WITH 1 AS local_value SELECT local_value' },
  {
    'WITH users AS (SELECT amount FROM prod.payments), returning AS (SELECT p.amount FROM pay',
    'm',
    'prod.payments',
    'WITH users AS (SELECT amount FROM prod.payments), returning AS (SELECT p.amount FROM prod.payments',
  },
  {
    'WITH users AS (SELECT * FROM prod.payments) SELECT * FROM prod.payments WHERE status = ',
    "'",
    'accountCreated',
    "WITH users AS (SELECT * FROM prod.payments) SELECT * FROM prod.payments WHERE status = 'accountCreated'",
  },
  {
    'WITH users AS (SELECT status FROM prod.payments) SELECT * FROM users WHERE status = ',
    "'",
    'accountCreated',
    "WITH users AS (SELECT status FROM prod.payments) SELECT * FROM users WHERE status = 'accountCreated'",
  },
  {
    'WITH signups AS (SELECT amount FROM prod.payments) SELECT * FROM sig',
    'n',
    'signups',
    'WITH signups AS (SELECT amount FROM prod.payments) SELECT * FROM signups',
  },
  {
    'WITH 30_day_curve AS (SELECT amount FROM prod.payments) SELECT * FROM 30_day_curv',
    'e',
    '30_day_curve',
    'WITH 30_day_curve AS (SELECT amount FROM prod.payments) SELECT * FROM 30_day_curve',
  },
  {
    'WITH signups AS (SELECT amount AS signed_up_at FROM prod.payments) SELECT * FROM signups s WHERE s',
    '.',
    'signed_up_at',
    'WITH signups AS (SELECT amount AS signed_up_at FROM prod.payments) SELECT * FROM signups s WHERE s.signed_up_at',
  },
  { 'SELECT * FROM prod.payments p WHERE p', '.', 'amount', 'SELECT * FROM prod.payments p WHERE p.amount' },
  { 'SELECT * FROM prod.payments WHERE status = ', "'", 'accountCreated', "SELECT * FROM prod.payments WHERE status = 'accountCreated'" },
  { "SELECT * FROM prod.payments WHERE status = 'ac", 'c', 'accountCreated', "SELECT * FROM prod.payments WHERE status = 'accountCreated" },
  { "SELECT * FROM prod.payments p WHERE p.status IN ('x', ", "'", 'accountCreated', "SELECT * FROM prod.payments p WHERE p.status IN ('x', 'accountCreated'" },
  { 'WITH 1 AS local_value SELECT local_v', 'a', 'local_value' },
  { 'SELECT prod', '.', 'payments', 'SELECT prod.payments' },
  { 'SELECT prod.payments', '.', 'amount', 'SELECT prod.payments.amount' },
  { 'SELECT prod.payments.a', 'm', 'amount', 'SELECT prod.payments.amount' },
  { 'SELECT * FROM prod', '.', 'payments', 'SELECT * FROM prod.payments' },
  { 'SELECT * FROM prod.payments W', 'H', 'WHERE' },
  { 'SELECT toDecimalStr', 'i', 'toDecimalString' },
  { 'SELECT sum(amount) AS total_paid FROM prod.payments ORDER BY total_p', 'a', 'total_paid' },
  {
    'SELECT * FROM analytics.events e WHERE e.string_propertie',
    's',
    'string_properties.name',
    'SELECT * FROM analytics.events e WHERE e.string_properties.name',
  },
}
local function key(s)
  vim.api.nvim_input(vim.api.nvim_replace_termcodes(s, true, false, true))
end
local function later(ms, fn)
  vim.defer_fn(function()
    local ok, err = pcall(fn)
    if not ok then
      print(err)
      vim.cmd 'cquit 1'
    end
  end, ms)
end
local function run(n)
  if not cases[n] then
    vim.fn.delete(root, 'rf')
    print 'PASS Blink popup and Ctrl-Y: qualified tables/columns, WHERE, functions, aliases'
    vim.cmd 'qa!'
    return
  end
  local case = cases[n]
  cmp.hide()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { case[1] })
  vim.api.nvim_win_set_cursor(0, { 1, #case[1] })
  vim.cmd 'startinsert!'
  later(100, function()
    key(case[2])
  end)
  later(650, function()
    assert(cmp.is_visible(), 'no popup for ' .. case[3])
    local found = false
    for _, item in ipairs(cmp.get_items()) do
      if item.label == case[3] and item.source_id == 'lsp' then
        found = true
      end
    end
    assert(found, 'missing ' .. case[3])
    if n == 1 then
      for _, item in ipairs(cmp.get_items()) do
        assert(item.kind ~= 5, 'column leaked into FROM menu')
      end
    end
    assert(cmp.get_selected_item().label == case[3], 'unexpected first item: ' .. cmp.get_selected_item().label)
    key '<C-y>'
  end)
  later(900, function()
    assert(
      vim.api.nvim_get_current_line() == (case[4] or case[1]:gsub('[%w_]+$', '') .. case[3]),
      'acceptance changed query incorrectly: ' .. vim.api.nvim_get_current_line()
    )
    key '<Esc>'
    later(100, function()
      run(n + 1)
    end)
  end)
end
run(1)
