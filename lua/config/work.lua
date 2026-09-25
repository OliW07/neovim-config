-- Work-machine extras. Home C++ clangd-22 stays preferred when present.

-- Flutter before Homebrew's standalone `dart`. dartls cannot resolve
-- package:flutter (or run `flutter pub get` analysis) on the brew SDK.
-- Must run before plugins.lsp enables dartls.
local flutter_root = vim.fn.expand '~/develop/flutter'
local flutter_bin = flutter_root .. '/bin'
if vim.fn.isdirectory(flutter_bin) == 1 then
  vim.env.FLUTTER_ROOT = vim.env.FLUTTER_ROOT or flutter_root
  if not vim.env.PATH:find(flutter_bin, 1, true) then
    vim.env.PATH = flutter_bin .. ':' .. vim.env.PATH
  end
end

-- gf on WYA-1234 opens the Linear issue. Hyphen is not in 'iskeyword', so
-- <cword> / default gf cannot see the identifier; scan the line instead.
local LINEAR_WORKSPACE = 'luminpdf'
local LINEAR_ISSUE = '[Ww][Yy][Aa]%-%d+'

local function linear_issue_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local start = 1
  while true do
    local s, e = line:find(LINEAR_ISSUE, start)
    if not s then
      return
    end
    if col >= s and col <= e then
      return line:sub(s, e):upper()
    end
    start = e + 1
  end
end

vim.keymap.set('n', 'gf', function()
  local ok, review = pcall(require, 'config.review')
  if ok and review.goto_commit_under_cursor and review.goto_commit_under_cursor() then
    return
  end
  local issue = linear_issue_under_cursor()
  if issue then
    vim.ui.open(('https://linear.app/%s/issue/%s'):format(LINEAR_WORKSPACE, issue))
    return
  end
  vim.cmd 'normal! gf'
end, { desc = 'Go to file, Linear issue, or commit hash / PR commit diff' })
