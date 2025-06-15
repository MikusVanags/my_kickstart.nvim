local save_times = 0
local display_notif = 10

vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('ETC?', { clear = true }),
  callback = function()
    save_times = save_times + 1
    if save_times == display_notif then
      vim.notify('ETC? (Easier To Change?)', 'error')
      save_times = 0
    end
  end,
})

return {}
