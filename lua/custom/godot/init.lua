-- Start a Neovim :server socket so the Godot editor can talk to this instance.
-- Loaded by custom.workspaces only when a project.godot marker is found.

if vim.v.servername ~= nil then
    return {}
end

pcall(vim.fn.serverstart, '/tmp/godot.pipe')

return {}
