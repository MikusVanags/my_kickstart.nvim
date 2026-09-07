-- Start a Neovim :server socket so Godot can talk to this instance.
-- Only loaded (by init.lua) when the current directory is a Godot project.

if vim.v.servername ~= nil then
    return {}
end

pcall(vim.fn.serverstart, '/tmp/godot.pipe')

return {}
