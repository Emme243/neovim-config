return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			close_if_last_window = false,

			window = {
				position = "float",
				popup = {
					size = {
						height = "80%",
						width = "60%",
					},
					position = "50%",
					border = "rounded",
				},
			},

			filesystem = {
				follow_current_file = {
					enabled = true,
				},
				hijack_netrw_behavior = "open_default",
				use_libuv_file_watcher = true,
				filtered_items = {
					hide_dotfiles = false,
				},
			},
		},

		keys = {
			{
				"<leader>e",
				function()
					require("neo-tree.command").execute({
						toggle = true,
						dir = vim.loop.cwd(),
						position = "float",
					})
				end,
				desc = "Toggle Neo-tree (float)",
			},
		},
	},
	{
		"antosha417/nvim-lsp-file-operations",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neo-tree/neo-tree.nvim", -- makes sure that this loads after Neo-tree.
		},
		config = function()
			require("lsp-file-operations").setup()
		end,
	},
	{
		"s1n7ax/nvim-window-picker",
		version = "2.*",
		config = function()
			require("window-picker").setup({
				filter_rules = {
					include_current_win = false,
					autoselect_one = true,
					-- filter using buffer options
					bo = {
						-- if the file type is one of following, the window will be ignored
						filetype = { "neo-tree", "neo-tree-popup", "notify" },
						-- if the buffer type is one of following, the window will be ignored
						buftype = { "terminal", "quickfix" },
					},
				},
			})
		end,
	},
}
