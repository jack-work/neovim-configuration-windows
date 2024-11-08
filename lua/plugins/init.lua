---@diagnostic disable: undefined-field, undefined-global: vim
return {
  { 'williamboman/mason.nvim' },
  { 'williamboman/mason-lspconfig.nvim' },
  { 'neovim/nvim-lspconfig' },
  {
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'L3MON4D3/LuaSnip',
    'saadparwaiz1/cmp_luasnip',
  },
  {
    'stevearc/oil.nvim',
    opts = {},
    keys = {
      { "<leader>-", ":Oil<CR>", desc = "Open parent directory" },
      {
        "<C-g>",
        function()
          local oil = require("oil")
          local path = (oil.get_cursor_entry() or {}).path or oil.get_current_dir()
          require("telescope.builtin").live_grep({ cwd = path })
        end,
        desc = "Grep in directory"
      },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  {
    'catppuccin/nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme('catppuccin')
    end
  },
  {
    'tpope/vim-fugitive',
    'tpope/vim-rhubarb',       -- GitHub integration
    'lewis6991/gitsigns.nvim', -- Git signs in gutter
    keys = {
      { "<leader>gs", ":Git<CR>",       desc = "Git status" },
      { "<leader>gb", ":Git blame<CR>", desc = "Git blame" },
      { "<leader>gd", ":Gdiff<CR>",     desc = "Git diff" },
      { "<leader>gl", ":Git log<CR>",   desc = "Git log" },
    },
  },
  {
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
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
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
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "typescript", "javascript" },    -- add languages you need
        highlight = { enable = true },
      })
    end,
  }
}

