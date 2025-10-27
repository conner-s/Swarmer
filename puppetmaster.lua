-- Puppetmaster Control Program
-- Controls worker turtles wirelessly

local COMMAND_CHANNEL = 220
local REPLY_CHANNEL = 221

-- Initialize modem
local modem = peripheral.find("modem")
if not modem then
    print("ERROR: No modem found!")
    return
end

modem.open(REPLY_CHANNEL)
print("Puppetmaster Control System")
print("Listening on channel: " .. REPLY_CHANNEL)
print("")

-- Function to send command to workers
local function sendCommand(command, args, targetId)
    local message = {
        command = command,
        args = args or {},
        targetId = targetId,  -- nil = broadcast to all
        timestamp = os.epoch("utc")
    }

    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, message)

    if targetId then
        print("Sent '" .. command .. "' to turtle #" .. targetId)
    else
        print("Broadcast '" .. command .. "' to all turtles")
    end
end

-- Function to listen for replies
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

                local status = message.success and "✓" or "✗"
                print(status .. " Turtle #" .. message.id .. ": " .. message.message)
            end
        end
    end

    return replies
end

-- Display menu
local function showMenu()
    print("\n--- Commands ---")
    print("1. Ping all turtles")
    print("2. Check status")
    print("3. Run digDown")
    print("4. Custom command")
    print("5. Target specific turtle")
    print("6. Reboot workers")
    print("0. Exit")
    print("----------------")
    write("Select option: ")
end

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
        write("Reboot all workers? (y/n): ")
        if read() == "y" then
            sendCommand("reboot")
            listenForReplies(2)
        end
    end
end
