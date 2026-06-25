return {
  {
    'nvim-telescope/telescope.nvim',
    commit = '5255aa2',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = vim.fn.has 'win32' == 1 and 'cmake -S. -Bbuild' or 'make',
        cond = function()
          return vim.fn.executable 'cmake' == 1 or vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup {
        pickers = {
          find_files = { theme = 'dropdown', previewer = false },
        },
        defaults = {
          vimgrep_arguments = {
            'rg', '--no-heading', '--with-filename',
            '--line-number', '--column', '--case-sensitive',
          },
          file_ignore_patterns = { 'node_modules', '.git', 'dist', 'build', 'target' },
          mappings = {
            i = {
              ['<C-j>'] = 'move_selection_next',
              ['<C-k>'] = 'move_selection_previous',
              ['<C-q>'] = function(...)
                require('telescope.actions').send_to_qflist(...)
                require('telescope.builtin').quickfix()
              end,
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = 'case_match',
          },
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
    end,
  },

  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 0,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ', Down = '<Down> ', Left = '<Left> ', Right = '<Right> ',
          C = '<C-…> ', M = '<M-…> ', D = '<D-…> ', S = '<S-…> ',
          CR = '<CR> ', Esc = '<Esc> ', ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ', NL = '<NL> ', BS = '<BS> ',
          Space = '<Space> ', Tab = '<Tab> ',
        },
      },
      spec = {
        { '<leader>t', group = 'Toggle' },
        { '<leader>h', group = 'Git hunk', mode = { 'n', 'v' } },
        { '<leader>g', group = 'Git' },
      },
    },
  },

  {
    'sainnhe/everforest',
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.everforest_background = 'medium'
      vim.g.everforest_transparent_background = 1
      vim.g.everforest_dim_inactive_windows = 1
      vim.g.everforest_disable_italic_comment = 1
      vim.g.everforest_colors_override = {
        green = { '#b8a070', '142' },
      }
      vim.cmd.colorscheme 'everforest'
      vim.api.nvim_set_hl(0, 'LineNr', { fg = '#C4B9A0' })
      vim.api.nvim_set_hl(0, 'LineNrAbove', { fg = '#C4B9A0' })
      vim.api.nvim_set_hl(0, 'LineNrBelow', { fg = '#C4B9A0' })
      vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#D4C9B8' })
      vim.api.nvim_set_hl(0, 'StatusLine', { bg = 'none', fg = '#D4C9B8' })
      vim.api.nvim_set_hl(0, 'StatusLineNC', { bg = 'none', fg = '#5A5247' })
    end,
  },

  {
    'iamcco/markdown-preview.nvim',
    ft = { 'markdown' },
    build = function()
      vim.fn['mkdp#util#install']()
    end,
    config = function()
      vim.g.mkdp_port = '9876'
      vim.g.mkdp_auto_close = 1
    end,
  },

  {
    'stevearc/oil.nvim',
    lazy = false,
    keys = {
      { '-', ':Oil<CR>', desc = 'Open parent directory', silent = true },
    },
    opts = {
      columns = {},
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ['.'] = 'actions.toggle_hidden',
        ['gx'] = 'actions.open_external',
        ['gy'] = 'actions.yank_entry',
      },
    },
    config = function(_, opts)
      require('oil').setup(opts)
      if vim.fn.argc() == 0 then
        vim.defer_fn(function()
          vim.cmd ':Oil'
        end, 100)
      end
    end,
  },

  {
    'folke/zen-mode.nvim',
    opts = {
      window = {
        width = 120,
        options = { number = false, relativenumber = false },
      },
    },
  },

  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      options = {
        theme = {
          normal = {
            a = { bg = 'none', fg = '#D4C9B8', gui = 'none' },
            b = { bg = 'none', fg = '#D4C9B8', gui = 'none' },
            c = { bg = 'none', fg = '#D4C9B8', gui = 'none' },
          },
          insert = { a = { bg = 'none', fg = '#A8C08A', gui = 'none' } },
          visual = { a = { bg = 'none', fg = '#C0A8C0', gui = 'none' } },
          replace = { a = { bg = 'none', fg = '#D4877A', gui = 'none' } },
          command = { a = { bg = 'none', fg = '#8AB8C0', gui = 'none' } },
          terminal = { a = { bg = 'none', fg = '#8AC0B0', gui = 'none' } },
          inactive = {
            a = { bg = 'none', fg = '#5A5247', gui = 'none' },
            b = { bg = 'none', fg = '#5A5247', gui = 'none' },
            c = { bg = 'none', fg = '#5A5247', gui = 'none' },
          },
        },
        globalstatus = true,
        disabled_filetypes = { statusline = { 'dashboard', 'alpha', 'starter' } },
        component_separators = '',
        section_separators = '',
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch' },
        lualine_c = { 'filename' },
        lualine_x = {
          {
            function()
              local reg = vim.fn.reg_recording()
              if reg == '' then return '' end
              return 'recording @' .. reg
            end,
            color = { fg = '#D4877A' },
          },
        },
        lualine_y = {},
        lualine_z = { 'location' },
      },
      extensions = { 'oil', 'fugitive' },
    },
  },

  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    },
    opts = {
      routes = {
        {
          filter = { event = 'msg_show', kind = { 'echo', 'echomsg' } },
          view = 'mini',
        },
      },
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = true,
      },
    },
    keys = {
      { '<S-Enter>', function() require('noice').redirect(vim.fn.getcmdline()) end, mode = 'c', desc = 'Redirect cmdline' },
    },
  },

  {
    'rcarriga/nvim-notify',
    opts = {
      stages = 'fade',
      timeout = 2000,
      render = 'default',
    },
  },

  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gd', '<Cmd>DiffviewOpen<CR>', desc = 'Diff view' },
      { '<leader>gh', '<Cmd>DiffviewFileHistory<CR>', desc = 'File history' },
    },
  },

  {
    'akinsho/toggleterm.nvim',
    cmd = { 'ToggleTerm', 'TermExec' },
    opts = {
      size = 10,
      open_mapping = '<C-\\>',
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 0,
      start_in_insert = true,
      persist_size = true,
      direction = 'horizontal',
      close_on_exit = true,
    },
    keys = {
      { '<C-\\>', '<Cmd>ToggleTerm<CR>', desc = 'Toggle terminal' },
      { '<leader>tt', '<Cmd>ToggleTerm<CR>', desc = 'Toggle terminal' },
    },
  },
}
