-- Terminal plugin initialization
-- Sets up terminals, keymaps, and commands based on declarative config

local M = {}

function M.setup()
  local config = require('terminal.config')
  local terminals = require('terminal.terminals')

  -- Load toggleterm
  local status, toggleterm = pcall(require, 'toggleterm')
  if not status then
    vim.notify("toggleterm not found", vim.log.levels.ERROR)
    return
  end

  -- Configure shell (Windows/PowerShell)
  vim.cmd("let &shell = " .. config.shell_config.shell)
  vim.cmd("let &shellcmdflag = '" .. config.shell_config.shellcmdflag .. "'")
  vim.cmd("let &shellredir = '" .. config.shell_config.shellredir .. "'")
  vim.cmd("let &shellpipe = '" .. config.shell_config.shellpipe .. "'")
  vim.cmd("set shellquote=" .. config.shell_config.shellquote .. " shellxquote=" .. config.shell_config.shellxquote)

  -- Setup toggleterm with base config
  toggleterm.setup(config.toggleterm_opts)

  -- Get Terminal class and set it in terminals module
  local Terminal = require('toggleterm.terminal').Terminal
  terminals.set_terminal_class(Terminal)

  -- Create terminal instances from config
  local terminal_instances = {}

  for name, term_config in pairs(config.terminals) do
    local term_opts = {
      cmd = term_config.cmd,
      direction = term_config.direction,
      close_on_exit = term_config.close_on_exit,
      start_in_insert = term_config.start_in_insert,
    }

    -- Add float_opts if specified
    if term_config.float_opts then
      term_opts.float_opts = term_config.float_opts
    end

    -- Add ctrl hotkey support for floating chat windows
    if term_config.use_ctrl then
      -- The ctrl hotkey signals that this should behave like a floating chat window
      -- Add Ctrl-q to close the terminal (like aichat)
      term_opts.on_open = function(term)
        local opts = { buffer = term.bufnr, noremap = true, silent = true }
        -- Ctrl-q in terminal mode closes the window
        vim.keymap.set('t', '<C-q>', [[<C-\><C-n>:q<CR>]], opts)
      end
    end

    terminal_instances[name] = Terminal:new(term_opts)
  end

  -- Create toggle functions and keymaps for each terminal
  for name, term_config in pairs(config.terminals) do
    if term_config.keymap then
      local toggle_func = function()
        terminal_instances[name]:toggle()
      end

      -- Store globally with descriptive name
      _G['_TOGGLE_' .. name:upper()] = toggle_func

      -- Create keymap
      vim.keymap.set("n", term_config.keymap, toggle_func, {
        desc = term_config.desc or ("Toggle " .. name)
      })
    end
  end

  -- Setup multi-terminal keymaps
  for name, multi_config in pairs(config.multi_terminals) do
    if multi_config.keymap then
      vim.keymap.set("n", multi_config.keymap, function()
        terminals.start_multi_terminals(multi_config)
      end, {
        desc = multi_config.desc or ("Start " .. name .. " terminals")
      })
    end
  end

  -- Setup custom keymaps
  for _, keymap_config in ipairs(config.custom_keymaps) do
    vim.keymap.set(
      keymap_config.mode,
      keymap_config.keymap,
      keymap_config.action,
      { desc = keymap_config.desc }
    )
  end

  -- Override the :terminal command
  vim.api.nvim_create_user_command('Terminal', terminals.custom_terminal, {
    nargs = 0,
    force = true
  })

  -- Create abbreviation to intercept :terminal
  vim.cmd('cabbrev terminal Terminal')
  vim.cmd('cabbrev term Terminal')

  -- Expose terminals module globally for backward compatibility
  _G.create_named_terminal = terminals.create_named_terminal
  _G.toggle_named_terminal = terminals.toggle_named_terminal
  _G.start_term = terminals.start_term
end

return M
