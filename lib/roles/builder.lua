-- Builder Role Library
-- Construction and building operations
-- Version: 4.0

local SwarmWorker = require("lib.swarm_worker_lib")
local SwarmCommon = require("lib.swarm_common")

local Builder = {}

-- Builder state
Builder.blocksPlaced = 0

-- Place block in direction
function Builder.placeBlock(direction, itemSlot)
    if itemSlot then
        turtle.select(itemSlot)
    end
    
    local placeFunc
    if direction == "forward" then
        placeFunc = turtle.place
    elseif direction == "up" then
        placeFunc = turtle.placeUp
    elseif direction == "down" then
        placeFunc = turtle.placeDown
    else
        return false, "Invalid direction: " .. tostring(direction)
    end
    
    if placeFunc() then
        Builder.blocksPlaced = Builder.blocksPlaced + 1
        return true
    end
    
    return false
end

-- Build a wall
function Builder.buildWall(length, height, blockSlot)
    SwarmWorker.initSession({length = length, height = height})
    
    local totalBlocks = length * height
    local progress = SwarmWorker.ProgressTracker.new(totalBlocks, 10)
    
    SwarmWorker.sendStatus(string.format("Building wall (%dx%d)", length, height), true)
    
    if blockSlot then
        turtle.select(blockSlot)
    end
    
    for h = 1, height do
        for l = 1, length do
            -- Place block
            if not Builder.placeBlock("forward", blockSlot) then
                SwarmWorker.sendStatus("Failed to place block - out of materials?", false)
                break
            end
            
            progress:increment()
            
            -- Move forward (except on last block)
            if l < length then
                SwarmWorker.forward()
            end
        end
        
        -- Move up for next layer
        if h < height then
            SwarmWorker.up()
            
            -- Return to start position
            turtle.turnLeft()
            turtle.turnLeft()
            for l = 1, length - 1 do
                SwarmWorker.forward()
            end
            turtle.turnLeft()
            turtle.turnLeft()
        end
    end
    
    SwarmWorker.sendStatus(string.format("Wall complete. Blocks placed: %d", Builder.blocksPlaced), true)
    SwarmWorker.endSession(true, "Wall construction completed")
    
    return true
end

-- Build a floor/platform
function Builder.buildFloor(width, length, blockSlot)
    SwarmWorker.initSession({width = width, length = length})
    
    local totalBlocks = width * length
    local progress = SwarmWorker.ProgressTracker.new(totalBlocks, 10)
    
    SwarmWorker.sendStatus(string.format("Building floor (%dx%d)", width, length), true)
    
    if blockSlot then
        turtle.select(blockSlot)
    end
    
    for w = 1, width do
        for l = 1, length do
            -- Place block below
            if not Builder.placeBlock("down", blockSlot) then
                SwarmWorker.sendStatus("Failed to place block - out of materials?", false)
                break
            end
            
            progress:increment()
            
            -- Move forward (except on last block of row)
            if l < length then
                SwarmWorker.forward()
            end
        end
        
        -- Move to next row
        if w < width then
            if w % 2 == 1 then
                -- Turn right, move, turn right
                turtle.turnRight()
                SwarmWorker.forward()
                turtle.turnRight()
            else
                -- Turn left, move, turn left
                turtle.turnLeft()
                SwarmWorker.forward()
                turtle.turnLeft()
            end
        end
    end
    
    SwarmWorker.sendStatus(string.format("Floor complete. Blocks placed: %d", Builder.blocksPlaced), true)
    SwarmWorker.endSession(true, "Floor construction completed")
    
    return true
end

-- Build a tower/pillar
function Builder.buildTower(height, blockSlot)
    SwarmWorker.initSession({height = height})
    
    local progress = SwarmWorker.ProgressTracker.new(height, 10)
    
    SwarmWorker.sendStatus(string.format("Building tower (height: %d)", height), true)
    
    if blockSlot then
        turtle.select(blockSlot)
    end
    
    for h = 1, height do
        -- Place block below
        if not Builder.placeBlock("down", blockSlot) then
            SwarmWorker.sendStatus("Failed to place block - out of materials?", false)
            break
        end
        
        progress:increment()
        
        -- Move up (except on last block)
        if h < height then
            SwarmWorker.up()
        end
    end
    
    SwarmWorker.sendStatus(string.format("Tower complete. Blocks placed: %d", Builder.blocksPlaced), true)
    SwarmWorker.endSession(true, "Tower construction completed")
    
    return true
end

-- Fill area (mining out space or filling with blocks)
function Builder.fillArea(width, height, depth, fillMode, blockSlot)
    SwarmWorker.initSession({width = width, height = height, depth = depth})
    
    local totalBlocks = width * height * depth
    local progress = SwarmWorker.ProgressTracker.new(totalBlocks, 20)
    
    SwarmWorker.sendStatus(string.format("Filling area (%dx%dx%d, mode: %s)", 
                          width, height, depth, fillMode), true)
    
    for d = 1, depth do
        for h = 1, height do
            for w = 1, width do
                if fillMode == "dig" then
                    SwarmWorker.digDirection("forward")
                elseif fillMode == "place" then
                    Builder.placeBlock("forward", blockSlot)
                end
                
                progress:increment()
                
                if w < width then
                    SwarmWorker.forward()
                end
            end
            
            -- Move to next layer
            if h < height then
                SwarmWorker.up()
                -- Return to start
                turtle.turnLeft()
                turtle.turnLeft()
                for w = 1, width - 1 do
                    SwarmWorker.forward()
                end
                turtle.turnLeft()
                turtle.turnLeft()
            end
        end
        
        -- Move to next depth layer
        if d < depth then
            -- Move down to ground level
            for h = 1, height - 1 do
                SwarmWorker.down()
            end
            
            -- Move forward one
            SwarmWorker.forward()
        end
    end
    
    SwarmWorker.sendStatus(string.format("Area fill complete. Operations: %d", totalBlocks), true)
    SwarmWorker.endSession(true, "Area fill completed")
    
    return true
end

-- Resupply from material chest
function Builder.resupplyMaterials(roleInstance)
    local materialChest = roleInstance:getConfig("materialChest")
    if not materialChest then
        return false, "No material chest configured"
    end
    
    SwarmWorker.sendStatus("Resupplying materials...", true)
    
    -- Navigate to material chest (simplified)
    local currentPos = SwarmCommon.getCurrentPosition()
    if not currentPos then
        return false, "Cannot determine position (GPS required)"
    end
    
    -- Pull materials from chest
    for slot = 1, 16 do
        turtle.select(slot)
        turtle.suckDown()
    end
    
    SwarmWorker.sendStatus("Materials resupplied", true)
    return true
end

-- Role-specific commands
function Builder.handleCommand(roleInstance, command, args)
    if command == "buildWall" then
        local length = tonumber(args[1]) or 5
        local height = tonumber(args[2]) or 3
        local blockSlot = tonumber(args[3])
        return Builder.buildWall(length, height, blockSlot)
    elseif command == "buildFloor" then
        local width = tonumber(args[1]) or 5
        local length = tonumber(args[2]) or 5
        local blockSlot = tonumber(args[3])
        return Builder.buildFloor(width, length, blockSlot)
    elseif command == "buildTower" then
        local height = tonumber(args[1]) or 10
        local blockSlot = tonumber(args[2])
        return Builder.buildTower(height, blockSlot)
    elseif command == "fillArea" then
        local width = tonumber(args[1]) or 5
        local height = tonumber(args[2]) or 3
        local depth = tonumber(args[3]) or 5
        local fillMode = args[4] or "dig"
        local blockSlot = tonumber(args[5])
        return Builder.fillArea(width, height, depth, fillMode, blockSlot)
    elseif command == "resupply" then
        return Builder.resupplyMaterials(roleInstance)
    else
        return false, "Unknown builder command: " .. command
    end
end

return Builder
