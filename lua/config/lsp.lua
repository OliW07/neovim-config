local M = {}
local function telescope(name)
  return function()
    require('telescope.builtin')[name]()
  end
end

function M.setup()
  local highlight_group = vim.api.nvim_create_augroup('lsp-highlight', { clear = true })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf
      local function map(key, callback, description, modes)
        vim.keymap.set(modes or 'n', key, callback, { buffer = buf, desc = 'LSP: ' .. description })
      end
      map('grn', vim.lsp.buf.rename, 'Rename')
      map('gra', vim.lsp.buf.code_action, 'Code action', { 'n', 'x' })
      map('grr', vim.lsp.buf.references, 'References')
      map('gri', telescope 'lsp_implementations', 'Implementation')
      map('gd', telescope 'lsp_definitions', 'Definition')
      map('grd', telescope 'lsp_definitions', 'Definition')
      map('grD', vim.lsp.buf.declaration, 'Declaration')
      map('gO', telescope 'lsp_document_symbols', 'Document symbols')
      map('gW', telescope 'lsp_dynamic_workspace_symbols', 'Workspace symbols')
      map('grt', telescope 'lsp_type_definitions', 'Type definition')
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', buf) then
        -- Multiple servers on a buffer still need only one set of callbacks.
        vim.api.nvim_clear_autocmds { group = highlight_group, buffer = buf }
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          group = highlight_group,
          buffer = buf,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          group = highlight_group,
          buffer = buf,
          callback = vim.lsp.buf.clear_references,
        })
      end
      if client and client:supports_method('textDocument/inlayHint', buf) then
        map('<leader>th', function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = buf }, { bufnr = buf })
        end, 'Toggle inlay hints')
      end
    end,
  })
  vim.api.nvim_create_autocmd('LspDetach', {
    group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
    callback = function(event)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(event.buf) then
          return
        end
        if #vim.lsp.get_clients { bufnr = event.buf, method = 'textDocument/documentHighlight' } == 0 then
          vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
          vim.api.nvim_buf_call(event.buf, vim.lsp.buf.clear_references)
        end
      end)
    end,
  })
  vim.diagnostic.config {
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = vim.diagnostic.severity.ERROR },
    signs = vim.g.have_nerd_font and {
      text = {
        [vim.diagnostic.severity.ERROR] = '󰅚 ',
        [vim.diagnostic.severity.WARN] = '󰀪 ',
        [vim.diagnostic.severity.INFO] = '󰋽 ',
        [vim.diagnostic.severity.HINT] = '󰌶 ',
      },
    } or {},
    virtual_text = {
      source = 'if_many',
      spacing = 2,
      format = function(diagnostic)
        local msg = diagnostic.message:gsub('\n', ' ')
        local win = vim.fn.winwidth(0)
        local line = vim.fn.virtcol('$') - 1
        local max = math.min(math.floor(win * 0.7), win - line) - 3
        if max < 20 then max = 20 end
        if #msg > max then
          msg = msg:sub(1, max - 1) .. '…'
        end
        return msg
      end,
    },
  }
  local projects = require 'config.projects'
  local capabilities = require('blink.cmp').get_lsp_capabilities()
  local names = {
    'lua_ls',
    'rust_analyzer',
    'pyright',
    'ts_ls',
    'jsonls',
    'yamlls',
    'html',
    'cssls',
    'bashls',
    'marksman',
    'clangd',
    'gopls',
    'tailwindcss',
    'biome',
    'eslint',
  }
  vim.lsp.config('lua_ls', { settings = { Lua = { completion = { callSnippet = 'Replace' } } } })
  vim.lsp.config('yamlls', { settings = { yaml = { format = { enable = false } } } })
  vim.lsp.config('rust_analyzer', { settings = { ['rust-analyzer'] = { cargo = { allFeatures = true }, check = { command = 'clippy' } } } })
  vim.lsp.config('ts_ls', { before_init = projects.ts_before_init })
  local clangd = vim.fn.exepath 'clangd-22'
  if clangd == '' then
    clangd = vim.fn.exepath 'clangd'
  end
  if clangd ~= '' then
    local cmd = { clangd, '--clang-tidy=false', '--pch-storage=disk' }
    if vim.fn.has 'unix' == 1 and vim.fn.has 'macunix' == 0 then
      cmd[#cmd + 1] = '--query-driver=/usr/bin/c++,/usr/bin/g++*,/usr/bin/aarch64-linux-gnu-g++*'
    end
    vim.lsp.config('clangd', { cmd = cmd })
  end
  local flutter = vim.fn.exepath 'flutter'
  local dart = flutter ~= '' and vim.fs.joinpath(vim.fs.dirname(flutter), 'dart') or ''
  if vim.fn.executable(dart) ~= 1 then
    dart = vim.fn.exepath 'dart'
  end
  if dart ~= '' then
    vim.lsp.config('dartls', { cmd = { dart, 'language-server', '--protocol=lsp' } })
    names[#names + 1] = 'dartls'
  end
  for _, name in ipairs(names) do
    local config = vim.lsp.config[name]
    local root_dir, markers, required = config.root_dir, config.root_markers, config.workspace_required
    vim.lsp.config(name, {
      capabilities = name == 'clangd' and vim.tbl_deep_extend('force', capabilities, { general = { positionEncodings = { 'utf-8', 'utf-16' } } })
        or capabilities,
      root_dir = function(buf, on_dir)
        if require('config.buffer').large(buf) then
          return
        end
        if name == 'biome' and not projects.biome_config(buf) then
          return
        end
        if name == 'eslint' and projects.biome_config(buf) then
          return
        end
        if type(root_dir) == 'function' then
          return root_dir(buf, on_dir)
        end
        local root = root_dir or (markers and vim.fs.root(buf, markers))
        if root or not required then
          on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(buf)))
        end
      end,
    })
  end
  vim.lsp.enable(names)
end
return M
