# gym.nvim — Design Proposal & Requirements

## Overview

**gym.nvim** is a Neovim plugin that implements workspace sessions called "gyms." A gym is an isolated group of tab pages, buffers, and a working directory. Switching gyms swaps the entire visible workspace: the current gym's tabs are serialized and destroyed, and the target gym's tabs are recreated from cache. Buffers are exclusively owned by one gym at a time.

The name "gym" comes from the fact that buff people go to the gym.

---

## Data Model

### Gym State (in-memory only, no persistence for now)

```lua
---@class GymState
---@field gyms table<string, Gym>       -- keyed by gym.id
---@field active_gym_id string           -- currently active gym UUID
---@field buf_to_gym table<number, string> -- bufnr → gym.id ownership map
---@field switch_journal SwitchJournal   -- crash recovery journal
---@field log table                      -- ring buffer of operation log entries

---@class SwitchJournal
---@field phase string           -- "idle" | "saving" | "destroying" | "restoring" | "cleanup"
---@field source_gym_id string?
---@field target_gym_id string?
---@field saved boolean
---@field destroyed boolean
---@field restored boolean

---@class Gym
---@field id string              -- UUID (generated via vim.loop or os.clock-based)
---@field name string            -- display name, defaults to id, renameable
---@field cwd string             -- working directory, captured on switch-away
---@field active_tab_index number -- 1-based index of last focused tab within this gym
---@field tabs GymTab[]          -- serialized tab layouts (only populated when gym is INACTIVE)
---@field is_active boolean      -- true if this gym is currently live (tabs exist in Neovim)

---@class GymTab
---@field layout table           -- result of vim.fn.winlayout() — nested tree of splits
---@field wins GymWindow[]       -- flat list of windows in this tab
---@field active_win_index number -- which window was focused

---@class GymWindow
---@field bufnr number           -- buffer handle
---@field width number           -- window width
---@field height number          -- window height
```

### Key invariants

- Every buffer belongs to exactly one gym (tracked in `buf_to_gym`).
- Exactly one gym is active at any time. The active gym's tabs are real Neovim tab pages. All other gyms' tabs are serialized in memory and have no corresponding Neovim tab pages.
- When a new buffer is opened (via `BufAdd` autocmd), it is automatically assigned to the currently active gym.

---

## Startup Behavior

On `VimEnter` (or plugin load):

1. Generate a UUID for the default gym.
2. Set its `name` to the UUID (user can rename later).
3. Set its `cwd` to `vim.fn.getcwd()`.
4. Mark it as active.
5. Claim all existing buffers (there's typically just one on startup).

No special UI. The user is in a gym from the start; they just don't notice until they create a second one.

---

## Core Operations

### 1. Create Gym — `:GymNew [name]`

- Generate a new UUID.
- Set `cwd` to the current gym's CWD (inherit).
- Set `name` to the provided argument, or to the UUID if none given.
- **Auto-switch to the new gym.** The new gym is created and the user is immediately switched into it. The new gym's `tabs` array starts empty; the first switch into it opens a single empty tab/buffer in its CWD.

### 2. Switch Gym — `:GymSwitch <name|id>`

This is the critical operation. It must feel fast. Steps:

**Phase 1: Save current gym**

1. Capture `vim.fn.getcwd()` → `current_gym.cwd`.
2. Record which tab is active → `current_gym.active_tab_index`.
3. For each Neovim tab page owned by the current gym:
   a. Capture `vim.fn.winlayout(tabnr)` → `tab.layout`.
   b. For each window in the tab, capture: `bufnr`, `width`, `height`.
   c. Record which window was focused → `tab.active_win_index`.
4. Store the serialized tabs in `current_gym.tabs`.
5. Set `current_gym.is_active = false`.

**Phase 2: Destroy current gym's tabs**

6. For each buffer owned by the current gym: `vim.api.nvim_buf_set_option(bufnr, 'buflisted', false)` — this hides them from `:ls` and buffer pickers.
7. Close all tab pages. Since we need to keep at least one tab, create a scratch buffer in a temporary tab first, then close all the gym's tabs, then proceed to restore the target.

**Phase 3: Restore target gym**

8. `vim.cmd('cd ' .. target_gym.cwd)` — change working directory.
9. If `target_gym.tabs` is empty (newly created gym): open a single tab with a new buffer in the gym's CWD.
10. Otherwise, for each serialized tab in `target_gym.tabs`:
    a. `:tabnew`
    b. Recreate the window layout by walking the `layout` tree and issuing `:split` / `:vsplit`.
    c. Assign buffers to windows via `nvim_win_set_buf`.
    d. Attempt to restore window sizes via `nvim_win_set_width` / `nvim_win_set_height`. (Best-effort; Neovim may adjust.)
    e. Set `buflisted = true` on all restored buffers.
11. Navigate to `target_gym.active_tab_index`.
12. Focus the correct window within that tab.
13. Set `target_gym.is_active = true`.
14. Clear `target_gym.tabs` (it's live now, no need for serialized state).
15. Clean up the scratch tab from step 7.

### 3. Delete Gym — `:GymDelete [name|id]`

- Cannot delete the currently active gym (switch away first), OR: switch to another gym, then delete. If it's the only gym, refuse.
- Delete all buffers owned by the gym via `nvim_buf_delete(bufnr, { force = true })`.
- Remove all entries from `buf_to_gym` for this gym.
- Remove the gym from `gyms`.

### 4. Rename Gym — `:GymRename <new_name>`

- Rename the active gym (or accept a gym ID argument).

### 5. Move Buffer — `:GymMoveBuffer <target_gym_name|id>`

- Reassign the current buffer from its current gym to the target gym.
- Update `buf_to_gym`.
- Optionally unlist the buffer immediately if moving out of the active gym.

---

## Layout Serialization Detail

The key question is how to serialize and restore a window layout tree. `vim.fn.winlayout(tabnr)` returns a nested structure like:

```lua
-- Single window:
{"leaf", 1001}

-- Vertical split (side by side):
{"row", {{"leaf", 1001}, {"leaf", 1002}}}

-- Horizontal split (stacked):
{"col", {{"leaf", 1001}, {"leaf", 1002}}}

-- Nested:
{"col", {{"leaf", 1001}, {"row", {{"leaf", 1002}, {"leaf", 1003}}}}}
```

### Serialization (save)

Walk the tree. At each `"leaf"`, record the window ID → look up its buffer, width, height. Replace the window ID with the captured `GymWindow` data.

### Deserialization (restore)

Recursive approach:

```
function restore(node, win_id):
  if node is "leaf":
    set buffer in win_id
    return
  if node is "row":
    for each child after the first:
      vsplit from win_id
    assign children to resulting windows
  if node is "col":
    for each child after the first:
      split from win_id
    assign children to resulting windows
```

This needs care — after splitting, you must track which new window IDs were created. Use `nvim_tabpage_list_wins` after each split, or split and immediately identify the new window.

**Performance note:** For ≤4 tabs with modest splits, this is on the order of 10–20 API calls total. Should be sub-10ms.

---

## Buffer Ownership Tracking

### Automatic assignment

Set up a `BufAdd` autocmd:

```lua
vim.api.nvim_create_autocmd("BufAdd", {
  callback = function(args)
    local bufnr = args.buf
    -- Only track normal buffers, not special ones (term, quickfix, etc.)
    if vim.bo[bufnr].buftype == "" then
      state.buf_to_gym[bufnr] = state.active_gym_id
    end
  end,
})
```

Also handle `BufDelete` / `BufWipeout` to clean up the map.

### Listing buffers for a gym

```lua
function get_gym_buffers(gym_id)
  local bufs = {}
  for bufnr, gid in pairs(state.buf_to_gym) do
    if gid == gym_id and vim.api.nvim_buf_is_valid(bufnr) then
      table.insert(bufs, bufnr)
    end
  end
  return bufs
end
```

---

## Keymaps & Commands

| Mapping / Command         | Action                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------ |
| `:GymNew [name]`          | Create a new gym                                                                     |
| `:GymSwitch <name\|id>`   | Switch to a gym                                                                      |
| `:GymDelete [name\|id]`   | Delete a gym and its buffers                                                         |
| `:GymRename <new_name>`   | Rename the active gym                                                                |
| `:GymMoveBuffer <target>` | Move current buffer to another gym                                                   |
| `:GymList`                | Print gym names/IDs                                                                  |
| `:GymAudit`               | Interactive state repair — scan for all inconsistencies, prompt user to resolve each |
| `:GymLog`                 | Print ring buffer of last ~100 gym operations for debugging                          |
| `<leader>fb`              | fzf-lua buffer picker, **filtered to active gym's buffers only**                     |
| `<leader>gyl`             | fzf-lua gym picker (browse, switch, delete gyms)                                     |

---

## fzf-lua Integration

### `<leader>fb` — Buffer Picker (Gym-Scoped)

Override or wrap the default fzf-lua buffer picker so it only shows buffers where `buf_to_gym[bufnr] == active_gym_id`.

```lua
-- Conceptual:
vim.keymap.set("n", "<leader>fb", function()
  local gym_bufs = get_gym_buffers(state.active_gym_id)
  require("fzf-lua").buffers({
    buf_filter = function(bufnr)
      return vim.tbl_contains(gym_bufs, bufnr)
    end,
  })
end)
```

Check the actual fzf-lua API — it may support `buf_filter` or you may need to use `fzf_exec` with a custom provider.

### `<leader>gyl` — Gym Picker

Custom fzf-lua picker:

```lua
vim.keymap.set("n", "<leader>gyl", function()
  local entries = {}
  for id, gym in pairs(state.gyms) do
    local marker = (id == state.active_gym_id) and "* " or "  "
    local buf_count = #get_gym_buffers(id)
    table.insert(entries, string.format("%s%s (%d bufs) [%s]", marker, gym.name, buf_count, gym.cwd))
  end
  require("fzf-lua").fzf_exec(entries, {
    actions = {
      ["default"] = function(selected) --[[ parse and switch ]] end,
      ["ctrl-x"]  = function(selected) --[[ parse and delete ]] end,
      ["ctrl-r"]  = function(selected) --[[ parse and rename ]] end,
    },
  })
end)
```

---

## Edge Cases & Decisions

| Scenario                                                 | Behavior                                                                                                     |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Last gym cannot be deleted                               | Refuse with error message                                                                                    |
| Buffer opened by Neovim internals (quickfix, help, etc.) | Ignore — only track `buftype == ""`                                                                          |
| Terminal buffers                                         | Decision needed: track them or ignore. Suggest: ignore for now                                               |
| Switching to already-active gym                          | No-op                                                                                                        |
| `:tabnew` in the middle of a gym                         | The new tab is part of the active gym; no special handling needed since we serialize all tabs on switch-away |
| `:bdelete` on a gym-tracked buffer                       | `BufDelete` autocmd cleans up `buf_to_gym`                                                                   |
| User runs `:cd` manually                                 | That's fine — we capture CWD on switch-away regardless of how it was set                                     |
| Window layout restoration imperfect                      | Acceptable. Sizes are best-effort. Buffer assignment is what matters.                                        |

---

## Plugin Structure

```
gym.nvim/
├── lua/
│   └── gym/
│       ├── init.lua          -- setup(), public API, commands, keymaps
│       ├── state.lua         -- GymState management, gym CRUD, switch journal
│       ├── switch.lua        -- save/restore/destroy logic (journaled phases)
│       ├── layout.lua        -- winlayout serialization/deserialization
│       ├── buffers.lua       -- buffer ownership, autocmds, filtering
│       ├── picker.lua        -- fzf-lua integration (gym picker, buffer filter)
│       ├── audit.lua         -- :GymAudit interactive state repair
│       └── log.lua           -- ring buffer operation log, :GymLog
└── plugin/
    └── gym.lua               -- auto-load: require("gym").setup()
```

---

## Error Recovery & Conflict Resolution

### Design Philosophy

**Assume any step can crash.** A Neovim plugin error, a user `:qa!`, an unexpected `BufWipeout`, or a Lua error mid-switch can leave state partially applied. The plugin must:

1. **Never silently lose buffers.** A buffer that exists in Neovim but isn't tracked by any gym is an orphan. Orphans must be surfaced to the user, never garbage-collected automatically.
2. **Never silently corrupt state.** If the plugin detects an inconsistency, it should stop, report it, and ask the user what to do — not guess.
3. **Prompt the user to resolve conflicts.** Use `vim.ui.select` or fzf-lua to present choices. Never auto-resolve ambiguous situations.
4. **Provide a manual cleanup command** that audits the full state and lets the user fix every inconsistency interactively.

### Inconsistency Classes

| Inconsistency                                                                        | How it happens                                                                                 | Detection                                 |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **Orphan buffer**: buffer exists in Neovim but `buf_to_gym` has no entry             | Crash during switch before buffer assignment; manual `:bdelete` partial; BufAdd autocmd failed | Periodic audit or on-demand scan          |
| **Ghost reference**: `buf_to_gym` points to a buffer that no longer exists           | Buffer wiped externally; Neovim closed it during error recovery                                | Check `nvim_buf_is_valid()` on any access |
| **Ghost gym reference**: `buf_to_gym` points to a gym ID that doesn't exist          | Gym deleted but `buf_to_gym` not fully cleaned                                                 | Check gym existence on any access         |
| **Dangling serialized tab**: a serialized `GymTab` references a bufnr that's invalid | Buffer was wiped while gym was inactive                                                        | Validate on restore                       |
| **No active gym**: `active_gym_id` is nil or points to nonexistent gym               | Crash during switch between setting inactive and setting active                                | Check on any operation                    |
| **Multiple active gyms**: two gyms both marked `is_active = true`                    | Crash during switch between deactivation and activation                                        | Startup audit                             |
| **Tab leak**: Neovim tab pages exist that aren't owned by the active gym             | Crash during destroy phase; plugin restored target before cleaning up source                   | Count tabs vs expected                    |
| **Empty active gym**: active gym has no tabs and no buffers                          | All buffers deleted, all tabs closed                                                           | Check after any delete operation          |

### Switch Operation: Crash Safety

The switch is the most dangerous operation. Structure it in numbered phases with a **journal** (a simple Lua table tracking which phase we're in):

```lua
-- Conceptual switch journal
state.switch_journal = {
  phase = "idle",         -- "saving", "destroying", "restoring", "cleanup", "idle"
  source_gym_id = nil,
  target_gym_id = nil,
  saved = false,          -- did we finish serializing source?
  destroyed = false,      -- did we finish closing source tabs?
  restored = false,       -- did we finish creating target tabs?
}
```

On any plugin entry point (command, keymap, autocmd), **check the journal first.** If `phase ~= "idle"`, a previous switch was interrupted. Present the user with recovery options:

```
⚠ gym.nvim: interrupted switch detected (phase: "destroying")
  Source gym: "frontend" | Target gym: "backend"

  [1] Retry: resume the switch from where it failed
  [2] Rollback: attempt to restore the source gym
  [3] Force target: abandon source state, finish switching to target
  [4] Manual cleanup: open the full audit tool
```

### The `:GymAudit` Command

This is the primary manual recovery tool. It scans all state and presents every inconsistency for interactive resolution.

**Step 1: Validate gym state integrity**

- Ensure exactly one gym is marked active
- Ensure `active_gym_id` points to a valid gym
- If violations found → prompt user to pick which gym should be active

**Step 2: Scan for orphan buffers**

```
Found 3 orphan buffers (exist in Neovim but not assigned to any gym):
  [buf 12] ~/project/src/index.ts
  [buf 15] ~/project/README.md
  [buf 18] [No Name]

For each orphan, choose:
  [a] Assign to current gym ("frontend")
  [s] Assign to a specific gym (pick from list)
  [t] Open in new tab in current gym
  [d] Delete buffer (force)
  [i] Ignore (leave untracked — will be asked again next audit)
```

**Step 3: Scan for ghost references**

- Remove `buf_to_gym` entries pointing to invalid buffers (auto-fix, just notify user)
- Remove `buf_to_gym` entries pointing to nonexistent gyms → treat those buffers as orphans (go to Step 2 flow)

**Step 4: Validate serialized tabs of inactive gyms**
For each inactive gym, check every buffer referenced in its serialized `GymTab[]`:

```
Gym "backend" has 2 tabs serialized. Validating...
  Tab 1: buf 5 (valid ✓), buf 8 (INVALID ✗)
  Tab 2: buf 9 (valid ✓)

  Buffer 8 is invalid. Options for Tab 1:
    [r] Remove that window from the layout (collapse split)
    [e] Replace with empty buffer when restored
    [s] Skip — leave as-is, will error on restore (not recommended)
```

**Step 5: Check for leaked tabs**

- Count actual Neovim tab pages
- Compare against what the active gym should own
- If extras exist:

```
Found 2 unexpected tab pages (not tracked by active gym "frontend"):
  Tab 3: contains buf 22 (~/stray/file.rs)
  Tab 5: contains buf 30 ([No Name])

  [a] Absorb into current gym
  [c] Close them (buffers become orphans → handle in next pass)
  [i] Ignore
```

**Step 6: Summary**
Print a final report of all actions taken and remaining issues.

### Per-Operation Error Handling

**Buffer restoration (during switch):**
When restoring a serialized tab and a referenced buffer is invalid:

- Do NOT abort the entire switch.
- Replace that window's buffer with a new empty buffer.
- Log a warning: `"gym.nvim: buffer <N> (<path>) was lost. Replaced with empty buffer in tab <T>."`
- After full switch completes, show a summary of all lost buffers.

**Layout restoration failure:**
If `winlayout` restoration produces the wrong number of windows (split failed, etc.):

- Fall back to a flat layout: open each buffer in its own split (vertical).
- Warn the user: `"gym.nvim: could not restore exact layout for tab <T>. Buffers preserved in flat layout."`

**Tab creation failure:**
If `:tabnew` fails for any reason:

- Try to put remaining buffers into the current tab as splits.
- Warn the user.

**CWD change failure:**
If `vim.cmd('cd ' .. path)` fails (directory deleted, permissions, etc.):

- Warn the user, keep the current CWD.
- Set `gym.cwd` to the current CWD so it doesn't keep failing.

### Defensive Coding Rules for the Implementer

1. **Wrap every Neovim API call** that can fail (`nvim_win_set_buf`, `nvim_buf_delete`, etc.) in `pcall`. Log failures, don't crash.
2. **Validate bufnr before every use.** Call `nvim_buf_is_valid(bufnr)` — never assume a stored bufnr is still good.
3. **Validate gym ID before every use.** Always check `state.gyms[id] ~= nil`.
4. **After the switch completes, run a quick sanity check**: count tabs, count listed buffers, verify they all belong to the active gym. If anything is off, notify (don't auto-fix — just tell the user to run `:GymAudit`).
5. **Never delete a buffer without confirmation** unless the user explicitly asked for it (e.g., `:GymDelete`).
6. **The `BufAdd` autocmd must be resilient.** If `active_gym_id` is somehow nil, assign to a fallback "unassigned" pool and warn.
7. **Log everything.** Maintain a ring buffer of the last ~100 gym operations (switch, create, delete, buffer assign) with timestamps. Accessible via `:GymLog`. This is invaluable for debugging state issues.

### `:GymLog` Command

Print the last N operations from the ring buffer:

```
[12:03:01] switch: "frontend" → "backend" (phase: saving)
[12:03:01] switch: "frontend" → "backend" (phase: destroying)
[12:03:01] switch: "frontend" → "backend" (phase: restoring)
[12:03:01] switch: "frontend" → "backend" (phase: idle) — OK
[12:03:15] buf_assign: buf 24 → gym "backend"
[12:04:02] warn: buf 8 invalid during restore of gym "backend" tab 1
```

---

## Non-Goals (For Now)

- Persistence across Neovim restarts
- Cursor position / view restoration per window
- Sharing buffers across gyms
- Statusline/tabline gym indicator (nice-to-have later)
- Per-gym LSP or treesitter config

---

## Performance Budget

Target: gym switch should complete in **< 50ms** for typical usage (3–4 tabs, 2–3 splits each, ~20 buffers per gym).

The serialization format is plain Lua tables in memory — no disk I/O, no JSON encoding. The bottleneck will be the Neovim API calls for creating/destroying windows, which should be well within budget for small tab counts.

---

## Summary of Decisions

| Question                       | Answer                                                            |
| ------------------------------ | ----------------------------------------------------------------- |
| Tabs per gym                   | Multiple                                                          |
| Buffer ownership               | Exclusive, moveable                                               |
| Hiding mechanism               | Save & destroy (serialize layout, close tabs, recreate on switch) |
| Persistence                    | Later                                                             |
| Orphaned buffers on gym delete | Deleted with force                                                |
| Picker                         | fzf-lua                                                           |
| Default gym on startup         | Yes, UUID-named, treated like any other gym                       |
| What we serialize per window   | bufnr, width, height                                              |
| What we skip for now           | Cursor position, window-local options, fold state                 |
