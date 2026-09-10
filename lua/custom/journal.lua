local M = {}

function M.open()
    local path = vim.fn.expand '~/journal.md'
    local bufnr = vim.fn.bufnr(path)

    -- Reuse an existing journal window, including one in another tab.
    if bufnr ~= -1 then
        for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
            if vim.api.nvim_win_get_config(win).relative == '' then
                vim.api.nvim_set_current_win(win)
                return
            end
        end
    end

    local windows = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative == '' then
            windows = windows + 1
        end
    end

    -- Keep at least roughly 80 columns per window; avoid a fourth split.
    if windows >= 3 or vim.o.columns < (windows + 1) * 80 then
        vim.cmd.tabedit(vim.fn.fnameescape(path))
    else
        vim.cmd('botright vsplit ' .. vim.fn.fnameescape(path))
    end

    vim.wo.wrap = true
    vim.wo.linebreak = true
end

vim.api.nvim_create_user_command('Journal', M.open, { desc = 'Open the work journal' })
vim.keymap.set('n', '<leader>wj', M.open, { desc = '[W]ork [J]ournal' })

return M
