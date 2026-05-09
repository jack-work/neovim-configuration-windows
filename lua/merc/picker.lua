local M = {}

--- Format a process into an ANSI display line for fzf.
--- Returns "PID\tdisplay" where PID is hidden from fzf via --with-nth.
--- @param p table
--- @return string
local function format_entry(p)
  local fzf_lua = require("fzf-lua")
  local ansi = fzf_lua.utils.ansi_codes

  local mem = ""
  if p.memoryBytes and p.memoryBytes > 0 then
    local mb = math.floor(p.memoryBytes / (1024 * 1024))
    mem = string.format("%d MB", mb)
  end

  local cpu = ""
  if p.cpuTime and p.cpuTime > 0 then
    local sec = p.cpuTime / 1e9
    if sec < 60 then
      cpu = string.format("%.1fs", sec)
    elseif sec < 3600 then
      cpu = string.format("%dm%02ds", math.floor(sec / 60), math.floor(sec) % 60)
    else
      cpu = string.format("%dh%02dm", math.floor(sec / 3600), math.floor(sec / 60) % 60)
    end
  end

  local weight = p.weightClass or ""
  local color_fn = ansi.grey
  if weight == "heavy" then color_fn = ansi.yellow
  elseif weight == "wew lad" then color_fn = ansi.red
  end

  local title = ""
  if p.windows and #p.windows > 0 then
    title = p.windows[1]
    if #title > 60 then title = title:sub(1, 57) .. "..." end
  end

  local display = string.format("%-25s %8s %8s  %s  %s",
    p.name, mem, cpu, color_fn(string.format("%-8s", weight)), title)

  -- PID is the hidden first field used by actions
  return string.format("%d\t%s", p.pid, display)
end

--- Open the merc process picker.
--- @param opts? { stats: boolean, junk: boolean }
function M.pick(opts)
  opts = opts or {}
  local merc = require("merc")
  local fzf_lua = require("fzf-lua")

  local procs = merc.list(opts)

  local entries = {}
  local pid_map = {}
  for _, p in ipairs(procs) do
    table.insert(entries, format_entry(p))
    pid_map[tostring(p.pid)] = p
  end

  fzf_lua.fzf_exec(entries, {
    prompt = "Merc> ",
    fzf_opts = {
      ["--multi"]     = true,
      ["--with-nth"]  = "2..",
      ["--delimiter"] = "\t",
      ["--ansi"]      = true,
      ["--header"]    = "Enter=kill  Ctrl-Y=yank PID  Ctrl-R=refresh",
    },
    actions = {
      ["default"] = function(selected)
        for _, line in ipairs(selected) do
          local pid = tonumber(line:match("^(%d+)\t"))
          if pid then
            local p = pid_map[tostring(pid)]
            local name = p and p.name or tostring(pid)
            vim.notify(string.format("Killing %s (PID %d)", name, pid), vim.log.levels.WARN)
            merc.kill(pid)
          end
        end
      end,

      ["ctrl-y"] = function(selected)
        local pids = {}
        for _, line in ipairs(selected) do
          local pid = line:match("^(%d+)\t")
          if pid then table.insert(pids, pid) end
        end
        vim.fn.setreg("+", table.concat(pids, "\n"))
        vim.notify("Yanked " .. #pids .. " PID(s)", vim.log.levels.INFO)
      end,

      ["ctrl-r"] = function()
        M.pick(opts)
      end,
    },
  })
end

return M
