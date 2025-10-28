-- programs/digDown.lua
-- Mines down a specified depth and returns to surface
-- Refactored to use worker library

local SwarmWorker = require("lib.swarm_worker_lib")

-- Get command line arguments
local args = {...}

-- Get depth from args
local depth = SwarmWorker.getNumericArg(args, 1, 1, 1000)
if not depth then
    SwarmWorker.sendStatus("Usage: digDown <depth>", false)
    return
end

-- Initialize session
SwarmWorker.initSession(args)
SwarmWorker.sendStatus("Mining " .. depth .. " blocks down", true)

-- Create progress tracker
local progress = SwarmWorker.ProgressTracker.new(depth * 2, 10) -- *2 for down and up

-- Create mining task
local miningTask = SwarmWorker.Task.new("Deep Mining", "Mine down " .. depth .. " blocks and return")

-- Add mining steps
miningTask:addStep("Prepare for mining", function()
    -- Initial fuel check
    local hasEnough, message = SwarmWorker.ensureFuel(depth * 2 + 50)
    if not hasEnough then
        error("Insufficient fuel: " .. message)
    end
    
    SwarmWorker.sendStatus("Fuel sufficient for operation", true)
    return true
end)

miningTask:addStep("Mine downward", function()
    for i = 1, depth do
        -- Ensure fuel before each move
        local hasEnough, message = SwarmWorker.ensureFuel()
        if not hasEnough then
            SwarmWorker.sendStatus("Stopped at " .. (i-1) .. " blocks: " .. message, false)
            return false
        end
        
        -- Dig and move down
        local success, err = SwarmWorker.digDirection("down", 5)
        if not success then
            SwarmWorker.sendStatus("Could not dig down at depth " .. i .. ": " .. err, false)
            return false
        end
        
        if not SwarmWorker.down() then
            SwarmWorker.sendStatus("Could not move down at depth " .. i, false)
            return false
        end
        
        progress:increment()
        
        -- Check for valuable blocks around us occasionally
        if i % 5 == 0 then
            SwarmWorker.reportPosition()
        end
    end
    
    SwarmWorker.sendStatus("Reached target depth: " .. depth, true)
    return true
end)

miningTask:addStep("Return to surface", function()
    SwarmWorker.sendStatus("Returning to surface...", true)
    
    for i = 1, depth do
        -- Ensure fuel
        local hasEnough, message = SwarmWorker.ensureFuel()
        if not hasEnough then
            SwarmWorker.sendStatus("Stranded at depth " .. (depth - i + 1) .. ": " .. message, false)
            return false
        end
        
        if not SwarmWorker.up() then
            SwarmWorker.sendStatus("Could not move up from depth " .. (depth - i + 1), false)
            return false
        end
        
        progress:increment()
        
        -- Progress report
        if i % 10 == 0 then
            SwarmWorker.sendStatus("Ascending: " .. i .. "/" .. depth .. " blocks", true)
        end
    end
    
    SwarmWorker.sendStatus("Returned to surface", true)
    return true
end)

miningTask:addStep("Report final status", function()
    local inventoryInfo = SwarmWorker.getInventoryInfo()
    local fuelRemaining = turtle.getFuelLevel()
    
    local summary = string.format("Mining complete! Blocks: %d, Items collected: %d, Fuel remaining: %s", 
                                 depth, inventoryInfo.totalItems, tostring(fuelRemaining))
    
    SwarmWorker.sendStatus(summary, true)
    return true
end)

-- Execute the task
local success, err = miningTask:execute()

-- End session with final status
if success then
    SwarmWorker.endSession(true, "Deep mining operation completed successfully")
else
    SwarmWorker.endSession(false, "Mining operation failed: " .. tostring(err))
end