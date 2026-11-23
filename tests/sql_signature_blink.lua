vim.cmd 'enew'
vim.bo.filetype = 'sql'
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
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'SELECT toDecimalString' })
vim.cmd 'startinsert!'
later(150, function()
  vim.api.nvim_input '('
end)
later(700, function()
  local window = require 'blink.cmp.signature.window'
  assert(window.win:is_open(), 'signature popup must open after typing (')
  local content = table.concat(vim.api.nvim_buf_get_lines(window.win:get_buf(), 0, -1, false), '\n')
  assert(content:find('toDecimalString(number, scale)', 1, true), content)
  vim.api.nvim_input '12'
  later(100, function()
    vim.api.nvim_input ','
  end)
end)
later(1300, function()
  local window = require 'blink.cmp.signature.window'
  assert(window.win:is_open(), 'signature must remain open for second argument')
  assert(window.context.active_signature_help.activeParameter == 1, vim.inspect(window.context))
  print 'PASS real Blink signature popup after ( and active parameter after comma'
  vim.cmd 'qa!'
end)
