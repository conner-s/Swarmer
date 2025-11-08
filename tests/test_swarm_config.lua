-- Tests for swarm_config.lua
-- Tests configuration management and JSON utilities

local TestFramework = require("tests.test_framework")
local SwarmConfig = require("lib.swarm_config")

local TEST_CONFIG_DIR = "tests/test_config"
local TEST_CONFIG_FILE = fs.combine(TEST_CONFIG_DIR, "test_config.json")

local function runTests()
    TestFramework.reset()
    
    -- Clean up test config before starting
    if fs.exists(TEST_CONFIG_FILE) then
        fs.delete(TEST_CONFIG_FILE)
    end
    
    local tests = {
        -- Test serializeJSON
        ["serializeJSON serializes string"] = function()
            local result = SwarmConfig.serializeJSON("test")
            TestFramework.assertType(result, "string", "Should return string")
            TestFramework.assertTrue(result:find("test") ~= nil, "Should contain string value")
        end,
        
        ["serializeJSON serializes number"] = function()
            local result = SwarmConfig.serializeJSON(42)
            TestFramework.assertEqual(result, "42", "Should serialize number correctly")
        end,
        
        ["serializeJSON serializes boolean"] = function()
            local result1 = SwarmConfig.serializeJSON(true)
            local result2 = SwarmConfig.serializeJSON(false)
            TestFramework.assertEqual(result1, "true", "Should serialize true")
            TestFramework.assertEqual(result2, "false", "Should serialize false")
        end,
        
        ["serializeJSON serializes nil"] = function()
            local result = SwarmConfig.serializeJSON(nil)
            TestFramework.assertEqual(result, "null", "Should serialize nil as null")
        end,
        
        ["serializeJSON serializes array"] = function()
            local arr = {1, 2, 3}
            local result = SwarmConfig.serializeJSON(arr)
            TestFramework.assertType(result, "string", "Should return string")
            TestFramework.assertTrue(result:find("1") ~= nil, "Should contain array elements")
        end,
        
        ["serializeJSON serializes table"] = function()
            local tbl = {key = "value", num = 42}
            local result = SwarmConfig.serializeJSON(tbl)
            TestFramework.assertType(result, "string", "Should return string")
            TestFramework.assertTrue(result:find("key") ~= nil, "Should contain keys")
            TestFramework.assertTrue(result:find("value") ~= nil, "Should contain values")
        end,
        
        -- Test writeJSON and readJSON (if textutils available)
        ["writeJSON writes file"] = function()
            local testData = {test = "value", number = 42}
            local success, err = SwarmConfig.writeJSON(TEST_CONFIG_FILE, testData)
            TestFramework.assertTrue(success, "Should write JSON file")
            TestFramework.assertTrue(fs.exists(TEST_CONFIG_FILE), "Config file should exist")
        end,
        
        -- Test init
        ["init creates config directory"] = function()
            SwarmConfig.init()
            TestFramework.assertTrue(fs.exists(SwarmConfig.CONFIG_DIR), "Config directory should exist")
        end,
        
        -- Test load (returns default if no file)
        ["load returns default config when no file exists"] = function()
            local config = SwarmConfig.load()
            TestFramework.assertType(config, "table", "Should return table")
            TestFramework.assertNotNil(config.version, "Should have version")
            TestFramework.assertNotNil(config.worker, "Should have worker config")
        end,
        
        -- Test get
        ["get retrieves nested value"] = function()
            -- This will use default config
            local autoStart = SwarmConfig.get("worker.autoStart")
            TestFramework.assertNotNil(autoStart, "Should retrieve nested value")
        end,
        
        ["get returns default for missing key"] = function()
            local value = SwarmConfig.get("nonexistent.key", "default")
            TestFramework.assertEqual(value, "default", "Should return default value")
        end,
        
        -- Test set and save
        ["set updates config value"] = function()
            local success = SwarmConfig.set("test.value", "test_data")
            TestFramework.assertTrue(success, "Should set config value")
        end,
        
        ["get retrieves set value"] = function()
            SwarmConfig.set("test.retrieve", "retrieved_value")
            local value = SwarmConfig.get("test.retrieve")
            TestFramework.assertEqual(value, "retrieved_value", "Should retrieve set value")
        end,
        
        -- Test constants
        ["CONFIG_DIR is defined"] = function()
            TestFramework.assertNotNil(SwarmConfig.CONFIG_DIR, "CONFIG_DIR should be defined")
            TestFramework.assertType(SwarmConfig.CONFIG_DIR, "string", "CONFIG_DIR should be a string")
        end,
        
        ["CONFIG_FILE is defined"] = function()
            TestFramework.assertNotNil(SwarmConfig.CONFIG_FILE, "CONFIG_FILE should be defined")
            TestFramework.assertType(SwarmConfig.CONFIG_FILE, "string", "CONFIG_FILE should be a string")
        end,
    }
    
    -- Ensure test config directory exists
    if not fs.exists(TEST_CONFIG_DIR) then
        fs.makeDir(TEST_CONFIG_DIR)
    end
    
    return TestFramework.runSuite("swarm_config", tests)
end

return {
    run = runTests
}

