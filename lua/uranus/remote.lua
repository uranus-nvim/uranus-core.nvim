--- Uranus remote kernel management
--- Start/stop kernels from Neovim and manage Jupyter Server connections
---
--- @module uranus.remote

local M = {}

local config = {
    server_url = "http://localhost:8888",
    token = "",
}

local ns_remote = vim.api.nvim_create_namespace("uranus_remote")

local function get_uranus()
    local ok, uranus = pcall(require, "uranus")
    return ok and uranus or nil
end

function M.configure(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_config()
    return config
end

function M.set_server(url)
    config.server_url = url
end

function M.set_token(token)
    config.token = token
end

--- List available servers
function M.list_servers()
    local servers = {
        { url = "http://localhost:8888", name = "Local Jupyter" },
        { url = "http://localhost:8889", name = "Jupyter Lab" },
    }
    return servers
end

--- Connect to server
function M.connect_server(url)
    url = url or config.server_url
    local u = get_uranus()
    if not u then
        return { success = false, error = { code = "NO_URANUS", message = "Uranus not available" } }
    end
    
    return u.connect_server(url)
end

--- Start a new kernel on remote server
--- @param kernel_name string Kernel name (e.g., "python3")
--- @param server_url string Server URL
function M.start_kernel(kernel_name, server_url)
    server_url = server_url or config.server_url
    kernel_name = kernel_name or "python3"
    
    local code = string.format([[
import requests
import json
url = "%s/api/kernels"
headers = {"Authorization": "token %s"}
payload = {"name": "%s"}
resp = requests.post(url, json=payload, headers=headers)
print(json.dumps(resp.json()))
]], server_url, config.token, kernel_name)
    
    local u = get_uranus()
    if not u then
        return { success = false, error = { code = "NO_URANUS", message = "Uranus not available" } }
    end
    
    return u.execute(code)
end

--- Stop a kernel on remote server
--- @param kernel_id string Kernel ID
--- @param server_url string Server URL
function M.stop_kernel(kernel_id, server_url)
    server_url = server_url or config.server_url
    
    local code = string.format([[
import requests
import json
url = "%s/api/kernels/%s"
headers = {"Authorization": "token %s"}
resp = requests.delete(url, headers=headers)
print(resp.status_code)
]], server_url, kernel_id, config.token)
    
    local u = get_uranus()
    if not u then
        return { success = false, error = { code = "NO_URANUS", message = "Uranus not available" } }
    end
    
    return u.execute(code)
end

--- List kernels on remote server
--- @param server_url string Server URL
function M.list_remote_kernels(server_url)
    server_url = server_url or config.server_url
    
    local u = get_uranus()
    if not u then
        return { success = false, error = { code = "NO_URANUS", message = "Uranus not available" } }
    end
    
    return u.list_remote_kernels(server_url)
end

--- Show remote kernel picker UI
function M.pick_remote_kernel()
    local servers = M.list_servers()
    
    vim.ui.select(servers, {
        prompt = "Select Jupyter Server: ",
        format_item = function(s)
            return s.name .. " (" .. s.url .. ")"
        end,
    }, function(choice)
        if choice then
            M.connect_server(choice.url)
        end
    end)
end

--- Show kernel manager UI
function M.show_manager()
    local u = get_uranus()
    if not u then
        vim.notify("Uranus not available", vim.log.levels.ERROR)
        return
    end
    
    local lines = { "=== Remote Kernel Manager ===", "" }
    
    local servers = M.list_servers()
    for _, server in ipairs(servers) do
        table.insert(lines, "Server: " .. server.name .. " (" .. server.url .. ")")
    end
    
    table.insert(lines, "")
    table.insert(lines, "Commands:")
    table.insert(lines, "  :UranusRemoteStart - Start new kernel")
    table.insert(lines, "  :UranusRemoteStop - Stop kernel")
    table.insert(lines, "  :UranusRemoteList - List remote kernels")
    
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = 60,
        height = #lines + 2,
        row = 5,
        col = 10,
        style = "minimal",
        border = "rounded",
        title = "Remote Kernel Manager",
        title_pos = "center",
    })
end

return M