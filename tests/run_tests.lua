-- Simple test runner for Uranus
local function run_tests()
  local tests_passed = 0
  local tests_failed = 0
  
  local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
      print("[PASS] " .. name)
      tests_passed = tests_passed + 1
    else
      print("[FAIL] " .. name .. ": " .. tostring(err))
      tests_failed = tests_failed + 1
    end
  end
  
  -- Test 1: Plugin loads without error
  test("Lua module loads", function()
    local ok, _ = pcall(require, "uranus")
    assert(ok, "Failed to load uranus module")
  end)
  
  -- Test 2: Version check
  test("Version check passes", function()
    local v = vim.version()
    assert(v.major == 0 and v.minor == 11)
  end)
  
  -- Test 3: Backend functions exist
  test("Backend functions exist", function()
    local uranus = require("uranus")
    assert(uranus.start_backend ~= nil)
    assert(uranus.stop_backend ~= nil)
    assert(uranus.status ~= nil)
    assert(uranus.list_kernels ~= nil)
    assert(uranus.connect_kernel ~= nil)
    assert(uranus.disconnect_kernel ~= nil)
    assert(uranus.execute ~= nil)
    assert(uranus.interrupt ~= nil)
  end)
  
  -- Test 4: start_backend works
  test("Start backend", function()
    local uranus = require("uranus")
    local result = uranus.start_backend()
    assert(result.success == true, "start_backend should return success")
  end)
  
  -- Test 5: status returns version
  test("Status returns version", function()
    local uranus = require("uranus")
    local result = uranus.status()
    assert(result.success == true, "status should return success")
    assert(result.data.version ~= nil, "status should include version")
  end)
  
  -- Test 6: stop_backend works
  test("Stop backend", function()
    local uranus = require("uranus")
    local result = uranus.stop_backend()
    assert(result.success == true, "stop_backend should return success")
  end)
  
  -- Test 7: list_kernels function exists
  test("list_kernels function works", function()
    local uranus = require("uranus")
    local result = uranus.list_kernels()
    assert(result.success == true, "list_kernels should return success")
    assert(result.data.kernels ~= nil, "list_kernels should include kernels")
  end)
  
  -- Test 8: connect_kernel function works
  test("connect_kernel function works", function()
    local uranus = require("uranus")
    local result = uranus.connect_kernel("python3")
    assert(result.success == true, "connect_kernel should return success")
  end)
  
  -- Test 9: execute without kernel returns error
  test("execute without kernel returns error", function()
    local uranus = require("uranus")
    uranus.stop_backend()  -- disconnect first
    local result = uranus.execute("print('hello')")
    assert(result.success == false, "execute without kernel should fail")
  end)
  
  -- Test 10: interrupt function exists
  test("interrupt function exists", function()
    local uranus = require("uranus")
    local result = uranus.interrupt()
    assert(result.success == true, "interrupt should return success")
  end)
  
  -- Summary
  print("")
  print(string.format("Results: %d passed, %d failed", tests_passed, tests_failed))
  
  return tests_failed == 0
end

-- Run tests
local success = run_tests()
vim.cmd(success and "quit 1" or "quit 0")
