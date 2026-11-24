local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/folder', 'p')
vim.fn.writefile({ 'test' }, root .. '/sample.txt')
vim.cmd('edit ' .. root .. '/example.py')
local cmp = require 'blink.cmp'
local function later(ms, fn)
  vim.defer_fn(function()
    local ok, err = pcall(fn)
    if not ok then print(err); vim.cmd 'cquit 1' end
  end, ms)
end
local function check(prefix, typed, expected, done)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { prefix })
  vim.api.nvim_win_set_cursor(0, { 1, #prefix })
  vim.cmd 'startinsert!'
  later(150, function() vim.api.nvim_input(typed) end)
  later(800, function()
    assert(cmp.is_visible(), 'missing completion for ' .. prefix)
    local items = cmp.get_items()
    local index
    for i, item in ipairs(items) do if item.source_id == 'path' and item.label == expected then index = i; break end end
    assert(index, vim.inspect(items))
    cmp.accept { index = index }
  end)
  later(1100, function()
    assert(vim.api.nvim_get_current_line() == prefix .. typed .. expected:sub(#(prefix:match('[^/"\']*$') .. typed) + 1), vim.api.nvim_get_current_line())
    vim.api.nvim_input(vim.keycode '<Esc>')
    later(100, done)
  end)
end
check('open("sam', 'p', 'sample.txt', function()
  check('open("./fol', 'd', 'folder/', function()
    vim.fn.delete(root, 'rf')
    print 'PASS path completion in Python strings'
    vim.cmd 'qa!'
  end)
end)
