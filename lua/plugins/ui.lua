return {
  {
    'nvim-telescope/telescope.nvim',
    commit = '5255aa2',
    cmd = 'Telescope',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = vim.fn.executable 'cmake' == 1
            and { 'cmake -S . -B build -DCMAKE_BUILD_TYPE=Release', 'cmake --build build --config Release --target install' }
          or 'make',
        cond = function()
          return vim.fn.executable 'cmake' == 1 or vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
    },
    config = function()
      require('telescope').setup {
        pickers = {
          find_files = {
            theme = 'dropdown',
            previewer = false,
            layout_config = { width = 0.9, height = 0.7 },
            path_display = { 'relative' },
          },
        },
        defaults = {
          file_ignore_patterns = { '^node_modules/', '/node_modules/', '^%.git/', '/%.git/', '^dist/', '/dist/', '^build/', '/build/', '^target/', '/target/' },
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
            case_mode = 'respect_case',
          },
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }
      local ok, err = pcall(require('telescope').load_extension, 'fzf')
      if not ok then
        vim.notify_once('Telescope native sorter unavailable. Check :Lazy build telescope-fzf-native.nvim. ' .. tostring(err), vim.log.levels.WARN)
      end
      pcall(require('telescope').load_extension, 'ui-select')
    end,
  },

  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 300,
      icons = { mappings = false, breadcrumb = '/', separator = ' ' },
      replace = { key = { { '<Space>', 'Space' } } },
      spec = {
        { '<leader>f', group = 'Find' },
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
      vim.o.background = 'dark'
      vim.g.everforest_ui_contrast = 'high'
      vim.g.everforest_disable_italic_comment = 1
      vim.g.everforest_colors_override = {
        bg_dim = { '#22201d', '234' },
        bg0 = { '#292723', '235' },
        bg1 = { '#302e29', '236' },
        bg2 = { '#393630', '237' },
        bg3 = { '#423e37', '238' },
        bg4 = { '#4c473f', '239' },
        bg5 = { '#696257', '241' },
        bg_visual = { '#504b3e', '239' },
        fg = { '#ded5c7', '253' },
        grey0 = { '#928a7d', '245' },
        grey1 = { '#a49b8e', '247' },
        grey2 = { '#beb4a4', '250' },
        red = { '#d39e88', '180' },
        orange = { '#c7b294', '180' },
        yellow = { '#d1b988', '180' },
        green = { '#b6b9a1', '145' },
        aqua = { '#aab594', '144' },
        blue = { '#b1b6b0', '145' },
        purple = { '#c1b0a1', '145' },
      }
      vim.cmd.colorscheme 'everforest'
    end,
  },

  {
    'iamcco/markdown-preview.nvim',
    ft = { 'markdown' },
    build = function()
      vim.fn['mkdp#util#install']()
    end,
    config = function()
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
      local stdin = false
      vim.api.nvim_create_autocmd('StdinReadPre', {
        once = true,
        callback = function()
          stdin = true
        end,
      })
      vim.api.nvim_create_autocmd('VimEnter', {
        once = true,
        callback = function()
          vim.schedule(function()
            if
              not stdin
              and vim.fn.argc() == 0
              and vim.bo.buftype == ''
              and not vim.bo.modified
              and vim.api.nvim_buf_get_name(0) == ''
              and vim.api.nvim_buf_line_count(0) == 1
              and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == ''
            then
              require('oil').open()
            end
          end)
        end,
      })
    end,
  },

  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gd', '<Cmd>DiffviewOpen<CR>', desc = 'Diff view' },
      { '<leader>gh', '<Cmd>DiffviewFileHistory<CR>', desc = 'File history' },
    },
    opts = function()
      local actions = require 'diffview.actions'
      return {
        use_icons = false,
        signs = { fold_closed = '>', fold_open = 'v', done = 'x' },
        file_panel = {
          win_config = {
            win_opts = {
              number = true,
              relativenumber = true,
            },
          },
        },
        keymaps = {
          -- L is <S-l>, which we use to move focus to the right window.
          file_panel = {
            { 'n', 'L', false },
            { 'n', 'gL', actions.open_commit_log, { desc = 'Open the commit log panel' } },
          },
          file_history_panel = {
            { 'n', 'L', false },
            { 'n', 'gL', actions.open_commit_log, { desc = 'Show commit details' } },
          },
        },
      }
    end,
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
