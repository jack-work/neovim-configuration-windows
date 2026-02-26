-- gym.nvim: window layout serialization and deserialization
local log = require('gym.log')

local M = {}

--- Serialize a single tab's layout.
--- Walks the winlayout tree and captures buffer/size info at each leaf.
---@param tabnr number 1-based tab number
---@return GymTab
function M.serialize_tab(tabnr)
  local layout = vim.fn.winlayout(tabnr)
  local wins = {}
  local active_win = vim.api.nvim_get_current_win()
  local active_win_index = nil

  -- Walk the layout tree, replacing window IDs with serialized data
  local win_index = 0
  local function walk(node)
    local kind = node[1]
    if kind == 'leaf' then
      local win_id = node[2]
      win_index = win_index + 1

      local bufnr = vim.api.nvim_win_get_buf(win_id)
      local width = vim.api.nvim_win_get_width(win_id)
      local height = vim.api.nvim_win_get_height(win_id)

      wins[win_index] = {
        bufnr = bufnr,
        width = width,
        height = height,
      }

      if win_id == active_win then
        active_win_index = win_index
      end

      -- Replace win_id with index for deserialization
      node[2] = win_index
    else
      -- 'row' or 'col'
      for _, child in ipairs(node[2]) do
        walk(child)
      end
    end
  end

  walk(layout)

  return {
    layout = layout,
    wins = wins,
    active_win_index = active_win_index or 1,
  }
end

--- Restore a serialized tab's layout into the current tab.
--- The current tab should have a single window to start.
---@param tab GymTab
---@return boolean ok
---@return string[] warnings
function M.restore_tab(tab)
  local warnings = {}
  local layout = tab.layout
  local wins = tab.wins

  -- Build a mapping from win_index → actual window ID
  local win_map = {}
  local current_win = vim.api.nvim_get_current_win()

  local function restore_node(node, target_win)
    local kind = node[1]

    if kind == 'leaf' then
      local win_index = node[2]
      win_map[win_index] = target_win

      local w = wins[win_index]
      if not w then return end

      -- Set the buffer
      if w.bufnr and vim.api.nvim_buf_is_valid(w.bufnr) then
        local ok, err = pcall(vim.api.nvim_win_set_buf, target_win, w.bufnr)
        if not ok then
          table.insert(warnings, 'failed to set buf ' .. w.bufnr .. ' in win: ' .. tostring(err))
        end
      else
        -- Buffer is gone — create an empty replacement
        local new_buf = vim.api.nvim_create_buf(true, false)
        pcall(vim.api.nvim_win_set_buf, target_win, new_buf)
        if w.bufnr then
          local msg = 'buf ' .. w.bufnr .. ' was lost, replaced with empty buffer'
          table.insert(warnings, msg)
          log.add('warn: ' .. msg)
        end
      end

    elseif kind == 'row' or kind == 'col' then
      local children = node[2]
      if #children == 0 then return end

      -- First child uses the target window
      restore_node(children[1], target_win)

      -- Remaining children: split from target window
      for i = 2, #children do
        vim.api.nvim_set_current_win(target_win)
        local split_cmd = (kind == 'row') and 'vsplit' or 'split'
        vim.cmd('belowright ' .. split_cmd)
        local new_win = vim.api.nvim_get_current_win()
        restore_node(children[i], new_win)
      end
    end
  end

  local ok_outer, err_outer = pcall(restore_node, layout, current_win)
  if not ok_outer then
    table.insert(warnings, 'layout restore failed: ' .. tostring(err_outer))
    log.add('error: layout restore failed: ' .. tostring(err_outer))
    -- Fallback: open each buffer in a vertical split
    M._fallback_flat(wins, warnings)
    return false, warnings
  end

  -- Best-effort size restoration (do it after all splits so Neovim has allocated space)
  for win_index, w in pairs(wins) do
    local win_id = win_map[win_index]
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      pcall(vim.api.nvim_win_set_width, win_id, w.width)
      pcall(vim.api.nvim_win_set_height, win_id, w.height)
    end
  end

  -- Focus the correct window
  local focus_win = win_map[tab.active_win_index]
  if focus_win and vim.api.nvim_win_is_valid(focus_win) then
    pcall(vim.api.nvim_set_current_win, focus_win)
  end

  return true, warnings
end

--- Fallback: open all buffers in a flat vertical layout.
---@param wins table<number, GymWindow>
---@param warnings string[]
function M._fallback_flat(wins, warnings)
  local first = true
  for _, w in pairs(wins) do
    if w.bufnr and vim.api.nvim_buf_is_valid(w.bufnr) then
      if first then
        pcall(vim.api.nvim_win_set_buf, vim.api.nvim_get_current_win(), w.bufnr)
        first = false
      else
        vim.cmd('vsplit')
        pcall(vim.api.nvim_win_set_buf, vim.api.nvim_get_current_win(), w.bufnr)
      end
    end
  end
  table.insert(warnings, 'fell back to flat layout')
  log.add('warn: fell back to flat layout')
end

return M
