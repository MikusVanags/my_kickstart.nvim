-- LSP configuration: clients, keymaps, mason

-- Global LSP defaults
vim.lsp.config('*', {
    root_markers = { '.git' },
})

-- LWC Language Server
vim.lsp.config('lwc_ls', {
    cmd = {
        'lwc-language-server',
        '--stdio',
    },
    filetypes = { 'javascript', 'html', 'component' },
    init_options = {},
    root_markers = { 'sfdx-project.json' },
})
vim.lsp.enable 'lwc_ls'

-- Apex Language Server
vim.lsp.config('apex_ls', {
    cmd = {
        'java',
        '-jar',
        vim.fn.expand '$HOME/.local/share/nvim/mason/share/apex-language-server/apex-jorje-lsp.jar',
        '--stdio',
    },
    filetypes = { 'apex' },
    root_markers = { 'sfdx-project.json' },
    handlers = {
        ['textDocument/publishDiagnostics'] = function(err, result, ctx, config)
            local bufnr = vim.uri_to_bufnr(result.uri)
            local ft = vim.bo[bufnr].filetype
            if ft ~= 'apex' then
                return
            end
            vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
        end,
    },
})
vim.lsp.enable 'apex_ls'

-- Lua Language Server
vim.lsp.config('lua_ls', {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings = {
        Lua = {
            completion = { callSnippet = 'Replace' },
            diagnostics = { disable = { 'missing-fields' } },
        },
    },
})
vim.lsp.enable 'lua_ls'

-- TypeScript Language Server
vim.lsp.config('ts_ls', {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
    root_markers = { 'package.json', 'tsconfig.json', '.git' },
    settings = {
        javascript = { inlayHints = { includeInlayEnumMemberValueHints = true } },
        typescript = { inlayHints = { includeInlayEnumMemberValueHints = true } },
    },
})
vim.lsp.enable 'ts_ls'

-- Diagnostic quickfix
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- LspAttach: keymaps and document highlight
vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
        local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('gd', function()
            local clients = vim.lsp.get_clients { bufnr = 0 }
            local has_definition_support = false
            for _, client in ipairs(clients) do
                if client.server_capabilities.definitionProvider then
                    has_definition_support = true
                    break
                end
            end
            if has_definition_support then
                local result = vim.lsp.buf_request_sync(0, 'textDocument/definition', vim.lsp.util.make_position_params(), 1000)
                if result and result[1] and result[1].result and #result[1].result > 0 then
                    vim.lsp.buf.definition()
                    return
                end
            end
            vim.cmd [[silent! execute "normal! \<C-]>"]]
        end, '[G]oto [D]efinition')

        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
        map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
        map('K', vim.lsp.buf.hover, 'Hover Documentation')
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = true })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
                group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
                callback = function(event2)
                    vim.lsp.buf.clear_references()
                    vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
                end,
            })
        end
    end,
})

-- Mason (package manager for LSP servers, formatters, linters)
require('mason').setup()
require('mason-tool-installer').setup {
    ensure_installed = { 'lua-language-server', 'typescript-language-server', 'stylua', 'prettier' },
}
