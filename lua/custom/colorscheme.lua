-- Colorscheme setup with transparency toggle

local ThemeToggle = { transparent = false, current = vim.g.colors_name or 'rose-pine-moon', updating = false }

local state_file = vim.fn.stdpath 'state' .. '/colorscheme_state.json'

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

local function apply_theme_transparency(enable, opts)
    opts = opts or {}
    ThemeToggle.transparent = enable

    local current = opts.current or vim.g.colors_name or ThemeToggle.current or 'rose-pine-main'
    ThemeToggle.current = current

    save_state { colorscheme = current, transparent = ThemeToggle.transparent }

    local ok_tokyo, tokyonight = pcall(require, 'tokyonight')
    if ok_tokyo then
        tokyonight.setup { transparent = enable }
    end

    local ok_rose, rose = pcall(require, 'rose-pine')
    if ok_rose then
        rose.setup {
            variant = 'auto',
            dark_variant = 'main',
            extend_background_behind_borders = true,
            nable = {
                terminal = true,
                legacy_highlights = true,
                migrations = true,
            },
            styles = {
                bold = true,
                italic = false,
                transparency = enable,
            },
        }
    end

    local ok_poi, poi = pcall(require, 'poimandres')
    if ok_poi then
        poi.setup {
            bold_vert_split = true,
            dim_nc_background = true,
            disable_background = not enable,
            disable_float_background = not enable,
            disable_italics = true,
        }
    end

    local ok_cat, catppuccin = pcall(require, 'catppuccin')
    if ok_cat then
        catppuccin.setup {
            flavour = 'auto',
            background = {
                light = 'latte',
                dark = 'mocha',
            },
            transparent_background = enable,
            show_end_of_buffer = true,
            term_colors = true,
            dim_inactive = {
                enabled = false,
            },
            no_italic = true,
            no_bold = false,
            no_underline = false,
            styles = {
                comments = {},
                conditionals = {},
                loops = {},
                functions = {},
                keywords = {},
                strings = {},
                variables = {},
                numbers = {},
                booleans = {},
                properties = {},
                types = {},
                operators = {},
            },
            color_overrides = {},
            custom_highlights = {},
            default_integrations = true,
            integrations = {
                cmp = true,
                gitsigns = true,
                nvimtree = true,
                treesitter = true,
                mason = true,
                dap = true,
                which_key = true,
                native_lsp = {
                    enabled = true,
                    virtual_text = {
                        errors = {},
                        hints = {},
                        warnings = {},
                        information = {},
                        ok = {},
                    },
                    underlines = {
                        errors = { 'underline' },
                        hints = { 'underline' },
                        warnings = { 'underline' },
                        information = { 'underline' },
                        ok = { 'underline' },
                    },
                    inlay_hints = {
                        background = true,
                    },
                },
                mini = {
                    enabled = true,
                    indentscope_color = '',
                },
            },
        }
    end

    ThemeToggle.updating = true
    vim.cmd.colorscheme(current)
    ThemeToggle.updating = false

    if enable then
        local groups = {
            'Normal',
            'NormalNC',
            'NormalFloat',
            'FloatBorder',
            'SignColumn',
            'LineNr',
            'CursorLineNr',
            'StatusLine',
            'StatusLineNC',
            'WinSeparator',
            'NeoTreeNormal',
            'NeoTreeNormalNC',
        }

        for _, group in ipairs(groups) do
            vim.api.nvim_set_hl(0, group, { bg = 'NONE' })
        end
    end

    if not opts.silent then
        vim.notify('Background transparency: ' .. (enable and 'on' or 'off'))
    end
end

function ThemeToggle.toggle()
    apply_theme_transparency(not ThemeToggle.transparent)
end

vim.api.nvim_create_user_command('ToggleTransparent', ThemeToggle.toggle, {})
vim.keymap.set('n', '<leader>tb', ThemeToggle.toggle, { desc = '[T]oggle [B]ackground transparency' })

vim.api.nvim_create_autocmd('ColorScheme', {
    callback = function()
        if ThemeToggle.updating then
            return
        end
        ThemeToggle.current = vim.g.colors_name
        if ThemeToggle.transparent then
            apply_theme_transparency(true, { silent = true, current = ThemeToggle.current })
        else
            save_state { colorscheme = ThemeToggle.current, transparent = false }
        end
    end,
})

local function apply_startup_state()
    local state = load_state()
    local scheme = state.colorscheme or 'rose-pine-main'
    local transparent = state.transparent == true

    ThemeToggle.current = scheme
    ThemeToggle.transparent = transparent

    ThemeToggle.updating = true
    local ok = pcall(vim.cmd.colorscheme, scheme)
    ThemeToggle.updating = false

    if not ok then
        ThemeToggle.current = 'rose-pine-main'
        pcall(vim.cmd.colorscheme, 'rose-pine-main')
        save_state { colorscheme = 'rose-pine-main', transparent = transparent }
    end

    apply_theme_transparency(transparent, { silent = true, current = ThemeToggle.current })
end

apply_startup_state()
