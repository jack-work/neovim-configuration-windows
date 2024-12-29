return {
  'nvim-telescope/telescope.nvim',
  branch = '0.1.x',
  lazy = false,
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- Optional but recommended
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      lazy = false,
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
  },
  config = function()
    local telescope = require('telescope')
    local builtin = require('telescope.builtin')
    telescope.setup({
      defaults = {
        path_display = { "truncate" },
        file_ignore_patterns = {
          "node_modules",
          ".git/",
          "dist/",
          "build/"
        },
      }
    })

    -- Load fzf native if installed
    pcall(telescope.load_extension, 'fzf')

    -- Keymaps
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
    vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Recent files' })
    vim.keymap.set('n', '<leader>fw', builtin.grep_string, { desc = 'Find word under cursor' })
  end,
  {
    "danymat/neogen",
    config = true,
  }
}
