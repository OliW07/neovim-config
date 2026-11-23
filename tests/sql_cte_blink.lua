local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
vim.fn.writefile(
  { 'CREATE TABLE prod.stg_pinpoint_events (lumin_user_id String, timestamp DateTime) ENGINE = MergeTree ORDER BY timestamp;' },
  root .. '/schema.sql'
)
vim.cmd('edit ' .. root .. '/query.sql')
assert(vim.wait(5000, function()
  local c = vim.lsp.get_clients({ bufnr = 0, name = 'sql_schema' })[1]
  return c and c._sql_schema
end, 20))
local text = [[WITH '2026-10-01' AS filter_date_start,
     '2026-10-04' AS filter_date_end,
customers AS (
 SELECT _id, created_date FROM prod.stg_mongo_users
 WHERE created_date >= filter_date_start AND created_date < filter_date_end
),
returning_customers_day_two AS (
 SELECT e.lumin_user_id, e.timestamp
 FROM prod.stg_pinpoint_events AS e
 INNER JOIN customers AS c ON e.lumin_user_id = c._id
 WHERE e.timestamp >= filter_date_start AND e.timestamp < filter_date_end
 AND e.timestamp >= c.created_date + INTERVAL 24 HOUR
 AND e.timestamp < c.created_date + INTERVAL 48 HOUR
),
churned_customer_day_two AS (
 SELECT c._id
 FROM customers AS c
 LEFT ANTI JOIN returning_customers_day_two AS r
 ON c._id = r.lumin_user|
)]]

local offset = text:find('|', 1, true)
local head = vim.split(text:sub(1, offset - 1), '\n')
local lines = vim.split(text:gsub('|', ''), '\n')
local row = #head
lines[row] = lines[row]:sub(1, -2)
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_win_set_cursor(0, { row, #lines[row] })
local cmp = require 'blink.cmp'
vim.cmd 'startinsert!'
vim.defer_fn(function()
  vim.api.nvim_input 'r'
end, 100)
vim.defer_fn(function()
  local ok, err = pcall(function()
    assert(cmp.is_visible(), 'popup missing')
    local found = false
    for _, item in ipairs(cmp.get_items()) do
      if item.label == 'lumin_user_id' then
        found = true
      end
    end
    assert(found, 'CTE field missing: ' .. vim.inspect(cmp.get_items()))
    assert(cmp.get_selected_item().label == 'lumin_user_id', 'CTE field should be selected')
  end)
  if not ok then
    print(err)
    vim.cmd 'cquit 1'
  end
  vim.api.nvim_input(vim.api.nvim_replace_termcodes('<C-y>', true, false, true))
end, 700)
vim.defer_fn(function()
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  if line ~= ' ON c._id = r.lumin_user_id' then
    print('bad acceptance: ' .. line)
    vim.cmd 'cquit 1'
  end
  vim.fn.delete(root, 'rf')
  print 'PASS multiline CTE JOIN field popup and Ctrl-Y'
  vim.cmd 'qa!'
end, 1000)
