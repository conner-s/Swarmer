-- Miner Role Library
-- Specialized mining operations with ore collection and home chest functionality
-- Version: 4.0

local SwarmWorker = require("lib.swarm_worker_lib")
local SwarmCommon = require("lib.swarm_common")

local Miner = {}

-- Miner-specific state
Miner.oresCollected = 0
Miner.cobblestoneCollected = 0

-- Ore detection (common valuable ores)
Miner.VALUABLE_ORES = {
    ["minecraft:coal_ore"] = true,
    ["minecraft:iron_ore"] = true,
    ["minecraft:gold_ore"] = true,
    ["minecraft:diamond_ore"] = true,
    ["minecraft:emerald_ore"] = true,
    ["minecraft:lapis_ore"] = true,
    ["minecraft:redstone_ore"] = true,
    ["minecraft:copper_ore"] = true,
    ["minecraft:deepslate_coal_ore"] = true,
    ["minecraft:deepslate_iron_ore"] = true,
    ["minecraft:deepslate_gold_ore"] = true,
    ["minecraft:deepslate_diamond_ore"] = true,
    ["minecraft:deepslate_emerald_ore"] = true,
    ["minecraft:deepslate_lapis_ore"] = true,
    ["minecraft:deepslate_redstone_ore"] = true,
    ["minecraft:deepslate_copper_ore"] = true,
}

-- Check if block is valuable ore
function Miner.isValuableOre(blockData)
    if not blockData or not blockData.name then
        return false
    end
    return Miner.VALUABLE_ORES[blockData.name] or false
end

-- Smart mining (detect and mine only valuable blocks)
function Miner.smartMineForward(keepCobble)
    local hasBlock, blockData = turtle.inspect()
    
    if not hasBlock then
        return false -- No block to mine
    end
    
    local isOre = Miner.isValuableOre(blockData)
    
    -- Mine if it's ore or if we're keeping cobblestone
    if isOre or keepCobble or blockData.name ~= "minecraft:cobblestone" then
        if turtle.dig() then
            if isOre then
                Miner.oresCollected = Miner.oresCollected + 1
            elseif blockData.name == "minecraft:cobblestone" then
                Miner.cobblestoneCollected = Miner.cobblestoneCollected + 1
            end
            return true
        end
    else
        -- It's cobblestone and we're not keeping it
        turtle.dig() -- Still mine it, just don't count
        return true
    end
    
    return false
end

-- Navigate to position (basic pathfinding)
function Miner.navigateToPosition(targetPos, currentPos)
    if not targetPos or not currentPos then
        return false, "Invalid position data"
    end
    
    SwarmWorker.sendStatus(string.format("Navigating to %s", SwarmCommon.formatPosition(targetPos)), true)
    
    -- Move vertically first (Y axis)
    local dy = targetPos.y - currentPos.y
    if dy > 0 then
        for i = 1, dy do
            if not SwarmWorker.up() then
                return false, "Failed to move up"
            end
        end
    elseif dy < 0 then
        for i = 1, -dy do
            if not SwarmWorker.down() then
                return false, "Failed to move down"
            end
        end
    end
    
    -- Move horizontally (X and Z)
    local dx = targetPos.x - currentPos.x
    local dz = targetPos.z - currentPos.z
    
    -- Move in X direction
    if dx ~= 0 then
        -- Turn to face correct direction
        -- Note: This is simplified; real implementation needs heading tracking
        for i = 1, math.abs(dx) do
            if not SwarmWorker.forward() then
                return false, "Failed to move in X direction"
            end
        end
    end
    
    -- Move in Z direction
    if dz ~= 0 then
        for i = 1, math.abs(dz) do
            if not SwarmWorker.forward() then
                return false, "Failed to move in Z direction"
            end
        end
    end
    
    SwarmWorker.sendStatus("Arrived at destination", true)
    return true
end

-- Return to home chest and deposit items
function Miner.returnHomeAndDeposit(roleInstance)
    local homeChest = roleInstance:getConfig("homeChest")
    if not homeChest then
        return false, "No home chest configured"
    end
    
    SwarmWorker.sendStatus("Returning to home chest...", true)
    
    -- Get current position
    local currentPos = SwarmCommon.getCurrentPosition()
    if not currentPos then
        return false, "Cannot determine current position (GPS required)"
    end
    
    -- Navigate to home chest
    local success, err = Miner.navigateToPosition(homeChest, currentPos)
    if not success then
        return false, err
    end
    
    -- Deposit items
    local deposited = SwarmWorker.dropAllItems("down")
    SwarmWorker.sendStatus(string.format("Deposited %d stack(s) of items", deposited), true)
    
    return true
end

-- Refuel from fuel chest
function Miner.refuelFromChest(roleInstance)
    local fuelChest = roleInstance:getConfig("fuelChest")
    if not fuelChest then
        return false, "No fuel chest configured"
    end
    
    SwarmWorker.sendStatus("Going to fuel chest...", true)
    
    -- Get current position
    local currentPos = SwarmCommon.getCurrentPosition()
    if not currentPos then
        return false, "Cannot determine current position (GPS required)"
    end
    
    -- Navigate to fuel chest
    local success, err = Miner.navigateToPosition(fuelChest, currentPos)
    if not success then
        return false, err
    end
    
    -- Pull fuel from chest
    -- Try to suck items from chest above
    for i = 1, 4 do -- Try multiple times
        turtle.suckUp()
        os.sleep(0.2)
    end
    
    -- Attempt to refuel
    local refueled, newLevel, gained = SwarmWorker.refuel()
    if refueled then
        SwarmWorker.sendStatus(string.format("Refueled to %d (+%d)", newLevel, gained), true)
        return true
    else
        return false, "No fuel found in inventory"
    end
end

-- Mine a vertical shaft
function Miner.mineShaft(depth, keepCobble)
    SwarmWorker.initSession({depth = depth})
    
    local progress = SwarmWorker.ProgressTracker.new(depth, 5)
    SwarmWorker.sendStatus(string.format("Starting shaft mining (depth: %d)", depth), true)
    
    for i = 1, depth do
        -- Check fuel before each block
        if SwarmWorker.needsRefuel(100) then
            SwarmWorker.sendStatus("Low fuel, stopping mining", false)
            break
        end
        
        -- Mine down
        SwarmWorker.digDirection("down")
        if not SwarmWorker.down() then
            SwarmWorker.sendStatus("Cannot move down, stopping", false)
            break
        end
        
        progress:increment()
    end
    
    SwarmWorker.sendStatus(string.format("Mining complete. Ores: %d, Cobble: %d", 
                          Miner.oresCollected, Miner.cobblestoneCollected), true)
    SwarmWorker.endSession(true, "Shaft mining completed")
    
    return true
end

-- Strip mine pattern
function Miner.stripMine(length, spacing, branches, keepCobble)
    SwarmWorker.initSession({length = length, spacing = spacing, branches = branches})
    
    local totalBlocks = length * branches
    local progress = SwarmWorker.ProgressTracker.new(totalBlocks, 10)
    
    SwarmWorker.sendStatus(string.format("Starting strip mine (length: %d, branches: %d)", length, branches), true)
    
    for branch = 1, branches do
        SwarmWorker.sendStatus(string.format("Mining branch %d/%d", branch, branches), true)
        
        -- Mine forward for branch length
        for i = 1, length do
            if SwarmWorker.needsRefuel(100) then
                SwarmWorker.sendStatus("Low fuel, returning", false)
                return false
            end
            
            Miner.smartMineForward(keepCobble)
            SwarmWorker.forward()
            progress:increment()
        end
        
        -- Return to main tunnel
        turtle.turnLeft()
        turtle.turnLeft()
        for i = 1, length do
            SwarmWorker.forward()
        end
        turtle.turnLeft()
        turtle.turnLeft()
        
        -- Move to next branch position
        if branch < branches then
            for i = 1, spacing do
                SwarmWorker.forward()
            end
        end
    end
    
    SwarmWorker.sendStatus(string.format("Strip mine complete. Ores: %d", Miner.oresCollected), true)
    SwarmWorker.endSession(true, "Strip mining completed")
    
    return true
end

-- Role-specific commands
function Miner.handleCommand(roleInstance, command, args)
    if command == "mineShaft" then
        local depth = tonumber(args[1]) or 10
        local keepCobble = roleInstance:getConfig("keepCobblestone")
        return Miner.mineShaft(depth, keepCobble)
    elseif command == "stripMine" then
        local length = tonumber(args[1]) or 20
        local spacing = tonumber(args[2]) or 3
        local branches = tonumber(args[3]) or 5
        local keepCobble = roleInstance:getConfig("keepCobblestone")
        return Miner.stripMine(length, spacing, branches, keepCobble)
    elseif command == "returnHome" then
        return Miner.returnHomeAndDeposit(roleInstance)
    elseif command == "getFuel" then
        return Miner.refuelFromChest(roleInstance)
    else
        return false, "Unknown miner command: " .. command
    end
end

return Miner
