-- Test synchronous integration
print("Testing Synchronous Integration")
print("===============================")

-- Test backend startup
local backend = require("uranus.backend")
print("Starting backend...")
local start_result = backend.start()
print("Start result:", vim.inspect(start_result))

if start_result.success then
  -- Test kernel discovery
  local kernel = require("uranus.kernel")
  print("Discovering kernels...")
  local discover_result = kernel.discover_local_kernels()
  print("Discovery result:", vim.inspect(discover_result))

  if discover_result.success then
    local kernels = discover_result.data
    print("Found kernels:")
    for i, k in ipairs(kernels) do
      print(string.format("  %d. %s (%s)", i, k.name, k.language))
    end
  else
    print("Discovery failed:", discover_result.error.message)
  end
else
  print("Backend start failed:", start_result.error.message)
end

print("Test complete!")