local map = vim.keymap.set
map("c", "%%", function()
	if vim.fn.getcmdtype() == ":" then
		return vim.fn.expand("%:h") .. "/"
	else
		return "%%"
	end
end, { expr = true })

-- Diagnostics
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev Diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })

-- Format (manual; format-on-save is in config.lsp-keymaps when a formatter client is attached)
map("n", "<leader>rf", function()
	vim.lsp.buf.format({
		async = true,
		filter = function(client)
			return client.name == "null-ls"
		end,
	})
end, { desc = "Format File" })
