local M = {}
local state_file = vim.fn.stdpath 'state' .. '/sql-output-window.json'
local placement = { side = 'bottom', size = 15 }
local commands = {
  bottom = 'botright %dnew',
  top = 'topleft %dnew',
  right = 'botright %dvnew',
  left = 'topleft %dvnew',
}
local ok, saved = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(state_file), '\n'))
end)
if ok and type(saved) == 'table' and commands[saved.side] and type(saved.size) == 'number' and saved.size >= 1 and saved.size == math.floor(saved.size) then
  placement = saved
end

-- The parent split determines which edge this window occupies.
local function side_of(layout, win)
  if layout[1] == 'leaf' then
    return
  end
  for i, child in ipairs(layout[2]) do
    if child[1] == 'leaf' and child[2] == win then
      if layout[1] == 'row' then
        return i == 1 and 'left' or 'right'
      end
      return i == 1 and 'top' or 'bottom'
    end
    local side = side_of(child, win)
    if side then
      return side
    end
  end
end

function M.remember(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.b[buf].chq_output then
    return
  end
  local tab = vim.api.nvim_win_get_tabpage(win)
  local side = side_of(vim.fn.winlayout(vim.api.nvim_tabpage_get_number(tab)), win)
  if not side then
    return
  end -- Floating or sole remaining window.
  local vertical = side == 'left' or side == 'right'
  local size = vertical and vim.api.nvim_win_get_width(win) or vim.api.nvim_win_get_height(win)
  if placement.side == side and placement.size == size then
    return
  end
  placement = { side = side, size = size }
  vim.fn.mkdir(vim.fn.fnamemodify(state_file, ':h'), 'p')
  vim.fn.writefile({ vim.json.encode(placement) }, state_file)
end

function M.open(previous)
  local reuse
  for _, buf in ipairs(previous) do
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      M.remember(win)
      if vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage() then
        reuse = reuse or win
      end
    end
  end
  if reuse then
    vim.api.nvim_set_current_win(reuse)
    vim.api.nvim_win_set_buf(reuse, vim.api.nvim_create_buf(false, true))
  else
    vim.cmd(commands[placement.side]:format(placement.size))
  end
  local output = vim.api.nvim_get_current_win()
  -- Retire only this mapping's previous outputs, keeping the reused split.
  for _, buf in ipairs(previous) do
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.api.nvim_set_current_win(output)
  vim.b.chq_output = true
end

local group = vim.api.nvim_create_augroup('SqlOutputPlacement', { clear = true })
vim.api.nvim_create_autocmd({ 'WinLeave', 'BufWinLeave', 'VimLeavePre' }, {
  group = group,
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      M.remember(win)
    end
  end,
})
vim.api.nvim_create_autocmd('WinResized', {
  group = group,
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      M.remember(win)
    end
  end,
})

return M
