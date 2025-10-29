-- Fleet Management Tool v4.0
-- Bulk operations and health monitoring for worker turtles
-- Now with role-based targeting
-- Refactored to use common libraries

local SwarmCommon = require("lib.swarm_common")
local SwarmUI = require("lib.swarm_ui")

-- Configuration
local FLEET_TIMEOUT = 5
local HEALTH_CHECK_INTERVAL = 10
local OFFLINE_THRESHOLD = 30 -- seconds

-- Initialize components
local modem, err = SwarmCommon.initModem()
if not modem then
    print("ERROR: " .. err)
    return
end

SwarmCommon.openChannels(modem, {SwarmCommon.REPLY_CHANNEL})

print("=== Fleet Management Tool v3.0 ===")
print("Advanced bulk operations for worker turtles")
print("")

local fleetData = {}

-- Fleet discovery and management
local function discoverFleet()
    print("Discovering fleet...")
    fleetData = {}
    
    local turtles = SwarmCommon.discoverTurtles(modem, FLEET_TIMEOUT)
    
    for id, turtle in pairs(turtles) do
        fleetData[id] = {
            id = id,
            lastSeen = turtle.lastSeen,
            status = "online",
            version = turtle.version or "unknown"
        }
        print("Found turtle #" .. id .. " (v" .. fleetData[id].version .. ")")
    end
    
    local count = 0
    for _ in pairs(fleetData) do count = count + 1 end
    print("Discovery complete: " .. count .. " turtles found")
    return count
end

local function getFleetStatus()
    print("Gathering fleet status...")
    
    SwarmCommon.sendCommand(modem, "status")
    
    local replies = SwarmCommon.collectReplies(FLEET_TIMEOUT, function(message)
        if fleetData[message.id] then
            fleetData[message.id].lastSeen = message.timestamp
            fleetData[message.id].status = message.success and "online" or "error"
            fleetData[message.id].statusMessage = message.message
            fleetData[message.id].version = message.version
        end
        return true
    end)
    
    return #replies
end

local function showFleetReport()
    print("\n=== Fleet Status Report ===")
    print(string.format("%-4s %-8s %-12s %-40s", "ID", "Status", "Last Seen", "Details"))
    print(string.rep("-", 70))
    
    local totalTurtles = 0
    local onlineTurtles = 0
    local now = os.epoch("utc")
    
    local sortedTurtles = {}
    for id, turtle in pairs(fleetData) do
        table.insert(sortedTurtles, {id = id, turtle = turtle})
    end
    
    table.sort(sortedTurtles, function(a, b) return a.id < b.id end)
    
    for _, entry in ipairs(sortedTurtles) do
        local id = entry.id
        local turtle = entry.turtle
        totalTurtles = totalTurtles + 1
        
        -- Check if turtle is still online
        local timeSinceLastSeen = (now - turtle.lastSeen) / 1000
        if timeSinceLastSeen < OFFLINE_THRESHOLD then
            onlineTurtles = onlineTurtles + 1
            turtle.status = "online"
        else
            turtle.status = "offline"
        end
        
        local lastSeenStr = SwarmCommon.formatTimestamp(turtle.lastSeen)
        local details = turtle.statusMessage or "No details"
        
        -- Color coding based on status
        local statusColor = turtle.status == "online" and "✓" or "✗"
        
        print(string.format("%s %-3d %-8s %-12s %-40s", 
            statusColor, id, turtle.status, lastSeenStr, details:sub(1, 40)))
    end
    
    print(string.rep("-", 70))
    print(string.format("Total: %d | Online: %d | Offline: %d", 
        totalTurtles, onlineTurtles, totalTurtles - onlineTurtles))
end

local function bulkCommand()
    local command = SwarmUI.promptChoice("Command to send to all turtles", {"ping", "status", "reboot", "custom"})
    
    if command == "custom" then
        write("Custom command: ")
        command = read()
        if not command or command == "" then
            SwarmUI.showStatus("No command entered", "error")
            return
        end
    end
    
    local args = {}
    if command == "custom" then
        write("Arguments (space-separated, optional): ")
        local argString = read()
        if argString and argString ~= "" then
            for arg in argString:gmatch("%S+") do
                table.insert(args, arg)
            end
        end
    end
    
    local fleetCount = 0
    for _ in pairs(fleetData) do fleetCount = fleetCount + 1 end
    
    if not SwarmUI.confirm("Send '" .. command .. "' to " .. fleetCount .. " turtles?") then
        print("Command cancelled")
        return
    end
    
    print("Sending command...")
    SwarmCommon.sendCommand(modem, command, args)
    
    -- Collect responses
    local responses = SwarmCommon.collectReplies(FLEET_TIMEOUT)
    
    print("\n=== Command Results ===")
    for _, response in ipairs(responses) do
        local status = response.success and "✓" or "✗"
        print(status .. " Turtle #" .. response.id .. ": " .. (response.message or "No response"))
    end
    
    print("Command completed: " .. #responses .. "/" .. fleetCount .. " responses")
end

local function targetedCommand()
    local targetId = SwarmUI.promptNumber("Target turtle ID: ", 1)
    
    if not fleetData[targetId] then
        SwarmUI.showStatus("Turtle #" .. targetId .. " not in fleet", "error")
        return
    end
    
    write("Command: ")
    local command = read()
    if not command or command == "" then
        SwarmUI.showStatus("No command entered", "error")
        return
    end
    
    local args = {}
    write("Arguments (space-separated, optional): ")
    local argString = read()
    if argString and argString ~= "" then
        for arg in argString:gmatch("%S+") do
            table.insert(args, arg)
        end
    end
    
    print("Sending '" .. command .. "' to turtle #" .. targetId .. "...")
    SwarmCommon.sendCommand(modem, command, args, targetId)
    
    -- Wait for specific response
    local replies = SwarmCommon.collectReplies(3, function(message)
        return message.id == targetId
    end)
    
    if #replies > 0 then
        local response = replies[1]
        local status = response.success and "✓" or "✗"
        print(status .. " Response: " .. (response.message or "No message"))
    else
        SwarmUI.showStatus("No response from turtle #" .. targetId, "warning")
    end
end

local function emergencyRecovery()
    print("\n=== Emergency Recovery Mode ===")
    print("This will attempt to recover unresponsive turtles")
    print("Actions:")
    print("1. Broadcast emergency reboot")
    print("2. Wait for systems to restart")
    print("3. Re-discover fleet")
    print("")
    
    if not SwarmUI.confirm("Proceed with recovery?") then
        print("Recovery cancelled")
        return
    end
    
    SwarmUI.showStatus("Broadcasting emergency reboot...", "info")
    SwarmCommon.sendCommand(modem, "reboot")
    
    print("Waiting for turtles to restart...")
    SwarmUI.showProgress(0, 3, "Waiting")
    os.sleep(2)
    SwarmUI.showProgress(1, 3, "Waiting")
    os.sleep(2)
    SwarmUI.showProgress(2, 3, "Waiting")
    os.sleep(1)
    SwarmUI.showProgress(3, 3, "Waiting")
    print("")
    
    SwarmUI.showStatus("Re-discovering fleet...", "info")
    local found = discoverFleet()
    
    SwarmUI.showStatus("Recovery complete. Found " .. found .. " turtles.", "success")
end

local function healthMonitor()
    print("\n=== Continuous Health Monitor ===")
    print("Monitoring fleet health every " .. HEALTH_CHECK_INTERVAL .. " seconds")
    print("Press any key to stop")
    print("")
    
    local monitoring = true
    
    local function monitor()
        while monitoring do
            local statusCount = getFleetStatus()
            local now = os.epoch("utc")
            
            -- Check for issues
            local issues = {}
            for id, turtle in pairs(fleetData) do
                local timeSinceLastSeen = (now - turtle.lastSeen) / 1000
                if timeSinceLastSeen > OFFLINE_THRESHOLD then
                    table.insert(issues, {
                        id = id,
                        offline_time = timeSinceLastSeen
                    })
                end
            end
            
            if #issues == 0 then
                SwarmUI.showStatus("All " .. statusCount .. " turtles healthy (" .. 
                                 SwarmCommon.formatTimestamp() .. ")", "success")
            else
                for _, issue in ipairs(issues) do
                    SwarmUI.showStatus("Turtle #" .. issue.id .. " offline for " .. 
                                     math.floor(issue.offline_time) .. " seconds", "warning")
                end
            end
            
            os.sleep(HEALTH_CHECK_INTERVAL)
        end
    end
    
    local function waitForStop()
        read()
        monitoring = false
    end
    
    parallel.waitForAny(monitor, waitForStop)
    SwarmUI.showStatus("Health monitoring stopped", "info")
end

local function exportFleetData()
    local filename = "fleet_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    
    local exportData = {
        "Fleet Status Export - " .. os.date(),
        "Generated by Fleet Management Tool v3.0",
        string.rep("=", 50),
        ""
    }
    
    for id, turtle in pairs(fleetData) do
        table.insert(exportData, "Turtle #" .. id)
        table.insert(exportData, "  Status: " .. turtle.status)
        table.insert(exportData, "  Version: " .. (turtle.version or "unknown"))
        table.insert(exportData, "  Last Seen: " .. SwarmCommon.formatTimestamp(turtle.lastSeen))
        table.insert(exportData, "  Details: " .. (turtle.statusMessage or "No details"))
        table.insert(exportData, "")
    end
    
    local success, err = SwarmCommon.writeFile(filename, table.concat(exportData, "\n"))
    if success then
        SwarmUI.showStatus("Fleet data exported to: " .. filename, "success")
    else
        SwarmUI.showStatus("Failed to create export file: " .. err, "error")
    end
end

-- Create main menu
local function createMainMenu()
    local menu = SwarmUI.Menu.new("Fleet Management v4.0")
    
    menu:addOption("1", "Discover fleet", discoverFleet)
    menu:addOption("2", "Fleet status report", function()
        getFleetStatus()
        showFleetReport()
    end)
    menu:addOption("3", "Bulk command", bulkCommand)
    menu:addOption("4", "Targeted command", targetedCommand)
    menu:addOption("5", "Role-based command", function()
        write("Target role (miner, courier, builder, etc.): ")
        local targetRole = read()
        write("Command: ")
        local command = read()
        
        local args = {}
        write("Arguments (space-separated, optional): ")
        local argString = read()
        if argString and argString ~= "" then
            for arg in argString:gmatch("%S+") do
                table.insert(args, arg)
            end
        end
        
        print("Sending '" .. command .. "' to all '" .. targetRole .. "' turtles...")
        SwarmCommon.sendRoleCommand(modem, targetRole, command, args)
        
        local replies = SwarmCommon.collectReplies(5)
        print("\n=== Responses from " .. targetRole .. " turtles ===")
        for _, response in ipairs(replies) do
            if response.role == targetRole then
                local status = response.success and "✓" or "✗"
                print(status .. " Turtle #" .. response.id .. ": " .. (response.message or "No response"))
            end
        end
        
        print("Received " .. #replies .. " responses")
    end)
    menu:addOption("6", "Health monitor", healthMonitor)
    menu:addOption("7", "Emergency recovery", emergencyRecovery)
    menu:addOption("8", "Export fleet data", exportFleetData)
    menu:addOption("9", "Show fleet by role", function()
        print("\n=== Fleet by Role ===")
        
        -- Get role info from all turtles
        SwarmCommon.sendCommand(modem, "getRoleInfo")
        local replies = SwarmCommon.collectReplies(3)
        
        local roleGroups = {}
        for _, reply in ipairs(replies) do
            local role = reply.role or "unassigned"
            if not roleGroups[role] then
                roleGroups[role] = {}
            end
            table.insert(roleGroups[role], reply.id)
        end
        
        for role, turtles in pairs(roleGroups) do
            print("\n" .. role .. " (" .. #turtles .. " turtles):")
            table.sort(turtles)
            local turtleList = {}
            for _, id in ipairs(turtles) do
                table.insert(turtleList, "#" .. id)
            end
            print("  " .. table.concat(turtleList, ", "))
        end
        
        print("\nPress Enter to continue...")
        read()
    end)
    menu:addOption("0", "Exit", function() return false end)
    
    return menu
end

-- Initialize and run
SwarmUI.showStatus("Auto-discovering fleet...", "info")
discoverFleet()

local mainMenu = createMainMenu()
mainMenu:run()

print("Exiting fleet management...")