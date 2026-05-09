return {
  dir = vim.fn.stdpath("config") .. "/lua/merc",
  dependencies = { "ibhagwan/fzf-lua" },
  keys = {
    { "<leader>merc", function() require("merc.picker").pick() end, desc = "Merc: process picker" },
    { "<leader>merr", function() require("merc.picker").pick({ stats = true }) end, desc = "Merc: with resources" },
    { "<leader>merj", function() require("merc.picker").pick({ junk = true }) end, desc = "Merc: junk" },
    { "<leader>mera", function() require("merc.picker").pick({ stats = true, junk = true }) end, desc = "Merc: all" },
  },
}
