vim.opt.rtp:prepend(vim.fn.getcwd())
local jobs = {}
vim.system = function(cmd, opts, callback)
  local job = { cmd = cmd, opts = opts, callback = callback }
  function job:kill()
    self.killed = true
  end
  jobs[#jobs + 1] = job
  return job
end
local data = require 'config.review_data'
data.cache_dir = vim.fn.tempname()
local function finish(job, result)
  job.callback(result or { code = 0, stdout = '{"number":7,"title":"example","commits":[]}' })
  vim.wait(20, function()
    return false
  end)
end
local received = 0
local function receive(err, pr)
  assert(not err and pr.number == 7)
  received = received + 1
end
local cancel = data.summary('/one', 7, receive)
data.summary('/one', 7, receive)
assert(#jobs == 1, 'in-flight requests must be shared')
cancel()
finish(jobs[1])
assert(received == 1, 'cancelled subscriber must not fire')
data.summary('/one', 7, receive)
assert(#jobs == 1 and received == 2, 'completed response must be cached')
data.summary('/two', 7, receive)
assert(#jobs == 2 and jobs[2].opts.cwd == '/two', 'cache must be repository scoped')
finish(jobs[2])
data.summary('/one', 7, receive, true)
assert(#jobs == 3, 'explicit refresh must bypass cache')
finish(jobs[3])
local unsubscribe = data.summary('/cancel', 7, receive)
unsubscribe()
vim.wait(200, function()
  return jobs[4].killed
end)
assert(jobs[4].killed, 'unused request must be cancelled')
finish(jobs[4])
local before = received
local leave = data.summary('/handoff', 7, receive)
leave()
data.summary('/handoff', 7, receive)
vim.wait(150, function()
  return false
end)
assert(not jobs[5].killed, 'opening must adopt a picker request')
finish(jobs[5])
assert(received == before + 1)
local failed
local function failure(err)
  failed = err
end
data.summary('/error', 7, failure)
finish(jobs[6], { code = 1, stderr = 'offline' })
assert(failed:find 'offline')
data.summary('/error', 7, failure)
assert(#jobs == 7, 'errors must not be cached')
finish(jobs[7], { code = 0, stdout = 'bad json' })
assert(failed == 'could not parse gh output')
-- Reloading the module simulates a fresh Neovim process reading the disk cache.
local directory = data.cache_dir
package.loaded['config.review_data'] = nil
local restarted = require 'config.review_data'
restarted.cache_dir = directory
local previous = #jobs
restarted.summary('/one', 7, receive)
assert(#jobs == previous, 'summary cache must survive restart')
local list_calls = 0
restarted.list('/one', 'review:required', 100, function(err, prs)
  assert(not err and #prs == 1)
  list_calls = list_calls + 1
end)
finish(jobs[#jobs], { code = 0, stdout = '[{"number":7}]' })
local after_list = #jobs
restarted.list('/one', 'review:required', 100, function(err, prs, hit)
  assert(not err and #prs == 1 and hit)
  list_calls = list_calls + 1
end)
assert(#jobs == after_list and list_calls == 2, 'repeat list must not launch gh')
restarted.list('/one', 'review:required', 100, function() end, true)
assert(#jobs == after_list + 1, 'forced list refresh bypasses cache')
finish(jobs[#jobs], { code = 0, stdout = '[]' })
package.loaded['config.review_data'] = nil
local fresh = require 'config.review_data'
fresh.cache_dir = directory
fresh.list('/one', 'review:required', 100, function(err, prs, hit)
  assert(not err and #prs == 0 and hit, 'empty list must survive restart')
end)
assert(#jobs == after_list + 1, 'restart must read list from disk')
fresh.list('/one', 'review-requested:@me', 100, function() end)
finish(jobs[#jobs], { code = 0, stdout = '[{"number":7,"title":"a"},{"number":8,"title":"b"}]' })
local jobs_before_drop = #jobs
fresh.remove_from_lists('/one', { 'review-requested:@me' }, 100, 7)
fresh.list('/one', 'review-requested:@me', 100, function(err, prs, hit)
  assert(not err and hit and #prs == 1 and prs[1].number == 8, 'approved PR must leave the cached list')
end)
assert(#jobs == jobs_before_drop, 'dropping a PR from the list must not refetch')
package.loaded['config.review_data'] = nil
local after_drop = require 'config.review_data'
after_drop.cache_dir = directory
after_drop.list('/one', 'review-requested:@me', 100, function(err, prs, hit)
  assert(not err and hit and #prs == 1 and prs[1].number == 8, 'list drop must survive restart')
end)
assert(#jobs == jobs_before_drop, 'restart after drop must not refetch')
local now = os.time
os.time = function()
  return now() + 301
end
local jobs_before_expire = #jobs
fresh.list('/one', 'review:required', 100, function() end)
assert(#jobs == jobs_before_expire + 1, 'expired list must request fresh data')
os.time = now
finish(jobs[#jobs], { code = 0, stdout = '[]' })
local pr = { number = 7, baseRefName = 'main', headRefOid = 'aaaa', baseRefOid = 'bbbb' }
local fetched
fresh.fetch('/one', 'origin', pr, function(err, refs, hit)
  assert(not err and not hit)
  fetched = refs
end)
finish(jobs[#jobs], { code = 0, stdout = '' })
finish(jobs[#jobs], { code = 0, stdout = 'aaaa\ncccc\n' })
assert(fetched and fetched.base == 'cccc')
local fetched_jobs = #jobs
fresh.fetch('/one', 'origin', pr, function(err, refs, hit)
  assert(not err and hit and refs.base == 'cccc', 'old advertised base must reuse fetched tip')
end)
assert(jobs[#jobs].cmd[2] == 'rev-parse')
finish(jobs[#jobs], { code = 0, stdout = 'aaaa\ncccc\n' })
assert(#jobs == fetched_jobs + 1, 'same advertised base must not repeatedly fetch')
pr.headRefOid = 'dddd'
fresh.fetch('/one', 'origin', pr, function() end)
assert(jobs[#jobs].cmd[2] == 'fetch', 'new advertised head must fetch')
finish(jobs[#jobs], { code = 1, stderr = 'offline' })
assert(fresh.peek_summary('/one', 7).number == 7, 'preview can read summary without a request')
local before_prefetch = #jobs
local a = { number = 10, baseRefName = 'main' }
fresh.prefetch('/prefetch', 'origin', a)
local adopted = false
fresh.fetch('/prefetch', 'origin', a, function(err)
  assert(not err)
  adopted = true
end)
assert(#jobs == before_prefetch + 1, 'opening must adopt speculative fetch')
fresh.prefetch('/prefetch', 'origin', { number = 11, baseRefName = 'main' })
local cancel_last = fresh.prefetch('/prefetch', 'origin', { number = 12, baseRefName = 'main' })
cancel_last()
assert(#jobs == before_prefetch + 1, 'background fetches must be bounded')
finish(jobs[#jobs], { code = 0, stdout = '' })
finish(jobs[#jobs], { code = 0, stdout = 'aaaa\ncccc\n' })
assert(adopted and #jobs == before_prefetch + 2, 'abandoned queued rows must not fetch')
fresh.prefetch('/prefetch', 'origin', { number = 20, baseRefName = 'main' })
fresh.prefetch('/prefetch', 'origin', { number = 21, baseRefName = 'main' })
fresh.prefetch('/prefetch', 'origin', { number = 22, baseRefName = 'main' })
finish(jobs[#jobs], { code = 1, stderr = 'offline' })
assert(table.concat(jobs[#jobs].cmd, ' '):find('refs/pull/22/head', 1, true), 'only latest queued row should fetch after failure')
finish(jobs[#jobs], { code = 1, stderr = 'offline' })
vim.fn.delete(directory, 'rf')
print 'PASS persistent summaries and list cache, sharing, cancellation, handoff, refresh, errors'
vim.cmd 'qa!'
