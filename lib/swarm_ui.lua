-- Swarm UI Library
-- UI components and multishell management for swarm programs
-- Version: 3.0

local SwarmCommon = require("lib.swarm_common")
local SwarmUI = {}

-- Color theme for consistent styling
SwarmUI.THEME = {
    background = colors.black,
    headerBg = colors.gray,
    headerText = colors.white,
    titleBg = colors.blue,
    titleText = colors.yellow,
    activeBg = colors.green,
    activeText = colors.white,
    errorBg = colors.red,
    errorText = colors.white,
    successBg = colors.lime,
    successText = colors.black,
    turtleIdBg = colors.lightGray,
    turtleIdText = colors.black,
    positionText = colors.lightBlue,
    timeText = colors.orange,
    accentLine = colors.cyan
}

-- Response buffer management
SwarmUI.ResponseBuffer = {}
SwarmUI.ResponseBuffer.__index = SwarmUI.ResponseBuffer

function SwarmUI.ResponseBuffer.new(maxLines)
    local self = setmetatable({}, SwarmUI.ResponseBuffer)
    self.buffer = {}
    self.maxLines = maxLines or 500
    return self
end

function SwarmUI.ResponseBuffer:add(text)
    table.insert(self.buffer, text)
    
    while #self.buffer > self.maxLines do
        table.remove(self.buffer, 1)
    end
end

function SwarmUI.ResponseBuffer:getLatest()
    return self.buffer[#self.buffer]
end

function SwarmUI.ResponseBuffer:getAll()
    return self.buffer
end

function SwarmUI.ResponseBuffer:clear()
    self.buffer = {}
end

function SwarmUI.ResponseBuffer:size()
    return #self.buffer
end

-- Multishell tab management
SwarmUI.TabManager = {}
SwarmUI.TabManager.__index = SwarmUI.TabManager

function SwarmUI.TabManager.new()
    local self = setmetatable({}, SwarmUI.TabManager)
    self.tabs = {}
    self.currentTab = nil
    return self
end

function SwarmUI.TabManager:createTab(title, program, args)
    if not multishell then
        return nil, "Multishell not available"
    end
    
    -- Empty table lets multishell create a proper shell environment
    -- This gives the new tab access to shell, require, fs, etc.
    local tabId = multishell.launch({}, program, table.unpack(args or {}))
    if tabId then
        multishell.setTitle(tabId, title)
        self.tabs[tabId] = {
            id = tabId,
            title = title,
            program = program,
            args = args
        }
        return tabId
    end
    
    return nil, "Failed to create tab"
end

function SwarmUI.TabManager:switchTo(tabId)
    if not multishell or not self.tabs[tabId] then
        return false
    end
    
    multishell.setFocus(tabId)
    self.currentTab = tabId
    return true
end

function SwarmUI.TabManager:closeTab(tabId)
    if not multishell or not self.tabs[tabId] then
        return false
    end
    
    -- Note: Actual tab closing is handled by the shell itself
    self.tabs[tabId] = nil
    if self.currentTab == tabId then
        self.currentTab = nil
    end
    return true
end

function SwarmUI.TabManager:getCurrentTab()
    return self.currentTab or multishell.getCurrent()
end

function SwarmUI.TabManager:setTitle(tabId, title)
    if not multishell or not self.tabs[tabId] then
        return false
    end
    
    multishell.setTitle(tabId, title)
    self.tabs[tabId].title = title
    return true
end

-- Response viewer system
SwarmUI.ResponseViewer = {}
SwarmUI.ResponseViewer.__index = SwarmUI.ResponseViewer

function SwarmUI.ResponseViewer.new(channel)
    local self = setmetatable({}, SwarmUI.ResponseViewer)
    self.buffer = SwarmUI.ResponseBuffer.new()
    self.channel = channel or SwarmCommon.VIEWER_CHANNEL
    self.modem = nil
    return self
end

function SwarmUI.ResponseViewer:init()
    local modem, err = SwarmCommon.initModem()
    if not modem then
        return false, err
    end
    
    self.modem = modem
    SwarmCommon.openChannels(modem, {self.channel})
    return true
end

function SwarmUI.ResponseViewer:addMessage(text)
    local timestamp = SwarmCommon.formatTimestamp()
    local message = "[" .. timestamp .. "] " .. text
    self.buffer:add(message)
    
    -- Send to viewer if available
    if self.modem then
        os.queueEvent("puppet_log", message)
    end
end

function SwarmUI.ResponseViewer:display()
    term.clear()
    term.setCursorPos(1, 1)
    
    print("=== Turtle Response Log ===")
    print("(" .. self.buffer:size() .. " messages)")
    print("Listening on channel: " .. self.channel)
    print("Last update: " .. SwarmCommon.formatTimestamp())
    print(string.rep("=", 28))
    print("")
    
    local w, h = term.getSize()
    local messages = self.buffer:getAll()
    local startLine = math.max(1, #messages - (h - 7) + 1)
    
    for i = startLine, #messages do
        print(messages[i])
    end
end

function SwarmUI.ResponseViewer:run()
    if not self:init() then
        print("ERROR: Failed to initialize response viewer")
        return
    end
    
    self:display()
    
    while true do
        local event, logText = os.pullEvent("puppet_log")
        
        if logText then
            self.buffer:add(logText)
            self:display()
        end
    end
end

-- Menu system
SwarmUI.Menu = {}
SwarmUI.Menu.__index = SwarmUI.Menu

function SwarmUI.Menu.new(title, options)
    local self = setmetatable({}, SwarmUI.Menu)
    self.title = title or "Menu"
    self.options = options or {}
    self.running = false
    return self
end

function SwarmUI.Menu:addOption(key, text, callback)
    self.options[key] = {
        text = text,
        callback = callback
    }
end

function SwarmUI.Menu:removeOption(key)
    self.options[key] = nil
end

function SwarmUI.Menu:display()
    term.clear()
    term.setCursorPos(1, 1)
    
    -- Title
    term.setTextColor(SwarmUI.THEME.titleText)
    term.setBackgroundColor(SwarmUI.THEME.titleBg)
    print("=== " .. self.title .. " ===")
    term.setBackgroundColor(SwarmUI.THEME.background)
    print("")
    
    -- Options
    local sortedKeys = {}
    for key in pairs(self.options) do
        table.insert(sortedKeys, key)
    end
    table.sort(sortedKeys)
    
    for _, key in ipairs(sortedKeys) do
        local option = self.options[key]
        print(key .. ". " .. option.text)
    end
    
    print("")
    term.setTextColor(SwarmUI.THEME.headerText)
    write("Choice: ")
    term.setTextColor(colors.white)
end

function SwarmUI.Menu:run()
    self.running = true
    
    while self.running do
        self:display()
        local choice = read()
        
        local option = self.options[choice]
        if option and option.callback then
            local result = option.callback(choice)
            if result == false then
                self.running = false
            end
        else
            print("Invalid choice: " .. choice)
            print("Press Enter to continue...")
            read()
        end
    end
end

function SwarmUI.Menu:stop()
    self.running = false
end

-- Progress display utilities
function SwarmUI.showProgress(current, total, message)
    local percentage = math.floor((current / total) * 100)
    local barWidth = 20
    local filled = math.floor((current / total) * barWidth)
    
    local bar = "[" .. string.rep("=", filled) .. string.rep("-", barWidth - filled) .. "]"
    
    term.clearLine()
    term.setCursorPos(1, select(2, term.getCursorPos()))
    write(message .. " " .. bar .. " " .. percentage .. "% (" .. current .. "/" .. total .. ")")
end

-- Status display utilities
function SwarmUI.showStatus(message, type)
    local color = colors.white
    local prefix = "[INFO]"
    
    if type == "success" then
        color = SwarmUI.THEME.successText
        prefix = "[OK]"
    elseif type == "error" then
        color = SwarmUI.THEME.errorText
        prefix = "[ERROR]"
    elseif type == "warning" then
        color = colors.yellow
        prefix = "[WARN]"
    end
    
    term.setTextColor(color)
    print(prefix .. " " .. message)
    term.setTextColor(colors.white)
end

-- Input utilities
function SwarmUI.promptNumber(prompt, min, max)
    while true do
        write(prompt)
        local input = read()
        local valid, num = SwarmCommon.validateNumber(input, min, max)
        
        if valid then
            return num
        else
            SwarmUI.showStatus(num, "error")
        end
    end
end

function SwarmUI.promptChoice(prompt, choices)
    while true do
        write(prompt .. " (" .. table.concat(choices, "/") .. "): ")
        local input = read():lower()
        
        for _, choice in ipairs(choices) do
            if input == choice:lower() then
                return choice
            end
        end
        
        SwarmUI.showStatus("Invalid choice. Please select from: " .. table.concat(choices, ", "), "error")
    end
end

function SwarmUI.confirm(prompt)
    return SwarmUI.promptChoice(prompt, {"y", "n"}) == "y"
end

-- Monitor utilities
function SwarmUI.initMonitor(scale)
    local monitor = peripheral.find("monitor")
    if not monitor then
        return nil, "No monitor found"
    end
    
    if scale then
        monitor.setTextScale(scale)
    end
    
    monitor.setBackgroundColor(SwarmUI.THEME.background)
    monitor.clear()
    
    return monitor
end

function SwarmUI.drawMonitorHeader(monitor, title)
    if not monitor then return false end
    
    local width = monitor.getSize()
    
    -- Title bar
    monitor.setBackgroundColor(SwarmUI.THEME.titleBg)
    monitor.setTextColor(SwarmUI.THEME.titleText)
    monitor.setCursorPos(1, 1)
    monitor.write(string.rep(" ", width))
    monitor.setCursorPos(2, 1)
    monitor.write(title)
    
    -- Accent line
    monitor.setBackgroundColor(SwarmUI.THEME.background)
    monitor.setTextColor(SwarmUI.THEME.accentLine)
    monitor.setCursorPos(1, 2)
    monitor.write(string.rep("=", width))
    
    return true
end

-- List display utilities
function SwarmUI.displayList(items, formatter, startLine)
    startLine = startLine or select(2, term.getCursorPos())
    
    if not formatter then
        formatter = tostring
    end
    
    for i, item in ipairs(items) do
        term.setCursorPos(1, startLine + i - 1)
        term.clearLine()
        print(formatter(item, i))
    end
end

-- Event handling utilities
function SwarmUI.handleEvents(handlers, timeout)
    local timer = timeout and os.startTimer(timeout)
    
    while true do
        local eventData = {os.pullEvent()}
        local event = eventData[1]
        
        if event == "timer" and timer and eventData[2] == timer then
            break
        elseif handlers[event] then
            local result = handlers[event](table.unpack(eventData, 2))
            if result == false then
                break
            end
        elseif handlers.default then
            local result = handlers.default(table.unpack(eventData))
            if result == false then
                break
            end
        end
    end
end

return SwarmUI