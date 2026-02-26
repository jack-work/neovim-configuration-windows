-- gym.nvim: fzf-lua integration (gym picker, buffer filter)
local state = require('gym.state')
local buffers = require('gym.buffers')
local switch = require('gym.switch')
local M = {}

--- Open a gym-scoped buffer picker (only shows active gym's buffers).
function M.buffers()
  local s = state.get()
  local gym_bufs = buffers.get_gym_buffers(s.active_gym_id)
  local lookup = {}
  for _, bufnr in ipairs(gym_bufs) do
    lookup[bufnr] = true
  end

  require('fzf-lua').buffers({
    buf_filter = function(bufnr)
      return lookup[bufnr] == true
    end,
  })
end

--- Open a gym picker to browse, switch, delete, and rename gyms.
function M.gym_picker()
  local s = state.get()
  local gyms = state.list_gyms()

  local entries = {}
  local id_map = {} -- display string → gym id

  for _, gym in ipairs(gyms) do
    local marker = (gym.id == s.active_gym_id) and '* ' or '  '
    local buf_count = #buffers.get_gym_buffers(gym.id)
    local tab_count = gym.is_active and vim.fn.tabpagenr('$') or #gym.tabs
    local entry = string.format('%s%s  (%d bufs, %d tabs)  [%s]',
      marker, gym.name, buf_count, tab_count, gym.cwd)
    table.insert(entries, entry)
    id_map[entry] = gym.id
  end

  require('fzf-lua').fzf_exec(entries, {
    prompt = 'Gyms> ',
    actions = {
      ['default'] = function(selected)
        if not selected or #selected == 0 then return end
        local id = id_map[selected[1]]
        if not id then return end
        if id == s.active_gym_id then return end -- already active

        local ok, err = switch.switch(id)
        if not ok then
          vim.notify('gym.nvim: ' .. (err or 'switch failed'), vim.log.levels.ERROR)
        end
      end,
      ['ctrl-x'] = function(selected)
        if not selected or #selected == 0 then return end
        local id = id_map[selected[1]]
        if not id then return end

        local gym = s.gyms[id]
        if not gym then return end

        vim.ui.select({ 'Yes', 'No' }, {
          prompt = 'Delete gym "' .. gym.name .. '" and all its buffers?',
        }, function(choice)
          if choice == 'Yes' then
            buffers.delete_gym_buffers(id)
            local ok, err = state.delete_gym(id)
            if not ok then
              vim.notify('gym.nvim: ' .. (err or 'delete failed'), vim.log.levels.ERROR)
            end
          end
        end)
      end,
      ['ctrl-r'] = function(selected)
        if not selected or #selected == 0 then return end
        local id = id_map[selected[1]]
        if not id then return end

        vim.ui.input({ prompt = 'New name: ' }, function(new_name)
          if new_name and new_name ~= '' then
            state.rename_gym(id, new_name)
          end
        end)
      end,
    },
  })
end

return M
