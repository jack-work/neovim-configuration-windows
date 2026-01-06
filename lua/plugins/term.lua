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
    -- Store terminal instances globally
    _G.named_terminals = _G.named_terminals or {}

    -- Function to create and run a named terminal with a command
    -- mode can be: "background", "current", "split", "vsplit", "tab"
    function _G.create_named_terminal(name, cmd, mode)
      mode = mode or "background"

      -- Check if terminal already exists
      if _G.named_terminals[name] then
        local term = _G.named_terminals[name]
        if mode == "background" then
          -- Just ensure it's running
          if not term:is_open() then
            term:open()
            term:close()
          end
        elseif mode == "tab" then
          term.direction = "tab"
          term:open()
        elseif mode == "split" then
          term.direction = "horizontal"
          term:open()
        elseif mode == "vsplit" then
          term.direction = "vertical"
          term:open()
        elseif mode == "current" then
          term.direction = "horizontal"
          term:open()
          vim.cmd('only')
        end
        return term
      end

      -- Create new terminal
      local term_opts = {
        cmd = cmd,
        close_on_exit = false,
        hidden = (mode == "background"),
        display_name = name,
      }

      if mode == "tab" then
        term_opts.direction = "tab"
      elseif mode == "split" then
        term_opts.direction = "horizontal"
      elseif mode == "vsplit" then
        term_opts.direction = "vertical"
      elseif mode == "current" then
        term_opts.direction = "horizontal"
      else -- background
        term_opts.direction = "horizontal"
        term_opts.hidden = true
      end

      local term = Terminal:new(term_opts)
      _G.named_terminals[name] = term

      -- Open the terminal based on mode
      if mode == "background" then
        term:open()
        term:close() -- Open then immediately hide to start the command
      else
        term:open()
        if mode == "current" then
          vim.cmd('only')
        end
      end

      return term
    end

    -- Function to toggle a named terminal
    function _G.toggle_named_terminal(name)
      if _G.named_terminals[name] then
        _G.named_terminals[name]:toggle()
      else
        vim.notify("Terminal '" .. name .. "' does not exist", vim.log.levels.WARN)
      end
    end

    function _G.start_term(name, cmd)
      -- Check if buffer with this name already exists
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match(name .. "$") then
          return
        end
      end

      -- Create new buffer (exactly like :terminal does)
      vim.cmd('enew')

      -- Add your environment variables
      local job_id = vim.fn.termopen({ 'pwsh', '-NoExit', '-Command', cmd }, {
        env = {
          VIM_SERVERNAME = vim.v.servername or 'VIMSERVER',
          VIM_LISTEN_ADDRESS = vim.v.servername
        }
      })

      vim.api.nvim_buf_set_name(0, name)

      vim.schedule(function()
        vim.bo.syntax = ''
        -- vim.bo.filetype = ''
        -- vim.diagnostic.disable(0)
        -- vim.wo.number = false
        vim.wo.signcolumn = 'no'
        vim.wo.spell = false
      end)
    end

    -- Function to open multiple terminals with a single command
    function _G.start_dev_terminals()
      _G.start_term("copilot", "npx copilot-api@latest start")
      _G.start_term("ccr", "ccr start")
      _G.start_term("claude", "ccr code")
    end

    vim.keymap.set("n", "<leader>yy", "<cmd>lua _TOGGLE_NODE_CLI()<CR>")
    vim.keymap.set("n", "<leader>ai", "<cmd>lua _TOGGLE_AICHAT()<CR>")
    vim.keymap.set("n", "<leader>th", function()
      local dir = vim.fn.expand('%:p:h')
      vim.cmd('edit term://' .. dir .. '//' .. vim.o.shell)
    end)
    vim.keymap.set("n", "<leader>tm", function() _G.start_term("term -- " .. os.date("%Y%m%d-%H%M%S"), ". prof") end)

    -- Add keymap to start all dev terminals
    vim.keymap.set("n", "<leader>clod", "<cmd>lua _G.start_dev_terminals()<CR>", { desc = "Start dev terminals" })
  end,
}
