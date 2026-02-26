-- tree-bear: source .nvim.lua from bare repo root when inside a worktree
--
-- When CWD is inside a git worktree whose common dir is a bare repo,
-- sources <bare-repo-root>/.nvim.lua with vim.secure.read() (trust prompt).
-- This lets you keep project-local config next to the bare repo without
-- committing it.

local M = {}

-- Track which exrc files have already been sourced to avoid double-execution
-- when CWD changes within the same bare repo (e.g. navigating subdirectories).
local sourced = {}

--- Detect whether CWD is a worktree of a bare repo.
--- Returns the bare repo root (parent of the git common dir), or nil.
local function detect_bare_root()
  local git_dir = vim.trim(vim.fn.system({ 'git', 'rev-parse', '--path-format=absolute', '--git-dir' }))
  if vim.v.shell_error ~= 0 then return nil end

  local common_dir = vim.trim(vim.fn.system({ 'git', 'rev-parse', '--path-format=absolute', '--git-common-dir' }))
  if vim.v.shell_error ~= 0 then return nil end

  -- Normalize paths for comparison (Windows backslash variance)
  git_dir = vim.fs.normalize(git_dir)
  common_dir = vim.fs.normalize(common_dir)

  if git_dir == common_dir then
    return nil -- regular repo, not a worktree
  end

  -- Confirm the common dir is actually a bare repo
  local is_bare = vim.trim(vim.fn.system({ 'git', '-C', common_dir, 'rev-parse', '--is-bare-repository' }))
  if is_bare ~= 'true' then
    return nil -- worktree, but parent isn't bare
  end

  -- The bare repo root is the parent of the git common dir
  -- e.g. ~/dev/orchard/.bare -> ~/dev/orchard/
  return vim.fs.normalize(vim.fn.fnamemodify(common_dir, ':h'))
end

--- Source .nvim.lua from the bare repo root if we haven't already.
---@param force? boolean  re-source even if already loaded
local function try_source(force)
  local bare_root = detect_bare_root()
  if not bare_root then return end

  local exrc_path = bare_root .. '/.nvim.lua'
  if not force and sourced[exrc_path] then return end

  local contents = vim.secure.read(exrc_path)
  if contents then
    local chunk, err = loadstring(contents, exrc_path)
    if chunk then
      sourced[exrc_path] = true
      chunk()
    else
      vim.notify('tree-bear: ' .. err, vim.log.levels.ERROR)
    end
  end
end

function M.setup()
  try_source()

  vim.api.nvim_create_autocmd('DirChanged', {
    group = vim.api.nvim_create_augroup('tree-bear', { clear = true }),
    callback = try_source,
  })

  vim.api.nvim_create_user_command('TreeBearSource', function()
    try_source(true)
  end, { desc = 'Re-source worktree .nvim.lua' })
end

return M
