-- Puppetmaster Control Program with Enhanced Multi-Shell Support
-- Controls worker turtles wirelessly with multiple shell sessions
 
local COMMAND_CHANNEL = 100
local REPLY_CHANNEL = 101

-- Debug configuration
local DEBUG_COMMANDS = false -- Set to true to log all commands sent to workers

-- Track active shell sessions per turtle
local activeSessions = {} -- activeSessions[turtleId] = {sessionId1, sessionId2, ...}

-- Multishell tab management
local responseTab = nil
local menuTab = nil
local responseBuffer = {}
local MAX_BUFFER_LINES = 500
local VIEWER_CHANNEL = 102 -- Internal channel for sending logs to viewer tab

-- Check command line arguments to determine mode
local args = {...}
if args[1] == "response-viewer" then
    -- Response viewer mode - display log messages
    local viewerBuffer = {}
    local VIEWER_CHANNEL = 102 -- Internal channel for log updates
    
    local modem = peripheral.find("modem")
    if not modem then
        print("ERROR: Response viewer - No modem found!")
        return
    end
    
    modem.open(VIEWER_CHANNEL)
    
    local function redrawViewer()
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Turtle Response Log ===")
        print("(" .. #viewerBuffer .. " messages)")
        print("Listening on channel: " .. VIEWER_CHANNEL)
        print("Last event: " .. os.clock())
        print(string.rep("=", 28))
        print("")
        
        local w, h = term.getSize()
        local startLine = math.max(1, #viewerBuffer - (h - 7) + 1)
        
        for i = startLine, #viewerBuffer do
            print(viewerBuffer[i])
        end
    end
    
    redrawViewer()
    
    -- Listen for log updates via custom events
    while true do
        local event, logText = os.pullEvent("puppet_log")
        
        if logText then
            table.insert(viewerBuffer, logText)
            
            -- Keep buffer from growing too large
            while #viewerBuffer > 500 do
                table.remove(viewerBuffer, 1)
            end
            
            redrawViewer()
        end
    end
end

-- Main puppetmaster mode continues below
 
local modem = peripheral.find("modem")
if not modem then
    print("ERROR: No modem found!")
    return
end

-- Check if multishell is available
if not multishell then
    print("ERROR: Multishell not available!")
    print("This program requires an Advanced Computer.")
    return
end
 
modem.open(REPLY_CHANNEL)
modem.open(VIEWER_CHANNEL) -- Also open viewer channel for sending logs

-- Initialize response logging system
local function initResponseTab()
    -- Get current tab as menu tab
    menuTab = multishell.getCurrent()
    multishell.setTitle(menuTab, "Menu")
    
    -- Launch this program again in response viewer mode
    responseTab = multishell.launch({}, shell.getRunningProgram(), "response-viewer")
    multishell.setTitle(responseTab, "Turtle Responses")
    
    -- Switch back to main tab immediately
    multishell.setFocus(menuTab)
    
    -- Give it a moment to initialize
    os.sleep(0.1)
end

local function addToResponseBuffer(text)
    table.insert(responseBuffer, text)
    
    -- Keep buffer from growing too large
    while #responseBuffer > MAX_BUFFER_LINES do
        table.remove(responseBuffer, 1)
    end
end

local function updateResponseTab()
    if not responseTab or not multishell.getTitle(responseTab) then
        return -- Response tab was closed
    end
    
    -- Send the latest message to the viewer tab via custom event
    if #responseBuffer > 0 then
        local latestMessage = responseBuffer[#responseBuffer]
        os.queueEvent("puppet_log", latestMessage)
        
        if DEBUG_COMMANDS then
            print("[DEBUG] Queued log event: " .. latestMessage)
        end
    end
end

local function logResponse(text)
    local timestamp = os.date("%H:%M:%S")
    addToResponseBuffer("[" .. timestamp .. "] " .. text)
    updateResponseTab()
end
 
local function sendCommand(command, args, targetId)
    local message = {
        command = command,
        args = args or {},
        targetId = targetId,
        timestamp = os.epoch("utc")
    }
 
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, message)
 
    if DEBUG_COMMANDS then
        if targetId then
            print("Sent '" .. command .. "' to turtle #" .. targetId)
        else
            print("Broadcast '" .. command .. "' to all turtles")
        end
    end
end
 
local function listenForReplies(timeout)
    timeout = timeout or 3
    local timer = os.startTimer(timeout)
    local replies = {}
 
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
 
        if event == "timer" and p1 == timer then
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id then
                table.insert(replies, message)
 
                if message.shellOutput or message.shellPrompt or message.sessionInfo then
                    -- Handle shell-related messages - these still go to current term for interactive shell
                    local prefix = message.sessionId and ("[Session " .. message.sessionId .. "] ") or ""
                    if message.shellOutput then
                        write(prefix .. message.shellOutput)
                    elseif message.shellPrompt then
                        write(prefix .. message.shellPrompt)
                    elseif message.sessionInfo then
                        print(prefix .. message.sessionInfo)
                    end
                else
                    -- Regular responses go to the response tab
                    local status = message.success and "[OK]" or "[X]"
                    local logMsg = status .. " Turtle #" .. message.id .. ": " .. message.message
                    logResponse(logMsg)
                    
                    -- Also print a brief notification in the menu tab
                    print(">> Response from turtle #" .. message.id .. " (see Responses tab)")
                end
            end
        end
    end
 
    return replies
end
 
-- Enhanced Interactive Remote Shell Function with Multi-Session Support
local function enhancedRemoteShell(targetId)
    if not targetId then
        write("Enter turtle ID: ")
        targetId = tonumber(read())
    end
 
    if not targetId then
        print("Invalid turtle ID")
        return
    end

    -- Initialize session tracking for this turtle
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
    local inputBuffer = ""
    local promptDisplayed = false
 
    -- Custom input handler to better manage cursor positioning
    local function customRead()
        local input = ""
        local startX, startY = term.getCursorPos()
        
        while true do
            local event, key = os.pullEvent()
            
            if event == "char" then
                input = input .. key
                write(key)
            elseif event == "key" then
                if key == keys.enter then
                    print() -- Move to next line
                    return input
                elseif key == keys.backspace and #input > 0 then
                    input = input:sub(1, -2)
                    local x, y = term.getCursorPos()
                    term.setCursorPos(x - 1, y)
                    write(" ")
                    term.setCursorPos(x - 1, y)
                end
            elseif event == "modem_message" then
                -- Handle incoming messages while typing
                local message = key -- In this context, 'key' is actually the message
                if type(message) == "table" and message.id == targetId then
                    if message.shellOutput then
                        -- Save cursor position
                        local currentX, currentY = term.getCursorPos()
                        
                        -- Move to start of line, clear it, show output
                        term.setCursorPos(1, currentY)
                        term.clearLine()
                        
                        local prefix = message.sessionId and ("[Session " .. message.sessionId .. "] ") or ""
                        write(prefix .. message.shellOutput)
                        
                        -- Redraw the input line
                        local newX, newY = term.getCursorPos()
                        if newX > 1 then
                            print() -- Move to new line if needed
                            newX, newY = term.getCursorPos()
                        end
                        write(input)
                        
                    elseif message.shellPrompt then
                        -- Save current input
                        local currentX, currentY = term.getCursorPos()
                        
                        -- Clear current line and show prompt
                        term.setCursorPos(1, currentY)
                        term.clearLine()
                        
                        local prefix = message.sessionId and ("[Session " .. message.sessionId .. "] ") or ""
                        write(prefix .. message.shellPrompt)
                        
                        -- Redraw user input
                        write(input)
                        
                    elseif message.sessionInfo then
                        -- Save cursor position and input
                        local currentX, currentY = term.getCursorPos()
                        
                        -- Move to new line for info
                        if currentX > 1 or #input > 0 then
                            print()
                        end
                        print("[INFO] " .. message.sessionInfo)
                        
                        -- Track new sessions
                        if message.sessionInfo:match("Shell session #(%d+) created") then
                            local sessionId = tonumber(message.sessionInfo:match("Shell session #(%d+) created"))
                            if sessionId then
                                table.insert(activeSessions[targetId], sessionId)
                                currentSessionId = sessionId
                                print(">> Now connected to session #" .. sessionId)
                            end
                        end
                        
                        -- Redraw input if there was any
                        if #input > 0 then
                            write(input)
                        end
                    end
                end
            end
        end
    end
 
    -- Simplified input handler using custom read
    local function handleInput()
        while shellActive do
            local input = customRead()
 
            if input == "exit" then
                shellActive = false
                break
                
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
                    currentSessionId = activeSessions[targetId][1] -- Switch to first available
                end
                
            else
                -- Send command to current shell session
                if currentSessionId then
                    sendCommand("shellInput", {tostring(currentSessionId), input}, targetId)
                else
                    print("No active session! Use 'new' to create one.")
                end
            end
        end
    end
 
    -- Start with creating a new shell session
    sendCommand("createShell", {}, targetId)
 
    -- Run input handler (no parallel needed with custom read)
    handleInput()
 
    print("\nDisconnected from turtle #" .. targetId)
    os.sleep(2)
end
 
local function showMenu()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Main Menu ===")
    print("Listening on channel: " .. REPLY_CHANNEL)
    print("Response Tab: Active")
    print("")
    print("--- Commands ---")
    print("1. Ping all turtles")
    print("2. Check status")
    print("3. Run digDown")
    print("4. Custom command")
    print("5. Target specific turtle")
    print("6. Enhanced Multi-Shell")
    print("7. Simple Shell (Legacy)")
    print("8. Session Management")
    print("9. Reboot workers")
    print("I. Import Program")
    print("P. Provision Existing Program")
    print("R. View Response Tab")
    print("0. Exit")
    print("----------------")
    write("Select option: ")
end

-- Initialize the response tab
initResponseTab()
logResponse("Puppetmaster Control System initialized")
logResponse("Listening on channel " .. REPLY_CHANNEL)
 
-- Main control loop
while true do
    showMenu()
    local choice = read()
 
    if choice == "0" then
        print("Exiting puppetmaster...")
        break
 
    elseif choice == "1" then
        print("\nPinging all turtles...")
        sendCommand("ping")
        listenForReplies(3)
 
    elseif choice == "2" then
        print("\nChecking status...")
        sendCommand("status")
        listenForReplies(3)
 
    elseif choice == "3" then
        write("Enter depth: ")
        local depth = read()
        print("\nSending digDown command...")
        sendCommand("digDown", {depth})
        listenForReplies(5)
 
    elseif choice == "4" then
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
 
    elseif choice == "5" then
        write("Turtle ID: ")
        local targetId = tonumber(read())
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
 
    elseif choice == "6" then
        enhancedRemoteShell()
 
    elseif choice == "7" then
        -- Legacy simple shell
        write("Enter turtle ID: ")
        local targetId = tonumber(read())
        if targetId then
            sendCommand("startShell", {}, targetId)
            print("Legacy shell session started. Use enhanced shell for better experience.")
        else
            print("Invalid turtle ID")
        end

    elseif choice == "8" then
        -- Session management
        write("Turtle ID: ")
        local targetId = tonumber(read())
        if targetId then
            print("1. List sessions")
            print("2. Close specific session")
            write("Choice: ")
            local subChoice = read()
            
            if subChoice == "1" then
                sendCommand("listSessions", {}, targetId)
                listenForReplies(3)
            elseif subChoice == "2" then
                write("Session ID to close: ")
                local sessionId = read()
                sendCommand("closeShell", {sessionId}, targetId)
                listenForReplies(3)
            end
        else
            print("Invalid turtle ID")
        end
 
    elseif choice == "9" then
        write("Reboot all workers? (y/n): ")
        if read() == "y" then
            sendCommand("reboot")
            listenForReplies(2)
        end
    
    elseif choice == "I" or choice == "i" then
        -- Import program via drag-and-drop
        print("\n=== Program Import ===")
        print("Drag and drop .lua files onto this window")
        print("Files will be saved to programs/ directory")
        print("Press Ctrl+T to cancel")
        print("")
        print("Waiting for files...")
        
        -- Create programs directory if it doesn't exist
        if not fs.exists("programs") then
            fs.makeDir("programs")
        end
        
        local importedFiles = {}
        
        while true do
            local event, files = os.pullEvent()
            
            if event == "file_transfer" then
                local fileList = files.getFiles()
                print("\nReceived " .. #fileList .. " file(s)")
                
                for _, file in ipairs(fileList) do
                    local fileName = file.getName()
                    
                    -- Only accept .lua files
                    if not fileName:match("%.lua$") then
                        print("Skipped: " .. fileName .. " (not a .lua file)")
                        file.close()
                    else
                        -- Get file size
                        local size = file.seek("end")
                        file.seek("set", 0)
                        
                        local programPath = "programs/" .. fileName
                        
                        -- Check if file exists
                        if fs.exists(programPath) then
                            write("Overwrite " .. fileName .. "? (y/n): ")
                            if read() ~= "y" then
                                print("Skipped: " .. fileName)
                                file.close()
                            else
                                -- Save the file
                                local handle = fs.open(programPath, "wb")
                                handle.write(file.readAll())
                                handle.close()
                                file.close()
                                
                                print("[OK] " .. fileName .. " (" .. size .. " bytes)")
                                table.insert(importedFiles, {name = fileName, path = programPath, size = size})
                            end
                        else
                            -- Save the file
                            local handle = fs.open(programPath, "wb")
                            handle.write(file.readAll())
                            handle.close()
                            file.close()
                            
                            print("[OK] " .. fileName .. " (" .. size .. " bytes)")
                            table.insert(importedFiles, {name = fileName, path = programPath, size = size})
                        end
                    end
                end
                
                -- Ask if they want to provision
                if #importedFiles > 0 then
                    print("\nImported " .. #importedFiles .. " file(s) successfully!")
                    write("\nProvision all to turtles? (y/n): ")
                    
                    if read() == "y" then
                        for _, fileInfo in ipairs(importedFiles) do
                            print("\n--- Provisioning " .. fileInfo.name .. " ---")
                            
                            local file = fs.open(fileInfo.path, "r")
                            if file then
                                local content = file.readAll()
                                file.close()
                                
                                -- Split content into chunks
                                local chunkSize = 6000
                                local chunks = {}
                                local totalChunks = math.ceil(#content / chunkSize)
                                
                                for i = 1, totalChunks do
                                    local startPos = (i - 1) * chunkSize + 1
                                    local endPos = math.min(i * chunkSize, #content)
                                    chunks[i] = content:sub(startPos, endPos)
                                end
                                
                                print("Size: " .. #content .. " bytes (" .. totalChunks .. " chunks)")
                                
                                -- Send deployment command
                                sendCommand("deployProgram", {
                                    fileInfo.name,
                                    tostring(totalChunks)
                                })
                                
                                os.sleep(0.5)
                                
                                -- Send chunks
                                for i, chunk in ipairs(chunks) do
                                    print("Chunk " .. i .. "/" .. totalChunks)
                                    sendCommand("programChunk", {
                                        fileInfo.name,
                                        tostring(i),
                                        tostring(totalChunks),
                                        chunk
                                    })
                                    os.sleep(0.3)
                                end
                            end
                        end
                        
                        print("\nWaiting for confirmations...")
                        listenForReplies(5)
                        print("Deployment complete!")
                    end
                end
                
                break -- Exit after processing files
                
            elseif event == "terminate" then
                print("\nImport cancelled")
                break
            end
        end
    
    elseif choice == "P" or choice == "p" then
        -- Provision program to turtles
        print("\n=== Program Provisioning ===")
        write("Program filename (in programs/): ")
        local programName = read()
        
        if not programName or programName == "" then
            print("Invalid filename")
        else
            local programPath = "programs/" .. programName
            if not programPath:match("%.lua$") then
                programPath = programPath .. ".lua"
            end
            
            if not fs.exists(programPath) then
                print("ERROR: File not found: " .. programPath)
            else
                -- Read the program file
                local file = fs.open(programPath, "r")
                if not file then
                    print("ERROR: Could not read file")
                else
                    local content = file.readAll()
                    file.close()
                    
                    print("File size: " .. #content .. " bytes")
                    print("Target: All turtles")
                    write("Proceed with deployment? (y/n): ")
                    
                    if read() == "y" then
                        print("\nDeploying " .. programName .. " to all turtles...")
                        
                        -- Split content into chunks (max ~6000 bytes per message to be safe)
                        local chunkSize = 6000
                        local chunks = {}
                        local totalChunks = math.ceil(#content / chunkSize)
                        
                        for i = 1, totalChunks do
                            local startPos = (i - 1) * chunkSize + 1
                            local endPos = math.min(i * chunkSize, #content)
                            chunks[i] = content:sub(startPos, endPos)
                        end
                        
                        print("Split into " .. totalChunks .. " chunks")
                        
                        -- Send deployment command
                        sendCommand("deployProgram", {
                            programName,
                            tostring(totalChunks)
                        })
                        
                        os.sleep(0.5)
                        
                        -- Send chunks
                        for i, chunk in ipairs(chunks) do
                            print("Sending chunk " .. i .. "/" .. totalChunks)
                            sendCommand("programChunk", {
                                programName,
                                tostring(i),
                                tostring(totalChunks),
                                chunk
                            })
                            os.sleep(0.3) -- Small delay between chunks
                        end
                        
                        print("Waiting for confirmations...")
                        listenForReplies(5)
                        print("Deployment complete!")
                    else
                        print("Deployment cancelled")
                    end
                end
            end
        end
    
    elseif choice == "R" or choice == "r" then
        -- Switch to response tab
        if responseTab and multishell.getTitle(responseTab) then
            multishell.setFocus(responseTab)
            print("\nPress any key to return to menu...")
            read()
            if menuTab then
                multishell.setFocus(menuTab)
            end
        else
            print("Response tab not available. Reinitializing...")
            initResponseTab()
            os.sleep(1)
        end
    end
end
 