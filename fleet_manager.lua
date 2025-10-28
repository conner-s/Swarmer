-- Fleet Management Tool v1.0
-- Bulk operations and health monitoring for worker turtles
-- Run this alongside puppetmaster for advanced fleet management

local COMMAND_CHANNEL = 100
local REPLY_CHANNEL = 101
local FLEET_TIMEOUT = 5

local modem = peripheral.find("modem")
if not modem then
    print("ERROR: No modem found!")
    return
end

modem.open(REPLY_CHANNEL)

print("=== Fleet Management Tool v1.0 ===")
print("Advanced bulk operations for worker turtles")
print("")

local fleetData = {}

-- Fleet discovery and health monitoring
local function discoverFleet()
    print("Discovering fleet...")
    fleetData = {}
    
    -- Send ping to all turtles
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = "ping",
        timestamp = os.epoch("utc")
    })
    
    -- Collect responses
    local timer = os.startTimer(FLEET_TIMEOUT)
    local responses = 0
    
    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id and message.message then
                if not fleetData[message.id] then
                    fleetData[message.id] = {
                        id = message.id,
                        lastSeen = os.epoch("utc"),
                        status = "online",
                        version = "unknown"
                    }
                    responses = responses + 1
                    print("Found turtle #" .. message.id)
                end
            end
        end
    end
    
    print("Discovery complete: " .. responses .. " turtles found")
    return responses
end

local function getFleetStatus()
    print("Gathering fleet status...")
    
    -- Send status request to all known turtles
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = "status",
        timestamp = os.epoch("utc")
    })
    
    -- Collect detailed status
    local timer = os.startTimer(FLEET_TIMEOUT)
    local statusReceived = 0
    
    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id and fleetData[message.id] then
                fleetData[message.id].lastSeen = os.epoch("utc")
                fleetData[message.id].status = message.success and "online" or "error"
                fleetData[message.id].statusMessage = message.message
                statusReceived = statusReceived + 1
            end
        end
    end
    
    return statusReceived
end

local function showFleetReport()
    print("\n=== Fleet Status Report ===")
    print(string.format("%-4s %-8s %-12s %-40s", "ID", "Status", "Last Seen", "Details"))
    print(string.rep("-", 70))
    
    local totalTurtles = 0
    local onlineTurtles = 0
    
    for id, turtle in pairs(fleetData) do
        totalTurtles = totalTurtles + 1
        if turtle.status == "online" then
            onlineTurtles = onlineTurtles + 1
        end
        
        local lastSeenStr = os.date("%H:%M:%S", turtle.lastSeen / 1000)
        local details = turtle.statusMessage or "No details"
        
        print(string.format("%-4d %-8s %-12s %-40s", 
            id, turtle.status, lastSeenStr, details:sub(1, 40)))
    end
    
    print(string.rep("-", 70))
    print(string.format("Total: %d | Online: %d | Offline: %d", 
        totalTurtles, onlineTurtles, totalTurtles - onlineTurtles))
end

local function bulkCommand()
    write("Command to send to all turtles: ")
    local command = read()
    
    if not command or command == "" then
        print("No command entered")
        return
    end
    
    write("Arguments (optional): ")
    local argString = read()
    local args = {}
    
    if argString and argString ~= "" then
        for arg in argString:gmatch("%S+") do
            table.insert(args, arg)
        end
    end
    
    local fleetCount = 0
    for _ in pairs(fleetData) do
        fleetCount = fleetCount + 1
    end
    
    print("Sending '" .. command .. "' to " .. fleetCount .. " turtles...")
    
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = command,
        args = args,
        timestamp = os.epoch("utc")
    })
    
    -- Wait for responses
    local timer = os.startTimer(FLEET_TIMEOUT)
    local responses = 0
    
    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id then
                responses = responses + 1
                local status = message.success and "✓" or "✗"
                print(status .. " Turtle #" .. message.id .. ": " .. (message.message or "No response"))
            end
        end
    end
    
    local fleetCount = 0
    for _ in pairs(fleetData) do
        fleetCount = fleetCount + 1
    end
    
    print("Command completed: " .. responses .. "/" .. fleetCount .. " responses")
end

local function targetedCommand()
    write("Target turtle ID: ")
    local targetId = tonumber(read())
    
    if not targetId or not fleetData[targetId] then
        print("Invalid turtle ID or turtle not in fleet")
        return
    end
    
    write("Command: ")
    local command = read()
    
    if not command or command == "" then
        print("No command entered")
        return
    end
    
    write("Arguments (optional): ")
    local argString = read()
    local args = {}
    
    if argString and argString ~= "" then
        for arg in argString:gmatch("%S+") do
            table.insert(args, arg)
        end
    end
    
    print("Sending '" .. command .. "' to turtle #" .. targetId .. "...")
    
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = command,
        args = args,
        targetId = targetId,
        timestamp = os.epoch("utc")
    })
    
    -- Wait for response
    local timer = os.startTimer(3)
    
    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            print("No response from turtle #" .. targetId)
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id == targetId then
                local status = message.success and "✓" or "✗"
                print(status .. " Response: " .. (message.message or "No message"))
                break
            end
        end
    end
end

local function emergencyRecovery()
    print("=== Emergency Recovery Mode ===")
    print("This will attempt to recover unresponsive turtles")
    print("")
    write("Proceed? (y/n): ")
    local confirm = read()
    
    if not (confirm == "y" or confirm == "Y") then
        print("Recovery cancelled")
        return
    end
    
    print("Step 1: Broadcasting emergency reboot...")
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = "reboot",
        timestamp = os.epoch("utc")
    })
    
    os.sleep(2)
    
    print("Step 2: Waiting for turtles to come back online...")
    os.sleep(5)
    
    print("Step 3: Re-discovering fleet...")
    discoverFleet()
    
    print("Recovery complete. Check fleet status for results.")
end

local function healthMonitor()
    print("Starting continuous health monitoring...")
    print("Press any key to stop")
    print("")
    
    local monitoring = true
    
    -- Start monitoring in background
    local function monitor()
        while monitoring do
            getFleetStatus()
            
            -- Check for issues
            local issues = 0
            for id, turtle in pairs(fleetData) do
                local timeSinceLastSeen = (os.epoch("utc") - turtle.lastSeen) / 1000
                if timeSinceLastSeen > 30 then -- 30 seconds threshold
                    print("WARNING: Turtle #" .. id .. " not responding for " .. 
                          math.floor(timeSinceLastSeen) .. " seconds")
                    issues = issues + 1
                end
            end
            
            if issues == 0 then
                print("All turtles healthy (" .. os.date("%H:%M:%S") .. ")")
            end
            
            os.sleep(10) -- Check every 10 seconds
        end
    end
    
    local function waitForStop()
        read()
        monitoring = false
    end
    
    parallel.waitForAny(monitor, waitForStop)
    print("Health monitoring stopped")
end

local function showMenu()
    print("\n=== Fleet Management Menu ===")
    print("1. Discover fleet")
    print("2. Fleet status report") 
    print("3. Bulk command")
    print("4. Targeted command")
    print("5. Health monitor")
    print("6. Emergency recovery")
    print("7. Export fleet data")
    print("0. Exit")
    print("=============================")
    write("Choice: ")
end

local function exportFleetData()
    local filename = "fleet_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    local file = fs.open(filename, "w")
    
    if file then
        file.writeLine("Fleet Status Export - " .. os.date())
        file.writeLine("Generated by Fleet Management Tool v1.0")
        file.writeLine(string.rep("=", 50))
        file.writeLine("")
        
        for id, turtle in pairs(fleetData) do
            file.writeLine("Turtle #" .. id)
            file.writeLine("  Status: " .. turtle.status)
            file.writeLine("  Last Seen: " .. os.date("%c", turtle.lastSeen / 1000))
            file.writeLine("  Details: " .. (turtle.statusMessage or "No details"))
            file.writeLine("")
        end
        
        file.close()
        print("Fleet data exported to: " .. filename)
    else
        print("Failed to create export file")
    end
end

-- Main program loop
local function main()
    while true do
        showMenu()
        local choice = read()
        
        if choice == "0" then
            print("Exiting fleet management...")
            break
        elseif choice == "1" then
            discoverFleet()
        elseif choice == "2" then
            getFleetStatus()
            showFleetReport()
        elseif choice == "3" then
            bulkCommand()
        elseif choice == "4" then
            targetedCommand()
        elseif choice == "5" then
            healthMonitor()
        elseif choice == "6" then
            emergencyRecovery()
        elseif choice == "7" then
            exportFleetData()
        else
            print("Invalid choice")
        end
    end
end

-- Auto-discover on startup
print("Auto-discovering fleet...")
discoverFleet()

main()