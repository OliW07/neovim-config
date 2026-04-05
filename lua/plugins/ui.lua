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
            case_mode = 'smart_case',
          },
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Search help' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = 'Search keymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = 'Search files' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = 'Search select' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = 'Search word' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Search grep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = 'Search diagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = 'Search resume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = 'Search recent' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = 'Find buffers' })
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = 'Fuzzy search in buffer' })
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep { grep_open_files = true, prompt_title = 'Live Grep in Open Files' }
      end, { desc = 'Search in open files' })
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = 'Search neovim files' })
      vim.keymap.set('n', '<leader>sp', builtin.git_files, { desc = 'Search git files' })
      vim.keymap.set('n', '<leader>st', builtin.tags, { desc = 'Search tags' })
      vim.keymap.set('n', '<leader>sc', builtin.git_commits, { desc = 'Git commits' })
      vim.keymap.set('n', '<leader>sC', builtin.git_bcommits, { desc = 'Git buffer commits' })
      vim.keymap.set('n', '<leader>sb', builtin.git_branches, { desc = 'Git branches' })
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
        { '<leader>s', group = 'Search' },
        { '<leader>t', group = 'Toggle' },
        { '<leader>h', group = 'Git hunk', mode = { 'n', 'v' } },
        { '<leader>g', group = 'Git' },
      },
    },
  },

  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('tokyonight').setup {
        style = 'storm',
        styles = {
          comments = { italic = false },
          keywords = { italic = false },
        },
        transparent = true,
        dim_inactive = true,
      }
      vim.cmd.colorscheme 'tokyonight'
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
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ['g?'] = 'actions.show_help',
        ['<CR>'] = 'actions.select',
        ['<C-s>'] = { 'actions.select', opts = { split = 'horizontal' } },
        ['<C-v>'] = { 'actions.select', opts = { split = 'vertical' } },
        ['<C-t>'] = { 'actions.select', opts = { tab = 'new' } },
        ['.'] = 'actions.toggle_hidden',
        ['gc'] = 'actions.close',
        ['gx'] = 'actions.open_external',
        ['ge'] = 'actions.rename',
        ['gE'] = 'actions.rename_basename',
        ['gy'] = 'actions.yank_entry',
        ['gp'] = 'actions.preview',
      },
    },
    config = function()
      require('oil').setup()
      vim.defer_fn(function()
        vim.cmd ':Oil'
      end, 100)
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
        theme = 'auto',
        globalstatus = true,
        disabled_filetypes = { statusline = { 'dashboard', 'alpha', 'starter' } },
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff' },
        lualine_c = {},
        lualine_x = { 'filetype', 'fileformat', 'encoding' },
        lualine_y = { 'progress' },
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
          ['cmp.entry.get_documentation'] = true,
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
      { '<leader>sn', function() require('noice').cmd 'history' end, desc = 'Noice history' },
      { '<leader>sa', function() require('noice').cmd 'all' end, desc = 'Noice all' },
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
