-- programs/hello.lua
-- Simple test program for provisioning demonstration
-- Refactored to use worker library

local SwarmWorker = require("lib.swarm_worker_lib")

-- Get command line arguments
local args = {...}

-- Initialize session
SwarmWorker.initSession(args)

-- Get turtle info
local turtleId = os.getComputerID()
local position = SwarmWorker.getPosition()
local fuelLevel = turtle.getFuelLevel()

-- Send greeting
SwarmWorker.sendStatus("Hello from turtle #" .. turtleId .. "!", true)

-- Create a simple demo task
local helloTask = SwarmWorker.Task.new("Hello Demo", "Demonstrate worker library features")

helloTask:addStep("System check", function()
    SwarmWorker.sendStatus("System check: All systems operational", true)
    return true
end)

helloTask:addStep("Report status", function()
    SwarmWorker.reportPosition()
    
    local inventoryInfo = SwarmWorker.getInventoryInfo()
    SwarmWorker.sendStatus("Inventory: " .. inventoryInfo.usedSlots .. "/16 slots used", true)
    SwarmWorker.sendStatus("Fuel level: " .. tostring(fuelLevel), true)
    
    return true
end)

helloTask:addStep("Demonstrate movement", function()
    SwarmWorker.sendStatus("Testing safe movement capabilities...", true)
    
    -- Try to move forward and back (safe movement with fuel checking)
    local moved = false
    
    if SwarmWorker.forward(true) then
        SwarmWorker.sendStatus("Forward movement successful", true)
        os.sleep(1)
        
        if SwarmWorker.back(true) then
            SwarmWorker.sendStatus("Returned to original position", true)
            moved = true
        end
    end
    
    if not moved then
        SwarmWorker.sendStatus("Movement blocked or insufficient fuel", true)
    end
    
    return true
end)

helloTask:addStep("Progress demonstration", function()
    SwarmWorker.sendStatus("Demonstrating progress tracking...", true)
    
    local progress = SwarmWorker.ProgressTracker.new(5, 1)
    
    for i = 1, 5 do
        os.sleep(0.5) -- Simulate work
        progress:increment()
    end
    
    SwarmWorker.sendStatus("Progress tracking complete", true)
    return true
end)

helloTask:addStep("Library test complete", function()
    SwarmWorker.sendStatus("All worker library features tested successfully!", true)
    SwarmWorker.sendStatus("This program was deployed via the v3.0 provisioning system", true)
    return true
end)

-- Execute the demonstration task
local success, err = helloTask:execute()

-- End session
if success then
    SwarmWorker.endSession(true, "Hello demo completed successfully")
else
    SwarmWorker.endSession(false, "Demo failed: " .. tostring(err))
end

-- Fallback for standalone mode (when not run through worker system)
if not SwarmWorker.getSession().startTime then
    print("Hello from turtle #" .. turtleId .. "!")
    print("Running in standalone mode")
    print("Worker library features:")
    print("  - Safe movement with fuel checking")
    print("  - Progress tracking")
    print("  - Status reporting")
    print("  - Task framework")
    print("  - Session management")
    print("This program was deployed via the v3.0 provisioning system")
end