return {
  'stevearc/oil.nvim',
  opts = {},
  show_path = true,
  keys = {
    { "<leader>-",    ":Oil<CR>",              desc = "Open parent directory" },
    {
      "<leader>src",
      function()
        require("oil").open(vim.env.userprofile .. '\\src')
      end,
      desc = "Open src folder"
    },
    {
      "<leader>down",
      function()
        require("oil").open(vim.env.userprofile .. '\\Downloads')
      end,
      desc = "Open Downloads folder"
    },
    {
      "<leader>fig",
      function()
        local oil = require("oil")
        local path = (oil.get_cursor_entry() or {}).path or oil.get_current_dir() or vim.fn.expand('%:p:h')
        require("telescope.builtin").live_grep({
          prompt_title = "grepping the directory of the current buffer",
          cwd = path })
      end,
      desc = "Grep in directory"
    },
    {
      '<leader>ep',
      function()
        local oil = require("oil")
        oil.open(vim.fn.stdpath('config') .. '\\lua\\plugins')
      end
    },
    {
      '<leader>conf',
      function() require("oil").open(vim.env.userprofile .. '/.config') end
    }
  },
  dependencies = { "nvim-tree/nvim-web-devicons" },
}
