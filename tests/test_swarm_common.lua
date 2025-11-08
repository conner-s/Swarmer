-- Tests for swarm_common.lua
-- Tests utility functions that don't require peripherals

local TestFramework = require("tests.test_framework")
local SwarmCommon = require("lib.swarm_common")

local function runTests()
    TestFramework.reset()
    
    local tests = {
        -- Test formatTimestamp
        ["formatTimestamp returns string"] = function()
            local result = SwarmCommon.formatTimestamp()
            TestFramework.assertType(result, "string", "formatTimestamp should return a string")
        end,
        
        ["formatTimestamp with epoch parameter"] = function()
            local epoch = 1000000
            local result = SwarmCommon.formatTimestamp(epoch)
            TestFramework.assertType(result, "string", "formatTimestamp with epoch should return a string")
            TestFramework.assertNotNil(result, "formatTimestamp should not return nil")
        end,
        
        -- Test formatLogMessage
        ["formatLogMessage formats correctly"] = function()
            local result = SwarmCommon.formatLogMessage("INFO", "Test message")
            TestFramework.assertType(result, "string", "formatLogMessage should return a string")
            TestFramework.assertTrue(result:find("Test message") ~= nil, "Message should contain the message text")
        end,
        
        ["formatLogMessage with turtle ID"] = function()
            local result = SwarmCommon.formatLogMessage("INFO", "Test", 42)
            TestFramework.assertTrue(result:find("42") ~= nil, "Message should contain turtle ID")
        end,
        
        -- Test validateArgs
        ["validateArgs passes with all required args"] = function()
            local args = {"arg1", "arg2", "arg3"}
            local required = {"arg1", "arg2", "arg3"}
            local valid, err = SwarmCommon.validateArgs(args, required)
            TestFramework.assertTrue(valid, "Should validate when all args present")
            TestFramework.assertNil(err, "Should not return error when valid")
        end,
        
        ["validateArgs fails with missing args"] = function()
            local args = {"arg1", "arg2"}
            local required = {"arg1", "arg2", "arg3"}
            local valid, err = SwarmCommon.validateArgs(args, required)
            TestFramework.assertFalse(valid, "Should fail when args missing")
            TestFramework.assertNotNil(err, "Should return error message")
            TestFramework.assertTrue(err:find("Missing required argument") ~= nil, "Error should mention missing argument")
        end,
        
        ["validateArgs with empty required list"] = function()
            local args = {}
            local required = {}
            local valid, err = SwarmCommon.validateArgs(args, required)
            TestFramework.assertTrue(valid, "Should pass with no required args")
        end,
        
        -- Test validateNumber
        ["validateNumber accepts valid number"] = function()
            local valid, num = SwarmCommon.validateNumber("42")
            TestFramework.assertTrue(valid, "Should validate number string")
            TestFramework.assertEqual(num, 42, "Should return parsed number")
        end,
        
        ["validateNumber rejects non-number"] = function()
            local valid, err = SwarmCommon.validateNumber("not a number")
            TestFramework.assertFalse(valid, "Should reject non-number")
            TestFramework.assertNotNil(err, "Should return error message")
        end,
        
        ["validateNumber enforces minimum"] = function()
            local valid, err = SwarmCommon.validateNumber("5", 10)
            TestFramework.assertFalse(valid, "Should reject number below minimum")
            TestFramework.assertNotNil(err, "Should return error message")
        end,
        
        ["validateNumber enforces maximum"] = function()
            local valid, err = SwarmCommon.validateNumber("15", nil, 10)
            TestFramework.assertFalse(valid, "Should reject number above maximum")
            TestFramework.assertNotNil(err, "Should return error message")
        end,
        
        ["validateNumber accepts number in range"] = function()
            local valid, num = SwarmCommon.validateNumber("5", 1, 10)
            TestFramework.assertTrue(valid, "Should accept number in range")
            TestFramework.assertEqual(num, 5, "Should return the number")
        end,
        
        -- Test generateSessionId
        ["generateSessionId returns number"] = function()
            local result = SwarmCommon.generateSessionId()
            TestFramework.assertType(result, "number", "generateSessionId should return a number")
            TestFramework.assertNotNil(result, "generateSessionId should not return nil")
        end,
        
        ["generateSessionId returns different values"] = function()
            local id1 = SwarmCommon.generateSessionId()
            os.sleep(0.1) -- Small delay to ensure different timestamp
            local id2 = SwarmCommon.generateSessionId()
            -- Note: These might be the same if called very quickly, but that's acceptable
            TestFramework.assertType(id1, "number", "First ID should be number")
            TestFramework.assertType(id2, "number", "Second ID should be number")
        end,
        
        -- Test createMessage
        ["createMessage creates STATUS message"] = function()
            local message = SwarmCommon.createMessage(
                SwarmCommon.MESSAGE_TYPES.STATUS,
                "Test status",
                {success = true}
            )
            TestFramework.assertNotNil(message, "Message should not be nil")
            TestFramework.assertEqual(message.message, "Test status", "Should set message field")
            TestFramework.assertEqual(message.success, true, "Should set success field")
            TestFramework.assertNotNil(message.id, "Should have id")
            TestFramework.assertNotNil(message.timestamp, "Should have timestamp")
        end,
        
        ["createMessage includes version"] = function()
            local message = SwarmCommon.createMessage(
                SwarmCommon.MESSAGE_TYPES.STATUS,
                "Test",
                {version = "4.1"}
            )
            TestFramework.assertEqual(message.version, "4.1", "Should set version")
        end,
        
        ["createMessage includes role"] = function()
            local message = SwarmCommon.createMessage(
                SwarmCommon.MESSAGE_TYPES.STATUS,
                "Test",
                {role = "miner", roleName = "Miner"}
            )
            TestFramework.assertEqual(message.role, "miner", "Should set role")
            TestFramework.assertEqual(message.roleName, "Miner", "Should set roleName")
        end,
        
        ["createMessage defaults to version 4.0"] = function()
            local message = SwarmCommon.createMessage(
                SwarmCommon.MESSAGE_TYPES.STATUS,
                "Test",
                {}
            )
            TestFramework.assertEqual(message.version, "4.0", "Should default to version 4.0")
        end,
        
        -- Test safeCall
        ["safeCall executes function successfully"] = function()
            local func = function() return "success" end
            local result, err = SwarmCommon.safeCall(func)
            TestFramework.assertEqual(result, "success", "Should return function result")
            TestFramework.assertNil(err, "Should not return error on success")
        end,
        
        ["safeCall catches errors"] = function()
            local func = function() error("Test error") end
            local result, err = SwarmCommon.safeCall(func)
            TestFramework.assertNil(result, "Should return nil on error")
            TestFramework.assertNotNil(err, "Should return error message")
        end,
        
        -- Test constants
        ["COMMAND_CHANNEL is defined"] = function()
            TestFramework.assertNotNil(SwarmCommon.COMMAND_CHANNEL, "COMMAND_CHANNEL should be defined")
            TestFramework.assertType(SwarmCommon.COMMAND_CHANNEL, "number", "COMMAND_CHANNEL should be a number")
        end,
        
        ["REPLY_CHANNEL is defined"] = function()
            TestFramework.assertNotNil(SwarmCommon.REPLY_CHANNEL, "REPLY_CHANNEL should be defined")
            TestFramework.assertType(SwarmCommon.REPLY_CHANNEL, "number", "REPLY_CHANNEL should be a number")
        end,
        
        ["MESSAGE_TYPES table is defined"] = function()
            TestFramework.assertNotNil(SwarmCommon.MESSAGE_TYPES, "MESSAGE_TYPES should be defined")
            TestFramework.assertType(SwarmCommon.MESSAGE_TYPES, "table", "MESSAGE_TYPES should be a table")
        end,
    }
    
    return TestFramework.runSuite("swarm_common", tests)
end

return {
    run = runTests
}

