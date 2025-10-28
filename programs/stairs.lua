-- programs/stairs.lua
-- Mines stairs in a specified direction (up or down)

local function checkFuelAndRefuel()
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return true
    end

    if fuelLevel < 50 then
        sendStatus("Low fuel (" .. fuelLevel .. "), refueling...", true)

        for slot = 1, 16 do
            turtle.select(slot)
            if turtle.refuel(0) then
                turtle.refuel(1)
                sendStatus("Refueled! New level: " .. turtle.getFuelLevel(), true)
                turtle.select(1)
                return true
            end
        end

        sendStatus("ERROR: No fuel available!", false)
        return false
    end

    return true
end

-- Get parameters from args
local depth = tonumber(args[1])
local direction = args[2] or "up" -- Default to up if not specified

if not depth or depth <= 0 then
    sendStatus("Invalid depth argument", false)
    return
end

if direction ~= "up" and direction ~= "down" then
    sendStatus("Direction must be 'up' or 'down'", false)
    return
end

sendStatus("Mining " .. depth .. " block staircase going " .. direction, true)

-- Initial fuel check
if not checkFuelAndRefuel() then
    sendStatus("Insufficient fuel to start", false)
    return
end

local stepsMined = 0

-- Main mining loop
if direction == "up" then
    -- Mine stairs going UP
    for i = 1, depth do
        if not checkFuelAndRefuel() then
            sendStatus("Stopped at step " .. stepsMined .. " (no fuel)", false)
            return
        end

        -- Dig out the step in front
        while not turtle.forward() do
            turtle.dig()
            turtle.attack()
            os.sleep(0.5)
        end
        
        -- Dig above for headroom
        while turtle.detectUp() do
            turtle.digUp()
            os.sleep(0.5)
        end
        
        -- Move up one step
        while not turtle.up() do
            turtle.digUp()
            turtle.attackUp()
            os.sleep(0.5)
        end
        
        stepsMined = stepsMined + 1
        
        -- Report progress every 10 steps
        if stepsMined % 10 == 0 then
            sendStatus("Progress: " .. stepsMined .. "/" .. depth .. " steps", true)
        end
    end
else
    -- Mine stairs going DOWN
    for i = 1, depth do
        if not checkFuelAndRefuel() then
            sendStatus("Stopped at step " .. stepsMined .. " (no fuel)", false)
            return
        end

        -- Dig out the step in front
        while not turtle.forward() do
            turtle.dig()
            turtle.attack()
            os.sleep(0.5)
        end
        
        -- Dig above for headroom
        while turtle.detectUp() do
            turtle.digUp()
            os.sleep(0.5)
        end
        
        -- Dig below and move down one step
        while not turtle.down() do
            turtle.digDown()
            turtle.attackDown()
            os.sleep(0.5)
        end
        
        stepsMined = stepsMined + 1
        
        -- Report progress every 10 steps
        if stepsMined % 10 == 0 then
            sendStatus("Progress: " .. stepsMined .. "/" .. depth .. " steps", true)
        end
    end
end

sendStatus("Staircase complete! Mined " .. stepsMined .. " steps going " .. direction, true)