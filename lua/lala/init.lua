local M = {}

--- Search ancestor directories for a file.
--- @param filename string
--- @return string|nil absolute path, or nil if not found
local function find_ancestor_file(filename)
  local current_file = vim.api.nvim_buf_get_name(0)
  local dir = vim.fn.fnamemodify(current_file, ':p:h')
  local found = vim.fn.findfile(filename, dir .. ';')
  if found == '' then
    return nil
  end
  return vim.fn.fnamemodify(found, ':p')
end

function M.get_token()
  local script_path = find_ancestor_file('Get-Token.ps1')
  if not script_path then
    vim.notify("Get-Token.ps1 not found in ancestor directories", vim.log.levels.ERROR)
    return
  end

  local script_dir = vim.fn.fnamemodify(script_path, ':p:h')

  -- Create a scratch buffer for output
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Get-Token Output')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'powershell')
  vim.api.nvim_buf_set_option(buf, 'fileformat', 'unix')

  -- Open in a split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Running: pwsh -File " .. script_path,
    "Working Directory: " .. script_dir,
    string.rep("-", 80),
    ""
  })

  local line_count = 4

  local function strip_cr(lines)
    return vim.tbl_map(function(line)
      return line:gsub('\r', '')
    end, lines)
  end

  local function scroll_to_bottom()
    local wins = vim.fn.win_findbuf(buf)
    for _, win in ipairs(wins) do
      vim.api.nvim_win_set_cursor(win, { line_count, 0 })
    end
  end

  vim.fn.jobstart(string.format('pwsh -File "%s"', script_path), {
    cwd = script_dir,
    on_stdout = function(_, data)
      if data then
        local lines = vim.tbl_filter(function(line) return line ~= '' end, strip_cr(data))
        if #lines > 0 then
          vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
          line_count = line_count + #lines
          scroll_to_bottom()
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        local lines = vim.tbl_filter(function(line) return line ~= '' end, strip_cr(data))
        if #lines > 0 then
          local error_lines = vim.tbl_map(function(line) return "[ERROR] " .. line end, lines)
          vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, error_lines)
          line_count = line_count + #error_lines
          scroll_to_bottom()
        end
      end
    end,
    on_exit = function(_, exit_code)
      local status_lines = {
        "",
        string.rep("-", 80),
      }
      if exit_code == 0 then
        table.insert(status_lines, "✓ Process completed successfully (exit code: 0)")
      else
        table.insert(status_lines, "✗ Process failed (exit code: " .. exit_code .. ")")
      end
      vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, status_lines)
      line_count = line_count + #status_lines
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
      scroll_to_bottom()
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })
end

function M.open_env()
  local path = find_ancestor_file('http-client.env.json')
  if not path then
    vim.notify("http-client.env.json not found in ancestor directories", vim.log.levels.ERROR)
    return
  end
  vim.cmd('split ' .. vim.fn.fnameescape(path))
end

return M
