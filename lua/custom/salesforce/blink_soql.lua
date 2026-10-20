local source = {}

local KEYWORDS = {
  'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'IN', 'LIKE', 'INCLUDES', 'EXCLUDES',
  'NULL', 'TRUE', 'FALSE', 'LIMIT', 'OFFSET', 'ORDER BY', 'ASC', 'DESC', 'NULLS FIRST',
  'NULLS LAST', 'GROUP BY', 'HAVING', 'TYPEOF', 'WHEN', 'THEN', 'ELSE', 'END',
  'USING SCOPE', 'FOR VIEW', 'FOR REFERENCE', 'UPDATE VIEWSTAT', 'UPDATE TRACKING',
  'WITH', 'DATA CATEGORY', 'AT', 'ABOVE', 'BELOW', 'ABOVE_OR_BELOW',
  'ALL ROWS', 'ALL FIELDS', 'ALL', 'IN ALL FIELDS', 'RETURNING',
  'FIND', 'IN EMAIL FIELDS', 'IN NAME FIELDS', 'IN PHONE FIELDS',
  'IN SIDEBAR FIELDS', 'SNIPPET', 'HIGHLIGHT', 'SPELL CORRECTION', 'DIVISION',
  'NETWORK', 'PRICEBOOKID', 'WITH DIVISION', 'WITH NETWORK', 'WITH PRICEBOOKID',
  'COUNT', 'COUNT_DISTINCT', 'AVG', 'SUM', 'MIN', 'MAX',
  'TODAY', 'YESTERDAY', 'TOMORROW', 'LAST_WEEK', 'THIS_WEEK', 'NEXT_WEEK',
  'LAST_MONTH', 'THIS_MONTH', 'NEXT_MONTH', 'LAST_90_DAYS', 'NEXT_90_DAYS',
  'LAST_N_DAYS', 'NEXT_N_DAYS', 'NEXT_N_WEEKS', 'LAST_N_WEEKS',
  'NEXT_N_MONTHS', 'LAST_N_MONTHS', 'THIS_QUARTER', 'LAST_QUARTER', 'NEXT_QUARTER',
  'NEXT_N_QUARTERS', 'LAST_N_QUARTERS', 'THIS_YEAR', 'LAST_YEAR', 'NEXT_YEAR',
  'NEXT_N_YEARS', 'LAST_N_YEARS', 'THIS_FISCAL_QUARTER', 'LAST_FISCAL_QUARTER',
  'NEXT_FISCAL_QUARTER', 'NEXT_N_FISCAL_QUARTERS', 'LAST_N_FISCAL_QUARTERS',
  'THIS_FISCAL_YEAR', 'LAST_FISCAL_YEAR', 'NEXT_FISCAL_YEAR',
  'NEXT_N_FISCAL_YEARS', 'LAST_N_FISCAL_YEARS',
}

local KEYWORD_SET = {}
for _, kw in ipairs(KEYWORDS) do
  KEYWORD_SET[kw] = true
end

local function find_project_root()
  local dir = vim.fn.getcwd()
  for _ = 1, 20 do
    local check = dir .. '/sfdx-project.json'
    if vim.fn.filereadable(check) == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then
      break
    end
    dir = parent
  end
end

local function parse_sobjects()
  local root = find_project_root()
  if not root then
    return nil
  end
  local dir_path = root .. '/.sfdx/tools/sobjects/standardObjects'
  if vim.fn.isdirectory(dir_path) == 0 then
    return nil
  end

  local objects = {}
  local handle = vim.loop.fs_scandir(dir_path)
  if not handle then
    return nil
  end

  while true do
    local name, t = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    if t == 'file' and name:match '%.cls$' then
      local obj_name = name:gsub('%.cls$', '')
      local fd = io.open(dir_path .. '/' .. name, 'r')
      if fd then
        local fields = {}
        for line in fd:lines() do
          local ftype, fname = line:match 'global%s+(%S+)%s+(%S+)%s*;'
          if ftype and fname and fname ~= 'class' then
            table.insert(fields, { name = fname, type = ftype })
          end
        end
        fd:close()
        table.sort(fields, function(a, b)
          return a.name:lower() < b.name:lower()
        end)
        objects[obj_name] = fields
      end
    end
  end

  return objects
end

local function parse_froms(text)
  local froms = {}
  local text_lower = text:lower()
  local pos = 1

  while true do
    local s, e = text_lower:find('%f[%w]from%f[%W]', pos)
    if not s then
      break
    end

    local obj_name = text:sub(e + 1):match('^%s*([%w_]+)')
    if obj_name and not KEYWORD_SET[obj_name:upper()] then
      table.insert(froms, { char_pos = s, obj = obj_name })
    end

    pos = e + 1
  end

  return froms
end

local function get_soql_context(bufnr, cursor)
  -- Full buffer text
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local full = table.concat(all_lines, '\n')

  -- Text before cursor
  local before_lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor[1] + 1, false)
  before_lines[#before_lines] = before_lines[#before_lines]:sub(1, cursor[2])
  local before = table.concat(before_lines, '\n')
  local before_flat = before:gsub('%s+', ' ')

  -- Cursor char offset in full text (for matching FROM positions)
  local cursor_offset = 0
  for i = 1, cursor[1] do
    cursor_offset = cursor_offset + #all_lines[i] + 1
  end
  cursor_offset = cursor_offset + cursor[2]

  -- Completing object name if cursor is right after FROM
  local completing_from = before_flat:match('%f[%w][Ff][Rr][Oo][Mm]%f[%W]%s+[%w_]*$') ~= nil
    or before_flat:match('%f[%w][Ff][Rr][Oo][Mm]%s*$') ~= nil

  -- Find the FROM that scopes this cursor: prefer the nearest FROM before cursor,
  -- then fall back to the nearest FROM anywhere (catches SELECT fields typed before FROM)
  local froms = parse_froms(full)
  local target = nil

  -- Closest FROM before cursor
  for i = #froms, 1, -1 do
    if froms[i].char_pos <= cursor_offset then
      target = froms[i].obj
      break
    end
  end

  -- If no FROM before cursor, try the first FROM after cursor
  -- (user typed SELECT fields before writing FROM)
  if not target then
    for i = 1, #froms do
      if froms[i].char_pos > cursor_offset then
        target = froms[i].obj
        break
      end
    end
  end

  return { target_object = target, completing_from = completing_from }
end

local function make_keyword_item(kw)
  return {
    label = kw,
    kind = vim.lsp.protocol.CompletionItemKind.Keyword,
    insertText = kw,
  }
end

local function make_object_item(obj_name, fields, use_snippet)
  if use_snippet then
    return {
      label = obj_name,
      kind = vim.lsp.protocol.CompletionItemKind.Class,
      detail = 'sObject (' .. #fields .. ' fields)',
      insertText = 'SELECT Id, Name FROM ' .. obj_name,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    }
  end
  return {
    label = obj_name,
    kind = vim.lsp.protocol.CompletionItemKind.Class,
    detail = 'sObject (' .. #fields .. ' fields)',
  }
end

local function make_field_item(field, parent)
  return {
    label = field.name,
    kind = vim.lsp.protocol.CompletionItemKind.Field,
    detail = parent .. '.' .. field.name .. ' (' .. field.type .. ')',
  }
end

function source.new(_opts)
  local self = setmetatable({}, { __index = source })
  return self
end

function source:get_completions(ctx, callback)
  local objects = parse_sobjects()
  if not objects then
    callback({
      items = vim.tbl_map(make_keyword_item, KEYWORDS),
      is_incomplete_backward = false,
      is_incomplete_forward = false,
    })
    return
  end

  local context = get_soql_context(ctx.bufnr, ctx.cursor)
  local items = {}

  for _, kw in ipairs(KEYWORDS) do
    table.insert(items, make_keyword_item(kw))
  end

  if context.completing_from then
    for obj_name, fields in pairs(objects) do
      table.insert(items, make_object_item(obj_name, fields, false))
    end
  elseif context.target_object and objects[context.target_object] then
    local flds = objects[context.target_object]
    for _, f in ipairs(flds) do
      table.insert(items, make_field_item(f, context.target_object))
    end
    for _, f in ipairs(flds) do
      if objects[f.type] then
        table.insert(items, {
          label = f.name .. '.',
          kind = vim.lsp.protocol.CompletionItemKind.Field,
          detail = f.type .. ' fields',
        })
      end
    end
  else
    -- Show objects with snippet expansion (fresh query)
    for obj_name, fields in pairs(objects) do
      table.insert(items, make_object_item(obj_name, fields, true))
    end
    for obj_name, fields in pairs(objects) do
      for _, f in ipairs(fields) do
        table.insert(items, make_field_item(f, obj_name))
      end
    end
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

function source:resolve(item, callback)
  callback(item)
end

return source
