local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
vim.fn.writefile({ '' }, root .. '/schema.sql')
vim.fn.writefile({ vim.json.encode { tables = { ['prod.events'] = { type = { 'accountCreated', 'pdfOpen' } } } } }, root .. '/sql-values.json')
vim.cmd('edit ' .. root .. '/query.sql')
local source = require('config.sql_words').new()
local function items(before, after)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(before .. (after or ''), '\n'))
  local lines = vim.split(before, '\n')
  return source:items { bufnr = vim.api.nvim_get_current_buf(), line = lines[#lines], cursor = { #lines, #lines[#lines] } }
end
local function expect(before, after, name)
  local result = items(before, after)
  assert(#result == 1 and result[1].label == (name or 'accountCreated'), vim.inspect(result) .. ' for ' .. before)
  local edit = result[1].textEdit
  local line = vim.api.nvim_buf_get_lines(0, edit.range.start.line, edit.range.start.line + 1, false)[1]
  local replaced = line:sub(1, edit.range.start.character) .. edit.newText .. line:sub(edit.range['end'].character + 1)
  assert(replaced:find(name or 'accountCreated', 1, true), replaced)
  return replaced
end
assert(expect("SELECT * FROM prod.events WHERE type = 'acc", "ountWrong' AND 1=1") == "SELECT * FROM prod.events WHERE type = 'accountCreated' AND 1=1")
expect "SELECT * FROM prod.events e WHERE e.type = 'acc"
expect "SELECT * FROM prod.events E WHERE E.type = 'acc"
expect "SELECT * FROM prod.events E WHERE E.`type` = 'acc"
expect("SELECT * FROM prod.events AS e WHERE e.type IN ('pdfOpen', 'acc", "')")
expect("SELECT * FROM prod.events PREWHERE type NOT IN ('acc", "')")
expect "SELECT * FROM prod.events WHERE type != 'acc"
expect "SELECT * FROM prod.events WHERE type <> 'acc"
expect "SELECT * FROM prod.events\nWHERE type = 'acc"
expect "SELECT 1; SELECT * FROM prod.events WHERE type = 'acc"
assert(#items "SELECT * FROM prod.events WHERE type = '" == 2)
for _, sql in ipairs {
  "SELECT * FROM other.events WHERE type = 'acc",
  "SELECT * FROM prod.events WHERE unknown = 'acc",
  "SELECT * FROM prod.events WHERE x.type = 'acc",
  "SELECT * FROM prod.events -- WHERE type = 'acc",
  "SELECT * FROM prod.events /* WHERE type = 'acc",
  "SELECT * FROM prod.events JOIN prod.other USING (id) WHERE type = 'acc",
  "SELECT * FROM prod.events, prod.other WHERE type = 'acc",
  "SELECT type = 'acc",
} do
  assert(#items(sql) == 0, sql)
end
expect "WITH x AS (SELECT * FROM prod.events) SELECT * FROM x WHERE type = 'acc"
expect "WITH x AS (SELECT type AS event_type FROM prod.events) SELECT * FROM x WHERE event_type = 'acc"
expect("WITH x AS (SELECT type FROM prod.events WHERE type = 'acc", "') SELECT * FROM x")
expect "WITH x AS (SELECT type FROM prod.events) SELECT * FROM prod.events WHERE type = 'acc"
expect "SELECT * FROM prod.events WHERE id IN (SELECT id FROM prod.events WHERE type = 'acc"
assert(#items "WITH x AS (SELECT lower(type) AS type FROM prod.events) SELECT * FROM x WHERE type = 'acc" == 0)
vim.fn.writefile({ '{bad json' }, root .. '/sql-values.json')
assert(#items "SELECT * FROM prod.events WHERE type = 'acc" == 0)
vim.fn.delete(root, 'rf')
print 'PASS value completion: aliases, IN, quotes, multiline, scope isolation, malformed cache'
vim.cmd 'qa!'
