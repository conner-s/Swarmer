-- Turtle Fleet Monitor v4.0
-- Displays turtle positions and IDs on a monitor
-- Refactored to use common libraries

-- Check command line arguments to determine mode FIRST
local args = {...}
if args[1] == "monitor-mode" then
    -- This is the actual monitor program running in its tab
    -- Skip multishell initialization and run normally
else
    -- First launch - set up multishell environment
    if not multishell then
        print("ERROR: Multishell not available!")
        print("This program requires an Advanced Computer.")
        return
    end
    
    -- Get current tab as shell tab
    local shellTab = multishell.getCurrent()
    multishell.setTitle(shellTab, "Shell")
    
    -- Launch this program again in monitor mode
    -- Pass the current environment so the new tab has access to shell, require, etc.
    local monitorTab = multishell.launch(_ENV, shell.getRunningProgram(), "monitor-mode")
    multishell.setTitle(monitorTab, "Fleet Monitor")
    
    -- Switch to monitor tab
    multishell.setFocus(monitorTab)
    
    -- This initial instance can now exit - the new tab will run the actual program
    return
end

-- This is monitor-mode - the actual monitor program running in its tab

-- Load required libraries
if not fs.exists("lib/swarm_common.lua") then
    print("ERROR: lib/swarm_common.lua not found!")
    print("Please ensure the swarm libraries are installed.")
    return
end

if not fs.exists("lib/swarm_ui.lua") then
    print("ERROR: lib/swarm_ui.lua not found!")
    print("Please ensure the swarm libraries are installed.")
    return
end

local SwarmCommon = require("lib.swarm_common")
local SwarmUI = require("lib.swarm_ui")
local SwarmGPS = require("lib.swarm_gps")

-- Load RoleManager to get role colors
local RoleManager = nil
if fs.exists("lib/roles.lua") then
    RoleManager = require("lib.roles")
end

-- Monitor configuration
local UPDATE_INTERVAL = 3 -- Seconds between position updates

-- Initialize components
local modem, err = SwarmCommon.initModem()
if not modem then
    print("ERROR: " .. err)
    return
end

local monitor, err = SwarmUI.initMonitor(0.5)
if not monitor then
    print("ERROR: " .. err)
    return
end

SwarmCommon.openChannels(modem, {SwarmCommon.REPLY_CHANNEL})

-- Turtle tracking
local turtles = {}
local monWidth, monHeight = monitor.getSize()

print("Monitor size: " .. monWidth .. "x" .. monHeight)

-- Enhanced display management
local function updateDisplay()
    SwarmUI.drawMonitorHeader(monitor, "FLEET MONITOR")
    
    -- Count active turtles
    local activeTurtles = 0
    local now = os.epoch("utc")
    
    for id, data in pairs(turtles) do
        if now - data.lastSeen < 30000 then
            activeTurtles = activeTurtles + 1
        end
    end
    
    -- Status bar
    monitor.setBackgroundColor(SwarmUI.THEME.activeBg)
    monitor.setTextColor(SwarmUI.THEME.activeText)
    monitor.setCursorPos(1, 3)
    local statusText = " ACTIVE: " .. activeTurtles .. " "
    monitor.write(statusText)
    monitor.setBackgroundColor(SwarmUI.THEME.background)
    monitor.write(string.rep(" ", monWidth - #statusText))
    
    -- Headers
    monitor.setCursorPos(1, 4)
    monitor.setBackgroundColor(SwarmUI.THEME.headerBg)
    monitor.setTextColor(SwarmUI.THEME.headerText)
    monitor.write(" ID ")
    monitor.write(string.rep(" ", monWidth - 4))
    monitor.setCursorPos(6, 4)
    monitor.write("ROLE")
    monitor.setCursorPos(18, 4)
    monitor.write("POSITION")
    
    -- Display turtle list
    local line = 5
    local sortedTurtles = {}
    
    -- Collect active turtles
    for id, data in pairs(turtles) do
        if now - data.lastSeen < 30000 then
            table.insert(sortedTurtles, {id = id, data = data})
        end
    end
    
    -- Sort by ID
    table.sort(sortedTurtles, function(a, b) return a.id < b.id end)
    
    -- Display each turtle with role-based colors
    for i, entry in ipairs(sortedTurtles) do
        if line > monHeight - 1 then break end
        
        -- Get role color (default to gray if no role or role not found)
        local roleColor = colors.gray
        if entry.data.role and RoleManager then
            local roleMetadata = RoleManager.getRole(entry.data.role)
            if roleMetadata and roleMetadata.color then
                roleColor = roleMetadata.color
            end
        end
        
        -- Use role color for row background
        monitor.setBackgroundColor(roleColor)
        monitor.setCursorPos(1, line)
        monitor.write(string.rep(" ", monWidth))
        
        -- Turtle ID
        monitor.setCursorPos(1, line)
        monitor.setBackgroundColor(SwarmUI.THEME.turtleIdBg)
        monitor.setTextColor(SwarmUI.THEME.turtleIdText)
        local idText = " #" .. entry.id .. " "
        monitor.write(idText)
        
        -- Role name
        monitor.setBackgroundColor(roleColor)
        monitor.setCursorPos(6, line)
        monitor.setTextColor(colors.white)
        local roleName = entry.data.roleName or "Worker"
        if #roleName > 10 then
            roleName = roleName:sub(1, 9) .. "."
        end
        monitor.write(roleName)
        
        -- Position
        monitor.setCursorPos(18, line)
        monitor.setTextColor(SwarmUI.THEME.positionText)
        
        local position = {x = entry.data.x, y = entry.data.y, z = entry.data.z}
        local posText = SwarmGPS.formatPosition(position)
        
        if entry.data.x then
            if #posText > (monWidth - 18) then
                posText = posText:sub(1, monWidth - 21) .. "..."
            end
            monitor.write(posText)
        else
            monitor.setTextColor(colors.red)
            monitor.write("No GPS")
        end
        
        line = line + 1
    end
    
    -- Clear remaining lines
    monitor.setBackgroundColor(SwarmUI.THEME.background)
    while line < monHeight do
        monitor.setCursorPos(1, line)
        monitor.write(string.rep(" ", monWidth))
        line = line + 1
    end
    
    -- Footer with timestamp
    monitor.setBackgroundColor(SwarmUI.THEME.headerBg)
    monitor.setCursorPos(1, monHeight)
    monitor.write(string.rep(" ", monWidth))
    monitor.setCursorPos(2, monHeight)
    monitor.setTextColor(SwarmUI.THEME.timeText)
    monitor.write(SwarmCommon.formatTimestamp())
end

-- Message handling
local function handleMessage(message)
    if type(message) == "table" and message.id then
        -- Initialize turtle record if new
        if not turtles[message.id] then
            turtles[message.id] = {}
        end
        
        local turtle = turtles[message.id]
        turtle.lastSeen = os.epoch("utc")
        turtle.version = message.version
        
        -- Capture role information
        if message.role then
            turtle.role = message.role
            turtle.roleName = message.roleName
        end
        
        -- Parse status message for position and fuel
        if message.message and message.message:find("Fuel:") then
            -- Extract fuel level
            local fuel = message.message:match("Fuel:%s*(%S+)")
            if fuel and fuel ~= "unlimited" then
                turtle.fuel = tonumber(fuel)
            end
            
            -- Extract position
            local x, y, z = message.message:match("X:(-?%d+)%s+Y:(-?%d+)%s+Z:(-?%d+)")
            if x and y and z then
                turtle.x = tonumber(x)
                turtle.y = tonumber(y)
                turtle.z = tonumber(z)
            end
        end
        
        -- Handle direct position data if available
        if message.position then
            turtle.x = message.position.x
            turtle.y = message.position.y
            turtle.z = message.position.z
        end
        
        updateDisplay()
    end
end

-- Request status from all turtles
local function requestStatus()
    SwarmCommon.sendCommand(modem, "status")
end

-- Initialize display
SwarmUI.drawMonitorHeader(monitor, "FLEET MONITOR")
monitor.setBackgroundColor(SwarmUI.THEME.background)
monitor.setCursorPos(1, 5)
monitor.setTextColor(colors.yellow)
local waitText = "Initializing..."
monitor.setCursorPos(math.floor((monWidth - #waitText) / 2), math.floor(monHeight / 2))
monitor.write(waitText)

print("Fleet Monitor v4.0 started")
print("Monitoring " .. monWidth .. "x" .. monHeight .. " display")
print("Press Ctrl+T to exit")

-- Request initial status
requestStatus()

-- Main event loop with improved timing
local lastRequest = os.epoch("utc")
local timer = os.startTimer(UPDATE_INTERVAL)

local eventHandlers = {
    modem_message = function(side, channel, replyChannel, message)
        handleMessage(message)
    end,
    
    timer = function(timerID)
        if timerID == timer then
            local now = os.epoch("utc")
            if now - lastRequest > (UPDATE_INTERVAL * 1000) then
                requestStatus()
                lastRequest = now
            end
            updateDisplay() -- Refresh display to update timestamps
            timer = os.startTimer(UPDATE_INTERVAL)
        end
    end,
    
    terminate = function()
        print("\nFleet Monitor shutting down...")
        return false -- Exit event loop
    end
}

SwarmUI.handleEvents(eventHandlers)