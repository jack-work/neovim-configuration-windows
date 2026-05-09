local M = {}

--- Run merc and return parsed JSON.
--- @param opts? { stats: boolean, junk: boolean }
--- @return table[]
function M.list(opts)
  opts = opts or {}
  local args = { "merc", "-json" }
  if opts.stats then table.insert(args, "-s") end
  if opts.junk then table.insert(args, "-j") end

  local result = vim.system(args, { text = true }):wait()
  if result.code ~= 0 then
    error("merc failed: " .. (result.stderr or ""))
  end
  return vim.json.decode(result.stdout)
end

--- Kill a process by PID.
--- @param pid number
function M.kill(pid)
  vim.system({ "merc", "-k" }, { stdin = tostring(pid) .. "\n" }):wait()
end

return M
