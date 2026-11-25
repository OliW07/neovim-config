-- ClickHouse context and signatures use the catalogs cached by :SqlSchemaSync.
local M = {}
local keywords = vim.split(
  'SELECT DISTINCT FROM WHERE GROUP BY HAVING ORDER LIMIT OFFSET AS AND OR NOT IN IS NULL BETWEEN LIKE ILIKE JOIN LEFT RIGHT INNER OUTER FULL CROSS ON USING UNION ALL WITH CASE WHEN THEN ELSE END ASC DESC FINAL PREWHERE SETTINGS EXCEPT INTERSECT QUALIFY ARRAY SEMI ANTI ASOF ANY GLOBAL SAMPLE FORMAT FILL RECURSIVE',
  ' '
)

local catalog_path = vim.fn.stdpath 'data' .. '/sql-schema/functions.json'
local cached
function M.new()
  local stat = vim.uv.fs_stat(catalog_path)
  if not cached or cached.inode ~= (stat and stat.ino) then
    local ok, docs = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(catalog_path), '\n'))
    end)
    docs = ok and type(docs) == 'table' and docs or {}
    cached = setmetatable({ docs = docs, functions = vim.tbl_keys(docs), inode = stat and stat.ino }, { __index = M })
  end
  return cached
end

-- Token positions let us distinguish code from comments/strings and isolate
-- statements, even while the SQL is incomplete. Quoted identifiers stay tokens.
local function tokens(text)
  local result, i, depth = {}, 1, 0
  while i <= #text do
    local start, c, pair = i, text:sub(i, i), text:sub(i, i + 1)
    local value, kind
    if pair == '--' then
      i = text:find('\n', i, true) or (#text + 1)
      kind = 'comment'
    elseif pair == '/*' then
      local finish = text:find('*/', i + 2, true)
      i = finish and finish + 2 or (#text + 1)
      kind = 'comment'
    elseif c == "'" or c == '`' or c == '"' then
      i = i + 1
      while i <= #text do
        if text:sub(i, i) == '\\' then
          i = i + 2
        elseif text:sub(i, i + 1) == c .. c then
          i = i + 2
        elseif text:sub(i, i) == c then
          i = i + 1
          break
        else
          i = i + 1
        end
      end
      kind = c == "'" and 'string' or 'quoted'
      value = text:sub(start, i - 1)
    elseif c:match '[%w_]' then
      local _, finish = text:find('[%w_]+', i)
      value = text:sub(i, finish)
      i = finish + 1
      kind = 'word'
    else
      value = c
      i = i + 1
      kind = 'symbol'
    end
    if value == ')' then
      depth = math.max(0, depth - 1)
    end
    if not c:match '%s' then
      result[#result + 1] = { value = value or '', kind = kind, start = start, finish = i - 1, depth = depth }
    end
    if value == '(' then
      depth = depth + 1
    end
  end
  return result
end

-- Completion, value provenance and the LSP filter share one linear scan per edit.
local documents = {}
vim.api.nvim_create_autocmd('BufWipeout', {
  group = vim.api.nvim_create_augroup('sql-context-cache', { clear = true }),
  callback = function(event)
    documents[event.buf] = nil
  end,
})
function M.context(ctx)
  local buf = ctx.bufnr
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local doc = documents[buf]
  if not doc or doc.tick ~= tick then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local offsets, offset = {}, 0
    for i, line in ipairs(lines) do
      offsets[i] = offset
      offset = offset + #line + 1
    end
    local text = table.concat(lines, '\n')
    doc = { tick = tick, text = text, offsets = offsets, tokens = tokens(text) }
    documents[buf] = doc
  end
  local offset = (doc.offsets[ctx.cursor[1]] or 0) + ctx.cursor[2]
  local first, last = 1, #doc.tokens
  for n, token in ipairs(doc.tokens) do
    if token.kind == 'symbol' and token.value == ';' then
      if token.start <= offset then
        first = n + 1
      else
        last = n - 1
        break
      end
    end
  end
  return doc.tokens, offset, first, last, doc.text
end

function M.completion_name(name, kind)
  -- ClickHouse also accepts digit-leading identifiers that are not numbers.
  local compact = name:gsub('_', '')
  local digit_identifier = name:match '^%d[%w_]*$'
    and not tonumber(compact)
    and not compact:match '^0[bB][01]+$'
  if name:match '^[%a_][%w_]*$' or digit_identifier then
    return name
  end
  local parts = kind == vim.lsp.protocol.CompletionItemKind.Field and vim.split(name, '.', { plain = true }) or { name }
  for _, part in ipairs(parts) do
    if not part:match '^[%a_][%w_]*$' then
      return '`' .. name:gsub('`', '``') .. '`'
    end
  end
  return name
end

function M:items(ctx)
  if require('config.buffer').large(ctx.bufnr) then
    return {}, 'exclusive'
  end
  local all, offset, first, last = M.context(ctx)
  local before = ctx.line:sub(1, ctx.cursor[2])
  local prefix = before:match '[%w_]+$'
  local values = require('config.sql_values').items(ctx, all, offset)
  if values then
    return values, 'literal'
  end
  for n = first, last do
    local token = all[n]
    if token.start <= offset and token.finish >= offset and (token.kind == 'string' or token.kind == 'comment' or token.kind == 'quoted') then
      return {}, 'exclusive'
    end
  end
  local client = vim.lsp.get_clients({ bufnr = ctx.bufnr, name = 'sql_schema' })[1]
  local catalog = client and client._sql_schema and client._sql_schema.tables or {}
  local scope = require('config.sql_scope').inspect(all, first, last, offset, catalog)
  -- The schema server drops qualified expressions after a dot. Walk the local
  -- catalog one component at a time: database -> table -> column.
  local qualifier, partial = before:match '([%w_%.]+)%.([%w_]*)$'
  if qualifier then
    local lead = before:sub(1, #before - #qualifier - #partial - 1)
    local word = lead:match '(%a+)%s+$'
    local tables_only = word and (word:upper() == 'FROM' or word:upper() == 'JOIN')
    local result = {}
    local function add(name, kind, detail)
      if not name:lower():find(partial:lower(), 1, true) then
        return
      end
      local insert = M.completion_name(name, kind)
      result[#result + 1] = { label = name, insertText = insert, kind = kind, detail = detail }
    end
    for _, tbl in ipairs(catalog) do
      local db, name = tbl.name:match '^([%w_]+)%.([%w_]+)$'
      if db == qualifier then
        add(name, vim.lsp.protocol.CompletionItemKind.Class, tbl.name)
      elseif not tables_only and tbl.name == qualifier then
        for _, col in ipairs(tbl.columns) do
          add(col.name, vim.lsp.protocol.CompletionItemKind.Field, col.data_type)
        end
      end
    end
    if tables_only then
      return result, 'exclusive'
    end
    for name, kind in pairs(scope.relations[qualifier] or scope.ctes[qualifier] or {}) do
      add(name, vim.lsp.protocol.CompletionItemKind.Field, kind)
    end
    return result, 'exclusive'
  end
  -- Don't flood empty expression positions with the entire function catalog.
  prefix = prefix or ''
  local previous
  for n = first, last do
    local token = all[n]
    if token.finish <= offset - #prefix and token.kind ~= 'comment' then
      previous = token.value:upper()
    end
  end
  if previous == '.' or previous == 'AS' then
    return {}, 'exclusive'
  end
  local table_context = previous == 'FROM' or previous == 'JOIN'
  local items, seen = {}, {}
  local function add(name, kind, detail, insert_text)
    if not name:lower():find(prefix:lower(), 1, true) or seen[name] then
      return
    end
    seen[name] = true
    local insert = insert_text or M.completion_name(name, kind)
    items[#items + 1] = { label = name, insertText = insert, kind = kind, detail = detail }
  end
  local kinds = vim.lsp.protocol.CompletionItemKind
  if table_context then
    for name in pairs(scope.ctes) do
      add(name, kinds.Class, 'WITH query in this scope')
    end
    for _, tbl in ipairs(catalog) do
      add(tbl.name, kinds.Class, 'ClickHouse table', tbl.name)
    end
    return items, 'exclusive'
  end
  if prefix ~= '' then
    for _, word in ipairs(keywords) do
      add(word, kinds.Keyword, 'SQL keyword')
    end
    for _, name in ipairs(self.functions) do
      add(name, kinds.Function, 'ClickHouse function')
    end
  end
  for name in pairs(scope.scalars) do
    add(name, kinds.Variable, 'WITH expression in this scope')
  end
  for name in pairs(scope.aliases) do
    add(name, kinds.Variable, 'SELECT alias in this scope')
  end
  for _, columns in pairs(scope.relations) do
    for name, kind in pairs(columns) do
      add(name, kinds.Field, kind)
    end
  end
  return items, nil, scope.relations
end

function M:get_signature_help(ctx, callback)
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, ctx.cursor[1], false)
  lines[#lines] = lines[#lines]:sub(1, ctx.cursor[2])
  local text = table.concat(lines, '\n')
  local stack, previous, closed = {}, nil, nil
  for _, token in ipairs(tokens(text)) do
    if (token.kind == 'comment' or token.kind == 'string') and token.finish == #text then
      -- Completed literals still allow argument help, unfinished ones do not.
      if token.kind == 'comment' or token.value:sub(-1) ~= "'" then
        callback(nil)
        return
      end
    end
    if token.kind ~= 'comment' then
      local value = token.value
      if value == ';' then
        stack = {}
        closed = nil
      elseif value == '(' or value == '[' or value == '{' then
        local name = previous and previous.kind == 'word' and previous.value or nil
        local group = 1
        if value == '(' and previous and previous.value == ')' and closed then
          name, group = closed.name, closed.group + 1
        end
        stack[#stack + 1] = { name = value == '(' and name or nil, argument = 0, group = group }
        closed = nil
      elseif value == ')' or value == ']' or value == '}' then
        closed = table.remove(stack)
      elseif value == ',' and #stack > 0 then
        stack[#stack].argument = stack[#stack].argument + 1
      end
      previous = token
    end
  end
  for n = #stack, 1, -1 do
    local call = stack[n]
    local doc = call.name and self.docs[call.name]
    if doc and doc.syntax ~= '' then
      local groups = {}
      for args in doc.syntax:gmatch '%(([^()]*)%)' do
        groups[#groups + 1] = args
      end
      local parameters, active, index = {}, 0, 0
      for g, args in ipairs(groups) do
        local arg = 0
        for label in args:gmatch '[^,]+' do
          label = vim.trim(label:gsub('[%[%]]', ''))
          if label ~= '' then
            parameters[#parameters + 1] = { label = label }
            if g == call.group and arg == call.argument then
              active = index
            end
            index, arg = index + 1, arg + 1
          end
        end
      end
      callback {
        signatures = {
          { label = doc.syntax, parameters = parameters, documentation = { kind = 'markdown', value = doc.description .. '\n' .. doc.arguments } },
        },
        activeSignature = 0,
        activeParameter = active,
      }
      return
    end
  end
  callback(nil)
end

return M
