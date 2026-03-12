-- Toggle memory module for inlay hints, diagnostics, and tabs

local ToggleMemory = {
    inlay_hints = true,
    diagnostics = true,
    tabs = true,
    updating = false,
}

local state_file = vim.fn.stdpath 'state' .. '/toggle_state.json'

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

local function toggle_inlay_hints()
    local bufnr = vim.api.nvim_get_current_buf()
    local enabled = vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }
    local success = pcall(vim.lsp.inlay_hint.enable, not enabled, { bufnr = bufnr })
    if success then
        ToggleMemory.inlay_hints = not enabled
        save_state {
            inlay_hints = ToggleMemory.inlay_hints,
            diagnostics = ToggleMemory.diagnostics,
            tabs = ToggleMemory.tabs,
        }
        vim.notify('Inlay hints: ' .. (ToggleMemory.inlay_hints and 'on' or 'off'))
    else
        vim.notify('Inlay hints not supported by current LSP', vim.log.levels.WARN)
    end
end

local function toggle_diagnostics()
    local config = vim.diagnostic.config()
    local current = config.virtual_text
    if current then
        vim.diagnostic.config { virtual_text = false }
        ToggleMemory.diagnostics = false
    else
        vim.diagnostic.config {
            virtual_text = {
                source = 'if_many',
                prefix = '',
                spacing = 4,
                severity = {
                    min = vim.diagnostic.severity.WARN,
                },
                format = function(diagnostic)
                    local icons = {
                        [vim.diagnostic.severity.ERROR] = ' ',
                        [vim.diagnostic.severity.WARN] = ' ',
                        [vim.diagnostic.severity.INFO] = ' ',
                        [vim.diagnostic.severity.HINT] = ' ',
                    }
                    return icons[diagnostic.severity] .. diagnostic.message
                end,
            },
            signs = true,
        }
        ToggleMemory.diagnostics = true
    end
    save_state {
        inlay_hints = ToggleMemory.inlay_hints,
        diagnostics = ToggleMemory.diagnostics,
        tabs = ToggleMemory.tabs,
    }
    vim.notify('Diagnostics: ' .. (ToggleMemory.diagnostics and 'on' or 'off'))
end

local function toggle_tabs()
    if vim.o.showtabline == 1 then
        vim.o.showtabline = 0
        ToggleMemory.tabs = false
    else
        vim.o.showtabline = 1
        ToggleMemory.tabs = true
    end
    save_state {
        inlay_hints = ToggleMemory.inlay_hints,
        diagnostics = ToggleMemory.diagnostics,
        tabs = ToggleMemory.tabs,
    }
    vim.notify('Tabs: ' .. (ToggleMemory.tabs and 'on' or 'off'))
end

function ToggleMemory.toggle_inlay_hints()
    toggle_inlay_hints()
end

function ToggleMemory.toggle_diagnostics()
    toggle_diagnostics()
end

function ToggleMemory.toggle_tabs()
    toggle_tabs()
end

local function apply_startup_state()
    local state = load_state()

    ToggleMemory.inlay_hints = state.inlay_hints ~= false
    ToggleMemory.diagnostics = state.diagnostics ~= false
    ToggleMemory.tabs = state.tabs ~= false

    if not ToggleMemory.diagnostics then
        vim.diagnostic.config { virtual_text = false }
    else
        vim.diagnostic.config {
            virtual_text = {
                source = 'if_many',
                prefix = '',
                spacing = 4,
                severity = {
                    min = vim.diagnostic.severity.WARN,
                },
                format = function(diagnostic)
                    local icons = {
                        [vim.diagnostic.severity.ERROR] = ' ',
                        [vim.diagnostic.severity.WARN] = ' ',
                        [vim.diagnostic.severity.INFO] = ' ',
                        [vim.diagnostic.severity.HINT] = ' ',
                    }
                    return icons[diagnostic.severity] .. diagnostic.message
                end,
            },
            signs = true,
        }
    end

    if not ToggleMemory.tabs then
        vim.o.showtabline = 0
    else
        vim.o.showtabline = 1
    end
end

local function apply_inlay_hints_to_buffer(bufnr)
    if ToggleMemory.inlay_hints then
        pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
    else
        pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })
    end
end

vim.api.nvim_create_user_command('ToggleInlayHints', ToggleMemory.toggle_inlay_hints, {})
vim.api.nvim_create_user_command('ToggleDiagnostics', ToggleMemory.toggle_diagnostics, {})
vim.api.nvim_create_user_command('ToggleTabs', ToggleMemory.toggle_tabs, {})

vim.keymap.set('n', '<leader>th', ToggleMemory.toggle_inlay_hints, { desc = '[T]oggle Inlay [H]ints' })
vim.keymap.set('n', '<leader>td', ToggleMemory.toggle_diagnostics, { desc = '[T]oggle [D]iagnostics' })
vim.keymap.set('n', '<leader>tt', ToggleMemory.toggle_tabs, { desc = '[T]oggle [T]abs' })

apply_startup_state()

vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        apply_inlay_hints_to_buffer(args.buf)
    end,
})

return ToggleMemory
