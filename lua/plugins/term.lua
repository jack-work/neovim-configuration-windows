return {
  "akinsho/toggleterm.nvim",
  config = function()
    local status, toggleterm = pcall(require, 'toggleterm')
    if (not status) then return end

    vim.cmd("let &shell = has('win32') ? 'powershell' : 'pwsh'")
    vim.cmd(
      "let &shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;'")
    vim.cmd("let &shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'")
    vim.cmd("let &shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'")
    vim.cmd("set shellquote= shellxquote=")

    toggleterm.setup({
      size = 10,
      open_mapping = [[<C-3>]],
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = true,
      close_on_exit = true,
      direction = 'float',
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal"
        }
      }
    })

    local Terminal = require('toggleterm.terminal').Terminal

    -- Define the terminal instance
    local nodeCLI = Terminal:new({
      cmd = "yipyap",
      direction = "float",
      open_mapping = [[<C-q>]],
      float_opts = {
        border = "curved",
        width = 80,
        height = 50,
      },
      close_on_exit = true,
      start_in_insert = true,
    })

    -- Create toggle function
    function _TOGGLE_NODE_CLI()
      nodeCLI:toggle()
    end

    -- Define the terminal instance
    local aichat = Terminal:new({
      cmd = "aichat -r coder",
      direction = "float",
      open_mapping = [[<C-q>]],
      float_opts = {
        border = "curved",
        width = 150,
        height = 50,
      },
      close_on_exit = true,
      start_in_insert = true,
    })

    -- Create toggle function
    function _TOGGLE_AICHAT()
      aichat:toggle()
    end

    -- Set keybinding
    local function custom_terminal()
      -- Create new buffer (exactly like :terminal does)
      vim.cmd('enew')

      -- Add your environment variables
      local job_id = vim.fn.termopen('pwsh', {
        env = {
          VIM_SERVERNAME = vim.v.servername or 'VIMSERVER',
          VIM_LISTEN_ADDRESS = vim.v.servername
        }
      })

      vim.schedule(function()
        vim.bo.syntax = ''
        -- vim.bo.filetype = ''
        -- vim.diagnostic.disable(0)
        -- vim.wo.number = false
        vim.wo.signcolumn = 'no'
        vim.wo.spell = false
      end)
    end

    -- Override the :terminal command
    vim.api.nvim_create_user_command('Terminal', custom_terminal, {
      nargs = 0,
      force = true
    })

    -- Create abbreviation to intercept :terminal
    vim.cmd('cabbrev terminal Terminal')
    vim.cmd('cabbrev term Terminal')
    vim.keymap.set("n", "<leader>yy", "<cmd>lua _TOGGLE_NODE_CLI()<CR>")
    vim.keymap.set("n", "<leader>ai", "<cmd>lua _TOGGLE_AICHAT()<CR>")
    vim.keymap.set("n", "<leader>th", ":exe 'cd %:p:h' | terminal<CR>")
    vim.keymap.set("n", "<leader>tm", function()
      -- Create new buffer (exactly like :terminal does)
      vim.cmd('enew')

      -- Add your environment variables
      local job_id = vim.fn.termopen('pwsh', {
        env = {
          VIM_SERVERNAME = vim.v.servername or 'VIMSERVER',
          VIM_LISTEN_ADDRESS = vim.v.servername
        }
      })

      vim.schedule(function()
        vim.bo.syntax = ''
        -- vim.bo.filetype = ''
        -- vim.diagnostic.disable(0)
        -- vim.wo.number = false
        vim.wo.signcolumn = 'no'
        vim.wo.spell = false
      end)
    end)
  end,
}
