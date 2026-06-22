vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic quickfix' })
vim.keymap.set('n', '<leader>Q', vim.diagnostic.setqflist, { desc = 'Open diagnostic qflist' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to upper window' })

vim.keymap.set('n', '<S-h>', '<C-w><C-h>', { desc = 'Move focus to left window' })
vim.keymap.set('n', '<S-l>', '<C-w><C-l>', { desc = 'Move focus to right window' })
vim.keymap.set('n', '<S-j>', '<C-w><C-j>', { desc = 'Move focus to lower window' })
vim.keymap.set('n', '<S-k>', '<C-w><C-k>', { desc = 'Move focus to upper window' })

vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w><C-h>', { desc = 'Move focus to left window' })
vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w><C-l>', { desc = 'Move focus to right window' })
vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w><C-j>', { desc = 'Move focus to lower window' })
vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w><C-k>', { desc = 'Move focus to upper window' })

vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and center' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center' })

vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next search result centered' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Prev search result centered' })

vim.keymap.set('n', '<leader>mp', '<cmd>MarkdownPreviewToggle<CR>', { desc = 'Markdown preview toggle' })
vim.keymap.set('n', '<leader>mz', '<cmd>ZenMode<CR>', { desc = 'Markdown zen mode' })
vim.keymap.set('n', '<leader>me', '<cmd>Pencil<CR>', { desc = 'Markdown edit mode' })
vim.keymap.set('n', '<leader>mn', '<cmd>noautocmd MarkdownPreviewStop<CR>', { desc = 'Markdown stop preview' })

vim.keymap.set({ 'n', 'x' }, '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set('n', '<leader>yp', function()
  local path = vim.fn.expand '%:p'
  path = path:gsub('^%a[%w.+-]*://', '')
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path)
end, { desc = 'Yank absolute file path' })
vim.keymap.set({ 'n', 'x' }, '<leader>p', '"+p', { desc = 'Paste from system clipboard' })
vim.keymap.set('n', '<leader>d', '"_d', { desc = 'Delete without yank' })
vim.keymap.set('n', '<leader>D', '"_D', { desc = 'Delete line without yank' })
vim.keymap.set({ 'n', 'x' }, '<leader>c', '"_c', { desc = 'Change without yank' })

vim.keymap.set('n', 'gp', '`[v`]', { desc = 'Select last pasted' })

vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = 'Save buffer' })
vim.keymap.set('n', '<leader>bd', '<cmd>bd<CR>', { desc = 'Delete buffer' })

vim.keymap.set('n', '<leader>ff', function()
  require('telescope.builtin').find_files()
end, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', function()
  require('telescope.builtin').live_grep()
end, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', function()
  require('telescope.builtin').buffers()
end, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', function()
  require('telescope.builtin').help_tags()
end, { desc = 'Help tags' })
vim.keymap.set('n', '<leader>fr', function()
  require('telescope.builtin').resume()
end, { desc = 'Resume last search' })
vim.keymap.set('n', '<leader>fc', function()
  require('telescope.builtin').colorscheme()
end, { desc = 'Find colorschemes' })

vim.keymap.set('n', '<leader>so', '<cmd>source<CR>', { desc = 'Source init.lua' })

vim.keymap.set('n', '<leader>gb', function()
  require('gitsigns').blame_line()
end, { desc = 'Git blame line' })

vim.keymap.set('n', '<leader>gS', function()
  local file = vim.fn.expand('%:p')
  local line = vim.fn.line('.')
  local cmd = 'git blame -L ' .. line .. ',' .. line .. ' -s ' .. vim.fn.shellescape(file)
  local output = vim.fn.system(cmd)
  local commit = output:match('^(%w+)')
  if commit and commit ~= '0000000000000000000000000000000000000000' then
    vim.cmd('tab G show ' .. commit)
  else
    vim.notify('No commit found for this line')
  end
end, { desc = 'Git show full commit for current line' })

-- Git hunk operations (gitsigns)
vim.keymap.set('n', '<leader>hs', function()
  require('gitsigns').stage_hunk()
end, { desc = 'Stage hunk' })
vim.keymap.set('n', '<leader>hr', function()
  require('gitsigns').reset_hunk()
end, { desc = 'Reset hunk' })
vim.keymap.set('n', '<leader>hp', function()
  require('gitsigns').preview_hunk()
end, { desc = 'Preview hunk' })
vim.keymap.set('n', '<leader>hu', function()
  require('gitsigns').undo_stage_hunk()
end, { desc = 'Undo stage hunk' })
vim.keymap.set('n', '<leader>hd', function()
  require('gitsigns').diffthis()
end, { desc = 'Diff this file' })
vim.keymap.set('v', '<leader>hs', function()
  require('gitsigns').stage_hunk { vim.fn.line('.'), vim.fn.line('v') }
end, { desc = 'Stage hunk' })
vim.keymap.set('v', '<leader>hr', function()
  require('gitsigns').reset_hunk { vim.fn.line('.'), vim.fn.line('v') }
end, { desc = 'Reset hunk' })

-- Git operations (fugitive)
vim.keymap.set('n', '<leader>gs', '<cmd>G<CR>', { desc = 'Git status' })
vim.keymap.set('n', '<leader>gl', '<cmd>G log<CR>', { desc = 'Git log' })
vim.keymap.set('n', '<leader>gc', '<cmd>Git commit<CR>', { desc = 'Git commit' })
vim.keymap.set('n', '<leader>gp', '<cmd>Git pull<CR>', { desc = 'Git pull' })
vim.keymap.set('n', '<leader>gP', '<cmd>Git push<CR>', { desc = 'Git push' })
vim.keymap.set('n', '<leader>gF', '<cmd>Git fetch<CR>', { desc = 'Git fetch' })

-- Makefile project: build, run, debug
local last_exe_file = vim.fn.stdpath('data') .. '/make_last_exe.json'
local last_exe = {}

local function load_last_exe()
  local ok, data = pcall(vim.fn.readfile, last_exe_file)
  if ok and #data > 0 then
    pcall(function() last_exe = vim.fn.json_decode(table.concat(data, '\n')) end)
  end
end

local function save_last_exe()
  vim.fn.writefile({ vim.fn.json_encode(last_exe) }, last_exe_file)
end

load_last_exe()

local function make_find_dir()
  local buf_path = vim.fn.expand '%:p'
  local dir = buf_path:gsub('^%a[%w.+-]*://', '')
  dir = vim.fn.fnamemodify(dir, ':h')
  if vim.fn.isdirectory(dir) ~= 1 then
    dir = vim.fn.getcwd()
  end
  local mf = vim.fn.findfile('Makefile', dir .. ';')
  if mf == '' then
    for _, sub in ipairs({ 'src', 'build', '.' }) do
      local p = dir .. '/' .. sub .. '/Makefile'
      if vim.fn.filereadable(p) == 1 then mf = p; break end
    end
  end
  if mf == '' then
    vim.notify('No Makefile found', vim.log.levels.ERROR)
    return nil
  end
  return vim.fn.fnamemodify(mf, ':h')
end

local function make_build()
  vim.cmd 'wa'
  local make_dir = make_find_dir()
  if not make_dir then return false end
  local nproc = tonumber(vim.fn.system('nproc')) or 1
  local out = vim.fn.system('make -j' .. nproc .. ' -C ' .. vim.fn.shellescape(make_dir) .. ' 2>&1')
  if vim.v.shell_error ~= 0 then
    local lines = vim.split(out, '\n')
    vim.notify('Build failed', vim.log.levels.ERROR)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
    vim.api.nvim_set_current_buf(buf)
    return false
  end
  vim.notify('Build OK', vim.log.levels.INFO)
  return make_dir
end

local function make_find_exe(make_dir)
  if last_exe[make_dir] and vim.fn.executable(last_exe[make_dir]) == 1 then
    return last_exe[make_dir]
  end
  local candidates = {}
  for _, pat in ipairs({ make_dir .. '/*', make_dir .. '/build/*', vim.fn.getcwd() .. '/*' }) do
    for _, f in ipairs(vim.fn.glob(pat, false, true)) do
      if vim.fn.executable(f) == 1 and not vim.fn.isdirectory(f) then
        table.insert(candidates, f)
      end
    end
  end
  local exe
  if #candidates == 1 then
    exe = candidates[1]
  elseif #candidates > 1 then
    local idx = vim.fn.inputlist(vim.list_extend({ 'Select executable:' }, candidates))
    if idx > 0 and idx <= #candidates then exe = candidates[idx] end
  end
  if not exe or exe == '' then
    exe = vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file')
  end
  if exe ~= '' then
    last_exe[make_dir] = exe
    save_last_exe()
  end
  return exe
end

vim.keymap.set('n', '<leader>mb', function()
  make_build()
end, { desc = 'Make build' })

vim.keymap.set('n', '<leader>mr', function()
  local make_dir = make_build()
  if not make_dir then return end
  local exe = make_find_exe(make_dir)
  if exe ~= '' and vim.fn.executable(exe) == 1 then
    vim.cmd('belowright 15split | terminal ' .. vim.fn.shellescape(exe))
  else
    vim.notify('No executable selected', vim.log.levels.WARN)
  end
end, { desc = 'Make build & run' })

vim.keymap.set('n', '<leader>md', function()
  local make_dir = make_build()
  if not make_dir then return end
  local exe = make_find_exe(make_dir)
  if exe ~= '' then
    require('dap').run {
      type = 'lldb',
      request = 'launch',
      program = exe,
      cwd = vim.fn.getcwd(),
      stopOnEntry = false,
      args = {},
      runInTerminal = true,
    }
  else
    vim.notify('No executable selected', vim.log.levels.WARN)
  end
end, { desc = 'Make build & debug' })

-- CMake helpers: always export compile_commands.json for LSP
local function cmake_find_build_dir()
  local buf_path = vim.fn.expand '%:p'
  local dir = buf_path:gsub('^%a[%w.+-]*://', '')
  dir = vim.fn.fnamemodify(dir, ':h')
  if vim.fn.isdirectory(dir) ~= 1 then
    dir = vim.fn.getcwd()
  end
  local cmake_file = vim.fn.findfile('CMakeLists.txt', dir .. ';')
  if cmake_file == '' then
    vim.notify('No CMakeLists.txt found', vim.log.levels.ERROR)
    return nil
  end
  return vim.fn.fnamemodify(cmake_file, ':h')
end

local function cmake_configure()
  local src_dir = cmake_find_build_dir()
  if not src_dir then return false end
  local build_dir = src_dir .. '/build'
  if vim.fn.isdirectory(build_dir) ~= 1 then
    vim.fn.mkdir(build_dir, 'p')
  end
  local cmd = 'cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -S ' .. vim.fn.shellescape(src_dir) .. ' -B ' .. vim.fn.shellescape(build_dir) .. ' 2>&1'
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('CMake configure failed', vim.log.levels.ERROR)
    return false
  end
  vim.notify('CMake configured (compile_commands.json generated)', vim.log.levels.INFO)
  return build_dir
end

local function cmake_build()
  vim.cmd 'wa'
  local src_dir = cmake_find_build_dir()
  if not src_dir then return false end
  local build_dir = src_dir .. '/build'
  if vim.fn.isdirectory(build_dir) ~= 1 then
    vim.notify('Build dir missing, run CMake configure first', vim.log.levels.WARN)
    return false
  end
  local nproc = tonumber(vim.fn.system('nproc')) or 1
  local out = vim.fn.system('cmake --build ' .. vim.fn.shellescape(build_dir) .. ' -j' .. nproc .. ' 2>&1')
  if vim.v.shell_error ~= 0 then
    local lines = vim.split(out, '\n')
    vim.notify('Build failed', vim.log.levels.ERROR)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
    vim.api.nvim_set_current_buf(buf)
    return false
  end
  vim.notify('Build OK', vim.log.levels.INFO)
  return build_dir
end

local function cmake_find_exe(build_dir)
  local candidates = {}
  local bin_dir = build_dir
  for _, dir in ipairs({ build_dir, build_dir .. '/bin', build_dir .. '/Debug', build_dir .. '/Release' }) do
    for _, f in ipairs(vim.fn.glob(dir .. '/*', false, true)) do
      if vim.fn.executable(f) == 1 and not vim.fn.isdirectory(f) then
        table.insert(candidates, f)
      end
    end
  end
  local exe
  if #candidates == 1 then
    exe = candidates[1]
  elseif #candidates > 1 then
    local idx = vim.fn.inputlist(vim.list_extend({ 'Select executable:' }, candidates))
    if idx > 0 and idx <= #candidates then exe = candidates[idx] end
  end
  if not exe or exe == '' then
    exe = vim.fn.input('Executable: ', build_dir .. '/', 'file')
  end
  return exe
end

vim.keymap.set('n', '<leader>cc', function()
  cmake_configure()
end, { desc = 'CMake configure (with compile_commands.json)' })

vim.keymap.set('n', '<leader>cb', function()
  cmake_build()
end, { desc = 'CMake build' })

vim.keymap.set('n', '<leader>cr', function()
  local build_dir = cmake_build()
  if not build_dir then return end
  local exe = cmake_find_exe(build_dir)
  if exe ~= '' and vim.fn.executable(exe) == 1 then
    vim.cmd('belowright 15split | terminal ' .. vim.fn.shellescape(exe))
  else
    vim.notify('No executable selected', vim.log.levels.WARN)
  end
end, { desc = 'CMake build & run' })

vim.keymap.set('n', '<leader>cd', function()
  local build_dir = cmake_build()
  if not build_dir then return end
  local exe = cmake_find_exe(build_dir)
  if exe ~= '' and vim.fn.executable(exe) == 1 then
    require('dap').run {
      type = 'lldb',
      request = 'launch',
      program = exe,
      cwd = vim.fn.getcwd(),
      stopOnEntry = false,
      args = {},
      runInTerminal = true,
    }
  else
    vim.notify('No executable selected', vim.log.levels.WARN)
  end
end, { desc = 'CMake build & debug' })
