return {
  dir = vim.fn.stdpath("config") .. "/lua/plugins/zj",
  config = function()
    require("plugins/zj").setup()
  end
}

