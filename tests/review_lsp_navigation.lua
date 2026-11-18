vim.opt.rtp:prepend(vim.fn.getcwd())
local server = vim.fn.stdpath 'data' .. '/mason/bin/lua-language-server'
assert(vim.fn.executable(server) == 1, 'install lua-language-server with Mason before running this test')
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/.git', 'p')
root = vim.uv.fs_realpath(root)
package.loaded['diffview.lib'] = {
  get_current_view = function()
    return { adapter = { ctx = { toplevel = root, dir = root .. '/.git' } } }
  end,
}
vim.lsp.config('review_real_lua', {
  cmd = { server },
  filetypes = { 'lua' },
  root_dir = root,
  settings = { Lua = { workspace = { checkThirdParty = false }, telemetry = { enable = false } } },
})
vim.lsp.enable 'review_real_lua'
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, 'diffview://' .. root .. '/.git/abcdef/example.lua')
vim.bo[buf].buftype = 'nowrite'
vim.bo[buf].filetype = 'lua'
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "local label = 'é'; local function greet() return 1 end",
  'local value = greet()',
  'return value',
})
vim.api.nvim_set_current_buf(buf)
local review = require 'config.review'
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    vim.keymap.set('n', 'gd', function()
      error 'normal mapping replaced review navigation'
    end, { buffer = event.buf })
  end,
})
review.attach_diff_lsp(buf)
assert(
  vim.wait(15000, function()
    local client = vim.lsp.get_clients({ bufnr = buf })[1]
    return client and client.initialized
  end, 50),
  'Lua server must initialise on the review blob'
)
vim.api.nvim_win_set_cursor(0, { 2, 15 })
vim.fn.maparg('gd', 'n', false, true).callback()
assert(
  vim.wait(15000, function()
    return vim.api.nvim_win_get_cursor(0)[1] == 1
  end, 50),
  'gd must resolve definition from PR contents'
)
assert(vim.api.nvim_get_current_buf() == buf, 'same-file definition should stay in review blob')
assert(vim.api.nvim_win_get_cursor(0)[2] == #"local label = 'é'; local function ", 'definition uses byte columns after Unicode')
local base_client = vim.lsp.get_clients({ bufnr = buf })[1]
local head = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(head, 'diffview://' .. root .. '/.git/123456/example.lua')
vim.bo[head].buftype = 'nowrite'
vim.bo[head].filetype = 'lua'
vim.api.nvim_buf_set_lines(
  head,
  0,
  -1,
  false,
  { '-- new header', '-- more header', 'local function greet() return 2 end', 'local value = greet()', 'return value' }
)
vim.api.nvim_set_current_buf(head)
review.attach_diff_lsp(head)
assert(vim.wait(15000, function()
  local client = vim.lsp.get_clients({ bufnr = head })[1]
  return client and client.initialized
end, 50))
local head_client = vim.lsp.get_clients({ bufnr = head })[1]
assert(head_client.id ~= base_client.id, 'base and head require separate document namespaces')
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_win_set_cursor(0, { 2, 15 })
vim.fn.maparg('gd', 'n', false, true).callback()
assert(
  vim.wait(15000, function()
    return vim.api.nvim_win_get_cursor(0)[1] == 1
  end, 50),
  'opening head must not replace base LSP text'
)
vim.api.nvim_buf_delete(head, { force = true })
assert(
  vim.wait(5000, function()
    return head_client:is_stopped()
  end, 20),
  'unused revision server must stop'
)
assert(not base_client:is_stopped(), 'closing head must preserve the active base server')
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
vim.fn.delete(root, 'rf')
print 'PASS real Lua language server: gd resolves definition in review contents'
vim.cmd 'qa!'
