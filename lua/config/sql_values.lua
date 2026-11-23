-- Project-local observed values. No credentials or network calls while typing.
local M = {}
local cache = {}

local function catalog(buf)
  local root = require('config.sql').root(buf)
  if not root then
    return
  end
  local path = root .. '/sql-values.json'
  local stat = vim.uv.fs_stat(path)
  if not stat then
    cache[path] = nil
    return
  end
  local stamp = stat.mtime.sec .. ':' .. stat.mtime.nsec .. ':' .. stat.size
  if not cache[path] or cache[path].stamp ~= stamp then
    local ok, data = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
    end)
    cache[path] = { stamp = stamp, data = ok and type(data) == 'table' and data or {} }
  end
  return cache[path].data
end

function M.items(ctx, all, offset)
  local first, last, current = 1, #all, nil
  for n, t in ipairs(all) do
    if t.value == ';' and t.kind == 'symbol' then
      if t.start <= offset then
        first = n + 1
      else
        last = n - 1
        break
      end
    end
    if t.kind == 'string' and offset >= t.start and offset <= t.finish then
      current = n
    end
  end
  if not current then
    return
  end
  -- Return an empty list in unsupported string contexts; never leak vocabulary.
  local ts = {}
  for n = first, last do
    if all[n].kind ~= 'comment' then
      ts[#ts + 1] = all[n]
      if n == current then
        current = -#ts
      end
    end
  end
  current = -current
  if current < 1 then
    return {}
  end
  local literal = ts[current]
  local prefix = literal.value:sub(2, offset - literal.start + 1)
  if prefix:find "['\\\n]" then
    return {}
  end
  local function word(n)
    return ts[n] and ts[n].value:lower() or ''
  end
  local function identifier(n)
    local token = ts[n]
    if not token then
      return
    end
    if token.kind == 'word' then
      return token.value
    end
    if token.kind == 'quoted' then
      return token.value:sub(2, -2)
    end
  end
  local field_index
  if word(current - 1) == '=' then
    field_index = current - 2
    if word(field_index) == '!' or word(field_index) == '<' or word(field_index) == '>' then
      field_index = field_index - 1
    end
  elseif word(current - 1) == '>' and word(current - 2) == '<' then
    field_index = current - 3
  else
    local n = current - 1
    while n > 0 and (ts[n].kind == 'string' or word(n) == ',') do
      n = n - 1
    end
    if word(n) == '(' and word(n - 1) == 'in' then
      field_index = n - 2
      if word(field_index) == 'not' then
        field_index = field_index - 1
      end
    end
  end
  if not field_index or not identifier(field_index) then
    return {}
  end
  local field = identifier(field_index)
  local qualifier = word(field_index - 1) == '.' and identifier(field_index - 2) or nil
  local clause
  for n = 1, field_index - 1 do
    if ts[n].kind == 'word' and ts[n].depth == ts[field_index].depth then
      local w = word(n)
      if w == 'where' or w == 'prewhere' or w == 'select' or w == 'from' or w == 'having' then
        clause = w
      end
    end
  end
  if clause ~= 'where' and clause ~= 'prewhere' then
    return {}
  end
  local data = catalog(ctx.bufnr)
  if not data or type(data.tables) ~= 'table' then
    return {}
  end
  -- Resolve value provenance through the same CTE/table-alias scope as columns.
  -- Only direct projections preserve provenance; computed expressions do not.
  local schemas, origins = {}, {}
  for table_name, fields in pairs(data.tables) do
    local columns = {}
    for name, values in pairs(fields) do
      local key = table_name .. '.' .. name
      columns[#columns + 1] = { name = name, data_type = key }
      origins[key] = { table_name = table_name, field = name, values = values }
    end
    schemas[#schemas + 1] = { name = table_name, columns = columns }
  end
  local scope = require('config.sql_scope').inspect(all, first, last, offset, schemas)
  local origin
  if qualifier then
    origin = origins[(scope.relations[qualifier] or {})[field]]
  else
    local seen, count = {}, 0
    for _, columns in pairs(scope.relations) do
      if not seen[columns] then
        seen[columns] = true
        count = count + 1
        origin = origins[columns[field]] or origin
      end
    end
    if count ~= 1 then
      return {}
    end
  end
  if not origin or type(origin.values) ~= 'table' then
    return {}
  end
  local table_name, values = origin.table_name, origin.values
  field = origin.field
  -- Replace the whole literal content, preserving its existing quotes and suffix.
  local closed = #literal.value > 1 and literal.value:sub(-1) == "'"
  local content = literal.value:sub(2, closed and -2 or -1)
  if content:find "['\\\n]" then
    return {}
  end
  local start_col = ctx.cursor[2] - #prefix
  local result = {}
  for _, value in ipairs(values) do
    if type(value) == 'string' and value:lower():find(prefix:lower(), 1, true) then
      result[#result + 1] = {
        label = value,
        filterText = value,
        kind = vim.lsp.protocol.CompletionItemKind.Value,
        detail = table_name .. '.' .. field .. ' (observed sample)',
        documentation = { kind = 'plaintext', value = 'Observed values: ' .. (data.window or 'unspecified window') .. '. This list is not exhaustive.' },
        textEdit = {
          newText = value:gsub('\\', '\\\\'):gsub("'", "\\'"),
          range = {
            start = { line = ctx.cursor[1] - 1, character = start_col },
            ['end'] = { line = ctx.cursor[1] - 1, character = start_col + #content },
          },
        },
      }
    end
  end
  return result
end

return M
