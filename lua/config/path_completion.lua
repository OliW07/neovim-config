-- Blink's path source requires a slash. Also complete bare names inside strings.
local path = require 'blink.cmp.sources.path'
local M = {}

function M.new(opts)
  local source = path.new(opts)
  local complete = source.get_completions
  function source:get_completions(ctx, callback)
    local before = ctx.line:sub(1, ctx.cursor[2])
    local quote = before:match('()(["\'])[^"\']*$')
    local fragment = quote and before:sub(quote + 1)
    if not fragment or fragment:find '[/\\]' then
      return complete(self, ctx, callback)
    end

    -- Present an implicit ./ to Blink, then translate edits back to the real line.
    local virtual = vim.deepcopy(ctx)
    virtual.line = ctx.line:sub(1, quote) .. './' .. ctx.line:sub(quote + 1)
    virtual.cursor[2] = virtual.cursor[2] + 2
    virtual.bounds.start_col = virtual.bounds.start_col + 2
    return complete(self, virtual, function(result)
      for _, item in ipairs(result and result.items or {}) do
        local range = item.textEdit and item.textEdit.range
        if range then
          range.start.character = range.start.character - 2
          range['end'].character = range['end'].character - 2
        end
      end
      callback(result)
    end)
  end
  return source
end

return M
