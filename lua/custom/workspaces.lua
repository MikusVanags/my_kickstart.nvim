-- Workspace profiles: detect a project type from the current directory and
-- load only the plugins/setup that belong to it.
--
-- See WORKSPACES.md for the conventions used to add or split a workspace.
--
-- Profiles also register their plugins as "known", so maintenance tools
-- (PackClean, automatic update checks) do not treat them as unused just
-- because the current session is a different kind of workspace.
local M = {}

---@class WorkspaceProfile
---@field markers string[] Files/directories that identify the workspace root.
---@field setup? string Lua module to require when the profile is active.
---@field plugins? (string|vim.pack.Spec)[] Plugins used only by this profile.

---@type table<string, WorkspaceProfile>
M.profiles = {
    salesforce = {
        markers = { 'sfdx-project.json' },
        setup = 'custom.salesforce',
        plugins = {},
    },
    zig = {
        markers = { 'build.zig' },
        setup = 'custom.zig',
        plugins = {
            'https://codeberg.org/ziglang/zig.vim',
        },
    },
    godot = {
        markers = { 'project.godot' },
        setup = 'custom.godot',
        plugins = {},
    },
}

--- Profiles are checked in this order; the first matching root wins.
M.order = { 'salesforce', 'zig', 'godot' }

---@param spec string|vim.pack.Spec
---@return string
local function plugin_name(spec)
    local src = type(spec) == 'table' and spec.src or spec
    local name = src:gsub('/+$', ''):match '([^/]+)$' or src
    return (name:gsub('%.git$', ''))
end

--- Find the profile matching the current working directory.
---@return string? name
---@return WorkspaceProfile? profile
---@return string? root
function M.current()
    local cwd = vim.fn.getcwd()
    for _, name in ipairs(M.order) do
        local profile = M.profiles[name]
        if profile then
            local root = vim.fs.root(cwd, profile.markers)
            if root then
                return name, profile, root
            end
        end
    end
end

--- Names of every plugin declared by any profile, regardless of whether that
--- profile is active in the current session.
---@return table<string, true>
function M.known_plugin_set()
    local known = {}
    for _, profile in pairs(M.profiles) do
        for _, spec in ipairs(profile.plugins or {}) do
            known[plugin_name(spec)] = true
        end
    end
    return known
end

--- Detect the current workspace, add its plugins, and run its setup module.
---@return string? name
function M.load()
    local name, profile, root = M.current()
    if not profile then
        return nil
    end

    vim.g.current_workspace = name
    vim.g.workspace_root = root

    if profile.plugins and #profile.plugins > 0 then
        vim.pack.add(profile.plugins)
    end

    if profile.setup then
        local ok, err = pcall(require, profile.setup)
        if not ok then
            vim.notify(('Workspace %s failed to load: %s'):format(name, err), vim.log.levels.ERROR)
        end
    end

    return name
end

vim.api.nvim_create_user_command('Workspace', function()
    local name, profile, root = M.current()
    if not name then
        vim.notify('No workspace profile for ' .. vim.fn.getcwd(), vim.log.levels.INFO)
        return
    end
    vim.notify(
        ('Workspace: %s\nRoot: %s\nSetup: %s'):format(name, root, profile.setup or 'none'),
        vim.log.levels.INFO
    )
end, { desc = 'Show the detected workspace profile' })

return M
