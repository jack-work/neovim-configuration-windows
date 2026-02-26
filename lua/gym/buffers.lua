-- gym.nvim: buffer ownership tracking and autocmds
local state = require('gym.state')
local log = require('gym.log')

local M = {}

--- Get all valid buffers owned by a gym.
---@param gym_id string
---@return number[] bufnrs
function M.get_gym_buffers(gym_id)
  local s = state.get()
  local bufs = {}
  for bufnr, gid in pairs(s.buf_to_gym) do
    if gid == gym_id and vim.api.nvim_buf_is_valid(bufnr) then
      table.insert(bufs, bufnr)
    end
  end
  return bufs
end

--- Assign a buffer to the active gym if it's a normal buffer.
---@param bufnr number
function M.assign_buffer(bufnr)
  local s = state.get()
  if s.buf_to_gym[bufnr] then return end -- already tracked

  -- Only track named file buffers (buftype='' and has a file path)
  local ok, bt = pcall(vim.api.nvim_get_option_value, 'buftype', { buf = bufnr })
  if not ok or bt ~= '' then return end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then return end -- skip [No Name] buffers

  if not s.active_gym_id then
    log.add('warn: BufAdd for buf ' .. bufnr .. ' but no active gym')
    return
  end

  s.buf_to_gym[bufnr] = s.active_gym_id
  log.add('buf_assign: buf ' .. bufnr .. ' → gym "' .. (state.get_active_gym() or {}).name .. '"')
end

--- Remove a buffer from tracking.
---@param bufnr number
function M.untrack_buffer(bufnr)
  local s = state.get()
  if s.buf_to_gym[bufnr] then
    s.buf_to_gym[bufnr] = nil
  end
end

--- Move a buffer from its current gym to a target gym.
---@param bufnr number
---@param target_gym_id string
---@return boolean ok
---@return string? err
function M.move_buffer(bufnr, target_gym_id)
  local s = state.get()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, 'buffer ' .. bufnr .. ' is not valid'
  end
  if not s.gyms[target_gym_id] then
    return false, 'target gym not found'
  end

  local source_id = s.buf_to_gym[bufnr]
  s.buf_to_gym[bufnr] = target_gym_id

  local source_name = source_id and s.gyms[source_id] and s.gyms[source_id].name or '?'
  local target_name = s.gyms[target_gym_id].name
  log.add('buf_move: buf ' .. bufnr .. ' "' .. source_name .. '" → "' .. target_name .. '"')

  -- If moving out of the active gym, unlist it
  if source_id == s.active_gym_id then
    pcall(vim.api.nvim_set_option_value, 'buflisted', false, { buf = bufnr })
  end

  return true
end

--- Delete all buffers owned by a gym (for gym deletion).
---@param gym_id string
function M.delete_gym_buffers(gym_id)
  local s = state.get()
  local to_delete = {}
  for bufnr, gid in pairs(s.buf_to_gym) do
    if gid == gym_id then
      table.insert(to_delete, bufnr)
    end
  end

  for _, bufnr in ipairs(to_delete) do
    s.buf_to_gym[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end

  log.add('buf_delete_all: deleted ' .. #to_delete .. ' buffers from gym [' .. gym_id .. ']')
end

--- Set buflisted for all buffers in a gym.
---@param gym_id string
---@param listed boolean
function M.set_listed(gym_id, listed)
  local bufs = M.get_gym_buffers(gym_id)
  for _, bufnr in ipairs(bufs) do
    pcall(vim.api.nvim_set_option_value, 'buflisted', listed, { buf = bufnr })
  end
end

--- Find orphan buffers (exist in Neovim but not tracked by any gym).
---@return number[] orphan_bufnrs
function M.find_orphans()
  local s = state.get()
  local orphans = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ok, bt = pcall(vim.api.nvim_get_option_value, 'buftype', { buf = bufnr })
      local name = vim.api.nvim_buf_get_name(bufnr)
      if ok and bt == '' and name ~= '' and not s.buf_to_gym[bufnr] then
        table.insert(orphans, bufnr)
      end
    end
  end
  return orphans
end

--- Clean ghost references (buf_to_gym entries pointing to invalid buffers or nonexistent gyms).
---@return number cleaned count of removed entries
function M.clean_ghosts()
  local s = state.get()
  local cleaned = 0
  local to_remove = {}
  for bufnr, gym_id in pairs(s.buf_to_gym) do
    if not vim.api.nvim_buf_is_valid(bufnr) or not s.gyms[gym_id] then
      table.insert(to_remove, bufnr)
    end
  end
  for _, bufnr in ipairs(to_remove) do
    s.buf_to_gym[bufnr] = nil
    cleaned = cleaned + 1
  end
  if cleaned > 0 then
    log.add('clean_ghosts: removed ' .. cleaned .. ' stale buf_to_gym entries')
  end
  return cleaned
end

--- Setup autocmds for buffer tracking.
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup('GymBuffers', { clear = true })

  vim.api.nvim_create_autocmd('BufAdd', {
    group = group,
    callback = function(args)
      M.assign_buffer(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    callback = function(args)
      M.untrack_buffer(args.buf)
    end,
  })
end

return M
