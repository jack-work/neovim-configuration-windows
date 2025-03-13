---@diagnostic disable: undefined-field, undefined-global: vim
return {
  { 'williamboman/mason.nvim' },
  { 'williamboman/mason-lspconfig.nvim' },
  {
    'neovim/nvim-lspconfig',
    config = function()
      vim.keymap.set('n', '<leader>ld', vim.diagnostic.open_float, { desc = 'open_float, open code float' })
    end,
  },
  {
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'L3MON4D3/LuaSnip',
    'saadparwaiz1/cmp_luasnip',
  },
  {
    'rebelot/kanagawa.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme('kanagawa')
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
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "typescript", "javascript" }, -- add languages you need
        highlight = { enable = true },
      })
    end,
  },
  {
    "danymat/neogen",
    config = true,
  }
}
