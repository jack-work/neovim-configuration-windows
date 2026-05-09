return {
  "pmizio/typescript-tools.nvim",
  enabled = true,
  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  opts = {
    settings = {
      separate_diagnostic_server = true,
      tsserver_max_memory = 4096,
      complete_function_calls = true,
    },
  },
}
