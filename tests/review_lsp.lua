vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/package', 'p')
root = vim.uv.fs_realpath(root)
vim.fn.writefile({}, root .. '/.git')
vim.fn.writefile({ '{}' }, root .. '/package/package.json')
local view = { adapter = { ctx = { toplevel = root, dir = root .. '/.git/worktrees/test' } } }
package.loaded['diffview.lib'] = {
  get_current_view = function()
    return view
  end,
}
local review = require 'config.review'
local starts, resolved = {}, {}
vim.lsp.config('review_test', {
  cmd = { 'unused' },
  filetypes = { 'typescriptreact' },
  root_dir = function(bufnr, done)
    resolved[#resolved + 1] = vim.api.nvim_buf_get_name(bufnr)
    assert(not vim.api.nvim_buf_is_loaded(bufnr), 'root probe must not read working-tree files')
    done(vim.fs.root(bufnr, 'package.json'))
  end,
})
vim.lsp.config('review_declined', {
  cmd = { 'unused' },
  filetypes = { 'typescriptreact' },
  root_dir = function() end,
})
for _, name in ipairs { 'biome', 'eslint', 'tailwindcss' } do
  vim.lsp.config(name, { cmd = { 'unused' }, filetypes = { 'typescriptreact' }, root_dir = root })
end
vim.lsp.enable { 'review_test', 'review_declined', 'biome', 'eslint', 'tailwindcss' }
vim.lsp.start = function(config, opts)
  starts[#starts + 1] = { name = config.name, root = config.root_dir, buf = opts.bufnr }
  return 1
end
local function buffer(file)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'diffview://' .. view.adapter.ctx.dir .. '/abcdef/package/' .. file)
  vim.bo[buf].buftype = 'nowrite'
  vim.bo[buf].filetype = 'typescriptreact'
  return buf
end
local first = buffer 'example.tsx'
review.attach_diff_lsp(first)
review.attach_diff_lsp(first)
assert(#starts == 1 and starts[1].name:match '^review_test@review:', 'only isolated navigation server, once')
assert(starts[1].root == root .. '/package', 'honour package root callback: ' .. vim.inspect { starts = starts, root = root, resolved = resolved })
assert(resolved[1] == root .. '/package/example.tsx', 'worktree URI must resolve to real path')
assert(vim.uri_from_bufnr(first) == vim.uri_from_fname(resolved[1]), 'LSP uses review path')
assert(vim.fn.maparg('gd', 'n', false, true).buffer == nil, 'mappings must stay buffer local')
local second = buffer 'second.tsx'
vim.api.nvim_set_current_buf(second)
view._pr_overview_pending = true
review.prepare_diff_lsp(second)
vim.wait(200, function()
  return false
end)
assert(#starts == 1, 'summary-only imports must not start LSP')
view._pr_overview_pending = false
review.prepare_diff_lsp(second)
review.prepare_diff_lsp(second)
assert(
  vim.wait(500, function()
    return #starts == 2
  end),
  'visible diff must attach after overview'
)
assert(vim.fn.maparg('gd', 'n', false, true).buffer == 1, 'definition mapping preserved')
local third = buffer 'hidden.tsx'
review.prepare_diff_lsp(third)
vim.wait(200, function()
  return false
end)
assert(#starts == 2, 'hidden buffers must not start LSP')
vim.fn.delete(root, 'rf')
print 'PASS LSP package roots, worktree paths, excluded servers, idempotency, deferred visibility, mappings'
vim.cmd 'qa!'
