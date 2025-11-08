-- Tests for swarm_ui.lua
-- Tests UI utility functions that don't require terminal/peripherals

local TestFramework = require("tests.test_framework")
local SwarmUI = require("lib.swarm_ui")

local function runTests()
    TestFramework.reset()
    
    local tests = {
        -- Test ResponseBuffer
        ["ResponseBuffer.new creates buffer"] = function()
            local buffer = SwarmUI.ResponseBuffer.new()
            TestFramework.assertNotNil(buffer, "Should create buffer")
            TestFramework.assertType(buffer, "table", "Should return table")
        end,
        
        ["ResponseBuffer.add adds text"] = function()
            local buffer = SwarmUI.ResponseBuffer.new()
            buffer:add("Test message")
            TestFramework.assertEqual(buffer:size(), 1, "Should have one message")
        end,
        
        ["ResponseBuffer.getLatest returns last message"] = function()
            local buffer = SwarmUI.ResponseBuffer.new()
            buffer:add("First")
            buffer:add("Second")
            TestFramework.assertEqual(buffer:getLatest(), "Second", "Should return latest message")
        end,
        
        ["ResponseBuffer.getAll returns all messages"] = function()
            local buffer = SwarmUI.ResponseBuffer.new()
            buffer:add("Message 1")
            buffer:add("Message 2")
            local all = buffer:getAll()
            TestFramework.assertType(all, "table", "Should return table")
            TestFramework.assertEqual(#all, 2, "Should return all messages")
        end,
        
        ["ResponseBuffer.clear removes all messages"] = function()
            local buffer = SwarmUI.ResponseBuffer.new()
            buffer:add("Test")
            buffer:clear()
            TestFramework.assertEqual(buffer:size(), 0, "Should be empty after clear")
        end,
        
        ["ResponseBuffer respects maxLines"] = function()
            local buffer = SwarmUI.ResponseBuffer.new(3)
            buffer:add("1")
            buffer:add("2")
            buffer:add("3")
            buffer:add("4")
            TestFramework.assertEqual(buffer:size(), 3, "Should limit to maxLines")
            TestFramework.assertEqual(buffer:getLatest(), "4", "Should keep latest messages")
        end,
        
        -- Test Menu
        ["Menu.new creates menu"] = function()
            local menu = SwarmUI.Menu.new("Test Menu")
            TestFramework.assertNotNil(menu, "Should create menu")
            TestFramework.assertEqual(menu.title, "Test Menu", "Should set title")
        end,
        
        ["Menu.addOption adds option"] = function()
            local menu = SwarmUI.Menu.new("Test")
            menu:addOption("1", "Option 1", function() end)
            TestFramework.assertNotNil(menu.options["1"], "Should add option")
            TestFramework.assertEqual(menu.options["1"].text, "Option 1", "Should set option text")
        end,
        
        ["Menu.removeOption removes option"] = function()
            local menu = SwarmUI.Menu.new("Test")
            menu:addOption("1", "Option 1", function() end)
            menu:removeOption("1")
            TestFramework.assertNil(menu.options["1"], "Should remove option")
        end,
        
        -- Test THEME
        ["THEME table is defined"] = function()
            TestFramework.assertNotNil(SwarmUI.THEME, "THEME should be defined")
            TestFramework.assertType(SwarmUI.THEME, "table", "THEME should be a table")
        end,
        
        ["THEME has required color properties"] = function()
            TestFramework.assertNotNil(SwarmUI.THEME.background, "Should have background color")
            TestFramework.assertNotNil(SwarmUI.THEME.headerBg, "Should have headerBg color")
            TestFramework.assertNotNil(SwarmUI.THEME.titleBg, "Should have titleBg color")
        end,
        
        -- Test utility functions exist
        ["showProgress function exists"] = function()
            TestFramework.assertNotNil(SwarmUI.showProgress, "showProgress should exist")
            TestFramework.assertType(SwarmUI.showProgress, "function", "showProgress should be a function")
        end,
        
        ["showStatus function exists"] = function()
            TestFramework.assertNotNil(SwarmUI.showStatus, "showStatus should exist")
            TestFramework.assertType(SwarmUI.showStatus, "function", "showStatus should be a function")
        end,
        
        ["promptNumber function exists"] = function()
            TestFramework.assertNotNil(SwarmUI.promptNumber, "promptNumber should exist")
            TestFramework.assertType(SwarmUI.promptNumber, "function", "promptNumber should be a function")
        end,
        
        ["promptChoice function exists"] = function()
            TestFramework.assertNotNil(SwarmUI.promptChoice, "promptChoice should exist")
            TestFramework.assertType(SwarmUI.promptChoice, "function", "promptChoice should be a function")
        end,
        
        ["confirm function exists"] = function()
            TestFramework.assertNotNil(SwarmUI.confirm, "confirm should exist")
            TestFramework.assertType(SwarmUI.confirm, "function", "confirm should be a function")
        end,
    }
    
    return TestFramework.runSuite("swarm_ui", tests)
end

return {
    run = runTests
}

