local M = {}

---@alias SfOrg { alias: string, username: string, is_last_used: boolean }

local state_file = vim.fn.stdpath 'state' .. '/sf_apex_state.json'
local output_win = nil


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

local function ensure_output_win()
  if output_win and vim.api.nvim_win_is_valid(output_win) then
    return vim.api.nvim_win_get_buf(output_win), output_win
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'

  local width = vim.o.columns
  local height = math.min(20, vim.o.lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = vim.o.lines - height - 2,
    col = 0,
    style = 'minimal',
    border = 'single',
    title = ' SF Apex ',
    title_pos = 'center',
  })

  vim.keymap.set('n', 'q', function()
    if output_win and vim.api.nvim_win_is_valid(output_win) then
      vim.api.nvim_win_close(output_win, true)
      output_win = nil
    end
  end, { buffer = buf, desc = 'Close output' })

  output_win = win
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
  if result.totalSize ~= nil then
    return result, 'query', nil
  end
  if result.compiled ~= nil then
    return result, 'apex', nil
  end
  return nil, nil, data.message or 'Unknown result format'
end

local function safe_set_lines(buf, raw_lines)
  local sanitised = {}
  for _, line in ipairs(raw_lines) do
    for _, subline in ipairs(vim.split(line, '\n', { plain = true })) do
      table.insert(sanitised, subline)
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, sanitised)
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

  M.exec_cmd(cmd, cleanup)
end

function M.exec_cmd(cmd, on_done)
  local buf, win = ensure_output_win()
  vim.api.nvim_win_set_buf(win, buf)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Running...' })
  vim.bo[buf].modified = false

  local stdout_data = {}
  local stderr_data = {}

  local function append_output(data)
    if not data or #data == 0 then
      return
    end
    for _, line in ipairs(data) do
      table.insert(stdout_data, line)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, stdout_data)
    vim.bo[buf].modified = false
  end

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      append_output(data)
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stderr_data, line)
        end
      end
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
          if result.logs and result.logs ~= '' then
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result.logs, '\n'))
          else
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Success (no debug log)' })
          end
        elseif not result.compiled then
          vim.notify('Compilation failed', vim.log.levels.ERROR)
          local msg = result.compileProblem or 'Unknown compilation error'
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(msg, '\n'))
        elseif not result.success then
          vim.notify('Exception', vim.log.levels.ERROR)
          local lines = {}
          if result.exceptionMessage then
            vim.list_extend(lines, vim.split(result.exceptionMessage, '\n'))
          end
          if result.exceptionStackTrace then
            vim.list_extend(lines, vim.split(result.exceptionStackTrace, '\n'))
          end
          if #lines == 0 then
            lines = { 'Unknown exception' }
          end
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        end
      elseif result and result_type == 'query' then
        vim.notify('Query returned ' .. (result.totalSize or '?') .. ' rows', vim.log.levels.INFO)
        local lines = {}
        if result.records and #result.records > 0 then
          table.insert(lines, result.totalSize .. ' record(s)')
          table.insert(lines, '')
          for _, rec in ipairs(result.records) do
            local parts = {}
            for k, v in pairs(rec) do
              if k ~= 'attributes' then
                table.insert(parts, k .. ': ' .. tostring(v))
              end
            end
            table.insert(lines, table.concat(parts, ', '))
          end
        else
          table.insert(lines, '0 records')
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      else
        local display = err and { err } or {}
        vim.list_extend(display, stdout_data)
        if #stderr_data > 0 then
          vim.list_extend(display, stderr_data)
        end
        if #display > 0 then
          safe_set_lines(buf, display)
        else
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '[no output]' })
        end
        if exit_code ~= 0 then
          vim.notify('Command failed (code ' .. exit_code .. ')', vim.log.levels.ERROR)
        end
      end

      vim.bo[buf].modified = false

      if on_done then
        on_done()
      end
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

vim.keymap.set('n', '<leader>se', M.open_scratch, { desc = '[S]alesforce [E]xecute anonymous' })
vim.keymap.set('n', '<leader>sq', M.open_soql, { desc = '[S]alesforce SO[Q]L query' })
vim.keymap.set('n', '<leader>sS', M.open_sosl, { desc = '[S]alesforce SO[S]L search' })
vim.keymap.set('n', '<leader>sr', M.run_with_pick, { desc = '[S]alesforce [R]un (auto-detect type)' })

vim.api.nvim_create_user_command('SfApexRun', M.run_with_pick, {})
vim.api.nvim_create_user_command('SfApexOpen', M.open_scratch, {})
vim.api.nvim_create_user_command('SfSoqlOpen', M.open_soql, {})
vim.api.nvim_create_user_command('SfSoslOpen', M.open_sosl, {})
vim.api.nvim_create_user_command('SfApexRefresh', M.refresh_orgs, {})
vim.api.nvim_create_user_command('SfHelp', function()
  vim.notify([[
Commands:
  :SfApexRun      - Execute buffer (auto-detect: apex/soql/sosl)
  :SfApexOpen     - Open scratch .apex file
  :SfSoqlOpen     - Open scratch .soql file
  :SfSoslOpen     - Open scratch .sosl file
  :SfApexRefresh  - Refresh cached org list

Keymaps:
  <leader>se      - Open .apex scratch
  <leader>sq      - Open .soql scratch
  <leader>sS      - Open .sosl scratch
  <leader>sr      - Run buffer (auto-detect type)]], vim.log.levels.INFO)
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
