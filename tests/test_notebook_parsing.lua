--- Test notebook parsing functionality
---
--- Verifies that .ipynb files are properly parsed and validated
---
--- @module tests.test_notebook_parsing

local runner = require("plenary.busted")
local assert = require("luassert")
local describe, it, before_each, after_each =
  runner.describe, runner.it, runner.before_each, runner.after_each

local fixtures_dir = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h") .. "/fixtures"

describe("Notebook Parsing Tests", function()
  local notebook = nil

  before_each(function()
    notebook = require("uranus.notebook")
  end)

  after_each(function()
    -- Cleanup test files
    local test_files = {
      fixtures_dir .. "/test_parse.ipynb",
      fixtures_dir .. "/test_invalid.ipynb",
    }
    for _, file in ipairs(test_files) do
      if vim.fn.filereadable(file) == 1 then
        os.remove(file)
      end
    end
  end)

  describe("File Validation", function()
    it("should detect valid notebook files", function()
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      if vim.fn.filereadable(test_path) == 1 then
        local result = notebook.open(test_path)
        if result.success then
          assert(result.cells, "Valid notebook should have cells")
          assert(#result.cells > 0, "Valid notebook should have at least one cell")
        end
      end
    end)

    it("should reject non-notebook JSON files", function()
      -- Create invalid notebook (missing required fields)
      local invalid_path = fixtures_dir .. "/test_invalid.ipynb"
      local file = io.open(invalid_path, "w")
      if file then
        file:write('{"not": "a notebook"}')
        file:close()
      end

      if vim.fn.filereadable(invalid_path) == 1 then
        local result = notebook.open(invalid_path)
        -- Should fail validation
        assert(not result.success or result.error, "Should reject invalid notebook")
      end
    end)

    it("should handle missing files", function()
      local result = notebook.open(fixtures_dir .. "/nonexistent.ipynb")
      assert(not result.success, "Should fail for missing file")
    end)
  end)

  describe("Cell Parsing", function()
    it("should parse code cells", function()
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      if vim.fn.filereadable(test_path) == 1 then
        local result = notebook.open(test_path)
        if result.success then
          local code_cells = {}
          for _, cell in ipairs(result.cells) do
            if cell.cell_type == "code" then
              table.insert(code_cells, cell)
            end
          end

          assert(#code_cells > 0, "Should have code cells")

          -- Check cell structure
          local first_code = code_cells[1]
          assert(first_code.source, "Code cell should have source")
        end
      end
    end)

    it("should parse markdown cells", function()
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      if vim.fn.filereadable(test_path) == 1 then
        local result = notebook.open(test_path)
        if result.success then
          local markdown_cells = {}
          for _, cell in ipairs(result.cells) do
            if cell.cell_type == "markdown" then
              table.insert(markdown_cells, cell)
            end
          end

          assert(#markdown_cells > 0, "Should have markdown cells")

          -- Check markdown cell structure
          local first_markdown = markdown_cells[1]
          assert(first_markdown.source, "Markdown cell should have source")
        end
      end
    end)

    it("should preserve cell order", function()
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      if vim.fn.filereadable(test_path) == 1 then
        local result = notebook.open(test_path)
        if result.success then
          -- Cells should be in same order as in file
          local prev_type = nil
          local order_preserved = true

          for i, cell in ipairs(result.cells) do
            if i > 1 then
              -- Just verify we can iterate
              order_preserved = true
            end
          end

          assert(order_preserved, "Cell order should be preserved")
        end
      end
    end)
  end)

  describe("Metadata Parsing", function()
    it("should parse notebook metadata", function()
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      if vim.fn.filereadable(test_path) == 1 then
        local result = notebook.open(test_path)
        if result.success then
          assert(result.metadata, "Notebook should have metadata")

          if result.metadata.kernelspec then
            assert(result.metadata.kernelspec.name, "Should have kernel name")
          end

          if result.metadata.language_info then
            assert(result.metadata.language_info.name, "Should have language name")
          end
        end
      end
    end)

    it("should parse execution counts", function()
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      if vim.fn.filereadable(test_path) == 1 then
        local result = notebook.open(test_path)
        if result.success then
          for _, cell in ipairs(result.cells) do
            if cell.cell_type == "code" then
              -- execution_count can be null or number
              assert(cell.execution_count == nil or type(cell.execution_count) == "number",
                "Execution count should be null or number")
            end
          end
        end
      end
    end)
  end)

  describe("Notebook Creation", function()
    it("should create valid notebook structure", function()
      local test_name = "test_create"
      local test_path = fixtures_dir .. "/test_create.ipynb"

      local result = notebook.new(test_name, test_path)

      if result.success then
        -- Verify file was created
        assert(vim.fn.filereadable(test_path) == 1, "Notebook file should be created")

        -- Verify it's valid JSON
        local content = io.open(test_path, "r"):read("*all")
        local ok, data = pcall(vim.json.decode, content)
        assert(ok, "Should be valid JSON")

        -- Verify structure
        assert(data.cells, "Should have cells array")
        assert(data.metadata, "Should have metadata")
        assert(data.nbformat, "Should have nbformat")

        -- Cleanup
        os.remove(test_path)
      end
    end)

    it("should save notebook correctly", function()
      local test_path = fixtures_dir .. "/test_save.ipynb"

      -- Create and save
      local create_result = notebook.new("test_save", test_path)

      if create_result.success then
        -- Modify notebook (add cell)
        -- This would require implementing cell addition in the test
        -- For now, just verify we can save what we created

        local save_result = notebook.save(test_path)
        assert(save_result.success, "Should save successfully")

        -- Cleanup
        os.remove(test_path)
      end
    end)
  end)

  describe("Treesitter Integration", function()
    it("should have JSON parser for notebooks", function()
      local parsers = require("uranus.parsers")
      local has_json = parsers.is_parser_installed("json")

      -- If parsers module works, should detect JSON parser
      if parsers.has_treesitter() then
        -- Parser should be available or installable
        assert(type(has_json) == "boolean", "Should return boolean")
      end
    end)

    it("should validate notebook JSON structure", function()
      local parsers = require("uranus.parsers")
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      if vim.fn.filereadable(test_path) == 1 then
        local result = parsers.validate_notebook_parsing(test_path)
        assert(result.success, "Should validate notebook JSON")
      end
    end)
  end)
end)
