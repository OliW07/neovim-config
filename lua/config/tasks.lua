-- Slow commands run outside the UI thread. Captured cwd/argv keep paths safe.
local M = {}
local busy = {}

function M.jobs()
  return vim.uv.available_parallelism and vim.uv.available_parallelism() or math.max(1, #(vim.uv.cpu_info() or {}))
end

function M.run(cmd, cwd, done)
  local key = cwd .. '\0' .. cmd[1]
  if busy[key] then
    vim.notify(cmd[1] .. ' is already running in ' .. cwd, vim.log.levels.WARN)
    return
  end
  busy[key] = true
  vim.notify('Running ' .. cmd[1] .. '…')
  local ok, job = pcall(vim.system, cmd, { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      busy[key] = nil
      if result.code ~= 0 then
        local output = (result.stdout or '') .. '\n' .. (result.stderr or '')
        local lines = vim.split(output, '\n')
        table.insert(lines, 1, '__NVIM_TASK_CWD__' .. cwd)
        vim.fn.setqflist({}, ' ', { title = table.concat(cmd, ' '), lines = lines, efm = '%D__NVIM_TASK_CWD__%f,' .. vim.o.errorformat })
        vim.cmd 'copen'
        vim.notify(cmd[1] .. ' failed; output is in quickfix', vim.log.levels.ERROR)
      else
        vim.notify(cmd[1] .. ' finished')
        if done then
          done(result)
        end
      end
    end)
  end)
  if not ok then
    busy[key] = nil
    vim.notify(tostring(job), vim.log.levels.ERROR)
  end
  return ok and job or nil
end

local function project_path()
  if vim.bo.filetype == 'oil' then
    return require('oil').get_current_dir()
  end
  local path = vim.b.review_lsp_path or vim.api.nvim_buf_get_name(0)
  if path ~= '' and not path:match '^%a[%w+.-]*://' then
    return path
  end
end

function M.save_project(root)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' and vim.bo[buf].modified then
      local path = vim.api.nvim_buf_get_name(buf)
      if path ~= '' and vim.fs.relpath(root, path) then
        vim.api.nvim_buf_call(buf, vim.cmd.update)
      end
    end
  end
end

local function cmake_root()
  local path = project_path() or vim.fn.getcwd()
  local cwd = vim.fn.getcwd()
  local selected = vim.fs.abspath(require('cmake-tools').get_config().cwd)
  if selected ~= cwd and vim.fn.filereadable(selected .. '/CMakeLists.txt') == 1 then
    return selected -- :CMakeSelectCwd sets the plugin's source directory directly.
  end
  local nearest = vim.fs.root(path, 'CMakeLists.txt')
  if not nearest then
    return
  end
  local boundary = vim.fs.root(nearest, '.git')
  local root = nearest
  local dir = nearest
  while dir do
    if vim.fn.filereadable(dir .. '/CMakeLists.txt') == 1 then
      root = dir
      if
        (dir == cwd and vim.fn.haslocaldir(-1, 0) == 2)
        or vim.fn.filereadable(dir .. '/CMakePresets.json') == 1
        or vim.fn.filereadable(dir .. '/CMakeUserPresets.json') == 1
      then
        break
      end
    end
    local parent = vim.fs.dirname(dir)
    if dir == boundary or dir == parent then
      break
    end
    dir = parent
  end
  return root
end

function M.cmake(command)
  local root = cmake_root()
  if not root then
    return vim.notify('No CMakeLists.txt found', vim.log.levels.WARN)
  end
  if vim.fn.getcwd() ~= root then
    vim.cmd.tcd(vim.fn.fnameescape(root))
  end
  local cmake = require 'cmake-tools'
  if (command == 'CMakeRun' or command == 'CMakeDebug') and not cmake.get_build_targets():is_ok() then
    -- Configure first. The pinned runner stops after generating its first code model.
    cmake.generate({ bang = false, fargs = {} }, function(result)
      if result:is_ok() and cmake.get_config().cwd == root then
        vim.cmd(command)
      end
    end)
  else
    vim.cmd(command)
  end
end

function M.file_action()
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local file, ft = vim.api.nvim_buf_get_name(buf), vim.bo[buf].filetype
  local python = ft == 'python'
  if vim.bo[buf].buftype ~= '' or file == '' or file:match '^%a[%w+.-]*://' or not (python or ft == 'c' or ft == 'cpp' or ft == 'cmake') then
    return vim.notify('Open a Python, C, C++ or CMake file first', vim.log.levels.INFO)
  end
  local actions = python and { 'Run', 'Debug' } or { 'Build', 'Run', 'Debug' }
  vim.ui.select(actions, { prompt = 'Action for ' .. vim.fs.basename(file) }, function(action)
    if not action or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
      return
    end
    vim.api.nvim_set_current_win(win)
    if not python then
      return M.cmake('CMake' .. action)
    end
    vim.cmd.update()
    local launch = require('config.dap').python_launch(file)
    if action == 'Debug' then
      require('dap').run(launch)
    else
      vim.cmd 'botright 12new'
      if vim.fn.jobstart({ launch.pythonPath, file }, { term = true, cwd = launch.cwd }) > 0 then
        vim.cmd.startinsert()
      else
        vim.cmd.bwipeout()
        vim.notify('Could not start ' .. launch.pythonPath, vim.log.levels.ERROR)
      end
    end
  end)
end

function M.format_project()
  local path = project_path()
  local root = path and vim.fs.root(path, '.git')
  if not root then
    return vim.notify('Open a file or directory in a Git project first', vim.log.levels.WARN)
  end
  if vim.fn.executable 'rg' ~= 1 or vim.fn.executable 'clang-format' ~= 1 then
    return vim.notify('Project formatting requires rg and clang-format', vim.log.levels.ERROR)
  end
  local dirs = {}
  for _, name in ipairs { 'src', 'tools' } do
    if vim.fn.isdirectory(root .. '/' .. name) == 1 then
      dirs[#dirs + 1] = name
    end
  end
  if #dirs == 0 then
    return vim.notify('No src/ or tools/ directory found', vim.log.levels.WARN)
  end
  local cmd = { 'rg', '--files', '-0', '-g', '*.c', '-g', '*.cc', '-g', '*.cpp', '-g', '*.h', '-g', '*.hpp' }
  vim.list_extend(cmd, dirs)
  vim.system(cmd, { cwd = root }, function(result)
    vim.schedule(function()
      if result.code == 1 and result.stdout == '' then
        return vim.notify 'No C/C++ source files found'
      end
      if result.code ~= 0 then
        return vim.notify(result.stderr, vim.log.levels.ERROR)
      end
      local files = vim.split(result.stdout, '\0', { trimempty = true, plain = true })
      -- Batches avoid OS argument-size limits on large projects.
      local index = 1
      local function next_batch()
        if index > #files then
          vim.cmd 'checktime'
          return
        end
        local args = { 'clang-format', '-i', '--' }
        for _ = 1, 100 do
          if not files[index] then
            break
          end
          local file = vim.fs.joinpath(root, files[index])
          local buf = vim.fn.bufnr(file)
          if buf ~= -1 and vim.api.nvim_buf_get_name(buf) == file and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
            vim.api.nvim_buf_call(buf, vim.cmd.update)
          end
          args[#args + 1] = files[index]
          index = index + 1
        end
        M.run(args, root, next_batch)
      end
      next_batch()
    end)
  end)
end

function M.show_commit()
  local file, line = vim.api.nvim_buf_get_name(0), vim.fn.line '.'
  if vim.bo.buftype ~= '' or file == '' then
    return vim.notify 'Open a working-tree file first'
  end
  local root = vim.fs.root(file, '.git')
  if not root then
    return vim.notify 'Not inside a Git repository'
  end
  -- Blame the line as displayed, including inserted and deleted unsaved lines.
  local contents = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  if vim.bo.endofline then
    contents = contents .. '\n'
  end
  local cmd = { 'git', 'blame', '--contents', '-', '--porcelain', '-L', line .. ',' .. line, '--', file }
  vim.system(cmd, { cwd = root, text = true, stdin = contents }, function(result)
    vim.schedule(function()
      local commit = result.code == 0 and result.stdout:match '^(%x+)'
      if not commit or commit:match '^0+$' then
        return vim.notify 'No committed change for this line'
      end
      -- Fugitive resolves its repository from the originating file.
      vim.cmd('tabedit ' .. vim.fn.fnameescape(file))
      vim.cmd('G show ' .. commit)
    end)
  end)
end

return M
