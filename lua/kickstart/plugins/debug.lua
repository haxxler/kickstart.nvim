-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
}

-- Basic debugging keymaps, feel free to change to your liking!
vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>b', function() require('dap').toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = 'Debug: Set Breakpoint' })
-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
vim.keymap.set('n', '<F7>', function() require('dapui').toggle() end, { desc = 'Debug: See last session result.' })

local dap = require 'dap'
local dapui = require 'dapui'

require('mason-nvim-dap').setup {
  -- Makes a best effort to setup the various debuggers with
  -- reasonable debug configurations
  automatic_installation = true,

  -- You can provide additional configuration to the handlers,
  -- see mason-nvim-dap README for more information
  handlers = {
    -- Python: run the current file with the project's uv .venv interpreter
    python = function(config)
      config.configurations = {
        {
          type = 'python',
          request = 'launch',
          name = 'Python: current file (.venv)',
          program = '${file}',
          console = 'integratedTerminal',
          pythonPath = function()
            local root = vim.fs.root(0, '.venv')
            if root then return root .. (vim.fn.has 'win32' == 1 and '/.venv/Scripts/python.exe' or '/.venv/bin/python') end
            return vim.fn.exepath 'python3'
          end,
        },
      }
      if vim.fn.has 'win32' == 1 then
        -- Windows: a detached adapter gets its own console, so nvim never sees its output.
        config.adapters.options = { detached = false }
      end
      require('mason-nvim-dap').default_setup(config)
    end,
  },

  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = vim.fn.has 'win32' == 1 and { 'python', 'cppdbg' } or { 'python' },
}

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
---@diagnostic disable-next-line: missing-fields
dapui.setup {
  -- Set icons to characters that are more likely to work in every terminal.
  --    Feel free to remove or use ones that you like more! :)
  --    Don't feel like these are good choices.
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  ---@diagnostic disable-next-line: missing-fields
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

-- Change breakpoint icons
-- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
-- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
-- local breakpoint_icons = vim.g.have_nerd_font
--     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
--   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
-- for type, icon in pairs(breakpoint_icons) do
--   local tp = 'Dap' .. type
--   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
--   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
-- end

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
-- keep dap-ui open after the session ends so the console output stays visible; close with <F7>.
-- dap.listeners.before.event_terminated['dapui_config'] = dapui.close
-- dap.listeners.before.event_exited['dapui_config'] = dapui.close

if vim.fn.has 'win32' == 1 then
  -- Windows: scoop gdb has no python, so gdb's native DAP is unavailable
  -- Use Microsoft cpptools, which drives gdb through MI instead.
  dap.adapters.cppdbg = {
    id = 'cppdbg',
    type = 'executable',
    command = vim.fn.stdpath 'data' .. '/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7.exe',
    options = { detached = false },
  }
  dap.configurations.c = {
    {
      name = 'Launch (cppdbg + gdb)',
      type = 'cppdbg',
      request = 'launch',
      program = function() return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file') end,
      cwd = '${workspaceFolder}',
      stopAtEntry = false,
      MIMode = 'gdb',
      miDebuggerPath = vim.fn.expand '~/scoop/apps/gdb/current/bin/gdb.exe',
    },
  }
else
  -- C/C++ gdb 14+ supports DAP natively, so no separate adapter is needed
  dap.adapters.gdb = {
    type = 'executable',
    command = 'gdb',
    args = { '--quiet', '--interpreter=dap' },
  }

  dap.configurations.c = {
    {
      name = 'Launch (gdb)',
      type = 'gdb',
      request = 'launch',
      program = function() return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file') end,
      cwd = '${workspaceFolder}',
      stopAtBeginningOfMainSubprogram = false,
    },
  }
end
dap.configurations.cpp = dap.configurations.c
