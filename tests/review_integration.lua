-- Run with the real config from a local fixture checkout. See tests/README.md.
local counts, messages = {}, {}
local fetch_count = 0
local original_system = vim.system
vim.system = function(cmd, opts, callback)
  if cmd[1] == 'git' and cmd[2] == 'fetch' then
    fetch_count = fetch_count + 1
  end
  if cmd[1] ~= 'gh' then
    return original_system(cmd, opts, callback)
  end
  if cmd[2] == 'api' then
    local killed = false
    vim.defer_fn(function()
      callback { code = killed and 143 or 0, stdout = '[]', stderr = '' }
    end, 40)
    return {
      kill = function()
        killed = true
      end,
    }
  end
  assert(cmd[2] == 'pr' and cmd[3] == 'view', 'unexpected network command')
  local number = tonumber(cmd[4])
  counts[number] = (counts[number] or 0) + 1
  local killed = false
  vim.defer_fn(function()
    callback {
      code = killed and 143 or 0,
      stdout = vim.json.encode {
        number = number,
        title = 'Fixture ' .. number,
        body = 'Summary fixture',
        author = { login = 'tester' },
        baseRefName = 'production',
        headRefName = 'feature',
        state = 'OPEN',
        url = 'https://example.invalid/' .. number,
        commits = {},
      },
      stderr = '',
    }
  end, 40)
  return {
    kill = function()
      killed = true
    end,
  }
end
vim.notify = function(message)
  messages[#messages + 1] = message
end
local function pr(number)
  return { number = number, title = 'Fixture ' .. number, baseRefName = 'production', headRefName = 'feature' }
end
local function summary_visible(number)
  return vim.api.nvim_buf_get_name(0):match('PR #' .. number .. '$') ~= nil
end
vim.defer_fn(function()
  local ok, err = xpcall(function()
    local review = require 'config.review'
    vim.o.columns = 160
    vim.o.lines = 50
    local first = pr(1)
    first.body = ('A long paragraph that must wrap at word boundaries. '):rep(80) .. '\n' .. ('More description details\n'):rep(100) .. 'END OF DESCRIPTION'
    review.show_picker({ first }, nil)
    local initial_prompt = vim.api.nvim_get_current_buf()
    local initial_picker = require('telescope.actions.state').get_current_picker(initial_prompt)
    assert(
      vim.wait(1000, function()
        local buf = initial_picker.previewer.state and initial_picker.previewer.state.bufnr
        return buf and table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'):find(first.body, 1, true)
      end, 1),
      'description should render before network response'
    )
    local preview_win = initial_picker.previewer.state.winid
    local preview_buf = initial_picker.previewer.state.bufnr
    assert(vim.wo[preview_win].wrap and vim.wo[preview_win].linebreak and vim.wo[preview_win].smoothscroll, 'preview must wrap and scroll long paragraphs')
    assert(vim.api.nvim_win_get_width(preview_win) > 120, 'description should use the wide layout')
    local function viewport()
      return vim.api.nvim_win_call(preview_win, vim.fn.winsaveview)
    end
    local before_scroll = viewport()
    require('telescope.actions').preview_scrolling_down(initial_prompt)
    local after_scroll = viewport()
    assert(after_scroll.topline > before_scroll.topline or after_scroll.skipcol > before_scroll.skipcol, 'preview paging must advance the viewport')
    local end_map = vim.fn.maparg('<C-End>', 'i', false, true)
    end_map.callback()
    assert(vim.api.nvim_win_get_cursor(preview_win)[1] == vim.api.nvim_buf_line_count(preview_buf), 'end mapping must reach all details')
    vim.fn.maparg('<C-Home>', 'i', false, true).callback()
    assert(vim.api.nvim_win_get_cursor(preview_win)[1] == 1, 'home mapping must return to the start')
    assert(not counts[1], 'first preview must not wait for GitHub')
    require('telescope.actions').close(initial_prompt)
    vim.wait(260, function()
      return false
    end)
    assert(fetch_count == 0 and not counts[1], 'closing promptly must cancel deferred preview work')
    review.show_picker({ first }, nil)
    initial_prompt = vim.api.nvim_get_current_buf()
    assert(
      vim.wait(2000, function()
        return fetch_count == 1
      end),
      'reading the preview must prefetch Git refs'
    )
    assert(not review.current, 'prefetch must not open a review')
    local start = vim.uv.hrtime()
    require('telescope.actions').select_default(initial_prompt)
    assert(
      vim.wait(5000, function()
        return summary_visible(1)
      end),
      'populated PR summary: ' .. table.concat(messages, '\n')
    )
    local first_ms = (vim.uv.hrtime() - start) / 1e6
    assert(fetch_count == 1, 'selecting prefetched PR must not fetch twice')
    assert(first_ms < 1900, 'summary still waits on fallback timer')
    local view = require('diffview.lib').get_current_view()
    assert(view and view.files:len() == 1, 'diff must contain feature change')
    view:set_file(view.panel:ordered_file_list()[1], true)
    assert(
      vim.wait(2000, function()
        return vim.api.nvim_buf_get_name(0):match 'sample.txt$' ~= nil
      end),
      'file navigation after summary'
    )
    start = vim.uv.hrtime()
    review.open(pr(2))
    assert(
      vim.wait(5000, function()
        return summary_visible(2)
      end),
      'empty PR summary'
    )
    local empty_ms = (vim.uv.hrtime() - start) / 1e6
    assert(empty_ms < 1900, 'empty PR still waits two seconds')
    review.open(pr(1))
    assert(
      vim.wait(5000, function()
        return summary_visible(1)
      end),
      'reopen summary'
    )
    assert(counts[1] == 1, 'reopen should reuse summary')
    assert(fetch_count == 2 and review.last_open.cached, 'reopening must not repeat network fetch')
    review.info()
    assert(
      vim.wait(2000, function()
        return counts[1] == 2
      end),
      'explicit refresh'
    )
    vim.wait(100, function()
      return false
    end)
    review.open(pr(2))
    review.open(pr(1))
    assert(
      vim.wait(5000, function()
        return review.current.number == 1 and summary_visible(1)
      end),
      'latest request wins'
    )
    vim.wait(300, function()
      return false
    end)
    assert(review.current.number == 1, 'stale fetch must not replace review')
    review.open_number(2)
    review.open(pr(1))
    vim.wait(400, function()
      return false
    end)
    assert(review.current.number == 1, 'late metadata must not supersede a newer open')
    vim.o.columns = 160
    vim.o.lines = 50
    local before_picker = counts[1]
    review.show_picker({ pr(1) }, nil)
    local prompt = vim.api.nvim_get_current_buf()
    local picker = require('telescope.actions.state').get_current_picker(prompt)
    assert(
      vim.wait(2000, function()
        local buf = picker.previewer.state and picker.previewer.state.bufnr
        return buf and table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'):find 'Summary fixture'
      end),
      'real Telescope preview must render cached summary'
    )
    require('telescope.actions').select_default(prompt)
    assert(
      vim.wait(2000, function()
        return summary_visible(1)
      end),
      'picker selection opens review'
    )
    assert(counts[1] == before_picker, 'picker-to-open must reuse summary without another request')
    local before_refresh = fetch_count
    review.open(pr(1), { force = true })
    assert(
      vim.wait(2000, function()
        return fetch_count == before_refresh + 1 and not review.last_open.cached
      end),
      'force must fetch fresh refs'
    )
    assert(
      vim.wait(2000, function()
        return summary_visible(1)
      end),
      'refreshed summary'
    )
    vim.fn.system { 'git', 'update-ref', '-d', 'refs/pr/1' }
    review.open(pr(1))
    assert(
      vim.wait(2000, function()
        return fetch_count == before_refresh + 2
      end),
      'missing local refs must invalidate cache'
    )
    assert(
      vim.wait(2000, function()
        return summary_visible(1)
      end),
      'missing refs recovered'
    )
    assert(#messages == 0, 'successful review navigation should not emit routine notifications: ' .. table.concat(messages, '; '))
    vim.fn.writefile(
      { ('PASS populated %.1fms; empty %.1fms; navigation, cache, refresh, latest-open, metadata race, Telescope handoff'):format(first_ms, empty_ms) },
      vim.env.REVIEW_TEST_RESULT
    )
  end, debug.traceback)
  if not ok then
    vim.fn.writefile({ err, table.concat(messages, '\n') }, vim.env.REVIEW_TEST_RESULT)
    vim.cmd 'cquit 1'
  end
  vim.cmd 'qa!'
end, 300)
