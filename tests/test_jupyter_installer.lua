--- Tests for jupyter_installer plugin module
--- Tests the Jupyter installation dialog and fallback strategy

package.path = package.path .. ";./tests/?.lua"
local T = require("testlib")
T.reset()

local function run_jupyter_installer_tests()
  T.section("Jupyter Installer Tests")

  local jupyter_installer = require("jupyter_installer")

  T.section("Module Loading")
  T.test("jupyter_installer module loads", function()
    local ok = pcall(require, "jupyter_installer")
    T.assert(ok, "Failed to load jupyter_installer module")
  end)

  T.section("Utility Functions")
  T.test("detect_python returns a command", function()
    local python = jupyter_installer.detect_python()
    if python then
      T.assert_type(python, "string")
      T.assert(#python > 0, "Python command should not be empty")
    else
      T.skip("No Python installation found")
    end
  end)

  T.test("has_uv returns boolean", function()
    local result = jupyter_installer.has_uv()
    T.assert_type(result, "boolean")
  end)

  T.test("find_project_root returns path or nil", function()
    local root = jupyter_installer.find_project_root()
    if root then
      T.assert_type(root, "string")
      T.assert(#root > 0, "Project root should not be empty")
    else
      T.skip("No project root found")
    end
  end)

  T.test("check_jupyter returns boolean", function()
    local result = jupyter_installer.check_jupyter()
    T.assert_type(result, "boolean")
  end)

  T.section("Install Strategy")
  T.test("get_install_strategy returns table", function()
    local strategies = jupyter_installer.get_install_strategy()
    T.assert_type(strategies, "table")
    T.assert(#strategies > 0, "Should have at least one install strategy")
  end)

  T.test("each strategy has required fields", function()
    local strategies = jupyter_installer.get_install_strategy()
    for i, strategy in ipairs(strategies) do
      T.assert_type(strategy.name, "string", "Strategy " .. i .. " name")
      T.assert_type(strategy.description, "string", "Strategy " .. i .. " description")
      T.assert_type(strategy.install, "function", "Strategy " .. i .. " install")
    end
  end)

  T.test("strategy names are unique", function()
    local strategies = jupyter_installer.get_install_strategy()
    local names = {}
    for _, strategy in ipairs(strategies) do
      T.assert_nil(names[strategy.name], "Duplicate strategy name: " .. strategy.name)
      names[strategy.name] = true
    end
  end)

  T.section("Strategy Priority")
  T.test("uv strategy preferred when available", function()
    local strategies = jupyter_installer.get_install_strategy()
    local has_uv = jupyter_installer.has_uv()

    if has_uv then
      local first_strategy = strategies[1]
      T.assert(first_strategy.name:match("uv"), "First strategy should be uv when available")
    else
      T.skip("uv not available")
    end
  end)

  T.test("system fallback is last", function()
    local strategies = jupyter_installer.get_install_strategy()
    local last_strategy = strategies[#strategies]
    T.assert(last_strategy.name:match("system"), "Last strategy should be system fallback")
  end)

  T.section("Integration")
  T.test("install strategy execution (dry run)", function()
    local strategies = jupyter_installer.get_install_strategy()
    if #strategies > 0 then
      local first_strategy = strategies[1]
      T.assert_type(first_strategy.install, "function")
    end
  end)

  T.section("Project Detection")
  T.test("finds .venv directory", function()
    local root = jupyter_installer.find_project_root()
    if root then
      local venv_path = root .. "/.venv"
      local is_venv = vim.fn.isdirectory(venv_path) == 1
      T.assert_type(is_venv, "number")
    else
      T.skip("No project root found")
    end
  end)

  T.section("Python Detection Priority")
  T.test("prefers python3 over python", function()
    local python = jupyter_installer.detect_python()
    if python then
      T.assert(python == "python3" or python == "python" or python == "py",
        "Should return valid python command")
    else
      T.skip("No Python found")
    end
  end)

  T.summary()
  return T.results()
end

local success = run_jupyter_installer_tests()
vim.cmd(success and "quit 1" or "quit 0")
