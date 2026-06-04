return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',
      'mason-org/mason.nvim',
      'jay-babu/mason-nvim-dap.nvim',
      'leoluz/nvim-dap-go',
    },
    keys = {
      { '<F5>', function() require('dap').continue() end, desc = 'Debug start/continue' },
      { '<F1>', function() require('dap').step_into() end, desc = 'Debug step into' },
      { '<F2>', function() require('dap').step_over() end, desc = 'Debug step over' },
      { '<F3>', function() require('dap').step_out() end, desc = 'Debug step out' },
      { '<leader>b', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
      { '<leader>B', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, desc = 'Set breakpoint' },
      { '<F7>', function() require('dapui').toggle() end, desc = 'Debug UI' },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      require('mason-nvim-dap').setup {
        automatic_installation = true,
        handlers = {},
        ensure_installed = { 'delve' },
      }

      local lldb_path = '/usr/bin/lldb'
      local lldb_dap_path = '/usr/bin/lldb-dap'
      if vim.fn.executable(lldb_dap_path) == 1 then
        lldb_path = lldb_dap_path
      elseif vim.fn.executable('/usr/bin/lldb-dap-19') == 1 then
        lldb_path = '/usr/bin/lldb-dap-19'
      end

      dap.adapters.lldb = {
        type = 'executable',
        command = lldb_path,
        name = 'lldb',
      }
      dap.adapters.cppdbg = dap.adapters.lldb
      dap.configurations.cpp = {
        {
          name = 'Launch',
          type = 'lldb',
          request = 'launch',
          program = function()
            local cwd = vim.fn.getcwd()
            local choices = { 'Select executable:', '1. Chess Engine', '2. Perft Tests' }
            local selection = vim.fn.inputlist(choices)
            if selection == 1 then
              return cwd .. '/build/chess_engine'
            elseif selection == 2 then
              return cwd .. '/build/perft_tests'
            else
              return vim.fn.input('Path to executable: ', cwd .. '/', 'file')
            end
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
          runInTerminal = true,
        },
      }
      dap.configurations.c = dap.configurations.cpp

      dapui.setup {
        icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
        controls = {
          icons = {
            pause = '⏸', play = '▶', step_into = '⏎', step_over = '⏭',
            step_out = '⏮', step_back = 'b', run_last = '▶▶', terminate = '⏹', disconnect = '⏏',
          },
        },
      }

      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      require('dap-go').setup { delve = { detached = vim.fn.has 'win32' == 0 } }
    end,
  },

  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      -- cppcheck operates per translation unit and can't see cross-TU usage.
      -- Suppress checks that produce false positives in multi-file projects.
      lint.linters.cppcheck.args = vim.list_extend(vim.deepcopy(lint.linters.cppcheck.args), {
        '--suppress=unusedStructMember',
      })

      lint.linters_by_ft = {
        python = { 'ruff' },
        javascript = { 'eslint' },
        typescript = { 'eslint' },
        javascriptreact = { 'eslint' },
        typescriptreact = { 'eslint' },
        lua = { 'selene' },
        c = { 'cppcheck' },
        cpp = { 'cppcheck' },
        go = { 'staticcheck' },
        sh = { 'shellcheck' },
        bash = { 'shellcheck' },
        yaml = { 'yamllint' },
        markdown = { 'vale' },
      }

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          if vim.bo.modifiable then
            lint.try_lint()
          end
        end,
      })
    end,
  },

  {
    'Civitasv/cmake-tools.nvim',
    lazy = true,
    init = function()
      local loaded = false
      local function check()
        local cwd = vim.uv.cwd()
        if vim.fn.filereadable(cwd .. '/CMakeLists.txt') == 1 then
          require('lazy').load { plugins = { 'cmake-tools.nvim' } }
          loaded = true
        end
      end
      check()
      vim.api.nvim_create_autocmd('DirChanged', {
        callback = function()
          if not loaded then check() end
        end,
      })
    end,
    opts = {
      cmake_build_directory = 'build',
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=1' },
      cmake_executor = { name = 'quickfix', opts = {} },
      cmake_runner = { name = 'terminal' },
      cmake_dap_configuration = {
        name = 'cpp', type = 'lldb', request = 'launch',
        stopOnEntry = false, runInTerminal = true, console = 'integratedTerminal',
      },
    },
    config = function(_, opts)
      require('cmake-tools').setup(opts)

      vim.keymap.set('n', '<leader>cg', '<cmd>CMakeGenerate<cr>', { desc = 'CMake generate' })
      vim.keymap.set('n', '<leader>cb', function()
        vim.cmd 'wa'
        vim.cmd 'CMakeBuild'
      end, { desc = 'CMake build' })
      vim.keymap.set('n', '<leader>cr', function()
        vim.cmd 'wa'
        vim.cmd 'CMakeRun'
      end, { desc = 'CMake run' })
      vim.keymap.set('n', '<leader>cd', function()
        vim.cmd 'wa'
        vim.cmd 'CMakeDebug'
      end, { desc = 'CMake debug' })
      vim.keymap.set('n', '<leader>ct', '<cmd>CMakeSelectBuildType<cr>', { desc = 'Select build type' })
      vim.keymap.set('n', '<leader>cs', '<cmd>CMakeSelectBuildTarget<cr>', { desc = 'Select target' })
      vim.keymap.set('n', '<leader>cT', function()
        vim.cmd 'wa'
        vim.cmd 'CMakeRunTest'
      end, { desc = 'Run tests' })
      vim.keymap.set('n', '<leader>cl', '<cmd>CMakeSelectLaunchTarget<cr>', { desc = 'Select launch target' })
      vim.keymap.set('n', '<F5>', function()
        if require('dap').session() then
          require('dap').continue()
        else
          vim.cmd 'wa'
          vim.cmd 'CMakeDebug'
        end
      end, { desc = 'Build & debug' })
    end,
  },
}
