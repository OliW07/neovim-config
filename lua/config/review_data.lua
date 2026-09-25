-- Repository-scoped caches survive :qa. Only successful responses are stored.
local M = { cache_dir = vim.fn.stdpath 'cache' .. '/pr-review-v2' }
local cache, pending = {}, {}
M.fields = table.concat({
  'number',
  'title',
  'body',
  'author',
  'baseRefName',
  'baseRefOid',
  'headRefName',
  'headRefOid',
  'isDraft',
  'url',
  'reviewDecision',
}, ',')
local summary_fields = table.concat({
  'number',
  'title',
  'state',
  'isDraft',
  'author',
  'baseRefName',
  'headRefName',
  'url',
  'body',
  'labels',
  'reviewDecision',
  'additions',
  'deletions',
  'changedFiles',
  'comments',
  'reviews',
  'commits',
}, ',')
local function key_for(root, kind, id)
  return vim.fn.sha256(root .. '\0' .. kind .. '\0' .. tostring(id))
end
local function load_entry(key)
  local entry = cache[key]
  if entry ~= nil then
    return entry or nil
  end
  local ok, lines = pcall(vim.fn.readfile, M.cache_dir .. '/' .. key .. '.json')
  if ok then
    local decoded, value = pcall(vim.json.decode, table.concat(lines, '\n'))
    if decoded and type(value) == 'table' then
      entry = value
    end
  end
  -- Remember misses so a missing file is not re-read on every picker open.
  cache[key] = entry or false
  return entry
end

local function read(key, ttl)
  local entry = load_entry(key)
  if entry and type(entry.time) == 'number' and os.time() >= entry.time and os.time() - entry.time < ttl then
    return entry.data
  end
end
local function write(key, data)
  local entry = { time = os.time(), data = data }
  cache[key] = entry
  -- Cache I/O failure should never stop a review. Rename prevents partial reads
  -- when two Neovim processes are reviewing the same repository.
  pcall(function()
    vim.fn.mkdir(M.cache_dir, 'p', '0700')
    local path = M.cache_dir .. '/' .. key .. '.json'
    local temporary = path .. '.' .. vim.fn.getpid() .. '.tmp'
    vim.fn.writefile({ vim.json.encode(entry) }, temporary)
    vim.uv.fs_rename(temporary, path)
  end)
end
local function request(root, kind, id, cmd, ttl, validate, callback, force)
  local key = key_for(root, kind, id)
  local hit = not force and read(key, ttl)
  if hit and validate(hit) then
    callback(nil, vim.deepcopy(hit), true)
    return function() end
  end
  local job = pending[key]
  local listener = { callback = callback }
  if job then
    table.insert(job.listeners, listener)
  else
    job = { listeners = { listener } }
    pending[key] = job
    job.process = vim.system(cmd, { cwd = root, text = true, timeout = 30000 }, function(result)
      vim.schedule(function()
        if pending[key] ~= job then
          return
        end
        pending[key] = nil
        local err, data
        if result.code ~= 0 then
          err = 'gh ' .. kind .. ' failed: ' .. (result.stderr or '')
        else
          local ok, decoded = pcall(vim.json.decode, result.stdout)
          if ok and validate(decoded) then
            data = decoded
            write(key, data)
          else
            err = 'could not parse gh output'
          end
        end
        for _, item in ipairs(job.listeners) do
          if item.callback then
            item.callback(err, vim.deepcopy(data), false)
          end
        end
      end)
    end)
  end
  return function()
    listener.callback = nil
    vim.defer_fn(function()
      if pending[key] ~= job then
        return
      end
      for _, item in ipairs(job.listeners) do
        if item.callback then
          return
        end
      end
      pending[key] = nil
      job.process:kill(15)
    end, 100)
  end
end
local function valid_pr(number)
  return function(data)
    return type(data) == 'table' and data.number == tonumber(number)
  end
end
local function valid_summary(number)
  return function(data)
    -- Reject pre-commits cache entries so the timeline refetches.
    return valid_pr(number)(data) and type(data.commits) == 'table'
  end
end
-- Synchronous local lookup lets the picker paint before any debounce/network work.
function M.peek_summary(root, number)
  local hit = read(key_for(root, 'summary', number), 300)
  if hit and valid_summary(number)(hit) then
    return vim.deepcopy(hit)
  end
end
function M.summary(root, number, callback, force)
  return request(root, 'summary', number, { 'gh', 'pr', 'view', tostring(number), '--json', summary_fields }, 300, valid_summary(number), callback, force)
end
function M.metadata(root, number, callback, force)
  return request(root, 'metadata', number, { 'gh', 'pr', 'view', tostring(number), '--json', M.fields }, 300, valid_pr(number), callback, force)
end
function M.commits(root, number, callback, force)
  return request(root, 'commits', number, { 'gh', 'pr', 'view', tostring(number), '--json', 'commits' }, 300, function(data)
    return type(data) == 'table' and type(data.commits) == 'table'
  end, callback, force)
end
-- Line comments on the diff. `gh pr view --json comments` is only the
-- conversation thread; these live on a separate REST list.
function M.review_comments(root, number, callback, force)
  return request(
    root,
    'review_comments',
    number,
    { 'gh', 'api', '--paginate', ('repos/:owner/:repo/pulls/%s/comments'):format(number) },
    300,
    function(data)
      return type(data) == 'table' and vim.islist(data)
    end,
    callback,
    force
  )
end
function M.list(root, search, limit, callback, force)
  return request(
    root,
    'list',
    search .. '\0' .. limit,
    {
      'gh',
      'pr',
      'list',
      '--state',
      'open',
      '--search',
      search,
      '--limit',
      tostring(limit),
      '--json',
      M.fields,
    },
    300,
    function(data)
      if type(data) ~= 'table' or not vim.islist(data) then
        return false
      end
      for _, pr in ipairs(data) do
        if type(pr) ~= 'table' or not pr.number then
          return false
        end
      end
      return true
    end,
    callback,
    force
  )
end

-- Drop a PR from already-cached `gh pr list` results. The picker keys lists by
-- search + limit, so pass every search this repo actually uses. No GitHub call.
function M.remove_from_lists(root, searches, limit, number)
  number = tonumber(number)
  if not root or type(searches) ~= 'table' or not number then
    return
  end
  for _, search in ipairs(searches) do
    local key = key_for(root, 'list', search .. '\0' .. tostring(limit))
    local entry = load_entry(key)
    local data = entry and entry.data
    if type(data) == 'table' and vim.islist(data) then
      local kept, changed = {}, false
      for _, pr in ipairs(data) do
        if tonumber(pr.number) == number then
          changed = true
        else
          kept[#kept + 1] = pr
        end
      end
      if changed then
        write(key, kept)
      end
    end
  end
end

-- A cache hit must also match the actual local refs. Deleting/changing refs,
-- changing the PR's target branch, or a new head/base SHA bypasses the cache.
local fetching = {}
function M.fetch(root, remote, pr, callback, force)
  local ref = ('refs/pr/%d'):format(pr.number)
  local base = ('refs/remotes/%s/%s'):format(remote, pr.baseRefName)
  local key = key_for(root, 'fetch', remote .. '\0' .. pr.number .. '\0' .. pr.baseRefName)
  local active = fetching[key]
  if active then
    table.insert(active.listeners, callback)
    active.force = active.force or force or pr.headRefOid ~= active.head or pr.baseRefOid ~= active.base
    return
  end
  local job = { listeners = { callback }, force = force, head = pr.headRefOid, base = pr.baseRefOid }
  fetching[key] = job
  local function complete(err, refs, cached)
    local listeners = fetching[key].listeners
    fetching[key] = nil
    for _, listener in ipairs(listeners) do
      listener(err, refs, cached)
    end
  end
  local function refs(done)
    vim.system({ 'git', 'rev-parse', ref, base }, { cwd = root, text = true }, function(result)
      vim.schedule(function()
        local values = vim.split(result.stdout or '', '\n', { trimempty = true })
        if result.code ~= 0 or #values ~= 2 or not values[1]:match '^%x+$' or not values[2]:match '^%x+$' then
          return done(nil)
        end
        done { head = values[1], base = values[2] }
      end)
    end)
  end
  local function fetch()
    vim.system({
      'git',
      'fetch',
      '--no-tags',
      '--no-recurse-submodules',
      '--no-auto-maintenance',
      remote,
      ('+refs/pull/%d/head:%s'):format(pr.number, ref),
      ('+refs/heads/%s:%s'):format(pr.baseRefName, base),
    }, { cwd = root, text = true, timeout = 60000 }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          return complete('fetch failed: ' .. (result.stderr or ''), nil, false)
        end
        refs(function(actual)
          if not actual then
            return complete('fetched PR refs could not be resolved', nil, false)
          end
          actual.requested_head, actual.requested_base = pr.headRefOid, pr.baseRefOid
          write(key, actual)
          complete(nil, actual, false)
        end)
      end)
    end)
  end
  local hit = not force and read(key, 300)
  if
    type(hit) ~= 'table'
    or (pr.headRefOid and pr.headRefOid ~= hit.head and pr.headRefOid ~= hit.requested_head)
    or (pr.baseRefOid and pr.baseRefOid ~= hit.base and pr.baseRefOid ~= hit.requested_base)
  then
    return fetch()
  end
  refs(function(actual)
    if not job.force and actual and actual.head == hit.head and actual.base == hit.base then
      complete(nil, actual, true)
    else
      fetch()
    end
  end)
end
-- Keep speculative Git traffic bounded. A running fetch finishes into the cache;
-- only the latest still-visible selection can start after it. Foreground opens
-- share M.fetch's in-flight request, even after the picker has closed.
local prefetch_running, prefetch_queued
local function drain_prefetch()
  if prefetch_running or not prefetch_queued then
    return
  end
  local item = prefetch_queued
  prefetch_queued, prefetch_running = nil, item
  M.fetch(item.root, item.remote, item.pr, function()
    prefetch_running = nil
    drain_prefetch()
  end)
end
function M.prefetch(root, remote, pr)
  local item = { root = root, remote = remote, pr = vim.deepcopy(pr) }
  prefetch_queued = item
  drain_prefetch()
  return function()
    if prefetch_queued == item then
      prefetch_queued = nil
    end
  end
end
return M
