-- Production Worker v2.4
-- Turtle swarm worker - handles remote commands and program execution
-- Version: 2.4
-- Latest change: 

local COMMAND_CHANNEL = 100
local REPLY_CHANNEL = 101
local PROGRAMS_DIR = "programs"
local WORKER_VERSION = "2.4"

local turtleID = os.getComputerID()
local shellSessions = {}
local sessionCounter = 0
local programDeployments = {} -- Track incoming program deployments

-- Setup modem with error handling
local modem = peripheral.find("modem")
if not modem then
    print("ERROR: No modem found!")
    print("Install a wireless modem and restart")
    return
end

modem.open(COMMAND_CHANNEL)
modem.open(REPLY_CHANNEL)

print("Worker Turtle #" .. turtleID .. " online v" .. WORKER_VERSION)
print("Listening on channel " .. COMMAND_CHANNEL)

-- Message sending
local function sendMessage(messageType, content, sessionId, success)
    local message = {
        id = turtleID,
        timestamp = os.epoch("utc"),
        version = WORKER_VERSION
    }
    
    if messageType == "status" then
        message.message = content
        message.success = success
    elseif messageType == "shell" then
        message.shellOutput = content
        message.sessionId = sessionId
    elseif messageType == "prompt" then
        message.shellPrompt = content
        message.sessionId = sessionId
    elseif messageType == "info" then
        message.sessionInfo = content
        message.sessionId = sessionId
    end
    
    modem.transmit(REPLY_CHANNEL, COMMAND_CHANNEL, message)
end

-- Session creation
local function createSession(sessionId)
    local session = {
        id = sessionId,
        active = true,
        tabId = nil,
        workingDir = shell.dir()
    }
    
    if multishell then
        sendMessage("info", "Shell session #" .. sessionId .. " created (remote only)", sessionId)
    else
        sendMessage("info", "Shell session #" .. sessionId .. " created (no multishell)", sessionId)
    end
    
    shellSessions[sessionId] = session
    sendMessage("shell", "Remote shell #" .. sessionId .. " ready\n", sessionId)
    sendMessage("prompt", session.workingDir .. "> ", sessionId)
    
    return session
end

-- Command execution
local function executeShellCommand(sessionId, input)
    local session = shellSessions[sessionId]
    if not session or not session.active then
        sendMessage("info", "Session #" .. sessionId .. " not available", sessionId)
        return
    end
    
    local originalDir = shell.dir()
    shell.setDir(session.workingDir)
    
    sendMessage("info", "Executing: '" .. input .. "' in " .. session.workingDir, sessionId)
    
    -- Built-in commands
    if input == "help" or input == "?" then
        sendMessage("shell", "Available: ls, cd, mkdir, rm, cp, mv, edit, programs, etc.\n", sessionId)
        sendMessage("prompt", session.workingDir .. "> ", sessionId)
        return
    elseif input == "pwd" then
        sendMessage("shell", session.workingDir .. "\n", sessionId)
        sendMessage("prompt", session.workingDir .. "> ", sessionId)
        return
    elseif input:match("^echo%s+") then
        local text = input:match("^echo%s+(.+)")
        sendMessage("shell", text .. "\n", sessionId)
        sendMessage("prompt", session.workingDir .. "> ", sessionId)
        return
    elseif input == "ls" or input == "dir" then
        local files = fs.list(session.workingDir)
        table.sort(files)
        local output = {}
        for _, file in ipairs(files) do
            if fs.isDir(fs.combine(session.workingDir, file)) then
                table.insert(output, file .. "/")
            else
                table.insert(output, file)
            end
        end
        sendMessage("shell", table.concat(output, "  ") .. "\n", sessionId)
        sendMessage("prompt", session.workingDir .. "> ", sessionId)
        return
    elseif input:match("^cd%s*") then
        local targetDir = input:match("^cd%s+(.+)") or ""
        if targetDir == "" then
            session.workingDir = ""
        else
            local newDir = fs.combine(session.workingDir, targetDir)
            if fs.exists(newDir) and fs.isDir(newDir) then
                session.workingDir = newDir
            else
                sendMessage("shell", "cd: no such directory: " .. targetDir .. "\n", sessionId)
            end
        end
        sendMessage("prompt", session.workingDir .. "> ", sessionId)
        return
    end
    
    -- Standard command execution
    local output = {}
    local oldPrint = print
    local oldWrite = write
    
    print = function(...)
        local args = {...}
        table.insert(output, table.concat(args, " "))
        table.insert(output, "\n")
    end
    
    write = function(text)
        if text then
            table.insert(output, tostring(text))
        end
    end
    
    local success, err = pcall(function()
        shell.run(input)
    end)
    
    session.workingDir = shell.dir()
    
    print = oldPrint
    write = oldWrite
    shell.setDir(originalDir)
    
    local outputText = table.concat(output)
    if outputText and outputText ~= "" then
        sendMessage("shell", outputText, sessionId)
    elseif success then
        sendMessage("shell", "(command completed)\n", sessionId)
    end
    
    if not success then
        sendMessage("shell", "Error: " .. tostring(err) .. "\n", sessionId)
    end
    
    sendMessage("prompt", session.workingDir .. "> ", sessionId)
end

-- Session management
local function closeSession(sessionId)
    local session = shellSessions[sessionId]
    if session then
        session.active = false
        shellSessions[sessionId] = nil
        sendMessage("info", "Session #" .. sessionId .. " closed", sessionId)
        sendMessage("shell", "Session ended\n", sessionId)
    end
end

local function listSessions()
    local sessionList = {}
    local count = 0
    for id, session in pairs(shellSessions) do
        count = count + 1
        local status = session.active and "active" or "inactive"
        local dirInfo = session.workingDir and (" @ " .. session.workingDir) or ""
        table.insert(sessionList, "Session #" .. id .. ": " .. status .. dirInfo)
    end
    
    if count == 0 then
        return "No active sessions"
    else
        return "Found " .. count .. " sessions:\n" .. table.concat(sessionList, "\n")
    end
end

-- Program execution
local function runProgram(programName, args)
    local programPath = PROGRAMS_DIR .. "/" .. programName
    
    if not fs.exists(programPath) and not fs.exists(programPath .. ".lua") then
        sendMessage("status", "Program not found: " .. programName, nil, false)
        return
    end
    
    print("Executing: " .. programName)
    sendMessage("status", "Starting: " .. programName, nil, true)
    
    _G.sendStatus = function(msg, success)
        sendMessage("status", msg, nil, success)
    end
    
    local success = shell.run(programPath, table.unpack(args or {}))
    _G.sendStatus = nil
    
    local result = success and "Completed: " or "Failed: "
    sendMessage("status", result .. programName, nil, success)
end

-- Startup checks
if not fs.exists(PROGRAMS_DIR) then
    fs.makeDir(PROGRAMS_DIR)
end

-- Main command loop
sendMessage("status", "Worker ready", nil, true)

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if type(message) == "table" and (not message.targetId or message.targetId == turtleID) then
        local command = message.command
        local args = message.args or {}
        
        if not command then
            print("Warning: Received message without command field")
            -- Skip processing if no command
        elseif command == "ping" then
            print("Command: " .. command)
            sendMessage("status", "Pong from turtle #" .. turtleID, nil, true)
            
        elseif command == "status" then
            print("Command: " .. command)
            local fuel = turtle.getFuelLevel()
            local x, y, z = gps.locate(5, false)
            local position = x and string.format("X:%d Y:%d Z:%d", x, y, z) or "Unknown"
            sendMessage("status", "Fuel: " .. tostring(fuel) .. " | Pos: " .. position, nil, true)
            
        elseif command == "reboot" then
            print("Command: " .. command)
            sendMessage("status", "Rebooting...", nil, true)
            os.sleep(0.5)
            os.reboot()
            
        elseif command == "getVersion" then
            print("Command: " .. command)
            sendMessage("status", "Version: " .. WORKER_VERSION, nil, true)
            
        elseif command == "createShell" then
            print("Command: " .. command)
            sessionCounter = sessionCounter + 1
            createSession(sessionCounter)
            
        elseif command == "shellInput" then
            print("Command: " .. command)
            local sessionId, input = tonumber(args[1]), args[2]
            if sessionId and input then
                executeShellCommand(sessionId, input)
            else
                sendMessage("status", "Invalid shell input", nil, false)
            end
            
        elseif command == "closeShell" then
            print("Command: " .. command)
            local sessionId = tonumber(args[1])
            if sessionId then
                closeSession(sessionId)
            end
            
        elseif command == "listSessions" then
            print("Command: " .. command)
            local sessionInfo = listSessions()
            sendMessage("status", sessionInfo, nil, true)
            
        elseif command == "switchTab" then
            print("Command: " .. command)
            local sessionId = tonumber(args[1])
            local session = shellSessions[sessionId]
            if session and session.active then
                sendMessage("info", "Switched to session #" .. sessionId .. " (remote only)", sessionId)
            else
                sendMessage("status", "Session not found or inactive", nil, false)
            end
            
        elseif command == "startShell" then
            print("Command: " .. command)
            sessionCounter = sessionCounter + 1
            createSession(sessionCounter)
            
        elseif command == "shell" then
            print("Command: " .. command)
            local cmdString = table.concat(args, " ")
            print("Shell: " .. cmdString)
            local success = shell.run(cmdString)
            sendMessage("status", "Shell command " .. (success and "succeeded" or "failed"), nil, success)
            
        elseif command == "deployProgram" then
            print("Command: " .. command)
            local programName = args[1]
            local totalChunks = tonumber(args[2])
            
            if not programName or not totalChunks then
                sendMessage("status", "Invalid deployment parameters", nil, false)
            else
                programDeployments[programName] = {
                    chunks = {},
                    totalChunks = totalChunks,
                    receivedChunks = 0
                }
                print("Receiving program: " .. programName .. " (" .. totalChunks .. " chunks)")
                sendMessage("status", "Ready to receive " .. programName, nil, true)
            end
            
        elseif command == "programChunk" then
            print("Command: " .. command)
            local programName = args[1]
            local chunkNum = tonumber(args[2])
            local totalChunks = tonumber(args[3])
            local chunkData = args[4]
            
            if not programDeployments[programName] then
                programDeployments[programName] = {
                    chunks = {},
                    totalChunks = totalChunks,
                    receivedChunks = 0
                }
            end
            
            local deployment = programDeployments[programName]
            deployment.chunks[chunkNum] = chunkData
            deployment.receivedChunks = deployment.receivedChunks + 1
            
            print("Chunk " .. chunkNum .. "/" .. totalChunks .. " received")
            
            -- Check if all chunks received
            if deployment.receivedChunks == deployment.totalChunks then
                print("All chunks received, assembling program...")
                
                -- Assemble chunks in order
                local fullContent = {}
                for i = 1, deployment.totalChunks do
                    if deployment.chunks[i] then
                        table.insert(fullContent, deployment.chunks[i])
                    else
                        sendMessage("status", "Missing chunk " .. i .. " for " .. programName, nil, false)
                        programDeployments[programName] = nil
                        return
                    end
                end
                
                local content = table.concat(fullContent)
                
                -- Write to programs directory
                local programPath = PROGRAMS_DIR .. "/" .. programName
                if not programPath:match("%.lua$") then
                    programPath = programPath .. ".lua"
                end
                
                local file = fs.open(programPath, "w")
                if file then
                    file.write(content)
                    file.close()
                    sendMessage("status", "Program deployed: " .. programName .. " (" .. #content .. " bytes)", nil, true)
                    print("Program saved: " .. programPath)
                else
                    sendMessage("status", "Failed to write " .. programName, nil, false)
                end
                
                -- Clean up deployment tracking
                programDeployments[programName] = nil
            end
            
        else
            print("Command: " .. command)
            runProgram(command, args)
        end
    end
end
