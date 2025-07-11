return {
  "beauwilliams/focus.nvim",
  config = function()
    require("focus").setup({
      enable = true,
      commands = true,
      autoresize = {
        enable = true,
        width = 0,
        height = 0,
        minwidth = 0,
        minheight = 0,
        focusedwindow_minwidth = 0,
        focusedwindow_minheight = 0,
        height_quickfix = 10,
      },
      split = {
        bufnew = false,
        tmux = false,
      },
      ui = {
        number = false,
        relativenumber = false,
        hybridnumber = false,
        absolutenumber_unfocussed = false,
        cursorline = true,
        cursorcolumn = false,
        colorcolumn = {
          enable = false,
          list = '+1',
        },
        signcolumn = true,
        winhighlight = false,
      }
    })
  end
}
