return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'mxsdev/nvim-dap-vscode-js'
  },
  config = function()
    -- require("nvim-vscode-js").setup({
    --   -- node_path = "node", -- Path of node executable. Defaults to $NODE_PATH, and then "node"
    --   debugger_path = "(runtimedir)/site/pack/packer/opt/vscode-js-debug", -- Path to vscode-js-debug installation.
    --   -- debugger_cmd = { "extension" }, -- Command to use to launch the debug server. Takes precedence over `node_path` and `debugger_path`.
    --   adapters = { 'chrome', 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost', 'node', 'chrome' }, -- which adapters to register in nvim-dap
    --   -- log_file_path = "(stdpath cache)/dap_vscode_js.log" -- Path for file logging
    --   -- log_file_level = false -- Logging level for output to file. Set to false to disable file logging.
    --   -- log_console_level = vim.log.levels.ERROR -- Logging level for output to console. Set to false to disable console output.
    -- })
    local dap = require("dap")
    -- Python configuration
    dap.adapters.python = {
      type = 'executable',
      command = 'python',
      args = { '-m', 'debugpy.adapter' }
    }

    dap.configurations.python = {
      {
        type = 'python',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        pythonPath = function()
          return '/usr/bin/python'
        end
      }
    }

    -- Set keymaps to control the debugger
    vim.keymap.set('n', '<F5>', require 'dap'.continue)
    vim.keymap.set('n', '<F10>', require 'dap'.step_over)
    vim.keymap.set('n', '<F11>', require 'dap'.step_into)
    vim.keymap.set('n', '<F12>', require 'dap'.step_out)
    vim.keymap.set('n', '<leader>b', require 'dap'.toggle_breakpoint)
    vim.keymap.set('n', '<leader>B', function()
      require 'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))
    end)

  end,
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'theHamsta/nvim-dap-virtual-text'
  }
}
