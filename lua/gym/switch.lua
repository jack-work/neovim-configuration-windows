-- gym.nvim: journaled gym switch operation
local state = require('gym.state')
local layout = require('gym.layout')
local buffers = require('gym.buffers')
local log = require('gym.log')

local M = {}

--- Check if a switch was interrupted and return journal info.
---@return table? journal non-nil if interrupted (phase ~= "idle")
function M.check_interrupted()
  local j = state.get().switch_journal
  if j.phase ~= 'idle' then
    return j
  end
  return nil
end

--- Phase 1: Save the current gym's state.
---@param gym table the active gym
local function save_gym(gym)
  state.journal_update({ phase = 'saving' })
  log.add('switch: saving "' .. gym.name .. '"')

  gym.cwd = vim.fn.getcwd()
  gym.active_tab_index = vim.fn.tabpagenr()

  -- Serialize all tab pages
  gym.tabs = {}
  for tabnr = 1, vim.fn.tabpagenr('$') do
    local tab = layout.serialize_tab(tabnr)
    table.insert(gym.tabs, tab)
  end

  gym.is_active = false
  state.journal_update({ saved = true })
  log.add('switch: saved "' .. gym.name .. '" (' .. #gym.tabs .. ' tabs)')
end

--- Phase 2: Destroy the current gym's visual presence.
---@param gym table the gym being switched away from
local function destroy_gym_tabs(gym)
  state.journal_update({ phase = 'destroying' })
  log.add('switch: destroying tabs for "' .. gym.name .. '"')

  -- Protect buffers from being wiped when their windows close.
  -- Default bufhidden='' unloads unlisted buffers on window close,
  -- which wipes empty/unnamed ones. Force 'hide' to keep them alive.
  local gym_bufs = buffers.get_gym_buffers(gym.id)
  for _, bufnr in ipairs(gym_bufs) do
    pcall(vim.api.nvim_set_option_value, 'bufhidden', 'hide', { buf = bufnr })
  end

  -- Unlist all buffers owned by this gym
  buffers.set_listed(gym.id, false)

  -- Reuse tab 1's window (keeps window IDs like 1000 alive so other
  -- plugins that cache window refs don't break on WinResized).
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = scratch })

  vim.cmd('1tabn')           -- go to first tab
  vim.cmd('only')            -- collapse to one window (keeps its ID)
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), scratch)

  -- Close all other tabs
  while vim.fn.tabpagenr('$') > 1 do
    vim.cmd('2tabclose!')
  end

  state.journal_update({ destroyed = true })
  log.add('switch: destroyed tabs for "' .. gym.name .. '"')
end

--- Phase 3: Restore the target gym.
---@param gym table the gym being switched to
---@return string[] warnings
local function restore_gym(gym)
  state.journal_update({ phase = 'restoring' })
  log.add('switch: restoring "' .. gym.name .. '"')

  local all_warnings = {}

  -- Change working directory
  local cd_ok, cd_err = pcall(vim.cmd, 'cd ' .. vim.fn.fnameescape(gym.cwd))
  if not cd_ok then
    local msg = 'could not cd to ' .. gym.cwd .. ': ' .. tostring(cd_err)
    table.insert(all_warnings, msg)
    log.add('warn: ' .. msg)
    gym.cwd = vim.fn.getcwd()
  end

  if #gym.tabs == 0 then
    -- New gym with no tabs: just open a fresh buffer in the current (scratch) tab
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
    -- Track this buffer
    local s = state.get()
    s.buf_to_gym[buf] = gym.id
    log.add('switch: new gym "' .. gym.name .. '" — opened empty buffer')
  else
    -- Restore each serialized tab
    for i, tab in ipairs(gym.tabs) do
      if i == 1 then
        -- Reuse the existing scratch tab for the first tab
        -- Close any extra windows first
        vim.cmd('only')
      else
        vim.cmd('tabnew')
      end

      local ok, warnings = layout.restore_tab(tab)
      for _, w in ipairs(warnings) do
        table.insert(all_warnings, 'tab ' .. i .. ': ' .. w)
      end
    end

    -- Navigate to the correct tab
    if gym.active_tab_index and gym.active_tab_index <= vim.fn.tabpagenr('$') then
      vim.cmd('tabn ' .. gym.active_tab_index)
    end
  end

  -- Re-list all buffers and reset bufhidden to default
  local gym_bufs = buffers.get_gym_buffers(gym.id)
  for _, bufnr in ipairs(gym_bufs) do
    pcall(vim.api.nvim_set_option_value, 'buflisted', true, { buf = bufnr })
    pcall(vim.api.nvim_set_option_value, 'bufhidden', '', { buf = bufnr })
  end

  -- Activate
  gym.is_active = true
  gym.tabs = {} -- live now, no serialized state needed
  state.set_active(gym.id)

  state.journal_update({ restored = true })
  log.add('switch: restored "' .. gym.name .. '"')

  return all_warnings
end

--- Run a post-switch sanity check.
---@return string[] issues
function M.sanity_check()
  local issues = {}
  local s = state.get()

  -- Check active gym exists
  if not s.active_gym_id or not s.gyms[s.active_gym_id] then
    table.insert(issues, 'no valid active gym after switch')
  end

  -- Check all listed buffers belong to the active gym
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ok, listed = pcall(vim.api.nvim_get_option_value, 'buflisted', { buf = bufnr })
      if ok and listed then
        local ok2, bt = pcall(vim.api.nvim_get_option_value, 'buftype', { buf = bufnr })
        local bname = vim.api.nvim_buf_get_name(bufnr)
        if ok2 and bt == '' and bname ~= '' and s.buf_to_gym[bufnr] ~= s.active_gym_id then
          table.insert(issues, 'buf ' .. bufnr .. ' is listed but not owned by active gym')
        end
      end
    end
  end

  return issues
end

--- Execute a full gym switch.
---@param target_query string gym name or ID
---@return boolean ok
---@return string? err
function M.switch(target_query)
  local s = state.get()

  -- Check for interrupted switch
  local interrupted = M.check_interrupted()
  if interrupted then
    return false, 'interrupted switch detected (phase: "' .. interrupted.phase .. '"). Run :GymAudit to recover.'
  end

  -- Find target gym
  local target = state.find_gym(target_query)
  if not target then
    return false, 'gym not found: ' .. target_query
  end

  -- No-op if switching to self
  if target.id == s.active_gym_id then
    return true
  end

  local source = state.get_active_gym()
  if not source then
    return false, 'no active gym to switch from'
  end

  -- Initialize journal
  state.journal_update({
    phase = 'saving',
    source_gym_id = source.id,
    target_gym_id = target.id,
    saved = false,
    destroyed = false,
    restored = false,
  })

  log.add('switch: "' .. source.name .. '" → "' .. target.name .. '"')

  -- Close any dashboard buffers (they cache window IDs in WinResized
  -- handlers that break when windows are destroyed during switch)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ok_ft, ft = pcall(vim.api.nvim_get_option_value, 'filetype', { buf = bufnr })
      if ok_ft and ft == 'snacks_dashboard' then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
    end
  end

  -- Phase 1: Save (reads state only, safe with autocmds)
  save_gym(source)

  -- Phase 2: Destroy
  destroy_gym_tabs(source)

  -- Phase 3: Restore
  local warnings = restore_gym(target)

  -- Cleanup: reset journal
  state.journal_reset()
  log.add('switch: "' .. source.name .. '" → "' .. target.name .. '" — complete')

  -- Sanity check
  local issues = M.sanity_check()
  if #issues > 0 then
    for _, issue in ipairs(issues) do
      log.add('sanity: ' .. issue)
    end
    vim.notify('gym.nvim: post-switch issues detected. Run :GymAudit', vim.log.levels.WARN)
  end

  if #warnings > 0 then
    for _, w in ipairs(warnings) do
      vim.notify('gym.nvim: ' .. w, vim.log.levels.WARN)
    end
  end

  return true
end

return M
