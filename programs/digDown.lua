-- programs/digDown.lua
-- Mines down a specified depth and returns to surface

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

-- Get depth from args
local depth = tonumber(args[1])

if not depth or depth <= 0 then
    sendStatus("Invalid depth argument", false)
    return
end

sendStatus("Mining " .. depth .. " blocks down", true)

-- Initial fuel check
if not checkFuelAndRefuel() then
    sendStatus("Insufficient fuel to start", false)
    return
end

local blocksMined = 0

-- Main mining loop
for i = 1, depth do
    if not checkFuelAndRefuel() then
        sendStatus("Stopped at " .. blocksMined .. " blocks (no fuel)", false)
        return
    end

    while turtle.digDown() do
        os.sleep(0.5)
    end

    while not turtle.down() do
        turtle.digDown()
        turtle.attackDown()
        os.sleep(0.5)
    end

    blocksMined = blocksMined + 1

    -- Report progress every 10 blocks
    if blocksMined % 10 == 0 then
        sendStatus("Progress: " .. blocksMined .. "/" .. depth, true)
    end
end

sendStatus("Mining complete! Returning to surface...", true)

-- Return to surface
for i = 1, blocksMined do
    checkFuelAndRefuel()

    while not turtle.up() do
        turtle.digUp()
        turtle.attackUp()
        os.sleep(0.5)
    end
end

sendStatus("Completed! Mined " .. blocksMined .. " blocks", true)
