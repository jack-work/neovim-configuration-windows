return {
  dir = vim.fn.stdpath("config") .. "/lua/plugins/filesmith",
  keys = {
    {
      "<leader>cf",
      function()
        require("plugins/filesmith").create_file_with_code()
      end,
      desc = "Create file from code block"
    },
    {
      "<leader>ycl",
      function()
        require("plugins/filesmith").copy_cursor_location()
      end
    },
    {
      "<leader>yff",
      function()
        require("plugins/filesmith").copy_file_link()
      end
    },
  }
}
