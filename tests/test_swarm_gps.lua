-- Tests for swarm_gps.lua
-- Tests GPS utility functions (some tests may require GPS to be available)

local TestFramework = require("tests.test_framework")
local SwarmGPS = require("lib.swarm_gps")

local function runTests()
    TestFramework.reset()
    
    local tests = {
        -- Test formatPosition
        ["formatPosition formats position correctly"] = function()
            local pos = {x = 10, y = 20, z = 30}
            local result = SwarmGPS.formatPosition(pos)
            TestFramework.assertType(result, "string", "Should return string")
            TestFramework.assertTrue(result:find("10") ~= nil, "Should contain x coordinate")
            TestFramework.assertTrue(result:find("20") ~= nil, "Should contain y coordinate")
            TestFramework.assertTrue(result:find("30") ~= nil, "Should contain z coordinate")
        end,
        
        ["formatPosition handles nil"] = function()
            local result = SwarmGPS.formatPosition(nil)
            TestFramework.assertEqual(result, "Unknown", "Should return 'Unknown' for nil")
        end,
        
        ["formatPosition handles missing x"] = function()
            local pos = {y = 20, z = 30}
            local result = SwarmGPS.formatPosition(pos)
            TestFramework.assertEqual(result, "Unknown", "Should return 'Unknown' for invalid position")
        end,
        
        ["formatPosition handles empty table"] = function()
            local result = SwarmGPS.formatPosition({})
            TestFramework.assertEqual(result, "Unknown", "Should return 'Unknown' for empty table")
        end,
        
        -- Test getCurrentPosition (may fail if GPS not available, but that's okay)
        ["getCurrentPosition function exists"] = function()
            TestFramework.assertNotNil(SwarmGPS.getCurrentPosition, "getCurrentPosition should exist")
            TestFramework.assertType(SwarmGPS.getCurrentPosition, "function", "getCurrentPosition should be a function")
        end,
        
        -- Note: getCurrentPosition requires GPS to be available, so we test the function exists
        -- but don't test its return value as it depends on the environment
    }
    
    return TestFramework.runSuite("swarm_gps", tests)
end

return {
    run = runTests
}

