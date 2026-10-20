-- Find and remove plugins installed by vim.pack that are no longer in any spec.
-- "Inactive" means installed on disk but not referenced by a vim.pack.add() call.
local M = {}

local workspaces = require 'custom.workspaces'

local function inactive()
    local known = workspaces.known_plugin_set()
    return vim.iter(vim.pack.get(nil, { info = false }))
        :filter(function(p)
            -- Plugins declared by any workspace profile count as used even
            -- when that workspace is not the current one.
            return not p.active and not known[p.spec.name]
        end)
        :totable()
end

local function names_of(plugins)
    return vim.tbl_map(function(p)
        return p.spec.name
    end, plugins)
end

function M.names()
    return names_of(inactive())
end

--- List unused plugins without changing anything.
function M.list()
    local names = M.names()
    if #names == 0 then
        vim.notify('No unused plugins found.', vim.log.levels.INFO, { title = 'vim.pack' })
        return
    end
    vim.notify(table.concat(names, '\n'), vim.log.levels.INFO, {
        title = ('%d unused plugin(s)'):format(#names),
        timeout = 10000,
    })
end

--- Ask for confirmation, then delete every unused plugin from disk.
function M.clean()
    local names = M.names()
    if #names == 0 then
        vim.notify('No unused plugins found.', vim.log.levels.INFO, { title = 'vim.pack' })
        return
    end

    local answer = vim.fn.confirm(
        ('Remove %d unused plugin(s) from disk?\n\n%s'):format(#names, table.concat(names, '\n')),
        '&Remove\n&Cancel',
        2,
        'Question'
    )
    if answer ~= 1 then
        return
    end

    local ok, err = pcall(vim.pack.del, names)
    if not ok then
        vim.notify('Failed to remove plugins: ' .. tostring(err), vim.log.levels.ERROR, { title = 'vim.pack' })
        return
    end
    vim.notify(('Removed %d plugin(s).'):format(#names), vim.log.levels.INFO, { title = 'vim.pack' })
end

--- Show a one-line reminder at startup if anything needs cleaning.
function M.remind()
    if vim.g.pack_clean_reminder == false then
        return
    end
    -- Don't nag in headless/scripted sessions.
    if #vim.api.nvim_list_uis() == 0 then
        return
    end

    local names = M.names()
    if #names == 0 then
        return
    end
    vim.notify(
        ('%d unused plugin(s) installed: %s\nRun :PackClean to review and remove them.'):format(
            #names,
            table.concat(names, ', ')
        ),
        vim.log.levels.WARN,
        { title = 'vim.pack', timeout = 10000 }
    )
end

vim.api.nvim_create_user_command('PackClean', M.clean, { desc = 'Review and remove unused vim.pack plugins' })
vim.api.nvim_create_user_command('PackUnused', M.list, { desc = 'List plugins installed but not in any spec' })

-- Set vim.g.pack_clean_reminder = false to disable the startup reminder.
vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
        vim.schedule(M.remind)
    end,
})

return M
