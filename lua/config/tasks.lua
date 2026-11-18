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

local function project(marker)
  local root = vim.fs.root(project_path() or vim.fn.getcwd(), marker)
  if not root then
    vim.notify('No ' .. marker .. ' found', vim.log.levels.WARN)
  end
  return root
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

function M.executables(dirs)
  local result, seen = {}, {}
  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      for name in vim.fs.dir(dir) do
        local path = vim.fs.joinpath(dir, name)
        if not seen[path] and vim.fn.isdirectory(path) == 0 and vim.fn.executable(path) == 1 then
          seen[path] = true
          result[#result + 1] = path
        end
      end
    end
  end
  table.sort(result)
  return result
end

local function choose_executable(root, callback, reselect)
  -- One file per root keeps independent editor sessions from clobbering other projects.
  local dir = vim.fs.joinpath(vim.fn.stdpath 'state', 'make-targets')
  local state = vim.fs.joinpath(dir, vim.fn.sha256(root))
  local previous
  if vim.fn.filereadable(state) == 1 then
    previous = vim.fn.readfile(state)[1]
  else
    local legacy = vim.fs.joinpath(vim.fn.stdpath 'data', 'make_last_exe.json')
    if vim.fn.filereadable(legacy) == 1 then
      local ok, targets = pcall(vim.json.decode, table.concat(vim.fn.readfile(legacy), '\n'))
      previous = ok and type(targets) == 'table' and targets[root] or nil
    end
  end
  if not reselect and type(previous) == 'string' and vim.fn.executable(previous) == 1 and vim.fn.isdirectory(previous) == 0 then
    return callback(previous)
  end
  local function selected(path)
    if not path or path == '' then
      return
    end
    path = vim.fn.fnamemodify(path, ':p')
    if vim.fn.executable(path) ~= 1 or vim.fn.isdirectory(path) == 1 then
      return vim.notify('Not an executable: ' .. path, vim.log.levels.ERROR)
    end
    vim.fn.mkdir(dir, 'p')
    local tmp = state .. '.' .. vim.fn.getpid()
    if vim.fn.writefile({ path }, tmp) ~= 0 or vim.fn.rename(tmp, state) ~= 0 then
      vim.fn.delete(tmp)
      vim.notify('Could not remember the Make target', vim.log.levels.WARN)
    end
    callback(path)
  end
  local candidates = M.executables { root .. '/build', root .. '/build/bin', root }
  if reselect then
    local browse = 'Enter a path…'
    table.insert(candidates, browse)
    return vim.ui.select(candidates, { prompt = 'Select Make executable:' }, function(path)
      if path == browse then
        vim.ui.input({ prompt = 'Executable: ', default = root .. '/', completion = 'file' }, selected)
      else
        selected(path)
      end
    end)
  end
  if #candidates == 1 then
    return selected(candidates[1])
  end
  if #candidates > 1 then
    return vim.ui.select(candidates, { prompt = 'Executable:' }, selected)
  end
  vim.ui.input({ prompt = 'Executable: ', default = root .. '/', completion = 'file' }, selected)
end

function M.make(action)
  local root = project 'Makefile'
  if not root then
    return
  end
  if action == 'select' then
    return choose_executable(root, function(path)
      vim.notify('Make target: ' .. path)
    end, true)
  end
  M.save_project(root)
  M.run({ 'make', '-j' .. M.jobs() }, root, function()
    if not action then
      return
    end
    choose_executable(root, function(exe)
      if action == 'debug' then
        require('dap').run { type = 'lldb', request = 'launch', program = exe, cwd = root, stopOnEntry = false }
      else
        vim.cmd 'botright 15new'
        vim.fn.jobstart({ exe }, { term = true, cwd = root })
        vim.cmd 'startinsert'
      end
    end)
  end)
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
  vim.cmd(command)
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
