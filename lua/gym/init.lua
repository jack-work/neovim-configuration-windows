-- gym.nvim: workspace sessions for Neovim
-- Buff people go to the gym.
local state = require('gym.state')
local buffers = require('gym.buffers')
local switch = require('gym.switch')
local picker = require('gym.picker')
local audit = require('gym.audit')
local log = require('gym.log')

local M = {}

function M.setup()
  -- Initialize default gym and claim all existing buffers
  local default_gym = state.init_default_gym()
  local s = state.get()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ok, bt = pcall(vim.api.nvim_get_option_value, 'buftype', { buf = bufnr })
      if ok and bt == '' then
        s.buf_to_gym[bufnr] = default_gym.id
      end
    end
  end

  -- Setup buffer tracking autocmds
  buffers.setup_autocmds()

  -- Register commands
  M._register_commands()

  -- Register keymaps
  M._register_keymaps()

  log.add('setup: gym.nvim initialized')
end

function M._register_commands()
  vim.api.nvim_create_user_command('GymNew', function(opts)
    local name = opts.args ~= '' and opts.args or nil
    local gym = state.create_gym(name)
    -- Auto-switch to the new gym
    local ok, err = switch.switch(gym.id)
    if not ok then
      vim.notify('gym.nvim: created "' .. gym.name .. '" but switch failed: ' .. (err or '?'), vim.log.levels.WARN)
    end
  end, { nargs = '?', desc = 'Create a new gym and switch to it' })

  vim.api.nvim_create_user_command('GymSwitch', function(opts)
    if opts.args == '' then
      vim.notify('gym.nvim: usage: :GymSwitch <name|id>', vim.log.levels.ERROR)
      return
    end
    local ok, err = switch.switch(opts.args)
    if not ok then
      vim.notify('gym.nvim: ' .. (err or 'switch failed'), vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = 'Switch to a gym',
    complete = function()
      local gyms = state.list_gyms()
      local names = {}
      for _, gym in ipairs(gyms) do
        table.insert(names, gym.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('GymDelete', function(opts)
    local query = opts.args
    local s = state.get()

    -- Default to active gym if no arg
    local gym
    if query == '' then
      gym = state.get_active_gym()
    else
      gym = state.find_gym(query)
    end

    if not gym then
      vim.notify('gym.nvim: gym not found', vim.log.levels.ERROR)
      return
    end

    -- If deleting active gym, switch away first
    if gym.id == s.active_gym_id then
      local others = state.list_gyms()
      local target = nil
      for _, g in ipairs(others) do
        if g.id ~= gym.id then
          target = g
          break
        end
      end
      if not target then
        vim.notify('gym.nvim: cannot delete the last gym', vim.log.levels.ERROR)
        return
      end

      vim.ui.select({ 'Yes', 'No' }, {
        prompt = 'Delete active gym "' .. gym.name .. '"? Will switch to "' .. target.name .. '" first.',
      }, function(choice)
        if choice ~= 'Yes' then return end
        local ok, err = switch.switch(target.id)
        if not ok then
          vim.notify('gym.nvim: switch failed: ' .. (err or '?'), vim.log.levels.ERROR)
          return
        end
        buffers.delete_gym_buffers(gym.id)
        state.delete_gym(gym.id)
        vim.notify('gym.nvim: deleted gym "' .. gym.name .. '"', vim.log.levels.INFO)
      end)
    else
      buffers.delete_gym_buffers(gym.id)
      local ok, err = state.delete_gym(gym.id)
      if ok then
        vim.notify('gym.nvim: deleted gym "' .. gym.name .. '"', vim.log.levels.INFO)
      else
        vim.notify('gym.nvim: ' .. (err or 'delete failed'), vim.log.levels.ERROR)
      end
    end
  end, {
    nargs = '?',
    desc = 'Delete a gym and its buffers',
    complete = function()
      local gyms = state.list_gyms()
      local names = {}
      for _, gym in ipairs(gyms) do
        table.insert(names, gym.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('GymRename', function(opts)
    if opts.args == '' then
      vim.notify('gym.nvim: usage: :GymRename <new_name>', vim.log.levels.ERROR)
      return
    end
    local active = state.get_active_gym()
    if not active then return end
    state.rename_gym(active.id, opts.args)
    vim.notify('gym.nvim: renamed to "' .. opts.args .. '"', vim.log.levels.INFO)
  end, { nargs = 1, desc = 'Rename the active gym' })

  vim.api.nvim_create_user_command('GymMoveBuffer', function(opts)
    if opts.args == '' then
      vim.notify('gym.nvim: usage: :GymMoveBuffer <target_gym>', vim.log.levels.ERROR)
      return
    end
    local target = state.find_gym(opts.args)
    if not target then
      vim.notify('gym.nvim: target gym not found: ' .. opts.args, vim.log.levels.ERROR)
      return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local ok, err = buffers.move_buffer(bufnr, target.id)
    if ok then
      vim.notify('gym.nvim: moved buffer to "' .. target.name .. '"', vim.log.levels.INFO)
    else
      vim.notify('gym.nvim: ' .. (err or 'move failed'), vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = 'Move current buffer to another gym',
    complete = function()
      local gyms = state.list_gyms()
      local names = {}
      for _, gym in ipairs(gyms) do
        table.insert(names, gym.name)
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('GymList', function()
    local s = state.get()
    local gyms = state.list_gyms()
    local lines = {}
    for _, gym in ipairs(gyms) do
      local marker = (gym.id == s.active_gym_id) and '* ' or '  '
      local buf_count = #buffers.get_gym_buffers(gym.id)
      local tab_count = gym.is_active and vim.fn.tabpagenr('$') or #gym.tabs
      table.insert(lines, string.format('%s%s  (%d bufs, %d tabs)  cwd=%s  [%s]',
        marker, gym.name, buf_count, tab_count, gym.cwd, gym.id))
    end
    vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
  end, { desc = 'List all gyms' })

  vim.api.nvim_create_user_command('GymAudit', function()
    audit.run()
  end, { desc = 'Interactive state repair' })

  vim.api.nvim_create_user_command('GymLog', function()
    local entries = log.get_all()
    if #entries == 0 then
      print('gym.nvim: log is empty')
      return
    end
    print(table.concat(entries, '\n'))
  end, { desc = 'Show gym operation log' })
end

function M._register_keymaps()
  vim.keymap.set('n', '<leader>fb', function()
    picker.buffers()
  end, { desc = 'Gym-scoped buffer picker' })

  vim.keymap.set('n', '<leader>gyl', function()
    picker.gym_picker()
  end, { desc = 'Gym picker (fzf-lua)' })
end

return M
