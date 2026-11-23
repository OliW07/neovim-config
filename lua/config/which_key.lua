-- Description-only presets. Actual mappings (including buffer-local LSP maps)
-- keep their own labels and actions. See :help index for the native commands.
local spec = { preset = true }

local function commands(prefix, modes, descriptions)
  local group = { mode = modes }
  for key, desc in pairs(descriptions) do
    group[#group + 1] = { prefix .. key, desc = desc }
  end
  spec[#spec + 1] = group
end

commands('', { 'n', 'x', 'o' }, {
  h = 'Left',
  j = 'Down',
  k = 'Up',
  l = 'Right',
  ['^'] = 'First nonblank on line',
  ['|'] = 'Go to column',
  ['('] = 'Previous sentence',
  [')'] = 'Next sentence',
  [';'] = 'Repeat character search',
  [','] = 'Reverse character search',
  n = 'Next search match',
  N = 'Previous search match',
  ['*'] = 'Search word forward',
  ['#'] = 'Search word backward',
})
commands('', 'n', {
  a = 'Append after cursor',
  A = 'Append at end of line',
  i = 'Insert before cursor',
  I = 'Insert at first nonblank',
  o = 'Open line below',
  O = 'Open line above',
  p = 'Paste after',
  P = 'Paste before',
  u = 'Undo',
  ['<C-r>'] = 'Redo',
  ['.'] = 'Repeat change',
  J = 'Join lines',
  x = 'Delete character',
  D = 'Delete to end of line',
  C = 'Change to end of line',
  S = 'Change line',
  R = 'Replace mode',
  ['='] = 'Reindent text',
  ['<C-v>'] = 'Blockwise selection',
  ['q:'] = 'Command history window',
  ['q/'] = 'Forward search history',
  ['q?'] = 'Backward search history',
})
commands('g', { 'n', 'x', 'o' }, {
  j = 'Down one screen line',
  k = 'Up one screen line',
  ['0'] = 'Start of screen line',
  ['^'] = 'First nonblank on screen line',
  ['$'] = 'End of screen line',
  ['_'] = 'Last nonblank on line',
  m = 'Middle of screen line',
  M = 'Middle of text line',
  E = 'End of previous WORD',
  o = 'Go to byte offset',
  ['*'] = 'Search word forward (partial match)',
  ['#'] = 'Search word backward (partial match)',
  ["'"] = 'Go to marked line (keep jumplist)',
  ['`'] = 'Go to mark (keep jumplist)',
  ['<Down>'] = 'Down one screen line',
  ['<Up>'] = 'Up one screen line',
  ['<Home>'] = 'Start of screen line',
  ['<End>'] = 'Last nonblank on screen line',
})

commands('g', { 'n', 'x' }, {
  q = 'Format text',
  w = 'Format text and keep cursor',
  J = 'Join without adding spaces',
  a = 'Show character value',
  ['8'] = 'Show UTF-8 bytes',
  ['<C-g>'] = 'Show cursor statistics',
  ['+'] = 'Newer undo state',
  ['-'] = 'Older undo state',
  f = 'Open file under cursor',
  F = 'Open file at referenced line',
  d = 'Go to local declaration',
  D = 'Go to file-wide declaration',
  ['<C-]>'] = 'Jump to matching tag',
  [']'] = 'Choose matching tag',
  ['<lt>'] = 'Show previous command output',
  ['&'] = 'Repeat substitution across file',
  ['?'] = 'ROT13 text',
  ['@'] = 'Run custom operator',
  p = 'Paste after and move past text',
  P = 'Paste before and move past text',
  h = 'Start Select mode',
  H = 'Start linewise Select mode',
  ['<C-h>'] = 'Start blockwise Select mode',
  ['<Tab>'] = 'Last accessed tab',
  ['<LeftMouse>'] = 'Jump to tag at mouse',
  ['<RightMouse>'] = 'Jump back from tag at mouse',
  ['<MiddleMouse>'] = 'Ctrl-middle mouse click',
})

commands('g', 'n', {
  I = 'Insert at column one',
  Q = 'Enter Ex mode',
  R = 'Enter Virtual Replace mode',
  r = 'Virtual replace character',
  s = 'Sleep for count seconds',
  V = 'Suppress Visual reselection',
})
commands('g', 'x', {
  ['<C-a>'] = 'Increment successive numbers',
  ['<C-x>'] = 'Decrement successive numbers',
  v = 'Exchange current and previous selections',
  q = 'Format selected lines',
  J = 'Join selected lines without spaces',
})

commands('z', { 'n', 'x' }, {
  ['+'] = 'Show next page at top',
  ['-'] = 'Show line at bottom, first nonblank',
  ['.'] = 'Center line, first nonblank',
  ['^'] = 'Show previous page at bottom',
  F = 'Fold counted lines',
  G = 'Mark spelling good for this session',
  W = 'Mark spelling bad for this session',
  N = 'Enable folding',
  n = 'Disable folding',
  X = 'Reapply fold level',
  j = 'Start of next fold',
  k = 'End of previous fold',
  h = 'Scroll view left',
  l = 'Scroll view right',
  ['<Left>'] = 'Scroll view left',
  ['<Right>'] = 'Scroll view right',
  p = 'Block paste after, trim trailing spaces',
  P = 'Block paste before, trim trailing spaces',
  y = 'Yank without trailing spaces',
  uw = 'Undo bad spelling',
  ug = 'Undo good spelling',
  uW = 'Undo session bad spelling',
  uG = 'Undo session good spelling',
})
commands('z', 'o', { j = 'Start of next fold', k = 'End of previous fold' })

for _, prefix in ipairs { '[', ']' } do
  local prev = prefix == '['
  local where = prev and 'previous' or 'next'
  commands(prefix, { 'n', 'x', 'o' }, {
    ["'"] = 'Line of ' .. where .. ' mark',
    ['`'] = 'Go to ' .. where .. ' mark',
    ['#'] = 'Go to ' .. where .. ' preprocessor branch',
    ['/'] = prev and 'Start of C comment' or 'End of C comment',
    ['*'] = prev and 'Start of C comment' or 'End of C comment',
    ['['] = prev and 'Previous section start' or 'Next section end',
    [']'] = prev and 'Previous section end' or 'Next section start',
    z = prev and 'Start of open fold' or 'End of open fold',
    [prev and '(' or ')'] = 'Go to unmatched parenthesis',
    [prev and '{' or '}'] = 'Go to unmatched brace',
    c = 'Go to ' .. where .. ' diff change',
    s = 'Go to ' .. where .. ' spelling error',
    m = prev and 'Previous method start' or 'Next method end',
  })
  commands(prefix, 'n', {
    d = 'Show matching definition',
    D = 'List matching definitions',
    ['<C-d>'] = 'Jump to matching definition',
    i = 'Show matching include line',
    I = 'List matching include lines',
    ['<C-i>'] = 'Jump to matching include line',
    f = 'Open file under cursor',
    p = prev and 'Paste before with matching indent' or 'Paste after with matching indent',
    P = 'Paste before with matching indent',
    ['<MiddleMouse>'] = 'Paste with matching indent',
  })
end

local windows = {
  b = 'Bottom window',
  c = 'Close window',
  d = 'Split at definition',
  f = 'Split at file',
  F = 'Split at file and line',
  h = 'Window left',
  i = 'Split at declaration',
  j = 'Window below',
  k = 'Window above',
  l = 'Window right',
  n = 'New window',
  o = 'Close other windows',
  p = 'Previous window',
  q = 'Quit window',
  r = 'Rotate windows down',
  s = 'Horizontal split',
  t = 'Top window',
  v = 'Vertical split',
  w = 'Next window',
  x = 'Exchange windows',
  z = 'Close preview',
  [']'] = 'Split at tag',
  ['^'] = 'Split at alternate file',
  ['_'] = 'Set window height',
  ['|'] = 'Set window width',
  ['}'] = 'Preview tag',
  P = 'Go to preview',
  R = 'Rotate windows up',
  S = 'Horizontal split',
  W = 'Previous window in layout',
  ['<Left>'] = 'Window left',
  ['<Down>'] = 'Window below',
  ['<Up>'] = 'Window above',
  ['<Right>'] = 'Window right',
  ['g<C-]>'] = 'Split and jump to tag',
  ['g]'] = 'Split and choose tag',
  ['g}'] = 'Choose tag to preview',
  gf = 'Open file in new tab',
  gF = 'Open file at line in new tab',
  gt = 'Next tab',
  gT = 'Previous tab',
  ['g<Tab>'] = 'Last accessed tab',
}
for key in ('bdfhijklnopqrstvwxz]^_'):gmatch '%S' do
  windows['<C-' .. key .. '>'] = windows[key]
end
commands('<C-w>', { 'n', 'x' }, windows)
commands('Z', 'n', { Z = 'Save changes and close', Q = 'Close without saving' })

commands('<C-x>', 'i', {
  ['<C-d>'] = 'Complete definitions',
  ['<C-e>'] = 'Scroll up',
  ['<C-y>'] = 'Scroll down',
  ['<C-f>'] = 'Complete file names',
  ['<C-i>'] = 'Complete included keywords',
  ['<C-k>'] = 'Complete from dictionary',
  ['<C-l>'] = 'Complete whole lines',
  ['<C-n>'] = 'Next buffer keyword',
  ['<C-p>'] = 'Previous buffer keyword',
  ['<C-o>'] = 'Omni completion',
  ['<C-r>'] = 'Complete from registers',
  ['<C-s>'] = 'Spelling suggestions',
  s = 'Spelling suggestions',
  ['<C-t>'] = 'Complete from thesaurus',
  ['<C-u>'] = 'User-defined completion',
  ['<C-v>'] = 'Command-line completion',
  ['<C-z>'] = 'Stop completion',
  ['<C-]>'] = 'Complete tags',
})

return spec
