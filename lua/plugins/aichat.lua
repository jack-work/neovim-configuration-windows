---@diagnostic disable: undefined-field, undefined-global: vim
local state = {
  floating = {
    buf = -1,
    win = -1,
  },
}

local function openwindow(opts)
    -- Calculate window size (60% of editor size)
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.6)

    -- Calculate starting position
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create a new buffer for the terminal
     local buf = nil
     if vim.api.nvim_buf_is_valid(opts.buf) then
       buf = opts.buf
     else
       buf = vim.api.nvim_create_buf(false, true)
       vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
     end

    -- Set up the floating window
    local win_opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded'
    }

    -- Open the window
    local win = vim.api.nvim_open_win(buf, true, win_opts)

    -- Add keybind to close the window
    vim.api.nvim_buf_set_keymap(buf, 't', '<C-q>', [[<C-\><C-n>:q<CR>]], { noremap = true, silent = true })
    return { buf = buf, win = win }
end

local function aichat()
  if not vim.api.nvim_win_is_valid(state.floating.win) then
    state.floating = openwindow { buf = state.floating.buf }
    if vim.bo[state.floating.buf].buftype ~= "terminal" then
      vim.cmd.terminal()
      vim.api.nvim_chan_send(vim.bo[state.floating.buf].channel, "aichat\n\n")
    end
  else
    vim.api.nvim_win_hide(state.floating.win)
  end
end

-- Create the command
vim.api.nvim_create_user_command('Aichat', aichat, {})
-- vim.keymap.set('n', '<leader>ai', ':Aichat<CR>', { noremap = true, silent = true })

return {}
