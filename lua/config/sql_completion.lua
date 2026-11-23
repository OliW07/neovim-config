-- Extend the offline server's LSP responses for ClickHouse. All completion UIs
-- use the same protocol response, including Neovim's built-in LSP completion.
local M = {}

local function context(params)
  local uri = params.textDocument.uri
  local buf = uri == vim.uri_from_bufnr(0) and vim.api.nvim_get_current_buf() or vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(buf) or require('config.sql').dialect(buf) ~= 'clickhouse' or require('config.buffer').large(buf) then
    return
  end
  local client = vim.lsp.get_clients({ bufnr = buf, name = 'sql_schema' })[1]
  if not client then
    return
  end
  local row = params.position.line
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  if not line then
    return
  end
  return {
    bufnr = buf,
    line = line,
    cursor = { row + 1, vim.str_byteindex(line, client.offset_encoding, params.position.character, false) },
    encoding = client.offset_encoding,
  }
end

local function complete(words, ctx, upstream)
  local extra, mode, relations = words:items(ctx)
  local before = ctx.line:sub(1, ctx.cursor[2])
  local catalog = before:match "(%w+)%s*=%s*'([%w_]*)$"
  if catalog and mode == 'literal' then
    catalog = catalog:lower()
    local tokens, offset, first, _, text = words.context(ctx)
    local sql = text:sub(tokens[first].start, offset):lower()
    if (catalog == 'table' and sql:match 'from%s+system%.columns') or (catalog == 'name' and sql:match 'from%s+system%.tables') then
      local client = vim.lsp.get_clients({ bufnr = ctx.bufnr, name = 'sql_schema' })[1]
      local db = sql:match "database%s*=%s*'([%w_]+)'"
      for _, tbl in ipairs(client and client._sql_schema and client._sql_schema.tables or {}) do
        local database, name = tbl.name:match '^([%w_]+)%.([%w_]+)$'
        if name and (not db or db == database) then
          extra[#extra + 1] = { label = name, kind = 7 }
        end
      end
    end
  end
  local seen = {}
  for _, item in ipairs(extra) do
    seen[item.label] = true
    if item.textEdit then
      for _, pos in pairs(item.textEdit.range) do
        pos.character = vim.str_utfindex(ctx.line, ctx.encoding, pos.character, false)
      end
    end
  end
  if not mode then
    for _, item in ipairs(upstream.items or upstream) do
      item.label = item.label:gsub('^%.', '')
      if item.kind == 5 and item.insertText then
        item.insertText = words.completion_name(item.insertText, item.kind)
      end
      local keep = true
      if item.kind == 5 and relations and next(relations) then
        keep = false
        for relation in pairs(relations) do
          if vim.startswith(item.label, relation .. '.') then
            keep = true
            break
          end
        end
      end
      if keep and not seen[item.label] then
        extra[#extra + 1] = item
      end
    end
  end
  return { isIncomplete = true, items = extra }
end

function M.start(dispatchers)
  local rpc = vim.lsp.rpc.start({ vim.fn.stdpath 'data' .. '/sql-schema/sql-lsp' }, dispatchers)
  local request = rpc.request
  -- Negative IDs keep locally answered signature requests separate from server RPC IDs.
  local local_id = 0
  function rpc.request(method, params, callback, replied)
    if method ~= 'textDocument/completion' and method ~= 'textDocument/signatureHelp' then
      return request(method, params, callback, replied)
    end
    local ctx = context(params)
    if not ctx then
      return request(method, params, callback, replied)
    end
    local words = require('config.sql_words').new()
    if method == 'textDocument/signatureHelp' then
      local_id = local_id - 1
      local id = local_id
      words:get_signature_help(ctx, function(result)
        vim.schedule(function()
          if replied then
            replied(id)
          end
          callback(nil, result)
        end)
      end)
      return true, id
    end
    local tick = vim.api.nvim_buf_get_changedtick(ctx.bufnr)
    return request(method, params, function(err, result)
      if err or not vim.api.nvim_buf_is_loaded(ctx.bufnr) or vim.api.nvim_buf_get_changedtick(ctx.bufnr) ~= tick then
        callback(err, nil)
      else
        callback(nil, complete(words, ctx, result or {}))
      end
    end, replied)
  end
  return rpc
end

return M
