-- gym.nvim: ring buffer operation log
local M = {}

local capacity = 100
local entries = {}
local head = 0 -- next write position (0-indexed internally)
local count = 0

function M.add(msg)
  local timestamp = os.date('%H:%M:%S')
  head = (head % capacity) + 1
  entries[head] = string.format('[%s] %s', timestamp, msg)
  if count < capacity then
    count = count + 1
  end
end

function M.get_all()
  local result = {}
  if count == 0 then return result end

  -- Read oldest to newest
  local start = (count < capacity) and 1 or (head % capacity) + 1
  for i = 0, count - 1 do
    local idx = ((start - 1 + i) % capacity) + 1
    table.insert(result, entries[idx])
  end
  return result
end

function M.clear()
  entries = {}
  head = 0
  count = 0
end

return M
