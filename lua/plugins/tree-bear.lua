return {
  dir = vim.fn.stdpath("config") .. "/lua/tree-bear",
  dependencies = {
    "folke/snacks.nvim",
    "ibhagwan/fzf-lua",
  },
  config = function()
    require("tree-bear").setup()
  end,
  keys = {
    { "<leader>gw", function() require("tree-bear").lazygit_worktree() end, desc = "Lazygit (worktree picker)" },
    { "<leader>gWt", function() require("tree-bear").track_worktree() end, desc = "Worktree: track remote branch" },
    { "<leader>gWn", function() require("tree-bear").new_worktree() end, desc = "Worktree: new branch from remote" },
  },
}
