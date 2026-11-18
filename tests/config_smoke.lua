local lazy = require 'lazy'
local f5 = vim.fn.maparg('<F5>', 'n', false, true).desc
lazy.load { plugins = { 'cmake-tools.nvim' } }
assert(vim.fn.exists ':CMakeBuild' == 2)
assert(vim.fn.maparg('<F5>', 'n', false, true).desc == f5, 'CMake must not overwrite general debugging')
local dap = require 'dap'
assert(dap.adapters.python and dap.configurations.python and dap.adapters.lldb and dap.configurations.cpp)
assert(vim.fn.maparg('<space>r', 'n', false, true).desc == 'Run, build or debug')
assert(vim.fn.maparg('<space>c', 'n') == '', 'CMake prefix must not also be a change operator')
assert(vim.fn.maparg('<space>b', 'n') == '', 'buffer prefix must not also toggle breakpoints')
assert(vim.fn.maparg('<space>f', 'n') == '', 'search prefix must not also trigger formatting')
assert(vim.fn.maparg('<space>cf', 'n', false, true).desc == 'Format buffer')
assert(vim.fn.maparg('<space>ff', 'n', false, true).desc == 'Find files in current directory')
assert(vim.fn.maparg('<space>fF', 'n', false, true).desc == 'Find files in working directory')
assert(vim.fn.maparg('<space>Y', 'n', false, true).desc == 'Yank absolute file path')
assert(not package.loaded.conform, 'formatting must not load before first use/save')
assert(not package.loaded['telescope.builtin'], 'Telescope must not load on startup')
lazy.load { plugins = { 'nvim-lspconfig' } }
assert(not package.loaded['telescope.builtin'], 'LSP setup must not eagerly load Telescope')
assert(vim.deep_equal(vim.lsp.config.clangd.capabilities.general.positionEncodings, { 'utf-8', 'utf-16' }), 'preserve upstream Clangd encoding negotiation')
assert(vim.lsp.is_enabled 'gopls' and vim.lsp.is_enabled 'biome', 'server setup must not depend on VeryLazy')
local proxy = vim.fn.exepath(vim.fs.joinpath(vim.env.CARGO_HOME or vim.fn.expand '~/.cargo', 'bin', 'rust-analyzer'))
local start = vim.lsp.rpc.start
local command, process
vim.lsp.rpc.start = function(cmd, _, opts)
  command, process = cmd, opts
end
vim.lsp.config.rust_analyzer.cmd({}, { root_dir = '/rust/project' })
vim.lsp.rpc.start = start
assert(command[1] == (proxy ~= '' and proxy or 'rust-analyzer'), 'Mason must not shadow rustup')
assert(process.cwd == '/rust/project', 'resolve rust-toolchain.toml from the opened project')
local original_get = vim.lsp.get_client_by_id
local original_clients = vim.lsp.get_clients
local fake = {
  supports_method = function()
    return true
  end,
}
vim.lsp.get_client_by_id = function()
  return fake
end
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_exec_autocmds('LspAttach', { buffer = buf, data = { client_id = 999 } })
vim.api.nvim_exec_autocmds('LspAttach', { buffer = buf, data = { client_id = 998 } })
assert(#vim.api.nvim_get_autocmds { group = 'lsp-highlight', buffer = buf } == 4, 'multiple clients must not duplicate cursor callbacks')
vim.lsp.get_clients = function()
  return { fake }
end
vim.api.nvim_exec_autocmds('LspDetach', { buffer = buf, data = { client_id = 999 } })
vim.wait(20, function()
  return false
end)
assert(#vim.api.nvim_get_autocmds { group = 'lsp-highlight', buffer = buf } == 4, 'remaining server keeps highlights')
vim.lsp.get_clients = function()
  return {}
end
vim.api.nvim_exec_autocmds('LspDetach', { buffer = buf, data = { client_id = 998 } })
vim.wait(20, function()
  return false
end)
assert(#vim.api.nvim_get_autocmds { group = 'lsp-highlight', buffer = buf } == 0)
vim.lsp.get_client_by_id, vim.lsp.get_clients = original_get, original_clients
for _, spec in ipairs(require 'plugins.lsp') do
  if spec[1] == 'stevearc/conform.nvim' then
    local opts = spec.opts()
    assert(vim.deep_equal(opts.formatters_by_ft.go, { 'gofumpt' }))
    assert(vim.deep_equal(opts.formatters_by_ft.python, { 'ruff_format' }))
    local scratch = vim.api.nvim_create_buf(false, true)
    assert(opts.format_on_save(scratch) == nil, 'scratch buffers must not format on save')
  end
end
vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy' })
assert(vim.fn.exists ':TSInstallCommon' == 2)
local markdown = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(markdown, 0, -1, false, { '# Smoke test', '', '**Markdown rendering**' })
vim.api.nvim_set_current_buf(markdown)
vim.bo[markdown].filetype = 'markdown'
assert(package.loaded['render-markdown'], 'Markdown renderer should load for Markdown')
local search = require('telescope.config').values
for _, pattern in ipairs(search.file_ignore_patterns) do
  assert(not ('src/digit.ts'):find(pattern), 'ignore patterns must not hide unrelated filenames')
end
assert(vim.tbl_contains(search.vimgrep_arguments, '--smart-case'))
for _, ext in ipairs { 'lua', 'md' } do
  local path = vim.fn.tempname() .. '.' .. ext
  vim.fn.writefile({ string.rep('a', require('config.buffer').max_bytes + 1) }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  assert(not vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], 'built-in highlighter remained active on large ' .. ext)
end
io.stdout:write 'PASS full config, lazy tools, independent debuggers, key prefixes, unified LSP/formatting, highlight lifecycle\n'
vim.cmd 'qa!'
