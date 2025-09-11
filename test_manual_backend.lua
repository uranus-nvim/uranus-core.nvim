-- Manual test of backend communication
print("Manual Backend Test")
print("===================")

-- Load the backend module
local backend = require("uranus.backend")

-- Check if backend is already running
print("Backend connected:", backend.state.connected)
print("Backend process:", backend.state.process ~= nil)

-- Start backend if not running
if not backend.state.connected then
  print("Starting backend...")
  local result = backend.start()
  print("Start result:", vim.inspect(result))
else
  print("Backend already running")
end

-- Wait a bit
vim.wait(2000, function() return false end)

-- Try to send a command
print("Sending list_kernels command...")
local cmd_result = backend.send_command("list_kernels", {}, function(response)
  print("Command response received:", vim.inspect(response))
end)

print("Command send result:", vim.inspect(cmd_result))

-- Wait for response
vim.wait(3000, function() return false end)

print("Test complete")