-- Puppetmaster Control Program v3.0
-- Controls worker turtles wirelessly with enhanced UI and reduced duplication
-- Refactored to use common libraries

local SwarmCommon = require("lib.swarm_common")
local SwarmUI = require("lib.swarm_ui")

-- Version information
local PUPPETMASTER_VERSION = "3.0"

-- Debug configuration
local DEBUG_COMMANDS = false

-- Session tracking
local activeSessions = {}

-- UI components
local responseBuffer = nil
local tabManager = nil
local mainMenu = nil

-- Check command line arguments to determine mode
local args = {...}
if args[1] == "response-viewer" then
    -- Response viewer mode
    local viewer = SwarmUI.ResponseViewer.new()
    viewer:run()
    return
end

-- Main puppetmaster mode
local modem, err = SwarmCommon.initModem()
if not modem then
    print("ERROR: " .. err)
    return
end

-- Check for multishell support
if not multishell then
    print("ERROR: Multishell not available!")
    print("This program requires an Advanced Computer.")
    return
end

-- Open required channels
SwarmCommon.openChannels(modem, {SwarmCommon.VIEWER_CHANNEL})

-- Initialize UI components
responseBuffer = SwarmUI.ResponseBuffer.new()
tabManager = SwarmUI.TabManager.new()

-- Initialize response logging system
local function initResponseTab()
    local menuTab = tabManager:getCurrentTab()
    tabManager:setTitle(menuTab, "Menu")
    
    local responseTab = tabManager:createTab("Turtle Responses", shell.getRunningProgram(), {"response-viewer"})
    if responseTab then
        tabManager:switchTo(menuTab)
        os.sleep(0.1) -- Give viewer time to initialize
    end
end

local function logResponse(text)
    responseBuffer:add(SwarmCommon.formatLogMessage("", text))
    
    -- Send to response viewer
    local latest = responseBuffer:getLatest()
    if latest then
        os.queueEvent("puppet_log", latest)
    end
    
    if DEBUG_COMMANDS then
        print("[DEBUG] Logged: " .. text)
    end
end

-- Enhanced message sending with logging
local function sendCommand(command, args, targetId, options)
    local success = SwarmCommon.sendCommand(modem, command, args, targetId, options)
    
    if DEBUG_COMMANDS then
        local target = targetId and ("turtle #" .. targetId) or "all turtles"
        print("Sent '" .. command .. "' to " .. target)
    end
    
    return success
end

-- Enhanced reply collection with response logging
local function listenForReplies(timeout)
    timeout = timeout or 3
    local replies = SwarmCommon.collectReplies(timeout, function(message)
        -- Handle different message types
        if message.shellOutput or message.shellPrompt or message.sessionInfo then
            -- Shell messages go to current terminal for interactive use
            local prefix = message.sessionId and ("[Session " .. message.sessionId .. "] ") or ""
            if message.shellOutput then
                write(prefix .. message.shellOutput)
            elseif message.shellPrompt then
                write(prefix .. message.shellPrompt)
            elseif message.sessionInfo then
                print(prefix .. message.sessionInfo)
            end
        else
            -- Regular responses go to response log
            local status = message.success and "OK" or "X"
            logResponse(status .. " Turtle #" .. message.id .. ": " .. message.message)
            print(">> Response from turtle #" .. message.id .. " (see Responses tab)")
        end
        return true
    end)
    
    return replies
end

-- Enhanced Remote Shell with improved session management
local function enhancedRemoteShell(targetId)
    if not targetId then
        targetId = SwarmUI.promptNumber("Enter turtle ID: ", 1)
    end
    
    if not activeSessions[targetId] then
        activeSessions[targetId] = {}
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Enhanced Multi-Shell: Turtle #" .. targetId .. " ===")
    print("Commands:")
    print("  'new' - Create new shell session")
    print("  'list' - List active sessions")
    print("  'switch <id>' - Switch to session")
    print("  'close <id>' - Close session")
    print("  'exit' - Disconnect")
    print("  Any other input goes to current session")
    print("")
    
    local shellActive = true
    local currentSessionId = nil
    
    -- Event handlers for shell interaction
    local eventHandlers = {
        char = function(char)
            return char -- Continue processing
        end,
        
        key = function(key)
            if key == keys.enter then
                return "enter"
            elseif key == keys.backspace then
                return "backspace"
            end
        end,
        
        modem_message = function(side, channel, replyChannel, message)
            if type(message) == "table" and message.id == targetId then
                if message.shellOutput then
                    local prefix = message.sessionId and ("[Session " .. message.sessionId .. "] ") or ""
                    write(prefix .. message.shellOutput)
                elseif message.shellPrompt then
                    local prefix = message.sessionId and ("[Session " .. message.sessionId .. "] ") or ""
                    write(prefix .. message.shellPrompt)
                elseif message.sessionInfo then
                    print("[INFO] " .. message.sessionInfo)
                    
                    -- Track new sessions
                    local sessionId = message.sessionInfo:match("Shell session #(%d+) created")
                    if sessionId then
                        sessionId = tonumber(sessionId)
                        table.insert(activeSessions[targetId], sessionId)
                        currentSessionId = sessionId
                        print(">> Now connected to session #" .. sessionId)
                    end
                end
            end
        end
    }
    
    -- Input handling
    local function handleInput()
        while shellActive do
            write("> ")
            local input = read()
            
            if input == "exit" then
                shellActive = false
                
            elseif input == "new" then
                sendCommand("createShell", {}, targetId)
                
            elseif input == "list" then
                sendCommand("listSessions", {}, targetId)
                
            elseif input:match("^switch%s+(%d+)$") then
                local sessionId = tonumber(input:match("^switch%s+(%d+)$"))
                currentSessionId = sessionId
                sendCommand("switchTab", {tostring(sessionId)}, targetId)
                print(">> Switched to session #" .. sessionId)
                
            elseif input:match("^close%s+(%d+)$") then
                local sessionId = tonumber(input:match("^close%s+(%d+)$"))
                sendCommand("closeShell", {tostring(sessionId)}, targetId)
                
                -- Remove from tracking
                for i, id in ipairs(activeSessions[targetId]) do
                    if id == sessionId then
                        table.remove(activeSessions[targetId], i)
                        break
                    end
                end
                
                if currentSessionId == sessionId then
                    currentSessionId = activeSessions[targetId][1]
                end
                
            else
                -- Send to current session
                if currentSessionId then
                    sendCommand("shellInput", {tostring(currentSessionId), input}, targetId)
                else
                    print("No active session! Use 'new' to create one.")
                end
            end
        end
    end
    
    -- Start with new session
    sendCommand("createShell", {}, targetId)
    
    -- Handle input with event processing
    parallel.waitForAny(handleInput, function()
        while shellActive do
            SwarmUI.handleEvents(eventHandlers, 0.1)
        end
    end)
    
    print("\nDisconnected from turtle #" .. targetId)
    os.sleep(2)
end

-- Program import functionality
local function importPrograms()
    print("\n=== Program Import ===")
    print("Drag and drop .lua files onto this window")
    print("Files will be saved to programs/ directory")
    print("Press Ctrl+T to cancel")
    print("")
    print("Waiting for files...")
    
    SwarmCommon.ensureDirectory("programs")
    local importedFiles = {}
    
    local eventHandlers = {
        file_transfer = function(files)
            local fileList = files.getFiles()
            print("\nReceived " .. #fileList .. " file(s)")
            
            for _, file in ipairs(fileList) do
                local fileName = file.getName()
                
                if not fileName:match("%.lua$") then
                    print("Skipped: " .. fileName .. " (not a .lua file)")
                    file.close()
                else
                    local size = file.seek("end")
                    file.seek("set", 0)
                    local programPath = "programs/" .. fileName
                    
                    if fs.exists(programPath) then
                        if not SwarmUI.confirm("Overwrite " .. fileName .. "?") then
                            print("Skipped: " .. fileName)
                            file.close()
                            goto continue
                        end
                    end
                    
                    local handle = fs.open(programPath, "wb")
                    handle.write(file.readAll())
                    handle.close()
                    file.close()
                    
                    SwarmUI.showStatus(fileName .. " (" .. size .. " bytes)", "success")
                    table.insert(importedFiles, {name = fileName, path = programPath, size = size})
                end
                ::continue::
            end
            
            -- Ask about provisioning
            if #importedFiles > 0 then
                print("\nImported " .. #importedFiles .. " file(s) successfully!")
                if SwarmUI.confirm("Provision all to turtles?") then
                    for _, fileInfo in ipairs(importedFiles) do
                        provisionProgram(fileInfo.name)
                    end
                end
            end
            
            return false -- Exit event loop
        end,
        
        terminate = function()
            print("\nImport cancelled")
            return false
        end
    }
    
    SwarmUI.handleEvents(eventHandlers)
end

-- Program provisioning functionality
function provisionProgram(programName)
    local programPath = "programs/" .. programName
    if not programPath:match("%.lua$") then
        programPath = programPath .. ".lua"
    end
    
    if not fs.exists(programPath) then
        SwarmUI.showStatus("File not found: " .. programPath, "error")
        return false
    end
    
    local content, err = SwarmCommon.readFile(programPath)
    if not content then
        SwarmUI.showStatus(err, "error")
        return false
    end
    
    print("\n--- Provisioning " .. programName .. " ---")
    print("File size: " .. #content .. " bytes")
    
    if not SwarmUI.confirm("Proceed with deployment?") then
        print("Deployment cancelled")
        return false
    end
    
    -- Split into chunks
    local chunks = SwarmCommon.splitIntoChunks(content)
    print("Split into " .. #chunks .. " chunks")
    
    -- Send deployment command
    sendCommand("deployProgram", {programName, tostring(#chunks)})
    os.sleep(0.5)
    
    -- Send chunks with progress
    for i, chunk in ipairs(chunks) do
        SwarmUI.showProgress(i, #chunks, "Sending chunks")
        sendCommand("programChunk", {programName, tostring(i), tostring(#chunks), chunk})
        os.sleep(0.3)
    end
    
    print("\nWaiting for confirmations...")
    listenForReplies(5)
    SwarmUI.showStatus("Deployment complete!", "success")
    return true
end

-- Create main menu
local function createMainMenu()
    local menu = SwarmUI.Menu.new("Puppetmaster Control v" .. PUPPETMASTER_VERSION)
    
    menu:addOption("1", "Ping all turtles", function()
        print("\nPinging all turtles...")
        sendCommand("ping")
        listenForReplies(3)
    end)
    
    menu:addOption("2", "Check status", function()
        print("\nChecking status...")
        sendCommand("status")
        listenForReplies(3)
    end)
    
    menu:addOption("3", "Run digDown", function()
        local depth = SwarmUI.promptNumber("Enter depth: ", 1)
        print("\nSending digDown command...")
        sendCommand("digDown", {tostring(depth)})
        listenForReplies(5)
    end)
    
    menu:addOption("4", "Custom command", function()
        write("Program name: ")
        local program = read()
        write("Arguments (space-separated): ")
        local argString = read()
        
        local args = {}
        for arg in argString:gmatch("%S+") do
            table.insert(args, arg)
        end
        
        print("\nSending custom command...")
        sendCommand(program, args)
        listenForReplies(5)
    end)
    
    menu:addOption("5", "Target specific turtle", function()
        local targetId = SwarmUI.promptNumber("Turtle ID: ", 1)
        write("Command: ")
        local command = read()
        write("Arguments (space-separated): ")
        local argString = read()
        
        local args = {}
        for arg in argString:gmatch("%S+") do
            table.insert(args, arg)
        end
        
        print("\nSending to turtle #" .. targetId .. "...")
        sendCommand(command, args, targetId)
        listenForReplies(5)
    end)
    
    menu:addOption("6", "Enhanced Multi-Shell", function()
        enhancedRemoteShell()
    end)
    
    menu:addOption("7", "Session Management", function()
        local targetId = SwarmUI.promptNumber("Turtle ID: ", 1)
        local choice = SwarmUI.promptChoice("Action", {"list", "close"})
        
        if choice == "list" then
            sendCommand("listSessions", {}, targetId)
            listenForReplies(3)
        elseif choice == "close" then
            local sessionId = SwarmUI.promptNumber("Session ID to close: ", 1)
            sendCommand("closeShell", {tostring(sessionId)}, targetId)
            listenForReplies(3)
        end
    end)
    
    menu:addOption("8", "Reboot workers", function()
        if SwarmUI.confirm("Reboot all workers?") then
            sendCommand("reboot")
            listenForReplies(2)
        end
    end)
    
    menu:addOption("I", "Import Program", function()
        importPrograms()
    end)
    
    menu:addOption("P", "Provision Existing Program", function()
        write("Program filename (in programs/): ")
        local programName = read()
        if programName and programName ~= "" then
            provisionProgram(programName)
        else
            SwarmUI.showStatus("Invalid filename", "error")
        end
    end)
    
    menu:addOption("R", "View Response Tab", function()
        local currentTab = tabManager:getCurrentTab()
        -- Try to find response tab (this is simplified)
        print("Switching to response tab...")
        print("Press Enter to return...")
        read()
    end)
    
    menu:addOption("0", "Exit", function()
        return false -- Exit menu
    end)
    
    return menu
end

-- Initialize system
initResponseTab()
logResponse("Puppetmaster Control System v" .. PUPPETMASTER_VERSION .. " initialized")
logResponse("Listening on channel " .. SwarmCommon.REPLY_CHANNEL)

-- Create and run main menu
mainMenu = createMainMenu()
mainMenu:run()

print("Exiting puppetmaster...")