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
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      { 'j-hui/fidget.nvim', opts = {} },
      'saghen/blink.cmp',
    },
    config = function()
      require('config.lsp').setup()
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
    opts = function()
      local js = require('config.projects').formatters
      return {
        notify_on_error = false,
        format_on_save = function(bufnr)
          if not require('config.buffer').editable(bufnr) then
            return
          end
          return { timeout_ms = 500, lsp_format = 'fallback' }
        end,
        formatters_by_ft = {
          c = { lsp = 'clangd' },
          cpp = { lsp = 'clangd' },
          lua = { 'stylua' },
          python = { 'ruff_fix', 'ruff_format' },
          javascript = js,
          javascriptreact = js,
          typescript = js,
          typescriptreact = js,
          json = js,
          jsonc = js,
          html = { 'prettier' },
          css = { 'prettier' },
          yaml = { 'prettier' },
          rust = { 'rustfmt' },
          dart = { 'dart_format' },
          go = { 'goimports', 'gofumpt' },
        },
      }
    end,
  },

  {
    'saghen/blink.cmp',
    event = 'InsertEnter',
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
