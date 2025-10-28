-- Single-File Turtle Deployment System v2.2
-- Self-contained: Includes worker code embedded
-- Usage: Copy this file to turtle and run it
-- Perfect for manual distribution via Pocket Computer

local WORKER_VERSION = "2.2"

print("=== Turtle Worker Installer v2.2 ===")
print("Self-contained deployment system")
print("")

-- Embedded worker code
local WORKER_CODE = [[-- Production Worker v2.2 - Embedded Edition
-- Simplified for deployment while maintaining reliability
-- Version: 2.2

local COMMAND_CHANNEL = 100
local REPLY_CHANNEL = 101
local PROGRAMS_DIR = "programs"
local WORKER_VERSION = "2.2"

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
        
        print("Command: " .. command)
        
        if command == "ping" then
            sendMessage("status", "Pong from turtle #" .. turtleID, nil, true)
            
        elseif command == "status" then
            local fuel = turtle.getFuelLevel()
            local x, y, z = gps.locate(5, false)
            local position = x and string.format("X:%d Y:%d Z:%d", x, y, z) or "Unknown"
            sendMessage("status", "Fuel: " .. tostring(fuel) .. " | Pos: " .. position, nil, true)
            
        elseif command == "reboot" then
            sendMessage("status", "Rebooting...", nil, true)
            os.sleep(0.5)
            os.reboot()
            
        elseif command == "getVersion" then
            sendMessage("status", "Version: " .. WORKER_VERSION, nil, true)
            
        elseif command == "createShell" then
            sessionCounter = sessionCounter + 1
            createSession(sessionCounter)
            
        elseif command == "shellInput" then
            local sessionId, input = tonumber(args[1]), args[2]
            if sessionId and input then
                executeShellCommand(sessionId, input)
            else
                sendMessage("status", "Invalid shell input", nil, false)
            end
            
        elseif command == "closeShell" then
            local sessionId = tonumber(args[1])
            if sessionId then
                closeSession(sessionId)
            end
            
        elseif command == "listSessions" then
            local sessionInfo = listSessions()
            sendMessage("status", sessionInfo, nil, true)
            
        elseif command == "switchTab" then
            local sessionId = tonumber(args[1])
            local session = shellSessions[sessionId]
            if session and session.active then
                sendMessage("info", "Switched to session #" .. sessionId .. " (remote only)", sessionId)
            else
                sendMessage("status", "Session not found or inactive", nil, false)
            end
            
        elseif command == "startShell" then
            sessionCounter = sessionCounter + 1
            createSession(sessionCounter)
            
        elseif command == "shell" then
            local cmdString = table.concat(args, " ")
            print("Shell: " .. cmdString)
            local success = shell.run(cmdString)
            sendMessage("status", "Shell command " .. (success and "succeeded" or "failed"), nil, success)
            
        elseif command == "deployProgram" then
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
            runProgram(command, args)
        end
    end
end
]]

-- Startup script template
local STARTUP_TEMPLATE = [[-- Auto-generated worker startup script
-- Version: %s
-- Generated: %s

local function safeStart()
    if not fs.exists("worker.lua") then
        print("ERROR: worker.lua not found!")
        print("Please re-run installer")
        return false
    end
    
    print("Starting Worker Turtle #" .. os.getComputerID() .. "...")
    print("Worker Version: %s")
    
    local modem = peripheral.find("modem")
    if not modem then
        print("WARNING: No modem found!")
        print("Install wireless modem and reboot")
        return false
    end
    
    local success, err = pcall(function()
        shell.run("worker.lua")
    end)
    
    if not success then
        print("ERROR: Worker crashed: " .. tostring(err))
        print("Restarting in 5 seconds...")
        os.sleep(5)
        os.reboot()
    end
    
    return true
end

-- Recovery mode check
if fs.exists(".recovery_mode") then
    print("=== RECOVERY MODE ===")
    print("Worker startup disabled")
    print("Delete .recovery_mode to re-enable")
    return
end

-- Startup delay
print("Worker starting in 3 seconds...")
print("Press Ctrl+T to abort")

local timer = os.startTimer(3)
while true do
    local event, param = os.pullEvent()
    if event == "timer" and param == timer then
        break
    elseif event == "terminate" then
        print("Startup aborted - recovery mode")
        local file = fs.open(".recovery_mode", "w")
        if file then
            file.write("Recovery mode: " .. os.date())
            file.close()
        end
        return
    end
end

safeStart()
]]

-- Utility functions
local function logStep(message, status)
    local symbol = status == "ok" and "[OK]" or status == "error" and "[ERROR]" or "[INFO]"
    print(symbol .. " " .. message)
end

local function backupFile(filename)
    if fs.exists(filename) then
        if not fs.exists("backups") then
            fs.makeDir("backups")
        end
        local timestamp = os.epoch("utc")
        local backupName = "backups/" .. filename .. "." .. timestamp
        fs.copy(filename, backupName)
        logStep("Backed up " .. filename, "ok")
        return backupName
    end
    return nil
end

local function writeFile(filename, content)
    local file = fs.open(filename, "w")
    if file then
        file.write(content)
        file.close()
        return true
    end
    return false
end

local function install()
    print("Installation process starting...")
    print("")
    
    -- Step 1: Backup existing files
    if fs.exists("startup.lua") then
        backupFile("startup.lua")
    end
    if fs.exists("worker.lua") then
        backupFile("worker.lua")
    end
    
    -- Step 2: Write worker code
    logStep("Installing worker.lua...", "info")
    if writeFile("worker.lua", WORKER_CODE) then
        logStep("Worker code installed", "ok")
    else
        logStep("Failed to write worker.lua", "error")
        return false
    end
    
    -- Step 3: Create startup script
    logStep("Creating startup.lua...", "info")
    local startupContent = string.format(STARTUP_TEMPLATE, 
        WORKER_VERSION, os.date(), WORKER_VERSION)
    
    if writeFile("startup.lua", startupContent) then
        logStep("Startup script created", "ok")
    else
        logStep("Failed to write startup.lua", "error")
        return false
    end
    
    -- Step 4: Create version file
    if writeFile(".worker_version", WORKER_VERSION) then
        logStep("Version tracking enabled", "ok")
    end
    
    -- Step 5: Setup directories
    if not fs.exists("programs") then
        fs.makeDir("programs")
        logStep("Created programs directory", "ok")
    end
    
    if not fs.exists("backups") then
        fs.makeDir("backups")
        logStep("Created backups directory", "ok")
    end
    
    -- Success!
    print("")
    print("=== Installation Complete! ===")
    print("Turtle ID: " .. os.getComputerID())
    print("Worker Version: " .. WORKER_VERSION)
    print("Auto-start: Enabled")
    print("")
    print("Files created:")
    print("  worker.lua     - Worker program")
    print("  startup.lua    - Auto-boot script")
    print("  programs/      - Custom programs")
    print("  backups/       - Backup files")
    print("")
    print("Recovery options:")
    print("  Create '.recovery_mode' to disable auto-start")
    print("  Restore from backups/ directory if needed")
    print("")
    
    return true
end

-- Main installer flow
print("This will install the worker system on this turtle.")
print("")
print("Actions:")
print("  • Backup existing startup.lua (if present)")
print("  • Install worker.lua")
print("  • Create auto-starting startup.lua")
print("  • Setup directory structure")
print("")
write("Proceed with installation? (y/n): ")
local confirm = read()

if confirm and (confirm == "y" or confirm == "Y" or confirm == "yes") then
    if install() then
        print("")
        write("Reboot turtle now to start worker? (y/n): ")
        local reboot = read()
        if reboot and (reboot == "y" or reboot == "Y") then
            print("Rebooting...")
            os.sleep(1)
            os.reboot()
        else
            print("Installation complete. Reboot when ready.")
        end
    else
        print("")
        print("Installation failed. Check errors above.")
    end
else
    print("Installation cancelled.")
end
