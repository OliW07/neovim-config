local M = {}
local data = vim.fn.stdpath 'data' .. '/sql-schema'
local script = vim.fn.stdpath 'config' .. '/scripts/sql-schema.py'

function M.dialect(buf)
  local path = vim.api.nvim_buf_get_name(buf):lower()
  for suffix, dialect in pairs {
    ['.postgres.sql'] = 'postgres',
    ['.pgsql'] = 'postgres',
    ['.mysql.sql'] = 'mysql',
    ['.mysql'] = 'mysql',
    ['.hive.sql'] = 'hive',
    ['.hql'] = 'hive',
    ['.redis.sql'] = 'redis',
    ['.redis'] = 'redis',
  } do
    if vim.endswith(path, suffix) then
      return dialect
    end
  end
  return 'clickhouse'
end

-- Stop at the nearest Git root (including worktrees), never inherit a different
-- repository's schema. Outside Git, use the nearest schema.sql directory.
function M.root(buf)
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
  return vim.fs.root(dir, '.git') or vim.fs.root(dir, 'schema.sql') or dir
end

function M.refresh(client)
  local path = client.config.root_dir .. '/schema.sql'
  client._schema_generation = (client._schema_generation or 0) + 1
  local generation = client._schema_generation
  local function publish(schema)
    if client:is_stopped() or generation ~= client._schema_generation then
      return
    end
    client._sql_schema = schema
    local files = vim.empty_dict()
    if schema then
      for buf in pairs(client.attached_buffers) do
        files[vim.uri_from_bufnr(buf)] = schema.id
      end
    end
    client:notify('workspace/didChangeConfiguration', {
      settings = { schemas = schema and { schema } or {}, fileSchemas = files },
    })
  end
  if vim.fn.filereadable(path) == 0 then
    publish(nil)
    return
  end
  vim.system({ data .. '/venv/bin/python', script, path }, { text = true, timeout = 10000 }, function(result)
    vim.schedule(function()
      if client:is_stopped() or generation ~= client._schema_generation then
        return
      end
      local ok, schema = pcall(vim.json.decode, result.stdout or '')
      if result.code ~= 0 or not ok then
        publish(nil)
        vim.notify(result.stderr ~= '' and result.stderr or 'Cannot parse ' .. path, vim.log.levels.ERROR)
        return
      end
      publish(schema)
    end)
  end)
end

function M.setup(capabilities)
  vim.lsp.config('sql_schema', {
    cmd = { data .. '/sql-lsp' },
    filetypes = { 'sql' },
    capabilities = capabilities,
    root_dir = function(buf, on_dir)
      if not require('config.buffer').large(buf) then
        on_dir(M.root(buf))
      end
    end,
    get_language_id = M.dialect,
    handlers = {
      ['textDocument/publishDiagnostics'] = function(err, result, ctx, config)
        -- Generic tree-sitter SQL rejects ClickHouse WITH expressions and FINAL.
        -- Syntax diagnostics come from the local ClickHouse SQLGlot parser instead.
        if result and M.dialect(vim.uri_to_bufnr(result.uri)) ~= 'redis' then
          result = vim.tbl_extend('force', result, { diagnostics = {} })
        end
        return vim.lsp.handlers['textDocument/publishDiagnostics'](err, result, ctx, config)
      end,
    },
    on_init = function(client)
      -- Request context-aware suggestions after FROM/WHERE and other SQL words.
      local completion = client.server_capabilities.completionProvider
      if completion then
        completion.triggerCharacters = completion.triggerCharacters or {}
        if not vim.tbl_contains(completion.triggerCharacters, ' ') then
          table.insert(completion.triggerCharacters, ' ')
        end
      end
      -- A metadata completion server must not format files on save.
      client.server_capabilities.documentFormattingProvider = false
      -- v0.1.3 advertises pull diagnostics but only implements push diagnostics.
      client.server_capabilities.diagnosticProvider = nil
      M.refresh(client)
    end,
    on_attach = function(client, buf)
      require('config.sql_diagnostics').attach(buf, client.config.root_dir)
      if client._sql_schema then
        client:notify('workspace/didChangeConfiguration', {
          settings = { fileSchemas = { [vim.uri_from_bufnr(buf)] = client._sql_schema.id } },
        })
      end
    end,
  })
  vim.lsp.enable 'sql_schema'
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = vim.api.nvim_create_augroup('sql-schema', { clear = true }),
    pattern = 'schema.sql',
    callback = function(event)
      local path = vim.fs.normalize(vim.api.nvim_buf_get_name(event.buf))
      for _, client in ipairs(vim.lsp.get_clients { name = 'sql_schema' }) do
        if path == client.config.root_dir .. '/schema.sql' then
          M.refresh(client)
        end
      end
    end,
  })
  vim.api.nvim_create_user_command('SqlSchemaReload', function()
    for _, client in ipairs(vim.lsp.get_clients { bufnr = 0, name = 'sql_schema' }) do
      M.refresh(client)
    end
  end, { desc = 'Reload the repository-root schema.sql' })
end

-- The server prefixes column display labels with its database name. The local
-- catalog uses fully qualified tables across databases, with no default database.
local function single_table_scope(ctx)
  if not (ctx.bufnr and ctx.cursor) then
    return
  end
  local all, _, first, last = require('config.sql_words').context(ctx)
  local code = {}
  local selects = 0
  for n = first, last do
    local token = all[n]
    if token.kind ~= 'comment' and token.kind ~= 'string' then
      local word = token.kind == 'word' and token.value:lower() or token.value
      if word == 'with' or word == 'join' then
        return
      end
      if word == 'select' then
        selects = selects + 1
      end
      code[#code + 1] = word
    end
  end
  if selects ~= 1 then
    return
  end
  for n, word in ipairs(code) do
    if word == 'from' and code[n + 2] == '.' and code[n + 3] then
      -- A comma-separated FROM list is not a single-table scope.
      for j = n + 4, #code do
        local next_word = code[j]
        if next_word == ',' then
          return
        end
        if
          next_word == 'where'
          or next_word == 'prewhere'
          or next_word == 'group'
          or next_word == 'order'
          or next_word == 'limit'
          or next_word == 'settings'
        then
          break
        end
      end
      return code[n + 1] .. '.' .. code[n + 3]
    end
  end
end

function M.completions(ctx, items)
  local buf = ctx.bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= 'sql' or M.dialect(buf) ~= 'clickhouse' or require('config.buffer').large(buf) then
    return items
  end
  -- Blink also transforms a single resolved item during acceptance. Preserve
  -- that choice instead of replacing it with the first catalog suggestion.
  if #items == 1 and items[1]._sql_catalog_completion then
    return items
  end
  -- The upstream parser can mistake FROM inside a CTE for a column context.
  -- Source names come directly from the catalog; sql_words supplies local CTEs.
  local source_prefix = require('config.sql_words').table_context(ctx)
  if source_prefix ~= nil then
    local client = vim.lsp.get_clients({ bufnr = ctx.bufnr, name = 'sql_schema' })[1]
    local matches = {}
    for _, tbl in ipairs(client and client._sql_schema and client._sql_schema.tables or {}) do
      if tbl.name:lower():find(source_prefix:lower(), 1, true) then
        local before = ctx.line:sub(1, ctx.cursor[2])
        matches[#matches + 1] = {
          label = tbl.name,
          insertText = tbl.name,
          filterText = tbl.name,
          detail = 'Table',
          kind = vim.lsp.protocol.CompletionItemKind.Class,
          _sql_catalog_completion = true,
          client_id = client.id,
          cursor_column = ctx.cursor[2],
          client_name = client.name,
          source_id = 'lsp',
          source_name = 'LSP',
          textEdit = {
            newText = tbl.name,
            range = {
              start = { line = ctx.cursor[1] - 1, character = vim.str_utfindex(before:sub(1, #before - #source_prefix), 'utf-16') },
              ['end'] = { line = ctx.cursor[1] - 1, character = vim.str_utfindex(before, 'utf-16') },
            },
          },
        }
      end
    end
    return matches
  end
  -- sql-lsp loses our fully qualified catalog names after a database dot.
  -- Complete that narrow FROM/JOIN context from the same loaded catalog.
  if ctx.line and ctx.cursor and ctx.bufnr then
    local before = ctx.line:sub(1, ctx.cursor[2])
    local keyword, database, prefix = before:match '(%a+)%s+([%w_]+)%.([%w_]*)$'
    local table_context = keyword and (keyword:upper() == 'FROM' or keyword:upper() == 'JOIN')
    -- system.columns.table and system.tables.name contain table-name strings,
    -- not column identifiers. Keep the surrounding quotes when completing.
    local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, ctx.cursor[1] - 1, false)
    table.insert(lines, before)
    local query = table.concat(lines, '\n')
    local field, value = before:match "([%w_]+)%s*=%s*'([%w_]*)$"
    local lower = query:lower()
    local catalog_value = field
      and (
        (field:lower() == 'table' and lower:match '%f[%a]from%s+system%.columns%f[%W]')
        or (field:lower() == 'name' and lower:match '%f[%a]from%s+system%.tables%f[%W]')
      )
    if catalog_value then
      database = lower:match "%f[%a]database%s*=%s*'([%w_]+)'"
      prefix = value
      table_context = true
    end
    if table_context then
      local client = vim.lsp.get_clients({ bufnr = ctx.bufnr, name = 'sql_schema' })[1]
      if client and client._sql_schema then
        local matches = {}
        for _, tbl in ipairs(client._sql_schema.tables) do
          local db, name = tbl.name:match '^([%w_]+)%.([%w_]+)$'
          if db and (not database or db == database) and name:lower():find(prefix:lower(), 1, true) then
            table.insert(matches, {
              label = name,
              _sql_catalog_completion = true,
              detail = tbl.name,
              filterText = name,
              insertText = name,
              kind = vim.lsp.protocol.CompletionItemKind.Class,
              client_id = client.id,
              cursor_column = ctx.cursor[2],
              client_name = client.name,
              source_id = 'lsp',
              source_name = 'LSP',
              textEdit = {
                newText = name,
                range = {
                  start = { line = ctx.cursor[1] - 1, character = vim.str_utfindex(before:sub(1, #before - #prefix), 'utf-16') },
                  ['end'] = { line = ctx.cursor[1] - 1, character = vim.str_utfindex(before, 'utf-16') },
                },
              },
            })
          end
        end
        return matches
      end
    end
  end
  -- Catalog literals above have their own table suggestions. All other
  -- strings belong to the value provider, even when it has no cached values.
  if require('config.sql_words').value_items(ctx) ~= nil then
    return {}
  end
  local scope = single_table_scope(ctx)
  local filtered = {}
  for _, item in ipairs(items) do
    local client = item.client_id and vim.lsp.get_client_by_id(item.client_id)
    local keep = true
    if client and client.name == 'sql_schema' then
      item.label = item.label:gsub('^%.', '')
      if item.kind == vim.lsp.protocol.CompletionItemKind.Field then
        if scope then
          keep = item.label:lower():sub(1, #scope + 1) == scope .. '.'
        end
        -- Blink transforms the item again on acceptance. Start from the original name.
        local name = item._sql_column_name or item.insertText
        if name and not name:match '^[%a_][%w_]*$' then
          item._sql_column_name = name
          item.insertText = require('config.sql_words').completion_name(name, item.kind)
        end
      end
    end
    if keep then
      table.insert(filtered, item)
    end
  end
  return filtered
end

return M
