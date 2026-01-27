-- Terminal management functions
-- Handles creation, toggling, and management of terminal instances

local M = {}

-- Store terminal instances globally
_G.named_terminals = _G.named_terminals or {}

-- Get config
local config = require('terminal.config')

-- Initialize Terminal class (will be set during setup)
local Terminal = nil

-- Set Terminal class reference
function M.set_terminal_class(terminal_class)
  Terminal = terminal_class
end

-- Function to create and run a named terminal with a command
-- mode can be: "background", "current", "split", "vsplit", "tab"
function M.create_named_terminal(name, cmd, mode)
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
function M.toggle_named_terminal(name)
  if _G.named_terminals[name] then
    _G.named_terminals[name]:toggle()
  else
    vim.notify("Terminal '" .. name .. "' does not exist", vim.log.levels.WARN)
  end
end

-- Check if a buffer with given name exists
function M.buffer_exists(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match(vim.pesc(config.buffer_prefix .. name) .. "$") then
        return true, buf
      end
    end
  end
  return false, nil
end

-- Start a terminal in a buffer
function M.start_term(name, cmd)
  local full_name = config.buffer_prefix .. name

  -- Check if buffer with this name already exists
  local exists, buf = M.buffer_exists(name)
  if exists then
    return buf
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

  vim.api.nvim_buf_set_name(0, full_name)

  vim.schedule(function()
    vim.bo.syntax = ''
    vim.wo.signcolumn = 'no'
    vim.wo.spell = false
  end)

  return vim.api.nvim_get_current_buf()
end

-- Start multiple terminals based on multi_terminal config
-- Only creates buffers that don't already exist
function M.start_multi_terminals(multi_config)
  local main_buf = nil
  local created_main = false

  for _, buf_config in ipairs(multi_config.buffers) do
    local exists, buf = M.buffer_exists(buf_config.name)

    if not exists then
      -- Buffer doesn't exist, create it
      local new_buf = M.start_term(buf_config.name, buf_config.cmd)

      if buf_config.main then
        main_buf = new_buf
        created_main = true
      else
        -- Hide background buffers
        vim.cmd('hide')
      end
    else
      -- Buffer exists
      if buf_config.main then
        main_buf = buf
      end
    end
  end

  -- Show the main buffer if we created it, or if user pressed the command again
  if main_buf and created_main then
    vim.api.nvim_set_current_buf(main_buf)
  elseif main_buf then
    -- User pressed command again, just switch to main buffer
    vim.api.nvim_set_current_buf(main_buf)
  end
end

-- Create a custom terminal with environment variables
function M.custom_terminal()
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
    vim.wo.signcolumn = 'no'
    vim.wo.spell = false
  end)
end

return M
