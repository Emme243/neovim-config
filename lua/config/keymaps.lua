local map = vim.keymap.set
map('c', '%%', function()
  if vim.fn.getcmdtype() == ':' then
    return vim.fn.expand('%:h') .. '/'
  else
    return '%%'
  end
end, { expr = true })

-- LSP
map("n", "gd",  vim.lsp.buf.definition, { desc = "Go to Definition" })
map("n", "gr",  vim.lsp.buf.references, { desc = "References" })
map("n", "gi", vim.lsp.buf.implementation, { desc = "Implementations" })
map("n", "gt", vim.lsp.buf.type_definition, { desc = "Type Definitions" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover Docs" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })

-- Diagnostics
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev Diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })

-- Format
map("n", "<leader>rf", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format File" })
