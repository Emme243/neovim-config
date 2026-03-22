-- Diagnostics config
vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
  virtual_text = {
    prefix = "●",
    spacing = 1,
  },
  float = {
    border = "rounded",
    source = true,
  },
  underline = true,
  severity_sort = true,
})

-- Hover popup
vim.o.updatetime = 250

-- Manual key
vim.keymap.set("n", "<leader>sd", vim.diagnostic.open_float, {
  desc = "Show diagnostics",
})
