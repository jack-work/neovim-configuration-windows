return {
  dir = vim.fn.stdpath("config") .. "/lua/tree-bear",
  config = function()
    require("tree-bear").setup()
  end,
}
