local M = {}

---@diagnostic disable: undefined-global
M.setup = function()
  -- Add both drives to the path
  vim.opt.path:append("C:\\**")
  vim.opt.path:append("D:\\**")
  -- Handle Windows paths with drive letters
  vim.opt.includeexpr = "v:lua.require'plugins/drive_paths'.expand_path(v:fname)"
end

M.expand_path = function(fname)
  -- First check if it's already a valid path
  if vim.fn.filereadable(fname) == 1 then
    return fname
  end

  -- Split on possible line number
  local file_path, line_num = fname:match("([^:]+):?(%d*)")

  -- If path doesn't start with a drive letter, try both C: and D:
  if not file_path:match("^[A-Za-z]:") then
    -- Try C: drive first
    local c_path = "C:\\" .. file_path:gsub("/", "\\")
    if vim.fn.filereadable(c_path) == 1 then
      return line_num and (c_path .. ":" .. line_num) or c_path
    end
    -- Try D: drive
    local d_path = "D:\\" .. file_path:gsub("/", "\\")
    if vim.fn.filereadable(d_path) == 1 then
      return line_num and (d_path .. ":" .. line_num) or d_path
    end
  end

  -- Return original if no matches found
  return fname
end

return M

