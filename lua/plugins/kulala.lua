return {
  "mistweaverco/kulala.nvim",
  keys = {
    { "<leader>Rs", desc = "Send request" },
    { "<leader>Ra", desc = "Send all requests" },
    { "<leader>Rb", desc = "Open scratchpad" },
    {
      "<leader>Rt",
      function()
      end,
      desc = ""
    },
    {
      "<leader>Re",
      function()
        local function get_envs()
          -- Get the directory of the current buffer
          local current_file = vim.api.nvim_buf_get_name(0)
          local current_dir = vim.fn.fnamemodify(current_file, ':p:h')

          -- Search for http-client.env.json in ancestor directories
          local config_file = vim.fn.findfile('http-client.env.json', current_dir .. ';')

          if config_file == '' then
            return nil, "http-client.env.json not found in ancestor directories"
          end

          -- Read and parse the JSON file
          local file = io.open(config_file, 'r')
          if not file then
            return nil, "Could not open file: " .. config_file
          end

          local content = file:read('*all')
          file:close()

          -- Parse JSON
          local ok, data = pcall(vim.fn.json_decode, content)
          if not ok then
            return nil, "Failed to parse JSON: " .. tostring(data)
          end

          -- Extract top-level keys that don't start with $
          local environments = {}
          for key, _ in pairs(data) do
            if type(key) == 'string' and not key:match('^%$') then
              table.insert(environments, key)
            end
          end
          return environments, nil
        end

        local envs, err = get_envs()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end

        require('fzf-lua').fzf_exec(envs, {
          prompt = 'Select HTTP Client Environment > ',
          actions = {
            ['default'] = function(selected)
              if selected and #selected > 0 then
                -- Do something with the selected environment
                vim.notify("Selected environment: " .. selected[1], vim.log.levels.INFO)
                require('kulala').set_selected_env(selected[1])
              end
            end
          }
        })
      end,
      desc = "Select http environment"
    }
  },
  ft = { "http", "rest" },
  opts = {
    global_keymaps = true,
    global_keymaps_prefix = "<leader>R",
    kulala_keymaps_prefix = "",
  },
}
