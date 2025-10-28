-- Pocket Computer Installer Distribution Tool
-- Pushes install.lua to turtles and triggers installation
-- Usage: Run this on your Pocket Computer to deploy workers

local COMMAND_CHANNEL = 100
local REPLY_CHANNEL = 101

print("=== Worker Distribution Tool ===")
print("Deploy workers from your Pocket Computer")
print("")

-- Check for modem
local modem = peripheral.find("modem")
if not modem then
    print("ERROR: No modem found!")
    print("This tool requires a wireless modem")
    return
end

modem.open(REPLY_CHANNEL)
print("Wireless modem ready")

-- Check for installer
if not fs.exists("install.lua") then
    print("ERROR: install.lua not found!")
    print("Please ensure install.lua is on this computer")
    return
end

-- Read the installer
local file = fs.open("install.lua", "r")
local installerCode = file and file.readAll()
if file then file.close() end

if not installerCode then
    print("ERROR: Could not read install.lua")
    return
end

print("Installer loaded (" .. #installerCode .. " bytes)")
print("")

-- Distribution methods
local function showMenu()
    print("\n=== Distribution Options ===")
    print("1. Discover turtles")
    print("2. Push to specific turtle")
    print("3. Broadcast to all turtles")
    print("4. Check installation status")
    print("5. Manual transfer instructions")
    print("0. Exit")
    print("===========================")
    write("Choice: ")
end

local function discoverTurtles()
    print("Discovering turtles...")
    local turtles = {}
    
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = "ping",
        timestamp = os.epoch("utc")
    })
    
    local timer = os.startTimer(3)
    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id then
                if not turtles[message.id] then
                    turtles[message.id] = true
                    print("  Found: Turtle #" .. message.id)
                end
            end
        end
    end
    
    local count = 0
    for _ in pairs(turtles) do count = count + 1 end
    
    print("Discovery complete: " .. count .. " turtles found")
    return turtles
end

local function checkStatus()
    print("Checking worker status...")
    
    modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
        command = "getVersion",
        timestamp = os.epoch("utc")
    })
    
    local timer = os.startTimer(3)
    local hasWorkers = false
    
    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            break
        elseif event == "modem_message" then
            local message = p4
            if type(message) == "table" and message.id and message.message then
                hasWorkers = true
                print("  Turtle #" .. message.id .. ": " .. message.message)
            end
        end
    end
    
    if not hasWorkers then
        print("No workers responded (may need installation)")
    end
end

local function showManualInstructions()
    print("\n=== Manual Transfer Instructions ===")
    print("")
    print("Since CC:Tweaked doesn't support file transfer via")
    print("wireless modem, here are your options:")
    print("")
    print("Option 1: Copy via in-game disk")
    print("  1. Craft a floppy disk")
    print("  2. Insert disk in this computer")
    print("  3. Run: cp install.lua disk/install.lua")
    print("  4. Take disk to turtle")
    print("  5. On turtle: cp disk/install.lua install.lua")
    print("  6. On turtle: install.lua")
    print("")
    print("Option 2: Use pastebin (if HTTP enabled)")
    print("  1. pastebin put install.lua")
    print("  2. Note the code (e.g., 'a1b2c3d4')")
    print("  3. On each turtle: pastebin get <code> install.lua")
    print("  4. On turtle: install.lua")
    print("")
    print("Option 3: Type manually (not recommended for large files)")
    print("  1. On turtle: edit install.lua")
    print("  2. Copy-paste the content")
    print("  3. Save and run")
    print("")
    print("Recommended: Option 1 (disk) for reliability")
end

local function deployToTurtle()
    write("Enter turtle ID to deploy to: ")
    local targetId = tonumber(read())
    
    if not targetId then
        print("Invalid turtle ID")
        return
    end
    
    print("")
    print("NOTE: Direct file transfer via modem is not supported")
    print("by CC:Tweaked. You'll need to use one of these methods:")
    print("")
    print("1. Copy install.lua to a disk, transfer to turtle")
    print("2. Use pastebin if HTTP is enabled")
    print("3. Use the installer remotely (see option below)")
    print("")
    print("Would you like to trigger remote installation?")
    print("(Requires install.lua to already be on turtle #" .. targetId .. ")")
    write("Trigger remote install? (y/n): ")
    local confirm = read()
    
    if confirm and (confirm == "y" or confirm == "Y") then
        print("Sending install command to turtle #" .. targetId .. "...")
        
        modem.transmit(COMMAND_CHANNEL, REPLY_CHANNEL, {
            command = "shell",
            args = {"install.lua"},
            targetId = targetId,
            timestamp = os.epoch("utc")
        })
        
        print("Command sent. Check turtle #" .. targetId .. " for results.")
    end
end

local function createQuickGuide()
    print("Creating quick deployment guide...")
    
    local guide = [[Quick Deployment Guide
=====================

Step-by-Step Deployment:

1. Prepare Disk
   - Craft a floppy disk
   - Insert into your Pocket Computer
   - Run: cp install.lua disk/install.lua
   
2. Transfer to First Turtle
   - Take disk to turtle
   - Insert disk into turtle
   - Run: cp disk/install.lua install.lua
   - Run: install.lua
   - Follow prompts (y to install, y to reboot)
   
3. Verify Installation
   - Turtle should reboot automatically
   - You should see "Worker Turtle #X online"
   - From control computer: run puppetmaster_simple.lua
   - Choose "2. Ping all turtles"
   - Should see response from turtle
   
4. Deploy to Additional Turtles
   - Repeat step 2 for each turtle
   - Or copy install.lua to each turtle's startup
   
5. Fleet Management
   - Use puppetmaster_simple.lua for control
   - Use fleet_manager.lua for bulk operations
   
Recovery:
- Create .recovery_mode file to disable auto-start
- Delete .recovery_mode and reboot to re-enable
- Backups stored in backups/ directory

Version: 2.2
]]
    
    local file = fs.open("DEPLOYMENT_GUIDE.txt", "w")
    if file then
        file.write(guide)
        file.close()
        print("Created: DEPLOYMENT_GUIDE.txt")
        print("You can copy this to disk for reference")
    else
        print("Could not create guide file")
    end
end

-- Main program loop
print("Installer ready for distribution")
createQuickGuide()

while true do
    showMenu()
    local choice = read()
    
    if choice == "0" then
        print("Exiting distribution tool...")
        break
    elseif choice == "1" then
        discoverTurtles()
    elseif choice == "2" then
        deployToTurtle()
    elseif choice == "3" then
        print("\nBroadcast deployment not supported")
        print("Use manual transfer methods instead")
        showManualInstructions()
    elseif choice == "4" then
        checkStatus()
    elseif choice == "5" then
        showManualInstructions()
    else
        print("Invalid choice")
    end
end
