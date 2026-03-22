return {

  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    keys = {
      {
        '<leader>ff',
        function() require('telescope.builtin').find_files() end,
        desc = 'Telescope find files',
      },
      {
        '<leader>fg',
        function() require('telescope.builtin').live_grep() end,
        desc = 'Telescope live grep',
      },
      {
        '<leader>fb',
        function() require('telescope.builtin').buffers() end,
        desc = 'Telescope buffers',
      },
      {
        '<leader>fh',
        function() require('telescope.builtin').help_tags() end,
        desc = 'Telescope help tags',
      },
    },
  },
  {
    'nvim-telescope/telescope-ui-select.nvim',
    config = function()
      require("telescope").setup {
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown {
            }
          }
        }
      }
      require("telescope").load_extension("ui-select")
    end
  }
}
