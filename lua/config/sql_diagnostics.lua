local M = {}
M.namespace = vim.api.nvim_create_namespace 'clickhouse-syntax'
local generations = {}
local jobs = {}
local data = vim.fn.stdpath 'data' .. '/sql-schema'

function M.check(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  generations[buf] = (generations[buf] or 0) + 1
  local generation = generations[buf]
  if jobs[buf] then
    pcall(jobs[buf].kill, jobs[buf], 15)
    jobs[buf] = nil
  end
  if not vim.api.nvim_buf_is_loaded(buf) or not require('config.buffer').editable(buf) then
    vim.diagnostic.reset(M.namespace, buf)
    return
  end
  local dialect = require('config.sql').dialect(buf)
  if dialect == 'redis' then
    return
  end -- The upstream server handles this non-SQL dialect.
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  jobs[buf] = vim.system(
    { data .. '/venv/bin/python', vim.fn.stdpath 'config' .. '/scripts/sql-diagnostics.py', dialect },
    { stdin = text, text = true, timeout = 10000 },
    function(result)
      vim.schedule(function()
        if
          not vim.api.nvim_buf_is_valid(buf)
          or not vim.api.nvim_buf_is_loaded(buf)
          or generations[buf] ~= generation
          or vim.api.nvim_buf_get_changedtick(buf) ~= tick
        then
          return
        end
        jobs[buf] = nil
        local ok, diagnostics = pcall(vim.json.decode, result.stdout or '')
        if result.code ~= 0 or not ok then
          vim.diagnostic.reset(M.namespace, buf)
          vim.notify('SQL syntax validation failed (' .. dialect .. '): ' .. (result.stderr or ''), vim.log.levels.ERROR)
          return
        end
        vim.diagnostic.set(M.namespace, buf, diagnostics)
      end)
    end
  )
end

function M.attach(buf, root)
  -- The catalog loader separately validates schema exports (including omitted semicolons).
  if vim.api.nvim_buf_get_name(buf) == root .. '/schema.sql' then
    return
  end
  local group = vim.api.nvim_create_augroup('clickhouse-syntax-' .. buf, { clear = true })
  local pending = 0
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufWritePost' }, {
    group = group,
    buffer = buf,
    callback = function()
      pending = pending + 1
      generations[buf] = (generations[buf] or 0) + 1
      if jobs[buf] then
        pcall(jobs[buf].kill, jobs[buf], 15)
        jobs[buf] = nil
      end
      local request = pending
      vim.defer_fn(function()
        if request == pending then
          M.check(buf)
        end
      end, 300)
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      pending = pending + 1
      generations[buf] = nil
      if jobs[buf] then
        pcall(jobs[buf].kill, jobs[buf], 15)
        jobs[buf] = nil
      end
      vim.diagnostic.reset(M.namespace, buf)
    end,
  })
  M.check(buf)
end

return M
