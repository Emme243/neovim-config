return {
	"nvim-mini/mini.diff",
	version = false,
	event = "VeryLazy",
	keys = {
		{
			"<leader>do",
			function()
				MiniDiff.toggle_overlay(0)
			end,
			desc = "Toggle diff overlay",
		},
	},
	config = function()
		require("mini.diff").setup({
			view = {
				style = "sign",
				signs = { add = "▎", change = "▎", delete = "" },
			},
		})
	end,
}
