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

--- Get the bare repo root from anywhere inside a bare repo or its worktrees.
--- Works from bare root itself (not just worktrees).
local function get_bare_root()
  -- First try the worktree detection path
  local bare_root = detect_bare_root()
  if bare_root then return bare_root end

  -- Maybe we're in the bare root itself
  local is_bare = vim.trim(vim.fn.system({ 'git', 'rev-parse', '--is-bare-repository' }))
  if is_bare == 'true' then
    local git_dir = vim.trim(vim.fn.system({ 'git', 'rev-parse', '--path-format=absolute', '--git-dir' }))
    if vim.v.shell_error == 0 then
      return vim.fs.normalize(vim.fn.fnamemodify(git_dir, ':h'))
    end
  end

  return nil
end

--- Parse `git worktree list --porcelain` output into a list of worktree entries.
--- Each entry has { path, branch? }. Bare entries are excluded.
local function list_worktrees()
  local raw = vim.fn.systemlist('git worktree list --porcelain')
  if vim.v.shell_error ~= 0 then return nil end

  local worktrees = {}
  local current = {}
  for _, line in ipairs(raw) do
    local path = line:match('^worktree (.+)')
    if path then
      current = { path = path }
    elseif line == 'bare' then
      current.bare = true
    else
      local branch = line:match('^branch refs/heads/(.+)')
      if branch then
        current.branch = branch
      end
    end
    if line == '' then
      if current.path and not current.bare then
        worktrees[#worktrees + 1] = current
      end
      current = {}
    end
  end
  if current.path and not current.bare then
    worktrees[#worktrees + 1] = current
  end
  return worktrees
end

--- Normalize branch input: strip 'origin/' prefix if present.
---@return string remote_ref  e.g. "origin/foo/bar"
---@return string local_name  e.g. "foo/bar"
---@return string dir_name    e.g. "bar" (last path segment)
local function parse_branch(input)
  local local_name = input:match('^origin/(.+)') or input
  local remote_ref = 'origin/' .. local_name
  local dir_name = local_name:match('.+/(.+)') or local_name
  return remote_ref, local_name, dir_name
end

--- Core worktree creation with fetch-on-failure fallback.
---@param bare_root string
---@param args string[]        args after `git worktree add`
---@param fetch_branch string  branch name to fetch from origin on failure
---@param on_success fun()
local function add_worktree(bare_root, args, fetch_branch, on_success)
  local cmd = { 'git', '-C', bare_root, 'worktree', 'add' }
  vim.list_extend(cmd, args)

  local out = vim.fn.system(cmd)
  if vim.v.shell_error == 0 then
    on_success()
    return
  end

  -- Worktree add failed — try fetching the branch from origin
  vim.fn.system({ 'git', '-C', bare_root, 'fetch', 'origin', fetch_branch })
  if vim.v.shell_error ~= 0 then
    vim.notify(
      'tree-bear: branch not found locally or on origin: ' .. fetch_branch .. '\n' .. vim.trim(out),
      vim.log.levels.ERROR
    )
    return
  end

  local out2 = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('tree-bear: worktree add failed after fetch:\n' .. vim.trim(out2), vim.log.levels.ERROR)
    return
  end

  on_success()
end

--- Pick a worktree via fzf-lua and open lazygit in it.
function M.lazygit_worktree()
  local worktrees = list_worktrees()
  if not worktrees or #worktrees == 0 then
    vim.notify('tree-bear: no worktrees found', vim.log.levels.WARN)
    return
  end

  if #worktrees == 1 then
    Snacks.lazygit({ cwd = worktrees[1].path })
    return
  end

  local entries = {}
  local lookup = {}
  for _, wt in ipairs(worktrees) do
    local name = vim.fn.fnamemodify(wt.path, ':t')
    local display = wt.branch and (name .. ' [' .. wt.branch .. ']') or name
    entries[#entries + 1] = display
    lookup[display] = wt.path
  end

  require('fzf-lua').fzf_exec(entries, {
    prompt = 'Worktree> ',
    actions = {
      ['default'] = function(selected)
        if selected and selected[1] and lookup[selected[1]] then
          Snacks.lazygit({ cwd = lookup[selected[1]] })
        end
      end,
    },
  })
end

--- Create a worktree that tracks a remote branch.
--- Local branch name matches the remote branch name and tracks it as upstream.
function M.track_worktree()
  local bare_root = get_bare_root()
  if not bare_root then
    vim.notify('tree-bear: not inside a bare repo or its worktrees', vim.log.levels.ERROR)
    return
  end

  vim.ui.input({ prompt = 'Track branch: ' }, function(input)
    if not input or input == '' then return end

    local remote_ref, local_name, dir_name = parse_branch(input)
    local wt_path = bare_root .. '/' .. dir_name

    if vim.fn.isdirectory(wt_path) == 1 then
      vim.notify('tree-bear: directory already exists: ' .. dir_name, vim.log.levels.ERROR)
      return
    end

    add_worktree(bare_root, { '--track', '-b', local_name, wt_path, remote_ref }, local_name, function()
      vim.notify('tree-bear: created worktree ' .. dir_name .. ' tracking ' .. remote_ref, vim.log.levels.INFO)
      Snacks.lazygit({ cwd = wt_path })
    end)
  end)
end

--- Create a worktree with a new local branch based on a remote branch.
--- The new branch tracks the remote base branch as its upstream.
function M.new_worktree()
  local bare_root = get_bare_root()
  if not bare_root then
    vim.notify('tree-bear: not inside a bare repo or its worktrees', vim.log.levels.ERROR)
    return
  end

  vim.ui.input({ prompt = 'Base branch: ' }, function(base_input)
    if not base_input or base_input == '' then return end

    local remote_ref, base_local, _ = parse_branch(base_input)

    vim.ui.input({ prompt = 'New branch name: ' }, function(new_branch)
      if not new_branch or new_branch == '' then return end

      local dir_name = new_branch:match('.+/(.+)') or new_branch
      local wt_path = bare_root .. '/' .. dir_name

      if vim.fn.isdirectory(wt_path) == 1 then
        vim.notify('tree-bear: directory already exists: ' .. dir_name, vim.log.levels.ERROR)
        return
      end

      add_worktree(bare_root, { '--track', '-b', new_branch, wt_path, remote_ref }, base_local, function()
        vim.notify('tree-bear: created worktree ' .. dir_name .. ' on branch ' .. new_branch, vim.log.levels.INFO)
        Snacks.lazygit({ cwd = wt_path })
      end)
    end)
  end)
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
