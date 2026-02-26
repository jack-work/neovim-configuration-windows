-- gym.nvim: interactive state repair (:GymAudit)
local state = require('gym.state')
local buffers = require('gym.buffers')
local log = require('gym.log')

local M = {}

--- Step 1: Validate gym state integrity (exactly one active gym).
---@param report string[]
---@param fixes string[]
local function validate_active_gym(report, fixes)
  local s = state.get()

  -- Check active_gym_id
  if not s.active_gym_id then
    table.insert(report, 'FAIL: no active_gym_id set')
  elseif not s.gyms[s.active_gym_id] then
    table.insert(report, 'FAIL: active_gym_id points to nonexistent gym [' .. s.active_gym_id .. ']')
  else
    table.insert(report, 'OK: active_gym_id points to "' .. s.gyms[s.active_gym_id].name .. '"')
  end

  -- Check for multiple active flags
  local active_count = 0
  local active_ids = {}
  for id, gym in pairs(s.gyms) do
    if gym.is_active then
      active_count = active_count + 1
      table.insert(active_ids, id)
    end
  end

  if active_count == 0 then
    table.insert(report, 'FAIL: no gym has is_active = true')
  elseif active_count == 1 then
    table.insert(report, 'OK: exactly one gym is active')
  else
    table.insert(report, 'FAIL: ' .. active_count .. ' gyms are marked active')
    -- Auto-fix: trust active_gym_id, deactivate others
    for _, id in ipairs(active_ids) do
      if id ~= s.active_gym_id then
        s.gyms[id].is_active = false
        table.insert(fixes, 'deactivated gym "' .. s.gyms[id].name .. '" (was incorrectly active)')
      end
    end
  end
end

--- Step 2: Scan for orphan buffers.
---@param report string[]
---@return number[] orphans
local function scan_orphans(report)
  local orphans = buffers.find_orphans()
  if #orphans == 0 then
    table.insert(report, 'OK: no orphan buffers')
  else
    table.insert(report, 'WARN: ' .. #orphans .. ' orphan buffer(s) found')
  end
  return orphans
end

--- Step 3: Clean ghost references.
---@param report string[]
---@param fixes string[]
local function clean_ghosts(report, fixes)
  local cleaned = buffers.clean_ghosts()
  if cleaned > 0 then
    table.insert(report, 'FIXED: removed ' .. cleaned .. ' ghost buf_to_gym entries')
    table.insert(fixes, 'removed ' .. cleaned .. ' ghost references')
  else
    table.insert(report, 'OK: no ghost references')
  end
end

--- Step 4: Validate serialized tabs of inactive gyms.
---@param report string[]
local function validate_serialized_tabs(report)
  local s = state.get()
  for _, gym in pairs(s.gyms) do
    if not gym.is_active and #gym.tabs > 0 then
      local invalid_count = 0
      for _, tab in ipairs(gym.tabs) do
        for _, w in pairs(tab.wins) do
          if w.bufnr and not vim.api.nvim_buf_is_valid(w.bufnr) then
            invalid_count = invalid_count + 1
          end
        end
      end
      if invalid_count > 0 then
        table.insert(report, 'WARN: gym "' .. gym.name .. '" has ' .. invalid_count .. ' invalid buffer ref(s) in serialized tabs')
      else
        table.insert(report, 'OK: gym "' .. gym.name .. '" serialized tabs are valid')
      end
    end
  end
end

--- Step 5: Check for switch journal interruption.
---@param report string[]
local function check_journal(report)
  local j = state.get().switch_journal
  if j.phase == 'idle' then
    table.insert(report, 'OK: switch journal is idle')
  else
    table.insert(report, 'WARN: interrupted switch detected (phase: "' .. j.phase .. '")')
    table.insert(report, '  source: ' .. (j.source_gym_id or 'nil') .. ', target: ' .. (j.target_gym_id or 'nil'))
    table.insert(report, '  saved=' .. tostring(j.saved) .. ' destroyed=' .. tostring(j.destroyed) .. ' restored=' .. tostring(j.restored))
  end
end

--- Run the full interactive audit.
function M.run()
  log.add('audit: starting')
  local report = {}
  local fixes = {}

  table.insert(report, '=== gym.nvim Audit ===')
  table.insert(report, '')

  -- Step 1: Active gym
  table.insert(report, '--- Active Gym ---')
  validate_active_gym(report, fixes)
  table.insert(report, '')

  -- Step 2: Orphans
  table.insert(report, '--- Orphan Buffers ---')
  local orphans = scan_orphans(report)
  table.insert(report, '')

  -- Step 3: Ghosts
  table.insert(report, '--- Ghost References ---')
  clean_ghosts(report, fixes)
  table.insert(report, '')

  -- Step 4: Serialized tabs
  table.insert(report, '--- Serialized Tab Validation ---')
  validate_serialized_tabs(report)
  table.insert(report, '')

  -- Step 5: Journal
  table.insert(report, '--- Switch Journal ---')
  check_journal(report)
  table.insert(report, '')

  -- Summary
  if #fixes > 0 then
    table.insert(report, '--- Auto-fixes Applied ---')
    for _, f in ipairs(fixes) do
      table.insert(report, '  ' .. f)
    end
    table.insert(report, '')
  end

  -- Print report
  print(table.concat(report, '\n'))

  -- Auto-assign orphans to active gym (no interactive prompt)
  if #orphans > 0 then
    local s = state.get()
    for _, bufnr in ipairs(orphans) do
      s.buf_to_gym[bufnr] = s.active_gym_id
    end
    table.insert(fixes, 'assigned ' .. #orphans .. ' orphan(s) to active gym')
  end

  log.add('audit: complete (' .. #fixes .. ' fixes, ' .. #orphans .. ' orphans)')
end

return M
