local M = {}
function M.setup()
  local lint = require 'lint'
  lint.linters.cppcheck.args = vim.list_extend(vim.deepcopy(lint.linters.cppcheck.args), { '--suppress=unusedStructMember' })
  lint.linters.staticcheck.append_fname = false -- Check the package from its directory, not one isolated file.
  lint.linters_by_ft = {
    python = { 'ruff' },
    lua = { 'selene' },
    c = { 'cppcheck' },
    cpp = { 'cppcheck' },
    go = { 'staticcheck' },
    sh = { 'shellcheck' },
    bash = { 'shellcheck' },
    yaml = { 'yamllint' },
  }
  local pending, checked = {}, {}
  local group = vim.api.nvim_create_augroup('lint', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave' }, {
    group = group,
    callback = function(event)
      local buf = event.buf
      if not require('config.buffer').editable(buf) then
        return
      end
      local ft = vim.bo[buf].filetype
      if ft == 'go' and event.event ~= 'BufWritePost' then
        return
      end
      if (ft == 'c' or ft == 'cpp') and event.event == 'InsertLeave' then
        return
      end
      local names = lint.linters_by_ft[ft]
      if not names or #names == 0 then
        return
      end
      pending[buf] = (pending[buf] or 0) + 1
      local sequence = pending[buf]
      vim.defer_fn(function()
        if pending[buf] ~= sequence or not require('config.buffer').editable(buf) then
          return
        end
        local tick = vim.api.nvim_buf_get_changedtick(buf)
        if event.event ~= 'BufWritePost' and checked[buf] == tick then
          return
        end
        local file = vim.api.nvim_buf_get_name(buf)
        if file == '' then
          return
        end
        local root = vim.fs.root(file, { 'selene.toml', '.git' }) or vim.fs.dirname(file)
        if ft == 'lua' and not vim.fs.root(file, 'selene.toml') then
          return
        end
        local available = {}
        for _, name in ipairs(names) do
          local linter = lint.linters[name]
          local command = type(linter.cmd) == 'function' and linter.cmd() or linter.cmd
          if vim.fn.executable(command) == 1 then
            available[#available + 1] = name
          end
        end
        if #available == 0 then
          return
        end
        checked[buf] = tick
        vim.api.nvim_buf_call(buf, function()
          lint.try_lint(available, { cwd = ft == 'go' and vim.fs.dirname(file) or root })
        end)
      end, 200)
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    callback = function(event)
      pending[event.buf], checked[event.buf] = nil, nil
    end,
  })
end
return M
