-- Place this as the startup.lua on the turtles
-- Worker Turtle Startup Program
-- Automatically runs on boot and listens for commands from puppetmaster

local COMMAND_CHANNEL = 220
local REPLY_CHANNEL = 221
local PROGRAMS_DIR = "programs"

-- Get turtle's unique ID
local turtleID = os.getComputerID()

-- Initialize modem
local modem = peripheral.find("modem")
if not modem then
    print("ERROR: No modem found!")
    return
end

-- Open channels
modem.open(COMMAND_CHANNEL)
modem.open(REPLY_CHANNEL)

print("Worker Turtle #" .. turtleID .. " online")
print("Listening on channel " .. COMMAND_CHANNEL)
print("Programs directory: " .. PROGRAMS_DIR)

-- Function to send status back to puppetmaster
local function sendStatus(message, success)
    modem.transmit(REPLY_CHANNEL, COMMAND_CHANNEL, {
        id = turtleID,
        message = message,
        success = success,
        timestamp = os.epoch("utc")
    })
end

-- Function to execute a program
local function executeProgram(programName, args)
    local programPath = PROGRAMS_DIR .. "/" .. programName .. ".lua"

    -- Check if program exists
    if not fs.exists(programPath) then
        sendStatus("Program not found: " .. programName, false)
        return
    end

    print("Executing: " .. programName)
    sendStatus("Starting: " .. programName, true)

    -- Load and run the program
    local func, err = loadfile(programPath)
    if not func then
        sendStatus("Load error: " .. err, false)
        return
    end

    -- Set up environment with args
    local env = setmetatable({
        args = args or {},
        sendStatus = sendStatus  -- Allow programs to report back
    }, {__index = _G})

    setfenv(func, env)

    -- Execute with error handling
    local success, result = pcall(func)
    if success then
        sendStatus("Completed: " .. programName, true)
    else
        sendStatus("Error: " .. result, false)
    end
end

-- Main command listening loop
sendStatus("Worker ready", true)

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    if type(message) == "table" then
        -- Check if command is for this turtle or broadcast to all
        if not message.targetId or message.targetId == turtleID then
            local command = message.command
            local args = message.args or {}

            print("Received command: " .. command)

            -- Special commands
            if command == "ping" then
                sendStatus("Pong from turtle #" .. turtleID, true)
            elseif command == "status" then
                local fuel = turtle.getFuelLevel()
                sendStatus("Fuel: " .. tostring(fuel), true)
            elseif command == "reboot" then
                sendStatus("Rebooting...", true)
                os.sleep(0.5)
                os.reboot()
            else
                -- Execute program from programs directory
                executeProgram(command, args)
            end
        end
    end
end
