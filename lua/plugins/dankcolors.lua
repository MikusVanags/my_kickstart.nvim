return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({

				base00 = '#1e1e1e',
				base01 = '#000000',
				base02 = '#303030',
				base03 = '#a59695',
				base0B = '#ffdb48',
				base04 = '#ffebeb',
				base05 = '#fff6f6',
				base06 = '#fff6f6',
				base07 = '#fff6f6',
				base08 = '#ff8382',
				base09 = '#ff8382',
				base0A = '#ff7771',
				base0C = '#ffb7b4',
				base0D = '#ff7771',
				base0E = '#ff8f8a',
				base0F = '#ff8f8a',
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
