local aug = vim.api.nvim_create_augroup("UserLsp", { clear = true })

local function client_supports_formatting(client)
	return client.supports_method and client.supports_method("textDocument/formatting")
end

local function buf_has_formatter(bufnr)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client_supports_formatting(client) then
			return true
		end
	end
	return false
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = aug,
	callback = function(args)
		local map = vim.keymap.set
		local opts = { buffer = args.buf }
		map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", { desc = "Go to Definition" }, opts))
		map("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", { desc = "References" }, opts))
		map("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", { desc = "Implementations" }, opts))
		map("n", "gt", vim.lsp.buf.type_definition, vim.tbl_extend("force", { desc = "Type Definitions" }, opts))
		map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", { desc = "Hover Docs" }, opts))
		map("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", { desc = "Code Action" }, opts))
		map("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", { desc = "Rename" }, opts))
	end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
	group = aug,
	callback = function(args)
		local buf = args.buf
		local bo = vim.bo[buf]
		if not bo.modifiable or bo.bt == "nofile" or bo.bt == "prompt" or bo.bt == "help" then
			return
		end
		if not buf_has_formatter(buf) then
			return
		end
		vim.lsp.buf.format({
			bufnr = buf,
			async = false,
			filter = function(client)
				return client.name == "null-ls"
			end,
		})
	end,
})
