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
    telescope.setup({
      defaults = {
        shorten_path = true,
        path_display = { "truncate" },
        file_ignore_patterns = {
          "node_modules",
          "%.git/",
          "%.cache",
          "%.DS_Store",
          "build/",
          "dist/",
          "%.env",
          ".*bin/",
          ".*obj/",
          ".*exe/",
        },
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          -- Add ignore patterns for ripgrep
          "--glob=!.git/*",
          "--glob=!node_modules/*",
          "--glob=!build/*",
          "--glob=!dist/*",
          "--glob=!obj/*",
          "--glob=!bin/*",
          "--glob=!*/**/exe/*",
        }
      }

    })

    -- Load fzf native if installed
    pcall(telescope.load_extension, 'fzf')
  end,
  keys = {
    { '<leader>fg', function()
      require("telescope.builtin").live_grep({
        prompt_title = "FILE GREP!"
      })
    end, { desc = 'Live grep' } },

    -- { '<leader>fgb', function()
    --   require("telescope.builtin").live_grep({
    --     grep_open_files = true,
    --     prompt_title = "Can You Suffer the Buffer?",
    --     only_sort_text = true,
    --   })
    -- end, { desc = 'Find word under cursor' } },

    { '<leader>fb', function()
      require("telescope.builtin").buffers({
        prompt_title = "Buffer? I Hardly Know Her!"
      })
    end, { desc = 'Find buffers' } },

    { '<leader>fh', function()
      require("telescope.builtin").help_tags({
        prompt_title = "Help me if you can I'm feeling down"
      })
    end, { desc = 'Help tags' } },

    { '<leader>fr', function()
      require("telescope.builtin").oldfiles({
        prompt_title = "History repeats itself."
      })
    end, { desc = 'Recent files' } },

    { '<leader>fw', function()
      require("telescope.builtin").grep_string({
        prompt_title = "Words, words, words."
      })
    end, { desc = 'Find word under cursor' } },

    { '<leader>fig', function()
      require("telescope.builtin").live_grep({
        prompt_title = "Out grepping in foreign lands",
        cwd = vim.fn.expand('%:p:h')
      })
    end, { desc = 'Find word under cursor in current dir' } },
    {
      '<C-f>', function() require('telescope.actions.layout').toggle_preview() end
    }
  },
}
