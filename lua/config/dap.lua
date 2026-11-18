local M = {}

local function executable(candidates)
  for _, candidate in ipairs(candidates) do
    local path = vim.fn.exepath(candidate)
    if path ~= '' then
      return path
    end
  end
end

function M.python()
  local root = vim.fs.root(0, { 'pyproject.toml', 'requirements.txt', '.git' }) or vim.fn.getcwd()
  local candidates = {}
  for _, directory in ipairs { vim.env.VIRTUAL_ENV or '', vim.env.CONDA_PREFIX or '', root .. '/.venv', root .. '/venv' } do
    if directory ~= '' then
      candidates[#candidates + 1] = directory .. (vim.fn.has 'win32' == 1 and '/Scripts/python.exe' or '/bin/python')
    end
  end
  vim.list_extend(candidates, { 'python3', 'python' })
  return executable(candidates) or error 'No Python interpreter found'
end

function M.setup()
  local dap, ui = require 'dap', require 'dapui'
  -- Installation is explicit; opening the debugger must not start downloads.
  require('mason-nvim-dap').setup { automatic_installation = false, ensure_installed = {} }
  dap.adapters.lldb = function(callback)
    local path = executable {
      'lldb-dap',
      'lldb-dap-22',
      'lldb-dap-21',
      'lldb-dap-20',
      'lldb-dap-19',
      'lldb-vscode',
      '/opt/homebrew/opt/llvm/bin/lldb-dap',
      '/usr/local/opt/llvm/bin/lldb-dap',
      '/Library/Developer/CommandLineTools/usr/bin/lldb-dap',
    }
    if not path then
      error 'C/C++ debugging needs lldb-dap (LLVM). Python and Go debugging are independent.'
    end
    callback { type = 'executable', command = path, name = 'lldb' }
  end
  dap.configurations.cpp = {
    {
      name = 'Launch executable',
      type = 'lldb',
      request = 'launch',
      program = function()
        return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/build/', 'file')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
      args = {},
    },
  }
  dap.configurations.c = dap.configurations.cpp
  dap.adapters.python = function(callback)
    local command = executable { 'debugpy-adapter' }
    if not command then
      error 'Python debugging needs :MasonInstall debugpy'
    end
    callback { type = 'executable', command = command }
  end
  local base = { type = 'python', request = 'launch', pythonPath = M.python, console = 'integratedTerminal' }
  dap.configurations.python = {
    vim.tbl_extend('force', base, { name = 'Launch file', program = '${file}' }),
    vim.tbl_extend('force', base, {
      name = 'Launch with args',
      program = '${file}',
      args = function()
        return vim.split(vim.fn.input 'Arguments: ', '%s+', { trimempty = true })
      end,
    }),
    vim.tbl_extend('force', base, {
      name = 'Django',
      program = function()
        local root = vim.fs.root(0, 'manage.py')
        return root and root .. '/manage.py' or vim.fn.input('manage.py: ', vim.fn.getcwd() .. '/', 'file')
      end,
      args = { 'runserver', '--noreload' },
    }),
  }
  ui.setup {
    icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
    controls = {
      icons = {
        pause = '⏸',
        play = '▶',
        step_into = '⏎',
        step_over = '⏭',
        step_out = '⏮',
        step_back = 'b',
        run_last = '▶▶',
        terminate = '⏹',
        disconnect = '⏏',
      },
    },
  }
  dap.listeners.after.event_initialized.dapui_config = function()
    ui.open()
  end
  require('dap-go').setup { delve = { detached = vim.fn.has 'win32' == 0 } }
  local go_adapter = dap.adapters.go
  dap.adapters.go = function(callback, config)
    go_adapter(function(adapter)
      adapter = vim.deepcopy(adapter)
      if adapter.executable then
        -- Delve builds in its own cwd; launch.cwd only sets the debuggee cwd.
        local program = type(config.program) == 'string' and config.program or vim.api.nvim_buf_get_name(0)
        adapter.executable.cwd = vim.fs.root(program, 'go.mod') or config.cwd or vim.fn.getcwd()
      end
      callback(adapter)
    end, config)
  end
end

return M
