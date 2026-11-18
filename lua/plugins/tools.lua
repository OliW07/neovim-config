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
      {
        '<F5>',
        function()
          require('dap').continue()
        end,
        desc = 'Debug start/continue',
      },
      {
        '<F1>',
        function()
          require('dap').step_into()
        end,
        desc = 'Debug step into',
      },
      {
        '<F2>',
        function()
          require('dap').step_over()
        end,
        desc = 'Debug step over',
      },
      {
        '<F3>',
        function()
          require('dap').step_out()
        end,
        desc = 'Debug step out',
      },
      {
        '<leader>bb',
        function()
          require('dap').toggle_breakpoint()
        end,
        desc = 'Toggle breakpoint',
      },
      {
        '<leader>bB',
        function()
          require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Set breakpoint',
      },
      {
        '<F7>',
        function()
          require('dapui').toggle()
        end,
        desc = 'Debug UI',
      },
    },
    config = function()
      require('config.dap').setup()
    end,
  },

  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('config.lint').setup()
    end,
  },

  {
    'Civitasv/cmake-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    lazy = true,
    cmd = {
      'CMakeGenerate',
      'CMakeBuild',
      'CMakeRun',
      'CMakeDebug',
      'CMakeRunTest',
      'CMakeSelectBuildType',
      'CMakeSelectBuildTarget',
      'CMakeSelectLaunchTarget',
      'CMakeSelectCwd',
      'CMakeSelectBuildDir',
    },
    keys = {
      {
        '<leader>cc',
        function()
          require('config.tasks').cmake 'CMakeGenerate'
        end,
        desc = 'CMake configure',
      },
      {
        '<leader>cg',
        function()
          require('config.tasks').cmake 'CMakeGenerate'
        end,
        desc = 'CMake generate',
      },
      {
        '<leader>cb',
        function()
          require('config.tasks').cmake 'CMakeBuild'
        end,
        desc = 'CMake build',
      },
      {
        '<leader>cr',
        function()
          require('config.tasks').cmake 'CMakeRun'
        end,
        desc = 'CMake run',
      },
      {
        '<leader>cd',
        function()
          require('config.tasks').cmake 'CMakeDebug'
        end,
        desc = 'CMake debug',
      },
      {
        '<leader>ct',
        function()
          require('config.tasks').cmake 'CMakeSelectBuildType'
        end,
        desc = 'Select build type',
      },
      {
        '<leader>cs',
        function()
          require('config.tasks').cmake 'CMakeSelectBuildTarget'
        end,
        desc = 'Select build target',
      },
      {
        '<leader>cT',
        function()
          require('config.tasks').cmake 'CMakeRunTest'
        end,
        desc = 'CMake tests',
      },
      {
        '<leader>cl',
        function()
          require('config.tasks').cmake 'CMakeSelectLaunchTarget'
        end,
        desc = 'Select launch target',
      },
    },
    config = function(_, opts)
      local cmake = require 'cmake-tools'
      -- The pinned executor and runner call this hook unconditionally before spawning.
      require('cmake-tools.utils').save_all_named_buffers = function()
        require('config.tasks').save_project(cmake.get_config().cwd)
      end
      cmake.setup(opts)
    end,
    opts = function()
      return {
        cmake_build_directory = 'build',
        cmake_regenerate_on_save = false,
        cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=1' },
        cmake_build_args = { '-j', tostring(require('config.tasks').jobs()) },
        cmake_executor = { name = 'quickfix', opts = {} },
        cmake_runner = { name = 'terminal' },
        cmake_dap_configuration = {
          name = 'cpp',
          type = 'lldb',
          request = 'launch',
          stopOnEntry = false,
          runInTerminal = true,
          console = 'integratedTerminal',
        },
      }
    end,
  },
}
