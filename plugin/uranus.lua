--- Uranus plugin initialization
---
--- This file handles the plugin initialization and lazy loading
--- for Uranus.nvim. It ensures proper setup and version checking.
---
--- @module plugin.uranus
--- @license MIT

local M = {
  name = "uranus.nvim",
  version = "0.1.0",
  description = "Jupyter kernel integration for Neovim",
}

--- Download prebuilt binary from GitHub releases
function M._download_prebuilt()
  local os = vim.loop.os_uname().sysname
  local arch = vim.loop.os_uname().machine

  local ext = (os == "Darwin" and "dylib" or "so")

  -- Find plugin directory (works with lazy.nvim, packer, etc.)
  local plugin_root = vim.fn.stdpath("config") .. "/plugins/uranus-core.nvim"
  if vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/uranus-core.nvim") == 1 then
    plugin_root = vim.fn.stdpath("data") .. "/lazy/uranus-core.nvim"
  elseif vim.fn.isdirectory(vim.fn.stdpath("data") .. "/site/pack/vendor/start/uranus-core.nvim") == 1 then
    plugin_root = vim.fn.stdpath("data") .. "/site/pack/vendor/start/uranus-core.nvim"
  end

  local dest_path = plugin_root .. "/lua/uranus.so"

  if vim.fn.filereadable(dest_path) == 1 then
    return true
  end

  local platform
  if os == "Darwin" then
    platform = (arch == "arm64" and "macos-arm64" or "macos-x64")
  else
    platform = "linux-x64"
  end

  local url = string.format(
    "https://github.com/yourname/uranus-core.nvim/releases/latest/download/%s-uranus.so",
    platform
  )

  vim.notify("Downloading Uranus prebuilt binary...", vim.log.levels.INFO)

  local cmd = string.format(
    "curl -L -o '%s' '%s' 2>&1",
    dest_path, url
  )

  local handle = io.popen(cmd)
  if not handle then
    return false
  end

  local output = handle:read("*a")
  local success = handle:close()

  if success then
    os.execute("chmod +x " .. dest_path)
    vim.notify("Uranus prebuilt downloaded!", vim.log.levels.INFO)
    return true
  else
    vim.notify("Download failed: " .. output, vim.log.levels.ERROR)
    return false
  end
end

--- Check if backend binary exists, try to download if not
function M._ensure_backend()
  -- Find plugin directory
  local plugin_root = vim.fn.stdpath("config") .. "/plugins/uranus-core.nvim"
  if vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/uranus-core.nvim") == 1 then
    plugin_root = vim.fn.stdpath("data") .. "/lazy/uranus-core.nvim"
  elseif vim.fn.isdirectory(vim.fn.stdpath("data") .. "/site/pack/vendor/start/uranus-core.nvim") == 1 then
    plugin_root = vim.fn.stdpath("data") .. "/site/pack/vendor/start/uranus-core.nvim"
  end

  local so_path = plugin_root .. "/lua/uranus.so"

  if vim.fn.filereadable(so_path) ~= 1 then
    return M._download_prebuilt()
  end

  return true
end

-- Early version check to prevent loading on incompatible Neovim versions
if vim.version().minor < 11 or (vim.version().minor == 11 and vim.version().patch < 0) then
  vim.notify_once(
    "Uranus requires Neovim 0.11.0+. Current version: " .. vim.version().major .. "." ..
    vim.version().minor .. "." .. vim.version().patch,
    vim.log.levels.ERROR
  )
  return
end

-- Enable modern loader for better performance (Neovim 0.11+)
if vim.loader then
  vim.loader.enable()
end

--- Check for Jupyter and optionally install
function M._check_jupyter()
  local handle = io.popen("python3 -c 'import jupyter_client; print(jupyter_client.__version__)' 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result and result:match("^%d+") then
      return true
    end
  end

  local handle2 = io.popen("python -c 'import jupyter_client; print(jupyter_client.__version__)' 2>/dev/null")
  if handle2 then
    local result = handle2:read("*a")
    handle2:close()
    if result and result:match("^%d+") then
      return true
    end
  end

  return false
end

function M._install_jupyter()
  local notify = vim.notify or print

  local jupyter_installer = require("jupyter_installer")

  if jupyter_installer.check_jupyter() then
    notify("Jupyter is already installed!", vim.log.levels.INFO)
    return true
  end

  jupyter_installer.show_install_dialog(function(ok, result)
    if ok then
      vim.defer_fn(function()
        if M._check_jupyter() then
          notify("Jupyter installation verified!", vim.log.levels.INFO)
        end
      end, 1000)
    end
  end)

  return false
end

function M._ensure_jupyter()
  if M._check_jupyter() then
    return true
  end

  local should_install = vim.env.URANUS_AUTO_INSTALL_JUPYTER
  if should_install == "0" then
    return false
  end

  vim.ui.select({"Yes", "No"}, {
    prompt = "Jupyter not found. Install now? (Set URANUS_AUTO_INSTALL_JUPYTER=0 to disable)",
    default = 1,
  }, function(choice)
    if choice == "Yes" then
      M._install_jupyter()
    end
  end)

  return false
end

--- Lazy initialization function
--- Called when the plugin should be fully loaded
function M._lazy_init()
  -- Ensure backend binary exists (download if needed)
  if not M._ensure_backend() then
    vim.notify("Uranus: Failed to get backend binary. Build from source or check network.", vim.log.levels.ERROR)
    return
  end

  -- Check for Jupyter and optionally install
  if not M._check_jupyter() then
    M._ensure_jupyter()
  end
  if _G.uranus_initialized then
    return
  end

  -- Check if vim functions are available
  if not vim or not vim.api or not vim.notify then
    print("Uranus: Vim functions not available during initialization")
    return
  end

  -- Load the main module
  local ok, uranus = pcall(require, "uranus")
  if not ok then
    vim.notify("Failed to load Uranus: " .. tostring(uranus), vim.log.levels.ERROR)
    return
  end

  -- Auto-start backend if not configured
  if not _G.uranus_configured then
    local start_result = uranus.start_backend()
    if not start_result.success then
      vim.notify("Failed to start Uranus backend: " .. tostring(start_result.error and start_result.error.message or "Unknown error"), vim.log.levels.ERROR)
      return
    end
    vim.notify("Uranus loaded with default configuration", vim.log.levels.INFO)
  end

  _G.uranus_initialized = true
end

--- Setup function for manual configuration
--- This is called when user configures Uranus in their init.lua
---@param opts? UranusConfig User configuration
---@return UranusResult
function M.setup(opts)
  -- Mark as configured to prevent auto-setup
  _G.uranus_configured = true

  -- Load the main module
  local ok, uranus = pcall(require, "uranus")
  if not ok then
    return {
      success = false,
      error = {
        code = "LOAD_FAILED",
        message = "Failed to load Uranus: " .. uranus,
      }
    }
  end

  -- Start backend
  return uranus.start_backend()
end

-- Export setup function for lazy.nvim and manual setup
_G.Uranus = M

-- Set up lazy loading with VeryLazy event
-- This ensures the plugin loads after most other plugins
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    -- Check if vim functions are available before initializing
    if vim and vim.api and vim.notify then
      M._lazy_init()
    else
      vim.defer_fn(function()
        if vim and vim.api and vim.notify then
          M._lazy_init()
        else
          print("Uranus: Vim functions not available, skipping initialization")
        end
      end, 100)
    end
  end,
  once = true,
})

-- Create user commands
vim.api.nvim_create_user_command("UranusStart", function()
  M._lazy_init()
  local uranus = require("uranus")
  local result = uranus.start_backend()
  if result.success then
    vim.notify("Uranus backend started", vim.log.levels.INFO)
  else
    vim.notify("Failed to start Uranus backend: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Start the Uranus backend",
})

vim.api.nvim_create_user_command("UranusStop", function()
  local uranus = require("uranus")
  local result = uranus.stop_backend()
  if result.success then
    vim.notify("Uranus backend stopped", vim.log.levels.INFO)
  else
    vim.notify("Failed to stop Uranus backend: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Stop the Uranus backend",
})

vim.api.nvim_create_user_command("UranusStatus", function()
  local uranus = require("uranus")
  local status = uranus.status()

  local lines = {
    "Uranus Status:",
    "  Version: " .. status.version,
    "  Backend: " .. (status.backend_running and "Running" or "Stopped"),
    "  Kernel: " .. (status.current_kernel and status.current_kernel.name or "None"),
    "  Config: " .. (status.config_valid and "Valid" or "Invalid"),
  }

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, {
  desc = "Show Uranus status",
})

vim.api.nvim_create_user_command("UranusConnect", function(opts)
  M._lazy_init()
  local uranus = require("uranus")
  local kernel_name = opts.args ~= "" and opts.args or nil

  if not kernel_name then
    vim.notify("Usage: UranusConnect <kernel_name>", vim.log.levels.ERROR)
    return
  end

  -- Auto-start backend if not running
  if not uranus.state.backend_running then
    vim.notify("Starting Uranus backend...", vim.log.levels.INFO)
    local start_result = uranus.start_backend()
    if not start_result.success then
      vim.notify("Failed to start Uranus backend: " .. start_result.error.message, vim.log.levels.ERROR)
      return
    end
  end

  local result = uranus.connect_kernel(kernel_name)
  if result.success then
    vim.notify("Connected to kernel: " .. kernel_name, vim.log.levels.INFO)
  else
    vim.notify("Failed to connect to kernel: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Connect to a Jupyter kernel",
  nargs = 1,
  complete = function()
    -- TODO: Add kernel name completion
    return {}
  end,
})

vim.api.nvim_create_user_command("UranusExecute", function(opts)
  M._lazy_init()
  local uranus = require("uranus")
  local code = opts.args

  if code == "" then
    vim.notify("Usage: UranusExecute <code>", vim.log.levels.ERROR)
    return
  end

  -- Auto-start backend if not running
  if not uranus.state.backend_running then
    vim.notify("Starting Uranus backend...", vim.log.levels.INFO)
    local start_result = uranus.start_backend()
    if not start_result.success then
      vim.notify("Failed to start Uranus backend: " .. start_result.error.message, vim.log.levels.ERROR)
      return
    end
  end

  local result = uranus.execute(code)
  if not result.success then
    vim.notify("Execution failed: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Execute code in the current kernel",
  nargs = "+",
})

vim.api.nvim_create_user_command("UranusListKernels", function()
  M._lazy_init()
  local uranus = require("uranus")
  local kernel = require("uranus.kernel")

  -- Auto-start backend if not running
  if not uranus.state.backend_running then
    vim.notify("Starting Uranus backend...", vim.log.levels.INFO)
    local start_result = uranus.start_backend()
    if not start_result.success then
      vim.notify("Failed to start Uranus backend: " .. start_result.error.message, vim.log.levels.ERROR)
      return
    end
  end

  -- Backend is ready, discover kernels immediately
  vim.notify("Discovering kernels...", vim.log.levels.INFO)
  local result = kernel.discover_local_kernels()
  if result.success then
    local kernels = result.data
    vim.notify("Found " .. #kernels .. " kernels", vim.log.levels.INFO)
    if #kernels == 0 then
      vim.notify("No kernels found", vim.log.levels.WARN)
      return
    end

    local lines = {"Available kernels:"}
    for _, k in ipairs(kernels) do
      table.insert(lines, string.format("  - %s (%s)", k.name, k.language))
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
   else
     vim.notify("Failed to list kernels: " .. result.error.message, vim.log.levels.ERROR)
   end
end, {
  desc = "List available Jupyter kernels",
})

vim.api.nvim_create_user_command("UranusStartKernel", function(opts)
   M._lazy_init()
   local uranus = require("uranus")
   local kernel_name = opts.args

   if kernel_name == "" then
     vim.notify("Usage: UranusStartKernel <kernel_name>", vim.log.levels.ERROR)
     return
   end

   -- Auto-start backend if not running
   if not uranus.state.backend_running then
     vim.notify("Starting Uranus backend...", vim.log.levels.INFO)
     local start_result = uranus.start_backend()
     if not start_result.success then
       vim.notify("Failed to start Uranus backend: " .. start_result.error.message, vim.log.levels.ERROR)
       return
     end
   end

   local result = uranus.connect_kernel(kernel_name)
   if result.success then
     vim.notify("Started kernel: " .. kernel_name, vim.log.levels.INFO)
   else
     vim.notify("Failed to start kernel: " .. result.error.message, vim.log.levels.ERROR)
   end
 end, {
   desc = "Start a Jupyter kernel",
   nargs = 1,
 })

vim.api.nvim_create_user_command("UranusRunCell", function()
   M._lazy_init()
   local repl = require("uranus.repl")
   local cell = repl.get_cell_at_cursor()
   if cell then
     local result = repl.run_cell(cell, vim.api.nvim_get_current_buf())
     if not result.success then
       vim.notify("Cell execution failed: " .. result.error.message, vim.log.levels.ERROR)
     else
       vim.notify("Cell executed", vim.log.levels.INFO)
     end
   else
     vim.notify("No cell found at cursor", vim.log.levels.WARN)
   end
end, {
  desc = "Run the current cell",
})

vim.api.nvim_create_user_command("UranusRunAll", function()
   M._lazy_init()
   local repl = require("uranus.repl")
   local results = repl.run_all(vim.api.nvim_get_current_buf())
   vim.notify("Executed " .. #results .. " cells", vim.log.levels.INFO)
end, {
  desc = "Run all cells",
})

vim.api.nvim_create_user_command("UranusRunSelection", function()
   M._lazy_init()
   local repl = require("uranus.repl")
   local result = repl.run_selection()
   if not result.success then
     vim.notify("Selection execution failed: " .. result.error.message, vim.log.levels.ERROR)
   end
end, {
  desc = "Run visual selection",
})

vim.api.nvim_create_user_command("UranusNextCell", function()
   local repl = require("uranus.repl")
   repl.next_cell()
end, {
  desc = "Go to next cell",
})

vim.api.nvim_create_user_command("UranusPrevCell", function()
   local repl = require("uranus.repl")
   repl.prev_cell()
end, {
  desc = "Go to previous cell",
})

vim.api.nvim_create_user_command("UranusInsertCell", function()
   local repl = require("uranus.repl")
   repl.insert_cell()
end, {
  desc = "Insert cell marker",
})

vim.api.nvim_create_user_command("UranusMarkCells", function()
   local repl = require("uranus.repl")
   repl.mark_cells(vim.api.nvim_get_current_buf())
   vim.notify("Cells marked", vim.log.levels.INFO)
end, {
  desc = "Mark cells in buffer",
})

vim.api.nvim_create_user_command("UranusShowOutputs", function()
   local output = require("uranus.output")
   local uranus = require("uranus")
   local status = uranus.status()
   if status.current_kernel then
     vim.notify("Kernel: " .. status.current_kernel.name, vim.log.levels.INFO)
   else
     vim.notify("No kernel connected", vim.log.levels.WARN)
   end
end, {
  desc = "Show outputs for current cell",
})

vim.api.nvim_create_user_command("UranusPickKernel", function()
   M._lazy_init()
   local uranus = require("uranus")
   local kernels = uranus.list_kernels()
   if not kernels.success or #kernels.data.kernels == 0 then
     vim.notify("No kernels available", vim.log.levels.WARN)
     return
   end
   local ui = require("uranus.ui")
   ui.pick_kernel(kernels.data.kernels, function(choice)
     local result = uranus.connect_kernel(choice.name)
     if result.success then
       vim.notify("Connected to " .. choice.name, vim.log.levels.INFO)
     else
       vim.notify("Failed: " .. result.error.message, vim.log.levels.ERROR)
     end
   end)
end, {
  desc = "Pick and connect to a kernel",
})

vim.api.nvim_create_user_command("UranusDebug", function()
   local ui = require("uranus.ui")
   ui.debug_view()
end, {
  desc = "Show debug information",
})

vim.api.nvim_create_user_command("UranusUIStatus", function()
   local ui = require("uranus.ui")
   ui.update_status()
   vim.notify("Status updated", vim.log.levels.INFO)
end, {
  desc = "Update UI status",
})

-- Notebook commands
vim.api.nvim_create_user_command("UranusNotebookOpen", function(opts)
   M._lazy_init()
   local notebook = require("uranus.notebook")
   local path = opts.args ~= "" and opts.args or nil
   if not path then
     vim.notify("Usage: UranusNotebookOpen <path>", vim.log.levels.ERROR)
     return
   end
   notebook.open(path)
end, {
  desc = "Open notebook file",
  nargs = 1,
  complete = "file",
})

vim.api.nvim_create_user_command("UranusNotebookNew", function(opts)
   M._lazy_init()
   local notebook = require("uranus.notebook")
   local name = opts.args ~= "" and opts.args or "notebook"
   notebook.new(name)
end, {
  desc = "Create new notebook",
  nargs = "?",
})

vim.api.nvim_create_user_command("UranusNotebookSave", function()
   local notebook = require("uranus.notebook")
   local path = vim.b.uranus_notebook_path
   if not path then
     vim.notify("No notebook open", vim.log.levels.WARN)
     return
   end
   local ok, err = notebook.save(path)
   if ok then
     vim.notify("Notebook saved: " .. path, vim.log.levels.INFO)
   else
     vim.notify("Failed to save: " .. err, vim.log.levels.ERROR)
   end
end, {
  desc = "Save current notebook",
})

vim.api.nvim_create_user_command("UranusNotebookRunCell", function()
   local notebook = require("uranus.notebook")
   local result = notebook.run_cell()
   if result and result.success then
     vim.notify("Cell executed", vim.log.levels.INFO)
   end
end, {
  desc = "Run current cell",
})

vim.api.nvim_create_user_command("UranusNotebookRunAll", function()
   local notebook = require("uranus.notebook")
   local results = notebook.run_all()
   vim.notify("Executed " .. #results .. " cells", vim.log.levels.INFO)
end, {
  desc = "Run all cells",
})

vim.api.nvim_create_user_command("UranusNotebookInsertAbove", function()
   local notebook = require("uranus.notebook")
   notebook.insert_cell_above()
end, {
  desc = "Insert cell above",
})

vim.api.nvim_create_user_command("UranusNotebookInsertBelow", function()
   local notebook = require("uranus.notebook")
   notebook.insert_cell_below()
end, {
  desc = "Insert cell below",
})

vim.api.nvim_create_user_command("UranusNotebookDeleteCell", function()
   local notebook = require("uranus.notebook")
   notebook.delete_cell()
end, {
  desc = "Delete current cell",
})

vim.api.nvim_create_user_command("UranusNotebookToggleCell", function()
   local notebook = require("uranus.notebook")
   notebook.toggle_cell_type()
end, {
  desc = "Toggle cell type (code/markdown)",
})

vim.api.nvim_create_user_command("UranusNotebookClearOutput", function()
   local notebook = require("uranus.notebook")
   notebook.clear_output()
end, {
  desc = "Clear cell output",
})

-- Keymaps for REPL mode
vim.keymap.set("n", "<leader>urc", ":UranusRunCell<cr>", { desc = "Uranus run cell" })
vim.keymap.set("n", "<leader>ura", ":UranusRunAll<cr>", { desc = "Uranus run all cells" })
vim.keymap.set("n", "<leader>urn", ":UranusNextCell<cr>", { desc = "Uranus next cell" })
vim.keymap.set("n", "<leader>urp", ":UranusPrevCell<cr>", { desc = "Uranus previous cell" })
vim.keymap.set("n", "<leader>uri", ":UranusInsertCell<cr>", { desc = "Uranus insert cell" })
vim.keymap.set("v", "<leader>ure", ":<c-u>UranusRunSelection<cr>", { desc = "Uranus run selection" })
vim.keymap.set("n", "<leader>urk", ":UranusPickKernel<cr>", { desc = "Uranus pick kernel" })
vim.keymap.set("n", "<leader>urd", ":UranusDebug<cr>", { desc = "Uranus debug" })

-- Keymaps for notebook mode
vim.keymap.set("n", "<leader>ujn", ":UranusNotebookNew<cr>", { desc = "New notebook" })
vim.keymap.set("n", "<leader>ujo", ":UranusNotebookOpen<cr>", { desc = "Open notebook" })
vim.keymap.set("n", "<leader>ujs", ":UranusNotebookSave<cr>", { desc = "Save notebook" })
vim.keymap.set("n", "<leader>ujr", ":UranusNotebookRunCell<cr>", { desc = "Run notebook cell" })
vim.keymap.set("n", "<leader>uja", ":UranusNotebookRunAll<cr>", { desc = "Run all cells" })
vim.keymap.set("n", "<leader>ujd", ":UranusNotebookDeleteCell<cr>", { desc = "Delete cell" })
vim.keymap.set("n", "<leader>ujt", ":UranusNotebookToggleCell<cr>", { desc = "Toggle cell type" })
vim.keymap.set("n", "<leader>ujc", ":UranusNotebookClearOutput<cr>", { desc = "Clear output" })
vim.keymap.set("n", "<leader>uj-", ":UranusNotebookInsertAbove<cr>", { desc = "Insert cell above" })
vim.keymap.set("n", "<leader>uj+", ":UranusNotebookInsertBelow<cr>", { desc = "Insert cell below" })

-- TOC and Inspector commands
vim.api.nvim_create_user_command("UranusNotebookTOC", function()
   local notebook = require("uranus.notebook")
   notebook.open_toc()
end, {
  desc = "Open table of contents",
})

vim.api.nvim_create_user_command("UranusInspectorOpen", function()
   local inspector = require("uranus.inspector")
   inspector.open_inspector()
end, {
  desc = "Open variable inspector",
})

vim.api.nvim_create_user_command("UranusInspectorToggle", function()
   local inspector = require("uranus.inspector")
   inspector.toggle_inspector()
end, {
  desc = "Toggle variable inspector",
})

vim.api.nvim_create_user_command("UranusInspectHover", function()
   local inspector = require("uranus.inspector")
   local info = inspector.inspect_at_cursor()
   if info then
     inspector.show_hover(info)
   end
end, {
  desc = "Inspect variable at cursor",
})

-- Keymaps for TOC and Inspector
vim.keymap.set("n", "<leader>ujt", ":UranusNotebookTOC<cr>", { desc = "Open TOC" })
vim.keymap.set("n", "<leader>uji", ":UranusInspectorToggle<cr>", { desc = "Toggle inspector" })

-- REPL Buffer commands
vim.api.nvim_create_user_command("UranusREPLOpen", function()
   local repl = require("uranus.repl_buffer")
   repl.open()
end, {
  desc = "Open REPL buffer",
})

vim.api.nvim_create_user_command("UranusREPLToggle", function()
   local repl = require("uranus.repl_buffer")
   repl.toggle()
end, {
  desc = "Toggle REPL buffer",
})

vim.api.nvim_create_user_command("UranusREPLClear", function()
   local repl = require("uranus.repl_buffer")
   repl.clear()
end, {
  desc = "Clear REPL buffer",
})

-- Cell Mode commands
vim.api.nvim_create_user_command("UranusCellMode", function()
   local cell = require("uranus.cell_mode")
   cell.toggle_cell_mode()
end, {
  desc = "Toggle cell mode",
})

vim.api.nvim_create_user_command("UranusCellEnter", function()
   local cell = require("uranus.cell_mode")
   cell.enter_cell_mode()
end, {
  desc = "Enter cell mode",
})

vim.api.nvim_create_user_command("UranusCellExit", function()
   local cell = require("uranus.cell_mode")
   cell.exit_cell_mode()
end, {
  desc = "Exit cell mode",
})

vim.api.nvim_create_user_command("UranusCellRun", function()
   local cell = require("uranus.cell_mode")
   cell.run_cell()
end, {
  desc = "Run cell in cell mode",
})

-- Keymaps for REPL Buffer
vim.keymap.set("n", "<leader>ure", ":UranusREPLToggle<cr>", { desc = "Toggle REPL buffer" })
vim.keymap.set("n", "<leader>uec", ":UranusREPLClear<cr>", { desc = "Clear REPL" })

-- Keymaps for Cell Mode
vim.keymap.set("n", "<leader>ucm", ":UranusCellMode<cr>", { desc = "Cell mode" })
vim.keymap.set("n", "<leader>ucr", ":UranusCellRun<cr>", { desc = "Run cell in cell mode" })

-- LSP commands (connects to existing LSP)
vim.api.nvim_create_user_command("UranusLSPStatus", function()
   local lsp = require("uranus.lsp")
   local status = lsp.status()
   if status.running then
     local client_names = {}
     for _, c in ipairs(status.clients) do
       table.insert(client_names, c.name)
     end
     vim.notify("LSP running: " .. table.concat(client_names, ", "), vim.log.levels.INFO)
   else
     vim.notify("No Python LSP found. Configure LSP in your neovim config.", vim.log.levels.WARN)
   end
end, {
  desc = "Show LSP status",
})

vim.api.nvim_create_user_command("UranusLSPHover", function()
   local lsp = require("uranus.lsp")
   local word = vim.fn.expand("<cword>")
   lsp.show_hover_enhanced(word)
end, {
  desc = "Show enhanced hover (LSP + Kernel)",
})

vim.api.nvim_create_user_command("UranusLSPDefinition", function()
   local lsp = require("uranus.lsp")
   lsp.goto_definition()
end, {
  desc = "Go to definition",
})

vim.api.nvim_create_user_command("UranusLSPReferences", function()
   local lsp = require("uranus.lsp")
   lsp.references()
end, {
  desc = "Find references",
})

vim.api.nvim_create_user_command("UranusLSPDiagnostics", function()
   local lsp = require("uranus.lsp")
   lsp.diagnostics()
end, {
  desc = "Show diagnostics",
})

-- LSP keymaps
vim.keymap.set("n", "<leader>uls", ":UranusLSPStatus<cr>", { desc = "LSP status" })
vim.keymap.set("n", "<leader>ulu", ":UranusLSPHover<cr>", { desc = "Enhanced hover" })
vim.keymap.set("n", "<leader>ulg", ":UranusLSPDefinition<cr>", { desc = "Go to definition" })
vim.keymap.set("n", "<leader>ulr", ":UranusLSPReferences<cr>", { desc = "References" })
vim.keymap.set("n", "<leader>uld", ":UranusLSPDiagnostics<cr>", { desc = "Diagnostics" })

-- Extended LSP commands
vim.api.nvim_create_user_command("UranusLSPWorkspaceSymbols", function()
   local lsp = require("uranus.lsp")
   vim.ui.input({ prompt = "Search workspace symbols: " }, function(query)
      if query then
         local results = lsp.workspace_symbols(query)
         if #results > 0 then
            vim.ui.select(results, {
               prompt = "Go to symbol: ",
               format_item = function(item)
                  return (item.location and item.name) or "unknown"
               end,
            }, function(choice)
               if choice and choice.location then
                  local uri = choice.location.uri
                  local range = choice.location.range
                  vim.api.nvim_command("edit " .. vim.uri_to_fname(uri))
                  vim.api.nvim_win_set_cursor(0, { range.start.line + 1, range.start.character })
               end
            end)
         else
            vim.notify("No symbols found", vim.log.levels.WARN)
         end
      end
   end)
end, { desc = "Search workspace symbols" })

vim.api.nvim_create_user_command("UranusLSPRename", function()
   local lsp = require("uranus.lsp")
   local word = vim.fn.expand("<cword>")
   vim.ui.input({ prompt = "Rename to: ", default = word }, function(new_name)
      if new_name and new_name ~= word then
         lsp.rename_with_preview(new_name)
      end
   end)
end, { desc = "Rename symbol" })

vim.api.nvim_create_user_command("UranusLSPCodeAction", function()
   local lsp = require("uranus.lsp")
   local actions = lsp.get_code_actions()
   if #actions == 0 then
      vim.notify("No code actions available", vim.log.levels.INFO)
      return
   end
   vim.ui.select(actions, {
      prompt = "Select code action: ",
      format_item = function(action)
         return action.title or "unnamed action"
      end,
   }, function(choice)
      if choice then
         lsp.execute_code_action(choice)
      end
   end)
end, { desc = "Show code actions" })

vim.api.nvim_create_user_command("UranusLSPFormat", function()
   local lsp = require("uranus.lsp")
   lsp.format()
end, { desc = "Format document" })

vim.api.nvim_create_user_command("UranusLSPInlayHints", function()
   local lsp = require("uranus.lsp")
   lsp.toggle_inlay_hints()
end, { desc = "Toggle inlay hints" })

vim.api.nvim_create_user_command("UranusLSPDocSymbols", function()
   local lsp = require("uranus.lsp")
   local symbols = lsp.get_document_symbols()
   if #symbols == 0 then
      vim.notify("No symbols found", vim.log.levels.INFO)
      return
   end
   vim.ui.select(symbols, {
      prompt = "Go to symbol: ",
      format_item = function(item)
         return (item.name or "unknown") .. " (" .. (item.kind or "?") .. ")"
      end,
   }, function(choice)
      if choice and choice.location then
         local uri = choice.location.uri
         local range = choice.location.range
         vim.api.nvim_command("edit " .. vim.uri_to_fname(uri))
         vim.api.nvim_win_set_cursor(0, { range.start.line + 1, range.start.character })
      end
   end)
end, { desc = "Document symbols" })

vim.api.nvim_create_user_command("UranusLSPIncoming", function()
   require("uranus.lsp").incoming_calls()
end, { desc = "Incoming calls" })

vim.api.nvim_create_user_command("UranusLSPOutgoing", function()
   require("uranus.lsp").outgoing_calls()
end, { desc = "Outgoing calls" })

-- Extended LSP keymaps
vim.keymap.set("n", "<leader>ulw", ":UranusLSPWorkspaceSymbols<cr>", { desc = "Workspace symbols" })
vim.keymap.set("n", "<leader>uln", ":UranusLSPRename<cr>", { desc = "Rename" })
vim.keymap.set("n", "<leader>ula", ":UranusLSPCodeAction<cr>", { desc = "Code action" })
vim.keymap.set("n", "<leader>ulf", ":UranusLSPFormat<cr>", { desc = "Format" })
vim.keymap.set("n", "<leader>ulh", ":UranusLSPInlayHints<cr>", { desc = "Inlay hints" })
vim.keymap.set("n", "<leader>uld", ":UranusLSPDocSymbols<cr>", { desc = "Doc symbols" })
vim.keymap.set("n", "<leader>uli", ":UranusLSPIncoming<cr>", { desc = "Incoming calls" })
vim.keymap.set("n", "<leader>ulo", ":UranusLSPOutgoing<cr>", { desc = "Outgoing calls" })

-- Cell navigation (j/k like Jupyter)
vim.keymap.set("n", "j", function()
   local notebook = require("uranus.notebook")
   notebook.next_cell()
end, { desc = "Next cell" })

vim.keymap.set("n", "k", function()
   local notebook = require("uranus.notebook")
   notebook.prev_cell()
end, { desc = "Previous cell" })

-- Completion commands
vim.api.nvim_create_user_command("UranusKernelComplete", function()
   local completion = require("uranus.completion")
   completion.complete_kernel_variables()
end, { desc = "Complete kernel variables" })

vim.keymap.set("n", "<leader>ucv", ":UranusKernelComplete<cr>", { desc = "Kernel variables" })

-- Performance optimization: lazy load completion module
local completion_loaded = false
vim.api.nvim_create_autocmd("InsertEnter", {
   pattern = "*.py",
   once = true,
   callback = function()
      if not completion_loaded then
         local ok = pcall(require, "uranus.completion")
         if ok then
            completion_loaded = true
         end
      end
   end,
})

-- Export the module

-- Remote kernel commands
vim.api.nvim_create_user_command("UranusRemoteConnect", function()
   local remote = require("uranus.remote")
   remote.pick_remote_kernel()
end, { desc = "Connect to remote Jupyter server" })

vim.api.nvim_create_user_command("UranusRemoteList", function()
   local remote = require("uranus.remote")
   local result = remote.list_remote_kernels()
   if result.success and result.data then
      vim.notify("Remote kernels: " .. vim.inspect(result.data), vim.log.levels.INFO)
   else
      vim.notify("Failed to list remote kernels", vim.log.levels.ERROR)
   end
end, { desc = "List remote kernels" })

vim.api.nvim_create_user_command("UranusRemoteStart", function(opts)
   local remote = require("uranus.remote")
   local kernel_name = opts.args ~= "" and opts.args or "python3"
   local result = remote.start_kernel(kernel_name)
   if result.success then
      vim.notify("Kernel '" .. kernel_name .. "' started", vim.log.levels.INFO)
   end
end, {
   desc = "Start remote kernel",
   nargs = "?",
   complete = function()
      return { "python3", "python2", "ir", "julia" }
   end,
})

vim.api.nvim_create_user_command("UranusRemoteStop", function(opts)
   local remote = require("uranus.remote")
   vim.ui.input({ prompt = "Kernel ID: " }, function(kernel_id)
      if kernel_id then
         local result = remote.stop_kernel(kernel_id)
         if result.success then
            vim.notify("Kernel stopped", vim.log.levels.INFO)
         end
      end
   end)
end, { desc = "Stop remote kernel" })

vim.api.nvim_create_user_command("UranusRemoteManager", function()
   local remote = require("uranus.remote")
   remote.show_manager()
end, { desc = "Show remote kernel manager" })

vim.keymap.set("n", "<leader>urr", ":UranusRemoteConnect<cr>", { desc = "Remote connect" })
vim.keymap.set("n", "<leader>url", ":UranusRemoteList<cr>", { desc = "Remote list" })
vim.keymap.set("n", "<leader>urm", ":UranusRemoteManager<cr>", { desc = "Remote manager" })

-- Notebook UI commands (ipynb-style modal interface)
vim.api.nvim_create_user_command("UranusNotebookUIOpen", function(opts)
  M._lazy_init()
  local notebook_ui = require("uranus.notebook_ui")
  local path = opts.args ~= "" and opts.args or nil
  if not path then
    vim.notify("Usage: UranusNotebookUIOpen <path>", vim.log.levels.ERROR)
    return
  end
  notebook_ui.open(path)
end, {
  desc = "Open notebook with TUI",
  nargs = 1,
  complete = "file",
})

vim.api.nvim_create_user_command("UranusNotebookUICellMode", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.enter_cell_mode()
end, { desc = "Enter cell mode" })

vim.api.nvim_create_user_command("UranusNotebookUIExecute", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.execute_cell()
end, { desc = "Execute current cell" })

vim.api.nvim_create_user_command("UranusNotebookUIExecuteNext", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.execute_and_next()
end, { desc = "Execute cell and move to next" })

vim.api.nvim_create_user_command("UranusNotebookUINext", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.next_cell()
end, { desc = "Go to next cell" })

vim.api.nvim_create_user_command("UranusNotebookUIPrev", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.prev_cell()
end, { desc = "Go to previous cell" })

vim.api.nvim_create_user_command("UranusNotebookUIGoto", function(opts)
  local notebook_ui = require("uranus.notebook_ui")
  local idx = tonumber(opts.args)
  if not idx then
    vim.notify("Usage: UranusNotebookUIGoto <cell_number>", vim.log.levels.ERROR)
    return
  end
  notebook_ui.goto_cell(idx)
end, {
  desc = "Go to cell by number",
  nargs = 1,
})

vim.api.nvim_create_user_command("UranusNotebookUIAddCell", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.add_cell_below()
end, { desc = "Add cell below" })

vim.api.nvim_create_user_command("UranusNotebookUIDeleteCell", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.delete_cell()
end, { desc = "Delete current cell" })

vim.api.nvim_create_user_command("UranusNotebookUIToggleCell", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.toggle_cell_type()
end, { desc = "Toggle cell type" })

vim.api.nvim_create_user_command("UranusNotebookUIOutput", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.output()
end, { desc = "Open cell output in split" })

vim.api.nvim_create_user_command("UranusNotebookUIFold", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.fold_toggle()
end, { desc = "Toggle cell fold" })

vim.api.nvim_create_user_command("UranusNotebookUISave", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.save()
end, { desc = "Save notebook" })

vim.api.nvim_create_user_command("UranusNotebookUIHover", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.show_hover_at_cursor()
end, { desc = "Show variable hover" })

vim.api.nvim_create_user_command("UranusNotebookUIHideHover", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.hide_hover()
end, { desc = "Hide hover window" })

vim.api.nvim_create_user_command("UranusNotebookUIFormatCell", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.format_cell()
end, { desc = "Format current cell via LSP" })

vim.api.nvim_create_user_command("UranusNotebookUIFormatAll", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.format_all_cells()
end, { desc = "Format all cells via LSP" })

vim.api.nvim_create_user_command("UranusNotebookUIHealth", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.health_check()
end, { desc = "Run health check" })

vim.api.nvim_create_user_command("UranusNotebookUIAutoHover", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.toggle_auto_hover()
end, { desc = "Toggle auto-hover" })

vim.api.nvim_create_user_command("UranusNotebookUIDiagnostics", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.toggle_lsp_diagnostics()
end, { desc = "Toggle LSP diagnostics" })

vim.api.nvim_create_user_command("UranusNotebookUICodeLens", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.toggle_code_lens()
end, { desc = "Toggle code lens" })

-- Notebook UI keymaps
vim.keymap.set("n", "<Leader>kn", ":UranusNotebookUIExecute<cr>", { desc = "Execute cell" })
vim.keymap.set("n", "<Leader>kN", ":UranusNotebookUIExecuteNext<cr>", { desc = "Execute and next" })
vim.keymap.set("n", "<Leader>k]", ":UranusNotebookUINext<cr>", { desc = "Next cell" })
vim.keymap.set("n", "<Leader>k[", ":UranusNotebookUIPrev<cr>", { desc = "Previous cell" })
vim.keymap.set("n", "<Leader>kj", ":UranusNotebookUIGoto<cr>", { desc = "Go to cell" })
vim.keymap.set("n", "<Leader>ki", ":UranusNotebookUIAddCell<cr>", { desc = "Insert cell" })
vim.keymap.set("n", "<Leader>kt", ":UranusNotebookUIToggleCell<cr>", { desc = "Toggle cell type" })
vim.keymap.set("n", "<Leader>kl", ":UranusNotebookUIFold<cr>", { desc = "Toggle fold" })
vim.keymap.set("n", "K", ":UranusNotebookUIHover<cr>", { desc = "Show hover" })
vim.keymap.set("n", "<Leader>kh", ":UranusNotebookUIHideHover<cr>", { desc = "Hide hover" })
vim.keymap.set("n", "<Leader>ke", ":UranusNotebookUIFormatCell<cr>", { desc = "Format cell" })
vim.keymap.set("n", "<Leader>kE", ":UranusNotebookUIFormatAll<cr>", { desc = "Format all cells" })
vim.keymap.set("n", "<Leader>ks", ":UranusNotebookUIHealth<cr>", { desc = "Health check" })
vim.keymap.set("n", "<Leader>kH", ":UranusNotebookUIAutoHover<cr>", { desc = "Toggle auto-hover" })
vim.keymap.set("n", "<Leader>kD", ":UranusNotebookUIDiagnostics<cr>", { desc = "Toggle diagnostics" })
vim.keymap.set("n", "<Leader>kL", ":UranusNotebookUICodeLens<cr>", { desc = "Toggle code lens" })

vim.api.nvim_create_user_command("UranusNotebookUIRunAll", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.run_all_async()
end, { desc = "Run all cells asynchronously" })

vim.api.nvim_create_user_command("UranusNotebookUIRunParallel", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.run_all_parallel()
end, { desc = "Run all cells in parallel" })

vim.api.nvim_create_user_command("UranusNotebookUIStop", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.stop_execution()
end, { desc = "Stop execution" })

vim.api.nvim_create_user_command("UranusNotebookUIAsyncMode", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.toggle_async_mode()
end, { desc = "Toggle async mode (sequential/parallel)" })

vim.keymap.set("n", "<Leader>ka", ":UranusNotebookUIRunAll<cr>", { desc = "Run all cells async" })
vim.keymap.set("n", "<Leader>kA", ":UranusNotebookUIRunParallel<cr>", { desc = "Run all cells parallel" })
vim.keymap.set("n", "<Leader>ku", ":UranusNotebookUIStop<cr>", { desc = "Stop execution" })
vim.keymap.set("n", "<Leader>km", ":UranusNotebookUIAsyncMode<cr>", { desc = "Toggle async mode" })

-- Health check command (compatible with :checkhealth)
vim.api.nvim_create_user_command("UranusCheckHealth", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.health_check()
end, { desc = "Run Uranus health check" })

-- Alias for :checkhealth uranus
vim.api.nvim_create_user_command("CheckhealthUranus", function()
  local notebook_ui = require("uranus.notebook_ui")
  notebook_ui.health_check()
end, { desc = "Run Uranus health check (alias)" })

vim.api.nvim_create_user_command("UranusNotebookUITreesitter", function()
  local notebook_ui = require("uranus.notebook_ui")
  local status = notebook_ui.get_treesitter_status()
  if status.available then
    if status.parser_installed then
      notebook_ui.enable_treesitter(true)
    else
      vim.notify("Treesitter parser '" .. status.language .. "' not installed", vim.log.levels.WARN)
    end
  else
    vim.notify("Treesitter not available", vim.log.levels.ERROR)
  end
end, { desc = "Enable treesitter for notebook" })

-- Kernel Manager commands
vim.api.nvim_create_user_command("UranusInstallKernel", function(opts)
  local km = require("uranus.kernel_manager")
  local kernel_name = opts.args ~= "" and opts.args or nil
  if kernel_name then
    km.install_kernel(kernel_name, function(success, err)
      if success then
        vim.notify("Kernel installed: " .. kernel_name, vim.log.levels.INFO)
      else
        vim.notify("Failed to install kernel: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end)
  else
    local env = km.get_python_env()
    local name = env.prefix ~= "" and env.name or "python3"
    vim.ui.select({"Current Environment (" .. name .. ")", "Custom..."}, {
      prompt = "Install kernel for:",
    }, function(choice)
      if choice == "Current Environment (" .. name .. ")" then
        km.install_kernel(name, function(success, err)
          if success then
            vim.notify("Kernel installed: " .. name, vim.log.levels.INFO)
          else
            vim.notify("Failed: " .. (err or "unknown"), vim.log.levels.ERROR)
          end
        end)
      elseif choice == "Custom..." then
        vim.ui.input({ prompt = "Kernel name: " }, function(input)
          if input and #input > 0 then
            km.install_kernel(input, function(success, err)
              if success then
                vim.notify("Kernel installed: " .. input, vim.log.levels.INFO)
              else
                vim.notify("Failed: " .. (err or "unknown"), vim.log.levels.ERROR)
              end
            end)
          end
        end)
      end
    end)
  end
end, {
  desc = "Install Jupyter kernel (VS Code-like)",
  nargs = "?",
})

vim.api.nvim_create_user_command("UranusListKernels", function()
  local km = require("uranus.kernel_manager")
  local kernels = km.list_kernels()
  if #kernels == 0 then
    vim.notify("No kernels found. Run :UranusInstallKernel to create one.", vim.log.levels.WARN)
    return
  end

  local lines = { "Available Jupyter kernels:" }
  for _, k in ipairs(kernels) do
    table.insert(lines, string.format("  - %s (%s) [%s]", k.name, k.display_name, k.language))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "List available Jupyter kernels" })

vim.api.nvim_create_user_command("UranusRemoveKernel", function(opts)
  local km = require("uranus.kernel_manager")
  local kernel_name = opts.args

  if kernel_name == "" then
    local kernels = km.list_kernels()
    if #kernels == 0 then
      vim.notify("No kernels to remove", vim.log.levels.WARN)
      return
    end

    local names = {}
    for _, k in ipairs(kernels) do
      table.insert(names, k.name)
    end

    vim.ui.select(names, {
      prompt = "Select kernel to remove:",
    }, function(choice)
      if choice then
        km.remove_kernel(choice, function(success, err)
          if success then
            vim.notify("Kernel removed: " .. choice, vim.log.levels.INFO)
          else
            vim.notify("Failed: " .. (err or "unknown"), vim.log.levels.ERROR)
          end
        end)
      end
    end)
  else
    km.remove_kernel(kernel_name, function(success, err)
      if success then
        vim.notify("Kernel removed: " .. kernel_name, vim.log.levels.INFO)
      else
        vim.notify("Failed: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end)
  end
end, {
  desc = "Remove a Jupyter kernel",
  nargs = "?",
  complete = function()
    local km = require("uranus.kernel_manager")
    local kernels = km.list_kernels()
    local names = {}
    for _, k in ipairs(kernels) do
      table.insert(names, k.name)
    end
    return names
  end,
})

vim.keymap.set("n", "<leader>uki", ":UranusInstallKernel<cr>", { desc = "Install kernel" })
vim.keymap.set("n", "<leader>ukl", ":UranusListKernels<cr>", { desc = "List kernels" })
vim.keymap.set("n", "<leader>ukr", ":UranusRemoveKernel<cr>", { desc = "Remove kernel" })

-- Error handling - graceful degradation
local function setup_error_handling()
   local ok, uranus = pcall(require, "uranus")
   if not ok then
      vim.notify("Failed to load uranus module: " .. tostring(uranus), vim.log.levels.ERROR)
   end
end

-- Set up command error handler via wrapper
local original_execute = vim.cmd
vim.cmd = function(cmd)
   local ok, err = pcall(original_execute, cmd)
   if not ok and type(cmd) == "string" and cmd:match("^Uranus") then
      vim.notify("Command '" .. cmd .. "' not available", vim.log.levels.WARN)
   end
   return ok, err
end

return M