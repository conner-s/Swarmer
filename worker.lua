-- Production Worker v4.0
-- Turtle swarm worker - handles remote commands and program execution
-- Now with role-based functionality
-- Refactored to use common libraries for reduced duplication

local SwarmCommon = require("lib.swarm_common")
local SwarmWorker = require("lib.swarm_worker_lib")
local RoleManager = require("lib.roles")
local SwarmFile = require("lib.swarm_file")
local SwarmGPS = require("lib.swarm_gps")

-- Worker configuration
local WORKER_VERSION = "4.0"
local PROGRAMS_DIR = "programs"

-- Worker state
local turtleID = os.getComputerID()
local shellSessions = {}
local sessionCounter = 0
local programDeployments = {}
local currentRole = nil

-- Initialize modem
local modem, err = SwarmCommon.initModem()
if not modem then
    print("ERROR: " .. err)
    print("Install a wireless modem and restart")
    return
end

SwarmCommon.openChannels(modem, {SwarmCommon.COMMAND_CHANNEL})

-- Load role if assigned
currentRole, err = RoleManager.loadRole()
if currentRole then
    print("Worker Turtle #" .. turtleID .. " online v" .. WORKER_VERSION)
    print("Role: " .. currentRole.metadata.name .. " (" .. currentRole.roleId .. ")")
else
    print("Worker Turtle #" .. turtleID .. " online v" .. WORKER_VERSION)
    print("No role assigned (base worker)")
end
print("Listening on channel " .. SwarmCommon.COMMAND_CHANNEL)

-- Enhanced message sending with version and role info
local function sendMessage(messageType, content, sessionId, success)
    local roleInfo = RoleManager.getRoleInfo()
    
    local options = {
        version = WORKER_VERSION,
        sessionId = sessionId,
        success = success,
        role = roleInfo.assigned and roleInfo.roleId or nil,
        roleName = roleInfo.assigned and roleInfo.roleName or nil
    }
    
    local message = SwarmCommon.createMessage(messageType, content, options)
    return SwarmCommon.sendMessage(modem, message, SwarmCommon.REPLY_CHANNEL, SwarmCommon.COMMAND_CHANNEL)
end

-- Session management with enhanced tracking
local function createSession(sessionId)
    local session = {
        id = sessionId,
        active = true,
        workingDir = shell.dir(),
        created = os.epoch("utc")
    }
    
    shellSessions[sessionId] = session
    
    if multishell then
        sendMessage(SwarmCommon.MESSAGE_TYPES.INFO, "Shell session #" .. sessionId .. " created (remote only)", sessionId)
    else
        sendMessage(SwarmCommon.MESSAGE_TYPES.INFO, "Shell session #" .. sessionId .. " created (no multishell)", sessionId)
    end
    
    sendMessage(SwarmCommon.MESSAGE_TYPES.SHELL, "Remote shell #" .. sessionId .. " ready\n", sessionId)
    sendMessage(SwarmCommon.MESSAGE_TYPES.PROMPT, session.workingDir .. "> ", sessionId)
    
    return session
end

-- Enhanced command execution with better error handling
local function executeShellCommand(sessionId, input)
    local session = shellSessions[sessionId]
    if not session or not session.active then
        sendMessage(SwarmCommon.MESSAGE_TYPES.INFO, "Session #" .. sessionId .. " not available", sessionId)
        return
    end
    
    -- Store original directory
    local originalDir = shell.dir()
    shell.setDir(session.workingDir)
    
    sendMessage(SwarmCommon.MESSAGE_TYPES.INFO, "Executing: '" .. input .. "' in " .. session.workingDir, sessionId)
    
    -- Built-in command handlers
    local builtinCommands = {
        help = function()
            return "Available: ls, cd, mkdir, rm, cp, mv, edit, programs, etc.\n"
        end,
        
        pwd = function()
            return session.workingDir .. "\n"
        end,
        
        echo = function()
            local text = input:match("^echo%s+(.+)")
            return text and (text .. "\n") or "\n"
        end,
        
        ls = function()
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
            return table.concat(output, "  ") .. "\n"
        end,
        
        cd = function()
            local targetDir = input:match("^cd%s+(.+)") or ""
            if targetDir == "" then
                session.workingDir = ""
                return ""
            else
                local newDir = fs.combine(session.workingDir, targetDir)
                if fs.exists(newDir) and fs.isDir(newDir) then
                    session.workingDir = newDir
                    return ""
                else
                    return "cd: no such directory: " .. targetDir .. "\n"
                end
            end
        end
    }
    
    -- Check for built-in commands
    local command = input:match("^(%S+)")
    if builtinCommands[command] or command == "dir" and builtinCommands.ls then
        local handler = builtinCommands[command] or builtinCommands.ls
        local output = handler()
        if output and output ~= "" then
            sendMessage(SwarmCommon.MESSAGE_TYPES.SHELL, output, sessionId)
        end
        sendMessage(SwarmCommon.MESSAGE_TYPES.PROMPT, session.workingDir .. "> ", sessionId)
        return
    end
    
    -- Standard command execution with output capture
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
    
    local success, err = SwarmCommon.safeCall(function()
        shell.run(input)
    end)
    
    -- Restore session state
    session.workingDir = shell.dir()
    print = oldPrint
    write = oldWrite
    shell.setDir(originalDir)
    
    -- Send output
    local outputText = table.concat(output)
    if outputText and outputText ~= "" then
        sendMessage(SwarmCommon.MESSAGE_TYPES.SHELL, outputText, sessionId)
    elseif success then
        sendMessage(SwarmCommon.MESSAGE_TYPES.SHELL, "(command completed)\n", sessionId)
    end
    
    if not success then
        sendMessage(SwarmCommon.MESSAGE_TYPES.SHELL, "Error: " .. tostring(err) .. "\n", sessionId)
    end
    
    sendMessage(SwarmCommon.MESSAGE_TYPES.PROMPT, session.workingDir .. "> ", sessionId)
end

local function closeSession(sessionId)
    local session = shellSessions[sessionId]
    if session then
        session.active = false
        shellSessions[sessionId] = nil
        sendMessage(SwarmCommon.MESSAGE_TYPES.INFO, "Session #" .. sessionId .. " closed", sessionId)
        sendMessage(SwarmCommon.MESSAGE_TYPES.SHELL, "Session ended\n", sessionId)
    end
end

local function listSessions()
    local sessionList = {}
    local count = 0
    
    for id, session in pairs(shellSessions) do
        count = count + 1
        local status = session.active and "active" or "inactive"
        local dirInfo = session.workingDir and (" @ " .. session.workingDir) or ""
        local age = os.epoch("utc") - session.created
        table.insert(sessionList, string.format("Session #%d: %s%s (age: %.1fs)", 
                                              id, status, dirInfo, age / 1000))
    end
    
    if count == 0 then
        return "No active sessions"
    else
        return "Found " .. count .. " sessions:\n" .. table.concat(sessionList, "\n")
    end
end

-- Enhanced program execution using worker library
local function runProgram(programName, args)
    local programPath = PROGRAMS_DIR .. "/" .. programName
    
    if not fs.exists(programPath) and not fs.exists(programPath .. ".lua") then
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Program not found: " .. programName, nil, false)
        return
    end
    
    print("Executing: " .. programName)
    sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Starting: " .. programName, nil, true)
    
    -- Set up worker environment
    SwarmWorker.setStatusCallback(function(msg, success)
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, msg, nil, success)
    end)
    
    -- Set up global sendStatus for backward compatibility
    _G.sendStatus = function(msg, success)
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, msg, nil, success)
    end
    
    local success, err = SwarmCommon.safeCall(function()
        shell.run(programPath, table.unpack(args or {}))
    end)
    
    -- Cleanup
    _G.sendStatus = nil
    SwarmWorker.setStatusCallback(nil)
    
    local result = success and "Completed: " or "Failed: "
    local message = result .. programName
    if not success then
        message = message .. " (" .. tostring(err) .. ")"
    end
    
    sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, message, nil, success)
end

-- Enhanced program deployment with chunked transfer
local function handleProgramDeployment(programName, totalChunks)
    if not programName or not totalChunks then
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Invalid deployment parameters", nil, false)
        return false
    end
    
    programDeployments[programName] = {
        chunks = {},
        totalChunks = totalChunks,
        receivedChunks = 0,
        startTime = os.epoch("utc")
    }
    
    print("Receiving program: " .. programName .. " (" .. totalChunks .. " chunks)")
    sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Ready to receive " .. programName, nil, true)
    return true
end

local function handleProgramChunk(programName, chunkNum, totalChunks, chunkData)
    if not programDeployments[programName] then
        programDeployments[programName] = {
            chunks = {},
            totalChunks = totalChunks,
            receivedChunks = 0,
            startTime = os.epoch("utc")
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
        local chunks = {}
        for i = 1, deployment.totalChunks do
            if deployment.chunks[i] then
                table.insert(chunks, deployment.chunks[i])
            else
                sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                           "Missing chunk " .. i .. " for " .. programName, nil, false)
                programDeployments[programName] = nil
                return false
            end
        end
        
        local content = SwarmFile.assembleChunks(chunks)
        
        -- Write to programs directory
        SwarmFile.ensureDirectory(PROGRAMS_DIR)
        local programPath = PROGRAMS_DIR .. "/" .. programName
        if not programPath:match("%.lua$") then
            programPath = programPath .. ".lua"
        end
        
        local success, err = SwarmFile.writeFile(programPath, content)
        if success then
            local duration = (os.epoch("utc") - deployment.startTime) / 1000
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       string.format("Program deployed: %s (%d bytes, %.1fs)", 
                                   programName, #content, duration), nil, true)
            print("Program saved: " .. programPath)
        else
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "Failed to write " .. programName .. ": " .. err, nil, false)
        end
        
        -- Clean up deployment tracking
        programDeployments[programName] = nil
        return success
    end
    
    return true
end

-- Command handlers table for better organization
local commandHandlers = {
    ping = function(args, targetId)
        print("Command: ping")
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Pong from turtle #" .. turtleID, nil, true)
    end,
    
    status = function(args, targetId)
        print("Command: status")
        local fuel = turtle.getFuelLevel()
        local position = SwarmGPS.getCurrentPosition()
        local posStr = SwarmGPS.formatPosition(position)
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                   "Fuel: " .. tostring(fuel) .. " | Pos: " .. posStr, nil, true)
    end,
    
    reboot = function(args, targetId)
        print("Command: reboot")
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Rebooting...", nil, true)
        os.sleep(0.5)
        os.reboot()
    end,
    
    getVersion = function(args, targetId)
        print("Command: getVersion")
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Version: " .. WORKER_VERSION, nil, true)
    end,
    
    createShell = function(args, targetId)
        print("Command: createShell")
        sessionCounter = sessionCounter + 1
        createSession(sessionCounter)
    end,
    
    shellInput = function(args, targetId)
        print("Command: shellInput")
        local sessionId, input = tonumber(args[1]), args[2]
        if sessionId and input then
            executeShellCommand(sessionId, input)
        else
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Invalid shell input", nil, false)
        end
    end,
    
    closeShell = function(args, targetId)
        print("Command: closeShell")
        local sessionId = tonumber(args[1])
        if sessionId then
            closeSession(sessionId)
        end
    end,
    
    listSessions = function(args, targetId)
        print("Command: listSessions")
        local sessionInfo = listSessions()
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, sessionInfo, nil, true)
    end,
    
    switchTab = function(args, targetId)
        print("Command: switchTab")
        local sessionId = tonumber(args[1])
        local session = shellSessions[sessionId]
        if session and session.active then
            sendMessage(SwarmCommon.MESSAGE_TYPES.INFO, 
                       "Switched to session #" .. sessionId .. " (remote only)", sessionId)
        else
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Session not found or inactive", nil, false)
        end
    end,
    
    startShell = function(args, targetId)
        print("Command: startShell")
        sessionCounter = sessionCounter + 1
        createSession(sessionCounter)
    end,
    
    shell = function(args, targetId)
        print("Command: shell")
        local cmdString = table.concat(args, " ")
        print("Shell: " .. cmdString)
        local success = shell.run(cmdString)
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                   "Shell command " .. (success and "succeeded" or "failed"), nil, success)
    end,
    
    deployProgram = function(args, targetId)
        print("Command: deployProgram")
        local programName = args[1]
        local totalChunks = tonumber(args[2])
        handleProgramDeployment(programName, totalChunks)
    end,
    
    programChunk = function(args, targetId)
        print("Command: programChunk")
        local programName = args[1]
        local chunkNum = tonumber(args[2])
        local totalChunks = tonumber(args[3])
        local chunkData = args[4]
        handleProgramChunk(programName, chunkNum, totalChunks, chunkData)
    end,
    
    -- Role management commands
    assignRole = function(args, targetId)
        print("Command: assignRole")
        local roleId = args[1]
        local config = args[2] or {}
        
        local success, result = RoleManager.assignRole(roleId, config)
        if success then
            currentRole = result
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "Role assigned: " .. roleId .. " (" .. result.metadata.name .. ")", nil, true)
        else
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "Failed to assign role: " .. tostring(result), nil, false)
        end
    end,
    
    clearRole = function(args, targetId)
        print("Command: clearRole")
        RoleManager.clearRole()
        currentRole = nil
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Role cleared", nil, true)
    end,
    
    getRoleInfo = function(args, targetId)
        print("Command: getRoleInfo")
        local info = RoleManager.getRoleInfo()
        local message = info.assigned and 
                       string.format("Role: %s (%s)", info.roleName, info.roleId) or
                       "No role assigned"
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, message, nil, true)
    end,
    
    setRoleConfig = function(args, targetId)
        print("Command: setRoleConfig")
        local fieldName = args[1]
        local value = args[2]
        
        if not currentRole then
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "No role assigned", nil, false)
            return
        end
        
        local success, err = currentRole:setConfig(fieldName, value)
        if success then
            RoleManager.saveRole(currentRole)
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "Config updated: " .. fieldName, nil, true)
        else
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "Failed to update config: " .. tostring(err), nil, false)
        end
    end,
    
    getRoleConfig = function(args, targetId)
        print("Command: getRoleConfig")
        if not currentRole then
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "No role assigned", nil, false)
            return
        end
        
        local fieldName = args[1]
        if fieldName then
            local value = currentRole:getConfig(fieldName)
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       fieldName .. " = " .. textutils.serialize(value), nil, true)
        else
            local config = textutils.serialize(currentRole.config)
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "Role config: " .. config, nil, true)
        end
    end,
    
    listRoles = function(args, targetId)
        print("Command: listRoles")
        local roles = RoleManager.listRoles()
        local roleList = {}
        for _, role in ipairs(roles) do
            table.insert(roleList, role.id .. ": " .. role.name)
        end
        sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                   "Available roles:\n" .. table.concat(roleList, "\n"), nil, true)
    end,
    
    -- Role-specific command routing
    roleCommand = function(args, targetId)
        print("Command: roleCommand")
        if not currentRole then
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "No role assigned - cannot execute role commands", nil, false)
            return
        end
        
        local roleCmd = args[1]
        local roleArgs = {}
        for i = 2, #args do
            table.insert(roleArgs, args[i])
        end
        
        -- Check if role has a library with command handler
        local roleLib = currentRole:getLibrary()
        if roleLib and roleLib.handleCommand then
            local success, result = pcall(roleLib.handleCommand, currentRole, roleCmd, roleArgs)
            if success and result ~= false then
                sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                           "Role command completed: " .. roleCmd, nil, true)
            else
                local errMsg = result or "Command failed"
                sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                           "Role command failed: " .. tostring(errMsg), nil, false)
            end
        elseif currentRole:hasCommand(roleCmd) then
            -- Use command from role metadata
            local success, result = currentRole:executeCommand(roleCmd, roleArgs)
            if success then
                sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                           "Role command completed: " .. roleCmd, nil, true)
            else
                sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                           "Role command failed: " .. tostring(result), nil, false)
            end
        else
            sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                       "Unknown role command: " .. roleCmd, nil, false)
        end
    end
}

-- Initialize worker environment
SwarmFile.ensureDirectory(PROGRAMS_DIR)
sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, "Worker ready", nil, true)

-- Main command processing loop
while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    -- Check if message is for this turtle (by ID or role)
    local isTargeted = false
    
    if type(message) == "table" then
        -- Check direct ID targeting
        if not message.targetId or message.targetId == turtleID then
            isTargeted = true
        end
        
        -- Check role-based targeting
        if message.targetRole and currentRole and currentRole.roleId == message.targetRole then
            isTargeted = true
        end
    end
    
    if isTargeted then
        local command = message.command
        local args = message.args or {}
        
        if not command then
            print("Warning: Received message without command field")
        else
            local handler = commandHandlers[command]
            if handler then
                local success, err = SwarmCommon.safeCall(handler, args, message.targetId)
                if not success then
                    print("Error handling command '" .. command .. "': " .. tostring(err))
                    sendMessage(SwarmCommon.MESSAGE_TYPES.STATUS, 
                               "Command error: " .. tostring(err), nil, false)
                end
            else
                -- Treat as program execution
                print("Command: " .. command)
                runProgram(command, args)
            end
        end
    end
end