-- gym.nvim: state management and gym CRUD
local log = require('gym.log')

local M = {}

---@class GymState
local state = {
  gyms = {},           -- table<string, Gym>
  active_gym_id = nil, -- string
  buf_to_gym = {},     -- table<number, string>
  switch_journal = {
    phase = 'idle',
    source_gym_id = nil,
    target_gym_id = nil,
    saved = false,
    destroyed = false,
    restored = false,
  },
}

-- Generate a short UUID (8 hex chars, good enough for session-local IDs)
local function gen_id()
  local id = string.format('%08x', math.random(0, 0xFFFFFFFF))
  return id
end

-- Seed random once
math.randomseed(os.time() + os.clock() * 1000)

--- Get the full state table (for other modules)
function M.get()
  return state
end

--- Create a new gym. Does NOT switch to it.
---@param name? string
---@param cwd? string
---@return table gym the created gym
function M.create_gym(name, cwd)
  local id = gen_id()
  local gym = {
    id = id,
    name = name or id,
    cwd = cwd or vim.fn.getcwd(),
    active_tab_index = 1,
    tabs = {},
    is_active = false,
  }
  state.gyms[id] = gym
  log.add('create: "' .. gym.name .. '" [' .. id .. '] cwd=' .. gym.cwd)
  return gym
end

--- Delete a gym by ID. Does NOT handle buffer cleanup (caller must do that).
---@param id string
---@return boolean ok
---@return string? err
function M.delete_gym(id)
  if not state.gyms[id] then
    return false, 'gym not found: ' .. id
  end
  if id == state.active_gym_id then
    return false, 'cannot delete the active gym (switch away first)'
  end
  local count = 0
  for _ in pairs(state.gyms) do count = count + 1 end
  if count <= 1 then
    return false, 'cannot delete the last gym'
  end

  local name = state.gyms[id].name
  state.gyms[id] = nil
  log.add('delete: "' .. name .. '" [' .. id .. ']')
  return true
end

--- Rename a gym.
---@param id string
---@param new_name string
function M.rename_gym(id, new_name)
  local gym = state.gyms[id]
  if not gym then return end
  local old = gym.name
  gym.name = new_name
  log.add('rename: "' .. old .. '" → "' .. new_name .. '" [' .. id .. ']')
end

--- Find a gym by name or ID.
---@param query string name or id
---@return table? gym
function M.find_gym(query)
  -- Try exact ID match first
  if state.gyms[query] then
    return state.gyms[query]
  end
  -- Try name match
  for _, gym in pairs(state.gyms) do
    if gym.name == query then
      return gym
    end
  end
  return nil
end

--- Get the active gym.
---@return table? gym
function M.get_active_gym()
  if not state.active_gym_id then return nil end
  return state.gyms[state.active_gym_id]
end

--- Set the active gym ID.
---@param id string
function M.set_active(id)
  state.active_gym_id = id
  if state.gyms[id] then
    state.gyms[id].is_active = true
  end
end

--- Get list of all gyms (sorted by name).
---@return table[] gyms
function M.list_gyms()
  local result = {}
  for _, gym in pairs(state.gyms) do
    table.insert(result, gym)
  end
  table.sort(result, function(a, b) return a.name < b.name end)
  return result
end

--- Initialize default gym on startup.
function M.init_default_gym()
  local gym = M.create_gym(nil, vim.fn.getcwd())
  gym.is_active = true
  state.active_gym_id = gym.id
  log.add('init: default gym "' .. gym.name .. '" [' .. gym.id .. ']')
  return gym
end

--- Reset the switch journal to idle.
function M.journal_reset()
  state.switch_journal = {
    phase = 'idle',
    source_gym_id = nil,
    target_gym_id = nil,
    saved = false,
    destroyed = false,
    restored = false,
  }
end

--- Update the switch journal.
---@param updates table partial journal fields to merge
function M.journal_update(updates)
  for k, v in pairs(updates) do
    state.switch_journal[k] = v
  end
end

return M
