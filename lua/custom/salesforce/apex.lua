local M = {}

---@alias SfOrg { alias: string, username: string, is_last_used: boolean }

local state_file = vim.fn.stdpath 'state' .. '/sf_apex_state.json'


local function load_state()
  local fd = io.open(state_file, 'r')
  if not fd then
    return {}
  end
  local contents = fd:read '*a'
  fd:close()
  local ok, data = pcall(vim.json.decode, contents)
  if not ok or type(data) ~= 'table' then
    return {}
  end
  return data
end

local function save_state(data)
  local dir = vim.fn.fnamemodify(state_file, ':h')
  pcall(vim.fn.mkdir, dir, 'p')
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return
  end
  local fd = io.open(state_file, 'w')
  if not fd then
    return
  end
  fd:write(encoded)
  fd:close()
end

local function sort_orgs(orgs)
  table.sort(orgs, function(a, b)
    if a.is_last_used ~= b.is_last_used then
      return a.is_last_used
    end
    return a.alias < b.alias
  end)
end

local function annotate_and_sort(orgs, last_username)
  for _, org in ipairs(orgs) do
    org.is_last_used = (last_username == org.username)
  end
  sort_orgs(orgs)
  return orgs
end

local function fetch_orgs(callback)
  local stdout_data = {}
  vim.fn.jobstart('sf org list --json', {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stdout_data, line)
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback({})
        return
      end
      local raw = table.concat(stdout_data, '\n')
      local ok, data = pcall(vim.json.decode, raw)
      if not ok then
        callback({})
        return
      end

      local orgs = {}

      local function collect(category)
        if not category then
          return
        end
        for _, org in ipairs(category) do
          if org.connectedStatus == 'Connected' then
            table.insert(orgs, {
              alias = org.alias or org.username,
              username = org.username,
            })
          end
        end
      end

      collect(data.result and data.result.other)
      collect(data.result and data.result.sandboxes)

      -- Persist cache
      local state = load_state()
      state.org_cache = { timestamp = os.time(), orgs = vim.deepcopy(orgs) }
      save_state(state)

      callback(annotate_and_sort(orgs, state.last_org_username))
    end,
  })
end

local function get_orgs(callback)
  local state = load_state()
  local cache = state.org_cache

  if cache and cache.orgs and #cache.orgs > 0 then
    callback(annotate_and_sort(vim.deepcopy(cache.orgs), state.last_org_username))
    return
  end

  fetch_orgs(callback)
end

function M.clear_org_cache()
  local state = load_state()
  state.org_cache = nil
  save_state(state)
end

function M.refresh_orgs()
  M.clear_org_cache()
  fetch_orgs(function(orgs)
    if #orgs == 0 then
      vim.notify('No connected orgs found', vim.log.levels.WARN)
    else
      vim.notify('Org list refreshed (' .. #orgs .. ' orgs)')
    end
  end)
end

function M.pick_org(callback)
  get_orgs(function(orgs)
    if #orgs == 0 then
      vim.notify('No connected orgs found', vim.log.levels.WARN)
      return
    end
    local items = {}
    for _, org in ipairs(orgs) do
      local label = org.alias
      if org.alias ~= org.username then
        label = label .. ' (' .. org.username .. ')'
      end
      if org.is_last_used then
        label = '[last used] ' .. label
      end
      table.insert(items, { label = label, value = org })
    end
    vim.ui.select(items, {
      prompt = 'Select target org:',
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if choice then
        callback(choice.value)
      end
    end)
  end)
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
  return nil
end

function M.open_scratch()
  local root = find_project_root()
  if not root then
    vim.notify('Not in a Salesforce DX project', vim.log.levels.WARN)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/.sfdx/anonymous.apex'))
end

function M.open_soql()
  local root = find_project_root()
  if not root then
    vim.notify('Not in a Salesforce DX project', vim.log.levels.WARN)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/.sfdx/query.soql'))
end

function M.open_sosl()
  local root = find_project_root()
  if not root then
    vim.notify('Not in a Salesforce DX project', vim.log.levels.WARN)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/.sfdx/search.sosl'))
end

-- One reusable result window per execution kind. Apex opens a vertical split,
-- queries open a horizontal split.
local outputs = {
  apex = { buf = nil, win = nil },
  query = { buf = nil, win = nil },
}

local function is_output_win(win)
  for _, output in pairs(outputs) do
    if output.win == win and vim.api.nvim_win_is_valid(output.win) then
      return true
    end
  end
  return false
end

local function source_window()
  local current = vim.api.nvim_get_current_win()
  if not is_output_win(current) then
    return current
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_output_win(win) then
      return win
    end
  end
  return current
end

local function close_output(kind)
  local output = outputs[kind]
  if output.win and vim.api.nvim_win_is_valid(output.win) then
    vim.api.nvim_win_close(output.win, true)
  end
  output.win = nil
  output.buf = nil
end

local function focus_output(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

local function set_output(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function ensure_output(kind, src_win)
  local output = outputs[kind]
  if output.buf and vim.api.nvim_buf_is_valid(output.buf) and output.win and vim.api.nvim_win_is_valid(output.win) then
    return output.buf, output.win
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = kind == 'apex' and 'log' or 'text'
  pcall(vim.api.nvim_buf_set_name, buf, ('sf://%s-output'):format(kind))

  local win = vim.api.nvim_open_win(buf, false, {
    split = kind == 'apex' and 'right' or 'below',
    win = src_win,
  })

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  if kind == 'apex' then
    -- Vertical split: code output gets ~60% of the width.
    local width = math.max(40, math.floor(vim.o.columns * 0.60))
    vim.api.nvim_win_set_width(win, math.min(width, math.max(20, vim.o.columns - 30)))
  else
    -- Horizontal split: query results get ~70%, source buffer keeps the rest.
    local height = math.max(5, math.floor(vim.o.lines * 0.70))
    vim.api.nvim_win_set_height(win, math.min(height, vim.o.lines - 3))
  end

  output.buf = buf
  output.win = win
  return buf, win
end

local function parse_result(raw_json)
  local ok, data = pcall(vim.json.decode, raw_json)
  if not ok then
    return nil, nil, 'Failed to parse output'
  end
  local result = data.result or data.data
  if not result then
    return nil, nil, data.message or 'No result returned'
  end
  if result.totalSize ~= nil or result.searchRecords ~= nil then
    return result, 'query', nil
  end
  if result.compiled ~= nil then
    return result, 'apex', nil
  end
  return nil, nil, data.message or 'Unknown result format'
end

local function sanitise_lines(raw_lines)
  local sanitised = {}
  for _, line in ipairs(raw_lines) do
    for _, subline in ipairs(vim.split(line, '\n', { plain = true })) do
      table.insert(sanitised, subline)
    end
  end
  return sanitised
end

local function format_value(value)
  if value == nil or value == vim.NIL then
    return ''
  end
  if type(value) == 'table' then
    local ok, encoded = pcall(vim.json.encode, value)
    return ok and encoded or vim.inspect(value)
  end
  if type(value) == 'boolean' then
    return value and 'true' or 'false'
  end
  -- Keep multi-line field values on one table row.
  return (tostring(value):gsub('[\r\n\t]', ' '))
end

local function truncate(value, max_width)
  if vim.fn.strdisplaywidth(value) <= max_width then
    return value
  end
  return vim.fn.strcharpart(value, 0, max_width - 1) .. '…'
end

--- Render query records as an aligned table. Works for both SOQL (`records`)
--- and SOSL (`searchRecords`).
local function query_lines(result)
  local records = result.records or result.searchRecords or {}
  local total = result.totalSize or #records
  if #records == 0 then
    return { ('%d record(s)'):format(total) }
  end

  -- Collect columns in a stable order, with Id/Name first.
  local columns, seen = {}, {}
  for _, record in ipairs(records) do
    for key in pairs(record) do
      if key ~= 'attributes' and not seen[key] then
        seen[key] = true
        columns[#columns + 1] = key
      end
    end
  end
  local priority = { Id = 1, Name = 2 }
  table.sort(columns, function(a, b)
    local pa = priority[a] or 100
    local pb = priority[b] or 100
    if pa ~= pb then
      return pa < pb
    end
    return a < b
  end)

  local max_column_width = 60
  local widths = {}
  for i, column in ipairs(columns) do
    widths[i] = vim.fn.strdisplaywidth(column)
  end

  local rows = {}
  for _, record in ipairs(records) do
    local row = {}
    for i, column in ipairs(columns) do
      local value = truncate(format_value(record[column]), max_column_width)
      row[i] = value
      widths[i] = math.max(widths[i], vim.fn.strdisplaywidth(value))
    end
    rows[#rows + 1] = row
  end

  local function pad(value, width)
    return value .. string.rep(' ', width - vim.fn.strdisplaywidth(value))
  end

  local function render(cells)
    local parts = {}
    for i, cell in ipairs(cells) do
      parts[i] = pad(cell, widths[i])
    end
    return table.concat(parts, '  ')
  end

  local lines = { ('%d record(s)'):format(total), '' }
  lines[#lines + 1] = render(columns)
  local separators = {}
  for i, width in ipairs(widths) do
    separators[i] = string.rep('-', width)
  end
  lines[#lines + 1] = render(separators)
  for _, row in ipairs(rows) do
    lines[#lines + 1] = render(row)
  end
  return lines
end

--- Format an Apex execution result.
local function apex_lines(result)
  if not result.compiled then
    local lines = { 'Compilation failed:', '' }
    vim.list_extend(lines, vim.split(result.compileProblem or 'Unknown compilation error', '\n'))
    return lines
  end

  if not result.success then
    local lines = { 'Exception:', '' }
    if result.exceptionMessage then
      vim.list_extend(lines, vim.split(result.exceptionMessage, '\n'))
    end
    if result.exceptionStackTrace then
      if #lines > 2 then
        lines[#lines + 1] = ''
      end
      vim.list_extend(lines, vim.split(result.exceptionStackTrace, '\n'))
    end
    if #lines == 2 then
      lines[#lines + 1] = 'Unknown exception'
    end
    return lines
  end

  if result.logs and result.logs ~= '' then
    return vim.split(result.logs, '\n')
  end
  return { 'Success (no debug log)' }
end

function M.run_anonymous(org)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local ft = vim.bo[bufnr].filetype

  -- Record this org as last used
  save_state { last_org_username = org.username }

  local tmpfile = nil
  local cleanup = nil

  if vim.bo[bufnr].buftype == '' and fname ~= '' then
    tmpfile = fname
  else
    local suffix = ({ apex = '.apex', soql = '.soql', sosl = '.sosl' })[ft] or '.apex'
    tmpfile = vim.fn.tempname() .. suffix
    local fd = io.open(tmpfile, 'w')
    if not fd then
      vim.notify('Failed to create temp file', vim.log.levels.ERROR)
      return
    end
    fd:write(table.concat(lines, '\n'))
    fd:close()
    cleanup = function()
      os.remove(tmpfile)
    end
  end

  local cmd
  if ft == 'soql' then
    cmd = { 'sf', 'data', 'query', '--target-org', org.alias or org.username, '--file', tmpfile, '--json' }
  elseif ft == 'sosl' then
    cmd = { 'sf', 'data', 'search', '--target-org', org.alias or org.username, '--file', tmpfile, '--json' }
  else
    cmd = { 'sf', 'apex', 'run', '--target-org', org.alias or org.username, '--file', tmpfile, '--json' }
  end

  local kind = (ft == 'soql' or ft == 'sosl') and 'query' or 'apex'
  M.exec_cmd(cmd, cleanup, kind)
end

function M.exec_cmd(cmd, on_done, kind)
  kind = kind or 'apex'
  local buf, win = ensure_output(kind, source_window())
  vim.api.nvim_win_set_buf(win, buf)
  set_output(buf, { 'Running…' })

  local stdout_data = {}
  local stderr_data = {}

  local function collect(data, target)
    if not data then
      return
    end
    for _, line in ipairs(data) do
      table.insert(target, line)
    end
  end

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      collect(data, stdout_data)
    end,
    on_stderr = function(_, data)
      collect(data, stderr_data)
    end,
    on_exit = function(_, exit_code)
      local raw = table.concat(stdout_data, '\n')
      local result, result_type, err = parse_result(raw)

      -- Invalidate cache if the error looks like an org/connection/auth issue
      if err then
        local lower = err:lower()
        local patterns = {
          'no org configuration found',
          'org cannot be found',
          'invalid.*username',
          'invalid.*session',
          'session.*expired',
          'not authenticated',
          'connection refused',
          'connection timed out',
        }
        for _, p in ipairs(patterns) do
          if lower:match(p) then
            M.clear_org_cache()
            break
          end
        end
      end

      if result and result_type == 'apex' then
        if result.compiled and result.success then
          vim.notify('Apex executed successfully', vim.log.levels.INFO)
        elseif not result.compiled then
          vim.notify('Compilation failed', vim.log.levels.ERROR)
        else
          vim.notify('Exception', vim.log.levels.ERROR)
        end
        set_output(buf, apex_lines(result))
      elseif result and result_type == 'query' then
        local count = result.totalSize or #(result.records or result.searchRecords or {})
        vim.notify('Query returned ' .. count .. ' rows', vim.log.levels.INFO)
        set_output(buf, query_lines(result))
      else
        local display = err and { err } or {}
        vim.list_extend(display, stdout_data)
        if #stderr_data > 0 then
          vim.list_extend(display, stderr_data)
        end
        set_output(buf, #display > 0 and sanitise_lines(display) or { '[no output]' })
        if exit_code ~= 0 then
          vim.notify('Command failed (code ' .. exit_code .. ')', vim.log.levels.ERROR)
        end
      end

      if on_done then
        on_done()
      end

      -- Jump to the results once they are ready.
      focus_output(win)
    end,
  })

  if job_id <= 0 then
    vim.notify('Failed to start SF CLI', vim.log.levels.ERROR)
  end
end

function M.run_with_pick()
  local ext = vim.fn.expand '%:e'
  if ext ~= 'apex' and ext ~= 'soql' and ext ~= 'sosl' then
    vim.notify('Buffer must be .apex, .soql, or .sosl', vim.log.levels.WARN)
    return
  end
  M.pick_org(function(org)
    M.run_anonymous(org)
  end)
end

vim.keymap.set('n', '<leader>Se', M.open_scratch, { desc = '[E]xecute anonymous' })
vim.keymap.set('n', '<leader>Sq', M.open_soql, { desc = '[Q]uery SOQL' })
vim.keymap.set('n', '<leader>Ss', M.open_sosl, { desc = '[S]earch SOSL' })
vim.keymap.set('n', '<leader>Sr', M.run_with_pick, { desc = '[R]un buffer' })

vim.api.nvim_create_user_command('SfApexRun', M.run_with_pick, {})
vim.api.nvim_create_user_command('SfApexOpen', M.open_scratch, {})
vim.api.nvim_create_user_command('SfSoqlOpen', M.open_soql, {})
vim.api.nvim_create_user_command('SfSoslOpen', M.open_sosl, {})
vim.api.nvim_create_user_command('SfApexRefresh', M.refresh_orgs, {})
vim.api.nvim_create_user_command('SfCloseOutput', function()
  close_output('apex')
  close_output('query')
end, { desc = 'Close Salesforce result splits' })
vim.api.nvim_create_user_command('SfHelp', function()
  vim.notify([[
Commands:
  :SfApexRun      - Execute buffer (auto-detect: apex/soql/sosl)
  :SfApexOpen     - Open scratch .apex file
  :SfSoqlOpen     - Open scratch .soql file
  :SfSoslOpen     - Open scratch .sosl file
  :SfApexRefresh  - Refresh cached org list
  :SfCloseOutput  - Close result splits

Keymaps:
  <leader>Se      - Open .apex scratch
  <leader>Sq      - Open .soql scratch
  <leader>Ss      - Open .sosl scratch
  <leader>Sr      - Run buffer (auto-detect type)

Results:
  Apex              - vertical split (logs/errors)
  SOQL/SOSL         - horizontal split (aligned table)]], vim.log.levels.INFO)
end, {})

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.defer_fn(function()
      if not load_state().org_cache then
        fetch_orgs(function(_) end)
      end
    end, 2000)
  end,
})

return M
