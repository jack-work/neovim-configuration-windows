return {
  dir = vim.fn.stdpath("config") .. "/lua/gym",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("gym").setup()
  end,
}
