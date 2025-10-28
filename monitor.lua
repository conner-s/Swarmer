-- Turtle Fleet Monitor
-- Displays turtle positions and IDs on a monitor
-- Requires a 3-tall by 5-wide monitor connected to the computer

-- Check command line arguments to determine mode
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
    local monitorTab = multishell.launch({}, shell.getRunningProgram(), "monitor-mode")
    multishell.setTitle(monitorTab, "Fleet Monitor")
    
    -- Switch to monitor tab
    multishell.setFocus(monitorTab)
    
    -- This initial instance can now exit - the new tab will run the actual program
    return
end

local COMMAND_CHANNEL = 100
local REPLY_CHANNEL = 101
local UPDATE_INTERVAL = 5 -- Seconds between position updates

-- Find and wrap the monitor
local monitor = peripheral.find("monitor")
if not monitor then
    print("ERROR: No monitor found!")
    print("Please connect a monitor to this computer.")
    return
end

-- Find the modem
local modem = peripheral.find("modem")
if not modem then
    print("ERROR: No modem found!")
    return
end

modem.open(REPLY_CHANNEL)

-- Turtle tracking
local turtles = {} -- turtles[id] = {x, y, z, fuel, lastSeen}

-- Monitor configuration
local monWidth, monHeight = monitor.getSize()
print("Monitor size: " .. monWidth .. "x" .. monHeight)

-- Set monitor scale if needed
monitor.setTextScale(0.5)
monWidth, monHeight = monitor.getSize()
print("Scaled size: " .. monWidth .. "x" .. monHeight)

-- Advanced color scheme
local theme = {
    background = colors.black,
    headerBg = colors.gray,
    headerText = colors.white,
    titleBg = colors.blue,
    titleText = colors.yellow,
    activeBg = colors.green,
    activeText = colors.white,
    turtleIdBg = colors.lightGray,
    turtleIdText = colors.black,
    positionBg = colors.black,
    positionText = colors.lightBlue,
    timeText = colors.orange,
    accentLine = colors.cyan
}

local function drawHeader()
    -- Clear screen
    monitor.setBackgroundColor(theme.background)
    monitor.clear()
    
    -- Title bar with colored background
    monitor.setBackgroundColor(theme.titleBg)
    monitor.setTextColor(theme.titleText)
    monitor.setCursorPos(1, 1)
    monitor.write(string.rep(" ", monWidth))
    monitor.setCursorPos(2, 1)
    monitor.write("FLEET MONITOR")
    
    -- Decorative line
    monitor.setBackgroundColor(theme.background)
    monitor.setTextColor(theme.accentLine)
    monitor.setCursorPos(1, 2)
    monitor.write(string.rep("=", monWidth))
end

local function updateDisplay()
    drawHeader()
    
    -- Count active turtles
    local activeTurtles = 0
    local now = os.epoch("utc")
    
    for id, data in pairs(turtles) do
        -- Consider turtle active if seen in last 30 seconds
        if now - data.lastSeen < 30000 then
            activeTurtles = activeTurtles + 1
        end
    end
    
    -- Status bar with active count
    monitor.setBackgroundColor(theme.activeBg)
    monitor.setTextColor(theme.activeText)
    monitor.setCursorPos(1, 3)
    local statusText = " ACTIVE: " .. activeTurtles .. " "
    monitor.write(statusText)
    -- Fill rest of line
    monitor.setBackgroundColor(theme.background)
    monitor.write(string.rep(" ", monWidth - #statusText))
    
    -- Display turtle list header
    monitor.setCursorPos(1, 4)
    monitor.setBackgroundColor(theme.headerBg)
    monitor.setTextColor(theme.headerText)
    monitor.write(" ID ")
    monitor.write(string.rep(" ", monWidth - 4))
    
    monitor.setCursorPos(6, 4)
    monitor.write("POSITION")
    
    -- Display turtle list
    local line = 5
    local sortedTurtles = {}
    
    for id, data in pairs(turtles) do
        if now - data.lastSeen < 30000 then
            table.insert(sortedTurtles, {id = id, data = data})
        end
    end
    
    -- Sort by ID
    table.sort(sortedTurtles, function(a, b) return a.id < b.id end)
    
    -- Display each turtle with alternating background
    for i, entry in ipairs(sortedTurtles) do
        if line > monHeight - 1 then break end -- Leave room for footer
        
        -- Alternating row colors
        local rowBg = (i % 2 == 0) and colors.gray or colors.black
        
        monitor.setBackgroundColor(rowBg)
        monitor.setCursorPos(1, line)
        monitor.write(string.rep(" ", monWidth))
        
        -- Turtle ID with highlight
        monitor.setCursorPos(1, line)
        monitor.setBackgroundColor(theme.turtleIdBg)
        monitor.setTextColor(theme.turtleIdText)
        local idText = " #" .. entry.id .. " "
        monitor.write(idText)
        
        -- Position
        monitor.setBackgroundColor(rowBg)
        monitor.setCursorPos(6, line)
        monitor.setTextColor(theme.positionText)
        
        if entry.data.x then
            local posText = string.format("%d,%d,%d", entry.data.x, entry.data.y, entry.data.z)
            -- Truncate if too long
            if #posText > (monWidth - 6) then
                posText = posText:sub(1, monWidth - 9) .. "..."
            end
            monitor.write(posText)
        else
            monitor.setTextColor(colors.red)
            monitor.write("No GPS")
        end
        
        line = line + 1
    end
    
    -- Clear any remaining lines
    monitor.setBackgroundColor(theme.background)
    while line < monHeight do
        monitor.setCursorPos(1, line)
        monitor.write(string.rep(" ", monWidth))
        line = line + 1
    end
    
    -- Footer with timestamp
    monitor.setBackgroundColor(theme.headerBg)
    monitor.setCursorPos(1, monHeight)
    monitor.write(string.rep(" ", monWidth))
    monitor.setCursorPos(2, monHeight)
    monitor.setTextColor(theme.timeText)
    monitor.write(os.date("%H:%M:%S"))
end

local function requestStatus()
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = "status",
        args = {},
        timestamp = os.epoch("utc")
    })
end

local function handleMessage(message)
    if type(message) == "table" and message.id then
        -- Update turtle record
        if not turtles[message.id] then
            turtles[message.id] = {}
        end
        
        local turtle = turtles[message.id]
        turtle.lastSeen = os.epoch("utc")
        
        -- Extract position if available
        if message.position then
            turtle.x = message.position.x
            turtle.y = message.position.y
            turtle.z = message.position.z
        end
        
        if message.fuel then
            turtle.fuel = message.fuel
        end
        
        updateDisplay()
    end
end

-- Initial display
drawHeader()
monitor.setBackgroundColor(theme.background)
monitor.setCursorPos(1, 5)
monitor.setTextColor(colors.yellow)
local waitText = "Initializing..."
monitor.setCursorPos(math.floor((monWidth - #waitText) / 2), math.floor(monHeight / 2))
monitor.write(waitText)

print("Fleet Monitor started")
print("Monitoring " .. monWidth .. "x" .. monHeight .. " display")
print("Press Ctrl+T to exit")

-- Request initial status
requestStatus()

-- Main loop
local lastRequest = os.epoch("utc")

while true do
    local event, p1, p2, p3, p4, p5 = os.pullEvent()
    
    if event == "modem_message" then
        local message = p4
        handleMessage(message)
    elseif event == "timer" then
        -- Periodic status request
        local now = os.epoch("utc")
        if now - lastRequest > (UPDATE_INTERVAL * 1000) then
            requestStatus()
            lastRequest = now
            updateDisplay() -- Refresh display to update timestamps
        end
    end
    
    -- Set timer for next update if not set
    if not os.startTimer then
        os.startTimer(UPDATE_INTERVAL)
    end
end
