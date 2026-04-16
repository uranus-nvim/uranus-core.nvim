--- Test utilities and shared test framework
--- Provides consistent test patterns across all test files

local TestLib = {}

TestLib.tests_passed = 0
TestLib.tests_failed = 0
TestLib.tests_skipped = 0
TestLib.test_results = {}

function TestLib.reset()
  TestLib.tests_passed = 0
  TestLib.tests_failed = 0
  TestLib.tests_skipped = 0
  TestLib.test_results = {}
end

function TestLib.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    print("[PASS] " .. name)
    TestLib.tests_passed = TestLib.tests_passed + 1
    table.insert(TestLib.test_results, { name = name, status = "pass" })
  else
    print("[FAIL] " .. name .. ": " .. tostring(err))
    TestLib.tests_failed = TestLib.tests_failed + 1
    table.insert(TestLib.test_results, { name = name, status = "fail", error = tostring(err) })
  end
end

function TestLib.skip(name, reason)
  reason = reason or "unknown"
  print("[SKIP] " .. name .. " (" .. tostring(reason) .. ")")
  TestLib.tests_skipped = TestLib.tests_skipped + 1
  table.insert(TestLib.test_results, { name = name, status = "skip", reason = reason })
end

function TestLib.pending(name)
  print("[PEND] " .. name)
  TestLib.tests_skipped = TestLib.tests_skipped + 1
  table.insert(TestLib.test_results, { name = name, status = "pending" })
end

function TestLib.section(name)
  print("\n=== " .. name .. " ===\n")
end

function TestLib.subsection(name)
  print("\n-- " .. name .. " --\n")
end

function TestLib.summary()
  print("\n========================================")
  print(string.format("Results: %d passed, %d failed, %d skipped",
    TestLib.tests_passed, TestLib.tests_failed, TestLib.tests_skipped))
  print(string.format("Total:  %d", TestLib.tests_passed + TestLib.tests_failed + TestLib.tests_skipped))
  print("========================================")
end

function TestLib.results()
  return {
    passed = TestLib.tests_passed,
    failed = TestLib.tests_failed,
    skipped = TestLib.tests_skipped,
    total = TestLib.tests_passed + TestLib.tests_failed + TestLib.tests_skipped,
    success = TestLib.tests_failed == 0
  }
end

function TestLib.assert(condition, message)
  if not condition then
    error(message or "Assertion failed")
  end
end

function TestLib.assert_eq(actual, expected, message)
  if actual ~= expected then
    error(message or string.format("Expected %q but got %q", tostring(expected), tostring(actual)))
  end
end

function TestLib.assert_type(value, typename, message)
  if type(value) ~= typename then
    error(message or string.format("Expected type %s but got %s", typename, type(value)))
  end
end

function TestLib.assert_nil(value, message)
  if value ~= nil then
    error(message or "Expected nil but got " .. tostring(value))
  end
end

function TestLib.assert_not_nil(value, message)
  if value == nil then
    error(message or "Expected non-nil value")
  end
end

function TestLib.run(name, fn)
  TestLib.section(name)
  fn()
  TestLib.summary()
  return TestLib.results()
end

return TestLib