vim.pack.add {
    'https://codeberg.org/ziglang/zig.vim',
}

-- don't show parse errors in a separate window
vim.g.zig_fmt_parse_errors = 0
-- disable format-on-save from `ziglang/zig.vim`
vim.g.zig_fmt_autosave = 0
-- enable  format-on-save from vim.lsp + ZLS
--
-- Formatting with ZLS matches `zig fmt`.
vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = { '*.zig', '*.zon' },
    callback = function(ev)
        vim.lsp.buf.format()
    end,
})

vim.lsp.config['zls'] = {
    -- Set to 'zls' if `zls` is in your PATH
    cmd = { 'zls' },
    filetypes = { 'zig' },
    root_markers = { 'build.zig' },
    -- There are two ways to set config options:
    --   - edit your `` that applies to any editor that uses ZLS
    --   - set in-editor config options with the `settings` field below.
    --
    -- Further information on how to configure ZLS:
    -- https://zigtools.org/zls/configure/
    settings = {
        zls = {
            -- Whether to enable build-on-save diagnostics
            --
            -- Further information about build-on save:
            -- https://zigtools.org/zls/guides/build-on-save/
            -- enable_build_on_save = true,

            -- omit the following line if `zig` is in your PATH
            -- zig_exe_path = 'zig',
        },
    },
}
vim.lsp.enable 'zls'

-- source.fixAll
-- vim.api.nvim_create_autocmd('BufWritePre', {
--   pattern = { "*.zig", "*.zon" },
--   callback = function(ev)
--     vim.lsp.buf.code_action({
--       context = { only = { "source.fixAll" } },
--       apply = true,
--     })
--   end
-- })
-- source.organizeImports
-- vim.api.nvim_create_autocmd('BufWritePre', {
--   pattern = { "*.zig", "*.zon" },
--   callback = function(ev)
--     vim.lsp.buf.code_action({
--       context = { only = { "source.organizeImports" } },
--       apply = true,
--     })
--   end
-- })

return {}
