vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/package/src', 'p')
root = vim.uv.fs_realpath(root)
vim.fn.mkdir(root .. '/.git', 'p')
vim.fn.writefile({ '{}' }, root .. '/package.json')
vim.fn.writefile({ '{}' }, root .. '/biome.json')
local project = require 'config.projects'
local standalone = vim.fn.bufadd(root .. '/index.ts')
assert(project.formatters(standalone)[1] == 'biome', 'standalone Biome config at project root must be included')
vim.fn.mkdir(root .. '/src/nested', 'p')
local source = vim.fn.bufadd(root .. '/src/nested/index.ts')
assert(project.formatters(source)[1] == 'biome', 'nested source must see standalone root Biome config')
vim.fn.writefile({ 'packages:', '  - package' }, root .. '/pnpm-workspace.yaml')
assert(project.formatters(source)[1] == 'prettier', 'including the root must preserve the pnpm workspace policy')
vim.fn.writefile({ '{}' }, root .. '/package/package.json')
local nested = vim.fn.bufadd(root .. '/package/src/index.ts')
assert(project.formatters(nested)[1] == 'prettier', 'workspace root Biome must not leak into unconfigured package')
vim.fn.writefile({ '{}' }, root .. '/package/biome.json')
assert(project.formatters(nested)[1] == 'biome', 'package-local Biome must win')
vim.fn.delete(root .. '/package/biome.json')
assert(project.formatters(nested)[1] == 'prettier', 'config removal must not leave stale formatter selection')
vim.fn.mkdir(root .. '/package/node_modules/typescript/lib', 'p')
vim.fn.writefile({}, root .. '/package/node_modules/typescript/lib/tsserver.js')
local review = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(review, 'diffview://' .. root .. '/.git/abc/package/src/index.ts')
vim.bo[review].filetype = 'typescript'
vim.b[review].review_lsp_path = root .. '/package/src/index.ts'
vim.api.nvim_set_current_buf(review)
local params, config = {}, { root_dir = root }
project.ts_before_init(params, config)
assert(params.initializationOptions.tsserver.path == root .. '/package/node_modules/typescript/lib/tsserver.js')
local limits = require 'config.buffer'
assert(not limits.large(review))
vim.api.nvim_buf_set_lines(review, 0, -1, false, { string.rep('a', limits.max_bytes + 1) })
assert(limits.large(review) and not limits.editable(review))
vim.fn.delete(root, 'rf')
print 'PASS formatter ownership, config changes, package TypeScript SDK, large-file limits'
vim.cmd 'qa!'
