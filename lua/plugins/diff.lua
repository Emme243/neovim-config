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
		{
			"<leader>dr",
			function()
				MiniDiff.do_hunks(0, "reset", { line_start = vim.fn.line("."), line_end = vim.fn.line(".") })
			end,
			desc = "Reset diff (line)",
		},
		{
			"<leader>dR",
			function()
				MiniDiff.do_hunks(0, "reset", { line_start = 1, line_end = vim.api.nvim_buf_line_count(0) })
			end,
			desc = "Reset diff (file)",
		},
		{
			"]h",
			function()
				MiniDiff.goto_hunk("next")
			end,
			desc = "Next diff hunk",
		},
		{
			"[h",
			function()
				MiniDiff.goto_hunk("prev")
			end,
			desc = "Prev diff hunk",
		},
	},
	config = function()
		require("mini.diff").setup()
	end,
}
