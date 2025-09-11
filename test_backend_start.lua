-- Test backend startup and communication
local uv = vim.loop

print("Testing backend startup...")

-- Find backend binary
local backend_path = vim.fn.getcwd() .. "/uranus-rs/target/release/uranus-rs"
print("Backend path: " .. backend_path)
print("Backend executable: " .. tostring(vim.fn.executable(backend_path) == 1))

-- Start backend process
local stdin = uv.new_pipe(false)
local stdout = uv.new_pipe(false)
local stderr = uv.new_pipe(false)

print("Starting backend process...")
local handle, pid = uv.spawn(backend_path, {
  stdio = {stdin, stdout, stderr},
  cwd = vim.fn.getcwd(),
}, function(code, signal)
  print("Backend process exited with code: " .. code)
end)

if not handle then
  print("Failed to start backend process")
  return
end

print("Backend process started with PID: " .. pid)

-- Set up readers
uv.read_start(stdout, function(err, data)
  if err then
    print("Error reading stdout: " .. err)
    return
  end
  if data then
    print("Backend stdout: " .. data:gsub("\n$", ""))
  end
end)

uv.read_start(stderr, function(err, data)
  if data then
    print("Backend stderr: " .. data:gsub("\n$", ""))
  end
end)

-- Send test command after a delay
vim.defer_fn(function()
  print("Sending test command...")
  local test_cmd = '{"id": "test123", "cmd": "list_kernels", "data": {}}\n'
  uv.write(stdin, test_cmd, function(err)
    if err then
      print("Failed to send command: " .. err)
    else
      print("Command sent successfully")
    end
  end)
end, 2000)

-- Clean up after some time
vim.defer_fn(function()
  print("Cleaning up...")
  uv.close(stdin)
  uv.close(stdout)
  uv.close(stderr)
  uv.close(handle)
end, 5000)