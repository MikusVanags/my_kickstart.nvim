return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#121315',
				base01 = '#121315',
				base02 = '#878d92',
				base03 = '#878d92',
				base04 = '#dfe6ed',
				base05 = '#f8fbff',
				base06 = '#f8fbff',
				base07 = '#f8fbff',
				base08 = '#ff9fbc',
				base09 = '#ff9fbc',
				base0A = '#c9e1f8',
				base0B = '#a5ffb1',
				base0C = '#e5f2ff',
				base0D = '#c9e1f8',
				base0E = '#d7ebff',
				base0F = '#d7ebff',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#878d92',
				fg = '#f8fbff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#c9e1f8',
				fg = '#121315',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#878d92' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#e5f2ff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#d7ebff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#c9e1f8',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#c9e1f8',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#e5f2ff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#a5ffb1',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#dfe6ed' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#dfe6ed' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#878d92',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
