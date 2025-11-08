-- Test Runner for Swarmer
-- Runs all test suites and reports results

print("=" .. string.rep("=", 60))
print("Swarmer Test Suite")
print("=" .. string.rep("=", 60))
print("")

local TestFramework = require("tests.test_framework")

-- List of test suites to run
local testSuites = {
    {name = "swarm_common", module = "tests.test_swarm_common"},
    {name = "swarm_file", module = "tests.test_swarm_file"},
    {name = "swarm_config", module = "tests.test_swarm_config"},
    {name = "swarm_gps", module = "tests.test_swarm_gps"},
    {name = "swarm_ui", module = "tests.test_swarm_ui"},
}

-- Run all test suites
local allPassed = true
local totalStats = {
    total = 0,
    passed = 0,
    failed = 0,
    errors = 0
}

for _, suite in ipairs(testSuites) do
    local success, suiteModule = pcall(require, suite.module)
    
    if not success then
        print("ERROR: Failed to load test suite: " .. suite.name)
        print("  " .. tostring(suiteModule))
        allPassed = false
        totalStats.errors = totalStats.errors + 1
    else
        local success2, stats = pcall(function()
            return suiteModule.run()
        end)
        
        if not success2 then
            print("ERROR: Failed to run test suite: " .. suite.name)
            print("  " .. tostring(stats))
            allPassed = false
            totalStats.errors = totalStats.errors + 1
        elseif stats then
            totalStats.total = totalStats.total + stats.total
            totalStats.passed = totalStats.passed + stats.passed
            totalStats.failed = totalStats.failed + stats.failed
            totalStats.errors = totalStats.errors + stats.errors
            
            if stats.failed > 0 or stats.errors > 0 then
                allPassed = false
            end
        end
    end
end

-- Print final summary
print("\n" .. string.rep("=", 60))
print("FINAL SUMMARY")
print(string.rep("=", 60))
print(string.format("Total tests: %d", totalStats.total))
print(string.format("Passed: %d", totalStats.passed))
print(string.format("Failed: %d", totalStats.failed))
print(string.format("Errors: %d", totalStats.errors))
print(string.rep("=", 60))

if allPassed then
    print("✓ ALL TESTS PASSED")
    return 0
else
    print("✗ SOME TESTS FAILED")
    return 1
end

