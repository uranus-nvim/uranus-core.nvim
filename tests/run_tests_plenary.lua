#!/usr/bin/env lua
--- Uranus test runner using plenary.nvim
---
--- This script runs all Uranus tests using the plenary.nvim test framework.
--- It provides better integration with Neovim and more detailed test reports.
---
--- Usage:
---   nvim --headless -c "luafile tests/run_tests_plenary.lua" -c "qa!"
---   or
---   make test

-- Add project to runtimepath
local project_root = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h:h")
vim.opt.runtimepath:prepend(project_root)

-- Load plenary
local plenary_ok, plenary = pcall(require, "plenary")
if not plenary_ok then
  print("plenary.nvim not found. Please install plenary.nvim first.")
  print("You can install it with: lazy install plenary.nvim")
  return
end

-- Test files to run
local test_files = {
  "tests/test_integration_e2e.lua",
  "tests/test_notebook_parsing.lua",
  "tests/test_runner.lua",
  "tests/test_performance.lua",
  "tests/test_integration.lua",
}

-- Test configuration
local test_config = {
  -- Run in headless mode for CI
  headless = vim.v.argv and vim.v.argv[1] == "--headless",

  -- Output format
  format = "plain",  -- or "json" for CI

  -- Timeout per test (ms)
  timeout = 10000,

  -- Stop on first failure
  stop_on_failure = false,
}

-- Statistics
local stats = {
  total = 0,
  passed = 0,
  failed = 0,
  skipped = 0,
}

-- Run tests
local function run_tests()
  print("=== Uranus.nvim Test Suite ===")
  print("Running tests with plenary.nvim...")
  print("")

  -- Load test files
  local test_modules = {}
  for _, file in ipairs(test_files) do
    local full_path = project_root .. "/" .. file
    if vim.fn.filereadable(full_path) == 1 then
      table.insert(test_modules, file:gsub("%.lua$", ""):gsub("/", "."))
    end
  end

  if #test_modules == 0 then
    print("No test files found!")
    return
  end

  -- Run tests with plenary
  local TestRunner = require("plenary.test_harness")

  TestRunner.run_tests(test_modules, {
    -- Test options
    sequential = true,
    timeout = test_config.timeout,

    -- Callbacks
    on_test_finish = function(test)
      stats.total = stats.total + 1
      if test.status == "passed" then
        stats.passed = stats.passed + 1
      elseif test.status == "failed" then
        stats.failed = stats.failed + 1
      elseif test.status == "skipped" then
        stats.skipped = stats.skipped + 1
      end
    end,

    on_suite_finish = function(suite)
      -- Print suite summary
    end,
  })

  -- Print summary
  print("")
  print("=== Test Summary ===")
  print(string.format("Total:   %d", stats.total))
  print(string.format("Passed:  %d", stats.passed))
  print(string.format("Failed:  %d", stats.failed))
  print(string.format("Skipped: %d", stats.skipped))
  print("")

  -- Exit with appropriate code
  if stats.failed > 0 then
    print("❌ Some tests failed")
    vim.cmd("cquit 1")
  else
    print("✅ All tests passed")
    vim.cmd("qa!")
  end
end

-- Run tests
run_tests()
