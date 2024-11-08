---@diagnostic disable: undefined-field, undefined-global: vim
-- Bootstrap lazy.nvim
vim.g.mapleader = " ";
vim.g.maplocalleader = " ";

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin setup
require("lazy").setup("plugins")

-- TODO: Figure out why this doesn't work
require('nvterm').setup()

require('mason').setup()
require('mason-lspconfig').setup({
  automatic_installation = true,
})
require('mason-lspconfig').setup_handlers {
  -- Default handler (will be called for each installed server that doesn't have
  -- a dedicated handler)
  function(server_name)
    require("lspconfig")[server_name].setup {}
  end,

  -- You can still customize specific servers
  ["lua_ls"] = function()
    require("lspconfig").lua_ls.setup {
      settings = {
        Lua = {
          diagnostics = {
            globals = { 'vim' }
          }
        }
      }
    }
  end,
}
require('lspconfig').lua_ls.setup {}

require('cmp').setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = {
    ['<C-p>'] = require('cmp').mapping.select_prev_item(),
    ['<C-n>'] = require('cmp').mapping.select_next_item(),
    ['<C-d>'] = require('cmp').mapping.scroll_docs(-4),
    ['<C-f>'] = require('cmp').mapping.scroll_docs(4),
    ['<C-Space>'] = require('cmp').mapping.complete(),
    ['<CR>'] = require('cmp').mapping.confirm({
      behavior = require('cmp').ConfirmBehavior.Replace,
      select = true
    }),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'buffer' },
    { name = 'path' }
  }
})
-- Function to open a file in a bottom split using nvr
local function open_in_bottom_split(file)
  -- Ensure we're in the main Neovim instance
  if vim.env.NVIM_LISTEN_ADDRESS then
    -- We're in a nested Neovim, use nvr
    vim.fn.system(string.format("nvr --remote-send '<C-\\><C-N>:split %s<CR>:wincmd J<CR>'", file))
  else
    -- We're in the main instance, just open the file
    vim.cmd('split ' .. file)
    vim.cmd('wincmd J')
  end
end

-- Create a command to open a file in a bottom split
vim.api.nvim_create_user_command('NvrBottomSplit', function(opts)
  open_in_bottom_split(opts.args)
end, { nargs = 1, complete = 'file' })

local builtin = require('telescope.builtin')
-- Or a more explicit function version
vim.keymap.set('n', '<leader>vsp', function()
    vim.cmd('vsplit ' .. vim.fs.joinpath(vim.fn.expand('%:p:h'), vim.fn.expand('<cfile>')))
end, { noremap = true })
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Recent files' })
vim.keymap.set('n', '<leader>fw', builtin.grep_string, { desc = 'Find word under cursor' })
vim.api.nvim_set_keymap('n', '<Leader>bs', ':NvrBottomSplit ', { noremap = true })

vim.api.nvim_set_keymap('n', '<leader>gs', ':Git<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>gb', ':Git blame<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>gd', ':Gdiff<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>gl', ':Git log<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>rr', ':so $myvimrc<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left split' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right split' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to down split' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to up split' })
vim.keymap.set('n', '<A-h>', '<C-w>H', { desc = 'Move to left split' })
vim.keymap.set('n', '<A-l>', '<C-w>L', { desc = 'Move to right split' })
vim.keymap.set('n', '<A-j>', '<C-w>J', { desc = 'Move to down split' })
vim.keymap.set('n', '<A-k>', '<C-w>K', { desc = 'Move to up split' })
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, {})
vim.keymap.set({ 'n', 'v' }, 'gr', '<cmd>Telescope lsp_references<CR>', { noremap = true })
vim.keymap.set({ 'n', 'v' }, '<leader>fo', vim.lsp.buf.format)
-- fugitive shortcuts

vim.api.nvim_create_user_command('Bless', function()
    local main = vim.fn.system('git rev-parse --abbrev-ref origin/HEAD'):gsub("origin/", ""):gsub("\n", "")
    vim.cmd('Git stash --include-untracked')
    vim.cmd('Git checkout ' .. main)
    vim.cmd('Git pull')
    vim.cmd('Git checkout -')
    vim.cmd('Git rebase ' .. main)
end, {})

-- Optional keymap
vim.keymap.set('n', '<leader>bl', ':Bless<CR>', { silent = true })

-- Go to definition
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
-- Go to declaration
vim.keymap.set('n', 'gD', vim.lsp.buf.declaration)
-- Show hover information
vim.keymap.set('n', 'K', vim.lsp.buf.hover)
-- Go to implementation
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation)
-- Map both normal and visual mode
vim.keymap.set({ 'n', 'v' }, '<leader>.', vim.lsp.buf.code_action)

vim.wo.number = true
vim.wo.relativenumber = true
vim.o.shell = "pwsh.exe"

-- In your init.lua
vim.opt.tabstop = 2     -- Width of tab character
vim.opt.softtabstop = 2 -- Fine tunes amount of whitespace
vim.opt.shiftwidth = 2  -- Width of indentation

vim.opt.expandtab = true -- Convert tabs to spaces
vim.opt.smartcase = true
vim.opt.ignorecase = true

-- Set a distinct background color for inactive windows
-- vim.api.nvim_set_hl(0, 'NormalNC', { bg = '#232323' })

-- Keep active window with regular background
vim.api.nvim_set_hl(0, 'Normal', { bg = '#000000' })

-- Make the window separators more visible
-- vim.opt.winblend = 0
-- vim.opt.winhl = 'Normal:Normal,NormalNC:NormalNC'

-- Set a more visible split separator
-- vim.opt.fillchars = {
--     vert = '│',
--     horiz = '─',
--     horizup = '┴',
--     horizdown = '┬',
--     vertleft = '┤',
--     vertright = '├',
--     verthoriz = '┼',
-- }

-- Make split separators stand out with a distinct color
-- vim.api.nvim_set_hl(0, 'WinSeparator', { fg = '#4444ff', bold = true })

-- Optional: Add a statusline highlight for inactive windows
vim.api.nvim_set_hl(0, 'StatusLineNC', { bg = '#232323', fg = '#888888' })
vim.api.nvim_set_hl(0, 'StatusLine', { bg = '#000000', fg = '#ffffff' })