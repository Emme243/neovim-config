return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	event = "VeryLazy",
	opts = {
		options = {
			diagnostics = "nvim_lsp",
			offsets = {
				{
					filetype = "neo-tree",
					text = "File Explorer",
					highlight = "Directory",
					separator = true,
				},
			},
		},
	},
	keys = {
		{ "<Tab>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
		{ "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
		{ "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin Buffer" },
		{ "<leader>bc", "<cmd>BufferLinePickClose<cr>", desc = "Pick Buffer to Close" },
	},
}
