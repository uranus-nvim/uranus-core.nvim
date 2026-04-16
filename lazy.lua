-- Uranus.nvim lazy.nvim specification
--
-- This file provides the lazy.nvim plugin specification for Uranus.nvim.
-- It handles lazy loading, dependencies, and build configuration.
--
-- Usage in your lazy.nvim setup:
-- {
--   "your-username/uranus-core.nvim",
--   config = function()
--     require("uranus").setup({
--       auto_install_jupyter = true,
--       auto_install_parsers = true,
--     })
--   end,
-- }

return {
  -- Plugin name and version
  name = "uranus-core.nvim",
  description = "Seamless Jupyter kernel integration for Neovim",
  version = "0.1.0",

  -- Build configuration for Rust backend
  build = function()
    vim.notify("Building Uranus Rust backend...", vim.log.levels.INFO)
    local build_ok = os.execute("cargo build --release")
    if build_ok then
      -- Copy the compiled library to lua directory
      local lib_name = vim.loop.os_uname().sysname == "Darwin" and "liburanus.dylib" or "liburanus.so"
      local copy_ok = os.execute(string.format("cp target/release/%s lua/uranus.so", lib_name))
      if copy_ok then
        vim.notify("Uranus backend built successfully!", vim.log.levels.INFO)
      else
        vim.notify("Failed to copy Uranus backend", vim.log.levels.ERROR)
      end
    else
      vim.notify("Failed to build Uranus backend", vim.log.levels.ERROR)
    end
  end,

  -- Dependencies
  dependencies = {
    -- Required: Treesitter for parsing
    "nvim-treesitter/nvim-treesitter",

    -- Optional: For better UI
    "folke/snacks.nvim",

    -- Optional: For completion
    "nvim-cmp",

    -- Optional: For LSP integration
    "neovim/nvim-lspconfig",
  },

  -- Lazy loading configuration
  ft = { "python", "jupyter", "json" },  -- Filetypes
  cmd = {                                -- Commands
    "UranusStart",
    "UranusStop",
    "UranusStatus",
    "UranusConnect",
    "UranusListKernels",
    "UranusRunCell",
    "UranusRunAll",
    "UranusRunSelection",
    "UranusNotebookOpen",
    "UranusNotebookNew",
    "UranusNotebookSave",
    "UranusNotebookUIOpen",
    "UranusCheckHealth",
  },
  keys = {                          -- Keymaps
    { "<leader>urc", "<cmd>UranusRunCell<cr>", desc = "Run cell" },
    { "<leader>ura", "<cmd>UranusRunAll<cr>", desc = "Run all cells" },
    { "<leader>urn", "<cmd>UranusNextCell<cr>", desc = "Next cell" },
    { "<leader>urp", "<cmd>UranusPrevCell<cr>", desc = "Previous cell" },
    { "<leader>urk", "<cmd>UranusPickKernel<cr>", desc = "Pick kernel" },
    { "<leader>ujn", "<cmd>UranusNotebookNew<cr>", desc = "New notebook" },
    { "<leader>ujo", "<cmd>UranusNotebookOpen<cr>", desc = "Open notebook" },
    { "<leader>kn", "<cmd>UranusNotebookUIExecute<cr>", desc = "Execute cell" },
    { "<leader>kN", "<cmd>UranusNotebookUIExecuteNext<cr>", desc = "Execute and next" },
    { "<leader>ka", "<cmd>UranusNotebookUIRunAll<cr>", desc = "Run all async" },
    { "<leader>kA", "<cmd>UranusNotebookUIRunParallel<cr>", desc = "Run parallel" },
  },

  -- Main configuration function
  config = function(_, opts)
    -- Merge user options with defaults
    local config = vim.tbl_deep_extend("force", {
      auto_install_jupyter = true,
      auto_install_parsers = true,
      async_execution = false,
      parallel_cells = false,
      max_parallel = 4,
      output = {
        use_virtual_text = true,
        use_snacks = true,
        max_image_width = 800,
      },
      lsp = {
        enabled = true,
        prefer_static = true,
        merge_with_kernel = true,
      },
      notebook = {
        auto_detect = true,
        show_outputs = true,
      },
      treesitter = {
        enabled = true,
        auto_highlight = true,
        language = "python",
      },
      cache = {
        max_size = 100,
        ttl = 30000,
      },
      keymaps = {
        enabled = true,
        prefix = "<leader>ur",
      },
    }, opts or {})

    -- Initialize Uranus
    require("uranus").setup(config)

    -- Setup Treesitter if enabled
    if config.treesitter.enabled then
      local ok, treesitter = pcall(require, "nvim-treesitter.configs")
      if ok then
        treesitter.setup({
          ensure_installed = { "python", "json", "markdown" },
          sync_install = false,
          auto_install = true,
        })
      end
    end
  end,

  -- Plugin metadata
  opts = {
    -- User options will be merged here
  },

  -- Main module
  main = "uranus",

  -- Priority for loading
  priority = 100,

  -- Lazy load on specific events
  event = { "BufReadPost", "BufNewFile" },

  -- Additional configuration
  init = function()
    -- Early initialization if needed
  end,
}
