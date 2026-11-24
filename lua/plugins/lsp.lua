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
    ft = 'sql',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      { 'j-hui/fidget.nvim', opts = { progress = { display = { progress_icon = '', done_icon = '' } } } },
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
        '<leader>cf',
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
        format_on_save = function(bufnr)
          if not require('config.buffer').editable(bufnr) then
            return
          end
          return { timeout_ms = 500, lsp_format = 'fallback', quiet = true }
        end,
        formatters_by_ft = {
          c = { name = 'clangd' },
          cpp = { name = 'clangd' },
          lua = { 'stylua' },
          python = { 'ruff_format' },
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
          go = { 'gofumpt' },
        },
      }
    end,
  },

  {
    'saghen/blink.cmp',
    event = { 'InsertEnter', 'CmdlineEnter' },
    version = '1.*',
    dependencies = {
      'folke/lazydev.nvim',
    },
    opts = {
      keymap = { preset = 'default' },
      cmdline = {
        completion = {
          menu = {
            auto_show = function()
              return vim.fn.getcmdtype() == ':'
            end,
          },
        },
      },
      completion = {
        menu = { draw = { columns = { { 'label', 'label_description', gap = 1 }, { 'kind' } } } },
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
        trigger = {
          show_on_blocked_trigger_characters = function()
            return vim.bo.filetype == 'sql' and { '\n', '\t' } or { ' ', '\n', '\t' }
          end,
        },
      },
      sources = {
        default = { 'lsp', 'path', 'lazydev' },
        providers = {
          path = { module = 'config.path_completion', score_offset = -10 },
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },
      fuzzy = { implementation = 'lua' },
      signature = { enabled = true },
    },
  },
}
