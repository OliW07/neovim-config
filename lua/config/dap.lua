local M = {}

local function executable(candidates)
  for _, candidate in ipairs(candidates) do
    local path = vim.fn.exepath(candidate)
    if path ~= '' then
      return path
    end
  end
end

function M.python_launch(file)
  local root = vim.fs.root(file, { { '.venv', 'venv', 'pyproject.toml', 'setup.py', 'requirements.txt', '.git' } }) or vim.fs.dirname(file)
  local candidates = {}
  for _, directory in ipairs { vim.env.VIRTUAL_ENV or '', vim.env.CONDA_PREFIX or '', root .. '/.venv', root .. '/venv' } do
    if directory ~= '' then
      candidates[#candidates + 1] = directory .. (vim.fn.has 'win32' == 1 and '/Scripts/python.exe' or '/bin/python')
    end
  end
  vim.list_extend(candidates, { 'python3', 'python' })
  return {
    name = 'Launch Python file',
    type = 'python',
    request = 'launch',
    program = file,
    cwd = root,
    pythonPath = executable(candidates) or error 'No Python interpreter found',
    console = 'integratedTerminal',
  }
end

function M.setup()
  local dap, ui = require 'dap', require 'dapui'
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
      error 'C/C++ debugging needs lldb-dap (LLVM).'
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
  dap.configurations.python = {
    setmetatable({ name = 'Launch Python file', type = 'python', request = 'launch' }, {
      __call = function()
        return M.python_launch(vim.api.nvim_buf_get_name(0))
      end,
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
end

return M
