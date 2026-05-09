return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local parsers = require("nvim-treesitter.parsers")
    parsers.kusto = {
      install_info = {
        url = "https://github.com/Willem-J-an/tree-sitter-kusto",
        files = { "src/parser.c" },
        branch = "main",
      },
      filetype = "kusto",
    }

    vim.filetype.add({
      extension = {
        kql = "kusto",
        csl = "kusto",
        kusto = "kusto",
      },
    })

    require("nvim-treesitter.configs").setup({
      ensure_installed = { "c_sharp", "typescript", "javascript", "kusto" },
      highlight = { enable = true },
    })
  end,
}
