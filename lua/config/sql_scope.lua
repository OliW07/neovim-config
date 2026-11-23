-- Conservative completion for local query names and projected columns.
-- Uses the existing lexer, not the database; unknown expressions are not guessed.
local M = {}
local function ident(t)
  if not t then
    return
  end
  if t.kind == 'word' then
    return t.value
  end
  if t.kind == 'quoted' then
    return t.value:sub(2, -2)
  end
end
local stops = {}
for w in
  ('WHERE PREWHERE GROUP ORDER HAVING QUALIFY LIMIT SETTINGS FORMAT UNION ON USING JOIN LEFT RIGHT INNER OUTER FULL CROSS FINAL ARRAY SAMPLE'):gmatch '%S+'
do
  stops[w] = true
end

function M.inspect(all, first, last, offset, catalog)
  local ts, close, stack = {}, {}, {}
  for n = first, last do
    if all[n].kind ~= 'comment' then
      ts[#ts + 1] = all[n]
    end
  end
  for n, t in ipairs(ts) do
    if t.value == '(' then
      stack[#stack + 1] = n
    elseif t.value == ')' and #stack > 0 then
      close[table.remove(stack)] = n
    end
  end
  for _, n in ipairs(stack) do
    close[n] = #ts + 1
  end
  local function word(n)
    return ts[n] and ts[n].value:upper() or ''
  end
  local function copy(t)
    return vim.tbl_extend('force', {}, t or {})
  end
  local active
  local parse
  parse = function(lo, hi, inherited, level)
    if lo > hi or level > 20 or not ts[lo] then
      return {}
    end
    local depth = ts[lo].depth
    -- Set-operation branches have separate aliases. Let the schema server
    -- handle these rather than mixing names from sibling SELECTs.
    for j = lo, hi do
      if ts[j].depth == depth and (word(j) == 'UNION' or word(j) == 'EXCEPT' or word(j) == 'INTERSECT') then
        return {}
      end
    end
    local env = { ctes = copy(inherited.ctes), scalars = copy(inherited.scalars) }
    local select_at, from_at, children = nil, nil, {}
    local n = lo
    -- WITH entries end at a top-level comma or the query's SELECT.
    if word(n) == 'WITH' then
      n = n + 1
      if word(n) == 'RECURSIVE' then
        n = n + 1
      end
      while n <= hi and word(n) ~= 'SELECT' do
        local finish = n
        while finish <= hi and not (ts[finish].depth == depth and (word(finish) == ',' or word(finish) == 'SELECT')) do
          finish = finish + 1
        end
        if word(n + 1) == 'AS' and word(n + 2) == '(' and (word(n + 3) == 'SELECT' or word(n + 3) == 'WITH') then
          local name = ident(ts[n])
          local ending = math.min((close[n + 2] or finish) - 1, hi)
          local columns = parse(n + 3, ending, env, level + 1)
          if name then
            env.ctes[name] = columns
          end
          children[n + 2] = true
        else
          for j = n, finish - 1 do
            if ts[j].depth == depth and word(j) == 'AS' and ident(ts[j + 1]) then
              env.scalars[ident(ts[j + 1])] = true
            end
          end
        end
        n = finish
        if word(n) == ',' then
          n = n + 1
        end
      end
    end
    for j = n, hi do
      if ts[j].depth == depth and word(j) == 'SELECT' then
        select_at = j
        break
      end
    end
    if not select_at then
      return {}
    end
    for j = select_at + 1, hi do
      if ts[j].depth == depth and (word(j) == 'FROM' or stops[word(j)]) then
        from_at = j
        break
      end
    end
    local relations = {}
    if from_at and word(from_at) == 'FROM' then
      for j = from_at + 1, hi do
        if ts[j].depth == depth then
          if word(j) == ',' then
            return {}
          end
          if stops[word(j)] then
            break
          end
        end
      end
    end
    local function resolve(name)
      if env.ctes[name] then
        return env.ctes[name]
      end
      for _, tbl in ipairs(catalog) do
        if tbl.name == name or tbl.name == 'prod.' .. name then
          local cols = {}
          for _, col in ipairs(tbl.columns) do
            cols[col.name] = col.data_type
          end
          return cols
        end
      end
      return {}
    end
    for j = select_at + 1, hi do
      if ts[j].depth == depth and (word(j) == 'FROM' or word(j) == 'JOIN') and ident(ts[j + 1]) then
        local name, k = ident(ts[j + 1]), j + 2
        if word(k) == '.' and ident(ts[k + 1]) then
          name = name .. '.' .. ident(ts[k + 1])
          k = k + 2
        end
        local cols = resolve(name)
        relations[name] = cols
        relations[name:match '([^.]+)$'] = cols
        if word(k) == 'FINAL' then
          k = k + 1
        end
        if word(k) == 'AS' then
          k = k + 1
        end
        if ident(ts[k]) and not stops[word(k)] then
          relations[ident(ts[k])] = cols
        end
      end
    end
    local columns, aliases = {}, {}
    local function column_type(a, b)
      if b == a + 2 and word(a + 1) == '.' then
        return (relations[ident(ts[a])] or {})[ident(ts[b])]
      elseif a == b and ident(ts[a]) then
        local found
        for _, cols in pairs(relations) do
          local kind = cols[ident(ts[a])]
          if kind and found and found ~= kind then
            return
          end
          found = kind or found
        end
        return found
      end
    end
    local function project(a, b)
      if word(a) == 'DISTINCT' then
        a = a + 1
      end
      for j = a, b do
        if ts[j].depth == depth and word(j) == 'AS' and ident(ts[j + 1]) then
          columns[ident(ts[j + 1])] = column_type(a, j - 1) or 'query output'
          aliases[ident(ts[j + 1])] = true
          return
        end
      end
      if a == b and ident(ts[a]) then
        columns[ident(ts[a])] = column_type(a, b) or 'query output'
      elseif b == a + 2 and word(a + 1) == '.' and ident(ts[b]) then
        columns[ident(ts[b])] = column_type(a, b) or 'query output'
      elseif a == b and word(a) == '*' then
        for _, cols in pairs(relations) do
          for name, kind in pairs(cols) do
            columns[name] = kind
          end
        end
      elseif b == a + 2 and word(b) == '*' then
        for name, kind in pairs(relations[ident(ts[a])] or {}) do
          columns[name] = kind
        end
      end
    end
    local start = select_at + 1
    local projection_end = (from_at or (hi + 1)) - 1
    for j = start, projection_end do
      if ts[j].depth == depth and word(j) == ',' then
        project(start, j - 1)
        start = j + 1
      end
    end
    if start <= projection_end then
      project(start, projection_end)
    end
    local contains = offset >= ts[lo].start - 1 and offset <= (ts[hi + 1] and ts[hi + 1].start - 1 or math.huge)
    if contains and (not active or level >= active.level) then
      active = { ctes = env.ctes, scalars = env.scalars, relations = relations, aliases = aliases, level = level }
    end
    -- Nested subqueries inherit WITH names but their own aliases stay local.
    for j = lo, hi do
      if word(j) == '(' and not children[j] and (word(j + 1) == 'SELECT' or word(j + 1) == 'WITH') then
        local ending = math.min((close[j] or hi + 1) - 1, hi)
        if offset >= ts[j].start and offset <= (ts[ending] and ts[ending].finish or offset) then
          parse(j + 1, ending, env, level + 1)
        end
      end
    end
    return columns
  end
  parse(1, #ts, { ctes = {}, scalars = {} }, 0)
  return active or { ctes = {}, scalars = {}, relations = {}, aliases = {} }
end
return M
