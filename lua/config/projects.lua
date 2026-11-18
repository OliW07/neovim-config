local M = {}

local tsserver_path = 'node_modules/typescript/lib/tsserver.js'

-- A ts_ls client has one SDK. Give packages with their own SDK distinct clients.
function M.typescript_root(buf, workspace)
  local path = vim.b[buf].review_lsp_path or vim.api.nvim_buf_get_name(buf)
  for dir in vim.fs.parents(path) do
    if not vim.fs.relpath(workspace, dir) then
      break
    end
    if vim.fn.filereadable(vim.fs.joinpath(dir, tsserver_path)) == 1 then
      return dir
    end
  end
  return workspace
end

local function package_biome_config(bufnr)
  local package_root = vim.fs.root(bufnr, 'package.json')
  local project_root = vim.fs.root(bufnr, {
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'bun.lockb',
    'bun.lock',
    '.git',
  }) or package_root
  if not project_root then
    return false
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local config = vim.fs.find({ 'biome.json', 'biome.jsonc' }, {
    path = vim.fs.dirname(filename),
    type = 'file',
    upward = true,
    -- find() excludes the stop directory; include the project root itself.
    stop = vim.fs.dirname(project_root),
    limit = 1,
  })[1]

  if not config then
    return false
  end

  if not package_root then
    return config
  end

  local config_dir = vim.fs.dirname(config)
  if config_dir == project_root and vim.fn.filereadable(project_root .. '/pnpm-workspace.yaml') == 1 then
    return
  end

  if config_dir == package_root or vim.startswith(config_dir, package_root .. '/') then
    return config
  end
end

local function javascript_formatters(bufnr)
  if package_biome_config(bufnr) then
    return { 'biome' }
  end
  return { 'prettier' }
end

function M.ts_before_init(params, config)
  local tsserver = vim.fs.joinpath(config.root_dir, tsserver_path)
  if vim.fn.filereadable(tsserver) == 1 then
    config.init_options = vim.tbl_deep_extend('force', config.init_options or {}, { tsserver = { path = tsserver } })
    params.initializationOptions = config.init_options
  end
end
M.biome_config = package_biome_config
M.formatters = javascript_formatters
return M
