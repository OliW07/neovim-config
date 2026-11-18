-- Durable drafts are identified by repository AND PR, independent of cwd.
local M = {}

function M.path(directory, pr, suffix)
  assert(pr._root, 'Review draft requires a captured repository root')
  local identity = pr._repo and (pr._repo.host .. '/' .. pr._repo.slug) or vim.fs.normalize(pr._root)
  return ('%s/%s/%d%s'):format(directory, vim.fn.sha256(identity), pr.number, suffix)
end

function M.read(path, default)
  if vim.fn.filereadable(path) == 0 then
    return default
  end
  local ok, value = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  end)
  if not ok or type(value) ~= 'table' then
    error('Invalid review draft; preserved at ' .. path)
  end
  return value
end

function M.write(path, value)
  vim.fn.mkdir(vim.fs.dirname(path), 'p', '0700')
  local temporary = path .. '.' .. vim.fn.getpid() .. '.tmp'
  local ok, err = pcall(function()
    vim.fn.writefile({ vim.json.encode(value) }, temporary)
    assert(vim.uv.fs_rename(temporary, path))
  end)
  if not ok then
    vim.fn.delete(temporary)
    error('Could not save review draft: ' .. tostring(err))
  end
end

function M.acknowledge(path, sent)
  local ids, kept = {}, {}
  for _, item in ipairs(sent) do
    ids[item.id] = true
  end
  for _, item in ipairs(M.read(path, {})) do
    if not ids[item.id] then
      kept[#kept + 1] = item
    end
  end
  M.write(path, kept)
end

return M
