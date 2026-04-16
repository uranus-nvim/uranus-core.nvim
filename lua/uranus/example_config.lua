-- Uranus.nvim Example Configuration
--
-- This file shows how to configure Uranus.nvim with lazy.nvim
-- Copy and adapt this to your Neovim configuration
--
-- Location: ~/.config/nvim/lua/plugins/uranus.lua (for lazy.nvim)

return {
  "your-username/uranus-core.nvim",
  -- Build the Rust backend
  build = "cargo build --release && cp target/release/liburanus.dylib lua/uranus.so",

  -- Dependencies
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "folke/snacks.nvim",  -- Optional: for better UI
  },

  -- Lazy loading
  ft = { "python", "jupyter", "ipynb" },
  cmd = {
    "UranusStart",
    "UranusStop",
    "UranusStatus",
    "UranusConnect",
    "UranusListKernels",
    "UranusRunCell",
    "UranusRunAll",
    "UranusNotebookOpen",
    "UranusNotebookNew",
    "UranusNotebookUIOpen",
  },
  keys = {
    -- REPL mode
    { "<leader>urc", "<cmd>UranusRunCell<cr>", desc = "Run cell" },
    { "<leader>ura", "<cmd>UranusRunAll<cr>", desc = "Run all cells" },
    { "<leader>urn", "<cmd>UranusNextCell<cr>", desc = "Next cell" },
    { "<leader>urp", "<cmd>UranusPrevCell<cr>", desc = "Previous cell" },
    { "<leader>urk", "<cmd>UranusPickKernel<cr>", desc = "Pick kernel" },

    -- Notebook
    { "<leader>ujn", "<cmd>UranusNotebookNew<cr>", desc = "New notebook" },
    { "<leader>ujo", "<cmd>UranusNotebookOpen<cr>", desc = "Open notebook" },
    { "<leader>ujs", "<cmd>UranusNotebookSave<cr>", desc = "Save notebook" },

    -- Notebook UI (Jupyter-like)
    { "<leader>kn", "<cmd>UranusNotebookUIExecute<cr>", desc = "Execute cell" },
    { "<leader>kN", "<cmd>UranusNotebookUIExecuteNext<cr>", desc = "Execute and next" },
    { "<leader>ka", "<cmd>UranusNotebookUIRunAll<cr>", desc = "Run all async" },
    { "<leader>kA", "<cmd>UranusNotebookUIRunParallel<cr>", desc = "Run parallel" },
  },

  -- Configuration
  config = function(_, opts)
    require("uranus").setup({
      -- Core settings
      auto_install_jupyter = true,  -- Auto-install Jupyter if not found
      auto_install_parsers = true,  -- Auto-install Treesitter parsers

      -- Execution settings
      async_execution = false,      -- Enable async cell execution
      parallel_cells = false,       -- Enable parallel execution
      max_parallel = 4,            -- Max parallel cells

      -- Output configuration
      output = {
        use_virtual_text = true,   -- Show output as virtual text
        use_snacks = true,         -- Use snacks.nvim for rendering
        max_image_width = 800,     -- Max image display width
      },

      -- LSP integration
      lsp = {
        enabled = true,            -- Enable LSP integration
        prefer_static = true,      -- Prefer static LSP info
        merge_with_kernel = true,  -- Merge LSP + kernel info
      },

      -- Notebook settings
      notebook = {
        auto_detect = true,        -- Auto-detect .ipynb files
        show_outputs = true,       -- Show cell outputs
        auto_save = true,          -- Auto-save notebook
      },

      -- Treesitter configuration
      treesitter = {
        enabled = true,            -- Enable Treesitter
        auto_highlight = true,     -- Auto-highlight cells
        language = "python",       -- Default language
      },

      -- Cache settings
      cache = {
        max_size = 100,            -- Max cache entries
        ttl = 30000,              -- Cache TTL (ms)
        enabled = true,            -- Enable caching
      },

      -- Keymap settings
      keymaps = {
        enabled = true,            -- Enable keymaps
        prefix = "<leader>ur",    -- REPL prefix
        notebook_prefix = "<leader>uj", -- Notebook prefix
        notebook_ui_prefix = "<leader>k", -- Notebook UI prefix
        lsp_prefix = "<leader>ul",       -- LSP prefix
      },
    })
  end,
}

-- Alternative: Minimal configuration
-- {
--   "your-username/uranus-core.nvim",
--   config = function()
--     require("uranus").setup()
--   end,
-- }

-- Alternative: With custom keymaps
-- {
--   "your-username/uranus-core.nvim",
--   config = function()
--     require("uranus").setup({
--       keymaps = {
--         prefix = "<leader>k",  -- Use <leader>k for all Uranus keymaps
--       },
--     })
--   end,
-- }

-- Alternative: Disable auto-install
-- {
--   "your-username/uranus-core.nvim",
--   config = function()
--     require("uranus").setup({
--       auto_install_jupyter = false,
--       auto_install_parsers = false,
--     })
--   end,
-- }
