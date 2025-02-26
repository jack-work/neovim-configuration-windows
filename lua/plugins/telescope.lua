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

    -- Keymaps
    vim.keymap.set({ 'n', 'v' }, '<leader>fg', function()
      builtin.live_grep({
        prompt_title = "FILE GREP!"
      })
    end, { desc = 'Live grep' })

    vim.keymap.set({ 'n', 'v' }, '<leader>fgb', function()
      builtin.live_grep({
        grep_open_files = true,
        prompt_title = "Can You Suffer the Buffer?",
        only_sort_text = true,
      })
    end, { desc = 'Find word under cursor' })

    vim.keymap.set({ 'n', 'v' }, '<leader>fb', function()
      builtin.buffers({
        prompt_title = "Buffer? I Hardly Know Her!"
      })
    end, { desc = 'Find buffers' })

    vim.keymap.set({ 'n', 'v' }, '<leader>fh', function()
      builtin.help_tags({
        prompt_title = "Help me if you can I'm feeling down"
      })
    end, { desc = 'Help tags' })

    vim.keymap.set({ 'n', 'v' }, '<leader>fr', function()
      builtin.oldfiles({
        prompt_title = "History repeats itself."
      })
    end, { desc = 'Recent files' })
    vim.keymap.set({ 'n', 'v' }, '<leader>fw', function()
      builtin.grep_string({
        prompt_title = "Words, words, words."
      })
    end, { desc = 'Find word under cursor' })

    vim.keymap.set({ 'n', 'v' }, '<leader>fig', function()
      builtin.grep_string({
        prompt_title = "Out grepping in foreign lands",
        cwd = vim.fn.expand('%:p:h')
      })
    end, { desc = 'Find word under cursor in current dir' })
  end,
  {
    "danymat/neogen",
    config = true,
  }
}
