-- PR review workflow.
--
-- Pick a PR that is waiting on your review, diff it against the branch it
-- actually targets (not your local HEAD), leave line comments, submit -- all
-- in nvim. Requires the `gh` CLI, plus telescope + diffview.
--
-- All review maps live under <leader>gr (which-key group "PR review").
-- Picker: <C-a> toggles the production-base filter, <C-o> switches between
-- your review-requested queue and every open PR still awaiting a review.
-- <leader>grl lists the PR's commits; pick one to diff just that commit.
-- In the summary, gf on a `commit/<sha>` token or any 7–40 hex hash
-- (e.g. 80a2cb79e2 in a comment) opens that commit's diff.
--
-- Diffview commit blobs are buftype=nowrite + a diffview:// name, so Neovim
-- will not auto-attach language servers. We attach them ourselves and present
-- the blob as the real project file so gd/grd resolve against the PR text.

local M = {}
local review_data = require 'config.review_data'
local open_generation = 0
local cancel_open_summary

M.config = {
  remote = 'origin',
  -- Only show PRs whose base is this branch. <C-a> in the picker toggles to
  -- every base. Set to nil to show everything by default.
  base_filter = 'production',
  -- <C-o> in the picker switches between this (your queue) and all_search.
  search = 'review-requested:@me',
  -- Open PRs that still need a review (anyone), not only ones assigned to you.
  all_search = 'review:required -is:draft',
  limit = 100,
  notes_dir = vim.fn.stdpath 'state' .. '/pr-review',
  -- Comment authors to hide in the PR summary. Plain substring, case
  -- insensitive -- 'vercel' covers 'vercel[bot]', and hyphens are literal
  -- so 'github-actions' matches.
  ignore_authors = {
    'vercel',
    'linear',
    'supabase',
    'coderabbit',
    'github-actions',
    'greptile',
    'chatgpt-codex',
    'codesmith',
    'blacksmith',
  },
  -- Land on the PR summary rather than the first file's diff. The file panel
  -- stays put; opening a file from it brings the diff back.
  overview_on_open = true,
  -- Opening a PR closes the diff view and buffers of the one before it.
  close_previous = true,
  -- Leave out PRs that already carry an approving review decision.
  hide_approved = true,
  -- Diff buffers need navigation, not a second lint/CSS indexing pipeline.
  review_lsp_exclude = { 'biome', 'eslint', 'tailwindcss' },
}

-- The PR currently being reviewed, as returned by `gh pr list --json`.
M.current = nil

-- Scratch buffers we created for the current PR, wiped when we move on.
M._scratch = {}

-- Forward declaration: the picker previews what <leader>gri renders, but that
-- lives further down the file.
local render_info

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'PR review' })
end

local function have_gh()
  if vim.fn.executable 'gh' == 1 then
    return true
  end
  notify('gh CLI not found -- brew install gh && gh auth login', vim.log.levels.ERROR)
  return false
end

local function git_root()
  -- Filesystem lookup handles .git directories and linked-worktree .git files
  -- without blocking the editor on a shell process for every request/buffer.
  return vim.fs.root(vim.fn.getcwd(), '.git')
end

--- Run against the captured repository, even if the user changes tabs.
local function run(cmd, on_done, opts)
  local options = vim.tbl_extend('force', { text = true, cwd = git_root() }, opts or {})
  return vim.system(cmd, options, function(res)
    vim.schedule(function()
      on_done(res)
    end)
  end)
end

--- Read-only scratch buffer. No window is opened and no `q` mapping is set,
--- because this buffer may be shown in the diff view's own main window, where
--- closing the window would break the layout.
local function scratch_buf(name, text, ft)
  local lines = vim.split(text or '', '\n', { trimempty = true })
  if #lines == 0 then
    lines = { '(no output)' }
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  if ft then
    vim.bo[buf].filetype = ft
  end
  pcall(vim.api.nvim_buf_set_name, buf, name)
  M._scratch[buf] = true
  return buf
end

--- Show a buffer in a throwaway split. `q` closes it.
local function open_split(buf)
  vim.cmd 'botright vsplit'
  vim.api.nvim_win_set_buf(0, buf)
  vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = buf, nowait = true, desc = 'Close' })
  return buf
end

local function scratch(name, text, ft)
  return open_split(scratch_buf(name, text, ft))
end

--- Put a buffer in the diff view's main window and collapse the other diff
--- window so it fills the area, leaving the file panel alone. Opening a file
--- from the panel makes diffview rebuild the pair itself
--- (StandardView:ensure_layout -> Layout:recover), so this is not destructive.
--- Returns false when we are not in a diff view.
local function show_in_main(buf)
  local ok, lib = pcall(require, 'diffview.lib')
  if not ok then
    return false
  end

  local view = lib.get_current_view()
  local layout = view and view.cur_layout
  if not layout or type(layout.get_main_win) ~= 'function' then
    return false
  end

  local main = layout:get_main_win()
  if not main or not main.id or not vim.api.nvim_win_is_valid(main.id) then
    return false
  end

  -- Detach the diff buffers before reusing the window.
  pcall(function()
    layout:open_null()
  end)

  for _, win in ipairs(layout.windows or {}) do
    if win.id and win.id ~= main.id and vim.api.nvim_win_is_valid(win.id) then
      pcall(vim.api.nvim_win_close, win.id, true)
    end
  end

  vim.api.nvim_win_set_buf(main.id, buf)
  pcall(vim.api.nvim_win_call, main.id, function()
    vim.cmd 'diffoff'
  end)
  pcall(function()
    vim.wo[main.id].winbar = ''
    vim.wo[main.id].foldcolumn = '0'
    vim.wo[main.id].number = false
    vim.wo[main.id].relativenumber = false
  end)
  pcall(vim.api.nvim_set_current_win, main.id)
  return true
end

local function require_current()
  if M.current then
    return M.current
  end
  notify('no PR open -- <leader>grr to pick one', vim.log.levels.WARN)
end

--- owner/repo, from the configured remote.
local function repo_slug()
  local url = vim.fn.systemlist('git remote get-url ' .. M.config.remote)[1]
  if not url then
    return nil
  end
  return url:match 'github%.com[:/](.-)%.git$' or url:match 'github%.com[:/](.+)$'
end

--- Recover a repo-relative path from a normal buffer or a diffview:// one.
local function repo_relative(path)
  path = path:gsub('^%a[%w.+-]*://', '')
  local rel = path:match '/%.git/[^/]+/(.+)$'
  if rel then
    return rel
  end
  local root = git_root()
  if root and vim.startswith(path, root .. '/') then
    return path:sub(#root + 2)
  end
  return nil
end

-- Language servers key documents by file:// URI and skip nowrite buffers.
-- Point those APIs at the repo path so dartls/gopls/ts_ls treat a review
-- blob as that file, with the PR's contents.
local function patch_review_uris()
  if vim.g.pr_review_uri_patched then
    return
  end
  vim.g.pr_review_uri_patched = true
  local orig = vim.uri_from_bufnr
  vim.uri_from_bufnr = function(bufnr)
    bufnr = vim._resolve_bufnr(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      local path = vim.b[bufnr].review_lsp_path
      if type(path) == 'string' and path ~= '' then
        return vim.uri_from_fname(path)
      end
    end
    return orig(bufnr)
  end
end

local function enabled_lsp_names()
  local names = {}
  local enabled = rawget(vim.lsp, '_enabled_configs')
  if type(enabled) == 'table' then
    for name in pairs(enabled) do
      names[#names + 1] = name
    end
  end
  if #names > 0 then
    return names
  end
  return {
    'dartls',
    'gopls',
    'ts_ls',
    'lua_ls',
    'rust_analyzer',
    'pyright',
    'clangd',
    'jsonls',
    'yamlls',
    'html',
    'cssls',
    'bashls',
    'marksman',
    'tailwindcss',
    'biome',
    'eslint',
  }
end

local function jump_location(client, loc)
  local uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange
  if not uri or not range then
    return
  end
  local fname = vim.uri_to_fname(uri)
  local here = vim.api.nvim_get_current_buf()
  if vim.b[here].review_lsp_path == fname then
    pcall(vim.api.nvim_win_set_cursor, 0, { range.start.line + 1, range.start.character })
    vim.cmd 'normal! zz'
    return
  end
  vim.cmd('tabedit ' .. vim.fn.fnameescape(fname))
  pcall(vim.api.nvim_win_set_cursor, 0, { range.start.line + 1, range.start.character })
  vim.cmd 'normal! zz'
end

local function review_lsp_request(method, empty_msg)
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients { bufnr = bufnr, method = method }
  if #clients == 0 then
    notify('no language server on this diff buffer', vim.log.levels.WARN)
    return
  end
  local client = clients[1]
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  client:request(method, params, function(err, result)
    if err then
      notify(err.message or tostring(err), vim.log.levels.WARN)
      return
    end
    if not result or vim.tbl_isempty(result) then
      notify(empty_msg, vim.log.levels.INFO)
      return
    end
    local loc = result
    if type(result) == 'table' and result[1] then
      loc = result[1]
    end
    jump_location(client, loc)
  end, bufnr)
end

local function map_review_lsp(bufnr)
  local function bufmap(lhs, method, desc, empty)
    vim.keymap.set('n', lhs, function()
      review_lsp_request(method, empty)
    end, { buffer = bufnr, desc = 'LSP: ' .. desc })
  end
  bufmap('gd', 'textDocument/definition', 'Goto definition', 'no definition')
  bufmap('grd', 'textDocument/definition', 'Goto definition', 'no definition')
  bufmap('gri', 'textDocument/implementation', 'Goto implementation', 'no implementation')
  bufmap('grt', 'textDocument/typeDefinition', 'Goto type', 'no type definition')
  bufmap('grD', 'textDocument/declaration', 'Goto declaration', 'no declaration')
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('pr-review-lsp-maps', { clear = true }),
  callback = function(event)
    if not vim.b[event.buf].review_lsp_path then
      return
    end
    -- Normal LspAttach mappings run during async server initialisation.
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        map_review_lsp(event.buf)
      end
    end)
  end,
})

function M.attach_diff_lsp(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  -- Working-tree sides are real files; the normal LSP autocmd already runs.
  if vim.bo[bufnr].buftype == '' then
    return
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if not vim.startswith(name, 'diffview://') or name:find('diffview://null', 1, true) then
    return
  end
  local ft = vim.bo[bufnr].filetype
  if ft == '' or ft == 'DiffviewFileHistory' or ft == 'DiffviewFiles' then
    return
  end

  if require('config.buffer').large(bufnr) then
    return
  end
  if package.loaded.lazy then
    require('lazy').load { plugins = { 'nvim-lspconfig' } }
  end
  local lib = require 'diffview.lib'
  local view = lib.get_current_view()
  local root = view and view.adapter.ctx.toplevel or git_root()
  local git_dir = view and view.adapter.ctx.dir
  local prefix = git_dir and ('diffview://' .. git_dir .. '/')
  local rel
  if prefix and vim.startswith(name, prefix) then
    rel = name:sub(#prefix + 1):match '^[^/]+/(.+)$'
  else
    rel = repo_relative(name)
  end
  if not rel or not root then
    return
  end
  local abs = root .. '/' .. rel
  vim.b[bufnr].review_lsp_path = abs
  patch_review_uris()

  if vim.b[bufnr].review_lsp_attempted then
    return
  end
  vim.b[bufnr].review_lsp_attempted = true
  map_review_lsp(bufnr)
  vim.diagnostic.enable(false, { bufnr = bufnr })

  -- Root callbacks expect a real filename, not diffview://.../.git/SHA/path.
  -- bufadd supplies that name without reading the file or triggering FileType.
  local probe = vim.fn.bufadd(abs)
  local function start(config, project_root)
    if not vim.api.nvim_buf_is_valid(bufnr) or type(project_root) ~= 'string' then
      return
    end
    config.root_dir = project_root
    vim.lsp.start(config, { bufnr = bufnr }) -- Default reuse matches name AND root.
  end
  for _, name_ in ipairs(enabled_lsp_names()) do
    if vim.lsp.is_enabled(name_) and not vim.tbl_contains(M.config.review_lsp_exclude, name_) then
      local config = vim.lsp.config[name_]
      if type(config) == 'table' and type(config.filetypes) == 'table' and vim.tbl_contains(config.filetypes, ft) then
        config = vim.deepcopy(config)
        if type(config.root_dir) == 'function' then
          -- Respect callbacks that deliberately decline this project (e.g. Deno).
          config.root_dir(probe, function(project_root)
            start(config, project_root)
          end)
        else
          local project_root = config.root_dir or (config.root_markers and vim.fs.root(abs, config.root_markers))
          start(config, project_root)
        end
      end
    end
  end
end

-- Diffview may open several buffers before hiding them behind the summary.
-- Only start navigation servers for a diff the user actually stays on.
function M.prepare_diff_lsp(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype == '' then
    return
  end
  local lib = require 'diffview.lib'
  local view = lib.get_current_view()
  local sequence = (vim.b[bufnr].review_lsp_sequence or 0) + 1
  vim.b[bufnr].review_lsp_sequence = sequence
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.b[bufnr].review_lsp_sequence ~= sequence then
      return
    end
    if view ~= lib.get_current_view() or (view and view._pr_overview_pending) then
      return
    end
    if #vim.fn.win_findbuf(bufnr) == 0 then
      return
    end
    M.attach_diff_lsp(bufnr)
  end, 150)
end

local function in_visual()
  local mode = vim.fn.mode()
  return mode == 'v' or mode == 'V' or mode == '\22'
end

--- Cursor line, or the selected range in visual mode.
local function cursor_range()
  local first, last = vim.fn.line '.', vim.fn.line '.'
  if in_visual() then
    first, last = vim.fn.line 'v', vim.fn.line '.'
    if first > last then
      first, last = last, first
    end
  end
  return first, last
end

--- Leave visual mode immediately, so prompts opened afterwards behave.
local function leave_visual()
  if in_visual() then
    local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
    vim.api.nvim_feedkeys(esc, 'nx', false)
  end
end

---------------------------------------------------------------------------
-- On-disk state: notes and the pending line-comment queue
---------------------------------------------------------------------------

local function notes_path(number)
  return ('%s/%d.md'):format(M.config.notes_dir, number)
end

local function queue_path(number)
  return ('%s/%d.comments.json'):format(M.config.notes_dir, number)
end

local function load_queue(number)
  local path = queue_path(number)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  if ok and type(data) == 'table' then
    return data
  end
  return {}
end

local function save_queue(number, queue)
  vim.fn.mkdir(M.config.notes_dir, 'p')
  if #queue == 0 then
    vim.fn.delete(queue_path(number))
    return
  end
  vim.fn.writefile({ vim.json.encode(queue) }, queue_path(number))
end

--- Write the open gn buffer if it is this PR's notes file.
local function flush_notes(number)
  local path = vim.fn.fnamemodify(notes_path(number), ':p')
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
    pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd 'silent write'
    end)
  end
end

--- Notes contents with the seeded <!-- --> header stripped. Prefers the live
--- gn buffer so unsaved drafts still go out.
local function notes_body(number)
  flush_notes(number)
  local path = vim.fn.fnamemodify(notes_path(number), ':p')
  local buf = vim.fn.bufnr(path)
  local lines
  if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  elseif vim.fn.filereadable(path) == 1 then
    lines = vim.fn.readfile(path)
  else
    return ''
  end
  local kept = {}
  for _, line in ipairs(lines) do
    if not line:match '^%s*<!%-%-' then
      table.insert(kept, line)
    end
  end
  return vim.trim(table.concat(kept, '\n'))
end

---------------------------------------------------------------------------
-- Tearing down the previous review
---------------------------------------------------------------------------

--- Close every open diff view and wipe what the last PR left lying around.
--- DiffView:close() destroys its own file buffers and its tabpage, so this
--- mostly has to make sure the view object goes with them; lib.is_buf_in_use
--- guards the sweep for any diffview:// buffer that outlived its view.
local function close_previous(number)
  local ok, lib = pcall(require, 'diffview.lib')
  if ok and lib.views then
    -- dispose_view mutates lib.views, so walk a copy.
    local views = {}
    for _, view in ipairs(lib.views) do
      table.insert(views, view)
    end
    for _, view in ipairs(views) do
      pcall(function()
        view:close()
        lib.dispose_view(view)
      end)
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        local in_use = false
        if lib.is_buf_in_use then
          local got, used = pcall(lib.is_buf_in_use, buf)
          in_use = got and used
        end
        if name:match '^diffview://' and not in_use then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end
  end

  -- Our own summary / checks / queue scratches. All 'nofile', nothing to lose.
  for buf in pairs(M._scratch) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    M._scratch[buf] = nil
  end

  -- The notes buffer is a real file, so save it before letting it go.
  if number then
    local buf = vim.fn.bufnr(vim.fn.fnamemodify(notes_path(number), ':p'))
    if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
      if vim.bo[buf].modified then
        pcall(vim.api.nvim_buf_call, buf, function()
          vim.cmd 'silent write'
        end)
      end
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

-- Conversation thread + inline review comments. `gh pr view --json comments`
-- is only the issue thread; line comments are a second request.
local function load_summary(root, number, callback, force)
  local summary, comments, summary_err
  local left = 2
  local function done()
    left = left - 1
    if left > 0 then
      return
    end
    if summary then
      summary.reviewComments = comments or {}
    end
    callback(summary_err, summary)
  end
  local cancel_summary = review_data.summary(root, number, function(err, data)
    summary_err, summary = err, data
    done()
  end, force)
  local cancel_comments = review_data.review_comments(root, number, function(_, data)
    comments = data
    done()
  end, force)
  return function()
    cancel_summary()
    cancel_comments()
  end
end

---------------------------------------------------------------------------
-- Opening a PR
---------------------------------------------------------------------------

--- Fetch the PR head and its base branch, then diff head against the merge
--- base. Nothing is checked out, so your working tree is untouched.
function M.open(pr, opts)
  opts = opts or {}
  local root = pr._root or git_root()
  if not root then
    notify('not inside a git repo', vim.log.levels.ERROR)
    return
  end
  open_generation = open_generation + 1
  local generation = open_generation
  if cancel_open_summary then
    cancel_open_summary()
  end
  local remote, base = M.config.remote, pr.baseRefName
  local ref = ('refs/pr/%d'):format(pr.number)
  local view, ready, summary, summary_error, shown
  local function overview()
    if generation ~= open_generation or shown or not ready or not view then
      return
    end
    if not summary and not summary_error then
      return
    end
    local lib = require 'diffview.lib'
    -- A late response must never replace a different tab or selected file.
    if lib.get_current_view() ~= view then
      return
    end
    shown = true
    view._pr_overview_pending = false
    local text = summary_error or render_info(summary)
    show_in_main(scratch_buf(('PR #%d'):format(pr.number), text, 'markdown'))
  end
  if M.config.overview_on_open then
    cancel_open_summary = load_summary(root, pr.number, function(err, data)
      summary_error, summary = err, data
      overview()
    end, opts.force)
  end
  local started = vim.uv.hrtime()
  review_data.fetch(root, remote, pr, function(err, refs, cached)
    if generation ~= open_generation then
      return
    end
    if err then
      if cancel_open_summary then
        cancel_open_summary()
      end
      notify(err, vim.log.levels.ERROR)
      return
    end
    pr.headRefOid, pr.baseRefOid = refs.head, refs.base
    M.last_open = { cached = cached, fetch_ms = (vim.uv.hrtime() - started) / 1e6 }
    if M.config.close_previous then
      close_previous(M.current and M.current.number)
    end
    pr._root = root
    M.current = pr
    local ok, err = pcall(vim.cmd, ('DiffviewOpen -C=%s %s/%s...%s'):format(vim.fn.fnameescape(root), remote, base, ref))
    if not ok then
      notify('DiffviewOpen failed: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
    view = require('diffview.lib').get_current_view()
    if view and M.config.overview_on_open then
      view._pr_overview_pending = true
      local function loaded()
        ready = true
        vim.schedule(overview)
      end
      view.emitter:once('file_open_post', loaded)
      view.emitter:once('files_updated', function(_, files)
        if files:len() == 0 then
          loaded()
        end
      end)
      -- Do not steal focus after the user starts navigating the diff.
      view.emitter:on('file_open_pre', function()
        if ready then
          shown = true
          view._pr_overview_pending = false
        end
      end)
      if view.initialized and view.cur_entry then
        loaded()
      end
    end
    local pending = #load_queue(pr.number)
    if pending > 0 then
      notify(('%d comments still queued for #%d'):format(pending, pr.number))
    end
  end, opts.force)
end

---------------------------------------------------------------------------
-- Picker
---------------------------------------------------------------------------

function M.show_picker(prs, base_filter, scope)
  scope = scope or 'mine'
  local root = prs[1] and prs[1]._root or git_root()
  local preview_generation = 0
  local cancel_preview, cancel_prefetch
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local previewers = require 'telescope.previewers'
  local entry_display = require 'telescope.pickers.entry_display'

  -- Drop already-approved PRs here as well as in the search query: a negated
  -- search qualifier fails quietly, and this cannot.
  local candidates = {}
  for _, pr in ipairs(prs) do
    if not (M.config.hide_approved and pr.reviewDecision == 'APPROVED') then
      table.insert(candidates, pr)
    end
  end

  local shown = {}
  for _, pr in ipairs(candidates) do
    if not base_filter or pr.baseRefName == base_filter then
      table.insert(shown, pr)
    end
  end
  if #shown == 0 and base_filter then
    shown, base_filter = candidates, nil
  end

  local displayer = entry_display.create {
    separator = '  ',
    items = { { width = 6 }, { width = 14 }, { width = 16 }, { remaining = true } },
  }

  local who = scope == 'all' and 'Awaiting review' or 'Your review queue'
  local hint = scope == 'all' and 'C-o yours' or 'C-o all'
  local title = base_filter and ('%s -> %s  (%s)'):format(who, base_filter, hint) or ('%s (all bases)  (%s)'):format(who, hint)

  pickers
    .new({}, {
      prompt_title = title,
      layout_strategy = 'vertical',
      layout_config = { width = 0.95, height = 0.95, preview_height = 0.7, preview_cutoff = 0, prompt_position = 'top' },
      finder = finders.new_table {
        results = shown,
        entry_maker = function(pr)
          local author = pr.author and pr.author.login or '?'
          return {
            value = pr,
            ordinal = ('%d %s %s %s'):format(pr.number, pr.title, author, pr.baseRefName),
            display = function()
              return displayer {
                { '#' .. pr.number, 'TelescopeResultsNumber' },
                { pr.baseRefName, 'TelescopeResultsComment' },
                { author, 'TelescopeResultsIdentifier' },
                (pr.isDraft and '[draft] ' or '') .. pr.title,
              }
            end,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      -- Preview the PR summary -- the same thing <leader>gri shows once it is
      -- open -- rather than the first file's diff.
      previewer = previewers.new_buffer_previewer {
        title = 'Description & details | C-d/C-u scroll | C-End/C-Home end/start',
        scroll_fn = function(self, direction)
          local win = self.state and self.state.winid
          if win and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_call(win, function()
              vim.cmd.normal { args = { math.abs(direction) .. string.char(direction > 0 and 5 or 25) }, bang = true }
            end)
          end
        end,
        teardown = function()
          preview_generation = preview_generation + 1
          if cancel_preview then
            cancel_preview()
          end
          if cancel_prefetch then
            cancel_prefetch()
          end
        end,
        -- One preview buffer per PR, so a slow gh call still lands in the
        -- buffer belonging to the entry that asked for it.
        get_buffer_by_name = function(_, entry)
          return 'pr-summary-' .. tostring(entry.value.number)
        end,
        define_preview = function(self, entry)
          local number = entry.value.number
          local bufnr = self.state.bufnr
          local win = self.state.winid
          vim.wo[win].wrap = true
          vim.wo[win].linebreak = true
          vim.wo[win].breakindent = true
          vim.wo[win].smoothscroll = true
          vim.wo[win].conceallevel = 0

          local function fill(text)
            if not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end
            local saved_view
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
              saved_view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
            end
            vim.bo[bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, '\n', { plain = true }))
            if saved_view then
              vim.api.nvim_win_call(win, function()
                vim.fn.winrestview(saved_view)
              end)
            end
            pcall(function()
              require('telescope.previewers.utils').highlighter(bufnr, 'markdown')
            end)
          end

          preview_generation = preview_generation + 1
          local generation = preview_generation
          if cancel_preview then
            cancel_preview()
          end
          if cancel_prefetch then
            cancel_prefetch()
          end
          local cached = review_data.peek_summary(root, number)
          local initial = cached or vim.deepcopy(entry.value)
          if initial.body == nil then
            initial.body = '_Loading description…_'
          end
          local preview = render_info(initial)
          if not cached then
            preview = preview .. '\n\n_Loading comments and reviews…_'
          end
          fill(preview)
          -- Give the preview a chance to paint; don't fetch every row while
          -- scrolling. No Diffview windows or language servers start here.
          vim.defer_fn(function()
            if generation == preview_generation and vim.api.nvim_buf_is_valid(bufnr) then
              cancel_prefetch = review_data.prefetch(root, M.config.remote, entry.value)
            end
          end, 220)
          -- Scrolling quickly should not launch a GitHub request per row.
          vim.defer_fn(function()
            if generation ~= preview_generation or not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end
            cancel_preview = load_summary(root, number, function(err, data)
              if generation == preview_generation then
                fill(err and (preview .. '\n\n' .. err) or render_info(data))
              end
            end)
          end, cached and 0 or 120)
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry then
            M.open(entry.value)
          end
        end)
        -- Toggle between "only PRs targeting the production branch" and everything.
        local toggle_base = function()
          actions.close(prompt_bufnr)
          local next_filter = nil
          if not base_filter then
            next_filter = M.config.base_filter
          end
          M.show_picker(prs, next_filter, scope)
        end
        -- Re-fetch: your review-requested queue vs every PR still awaiting review.
        local toggle_scope = function()
          actions.close(prompt_bufnr)
          M.pick {
            scope = scope == 'all' and 'mine' or 'all',
            base_filter = base_filter,
            all_bases = base_filter == nil,
          }
        end
        local function preview_edge(at_end)
          local picker = action_state.get_current_picker(prompt_bufnr)
          local win = picker.previewer.state.winid
          if win and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_call(win, function()
              vim.cmd.normal { args = { at_end and 'G$zb' or 'ggzt' }, bang = true }
            end)
          end
        end
        for _, mode in ipairs { 'i', 'n' } do
          map(mode, '<C-d>', actions.preview_scrolling_down)
          map(mode, '<C-u>', actions.preview_scrolling_up)
          map(mode, '<PageDown>', actions.preview_scrolling_down)
          map(mode, '<PageUp>', actions.preview_scrolling_up)
          map(mode, '<C-End>', function()
            preview_edge(true)
          end)
          map(mode, '<C-Home>', function()
            preview_edge(false)
          end)
        end
        map('i', '<C-a>', toggle_base)
        map('n', '<C-a>', toggle_base)
        map('i', '<C-o>', toggle_scope)
        map('n', '<C-o>', toggle_scope)
        return true
      end,
    })
    :find()
end

function M.pick(opts)
  if not have_gh() then
    return
  end
  opts = opts or {}
  local scope = opts.scope or 'mine'
  local base_filter
  if opts.all_bases then
    base_filter = nil
  elseif opts.base_filter ~= nil then
    base_filter = opts.base_filter
  else
    base_filter = M.config.base_filter
  end

  local root = git_root()
  if not root then
    return notify('not inside a git repo', vim.log.levels.ERROR)
  end

  local search = scope == 'all' and M.config.all_search or M.config.search
  if M.config.hide_approved then
    search = search .. ' -review:approved'
  end

  review_data.list(root, search, M.config.limit, function(err, prs)
    if err then
      return notify(err, vim.log.levels.ERROR)
    end
    if #prs == 0 then
      notify(scope == 'all' and 'no open PRs awaiting review' or 'no PRs awaiting your review')
    end
    for _, pr in ipairs(prs) do
      pr._root = root
    end
    M.show_picker(prs, base_filter, scope)
  end, opts.force)
end

--- Open any PR by number, whether or not it is assigned to you. Accepts
--- "1284", "#1284", or a full pull-request URL.
function M.open_number(arg, opts)
  opts = opts or {}
  if not have_gh() then
    return
  end

  local function go(input)
    if not input or input == '' then
      return
    end

    -- A URL for some other repo would give a number we then fetch from *this*
    -- repo's origin, quietly diffing the wrong PR. Refuse instead.
    local owner_repo = input:match 'github%.com/([^/]+/[^/]+)/pull/%d+'
    if owner_repo then
      local slug = repo_slug()
      if slug and owner_repo:lower() ~= slug:lower() then
        notify(('that PR is in %s, but this repo is %s'):format(owner_repo, slug), vim.log.levels.ERROR)
        return
      end
    end

    local number = input:match 'pull/(%d+)' or input:match '(%d+)'
    if not number then
      notify('no PR number in: ' .. input, vim.log.levels.WARN)
      return
    end

    local root = opts.root or git_root()
    if not root then
      return notify('not inside a git repo', vim.log.levels.ERROR)
    end
    open_generation = open_generation + 1
    local generation = open_generation
    if cancel_open_summary then
      cancel_open_summary()
    end
    review_data.metadata(root, number, function(err, pr)
      if generation ~= open_generation then
        return
      end
      if err then
        return notify(err, vim.log.levels.ERROR)
      end
      pr._root = root
      M.open(pr, opts)
    end, opts.force)
  end

  if arg and arg ~= '' then
    go(tostring(arg))
  else
    vim.ui.input({ prompt = 'PR number or url: ' }, go)
  end
end

--- Diff one commit against its parent. Line comments still queue against the
--- PR head -- go back to the full PR (<leader>grR) before submitting them.
function M.open_commit(commit)
  local pr = require_current()
  if not pr then
    return
  end
  local sha = commit and (commit.oid or commit.sha)
  if not sha or sha == '' then
    notify('that commit has no sha', vim.log.levels.WARN)
    return
  end
  local root = pr._root or git_root()
  if not root then
    notify('not inside a git repo', vim.log.levels.ERROR)
    return
  end

  local function show()
    open_generation = open_generation + 1
    if cancel_open_summary then
      cancel_open_summary()
    end
    close_previous(pr.number)
    pr._commit = sha
    M.current = pr
    local spec = ('%s~1..%s'):format(sha, sha)
    local ok, err = pcall(vim.cmd, ('DiffviewOpen -C=%s %s'):format(vim.fn.fnameescape(root), spec))
    if not ok then
      notify('DiffviewOpen failed: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
    local title = commit.messageHeadline or commit.message or sha:sub(1, 7)
    notify(('#%d %s  %s'):format(pr.number, sha:sub(1, 7), title))
  end

  run({ 'git', 'cat-file', '-e', sha .. '^{commit}' }, function(res)
    if res.code == 0 then
      show()
      return
    end
    review_data.fetch(root, M.config.remote, pr, function(err)
      if err then
        notify('could not fetch that commit: ' .. err, vim.log.levels.ERROR)
        return
      end
      show()
    end, true)
  end)
end

--- Commits on the current PR. Select one to review just that commit's diff.
function M.commits()
  local pr = require_current()
  if not pr then
    return
  end
  if not have_gh() then
    return
  end
  local root = pr._root or git_root()
  if not root then
    return
  end
  notify('loading commits...')
  review_data.commits(root, pr.number, function(err, data)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    local commits = data and data.commits or {}
    if #commits == 0 then
      notify('no commits on #' .. pr.number)
      return
    end

    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'
    local entry_display = require 'telescope.pickers.entry_display'
    local displayer = entry_display.create {
      separator = '  ',
      items = { { width = 4 }, { width = 10 }, { width = 7 }, { width = 14 }, { remaining = true } },
    }

    local rows = {
      {
        full_pr = true,
        ordinal = 'full pr all commits',
        display = function()
          return displayer {
            { 'PR', 'TelescopeResultsNumber' },
            { '', 'TelescopeResultsComment' },
            { 'full', 'TelescopeResultsComment' },
            { '', 'TelescopeResultsIdentifier' },
            ('#%d %s'):format(pr.number, pr.title or ''),
          }
        end,
      },
    }
    for i, commit in ipairs(commits) do
      local author = '?'
      if commit.authors and commit.authors[1] then
        author = commit.authors[1].login or commit.authors[1].name or '?'
      end
      local date = (commit.committedDate or commit.authoredDate or ''):sub(1, 10)
      table.insert(rows, {
        commit = commit,
        ordinal = ('%s %s %s %s'):format(date, commit.oid or '', commit.messageHeadline or '', author),
        display = function()
          return displayer {
            { tostring(i), 'TelescopeResultsNumber' },
            { date, 'TelescopeResultsComment' },
            { (commit.oid or '?'):sub(1, 7), 'TelescopeResultsIdentifier' },
            { author, 'TelescopeResultsIdentifier' },
            commit.messageHeadline or '(no message)',
          }
        end,
      })
    end

    pickers
      .new({}, {
        prompt_title = ('#%d commits'):format(pr.number),
        finder = finders.new_table {
          results = rows,
          entry_maker = function(row)
            return {
              value = row,
              ordinal = row.ordinal,
              display = row.display,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not entry then
              return
            end
            if entry.value.full_pr then
              M.open(pr)
            else
              M.open_commit(entry.value.commit)
            end
          end)
          return true
        end,
      })
      :find()
  end)
end

--- Git object ids are 7–40 hex. Cursor may sit on the hex, a leading `#`,
--- or the `commit/` prefix used on activity timeline lines.
--- Returns sha, kind (`link` for `commit/<sha>`, `bare` otherwise).
local function sha_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local start = 1
  while true do
    local s, e = line:find('[0-9a-fA-F]+', start)
    if not s then
      return
    end
    local sha = line:sub(s, e)
    if #sha >= 7 and #sha <= 40 then
      local left = s
      local kind = 'bare'
      if s > 7 and line:sub(s - 7, s - 1) == 'commit/' then
        left = s - 7
        kind = 'link'
      elseif s > 1 and line:sub(s - 1, s - 1) == '#' then
        left = s - 1
      end
      if col >= left and col <= e then
        return sha, kind
      end
    end
    start = e + 1
  end
end

--- `gf` on `commit/abc1234` or a bare hash like `80a2cb79e2` in a message.
function M.goto_commit_under_cursor()
  local sha, kind = sha_under_cursor()
  if not sha then
    return false
  end
  if not M.current then
    if kind == 'link' then
      notify('no PR open -- <leader>grr to pick one', vim.log.levels.WARN)
      return true
    end
    return false
  end
  local line = vim.api.nvim_get_current_line()
  M.open_commit {
    oid = sha,
    messageHeadline = line:match 'commit/%x+%s+%S+%s+(.*)$' or sha,
  }
  return true
end

---------------------------------------------------------------------------
-- Context: description, comments, CI
---------------------------------------------------------------------------

local function ignored_author(login)
  login = (login or ''):lower()
  if login == '' then
    return false
  end
  for _, needle in ipairs(M.config.ignore_authors or {}) do
    if login:find(needle:lower(), 1, true) then
      return true
    end
  end
  return false
end

-- Blacksmith injects an HTML <!-- codesmith:footer --> block into PR bodies.
local function strip_review_noise(text)
  text = text or ''
  local lowered = text:lower()
  local s = lowered:find('<!-- codesmith:footer', 1, true) or lowered:find('<!--codesmith:footer', 1, true)
  if s then
    local close = lowered:find('<!-- /codesmith:footer', s, true) or lowered:find('<!--/codesmith:footer', s, true)
    if close then
      local ce = text:find('-->', close, true)
      text = text:sub(1, s - 1) .. (ce and text:sub(ce + 3) or '')
    else
      text = text:sub(1, s - 1)
    end
  end
  text = text:gsub('<%!%-%-[^\n]-codesmith[^\n]-%-%->', '')
  text = text:gsub('\n%-%-%-%s*$', '')
  text = text:gsub('\n%s*\n%s*\n+', '\n\n')
  return vim.trim(text)
end

--- Title, metadata, description, reviews and comments as one markdown document.
--- (Declared as a local at the top of the file.)
function render_info(d)
  local out = {}
  local function add(line)
    table.insert(out, line or '')
  end
  local function add_block(text)
    for _, line in ipairs(vim.split(text or '', '\n', { plain = true })) do
      add((line:gsub('\r$', '')))
    end
  end

  add(('# #%s  %s'):format(tostring(d.number), d.title or ''))
  add ''

  local meta = { d.state or 'OPEN' }
  if d.isDraft then
    table.insert(meta, 'DRAFT')
  end
  table.insert(meta, ('%s -> %s'):format(d.headRefName or '?', d.baseRefName or '?'))
  table.insert(meta, '@' .. ((d.author and d.author.login) or '?'))
  if d.reviewDecision and d.reviewDecision ~= '' then
    table.insert(meta, d.reviewDecision)
  end
  if d.changedFiles then
    table.insert(meta, ('%d files +%d -%d'):format(d.changedFiles, d.additions or 0, d.deletions or 0))
  end
  add('`' .. table.concat(meta, '  |  ') .. '`')

  if d.labels and #d.labels > 0 then
    local names = {}
    for _, label in ipairs(d.labels) do
      table.insert(names, label.name)
    end
    add ''
    add('labels: ' .. table.concat(names, ', '))
  end

  add ''
  add(d.url or '')
  add ''
  add '---'
  add ''

  local body = strip_review_noise(d.body)
  if body ~= '' then
    add_block(body)
  else
    add '_(no description)_'
  end

  local hidden = 0
  local function iso_time(s)
    if type(s) ~= 'string' then
      return 0
    end
    local y, mo, day, h, mi, sec = s:match '^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)'
    if not y then
      return 0
    end
    return os.time {
      year = tonumber(y),
      month = tonumber(mo),
      day = tonumber(day),
      hour = tonumber(h),
      min = tonumber(mi),
      sec = tonumber(sec),
      isdst = false,
    }
  end

  local events = {}
  for _, r in ipairs(d.reviews or {}) do
    local login = r.author and r.author.login
    if ignored_author(login) then
      hidden = hidden + 1
    elseif vim.trim(r.body or '') ~= '' or (r.state and r.state ~= 'COMMENTED') then
      local when = r.submittedAt or r.createdAt
      table.insert(events, { kind = 'review', t = iso_time(when), item = r })
    end
  end
  for _, c in ipairs(d.comments or {}) do
    if ignored_author(c.author and c.author.login) then
      hidden = hidden + 1
    else
      table.insert(events, { kind = 'comment', t = iso_time(c.createdAt), item = c })
    end
  end
  for _, commit in ipairs(d.commits or {}) do
    local when = commit.committedDate or commit.authoredDate
    table.insert(events, { kind = 'commit', t = iso_time(when), item = commit })
  end
  for _, c in ipairs(d.reviewComments or {}) do
    local login = (c.author and c.author.login) or (c.user and c.user.login)
    if ignored_author(login) then
      hidden = hidden + 1
    else
      local when = c.createdAt or c.created_at
      table.insert(events, { kind = 'line', t = iso_time(when), item = c })
    end
  end
  for _, item in ipairs(load_queue(d.number) or {}) do
    table.insert(events, { kind = 'queued', t = os.time(), item = item })
  end
  table.sort(events, function(a, b)
    if a.t == b.t then
      return (a.kind == 'commit' and 0 or 1) < (b.kind == 'commit' and 0 or 1)
    end
    return a.t < b.t
  end)

  if #events > 0 then
    add ''
    add '---'
    add ''
    add '## Activity'
    for _, event in ipairs(events) do
      add ''
      if event.kind == 'commit' then
        local commit = event.item
        local sha = (commit.oid or '?'):sub(1, 7)
        local date = (commit.committedDate or commit.authoredDate or ''):sub(1, 10)
        local title = commit.messageHeadline or '(no message)'
        -- `commit/<sha>` is what gf looks for.
        add(('`commit/%s`  %s  %s'):format(sha, date, title))
      elseif event.kind == 'review' then
        local r = event.item
        add(('### @%s — %s'):format((r.author and r.author.login) or '?', r.state or ''))
        add ''
        if vim.trim(r.body or '') ~= '' then
          add_block(r.body)
        else
          add '_(no summary)_'
        end
      elseif event.kind == 'line' then
        local c = event.item
        local login = (c.author and c.author.login) or (c.user and c.user.login) or '?'
        local when = c.createdAt or c.created_at or ''
        local path = c.path or '?'
        local line = c.line or c.original_line or c.originalLine
        local where = line and ('%s:%s'):format(path, line) or path
        add(('### @%s — %s  `%s`'):format(login, when:sub(1, 10), where))
        add ''
        add_block(c.body)
      elseif event.kind == 'queued' then
        local item = event.item
        local where = (item.path or '?') .. ':' .. tostring(item.line or '?')
        add(('### queued — `%s`'):format(where))
        add ''
        add_block(item.body)
      else
        local c = event.item
        add(('### @%s — %s'):format((c.author and c.author.login) or '?', (c.createdAt or ''):sub(1, 10)))
        add ''
        add_block(c.body)
      end
    end
  end

  if hidden > 0 then
    add ''
    add(('_%d hidden (ignore_authors: %s)_'):format(hidden, table.concat(M.config.ignore_authors or {}, ', ')))
  end

  return table.concat(out, '\n')
end

--- opts.pr        review this PR instead of the current one
--- opts.main_only only place it in the diff view's main window; if we are not
---                in a diff view, do nothing rather than opening a split
function M.info(opts)
  opts = opts or {}
  local pr = opts.pr or require_current()
  if not pr then
    return
  end
  local root = pr._root or git_root()
  if not root then
    return
  end
  local generation = open_generation
  load_summary(root, pr.number, function(err, data)
    if generation ~= open_generation then
      return
    end
    if err then
      return notify(err, vim.log.levels.ERROR)
    end
    local buf = scratch_buf(('PR #%d'):format(pr.number), render_info(data), 'markdown')
    if not show_in_main(buf) and not opts.main_only then
      open_split(buf)
    end
  end, true) -- Explicit <leader>gri always refreshes comments/reviews.
end

--- Open the PR on github.com in the system browser.
function M.browse()
  local pr = require_current()
  if not pr then
    return
  end

  -- The picker already gave us the URL, so this needs no round trip.
  local url = pr.url
  if url and url ~= '' and vim.ui and vim.ui.open then
    local ok = pcall(vim.ui.open, url)
    if ok then
      notify(url)
      return
    end
  end

  -- Older nvim, or a PR record without a url: let gh work it out.
  run({ 'gh', 'pr', 'view', tostring(pr.number), '--web' }, function(res)
    if res.code ~= 0 then
      notify('could not open the PR: ' .. (res.stderr or ''), vim.log.levels.ERROR)
    end
  end)
end

--- Is the cursor in one of the diff windows (rather than the file panel)?
local function in_diff_window()
  local ok, lib = pcall(require, 'diffview.lib')
  if not ok then
    return false
  end
  local view = lib.get_current_view()
  local layout = view and view.cur_layout
  if not layout then
    return false
  end
  local win = vim.api.nvim_get_current_win()
  for _, w in ipairs(layout.windows or {}) do
    if w.id == win then
      return true
    end
  end
  return false
end

--- Open the working-tree copy of the file under review in a new tab, at the
--- same line. gd on the diff already talks to LSP using the PR text; this is
--- the escape hatch when you want your branch's file instead.
function M.open_local()
  local ok, lib = pcall(require, 'diffview.lib')
  local view = ok and lib.get_current_view()
  local entry = view and view.cur_entry
  if not entry then
    notify('not in a diff view', vim.log.levels.WARN)
    return
  end

  local root = git_root()
  if not root then
    notify('not inside a git repo', vim.log.levels.WARN)
    return
  end

  -- Only trust the cursor line if we are in a diff window, not the file tree.
  local line = 1
  if in_diff_window() then
    line = vim.fn.line '.'
  end

  -- A renamed file may only exist under its old name on your branch.
  local target
  for _, candidate in ipairs { entry.path, entry.oldpath } do
    if candidate and candidate ~= '' then
      local full = root .. '/' .. candidate
      if vim.fn.filereadable(full) == 1 then
        target = full
        break
      end
    end
  end

  if not target then
    notify((entry.path or '?') .. ' does not exist on your branch', vim.log.levels.WARN)
    return
  end

  vim.cmd('tabedit ' .. vim.fn.fnameescape(target))
  line = math.min(line, vim.api.nvim_buf_line_count(0))
  pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
  vim.cmd 'normal! zz'
  notify(('%s:%d (your branch, not the PR)'):format(vim.fn.fnamemodify(target, ':.'), line))
end

function M.checks()
  local pr = require_current()
  if not pr then
    return
  end
  -- gh exits non-zero when checks are failing or pending, so show output either way.
  run({ 'gh', 'pr', 'checks', tostring(pr.number) }, function(res)
    local text = res.stdout
    if text == nil or text == '' then
      text = res.stderr
    end
    scratch(('PR #%d checks'):format(pr.number), text)
  end)
end

---------------------------------------------------------------------------
-- Line comments
--
-- GitHub anchors review comments to (path, side, line), where RIGHT is the
-- post-change file and LEFT the pre-change one. Comments are queued locally
-- and sent together with the summary when you submit, which is exactly how a
-- "pending review" works in the web UI.
---------------------------------------------------------------------------

--- Where is the cursor, in GitHub review terms? nil when not in a diff window.
local function diff_location()
  local ok, lib = pcall(require, 'diffview.lib')
  if not ok then
    notify('diffview is not loaded', vim.log.levels.WARN)
    return nil
  end

  local view = lib.get_current_view()
  if not view or not view.cur_entry or not view.cur_layout then
    notify('not in a diff view -- <leader>grr to open a PR', vim.log.levels.WARN)
    return nil
  end

  local layout = view.cur_layout
  local win = vim.api.nvim_get_current_win()
  local side
  if layout.b and layout.b.id == win then
    side = 'RIGHT'
  elseif layout.a and layout.a.id == win then
    side = 'LEFT'
  else
    notify('put the cursor in one of the diff windows', vim.log.levels.WARN)
    return nil
  end

  local entry = view.cur_entry
  local path = entry.path
  if side == 'LEFT' and entry.oldpath and entry.oldpath ~= '' then
    path = entry.oldpath
  end
  if not path or path == '' then
    notify('could not work out which file this is', vim.log.levels.WARN)
    return nil
  end

  return { path = path, side = side }
end

local function add_comment(pr, loc, first, last, body)
  body = vim.trim(body or '')
  if body == '' then
    notify('empty comment, nothing queued', vim.log.levels.WARN)
    return
  end

  local queue = load_queue(pr.number)
  local item = { path = loc.path, side = loc.side, line = last, body = body }
  if last > first then
    item.start_line = first
    item.start_side = loc.side
  end
  table.insert(queue, item)
  save_queue(pr.number, queue)

  local where = loc.path .. ':' .. (last > first and ('%d-%d'):format(first, last) or tostring(last))
  notify(('queued (%d pending) %s'):format(#queue, where))
end

--- One-line comment on the cursor line or the visual selection.
function M.comment()
  local pr = require_current()
  if not pr then
    return
  end
  local loc = diff_location()
  if not loc then
    return
  end
  local first, last = cursor_range()
  leave_visual()

  local where = vim.fn.fnamemodify(loc.path, ':t') .. ':' .. tostring(last)
  vim.ui.input({ prompt = ('Comment on %s > '):format(where) }, function(input)
    if input then
      add_comment(pr, loc, first, last, input)
    end
  end)
end

--- Multi-line comment: compose in a split, <C-s> to queue, q to discard.
function M.compose()
  local pr = require_current()
  if not pr then
    return
  end
  local loc = diff_location()
  if not loc then
    return
  end
  local first, last = cursor_range()
  leave_visual()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'markdown'
  pcall(vim.api.nvim_buf_set_name, buf, ('comment %s:%d'):format(loc.path, last))

  vim.cmd 'botright 12split'
  vim.api.nvim_win_set_buf(0, buf)
  local win = vim.api.nvim_get_current_win()

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set({ 'n', 'i' }, '<C-s>', function()
    vim.cmd 'stopinsert'
    local body = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    close()
    add_comment(pr, loc, first, last, body)
  end, { buffer = buf, desc = 'Queue this comment' })

  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true, desc = 'Discard' })

  notify '<C-s> to queue, q to discard'
  vim.cmd 'startinsert'
end

function M.queued()
  local pr = require_current()
  if not pr then
    return
  end
  local queue = load_queue(pr.number)
  if #queue == 0 then
    notify('no queued comments for #' .. pr.number)
    return
  end
  local lines = {}
  for i, c in ipairs(queue) do
    local where = c.start_line and ('%d-%d'):format(c.start_line, c.line) or tostring(c.line)
    local head = vim.split(c.body, '\n')[1] or ''
    table.insert(lines, ('%d. [%s] %s:%s  %s'):format(i, c.side, c.path, where, head))
  end
  table.insert(lines, '')
  table.insert(lines, '-- :PRUncomment <n> to drop one, <leader>grQ to clear all')
  scratch(('PR #%d queued comments'):format(pr.number), table.concat(lines, '\n'))
end

function M.unqueue(index)
  local pr = require_current()
  if not pr then
    return
  end
  local queue = load_queue(pr.number)
  index = tonumber(index)
  if not index or not queue[index] then
    notify('no queued comment ' .. tostring(index), vim.log.levels.WARN)
    return
  end
  local removed = table.remove(queue, index)
  save_queue(pr.number, queue)
  notify(('dropped comment on %s:%d (%d left)'):format(removed.path, removed.line, #queue))
end

function M.clear_queue()
  local pr = require_current()
  if not pr then
    return
  end
  local queue = load_queue(pr.number)
  if #queue == 0 then
    notify 'queue already empty'
    return
  end
  if vim.fn.confirm(('Discard %d queued comments on #%d?'):format(#queue, pr.number), '&Yes\n&No', 2) ~= 1 then
    return
  end
  save_queue(pr.number, {})
  notify 'queue cleared'
end

---------------------------------------------------------------------------
-- Summary notes and submitting
---------------------------------------------------------------------------

--- A real file per PR, so notes survive a restart.
function M.notes()
  local pr = require_current()
  if not pr then
    return
  end
  vim.fn.mkdir(M.config.notes_dir, 'p')
  local path = notes_path(pr.number)
  local fresh = vim.fn.filereadable(path) == 0
  vim.cmd('botright vsplit ' .. vim.fn.fnameescape(path))
  if fresh then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      ('<!-- #%d %s -->'):format(pr.number, pr.title),
      ('<!-- %s -->'):format(pr.url or ''),
      '',
      '',
    })
    vim.cmd 'normal! G'
  end
end

-- Searches the picker actually caches. Dropping a PR from these avoids a
-- full `gh pr list` after we already know it left the queue.
local function list_searches()
  local searches = { M.config.search, M.config.all_search }
  if M.config.hide_approved then
    searches[#searches + 1] = M.config.search .. ' -review:approved'
    searches[#searches + 1] = M.config.all_search .. ' -review:approved'
  end
  return searches
end

local function forget_listed(pr)
  local root = pr and (pr._root or git_root())
  if not root or not pr.number then
    return
  end
  review_data.remove_from_lists(root, list_searches(), M.config.limit, pr.number)
end

local EVENTS = {
  approve = { event = 'APPROVE', label = 'APPROVE' },
  comment = { event = 'COMMENT', label = 'COMMENT' },
  request = { event = 'REQUEST_CHANGES', label = 'REQUEST CHANGES' },
}

local function api_post(endpoint, payload, on_done)
  run({ 'gh', 'api', '--method', 'POST', endpoint, '--input', '-' }, on_done, {
    stdin = vim.json.encode(payload),
  })
end

--- Submit the summary and every queued line comment as one review.
--- opts.skip_confirm / opts.on_done are for close-PR, which already confirmed.
local function submit_review(pr, kind, opts)
  opts = opts or {}
  local ev = EVENTS[kind]
  if not ev then
    notify('unknown review type: ' .. tostring(kind), vim.log.levels.ERROR)
    return
  end
  if not have_gh() then
    return
  end

  local slug = repo_slug()
  if not slug then
    notify('could not read the ' .. M.config.remote .. ' remote', vim.log.levels.ERROR)
    return
  end

  vim.cmd 'silent! wall'
  local body = notes_body(pr.number)
  local queue = load_queue(pr.number)

  -- A verdict needs something behind it, but line comments count -- an empty
  -- summary is fine when you have already said it inline.
  if body == '' and #queue == 0 and ev.event ~= 'APPROVE' then
    notify(ev.label .. ' needs a summary (<leader>grn) or at least one line comment', vim.log.levels.WARN)
    return
  end
  local payload = { commit_id = pr.headRefOid }
  if body ~= '' then
    payload.body = body
  end
  if #queue > 0 then
    payload.comments = queue
  end

  if not opts.skip_confirm then
    local prompt
    if #queue == 0 and body == '' then
      prompt = ('%s #%d with no comments?'):format(ev.label, pr.number)
    else
      prompt = ('%s on #%d with %d line comment(s)?'):format(ev.label, pr.number, #queue)
    end
    if vim.fn.confirm(prompt, '&Yes\n&No', 2) ~= 1 then
      return
    end
  end

  local function finished()
    save_queue(pr.number, {})
    if ev.event == 'APPROVE' then
      forget_listed(pr)
    end
    notify(('#%d submitted (%s, %d line comments)'):format(pr.number, ev.label, #queue))
    if opts.on_done then
      opts.on_done()
    end
  end

  local function failed(res, what)
    local err = res.stderr
    if err == nil or err == '' then
      err = res.stdout
    end
    -- The usual cause is a comment anchored to a line outside the diff.
    notify((what or 'review failed: ') .. (err or ''), vim.log.levels.ERROR)
  end

  local reviews_endpoint = ('repos/%s/pulls/%d/reviews'):format(slug, pr.number)

  -- With a summary (or when approving, where the body is optional) the review
  -- goes out in one request.
  if body ~= '' or ev.event == 'APPROVE' then
    payload.event = ev.event
    api_post(reviews_endpoint, payload, function(res)
      if res.code ~= 0 then
        return failed(res)
      end
      finished()
    end)
    return
  end

  -- No summary: POST without an event, which creates a PENDING review and has
  -- no body requirement, then submit that review, where the body is optional.
  -- This is the same two-step the web UI performs.
  api_post(reviews_endpoint, payload, function(res)
    if res.code ~= 0 then
      return failed(res)
    end

    local ok, review = pcall(vim.json.decode, res.stdout)
    if not ok or type(review) ~= 'table' or not review.id then
      notify('could not read the pending review id from gh', vim.log.levels.ERROR)
      return
    end

    api_post(('%s/%d/events'):format(reviews_endpoint, review.id), { event = ev.event }, function(res2)
      if res2.code ~= 0 then
        -- The comments are on GitHub as a pending review; only the verdict failed.
        save_queue(pr.number, {})
        return failed(res2, 'comments posted as a pending review, but submitting failed: ')
      end
      finished()
    end)
  end)
end

function M.submit(kind)
  local pr = require_current()
  if not pr then
    return
  end
  submit_review(pr, kind)
end

--- Close the GitHub PR. Posts the gn notes and any queued line comments first.
function M.close_pr()
  local pr = require_current()
  if not pr then
    return
  end
  if not have_gh() then
    return
  end

  vim.cmd 'silent! wall'
  local body = notes_body(pr.number)
  local queue = load_queue(pr.number)

  local prompt
  if body ~= '' or #queue > 0 then
    prompt = ('Close #%d on GitHub, sending gn notes and %d line comment(s)?'):format(pr.number, #queue)
  else
    prompt = ('Close #%d on GitHub with no comment?'):format(pr.number)
  end
  if vim.fn.confirm(prompt, '&Yes\n&No', 2) ~= 1 then
    return
  end

  local function tear_down()
    close_previous(pr.number)
    M.current = nil
  end

  local function do_close()
    local cmd = { 'gh', 'pr', 'close', tostring(pr.number) }
    -- Line comments already went out as a review (with the notes as its body).
    -- Notes-only uses --comment so the close reason is on the issue thread.
    if body ~= '' and #queue == 0 then
      table.insert(cmd, '--comment')
      table.insert(cmd, body)
    end
    run(cmd, function(res)
      if res.code ~= 0 then
        local err = res.stderr
        if err == nil or err == '' then
          err = res.stdout
        end
        notify('close failed: ' .. (err or ''), vim.log.levels.ERROR)
        return
      end
      notify(('#%d closed'):format(pr.number))
      forget_listed(pr)
      tear_down()
    end)
  end

  if #queue > 0 then
    submit_review(pr, 'comment', { skip_confirm = true, on_done = do_close })
    return
  end
  do_close()
end

---------------------------------------------------------------------------
-- Permalinks, for referring to code outside the diff
---------------------------------------------------------------------------

function M.permalink()
  local slug = repo_slug()
  if not slug then
    notify('could not read the ' .. M.config.remote .. ' remote', vim.log.levels.ERROR)
    return
  end
  local rel = repo_relative(vim.fn.expand '%:p')
  if not rel then
    notify("could not work out this file's path in the repo", vim.log.levels.WARN)
    return
  end

  local sha = M.current and M.current.headRefOid
  if not sha then
    local head = vim.fn.systemlist 'git rev-parse HEAD'
    sha = head and head[1]
  end
  if not sha or sha == '' then
    notify('could not resolve a commit to link to', vim.log.levels.WARN)
    return
  end

  local first, last = cursor_range()
  local anchor = ('#L%d'):format(first)
  if last > first then
    anchor = anchor .. ('-L%d'):format(last)
  end

  local url = ('https://github.com/%s/blob/%s/%s%s'):format(slug, sha, rel, anchor)
  vim.fn.setreg('+', url)
  notify(url)
end

---------------------------------------------------------------------------
-- Keymaps
---------------------------------------------------------------------------

local function map(lhs, rhs, desc, mode)
  vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc })
end

-- Old <leader>g* review maps. Drop them so which-key only shows <leader>gr.
for _, suffix in ipairs {
  'r',
  'R',
  'i',
  'k',
  'N',
  'o',
  'f',
  'm',
  'M',
  'q',
  'Q',
  'n',
  'A',
  'C',
  'X',
  'Z',
  'y',
} do
  for _, mode in ipairs { 'n', 'x' } do
    pcall(vim.keymap.del, mode, '<leader>g' .. suffix)
  end
end
for _, mode in ipairs { 'n', 'x' } do
  pcall(vim.keymap.del, mode, '<leader>grc')
end

map('<leader>grr', M.pick, 'Review: pick a PR')
map('<leader>grR', function()
  if M.current then
    M.open_number(tostring(M.current.number), { force = true, root = M.current._root })
  else
    M.pick()
  end
end, 'Review: refresh current PR from GitHub')
map('<leader>gri', function()
  M.info()
end, 'Review: PR description + comments')
map('<leader>grl', M.commits, 'Review: PR commit log')
map('<leader>grk', M.checks, 'Review: PR checks')
map('<leader>grN', function()
  M.open_number()
end, 'Review: open PR by number')
map('<leader>gro', M.browse, 'Review: open PR in browser')
map('<leader>grf', M.open_local, 'Review: open local copy of this file (LSP)')

map('<leader>grm', M.comment, 'Review: comment on this line', { 'n', 'x' })
map('<leader>grM', M.compose, 'Review: comment (multi-line)', { 'n', 'x' })
map('<leader>grq', M.queued, 'Review: list queued comments')
map('<leader>grQ', M.clear_queue, 'Review: clear queued comments')

map('<leader>grn', M.notes, 'Review: summary notes')
map('<leader>grA', function()
  M.submit 'approve'
end, 'Review: submit approval')
map('<leader>grC', function()
  M.submit 'comment'
end, 'Review: submit comment')
map('<leader>grX', function()
  M.submit 'request'
end, 'Review: submit request-changes')
map('<leader>grZ', M.close_pr, 'Review: close PR (send gn notes)')

map('<leader>gry', M.permalink, 'Review: yank GitHub permalink', { 'n', 'x' })

-- Hunk navigation outside of diff mode (diff mode already has ]c / [c).
map(']h', function()
  require('gitsigns').nav_hunk 'next'
end, 'Next git hunk')
map('[h', function()
  require('gitsigns').nav_hunk 'prev'
end, 'Previous git hunk')

vim.api.nvim_create_user_command('PRReview', function(opts)
  if opts.args == 'all' then
    M.pick { scope = 'all', force = opts.bang }
  elseif opts.args and opts.args ~= '' then
    M.open_number(opts.args, { force = opts.bang })
  else
    M.pick { force = opts.bang }
  end
end, { bang = true, nargs = '?', desc = 'Review a PR: pick from your queue, all open PRs, or a number/url' })

vim.api.nvim_create_user_command('PRUncomment', function(opts)
  M.unqueue(opts.args)
end, { nargs = 1, desc = 'Drop a queued review comment by index' })

vim.api.nvim_create_user_command('PRClose', function()
  M.close_pr()
end, { desc = 'Close the current PR, sending gn notes and queued comments' })

return M
