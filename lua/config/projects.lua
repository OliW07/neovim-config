local M = {}

local typescript_filetypes = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
}

local function local_tsserver(bufnr, root_dir)
  local filename = vim.b[bufnr].review_lsp_path or vim.api.nvim_buf_get_name(bufnr)
  if filename == '' then
    return
  end

  local directory = vim.fs.dirname(filename)
  while directory and (not root_dir or directory == root_dir or vim.startswith(directory, root_dir .. '/')) do
    local candidate = vim.fs.joinpath(directory, 'node_modules', 'typescript', 'lib', 'tsserver.js')
    if (vim.uv or vim.loop).fs_stat(candidate) then
      return candidate
    end

    local parent = vim.fs.dirname(directory)
    if parent == directory then
      break
    end
    directory = parent
  end
end

local function project_tsserver(root_dir)
  local current = vim.api.nvim_get_current_buf()
  if typescript_filetypes[vim.bo[current].filetype] then
    local tsserver = local_tsserver(current, root_dir)
    if tsserver then
      return tsserver
    end
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and typescript_filetypes[vim.bo[bufnr].filetype] then
      local tsserver = local_tsserver(bufnr, root_dir)
      if tsserver then
        return tsserver
      end
    end
  end
end

local function package_biome_config(bufnr)
  local project_root = vim.fs.root(bufnr, {
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'bun.lockb',
    'bun.lock',
    '.git',
  })
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

  local package_root = vim.fs.root(bufnr, 'package.json')
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
  local tsserver = project_tsserver(config.root_dir)
  if tsserver then
    config.init_options = vim.tbl_deep_extend('force', config.init_options or {}, { tsserver = { path = tsserver } })
    params.initializationOptions = config.init_options
  end
end
M.biome_config = package_biome_config
M.formatters = javascript_formatters
return M
