-- Simple Test Framework for Swarmer
-- Provides assertion utilities and test runner functionality

local TestFramework = {}

-- Test statistics
local stats = {
    total = 0,
    passed = 0,
    failed = 0,
    errors = 0
}

-- Test results storage
local results = {}

-- Reset statistics
function TestFramework.reset()
    stats = {
        total = 0,
        passed = 0,
        failed = 0,
        errors = 0
    }
    results = {}
end

-- Assertion functions
function TestFramework.assert(condition, message)
    stats.total = stats.total + 1
    message = message or "Assertion failed"
    
    if condition then
        stats.passed = stats.passed + 1
        return true
    else
        stats.failed = stats.failed + 1
        table.insert(results, {
            type = "assertion",
            message = message,
            passed = false
        })
        return false
    end
end

function TestFramework.assertEqual(actual, expected, message)
    stats.total = stats.total + 1
    message = message or string.format("Expected %s, got %s", tostring(expected), tostring(actual))
    
    local passed = actual == expected
    if passed then
        stats.passed = stats.passed + 1
        return true
    else
        stats.failed = stats.failed + 1
        table.insert(results, {
            type = "equal",
            message = message,
            expected = expected,
            actual = actual,
            passed = false
        })
        return false
    end
end

function TestFramework.assertNotEqual(actual, expected, message)
    stats.total = stats.total + 1
    message = message or string.format("Expected not %s, but got %s", tostring(expected), tostring(actual))
    
    local passed = actual ~= expected
    if passed then
        stats.passed = stats.passed + 1
        return true
    else
        stats.failed = stats.failed + 1
        table.insert(results, {
            type = "not_equal",
            message = message,
            expected = expected,
            actual = actual,
            passed = false
        })
        return false
    end
end

function TestFramework.assertNil(value, message)
    stats.total = stats.total + 1
    message = message or string.format("Expected nil, got %s", tostring(value))
    
    local passed = value == nil
    if passed then
        stats.passed = stats.passed + 1
        return true
    else
        stats.failed = stats.failed + 1
        table.insert(results, {
            type = "nil",
            message = message,
            actual = value,
            passed = false
        })
        return false
    end
end

function TestFramework.assertNotNil(value, message)
    stats.total = stats.total + 1
    message = message or "Expected non-nil value, got nil"
    
    local passed = value ~= nil
    if passed then
        stats.passed = stats.passed + 1
        return true
    else
        stats.failed = stats.failed + 1
        table.insert(results, {
            type = "not_nil",
            message = message,
            passed = false
        })
        return false
    end
end

function TestFramework.assertType(value, expectedType, message)
    stats.total = stats.total + 1
    message = message or string.format("Expected type %s, got %s", expectedType, type(value))
    
    local passed = type(value) == expectedType
    if passed then
        stats.passed = stats.passed + 1
        return true
    else
        stats.failed = stats.failed + 1
        table.insert(results, {
            type = "type_check",
            message = message,
            expected = expectedType,
            actual = type(value),
            passed = false
        })
        return false
    end
end

function TestFramework.assertTrue(value, message)
    return TestFramework.assertEqual(value, true, message or "Expected true")
end

function TestFramework.assertFalse(value, message)
    return TestFramework.assertEqual(value, false, message or "Expected false")
end

function TestFramework.assertError(func, message)
    stats.total = stats.total + 1
    message = message or "Expected function to raise an error"
    
    local success, err = pcall(func)
    local passed = not success
    
    if passed then
        stats.passed = stats.passed + 1
        return true
    else
        stats.failed = stats.failed + 1
        table.insert(results, {
            type = "error",
            message = message,
            passed = false
        })
        return false
    end
end

function TestFramework.assertNoError(func, message)
    stats.total = stats.total + 1
    message = message or "Expected function to not raise an error"
    
    local success, err = pcall(func)
    local passed = success
    
    if passed then
        stats.passed = stats.passed + 1
        return true
    else
        stats.errors = stats.errors + 1
        table.insert(results, {
            type = "no_error",
            message = message .. " (Error: " .. tostring(err) .. ")",
            error = err,
            passed = false
        })
        return false
    end
end

-- Test suite runner
function TestFramework.runSuite(suiteName, tests)
    print("\n" .. string.rep("=", 60))
    print("Running test suite: " .. suiteName)
    print(string.rep("=", 60))
    
    local suiteStats = {
        total = 0,
        passed = 0,
        failed = 0,
        errors = 0
    }
    
    for testName, testFunc in pairs(tests) do
        print("\n  Test: " .. testName)
        local success, err = pcall(function()
            testFunc()
        end)
        
        suiteStats.total = suiteStats.total + 1
        
        if success then
            suiteStats.passed = suiteStats.passed + 1
            print("    ✓ PASSED")
        else
            suiteStats.errors = suiteStats.errors + 1
            print("    ✗ ERROR: " .. tostring(err))
        end
    end
    
    print("\n" .. string.rep("-", 60))
    print(string.format("Suite Results: %d/%d passed, %d failed, %d errors",
        suiteStats.passed, suiteStats.total, suiteStats.failed, suiteStats.errors))
    print(string.rep("=", 60))
    
    return suiteStats
end

-- Get statistics
function TestFramework.getStats()
    return {
        total = stats.total,
        passed = stats.passed,
        failed = stats.failed,
        errors = stats.errors
    }
end

-- Get results
function TestFramework.getResults()
    return results
end

-- Print summary
function TestFramework.printSummary()
    local s = TestFramework.getStats()
    print("\n" .. string.rep("=", 60))
    print("TEST SUMMARY")
    print(string.rep("=", 60))
    print(string.format("Total tests: %d", s.total))
    print(string.format("Passed: %d", s.passed))
    print(string.format("Failed: %d", s.failed))
    print(string.format("Errors: %d", s.errors))
    
    if s.failed > 0 or s.errors > 0 then
        print("\nFAILURES:")
        for _, result in ipairs(results) do
            if not result.passed then
                print("  ✗ " .. result.message)
                if result.expected and result.actual then
                    print("    Expected: " .. tostring(result.expected))
                    print("    Actual: " .. tostring(result.actual))
                end
            end
        end
    end
    
    print(string.rep("=", 60))
    
    return s.failed == 0 and s.errors == 0
end

return TestFramework

