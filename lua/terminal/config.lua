-- Declarative terminal configuration
-- This config defines all terminals, their properties, and keybindings

local M = {}

-- Base toggleterm configuration
M.toggleterm_opts = {
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
}

-- Shell configuration for Windows/PowerShell
M.shell_config = {
  shell = "has('win32') ? 'powershell' : 'pwsh'",
  shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;',
  shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode',
  shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode',
  shellquote = '',
  shellxquote = ''
}

-- Declarative terminal definitions
-- Each terminal can have:
--   cmd: command to run
--   direction: "float", "horizontal", "vertical", "tab"
--   float_opts: custom float options (if direction is float)
--   close_on_exit: whether to close on exit
--   start_in_insert: whether to start in insert mode
--   keymap: keybinding to toggle this terminal
--   desc: description for the keymap
--   use_ctrl: whether to use ctrl modifier (for floating chat-style windows)
M.terminals = {
  nodecli = {
    cmd = "yipyap",
    direction = "float",
    float_opts = {
      border = "curved",
      width = 80,
      height = 50,
    },
    close_on_exit = true,
    start_in_insert = true,
    keymap = "<leader>yy",
    desc = "Toggle Node CLI (yipyap)"
  },

  aichat = {
    cmd = "aichat -r coder",
    direction = "float",
    float_opts = {
      border = "curved",
      width = 150,
      height = 50,
    },
    close_on_exit = true,
    start_in_insert = true,
    keymap = "<leader>ai",
    desc = "Toggle AI Chat",
    use_ctrl = true  -- Uses ctrl hotkey for floating chat
  },

  claude = {
    cmd = "agency claude",
    direction = "float",
    float_opts = {
      border = "curved",
      width = 150,
      height = 50,
    },
    close_on_exit = true,
    start_in_insert = true,
    keymap = "<leader>clark",
    desc = "Claude Agency",
    use_ctrl = true  -- Uses ctrl hotkey for floating chat
  },

  claude_skip = {
    cmd = "agency claude --dangerously-skip-permissions",
    direction = "float",
    float_opts = {
      border = "curved",
      width = 150,
      height = 50,
    },
    close_on_exit = true,
    start_in_insert = true,
    keymap = "<leader>clyde",
    desc = "Claude Agency (skip permissions)",
    use_ctrl = true  -- Uses ctrl hotkey for floating chat
  }
}

-- Multi-buffer terminal configurations
-- These terminals spawn multiple buffers when invoked
-- The 'main' buffer will be shown to the user, others run in background
-- Pressing the keymap again will check for existing buffers and only create missing ones
M.multi_terminals = {
  dev = {
    keymap = "<leader>clod",
    desc = "Start dev terminals",
    buffers = {
      {
        name = "copilot",
        cmd = "npx copilot-api@latest start",
        main = false  -- Runs in background
      },
      {
        name = "ccr",
        cmd = "ccr start",
        main = false  -- Runs in background
      },
      {
        name = "claude",
        cmd = "ccr code",
        main = true  -- This is the main buffer shown to user
      }
    }
  }
}

-- Additional custom keymaps
M.custom_keymaps = {
  {
    mode = "n",
    keymap = "<leader>th",
    desc = "Open terminal in current directory",
    action = function()
      local dir = vim.fn.expand('%:p:h')
      vim.cmd('edit term://' .. dir .. '//' .. vim.o.shell)
    end
  },
  {
    mode = "n",
    keymap = "<leader>tm",
    desc = "Open terminal with profile",
    action = function()
      require('terminal.terminals').start_term("term -- " .. os.date("%Y%m%d-%H%M%S"), ". prof")
    end
  }
}

-- Buffer name prefix for multi-terminal system
M.buffer_prefix = "nvim_term_"

return M
