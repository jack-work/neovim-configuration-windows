return {
  "jack-work/tree-bear.nvim",
  dev = true,
  dependencies = {
    "folke/snacks.nvim",
    "ibhagwan/fzf-lua",
  },
  event = "VeryLazy",
  config = function()
    require("tree-bear").setup()
  end,
  keys = {
    { "<leader>gw", function() require("tree-bear").lazygit_worktree() end, desc = "Lazygit (worktree picker)" },
    { "<leader>gWt", function() require("tree-bear").track_worktree() end, desc = "Worktree: track remote branch" },
    { "<leader>gWn", function() require("tree-bear").new_worktree() end, desc = "Worktree: new branch from remote" },
    { "<leader>gWc", function() require("tree-bear").cleanup_worktree() end, desc = "Worktree: cleanup" },
  },
}
