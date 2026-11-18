vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
root = vim.uv.fs_realpath(root)
for _, name in ipairs { 'a', 'b' } do
  vim.fn.mkdir(root .. '/' .. name, 'p')
  vim.fn.system { 'git', '-C', root .. '/' .. name, 'init', '-q' }
  vim.fn.system { 'git', '-C', root .. '/' .. name, 'remote', 'add', 'origin', 'https://github.com/example/' .. name .. '.git' }
end
local data = require 'config.review_data'
data.cache_dir = root .. '/cache'
local fetch = data.fetch
data.fetch = function(_, _, pr, callback)
  callback(nil, { head = pr.headRefOid, base = string.rep('b', 40) }, false)
end
local view = { adapter = { ctx = {} }, cur_entry = { path = 'sample.lua' }, cur_layout = { b = { id = vim.api.nvim_get_current_win() } } }
package.loaded['diffview.lib'] = {
  get_current_view = function()
    return view
  end,
}
vim.api.nvim_create_user_command('DiffviewOpen', function() end, { nargs = '*' })
local review, drafts = require 'config.review', require 'config.review_drafts'
review.config.notes_dir = root .. '/drafts'
review.config.overview_on_open, review.config.close_previous = false, false
local notifications, requests = {}, {}
vim.notify = function(message)
  notifications[#notifications + 1] = message
end
vim.fn.confirm = function()
  return 1
end
local original_system = vim.system
vim.system = function(cmd, opts, callback)
  assert(cmd[1] == 'gh' or (cmd[1] == 'git' and cmd[2] == 'cat-file'), 'unexpected external request: ' .. vim.inspect(cmd))
  requests[#requests + 1] = { cmd = cmd, opts = opts, callback = callback }
  return { kill = function() end }
end
local a = { number = 42, _root = root .. '/a', title = 'A', headRefOid = string.rep('a', 40), baseRefName = 'main' }
local b = { number = 42, _root = root .. '/b', title = 'B', headRefOid = string.rep('c', 40), baseRefName = 'main' }
review.open(a)
assert(a._repo.host == 'github.com' and a._repo.slug == 'example/a', 'HTTPS remote parsing')
local apath = drafts.path(review.config.notes_dir, a, '.comments.json')
review.notes()
local notes = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(notes, 0, -1, false, { 'draft from A' })
vim.cmd 'write'
review.open(b)
assert(apath ~= drafts.path(review.config.notes_dir, b, '.comments.json'), 'draft paths must differ across repositories')
review.notes()
assert(not table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('draft from A', 1, true), 'notes must not leak across repositories')
vim.bo.modified = false
review.open(a)
vim.cmd.cd(root .. '/b')
local function comment(id, body)
  return { id = id, path = 'sample.lua', side = 'RIGHT', line = 1, body = body, commit_id = a.headRefOid }
end
local first, second = comment('one', 'first'), comment('two', 'unsent')
drafts.write(apath, { first })
review.submit 'approve'
local request = requests[#requests]
assert(vim.tbl_contains(request.cmd, 'repos/example/a/pulls/42/reviews') and request.opts.cwd == a._root, 'submission must use captured repository')
local payload = vim.json.decode(request.opts.stdin)
assert(payload.body == 'draft from A' and payload.comments[1].id == nil and payload.comments[1].commit_id == nil, 'wire payload excludes local draft metadata')
local count = #requests
review.submit 'approve'
assert(#requests == count, 'duplicate submission must be blocked')
drafts.write(apath, { first, second })
request.callback { code = 0, stdout = '{}', stderr = '' }
vim.wait(20, function()
  return false
end)
assert(vim.deep_equal(drafts.read(apath, {}), { second }), 'only submitted comments may be removed')
drafts.write(apath, {})
review.close_pr()
local closing = requests[#requests]
assert(vim.tbl_contains(closing.cmd, 'github.com/example/a') and closing.opts.cwd == a._root, 'close must pin --repo and cwd')
review.open(b)
closing.callback { code = 0, stdout = '', stderr = '' }
vim.wait(20, function()
  return false
end)
assert(review.current == b, 'late close must not tear down a new review')
review.open(a)
review.open_commit { oid = string.rep('d', 40) }
local lookup = requests[#requests]
assert(lookup.opts.cwd == a._root)
review.open(b)
lookup.callback { code = 0, stdout = '', stderr = '' }
vim.wait(20, function()
  return false
end)
assert(review.current == b, 'late commit lookup must not resurrect a previous review')
review.open(a)
drafts.write(apath, { first })
a.headRefOid = string.rep('e', 40)
count = #requests
review.submit 'approve'
assert(#requests == count, 'head changes must reject stale full-PR anchors')
review.open(a)
view.cur_layout.b.id = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line one', 'line two' })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
review.reanchor(1)
local moved = drafts.read(apath, {})[1]
assert(moved.commit_id == a.headRefOid and moved.line == 2, 'reanchor captures the currently viewed revision and line')
view._review.commit_view = true
view.cur_layout.a = { id = vim.api.nvim_get_current_win() }
view.cur_layout.b.id = -1
review.reanchor(1)
assert(drafts.read(apath, {})[1].id == moved.id, 'commit-parent lines must not be mistaken for the PR base')
view.cur_layout.a, view._review.commit_view = nil, nil
view.cur_layout.b.id = vim.api.nvim_get_current_win()
vim.bo.modified = false
-- Failed second-stage submission must resume the same pending review.
vim.api.nvim_buf_set_lines(notes, 0, -1, false, { '' })
vim.api.nvim_buf_call(notes, function()
  vim.cmd 'write'
end)
review.submit 'comment'
local create = requests[#requests]
create.callback { code = 0, stdout = '{"id":99}', stderr = '' }
vim.wait(20, function()
  return false
end)
local event = requests[#requests]
assert(vim.tbl_contains(event.cmd, 'repos/example/a/pulls/42/reviews/99/events'))
event.callback { code = 1, stdout = '', stderr = 'fixture failure' }
vim.wait(20, function()
  return false
end)
assert(#drafts.read(apath, {}) == 1, 'failed pending review preserves draft')
review.submit 'comment'
local retry = requests[#requests]
assert(vim.tbl_contains(retry.cmd, 'repos/example/a/pulls/42/reviews/99/events'), 'retry must resume pending review, not create another')
retry.callback { code = 0, stdout = '{}', stderr = '' }
vim.wait(20, function()
  return false
end)
assert(#drafts.read(apath, {}) == 0)
-- A write error must preserve notes and the current review before any teardown.
vim.api.nvim_buf_set_lines(notes, 0, -1, false, { 'unsaved draft' })
local write_event = vim.api.nvim_create_autocmd('BufWriteCmd', {
  buffer = notes,
  callback = function()
    error 'simulated disk error'
  end,
})
review.config.close_previous = true
review.open(b)
assert(review.current == a and vim.api.nvim_buf_is_valid(notes) and vim.bo[notes].modified, 'failed note write must prevent teardown')
vim.api.nvim_del_autocmd(write_event)
vim.bo[notes].modified = false
-- Real cache/JSON callback receives two slurped pages.
data.review_comments(root .. '/a', 8, function(err, rows)
  assert(not err and #rows == 2 and rows[2].body == 'two', 'all paginated comments must be retained')
end, true)
assert(vim.tbl_contains(requests[#requests].cmd, '--slurp'))
requests[#requests].callback { code = 0, stdout = '[[{"body":"one"}],[{"body":"two"}]]', stderr = '' }
vim.wait(20, function()
  return false
end)
vim.system, data.fetch = original_system, fetch
vim.fn.delete(root, 'rf')
print 'PASS review repository identity, draft isolation, submission races, stale callbacks, anchor validation, pending retry, save failure, pagination'
vim.cmd 'qa!'
