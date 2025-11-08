-- Swarm Common Library
-- Core communication functionality for all swarm components
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