-- Courier Role Library
-- Transport items between pickup and delivery locations
-- Version: 4.0

local SwarmWorker = require("lib.swarm_worker_lib")
local SwarmCommon = require("lib.swarm_common")

local Courier = {}

-- Courier state
Courier.deliveriesComplete = 0
Courier.itemsTransported = 0

-- Navigate to position (simplified - needs GPS)
function Courier.navigateToPosition(targetPos)
    local currentPos = SwarmCommon.getCurrentPosition()
    if not currentPos then
        return false, "Cannot determine current position (GPS required)"
    end
    
    SwarmWorker.sendStatus(string.format("Navigating from %s to %s", 
                          SwarmCommon.formatPosition(currentPos),
                          SwarmCommon.formatPosition(targetPos)), true)
    
    -- Vertical movement first
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
    
    -- Horizontal movement (simplified - assumes clear path)
    local dx = math.abs(targetPos.x - currentPos.x)
    local dz = math.abs(targetPos.z - currentPos.z)
    local totalDistance = dx + dz
    
    for i = 1, totalDistance do
        if not SwarmWorker.forward() then
            return false, "Failed to move forward"
        end
    end
    
    SwarmWorker.sendStatus("Arrived at destination", true)
    return true
end

-- Pick up items from chest
function Courier.pickupItems(roleInstance)
    local pickupChest = roleInstance:getConfig("pickupChest")
    if not pickupChest then
        return false, "No pickup chest configured"
    end
    
    SwarmWorker.sendStatus("Going to pickup location...", true)
    
    local success, err = Courier.navigateToPosition(pickupChest)
    if not success then
        return false, err
    end
    
    -- Pull all items from chest (assume chest is below)
    SwarmWorker.sendStatus("Collecting items...", true)
    local itemsPicked = 0
    
    for slot = 1, 16 do
        if turtle.suckDown() then
            itemsPicked = itemsPicked + 1
        end
    end
    
    if itemsPicked == 0 then
        SwarmWorker.sendStatus("No items to pick up", false)
        return false, "Chest is empty"
    end
    
    SwarmWorker.sendStatus(string.format("Picked up items from %d slot(s)", itemsPicked), true)
    Courier.itemsTransported = Courier.itemsTransported + itemsPicked
    
    return true
end

-- Deliver items to chest
function Courier.deliverItems(roleInstance)
    local deliveryChest = roleInstance:getConfig("deliveryChest")
    if not deliveryChest then
        return false, "No delivery chest configured"
    end
    
    SwarmWorker.sendStatus("Going to delivery location...", true)
    
    local success, err = Courier.navigateToPosition(deliveryChest)
    if not success then
        return false, err
    end
    
    -- Drop all items into chest
    SwarmWorker.sendStatus("Delivering items...", true)
    local itemsDelivered = SwarmWorker.dropAllItems("down")
    
    if itemsDelivered == 0 then
        SwarmWorker.sendStatus("No items to deliver", false)
        return false, "Inventory is empty"
    end
    
    SwarmWorker.sendStatus(string.format("Delivered %d stack(s)", itemsDelivered), true)
    Courier.deliveriesComplete = Courier.deliveriesComplete + 1
    
    return true
end

-- Complete delivery cycle
function Courier.runDeliveryCycle(roleInstance, cycles)
    cycles = cycles or 1
    
    SwarmWorker.initSession({cycles = cycles})
    SwarmWorker.sendStatus(string.format("Starting delivery cycle (%d run(s))", cycles), true)
    
    for i = 1, cycles do
        SwarmWorker.sendStatus(string.format("Cycle %d/%d", i, cycles), true)
        
        -- Check fuel
        if SwarmWorker.needsRefuel(200) then
            local fuelChest = roleInstance:getConfig("fuelChest")
            if fuelChest then
                SwarmWorker.sendStatus("Refueling...", true)
                Courier.navigateToPosition(fuelChest)
                
                for j = 1, 4 do
                    turtle.suckDown()
                end
                
                SwarmWorker.refuel()
            else
                SwarmWorker.sendStatus("Low fuel and no fuel chest configured", false)
                break
            end
        end
        
        -- Pickup -> Deliver cycle
        local success = Courier.pickupItems(roleInstance)
        if success then
            success = Courier.deliverItems(roleInstance)
        end
        
        if not success then
            SwarmWorker.sendStatus("Delivery cycle failed", false)
            break
        end
    end
    
    SwarmWorker.sendStatus(string.format("Completed %d deliveries, %d items transported", 
                          Courier.deliveriesComplete, Courier.itemsTransported), true)
    SwarmWorker.endSession(true, "Delivery cycles completed")
    
    return true
end

-- Role-specific commands
function Courier.handleCommand(roleInstance, command, args)
    if command == "pickup" then
        return Courier.pickupItems(roleInstance)
    elseif command == "deliver" then
        return Courier.deliverItems(roleInstance)
    elseif command == "runCycle" then
        local cycles = tonumber(args[1]) or 1
        return Courier.runDeliveryCycle(roleInstance, cycles)
    elseif command == "goTo" then
        -- Go to specific location (x, y, z from args)
        local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
        if x and y and z then
            return Courier.navigateToPosition({x = x, y = y, z = z})
        else
            return false, "Invalid coordinates"
        end
    else
        return false, "Unknown courier command: " .. command
    end
end

return Courier
