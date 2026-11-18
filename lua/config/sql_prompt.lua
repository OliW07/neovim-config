-- RPC adapter for chq: reuse the actual schema LSP and local completion sources.
local M = {}
function M.setup(root)
  vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/.chq-prompt.sql'))
  M.buf = vim.api.nvim_get_current_buf()
  vim.bo[M.buf].filetype = 'sql'
  local client
  assert(
    vim.wait(10000, function()
      client = vim.lsp.get_clients({ bufnr = M.buf, name = 'sql_schema' })[1]
      return client and client._sql_schema
    end, 20),
    'SQL LSP could not load ' .. root .. '/schema.sql'
  )
  M.client = client
  M.source = require('config.sql_words').new()
  -- Prompt edits are in memory; diagnostics are not part of the terminal menu.
  pcall(vim.api.nvim_del_augroup_by_name, 'clickhouse-syntax-' .. M.buf)
  vim.bo[M.buf].buftype = 'nofile'
  vim.bo[M.buf].swapfile = false
end

function M.reload()
  local previous = M.client._sql_schema
  require('config.sql').refresh(M.client)
  assert(
    vim.wait(10000, function()
      return M.client._sql_schema ~= previous
    end, 20),
    'Schema reload timed out'
  )
end

function M.complete(text, row, col)
  local lines = vim.split(text, '\n', { plain = true })
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  local line = lines[row + 1]
  local ctx = { bufnr = M.buf, line = line, cursor = { row + 1, col } }
  local local_items = M.source:items(ctx)
  local response, err = M.client:request_sync('textDocument/completion', {
    textDocument = { uri = vim.uri_from_bufnr(M.buf) },
    position = { line = row, character = vim.str_utfindex(line:sub(1, col), M.client.offset_encoding) },
  }, 1500, M.buf)
  if err then
    error('SQL LSP completion failed: ' .. tostring(err))
  end
  local raw = response and response.result or {}
  local lsp_items = raw.items or raw
  for _, item in ipairs(lsp_items) do
    item.client_id = M.client.id
  end
  lsp_items = require('config.sql').completions(ctx, lsp_items)
  local results, seen = {}, {}
  local before = line:sub(1, col)
  local prefix = before:match '[%w_]*$' or ''
  local function add(item, encoding)
    local edit = item.textEdit
    local range = edit and (edit.replace or edit.range)
    local value = edit and edit.newText or item.insertText or item.label
    local start_col, end_col = col - #prefix, col
    if range then
      if range.start.line ~= row or range['end'].line ~= row then
        return
      end
      start_col = vim.str_byteindex(line, encoding, range.start.character, false)
      end_col = vim.str_byteindex(line, encoding, range['end'].character, false)
    end
    if start_col > col or end_col < col then
      return
    end
    local typed = line:sub(start_col + 1, col)
    -- Match anywhere, just like the shared SQL sources used by Blink.
    local matches = (item.filterText or item.label or value):lower():find(typed:lower(), 1, true) ~= nil
    if not matches then
      return
    end
    local key = start_col .. ':' .. end_col .. ':' .. value
    if not seen[key] then
      seen[key] = true
      results[#results + 1] = { label = item.label, text = value, detail = item.detail or '', start_col = start_col, end_col = end_col }
    end
  end
  for _, item in ipairs(local_items) do
    add(item, 'utf-8')
  end
  for _, item in ipairs(lsp_items) do
    add(item, M.client.offset_encoding or 'utf-16')
  end
  table.sort(results, function(a, b)
    return a.label:lower() < b.label:lower()
  end)
  return results
end
return M
