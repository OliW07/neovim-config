return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '★' },
      },
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text_pos = 'eol',
      },
    },
  },

  {
    'tpope/vim-fugitive',
    cmd = { 'G', 'Git', 'Gdiffsplit', 'Gread', 'Gwrite', 'Gstatus', 'Glog', 'Gblame' },
  },

  {
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()
    end,
  },

  {
    'NMAC427/guess-indent.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      auto_cmd = true,
      override_editorconfig = false,
    },
  },

  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      -- nvim-treesitter main (required on Neovim 0.12+) dropped the old
      -- configs.setup / ensure_installed API.
      local langs = {
        'bash',
        'c',
        'cpp',
        'css',
        'dart',
        'diff',
        'go',
        'html',
        'javascript',
        'json',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'python',
        'query',
        'rust',
        'tsx',
        'typescript',
        'vim',
        'vimdoc',
        'yaml',
      }
      vim.api.nvim_create_user_command('TSInstallCommon', function()
        require('nvim-treesitter').install(langs)
      end, { desc = 'Install the configured Treesitter parsers' })
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(event)
          if require('config.buffer').large(event.buf) then
            vim.treesitter.stop(event.buf) -- Bundled ftplugins can start it before this hook.
            return
          end
          local ok = pcall(vim.treesitter.start, event.buf)
          if ok and vim.bo[event.buf].buftype == '' then
            vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  {
    'mluders/comfy-line-numbers.nvim',
    event = 'BufReadPre',
    opts = {},
  },

  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {},
  },

  {
    'preservim/vim-pencil',
    ft = { 'markdown', 'text' },
    config = function()
      vim.g.pencil_wrapMode = 'soft'
      vim.g.pencil_textwidth = 80
      vim.g.pencil_conceallevel = 2
      vim.g.pencil_concealcursor = 'i'
    end,
  },

  {
    'dkarter/bullets.vim',
    ft = { 'markdown', 'text' },
  },

  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { 'markdown', 'Avante' },
    opts = {
      heading = {
        backgrounds = {},
      },
      code = {
        border = 'thin',
        above = '▔',
        below = '▁',
      },
    },
    config = function(_, opts)
      require('render-markdown').setup(opts)
      vim.api.nvim_set_hl(0, 'RenderMarkdownCodeInline', {})
      vim.api.nvim_set_hl(0, 'RenderMarkdownCode', { bg = '#121212' })
    end,
  },
}
