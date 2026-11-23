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

local function cloud_cache(client)
  return vim.fn.stdpath 'cache' .. '/lumin-sql/' .. vim.fn.sha256(client.config.root_dir) .. '.json'
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
  local cache = cloud_cache(client)
  if vim.fn.filereadable(cache) == 1 then
    local ok, schema = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(cache), '\n'))
    end)
    if ok and type(schema) == 'table' and type(schema.tables) == 'table' and schema.id then
      publish(schema)
      return
    end
    vim.notify('Invalid Cloud catalog. Run :SqlSchemaSync to refresh it.', vim.log.levels.WARN)
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
    cmd = require('config.sql_completion').start,
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
        for _, ch in ipairs { ' ', '.', "'" } do
          if not vim.tbl_contains(completion.triggerCharacters, ch) then
            table.insert(completion.triggerCharacters, ch)
          end
        end
      end
      client.server_capabilities.signatureHelpProvider = { triggerCharacters = { '(', ',' }, retriggerCharacters = { ')' } }
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
  vim.api.nvim_create_user_command('SqlSchemaSync', function()
    local client = vim.lsp.get_clients({ bufnr = 0, name = 'sql_schema' })[1]
    if not client or M.dialect(0) ~= 'clickhouse' then
      vim.notify('Open a ClickHouse SQL buffer with the SQL LSP attached', vim.log.levels.WARN)
      return
    end
    if client._cloud_syncing then
      return
    end
    client._cloud_syncing = true
    vim.system(
      { 'python3', vim.fn.stdpath 'config' .. '/scripts/sql-cloud-schema.py', cloud_cache(client), data .. '/functions.json' },
      { text = true },
      vim.schedule_wrap(function(result)
        client._cloud_syncing = nil
        if result.code ~= 0 then
          vim.notify(vim.trim(result.stderr), vim.log.levels.ERROR)
          return
        end
        if not client:is_stopped() then
          M.refresh(client)
        end
        vim.notify(vim.trim(result.stdout))
      end)
    )
  end, { desc = 'Sync Lumin ClickHouse metadata for this repository' })
  vim.api.nvim_create_user_command('SqlSchemaReload', function()
    for _, client in ipairs(vim.lsp.get_clients { bufnr = 0, name = 'sql_schema' }) do
      M.refresh(client)
    end
  end, { desc = 'Reload the repository SQL catalog' })
end

return M
