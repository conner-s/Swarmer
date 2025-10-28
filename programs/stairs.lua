-- programs/stairs.lua
-- Mines stairs in a specified direction (up or down)
-- Refactored to use worker library

local SwarmWorker = require("lib.swarm_worker_lib")

-- Get command line arguments
local args = {...}

-- Parse arguments
local depth = SwarmWorker.getNumericArg(args, 1, 1, 1000)
local direction = SwarmWorker.getStringArg(args, 2, {"up", "down"}, "up")

if not depth then
    SwarmWorker.sendStatus("Usage: stairs <depth> [up|down]", false)
    return
end

if not direction then
    SwarmWorker.sendStatus("Invalid direction. Use 'up' or 'down'", false)
    return
end

-- Initialize session
SwarmWorker.initSession(args)
SwarmWorker.sendStatus("Mining " .. depth .. " step staircase going " .. direction, true)

-- Create progress tracker
local progress = SwarmWorker.ProgressTracker.new(depth, 10)

-- Staircase building functions
local function buildStaircaseUp(steps, progress)
    for i = 1, steps do
        if not SwarmWorker.ensureFuel() then
            SwarmWorker.sendStatus("Stopped at step " .. i .. " (no fuel)", false)
            return false
        end
        
        -- Dig forward path
        local success, err = SwarmWorker.digDirection("forward", 5)
        if not success then
            SwarmWorker.sendStatus("Could not dig forward at step " .. i .. ": " .. err, false)
        end
        
        -- Move forward
        if not SwarmWorker.forward() then
            SwarmWorker.sendStatus("Could not move forward at step " .. i, false)
            return false
        end
        
        -- Dig above for headroom
        SwarmWorker.digDirection("up", 3) -- Don't fail if can't dig up
        
        -- Move up one level
        if not SwarmWorker.up() then
            SwarmWorker.sendStatus("Could not move up at step " .. i, false)
            return false
        end
        
        progress:increment()
        
        -- Position report every 10 steps
        if i % 10 == 0 then
            SwarmWorker.reportPosition()
        end
    end
    
    return true
end

local function buildStaircaseDown(steps, progress)
    for i = 1, steps do
        if not SwarmWorker.ensureFuel() then
            SwarmWorker.sendStatus("Stopped at step " .. i .. " (no fuel)", false)
            return false
        end
        
        -- Dig forward path
        local success, err = SwarmWorker.digDirection("forward", 5)
        if not success then
            SwarmWorker.sendStatus("Could not dig forward at step " .. i .. ": " .. err, false)
        end
        
        -- Move forward
        if not SwarmWorker.forward() then
            SwarmWorker.sendStatus("Could not move forward at step " .. i, false)
            return false
        end
        
        -- Dig down for the step
        local success, err = SwarmWorker.digDirection("down", 5)
        if not success then
            SwarmWorker.sendStatus("Could not dig down at step " .. i .. ": " .. err, false)
        end
        
        -- Move down one level
        if not SwarmWorker.down() then
            SwarmWorker.sendStatus("Could not move down at step " .. i, false)
            return false
        end
        
        progress:increment()
        
        -- Position report every 10 steps
        if i % 10 == 0 then
            SwarmWorker.reportPosition()
        end
    end
    
    return true
end

-- Create staircase task
local stairTask = SwarmWorker.Task.new("Staircase Mining", "Build " .. direction .. " staircase")

stairTask:addStep("Prepare for staircase", function()
    -- Estimate fuel needed: each step requires movement + digging
    local fuelNeeded = depth * 3 + 50 -- Conservative estimate
    local hasEnough, message = SwarmWorker.ensureFuel(fuelNeeded)
    if not hasEnough then
        error("Insufficient fuel: " .. message)
    end
    
    SwarmWorker.sendStatus("Fuel sufficient for " .. depth .. " steps", true)
    return true
end)

stairTask:addStep("Build staircase", function()
    if direction == "up" then
        return buildStaircaseUp(depth, progress)
    else
        return buildStaircaseDown(depth, progress)
    end
end)

stairTask:addStep("Final report", function()
    local inventoryInfo = SwarmWorker.getInventoryInfo()
    local fuelRemaining = turtle.getFuelLevel()
    
    local summary = string.format("Staircase complete! Steps: %d %s, Items: %d, Fuel: %s",
                                 depth, direction, inventoryInfo.totalItems, tostring(fuelRemaining))
    
    SwarmWorker.sendStatus(summary, true)
    return true
end)

-- Execute the task
local success, err = stairTask:execute()

-- End session with final status
if success then
    SwarmWorker.endSession(true, "Staircase construction completed successfully")
else
    SwarmWorker.endSession(false, "Staircase construction failed: " .. tostring(err))
end