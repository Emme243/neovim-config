-- Icons
local signs = {
  Error = " ",
  Warn = " ",
  Hint = " ",
  Info = " ",
}

for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- Diagnostics config
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
    spacing = 1,
  },
  float = {
    border = "rounded",
    source = "always",
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
