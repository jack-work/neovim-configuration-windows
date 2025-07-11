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

require('mason').setup()
require("mason-lspconfig").setup({
  ensure_installed = { "powershell_es" }
})

require('lspconfig').powershell_es.setup{
  bundle_path = vim.fn.stdpath "data" .. "/mason/packages/powershell-editor-services",
}
-- require('mason-lspconfig').setup({
--   automatic_installation = true,
-- })
-- require('mason-lspconfig').setup_handlers {
--   -- Default handler (will be called for each installed server that doesn't have
--   -- a dedicated handler)
--   function(server_name)
--     require("lspconfig")[server_name].setup {}
--   end,
--
--   -- You can still customize specific servers
--   ["lua_ls"] = function()
--     require("lspconfig").lua_ls.setup {
--       settings = {
--         Lua = {
--           diagnostics = {
--             globals = { 'vim' }
--           }
--         }
--       }
--     }
--   end,
-- }
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
vim.keymap.set('n', '<leader>ft', function()
  vim.ui.input({ prompt = 'File type: ' }, function(input)
    if input then
      builtin.live_grep({ type_filter = input })
    end
  end)
end, { desc = 'Find files by type' })
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
vim.keymap.set('n', '<C-A-h>', '<C-w>H', { desc = 'Move to left split' })
vim.keymap.set('n', '<C-A-l>', '<C-w>L', { desc = 'Move to right split' })
vim.keymap.set('n', '<C-A-j>', '<C-w>J', { desc = 'Move to down split' })
vim.keymap.set('n', '<C-A-k>', '<C-w>K', { desc = 'Move to up split' })
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
vim.keymap.set('n', 'gl', vim.diagnostic.open_float)
-- Map both normal and visual mode
vim.keymap.set({ 'n', 'v' }, '<leader>.', vim.lsp.buf.code_action)

vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.wrap = false
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})
vim.o.shell = "pwsh.exe"

vim.opt.tabstop = 2      -- Width of tab character
vim.opt.softtabstop = 2  -- Fine tunes amount of whitespace
vim.opt.shiftwidth = 2   -- Width of indentation

vim.opt.expandtab = true -- Convert tabs to spaces
vim.opt.smartcase = true
vim.opt.ignorecase = true
vim.opt.cursorline = true

vim.g.netrw_bufsettings = 'noma nomod nu nowrap ro nobl'
vim.keymap.set('n', '<M-k>', ':resize +2<CR>')
vim.keymap.set('n', '<M-j>', ':resize -2<CR>')
vim.keymap.set('n', '<M-h>', ':vertical resize -2<CR>')
vim.keymap.set('n', '<M-l>', ':vertical resize +2<CR>')

vim.keymap.set('n', '<leader>ev', ':e $MYVIMRC<CR>')
vim.keymap.set('n', '<leader>cd', ':cd %:p:h<CR>', { desc = 'Change to current file directory' })
vim.keymap.set('n', '<leader>c-', ':cd -<CR>', { desc = 'Change to previous directory' })
vim.keymap.set('t', '<esc><esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- copy path to current file
-- :let @+ = expand('%:p')
vim.keymap.set({ 'n', 'v' }, '<leader>yp', ':let @+ = expand(\'%:p\')<CR>', { desc = 'yank current file path to clipboard' })
vim.keymap.set('n', '<leader><leader>', ':noh<CR>', { silent = true, desc = 'Clear search highlighting' })
vim.keymap.set('n', '<leader>dq', ':lua vim.diagnostic.setqflist()<CR>', { desc = 'open diagnostics in a buffer so they can be searched' })

vim.api.nvim_create_user_command('Timestamp', function()
    local timestamp = os.date('[%Y-%m-%d %H:%M:%S]')
    vim.api.nvim_put({timestamp}, '', false, true)
end, {})

vim.keymap.set('n', '<leader>gu', function()
  -- Get current file's relative path
  local relative_path = vim.fn.fnamemodify(vim.fn.expand('%'), ':.')
  -- Convert backslashes to forward slashes
  relative_path = string.gsub(relative_path, "\\", "/")
  -- Get cursor position
  local cursor_line = vim.fn.line('.')
  local cursor_end_line = cursor_line
  -- Build the URL with line highlighting
  local url = "https://msazure.visualstudio.com/OneAgile/_git/PowerApps-Client?path=/" .. relative_path
  url = url .. "&line=" .. cursor_line .. "&lineEnd=" .. cursor_end_line
  url = url .. "&lineStartColumn=1&lineEndColumn=46&lineStyle=plain&_a=contents"
  -- Copy to clipboard
  vim.fn.setreg('+', url)
  print("Azure DevOps URL copied to clipboard: " .. url)
end, {})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
  end,
})

vim.keymap.set({"n","v"}, "<leader>m", "<C-w>|<C-w>_")
vim.keymap.set("i", "<C-S-m>", "<esc><C-w>|<C-w>_i")

