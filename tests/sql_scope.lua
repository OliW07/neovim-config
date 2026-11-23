local source = require('config.sql_words').new()
local original = vim.lsp.get_clients
vim.lsp.get_clients = function()
  return {
    {
      _sql_schema = {
        tables = { { name = 'prod.events', columns = { { name = 'user_id', data_type = 'String' }, { name = 'timestamp', data_type = 'DateTime' } } } },
      },
    },
  }
end
local function items(query)
  local cursor = assert(query:find('|', 1, true))
  local before = query:sub(1, cursor - 1)
  query = before .. query:sub(cursor + 1)
  local lines = vim.split(query, '\n')
  local head = vim.split(before, '\n')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  return source:items { bufnr = vim.api.nvim_get_current_buf(), line = lines[#head], cursor = { #head, #head[#head] } }
end
local function has(query, label, expected)
  local result = items(query)
  local found = false
  for _, v in ipairs(result) do
    if v.label == label then
      found = true
    end
  end
  assert(found == (expected ~= false), query .. '\n' .. vim.inspect(result))
end
has('WITH signups AS (SELECT user_id FROM prod.events) SELECT * FROM sig|', 'signups')
has('WITH signups AS (SELECT user_id FROM prod.events) SELECT * FROM |', 'signups')
has('WITH signups AS (SELECT user_id FROM prod.events) SELECT * FROM prod.events JOIN sig|', 'signups')
has('WITH signups AS (SELECT user_id, min(timestamp) AS signed_up_at FROM prod.events GROUP BY user_id) SELECT s.sig| FROM signups AS s', 'signed_up_at')
has('WITH signups AS (SELECT user_id FROM prod.events) SELECT signups.| FROM signups', 'user_id')
has('WITH signups AS (SELECT user_id FROM prod.events) SELECT user_| FROM signups', 'user_id')
has('WITH signups AS (SELECT user_id FROM prod.events), later AS (SELECT * FROM signups) SELECT later.| FROM later', 'user_id')
has('WITH signups AS (SELECT * FROM prod.events) SELECT signups.| FROM signups', 'timestamp')
has('SELECT e.| FROM prod.events e', 'timestamp')
has('WITH 24 AS hours, signups AS (SELECT user_id FROM prod.events WHERE timestamp > hou|) SELECT * FROM signups', 'hours')
has('WITH signups AS (SELECT user_id FROM prod.events), later AS (SELECT * FROM sig|) SELECT * FROM later', 'signups')
has('WITH signups AS (SELECT user_id FROM prod.events) SELECT * FROM (WITH inner_query AS (SELECT 1 AS x) SELECT * FROM inn|)', 'inner_query')
has('SELECT * FROM (WITH inner_query AS (SELECT 1 AS x) SELECT * FROM inner_query) JOIN inn|', 'inner_query', false)
has('WITH signups AS (SELECT 1 AS x) SELECT * FROM signups; SELECT * FROM sig|', 'signups', false)
has("WITH signups AS (SELECT 1 AS x) SELECT 'sig|'", 'signups', false)
has('WITH signups AS (SELECT 1 AS x) SELECT 1 -- sig|', 'signups', false)
has('WITH signups AS (SELECT 1 AS x) SELECT * FROM sig|', 'x', false)
has('WITH signups AS (SELECT 1 AS x) SELECT * FROM signups WHERE unrelated.|', 'x', false)
has('WITH signups AS (SELECT 1 AS x) SELECT signups.| FROM (WITH signups AS (SELECT 2 AS y) SELECT * FROM signups)', 'y', false)
has('SELECT * FROM prod.events QUA|', 'QUALIFY')
has('WITH 2 AS `day count` SELECT day|', 'day count')
has('WITH signups AS (\nSELECT user_id FROM prod.events\n)\nSELECT s.us| FROM signups s', 'user_id')
vim.lsp.get_clients = original
print 'PASS CTE names, output columns, chained queries, stars, aliases, nested scope, statement isolation, ClickHouse keywords'
vim.cmd 'qa!'
