-- Swarm Common Library
-- Shared functionality for all swarm components
-- Version: 4.0

local SwarmCommon = {}

-- Communication constants
SwarmCommon.COMMAND_CHANNEL = 100
SwarmCommon.REPLY_CHANNEL = 101
SwarmCommon.VIEWER_CHANNEL = 102

-- Message types
SwarmCommon.MESSAGE_TYPES = {
    STATUS = "status",
    SHELL = "shell", 
    PROMPT = "prompt",
    INFO = "info"
}

-- Modem management
function SwarmCommon.initModem()
    local modem = peripheral.find("modem")
    if not modem then
        return nil, "No modem found"
    end
    
    modem.open(SwarmCommon.REPLY_CHANNEL)
    return modem, nil
end

function SwarmCommon.openChannels(modem, channels)
    if not modem then return false end
    
    for _, channel in ipairs(channels or {}) do
        modem.open(channel)
    end
    return true
end

-- Message creation and transmission
function SwarmCommon.createMessage(messageType, content, options)
    options = options or {}
    
    -- Core message metadata - always included
    local message = {
        id = os.getComputerID(),
        timestamp = os.epoch("utc"),
        version = options.version or "4.0",
        role = options.role,        -- Role ID (nil if not assigned)
        roleName = options.roleName -- Human-readable role name (nil if not assigned)
    }
    
    -- Message type-specific fields
    if messageType == SwarmCommon.MESSAGE_TYPES.STATUS then
        message.message = content
        message.success = options.success
    elseif messageType == SwarmCommon.MESSAGE_TYPES.SHELL then
        message.shellOutput = content
        message.sessionId = options.sessionId
    elseif messageType == SwarmCommon.MESSAGE_TYPES.PROMPT then
        message.shellPrompt = content
        message.sessionId = options.sessionId
    elseif messageType == SwarmCommon.MESSAGE_TYPES.INFO then
        message.sessionInfo = content
        message.sessionId = options.sessionId
    else
        -- Custom message type - merge all options
        for k, v in pairs(options) do
            if k ~= "version" and k ~= "role" and k ~= "roleName" then
                message[k] = v
            end
        end
    end
    
    return message
end

function SwarmCommon.sendMessage(modem, message, targetChannel, replyChannel)
    if not modem then return false end
    
    targetChannel = targetChannel or SwarmCommon.COMMAND_CHANNEL
    replyChannel = replyChannel or SwarmCommon.REPLY_CHANNEL
    
    modem.transmit(targetChannel, replyChannel, message)
    return true
end

function SwarmCommon.sendCommand(modem, command, args, targetId, options)
    options = options or {}
    
    local message = {
        command = command,
        args = args or {},
        targetId = targetId,
        timestamp = os.epoch("utc")
    }
    
    -- Add any additional options (e.g., targetRole for role-based filtering)
    for k, v in pairs(options) do
        message[k] = v
    end
    
    return SwarmCommon.sendMessage(modem, message, SwarmCommon.COMMAND_CHANNEL, SwarmCommon.REPLY_CHANNEL)
end

-- Role-aware command sending
function SwarmCommon.sendRoleCommand(modem, targetRole, command, args, options)
    options = options or {}
    options.targetRole = targetRole
    
    return SwarmCommon.sendCommand(modem, command, args, nil, options)
end

-- Reply collection utilities
function SwarmCommon.collectReplies(timeout, filter)
    timeout = timeout or 3
    filter = filter or function() return true end
    
    local timer = os.startTimer(timeout)
    local replies = {}
    
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id and filter(message) then
                table.insert(replies, message)
            end
        end
    end
    
    return replies
end

function SwarmCommon.discoverTurtles(modem, timeout)
    if not modem then return {} end
    
    SwarmCommon.sendCommand(modem, "ping")
    
    local replies = SwarmCommon.collectReplies(timeout or 3, function(message)
        return message.message and message.message:find("Pong")
    end)
    
    local turtles = {}
    for _, reply in ipairs(replies) do
        turtles[reply.id] = {
            id = reply.id,
            lastSeen = reply.timestamp,
            version = reply.version
        }
    end
    
    return turtles
end

-- Logging utilities
function SwarmCommon.formatTimestamp(epoch)
    epoch = epoch or os.epoch("utc")
    return os.date("%H:%M:%S", epoch / 1000)
end

function SwarmCommon.formatLogMessage(level, message, turtleId)
    local timestamp = SwarmCommon.formatTimestamp()
    local prefix = level and ("[" .. level .. "]") or ""
    local turtle = turtleId and (" Turtle #" .. turtleId) or ""
    
    return "[" .. timestamp .. "]" .. prefix .. turtle .. ": " .. message
end

-- File utilities
function SwarmCommon.ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
        return true
    end
    return fs.isDir(path)
end

function SwarmCommon.readFile(path)
    if not fs.exists(path) then
        return nil, "File not found: " .. path
    end
    
    local file = fs.open(path, "r")
    if not file then
        return nil, "Could not open file: " .. path
    end
    
    local content = file.readAll()
    file.close()
    return content
end

function SwarmCommon.writeFile(path, content)
    local file = fs.open(path, "w")
    if not file then
        return false, "Could not create file: " .. path
    end
    
    file.write(content)
    file.close()
    return true
end

-- Enhanced logging with status symbols
function SwarmCommon.logStep(message, status)
    local symbol = status == "ok" and "[OK]" or 
                  status == "error" and "[ERROR]" or 
                  status == "warn" and "[WARN]" or 
                  "[INFO]"
    print(symbol .. " " .. message)
end

-- File backup with timestamping
function SwarmCommon.backupFile(filename, backupDir)
    backupDir = backupDir or "backups"
    
    if not fs.exists(filename) then
        return nil, "File not found: " .. filename
    end
    
    if not SwarmCommon.ensureDirectory(backupDir) then
        return nil, "Could not create backup directory: " .. backupDir
    end
    
    local timestamp = os.epoch("utc")
    local backupName = fs.combine(backupDir, fs.getName(filename) .. "." .. timestamp)
    
    local success, err = pcall(fs.copy, filename, backupName)
    if success then
        SwarmCommon.logStep("Backed up " .. filename .. " to " .. backupName, "ok")
        return backupName
    else
        return nil, "Backup failed: " .. tostring(err)
    end
end

-- Generic file discovery utility
function SwarmCommon.findFiles(requiredFiles, searchPaths)
    searchPaths = searchPaths or {".", "disk", "disk0", "disk1"}
    
    local sourceFiles = {}
    local missing = {}
    
    for _, filename in ipairs(requiredFiles) do
        local found = false
        
        for _, searchPath in ipairs(searchPaths) do
            local fullPath = fs.combine(searchPath, filename)
            if fs.exists(fullPath) then
                sourceFiles[filename] = fullPath
                SwarmCommon.logStep("Found " .. filename .. " at " .. fullPath, "ok")
                found = true
                break
            end
        end
        
        if not found then
            table.insert(missing, filename)
        end
    end
    
    return sourceFiles, missing
end

-- Library installation utility
function SwarmCommon.installLibraries(sourceFiles, targetDir)
    targetDir = targetDir or "lib"
    
    SwarmCommon.logStep("Installing library files...", "info")
    
    -- Create target directory
    if not SwarmCommon.ensureDirectory(targetDir) then
        return false, "Could not create directory: " .. targetDir
    end
    
    -- Recursive function to copy directory contents
    local function copyDirectoryRecursive(sourcePath, targetPath)
        local items = fs.list(sourcePath)
        local copiedCount = 0
        
        for _, item in ipairs(items) do
            local sourceItem = fs.combine(sourcePath, item)
            local targetItem = fs.combine(targetPath, item)
            
            if fs.isDir(sourceItem) then
                -- Create subdirectory
                if not fs.exists(targetItem) then
                    fs.makeDir(targetItem)
                    SwarmCommon.logStep("Created directory: " .. targetItem, "ok")
                end
                -- Recursively copy subdirectory contents
                copiedCount = copiedCount + copyDirectoryRecursive(sourceItem, targetItem)
            elseif item:match("%.lua$") then
                -- Copy Lua file
                local content, err = SwarmCommon.readFile(sourceItem)
                if content then
                    local success, writeErr = SwarmCommon.writeFile(targetItem, content)
                    if success then
                        SwarmCommon.logStep("Installed " .. targetItem .. " (" .. #content .. " bytes)", "ok")
                        copiedCount = copiedCount + 1
                    else
                        SwarmCommon.logStep("Failed to write " .. targetItem .. ": " .. tostring(writeErr), "error")
                        return 0
                    end
                else
                    SwarmCommon.logStep("Failed to read " .. sourceItem .. ": " .. tostring(err), "error")
                    return 0
                end
            end
        end
        
        return copiedCount
    end
    
    -- Check if entire lib directory exists on disk and copy it over
    local diskLibPaths = {"disk/lib", "disk0/lib", "disk1/lib"}
    local foundDiskLib = false
    
    for _, diskLibPath in ipairs(diskLibPaths) do
        if fs.exists(diskLibPath) and fs.isDir(diskLibPath) then
            SwarmCommon.logStep("Found library directory at " .. diskLibPath, "ok")
            
            -- Copy entire lib directory recursively (including subdirectories)
            local copiedCount = copyDirectoryRecursive(diskLibPath, targetDir)
            
            if copiedCount > 0 then
                SwarmCommon.logStep("Library installation complete: " .. copiedCount .. " files", "ok")
                foundDiskLib = true
                break
            else
                SwarmCommon.logStep("Failed to copy files from " .. diskLibPath, "error")
                return false, "Copy failed"
            end
        end
    end
    
    -- Fallback to individual file installation if no disk lib directory found
    if not foundDiskLib then
        SwarmCommon.logStep("No disk lib directory found, installing individual files...", "info")
        
        local libraryFiles = {
            "lib/swarm_common.lua",
            "lib/swarm_ui.lua", 
            "lib/swarm_worker_lib.lua",
            "lib/roles.lua"
        }
        
        for _, libFile in ipairs(libraryFiles) do
            if sourceFiles[libFile] then
                local content, err = SwarmCommon.readFile(sourceFiles[libFile])
                if not content then
                    SwarmCommon.logStep("Failed to read " .. libFile .. ": " .. tostring(err), "error")
                    return false, "Read failed: " .. libFile
                end
                
                local targetPath = fs.combine(targetDir, fs.getName(libFile))
                local success, writeErr = SwarmCommon.writeFile(targetPath, content)
                if not success then
                    SwarmCommon.logStep("Failed to write " .. targetPath .. ": " .. tostring(writeErr), "error")
                    return false, "Write failed: " .. targetPath
                end
                
                SwarmCommon.logStep("Installed " .. targetPath .. " (" .. #content .. " bytes)", "ok")
            end
        end
    end
    
    return true
end

-- Chunked file transfer utilities
SwarmCommon.CHUNK_SIZE = 6000

function SwarmCommon.splitIntoChunks(content, chunkSize)
    chunkSize = chunkSize or SwarmCommon.CHUNK_SIZE
    local chunks = {}
    local pos = 1
    
    while pos <= #content do
        local chunk = content:sub(pos, pos + chunkSize - 1)
        table.insert(chunks, chunk)
        pos = pos + chunkSize
    end
    
    return chunks
end

function SwarmCommon.assembleChunks(chunks)
    return table.concat(chunks)
end

-- GPS utilities
function SwarmCommon.getCurrentPosition(timeout)
    local x, y, z = gps.locate(timeout or 5, false)
    if x then
        return {x = x, y = y, z = z}
    end
    return nil
end

function SwarmCommon.formatPosition(position)
    if not position or not position.x then
        return "Unknown"
    end
    return string.format("X:%d Y:%d Z:%d", position.x, position.y, position.z)
end

-- Validation utilities
function SwarmCommon.validateArgs(args, required)
    for i, argName in ipairs(required) do
        if not args[i] then
            return false, "Missing required argument: " .. argName
        end
    end
    return true
end

function SwarmCommon.validateNumber(value, min, max)
    local num = tonumber(value)
    if not num then
        return false, "Not a number: " .. tostring(value)
    end
    if min and num < min then
        return false, "Value too small (min: " .. min .. "): " .. num
    end
    if max and num > max then
        return false, "Value too large (max: " .. max .. "): " .. num
    end
    return true, num
end

-- Session management utilities
function SwarmCommon.generateSessionId()
    return os.epoch("utc") % 100000
end

-- JSON utilities (simple serialization for config files)
function SwarmCommon.serializeJSON(value, indent)
    indent = indent or 0
    local indentStr = string.rep("  ", indent)
    
    if type(value) == "table" then
        local items = {}
        local isArray = true
        local count = 0
        
        -- Check if it's an array
        for k, v in pairs(value) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                isArray = false
                break
            end
        end
        
        if isArray then
            -- Array format
            local parts = {}
            for i, v in ipairs(value) do
                table.insert(parts, indentStr .. "  " .. SwarmCommon.serializeJSON(v, indent + 1))
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indentStr .. "]"
        else
            -- Object format
            local parts = {}
            for k, v in pairs(value) do
                local key = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
                table.insert(parts, indentStr .. "  " .. key .. ": " .. SwarmCommon.serializeJSON(v, indent + 1))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indentStr .. "}"
        end
    elseif type(value) == "string" then
        return '"' .. value:gsub('"', '\\"') .. '"'
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    elseif value == nil then
        return "null"
    else
        return '""'
    end
end

function SwarmCommon.writeJSON(path, data)
    local json = SwarmCommon.serializeJSON(data)
    return SwarmCommon.writeFile(path, json)
end

function SwarmCommon.readJSON(path)
    local content, err = SwarmCommon.readFile(path)
    if not content then
        return nil, err
    end
    
    -- Use textutils.unserialiseJSON if available (CC:Tweaked 1.96+)
    if textutils.unserialiseJSON then
        local success, data = pcall(textutils.unserialiseJSON, content)
        if success then
            return data
        end
    end
    
    -- Fallback to textutils.unserialize for simple cases
    local success, data = pcall(textutils.unserialize, content)
    if success then
        return data
    end
    
    return nil, "Failed to parse JSON"
end

-- Error handling utilities
function SwarmCommon.safeCall(func, ...)
    local success, result = pcall(func, ...)
    if success then
        return result
    else
        return nil, result
    end
end

function SwarmCommon.retry(func, attempts, delay, ...)
    attempts = attempts or 3
    delay = delay or 1
    
    for i = 1, attempts do
        local result, err = SwarmCommon.safeCall(func, ...)
        if result then
            return result
        end
        
        if i < attempts then
            os.sleep(delay)
        else
            return nil, err
        end
    end
end

return SwarmCommon