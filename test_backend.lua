#!/usr/bin/env lua

-- Simple test script to verify Rust backend communication
-- Run with: lua test_backend.lua

local backend = require("uranus.backend")

print("Testing Uranus backend communication...")

-- Initialize backend
local result = backend.init({
  kernels = {
    timeout = 5000,
  }
})

if not result.success then
  print("Failed to initialize backend:", result.error.message)
  os.exit(1)
end

print("Backend initialized successfully")

-- Test starting backend
print("Starting backend...")
result = backend.start()
if not result.success then
  print("Failed to start backend:", result.error.message)
  os.exit(1)
end

print("Backend started successfully")

-- Test sending commands
print("Testing list_kernels command...")
backend.send_command("list_kernels", {}, function(result)
  if result.success then
    print("Kernels found:")
    for _, kernel in ipairs(result.data.kernels) do
      print(string.format("  - %s (%s)", kernel.name, kernel.display_name))
    end
  else
    print("Failed to list kernels:", result.error.message)
  end
end)

-- Test start_kernel command
print("Testing start_kernel command...")
backend.send_command("start_kernel", {kernel = "python3"}, function(result)
  if result.success then
    print("Kernel started successfully:")
    print(string.format("  Name: %s", result.data.kernel_info.name))
    print(string.format("  Status: %s", result.data.kernel_info.status))
  else
    print("Failed to start kernel:", result.error.message)
  end
end)

-- Wait a bit for async operations
vim.defer_fn(function()
  print("Stopping backend...")
  result = backend.stop()
  if result.success then
    print("Backend stopped successfully")
  else
    print("Failed to stop backend:", result.error.message)
  end

  print("Test completed!")
end, 2000)