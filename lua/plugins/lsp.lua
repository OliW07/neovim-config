return {
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    commit = '0203a96',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      { 'j-hui/fidget.nvim', opts = {} },
      'saghen/blink.cmp',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, 'Rename')
          map('gra', vim.lsp.buf.code_action, 'Code action', { 'n', 'x' })
          map('grr', vim.lsp.buf.references, 'Goto references')
          map('gri', require('telescope.builtin').lsp_implementations, 'Goto implementation')
          map('grd', require('telescope.builtin').lsp_definitions, 'Goto definition')
          map('grD', vim.lsp.buf.declaration, 'Goto declaration')
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Document symbols')
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Workspace symbols')
          map('grt', require('telescope.builtin').lsp_type_definitions, 'Goto type')

          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, 'Toggle inlay hints')
          end
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
            return diagnostic.message
          end,
        },
      }

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      vim.lsp.config.lua_ls = vim.tbl_deep_extend('force', vim.lsp.config.lua_ls or {}, {
        capabilities = capabilities,
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
          },
        },
      })

      vim.lsp.config.rust_analyzer = vim.tbl_deep_extend('force', vim.lsp.config.rust_analyzer or {}, {
        capabilities = capabilities,
        settings = {
          ['rust-analyzer'] = {
            cargo = { allFeatures = true },
            check = { command = 'clippy' },
          },
        },
      })

      vim.lsp.config.pyright = vim.tbl_deep_extend('force', vim.lsp.config.pyright or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config.ts_ls = vim.tbl_deep_extend('force', vim.lsp.config.ts_ls or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config.jsonls = vim.tbl_deep_extend('force', vim.lsp.config.jsonls or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config.yamlls = vim.tbl_deep_extend('force', vim.lsp.config.yamlls or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config.html = vim.tbl_deep_extend('force', vim.lsp.config.html or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config.cssls = vim.tbl_deep_extend('force', vim.lsp.config.cssls or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config.bashls = vim.tbl_deep_extend('force', vim.lsp.config.bashls or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config.marksman = vim.tbl_deep_extend('force', vim.lsp.config.marksman or {}, {
        capabilities = capabilities,
      })

      vim.lsp.config('clangd', {
        capabilities = capabilities,
        cmd = { 'clangd', '--clang-tidy=false', '--pch-storage=disk' },
      })

      vim.lsp.enable({
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
      })


    end,
  },

  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = 'Format buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return { timeout_ms = 500, lsp_format = 'fallback' }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_format', 'ruff_fix' },
        javascript = { 'prettier' },
        typescript = { 'prettier' },
        json = { 'prettier' },
        html = { 'prettier' },
        css = { 'prettier' },
        rust = { 'rustfmt' },
      },
    },
  },

  {
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      'folke/lazydev.nvim',
    },
    opts = {
      keymap = { preset = 'default' },
      appearance = { nerd_font_variant = 'mono' },
      completion = { documentation = { auto_show = false, auto_show_delay_ms = 500 } },
      sources = {
        default = { 'lsp', 'path', 'lazydev' },
        providers = { lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 } },
      },
      fuzzy = { implementation = 'lua' },
      signature = { enabled = true },
    },
  },
}
