-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set clipboard=unnamedplus")

vim.keymap.set('c', '%%', function()
  if vim.fn.getcmdtype() == ':' then
    return vim.fn.expand('%:h') .. '/'
  else
    return '%%'
  end
end, { expr = true })

-- ~/.config/nvim/lua/config/keymaps.lua

-- Better LSP UX (Telescope, lazy-safe)
local map = vim.keymap.set
map("n", "gd", function()
  require("telescope.builtin").lsp_definitions()
end, { desc = "Go to Definition" })

map("n", "gr", function()
  require("telescope.builtin").lsp_references()
end, { desc = "References" })

map("n", "gi", function()
  require("telescope.builtin").lsp_implementations()
end, { desc = "Implementations" })

map("n", "gt", function()
  require("telescope.builtin").lsp_type_definitions()
end, { desc = "Type Definitions" })

-- LSP actions
map("n", "K", vim.lsp.buf.hover, { desc = "Hover Docs" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename" })

-- Diagnostics
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev Diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })

-- Format
map("n", "<leader>cf", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format File" })
