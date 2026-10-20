-- Automatic plugin update checks for vim.pack.
--
--   :PackCheck    check now and show a report of available updates
--   :PackUpdate   open the built-in update preview/confirmation buffer
--   :PackUpdate!  apply all updates without confirmation
--
-- The automatic check runs shortly after startup, at most once per interval.
-- Disable it with vim.g.pack_check_auto = false, change the interval with
-- vim.g.pack_check_interval_days = 3, or the delay with
-- vim.g.pack_check_delay_ms = 10000.
local M = {}

local state_file = vim.fn.stdpath 'state' .. '/pack_update_state.json'
local default_interval_days = 1
local default_delay_ms = 10000
local fetch_concurrency = 4
local fetch_timeout_ms = 30000
local max_commits_per_plugin = 5

local checking = false

local function read_state()
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

local function write_state(data)
    vim.fn.mkdir(vim.fn.fnamemodify(state_file, ':h'), 'p')
    local fd = io.open(state_file, 'w')
    if not fd then
        return
    end
    fd:write(vim.json.encode(data))
    fd:close()
end

local function record(field)
    local state = read_state()
    state[field] = os.time()
    write_state(state)
end

local function git(args, cwd)
    local cmd = vim.list_extend({ 'git', '-C', cwd }, args)
    local res = vim.system(cmd, {
        text = true,
        timeout = fetch_timeout_ms,
        env = { GIT_TERMINAL_PROMPT = '0' },
    }):wait()
    if res.code ~= 0 then
        return nil
    end
    return vim.trim(res.stdout)
end

--- Resolve the Git ref vim.pack would update this plugin to.
local function resolve_target(p)
    local version = p.spec.version

    if version == nil then
        local branch = git({ 'rev-parse', '--abbrev-ref', 'origin/HEAD' }, p.path)
        if not branch then
            return nil, 'cannot determine default branch'
        end
        return 'origin/' .. branch:gsub('^origin/', '')
    end

    if type(version) == 'string' then
        if git({ 'rev-parse', '--verify', '--quiet', 'origin/' .. version }, p.path) then
            return 'origin/' .. version
        end
        return version
    end

    -- version is a vim.VersionRange: pick the newest matching semver tag.
    local tags = git({ 'tag', '--list', '--sort=-v:refname' }, p.path) or ''
    local last_tag, last_ver
    for tag in vim.gsplit(tags, '\n', { plain = true }) do
        local ver = vim.version.parse(tag, { strict = true })
        if ver and version:has(ver) and (not last_ver or ver > last_ver) then
            last_tag, last_ver = tag, ver
        end
    end
    if not last_tag then
        return nil, 'no tag matches version range'
    end
    return last_tag
end

--- Inspect one plugin. Returns nil when up to date.
local function check_plugin(p)
    local target_ref, err = resolve_target(p)
    if not target_ref then
        return { name = p.spec.name, error = err }
    end

    local head = git({ 'rev-parse', 'HEAD' }, p.path)
    local target = git({ 'rev-parse', target_ref }, p.path)
    if not head or not target then
        return { name = p.spec.name, error = 'cannot resolve revisions' }
    end
    if head == target then
        return nil
    end

    local count = tonumber(git({ 'rev-list', '--count', head .. '..' .. target }, p.path)) or 0
    local log = git({
        'log',
        '--pretty=format:%h %s',
        '--no-merges',
        '-n',
        tostring(max_commits_per_plugin),
        head .. '..' .. target,
    }, p.path) or ''

    local commits = {}
    for line in vim.gsplit(log, '\n', { plain = true }) do
        if line ~= '' then
            commits[#commits + 1] = line
        end
    end
    return { name = p.spec.name, count = count, commits = commits }
end

local function fetch_plugin(p, callback)
    local cmd = { 'git', '-C', p.path, 'fetch', '--quiet', '--tags', '--force', 'origin' }
    vim.system(cmd, {
        text = true,
        timeout = fetch_timeout_ms,
        env = { GIT_TERMINAL_PROMPT = '0' },
    }, function(res)
        -- vim.system callbacks run in a fast event context; move to the main
        -- loop so the synchronous local git commands in check_plugin() work.
        vim.schedule(function()
            callback(res.code == 0)
        end)
    end)
end

local function active_plugins()
    return vim.tbl_filter(function(p)
        return p.active and vim.uv.fs_stat(p.path) ~= nil
    end, vim.pack.get(nil, { info = false }))
end

--- Fetch and inspect all active plugins, then call `on_done(results)`.
local function check_all(on_done)
    local plugins = active_plugins()
    if #plugins == 0 then
        on_done {}
        return
    end

    local results = {}
    local index = 0
    local running = 0

    local function start_next()
        while running < fetch_concurrency and index < #plugins do
            index = index + 1
            local p = plugins[index]
            running = running + 1

            fetch_plugin(p, function(ok)
                if ok then
                    local result = check_plugin(p)
                    if result then
                        results[#results + 1] = result
                    end
                else
                    results[#results + 1] = { name = p.spec.name, error = 'fetch failed' }
                end
                running = running - 1

                if index >= #plugins and running == 0 then
                    vim.schedule(function()
                        on_done(results)
                    end)
                else
                    start_next()
                end
            end)
        end
    end

    start_next()
end

local function updates_of(results)
    return vim.tbl_filter(function(r)
        return r.count ~= nil
    end, results)
end

local function errors_of(results)
    return vim.tbl_filter(function(r)
        return r.error ~= nil
    end, results)
end

local function plugin_summary(r)
    local count = r.count or 0
    local first = r.commits and r.commits[1] or nil
    if first then
        return ('%s (%d commit%s) — %s'):format(r.name, count, count == 1 and '' or 's', first)
    end
    return ('%s (%d commit%s)'):format(r.name, count, count == 1 and '' or 's')
end

--- Compact notification: names plus one commit subject per plugin.
local function notify_updates(results)
    local updates = updates_of(results)
    if #updates == 0 then
        return
    end

    local shown = math.min(#updates, 5)
    local lines = { ('%d plugin update(s) available:'):format(#updates) }
    for i = 1, shown do
        lines[#lines + 1] = '  ' .. plugin_summary(updates[i])
    end
    if #updates > shown then
        lines[#lines + 1] = ('  …and %d more'):format(#updates - shown)
    end
    lines[#lines + 1] = 'Run :PackCheck for details or :PackUpdate to apply.'

    vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'vim.pack', timeout = 15000 })
end

--- Full report in a floating window.
local function show_report(results)
    local updates = updates_of(results)
    local errors = errors_of(results)

    if #updates == 0 and #errors == 0 then
        vim.notify('All plugins are up to date.', vim.log.levels.INFO, { title = 'vim.pack' })
        return
    end

    local lines = {}
    for _, r in ipairs(updates) do
        local count = r.count or 0
        lines[#lines + 1] = ('%s — %d commit%s'):format(r.name, count, count == 1 and '' or 's')
        for _, commit in ipairs(r.commits or {}) do
            lines[#lines + 1] = '  ' .. commit
        end
        if count > #(r.commits or {}) then
            lines[#lines + 1] = ('  …and %d more'):format(count - #(r.commits or {}))
        end
        lines[#lines + 1] = ''
    end
    for _, r in ipairs(errors) do
        lines[#lines + 1] = ('%s — %s'):format(r.name, r.error)
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(line))
    end
    width = math.min(math.max(width + 2, 40), vim.o.columns - 4)
    local height = math.min(#lines, math.max(5, vim.o.lines - 8))

    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' Plugin updates ',
        title_pos = 'center',
    })

    for _, lhs in ipairs { 'q', '<Esc>' } do
        vim.keymap.set('n', lhs, function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end, { buffer = buf, nowait = true })
    end
end

--- Run a check and optionally show the full report.
function M.check(show)
    if checking then
        vim.notify('Already checking for updates…', vim.log.levels.INFO, { title = 'vim.pack' })
        return
    end
    checking = true

    check_all(function(results)
        checking = false
        record 'last_check'
        if show then
            show_report(results)
        else
            notify_updates(results)
        end
    end)
end

--- Update all plugins. `force` skips the confirmation buffer.
function M.update(force)
    local ok, err = pcall(vim.pack.update, nil, { force = force })
    if not ok then
        vim.notify('Plugin update failed: ' .. tostring(err), vim.log.levels.ERROR, { title = 'vim.pack' })
        return
    end
    record 'last_update'
end

local function maybe_auto_check()
    if vim.g.pack_check_auto == false then
        return
    end
    if #vim.api.nvim_list_uis() == 0 then
        return
    end

    local interval = tonumber(vim.g.pack_check_interval_days) or default_interval_days
    local last = tonumber(read_state().last_check) or 0
    if last ~= 0 and (os.time() - last) < interval * 86400 then
        return
    end

    local delay = tonumber(vim.g.pack_check_delay_ms) or default_delay_ms
    vim.defer_fn(function()
        -- Re-read state: a manual :PackCheck may have run while waiting.
        local now_last = tonumber(read_state().last_check) or 0
        if checking or (now_last ~= 0 and (os.time() - now_last) < interval * 86400) then
            return
        end
        M.check(false)
    end, delay)
end

vim.api.nvim_create_user_command('PackCheck', function()
    M.check(true)
end, { desc = 'Check for vim.pack plugin updates' })

vim.api.nvim_create_user_command('PackUpdate', function(args)
    M.update(args.bang)
end, { bang = true, desc = 'Update vim.pack plugins (:PackUpdate! to skip confirmation)' })

-- Record successful updates, including ones applied from the preview buffer.
vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
        if ev.data.kind == 'update' then
            record 'last_update'
        end
    end,
})

vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
        vim.schedule(maybe_auto_check)
    end,
})

return M
