return {
  {
    "mason-org/mason.nvim",
    opts = {}
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "vtsls",      -- Vue/TS
        "ts_ls",     -- JS/TS
        "vue_ls",        -- Vue
        "lua_ls",       -- Neovim config
        "pyright",      -- Python
        "jsonls",       -- JSON
        "html",         -- HTML
        "cssls",        -- CSS
      }
    },
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "neovim/nvim-lspconfig",
    },
  }
} 
