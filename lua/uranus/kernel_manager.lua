--- Uranus kernel manager
--- Install and manage Jupyter kernels similar to VS Code
---
--- @module uranus.kernel_manager

local M = {}

local config = nil

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    local defaults = cfg.get("kernel_manager")
    config = vim.deepcopy(defaults)
  end
  return config
end

local function get_uranus()
    local ok, uranus = pcall(require, "uranus")
    return ok and uranus or nil
end

function M.configure(opts)
    local cfg = require("uranus.config")
    local current = cfg.get("kernel_manager") or {}
    config = vim.tbl_deep_extend("force", current, opts or {})
end

function M.get_config()
    return get_config()
end

--- Check if ipykernel is installed
function M.check_ipykernel()
    local handle = io.popen("python3 -c 'import ipykernel; print(ipykernel.__version__)' 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result:match("^%d+") then
            return true, result:gsub("%s+", "")
        end
    end

    local handle2 = io.popen("python -c 'import ipykernel; print(ipykernel.__version__)' 2>/dev/null")
    if handle2 then
        local result = handle2:read("*a")
        handle2:close()
        if result and result:match("^%d+") then
            return true, result:gsub("%s+", "")
        end
    end

    return false, nil
end

--- Install ipykernel
function M.install_ipykernel(on_complete)
    local notify = vim.notify or print
    notify("Installing ipykernel...", vim.log.levels.INFO)

    local function try_install(cmd)
        local handle = io.popen(cmd .. " 2>&1")
        if not handle then
            notify("Failed to run install command", vim.log.levels.ERROR)
            if on_complete then on_complete(false, "Failed to run pip") end
            return false
        end

        local output = handle:read("*a")
        local success = handle:close()

        if success then
            notify("ipykernel installed successfully!", vim.log.levels.INFO)
            if on_complete then on_complete(true, nil) end
        else
            notify("Failed to install ipykernel: " .. output, vim.log.levels.ERROR)
            if on_complete then on_complete(false, output) end
        end
        return success
    end

    local uv_check = io.popen("which uv")
    local has_uv = uv_check and uv_check:read("*a"):match("uv")
    uv_check:close()

    if has_uv then
        local cmd = "uv add ipykernel"
        if try_install(cmd) then return end
    end

    if vim.env.VIRTUAL_ENV then
        local venv_bin = vim.env.VIRTUAL_ENV .. "/bin"
        local cmd = venv_bin .. "/pip install ipykernel"
        if try_install(cmd) then return end
    end

    local python_check = io.popen("which python3")
    local has_python = python_check and python_check:read("*a"):match("python")
    python_check:close()

    if has_python then
        local cmd = "python3 -m pip install --break-system-packages ipykernel"
        if try_install(cmd) then return end
    end

    try_install("pip install --break-system-packages ipykernel")
end

--- Ensure ipykernel is installed
function M.ensure_ipykernel(on_ready)
    local installed, version = M.check_ipykernel()
    if installed then
        if on_ready then on_ready(true, version) end
        return
    end

    if config.auto_install then
        M.install_ipykernel(function(success, err)
            if success then
                if on_ready then on_ready(true, "installed") end
            else
                if on_ready then on_ready(false, err) end
            end
        end)
    else
        if on_ready then on_ready(false, "ipykernel not installed and auto_install is false") end
    end
end

--- Get current Python environment info
function M.get_python_env()
    local env = {
        executable = "python3",
        prefix = "",
        name = "system",
    }

    local handle = io.popen("which python3 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and #result > 0 then
            env.executable = result:gsub("%s+", "")
        end
    end

    if vim.env.VIRTUAL_ENV then
        env.prefix = vim.env.VIRTUAL_ENV
        local name = vim.env.VIRTUAL_ENV:match("([^/]+)$")
        if name then
            env.name = name
        end
    end

    local handle2 = io.popen(env.executable .. " -c 'import sys; print(sys.version_info.major, sys.version_info.minor, sep=\".\")' 2>/dev/null")
    if handle2 then
        local version = handle2:read("*a")
        handle2:close()
        if version and #version > 0 then
            env.version = version:gsub("%s+", "")
        end
    end

    return env
end

--- Create a Jupyter kernel for the current environment
--- @param kernel_name? string Name for the kernel (defaults to environment name)
--- @param on_complete? function Callback when complete
function M.install_kernel(kernel_name, on_complete)
    local notify = vim.notify or print

    M.ensure_ipykernel(function(installed, err)
        if not installed then
            notify("Cannot install kernel: " .. (err or "ipykernel not available"), vim.log.levels.ERROR)
            if on_complete then on_complete(false, err) end
            return
        end

        local env = M.get_python_env()
        kernel_name = kernel_name or env.name

        local cmd = string.format(
            'python3 -m ipykernel install --user --name="%s" --display-name="%s" 2>&1',
            kernel_name,
            kernel_name .. " (" .. env.version .. ")"
        )

        if env.prefix ~= "" and vim.fn.executable(env.prefix .. "/bin/python") == 1 then
            cmd = env.prefix .. "/bin/python -m ipykernel install --user --name=\"" .. kernel_name .. "\" --display-name=\"" .. kernel_name .. " (" .. env.version .. ")\" 2>&1"
        end

        notify("Creating kernel '" .. kernel_name .. "'...", vim.log.levels.INFO)

        local handle = io.popen(cmd)
        if not handle then
            notify("Failed to create kernel: could not run ipykernel", vim.log.levels.ERROR)
            if on_complete then on_complete(false, "Failed to run ipykernel") end
            return
        end

        local output = handle:read("*a")
        local success = handle:close()

        if success then
            notify("Kernel '" .. kernel_name .. "' installed successfully!", vim.log.levels.INFO)
            if on_complete then on_complete(true, nil) end
        else
            notify("Failed to install kernel: " .. output, vim.log.levels.ERROR)
            if on_complete then on_complete(false, output) end
        end
    end)
end

--- List available Jupyter kernels
function M.list_kernels()
    local kernels = {}

    local paths = {}
    table.insert(paths, vim.fn.stdpath("data"))
    table.insert(paths, vim.fn.stdpath("config"))

    for _, base_path in ipairs(paths) do
        local kernel_dir = base_path .. "/kernels"
        if vim.fn.isdirectory(kernel_dir) == 1 then
            local dirs = vim.fn.readdir(kernel_dir)
            for _, dir in ipairs(dirs) do
                local kernel_json = kernel_dir .. "/" .. dir .. "/kernel.json"
                if vim.fn.filereadable(kernel_json) == 1 then
                    local lines = vim.fn.readfile(kernel_json)
                    if #lines > 0 then
                        local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
                        if ok and data then
                            table.insert(kernels, {
                                name = dir,
                                display_name = data.display_name or dir,
                                language = data.language or "unknown",
                                path = kernel_dir .. "/" .. dir,
                            })
                        end
                    end
                end
            end
        end
    end

    return kernels
end

--- Remove a kernel
--- @param kernel_name string Name of kernel to remove
--- @param on_complete? function Callback when complete
function M.remove_kernel(kernel_name, on_complete)
    local notify = vim.notify or print

    if not kernel_name or #kernel_name == 0 then
        notify("Kernel name required", vim.log.levels.ERROR)
        if on_complete then on_complete(false, "Kernel name required") end
        return
    end

    local cmd = string.format('jupyter kernelspec remove "%s" -f 2>&1', kernel_name)

    local handle = io.popen(cmd)
    if not handle then
        notify("Failed to remove kernel: could not run jupyter", vim.log.levels.ERROR)
        if on_complete then on_complete(false, "Failed to run jupyter") end
        return
    end

    local output = handle:read("*a")
    local success = handle:close()

    if success then
        notify("Kernel '" .. kernel_name .. "' removed", vim.log.levels.INFO)
        if on_complete then on_complete(true, nil) end
    else
        notify("Failed to remove kernel: " .. output, vim.log.levels.ERROR)
        if on_complete then on_complete(false, output) end
    end
end

--- Install kernel for current virtual environment
function M.install_venv_kernel()
    local env = M.get_python_env()
    if env.prefix == "" then
        vim.notify("No virtual environment detected. Activate a venv first or specify a kernel name.", vim.log.levels.WARN)
        return
    end

    M.install_kernel(env.name)
end

return M