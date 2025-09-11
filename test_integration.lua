#!/usr/bin/env lua
-- Simple test script to verify Uranus integration

print("Testing Uranus Neovim Integration")
print("=================================")

-- Test 1: Check if backend binary exists
local backend_path = "./uranus-rs/target/release/uranus-rs"
local f = io.open(backend_path, "r")
if f then
  f:close()
  print("✓ Backend binary found at: " .. backend_path)
else
  print("✗ Backend binary not found at: " .. backend_path)
  print("  Please run: cd uranus-rs && cargo build --release")
  return
end

-- Test 2: Check if Lua files exist
local lua_files = {
  "lua/uranus/init.lua",
  "lua/uranus/backend.lua",
  "lua/uranus/kernel.lua",
  "plugin/uranus.lua"
}

for _, file in ipairs(lua_files) do
  local f = io.open(file, "r")
  if f then
    f:close()
    print("✓ Lua file exists: " .. file)
  else
    print("✗ Lua file missing: " .. file)
  end
end

print("\nIntegration Test Complete!")
print("\nTo use Uranus in Neovim:")
print("1. Add to your init.lua:")
print([[
  require('uranus').setup({
    debug = true,
    kernels = {
      auto_start = true,
      default = "python3"
    }
  })
]])
print("\n2. Available commands:")
print("  :UranusStart     - Start the backend")
print("  :UranusStop      - Stop the backend")
print("  :UranusStatus    - Show status")
print("  :UranusListKernels - List available kernels")
print("  :UranusStartKernel <name> - Start a specific kernel")
print("  :UranusConnect <name> - Connect to a kernel")
print("  :UranusExecute <code> - Execute code")