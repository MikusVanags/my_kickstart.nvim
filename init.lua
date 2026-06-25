-- IDEA: grab all TODOS, FIXES, IDEAS etc and store the in the quickfix list in the opened file
-- controls the same as quickfix list, go over them and navigate to it on enter
-- IDEA: have a search that combines grep + filepath search

--  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = true
vim.o.termguicolors = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.fixendofline = true
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'CursorHold', 'CursorHoldI' }, { pattern = '*', command = 'silent checktime' })

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = 'unnamedplus'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- tab looks like 4 spaces
-- NOTE: can use ftplugin to use only on specific files
vim.o.tabstop = 4 -- A TAB character looks like 4 spaces
vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = 4 -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = 4 -- Number of spaces inserted when indenting

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true
vim.o.confirm = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.o.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- TreeSitter for Apex/Salesforce things
vim.filetype.add {
    extension = {
        ['cls'] = 'apex',
        ['trigger'] = 'apex',
        ['apex'] = 'apex',
        ['cmp'] = 'html',
        ['page'] = 'html',
        ['component'] = 'component',
    },
}

-- Configure LSP clients
vim.lsp.config('*', {
    root_markers = { '.git' },
})

vim.lsp.config('lwc_ls', {
    cmd = {
        'lwc-language-server',
        '--stdio',
    },
    filetypes = { 'javascript', 'html', 'component' },
    init_options = {
        -- embeddedLanguages = {
        --     javascript = true,
        --     html = true,
        -- },
    },
    root_markers = { 'sfdx-project.json', 'package.json' },
})

vim.lsp.config('apex_ls', {
    cmd = {
        'java',
        '-jar',
        vim.fn.expand '$HOME/.local/share/nvim/mason/share/apex-language-server/apex-jorje-lsp.jar',
        '--stdio',
    },
    filetypes = { 'apex', 'apexcode' },
    root_markers = { 'sfdx-project.json' },
})

vim.lsp.enable 'lwc_ls'
vim.lsp.enable 'apex_ls'

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Configure diagnostic display
-- Diagnostics toggle is now handled by toggle_memory module

-- local function toggle_diagnostics()
--     local config = vim.diagnostic.config()
--     local current = config.virtual_text
--     if current then
--         vim.diagnostic.config { virtual_text = false }
--     else
--         vim.diagnostic.config {
--             virtual_text = {
--                 source = 'if_many', -- Show source only if multiple diagnostics
--                 prefix = '', -- Custom prefix character
--                 spacing = 4, -- Space between code and diagnostic
--                 severity = {
--                     min = vim.diagnostic.severity.WARN, -- Show warnings and errors only
--                 },
--                 format = function(diagnostic)
--                     -- Custom format: show severity icon and message
--                     local icons = {
--                         [vim.diagnostic.severity.ERROR] = ' ',
--                         [vim.diagnostic.severity.WARN] = ' ',
--                         [vim.diagnostic.severity.INFO] = ' ',
--                         [vim.diagnostic.severity.HINT] = ' ',
--                     }
--                     return icons[diagnostic.severity] .. diagnostic.message
--                 end,
--             },
--             signs = true, -- Keep gutter signs
--             underline = true, -- Keep underline styling
--             update_in_insert = false, -- Don't update while typing
--             severity_sort = true, -- Sort by severity
--         }
--     end
-- end
-- vim.keymap.set('n', '<leader>td', toggle_diagnostics, { desc = '[T]oggle [D]iagnostics' })

vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

vim.keymap.set('n', '<leader>e', '<cmd>Explore<CR>', { desc = '[E]xplore' })
vim.keymap.set('n', '<leader>se', '<cmd>Sexplore!"<CR>', { desc = '[S]plit [E]xplore' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('n', '<leader>tt', '<cmd>vsplit | terminal<CR>', { desc = '[tt]erminal' })
vim.keymap.set('n', '<leader>tT', function()
    vim.cmd 'tabnew'
    vim.cmd 'terminal'
end, { desc = '[T]ab [t]erminal' })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

vim.keymap.set('n', '<leader>g', function()
    vim.cmd '$argadd %'
    vim.cmd 'argdedup'
end, { desc = 'Arg Grab' })
vim.keymap.set('n', '<leader>1', function()
    vim.cmd 'silent! 1argument'
end, { desc = 'Arg Get 1' })
vim.keymap.set('n', '<leader>2', function()
    vim.cmd 'silent! 2argument'
end, { desc = 'Arg Get 2' })
vim.keymap.set('n', '<leader>3', function()
    vim.cmd 'silent! 3argument'
end, { desc = 'Arg Get 3' })
vim.keymap.set('n', '<leader>4', function()
    vim.cmd 'silent! 4argument'
end, { desc = 'Arg Get 4' })
vim.keymap.set('n', '<leader>5', function()
    vim.cmd 'silent! 5argument'
end, { desc = 'Arg Get 5' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

local projectfile = io.open(vim.fn.getcwd() .. '/project.godot', 'r')
if projectfile then
    io.close(projectfile)
    vim.fn.serverstart '/tmp/godot.pipe'
end

-- PackChanged hooks (must be before vim.pack.add to catch install events)
vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
        local name, kind = ev.data.spec.name, ev.data.kind
        if not (kind == 'install' or kind == 'update') then
            return
        end
        if name == 'fff.nvim' then
            if not ev.data.active then
                vim.cmd.packadd 'fff.nvim'
            end
            require('fff.download').download_or_build_binary()
        elseif name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
            vim.system({ 'make' }, { cwd = ev.data.path })
        elseif name == 'LuaSnip' and vim.fn.executable 'make' == 1 and not vim.fn.has 'win32' then
            vim.system({ 'make', 'install_jsregexp' }, { cwd = ev.data.path })
        end
    end,
})

-- plugins
vim.pack.add({
    -- Colorschemes
    'https://github.com/RRethy/base16-nvim',
    'https://github.com/folke/tokyonight.nvim',
    'https://github.com/rose-pine/neovim',
    'https://github.com/olivercederborg/poimandres.nvim',
    'https://github.com/catppuccin/nvim',

    -- Utility
    'https://github.com/tpope/vim-sleuth',
    'https://github.com/tpope/vim-fugitive',
    'https://github.com/numToStr/Comment.nvim',
    'https://github.com/lewis6991/gitsigns.nvim',
    'https://github.com/folke/which-key.nvim',
    'https://github.com/folke/todo-comments.nvim',
    'https://github.com/nvim-tree/nvim-web-devicons',
    'https://github.com/nvim-mini/mini.nvim',
    'https://github.com/NvChad/nvim-colorizer.lua',
    'https://github.com/nicolasgb/jj.nvim',
    -- 'https://github.com/github/copilot.vim',
    { src = 'https://github.com/dmtrKovalenko/fff.nvim', version = 'v0.5.1' },
    'https://github.com/stevearc/conform.nvim',

    -- Fuzzy finder
    'https://github.com/nvim-lua/plenary.nvim',
    'https://github.com/nvim-telescope/telescope-fzf-native.nvim',
    'https://github.com/nvim-telescope/telescope-ui-select.nvim',
    { src = 'https://github.com/nvim-telescope/telescope.nvim', version = '0.1.x' },

    -- LSP
    'https://github.com/neovim/nvim-lspconfig',
    'https://github.com/mason-org/mason.nvim',
    'https://github.com/mason-org/mason-lspconfig.nvim',
    'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim',
    'https://github.com/j-hui/fidget.nvim',
    'https://github.com/folke/lazydev.nvim',

    -- Completion
    { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range '1.*' },
    { src = 'https://github.com/L3MON4D3/LuaSnip', version = vim.version.range '2.*' },
    -- 'https://github.com/fang2hou/blink-copilot',

    -- Treesitter
    'https://github.com/romus204/tree-sitter-manager.nvim',

    -- Debugging
    'https://github.com/mfussenegger/nvim-dap',
    'https://github.com/rcarriga/nvim-dap-ui',
    'https://github.com/nvim-neotest/nvim-nio',
    'https://github.com/jay-babu/mason-nvim-dap.nvim',
    'https://github.com/leoluz/nvim-dap-go',

    -- Linting
    'https://github.com/mfussenegger/nvim-lint',
}, { load = false })

-- Plugin setups

-- Comment.nvim
require('Comment').setup {}
require('Comment.ft').set('apex', { '//%s', '/*%s*/' })

-- gitsigns
require('gitsigns').setup {
    signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
    },
}

-- jj.nvim
require('jj').setup {}

-- which-key
require('which-key').setup {
    delay = 0,
    icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {},
    },
    spec = {
        { '<leader>c', group = '[C]ode', mode = { 'n', 'x' } },
        { '<leader>d', group = '[D]ocument' },
        { '<leader>r', group = '[R]ename' },
        { '<leader>s', group = '[S]earch' },
        { '<leader>w', group = '[W]orkspace' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    },
}

-- Telescope
require('telescope').setup {
    extensions = {
        ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
        },
    },
}
pcall(require('telescope').load_extension, 'fzf')
pcall(require('telescope').load_extension, 'ui-select')
local builtin = require 'telescope.builtin'
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>/', function()
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
    })
end, { desc = '[/] Fuzzily search in current buffer' })
vim.keymap.set('n', '<leader>s/', function()
    builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Gep in Open Files',
    }
end, { desc = '[S]earch [/] in Open Files' })
vim.keymap.set('n', '<leader>sm', function()
    builtin.live_grep {
        grep_open_files = true,
        additional_args = function()
            return { '-U' }
        end,
    }
end, { desc = '[S]earch [M]ultiLine' })
vim.keymap.set('n', '<leader>sn', function()
    builtin.find_files { cwd = vim.fn.stdpath 'config' }
end, { desc = '[S]earch [N]eovim files' })

-- lazydev
require('lazydev').setup {
    library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
    },
}

-- LSP
vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
        local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('gd', function()
            local clients = vim.lsp.get_active_clients { bufnr = 0 }
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

        local function client_supports_method(client, method, bufnr)
            return client:supports_method(method, bufnr)
        end

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
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

local capabilities = vim.lsp.protocol.make_client_capabilities()
local servers = {
    lua_ls = {
        settings = {
            Lua = {
                completion = { callSnippet = 'Replace' },
                diagnostics = { disable = { 'missing-fields' } },
            },
        },
    },
}

require('mason').setup()
local ensure_installed = vim.tbl_keys(servers or {})
vim.list_extend(ensure_installed, { 'stylua', 'prettier' })
require('mason-tool-installer').setup { ensure_installed = ensure_installed }
require('mason-lspconfig').setup {
    ensure_installed = {},
    automatic_installation = false,
    handlers = {
        function(server_name)
            local server = servers[server_name]
            if not server then
                return
            end
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
        end,
    },
}

-- fidget
require('fidget').setup {}

-- Conform
require('conform').setup {
    notify_on_error = true,
    format_on_save = function(bufnr)
        local disable_filetypes = { c = true, cpp = true, zig = true }
        return {
            timeout_ms = 500,
            lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
        }
    end,
    formatters_by_ft = {
        lua = { 'stylua' },
        apex = { 'prettier' },
        javascript = { 'prettier' },
        css = { 'prettier' },
        xml = { 'prettier' },
        html = { 'prettier' },
        json = { 'prettier' },
    },
}
vim.keymap.set({ 'n', 'x' }, '<leader>f', function()
    require('conform').format { async = true, lsp_fallback = true }
end, { desc = '[F]ormat buffer' })

-- Blink (completion)
require('blink.cmp').setup {
    keymap = {
        preset = 'default',
        ['<c-y>'] = { 'select_and_accept' },
    },
    appearance = { nerd_font_variant = 'mono' },
    completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 500 },
        list = {
            selection = { preselect = true, auto_insert = false },
        },
    },
    sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer', 'cmdline' },
        --, 'copilot' },
        providers = {
            -- copilot = {
            --     name = 'copilot',
            --     module = 'blink-copilot',
            --     score_offset = -1000,
            --     async = true,
            -- },
        },
    },
    snippets = {},
    fuzzy = { implementation = 'prefer_rust' },
    signature = { enabled = true },
}

-- Treesitter: parser manager
require('tree-sitter-manager').setup {
    ensure_installed = { 'apex', 'bash', 'html', 'javascript', 'soql', 'sosl', 'typescript', 'zig' },
}

-- todo-comments
require('todo-comments').setup {
    signs = true,
    keywords = {
        IDEA = { icon = '', color = 'idea', alt = { 'IDEAS' } },
    },
    colors = {
        idea = { '#6bb300' },
    },
}

-- mini.nvim
require('mini.ai').setup { n_lines = 500 }
require('mini.surround').setup()
require('mini.icons').setup()
local statusline = require 'mini.statusline'
statusline.setup { use_icons = vim.g.have_nerd_font }
statusline.section_location = function()
    return '%2l:%-2v'
end

-- copilot.vim
-- vim.g.copilot_no_maps = true
-- vim.api.nvim_create_augroup('github_copilot', { clear = true })
-- vim.api.nvim_create_autocmd({ 'FileType', 'BufUnload' }, {
--     group = 'github_copilot',
--     callback = function(args)
--         vim.fn['copilot#On' .. args.event]()
--     end,
-- })
-- vim.fn['copilot#OnFileType']()

-- nvim-colorizer
require('colorizer').setup {
    filetypes = {
        css = { rgb_fn = true },
        html = { mode = 'foreground' },
        'lua',
    },
    user_default_options = { mode = 'background' },
}

vim.g.fff = {
    lazy_sync = true,
    debug = { enabled = true, show_scores = true },
}

-- Build fff Rust binary on first install only
local fff_so = vim.fn.stdpath 'data' .. '/site/pack/core/opt/fff.nvim/target/release/libfff_nvim.so'
if not vim.uv.fs_stat(fff_so) then
    vim.schedule(function()
        require('fff.download').download_or_build_binary()
    end)
end

-- fff keymaps
vim.keymap.set('n', 'ff', function()
    require('fff').find_files()
end, { desc = 'FFFind files' })
vim.keymap.set('n', 'fg', function()
    require('fff').live_grep()
end, { desc = 'LiFFFe grep' })
vim.keymap.set('n', 'fz', function()
    require('fff').live_grep { grep = { modes = { 'fuzzy', 'plain' } } }
end, { desc = 'Live fffuzy grep' })
vim.keymap.set('n', 'fc', function()
    require('fff').live_grep { query = vim.fn.expand '<cword>' }
end, { desc = 'Search current word' })

-- base16-nvim (dankcolors)
require('base16-colorscheme').setup {
    base00 = '#1e1e1e',
    base01 = '#000000',
    base02 = '#303030',
    base03 = '#a59695',
    base04 = '#ffebeb',
    base05 = '#fff6f6',
    base06 = '#fff6f6',
    base07 = '#fff6f6',
    base08 = '#ff8382',
    base09 = '#ff8382',
    base0A = '#ff7771',
    base0B = '#ffdb48',
    base0C = '#ffb7b4',
    base0D = '#ff7771',
    base0E = '#ff8f8a',
    base0F = '#ff8f8a',
}
-- File watcher for live-reload of base16 colors
local current_file_path = vim.fn.stdpath 'config' .. '/lua/plugins/dankcolors.lua'
if not _G._matugen_theme_watcher then
    local uv = vim.uv or vim.loop
    _G._matugen_theme_watcher = uv.new_fs_event()
    _G._matugen_theme_watcher:start(
        current_file_path,
        {},
        vim.schedule_wrap(function()
            local new_spec = dofile(current_file_path)
            if new_spec and new_spec[1] and new_spec[1].config then
                new_spec[1].config()
                print 'Theme reload'
            end
        end)
    )
end

-- Debug (nvim-dap)
local dap = require 'dap'
local dapui = require 'dapui'
require('mason-nvim-dap').setup {
    automatic_setup = true,
    automatic_installation = false,
    handlers = {},
    ensure_installed = {},
}
dap.adapters.codelldb = {
    type = 'server',
    port = '${port}',
    executable = {
        command = 'codelldb',
        args = { '--port', '${port}' },
    },
}
dap.configurations.zig = {
    {
        name = 'Launch',
        type = 'codelldb',
        request = 'launch',
        program = function()
            local workspace_basename = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
            local last_binary_name = vim.g.zig_last_binary_name or workspace_basename
            local binary_name = vim.fn.input('Binary name (leave empty for ' .. workspace_basename .. '): ', last_binary_name)
            if binary_name == '' then
                binary_name = workspace_basename
            end
            vim.g.zig_last_binary_name = binary_name
            return '${workspaceFolder}/zig-out/bin/' .. binary_name
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = {},
    },
}
vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', dap.step_into, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', dap.step_over, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', dap.step_out, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function()
    dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
end, { desc = 'Debug: Set Breakpoint' })
dapui.setup {
    icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
    controls = {
        icons = {
            pause = '⏸',
            play = '▶',
            step_into = '⏎',
            step_over = '⏭',
            step_out = '⏮',
            step_back = 'b',
            run_last = '▶▶',
            terminate = '⏹',
            disconnect = '⏏',
        },
    },
}
vim.keymap.set('n', '<F7>', dapui.toggle, { desc = 'Debug: See last session result.' })
dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close
require('dap-go').setup()

-- Lint
local lint = require 'lint'
lint.linters_by_ft = {}
local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
    group = lint_augroup,
    callback = function()
        require('lint').try_lint()
    end,
})

vim.keymap.set('n', 'ff', function()
    require('fff').find_files()
end, { desc = 'FFFind files' })

-- Autosave easter egg
require 'custom.plugins.autosave'
require 'custom.colorscheme'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
vim.o.tags = './tags,tags'
vim.o.tagfunc = 'v:lua.vim.lsp.tagfunc'

-- Project runner: set command, auto-runs on save (silent background)
local RunnerCmd = nil
local RunnerJob = nil
local function run_command()
    if not RunnerCmd then
        return
    end

    if RunnerJob then
        pcall(vim.fn.jobstop, RunnerJob)
    end
    vim.fn.jobstart "pkill -f 'zig-out/bin' 2>/dev/null || true"

    RunnerJob = vim.fn.jobstart(RunnerCmd, {
        detach = true,
        on_exit = function(_, code)
            if code ~= 0 then
                vim.notify('Build failed (exit ' .. code .. ')', vim.log.levels.ERROR)
            end
        end,
    })
end
vim.keymap.set('n', '<leader>rm', function()
    vim.ui.input({ prompt = 'Run command: ', default = RunnerCmd or 'zig build run' }, function(input)
        if input then
            RunnerCmd = input
            vim.notify('Runner: ' .. input)
        end
    end)
end, { desc = 'Set run command' })
vim.keymap.set('n', '<leader>rr', function()
    if not RunnerCmd then
        vim.notify('No command set! Use <leader>rm first', vim.log.levels.WARN)
        return
    end
    run_command()
end, { desc = 'Run now' })
vim.keymap.set('n', '<leader>rk', function()
    if RunnerJob then
        pcall(vim.fn.jobstop, RunnerJob)
    end
    vim.fn.jobstart "pkill -f 'zig-out/bin' 2>/dev/null || true"
    RunnerCmd = nil
    vim.notify 'Runner disabled'
end, { desc = 'Kill & disable' })
vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.zig',
    callback = function()
        if RunnerCmd then
            run_command()
        end
    end,
})

-- Toggle memory module for persistent toggle states
require 'custom.toggle_memory'
require 'custom.zig'
