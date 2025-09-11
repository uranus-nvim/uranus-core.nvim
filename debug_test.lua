-- Debug test for Uranus kernel discovery
print("=== Uranus Debug Test ===")

-- Test 1: Check if backend binary exists
local backend_path = vim.fn.getcwd() .. "/uranus-rs/target/release/uranus-rs"
print("Backend path: " .. backend_path)
print("Backend exists: " .. tostring(vim.fn.executable(backend_path) == 1))

-- Test 2: Check if we can find the binary using the same logic as _find_binary
local candidates = {
  vim.fn.getcwd() .. "/uranus-rs/target/release/uranus-rs",
  vim.fn.getcwd() .. "/uranus-rs/target/debug/uranus-rs",
  vim.fn.expand("~/projects/uranus.nvim/uranus-rs/target/release/uranus-rs"),
  vim.fn.expand("~/projects/uranus.nvim/uranus-rs/target/debug/uranus-rs"),
  vim.fn.expand("~/.cargo/bin/uranus-rs"),
  vim.fn.expand("~/.local/share/uranus/bin/uranus-rs"),
  vim.fn.expand("~/.config/uranus/bin/uranus-rs"),
  "/usr/local/bin/uranus-rs",
  "/usr/bin/uranus-rs",
  vim.fn.exepath("uranus-rs"),
}

print("\nChecking candidate paths:")
for i, path in ipairs(candidates) do
  local exists = vim.fn.executable(path) == 1
  print(string.format("%d. %s -> %s", i, path, exists and "EXISTS" or "NOT FOUND"))
end

-- Test 3: Check current working directory
print("\nCurrent working directory: " .. vim.fn.getcwd())

-- Test 4: Check if kernels exist
print("\nChecking for kernels:")
local kernel_paths = {
  "/home/mark/.local/share/jupyter/kernels",
  "/usr/local/share/jupyter/kernels",
  "/usr/share/jupyter/kernels"
}

for _, path in ipairs(kernel_paths) do
  local exists = vim.fn.isdirectory(path) == 1
  print(string.format("Directory %s -> %s", path, exists and "EXISTS" or "NOT FOUND"))
  if exists then
    local files = vim.fn.glob(path .. "/*/kernel.json")
    print("  Kernel files found: " .. (files ~= "" and files or "NONE"))
  end
end

print("\n=== Debug Test Complete ===")