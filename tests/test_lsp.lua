--- LSP module tests for Uranus
---
--- @module tests.test_lsp

local function wait_for_timeout(fn, timeout_ms)
  local start = vim.loop.now()
  while vim.loop.now() - start < timeout_ms do
    local result = fn()
    if result then
      return result
    end
    vim.wait(10)
  end
  return fn()
end

describe("Uranus LSP Module", function()
  local lsp = nil
  
  before_each(function()
    lsp = require("uranus.lsp")
  end)

  describe("Configuration", function()
    it("should have default config", function()
      local config = lsp.get_config()
      assert.is_table(config)
      assert.is_boolean(config.prefer_static)
      assert.is_boolean(config.merge_with_kernel)
    end)

    it("should allow configuration update", function()
      lsp.configure({ prefer_static = false })
      local config = lsp.get_config()
      assert.is_false(config.prefer_static)
    end)
  end)

  describe("Client Detection", function()
    it("should detect Python LSP clients", function()
      local clients = lsp.get_clients()
      assert.is_table(clients)
      
      for _, client in ipairs(clients) do
        local name = client.name:lower()
        assert.is_true(
          name:match("py") or name:match("ty") or name:match("ruff"),
          "Client name should be Python-related"
        )
      end
    end)

    it("should check if LSP is available", function()
      local available = lsp.is_available()
      assert.is_boolean(available)
    end)

    it("should return first client", function()
      local client = lsp.get_first_client()
      if client then
        assert.is_number(client.id)
        assert.is_string(client.name)
      end
    end)
  end)

  describe("Status", function()
    it("should return status info", function()
      local status = lsp.status()
      assert.is_table(status)
      assert.is_boolean(status.running)
      assert.is_table(status.clients)
    end)
  end)

  describe("Hover", function()
    it("should return nil when no LSP available", function()
      local result = lsp.get_lsp_hover("test")
      if not lsp.is_available() then
        assert.is_nil(result)
      end
    end)

    it("should return merged hover info", function()
      local word = "test"
      local result = lsp.hover(word)
      assert.is_table(result)
    end)
  end)

  describe("Definition", function()
    it("should return nil when no LSP available", function()
      local result = lsp.get_lsp_definition("test")
      if not lsp.is_available() then
        assert.is_nil(result)
      end
    end)
  end)

  describe("References", function()
    it("should return empty when no LSP available", function()
      local result = lsp.get_lsp_references("test")
      assert.is_table(result)
    end)
  end)

  describe("Completions", function()
    it("should return empty when no LSP available", function()
      local result = lsp.get_lsp_completions()
      assert.is_table(result)
    end)
  end)

  describe("Diagnostics", function()
    it("should return diagnostics list", function()
      local result = lsp.get_diagnostics()
      assert.is_table(result)
    end)
  end)

  describe("Kernel Info", function()
    it("should return kernel info when available", function()
      local result = lsp.get_kernel_info("test")
      if result then
        assert.is_table(result)
      end
    end)
  end)

  describe("Capabilites", function()
    it("should return server capabilities", function()
      local caps = lsp.get_capabilities()
      assert.is_table(caps)
    end)
  end)
end)

describe("Uranus LSP Commands", function()
  local lsp = nil
  
  before_each(function()
    lsp = require("uranus.lsp")
  end)

  describe("Navigation", function()
    it("should have goto_definition function", function()
      assert.is_function(lsp.goto_definition)
    end)

    it("should have goto_type_definition function", function()
      assert.is_function(lsp.goto_type_definition)
    end)

    it("should have references function", function()
      assert.is_function(lsp.references)
    end)

    it("should have implementation function", function()
      assert.is_function(lsp.implementation)
    end)
  end)

  describe("Code Actions", function()
    it("should have rename function", function()
      assert.is_function(lsp.rename)
    end)

    it("should have code_action function", function()
      assert.is_function(lsp.code_action)
    end)

    it("should have format function", function()
      assert.is_function(lsp.format)
    end)

    it("should have hover function", function()
      assert.is_function(lsp.hover)
    end)

    it("should have signature_help function", function()
      assert.is_function(lsp.signature_help)
    end)
  end)

  describe("Symbols", function()
    it("should have document_symbol function", function()
      assert.is_function(lsp.document_symbol)
    end)

    it("should have workspace_symbol function", function()
      assert.is_function(lsp.workspace_symbol)
    end)
  end)

  describe("Diagnostics Display", function()
    it("should have diagnostics function", function()
      assert.is_function(lsp.diagnostics)
    end)

    it("should have list_diagnostics function", function()
      assert.is_function(lsp.list_diagnostics)
    end)
  end)
end)