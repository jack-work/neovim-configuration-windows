# Terminal Config Refactor Plan

## Goal
Create a declarative, config-driven terminal system where ALL configuration
lives in `term.lua` and the `terminal/` module is a generic library.

## Config Shape (Polymorphic List)
```lua
opts = {
  toggleterm = { ... },  -- base toggleterm opts
  terminals = {
    -- Single-process terminal
    {
      name = "claude",           -- REQUIRED: used as prefix for buffers
      keymap = "<leader>clark",  -- REQUIRED: shortcut to invoke
      cmd = "agency claude",
      singleton = true,          -- reuse instance or create numbered copies
      direction = "float",
      float_opts = { ... },
      use_ctrl = true,           -- adds Ctrl-q to close
    },
    -- Multi-process terminal (has `buffers` field)
    {
      name = "dev",
      keymap = "<leader>clod",
      singleton = false,         -- false = new instance each press
      buffers = {
        { name = "copilot", cmd = "...", main = false, singleton = true },
        { name = "ccr", cmd = "...", main = false, singleton = true },
        { name = "claude", cmd = "...", main = true, singleton = false },
      }
    },
  }
}
```

## Buffer Tracking
- Local collection tracks buffer IDs (not names)
- On keypress: check if buffer exists, recreate if dead, update collection
- Global index counter for numbered instances (name_2, name_3...)
- Only apply number suffix starting from 2nd instance

## Steps

### 1. Write this plan to file
Status: DONE

### 2. YIELD: User approval of plan
Status: DONE (approved)

### 3. Refactor terminal/init.lua
- Remove all hardcoded config
- Accept opts parameter
- Setup toggleterm with opts.toggleterm
Status: DONE

### 4. Refactor terminal/terminals.lua
- Remove config.lua dependency
- Accept config at runtime via setup()
- Implement buffer ID tracking collection
- Implement singleton vs numbered instance logic
- Implement buffer existence check and recreation
Status: DONE

### 5. Delete terminal/config.lua
- All config moves to term.lua
Status: DONE

### 6. YIELD: User approval of library changes
Status: PENDING (current)

### 7. Refactor term.lua (plugin spec)
- Add dependencies = {"akinsho/toggleterm.nvim"}
- Move ALL terminal definitions to opts table
- Use polymorphic list format
- config function passes opts to terminal.setup()
Status: PENDING

### 8. YIELD: User approval of final config
Status: PENDING

### 9. Test and commit
Status: PENDING

## Important Notes (Retain Long-Term)
- lazy.nvim loads everything in plugins/ as specs - modules go elsewhere
- Use opts + config function pattern for setup with extra logic
- Buffer names use format: {name}_{instance_number} (number only for 2+)
- Singleton buffers: recreate if dead, reuse if alive
- Non-singleton: always create new numbered instance
