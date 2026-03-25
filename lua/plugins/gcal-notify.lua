return {
	dir = vim.fn.stdpath("config") .. "/lua/gcal-notify",
	name = "gcal-notify",
	event = "VeryLazy",
	dependencies = {
		"rcarriga/nvim-notify",
		"nvim-lua/plenary.nvim",
	},
	config = function()
		require("gcal-notify").setup()
	end,
	keys = {
		{ "<leader>gc", desc = "Toggle GCal Notifications" },
	},
	cmd = {
		"GcalSetup",
		"GcalAddAccount",
		"GcalRemoveAccount",
		"GcalListAccounts",
		"GcalStart",
		"GcalStop",
		"GcalTest",
	},
}
