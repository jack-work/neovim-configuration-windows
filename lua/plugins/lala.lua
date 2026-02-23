return {
  dir = vim.fn.stdpath("config") .. "/lua/lala",
  keys = {
    { "<leader>Tt", function() require("lala").get_token() end, desc = "Run nearest Get-Token.ps1" },
    { "<leader>Te", function() require("lala").open_env() end,  desc = "Open nearest http-client.env.json" },
  },
}
