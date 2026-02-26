return {
  'stevearc/oil.nvim',
  opts = {
    keymaps = {
      ["<C-h>"] = false,
      ["<C-j>"] = false,
      ["<C-k>"] = false,
      ["<C-l>"] = false,
    },
    columns = {
      "icon",
      "permissions",
      "size",
      "mtime",
    },
    view_options = {
      -- Show files and directories that start with "."
      show_hidden = true,
      -- This function defines what is considered a "hidden" file
      is_hidden_file = function(name, bufnr)
        return vim.startswith(name, ".")
      end,
      -- This function defines what will never be shown, even when `show_hidden` is set
      is_always_hidden = function(name, bufnr)
        return false
      end,
    },
    -- Configuration for the file preview window
    preview_win = {
      -- Whether the preview window is automatically updated when the cursor is moved
      update_on_cursor_moved = false,
      -- How to open the preview window "load"|"scratch"|"fast_scratch"
      preview_method = "fast_scratch",
      -- A function that returns true to disable preview on a file e.g. to avoid lag
      disable_preview = function(filename)
        return false
      end,
      -- Window-local options to use for preview window buffers
      win_options = {},
    },
  },
  keys = {
    { "<leader>-", ":Oil<CR>", desc = "Open parent directory" },
    {
      "<leader>dev",
      function()
        require("oil").open(vim.env.userprofile .. '\\dev')
      end,
      desc = "Open src folder"
    },
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
      '<leader>ep',
      function()
        local oil = require("oil")
        oil.open(vim.fn.stdpath('config') .. '\\lua\\plugins')
      end
    },
    {
      '<leader>conf',
      function() require("oil").open(vim.env.userprofile .. '/.config') end
    },
    {
      '<leader>op',
      function()
        local oil_ok, oil = pcall(require, "oil")
        if oil_ok and oil.get_current_dir() then
          -- In an Oil buffer: copy the full path of the entry under cursor
          local entry = oil.get_cursor_entry()
          if entry then
            local path = oil.get_current_dir() .. entry.name
            vim.fn.setreg("+", path)
            vim.notify("Copied: " .. path)
          end
        else
          -- Not in Oil: copy the current buffer's file path
          local path = vim.fn.expand("%:p")
          vim.fn.setreg("+", path)
          vim.notify("Copied: " .. path)
        end
      end,
      desc = "Copy path (Oil entry or current buffer)",
    },
    {
      '<leader>home',
      function() require("oil").open(vim.env.userprofile) end
    }
  },
  dependencies = { "nvim-tree/nvim-web-devicons" },
}
