local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/.git', 'p')
vim.fn.writefile({ 'CREATE TABLE prod.payments (amount Int64);' }, root .. '/schema.sql')
vim.cmd('edit ' .. root .. '/query.sql')
assert(vim.wait(5000, function()
  local c = vim.lsp.get_clients({ bufnr = 0, name = 'sql_schema' })[1]
  return c and c._sql_schema
end))
local cmp = require 'blink.cmp'
local function later(ms, fn)
  vim.defer_fn(function()
    local ok, err = pcall(fn)
    if not ok then
      print(err)
      vim.cmd 'cquit 1'
    end
  end, ms)
end
local function check(prefix, typed, accepted, next_case)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { prefix })
  vim.api.nvim_win_set_cursor(0, { 1, #prefix })
  vim.cmd 'startinsert!'
  later(150, function()
    vim.api.nvim_input(typed)
  end)
  later(800, function()
    assert(cmp.is_visible(), 'missing Blink popup: ' .. prefix)
    local item = cmp.get_selected_item()
    assert(item and item.source_id == 'lsp', vim.inspect(item))
    vim.api.nvim_input(vim.keycode '<C-y>')
  end)
  later(1100, function()
    assert(vim.api.nvim_get_current_line() == accepted, vim.api.nvim_get_current_line())
    vim.api.nvim_input(vim.keycode '<Esc>')
    later(100, next_case)
  end)
end
check('SELECT * FROM paymen', 't', 'SELECT * FROM prod.payments', function()
  check('SELECT * FROM prod.payments WHERE amou', 'n', 'SELECT * FROM prod.payments WHERE amount', function()
    vim.fn.delete(root, 'rf')
    print 'PASS SQL LSP via Blink: accept a qualified table and a column'
    vim.cmd 'qa!'
  end)
end)
