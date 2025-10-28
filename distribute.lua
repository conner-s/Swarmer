-- Worker Distribution Tool v3.0
-- Deploy workers from your Pocket Computer
-- Refactored to use common libraries

local SwarmCommon = require("lib.swarm_common")
local SwarmUI = require("lib.swarm_ui")

print("=== Worker Distribution Tool v3.0 ===")
print("Deploy workers from your Pocket Computer")
print("")

-- Initialize components
local modem, err = SwarmCommon.initModem()
if not modem then
    print("ERROR: " .. err)
    print("This tool requires a wireless modem")
    return
end

SwarmCommon.openChannels(modem, {SwarmCommon.REPLY_CHANNEL})
SwarmUI.showStatus("Wireless modem ready", "success")

-- Check for installer
if not fs.exists("install.lua") then
    SwarmUI.showStatus("install.lua not found!", "error")
    print("Please ensure install.lua is on this computer")
    return
end

local installerCode, err = SwarmCommon.readFile("install.lua")
if not installerCode then
    SwarmUI.showStatus(err, "error")
    return
end

SwarmUI.showStatus("Installer loaded (" .. #installerCode .. " bytes)", "success")

-- Distribution functions
local function discoverTurtles()
    print("\nDiscovering turtles...")
    local turtles = SwarmCommon.discoverTurtles(modem, 3)
    
    local count = 0
    for id, turtle in pairs(turtles) do
        count = count + 1
        print("  Found: Turtle #" .. id .. " (v" .. (turtle.version or "unknown") .. ")")
    end
    
    SwarmUI.showStatus("Discovery complete: " .. count .. " turtles found", "success")
    return turtles
end

local function checkStatus()
    print("\nChecking worker status...")
    
    SwarmCommon.sendCommand(modem, "getVersion")
    
    local replies = SwarmCommon.collectReplies(3)
    local hasWorkers = false
    
    for _, reply in ipairs(replies) do
        if reply.message then
            hasWorkers = true
            print("  Turtle #" .. reply.id .. ": " .. reply.message)
        end
    end
    
    if not hasWorkers then
        SwarmUI.showStatus("No workers responded (may need installation)", "warning")
    else
        SwarmUI.showStatus("Found " .. #replies .. " active workers", "success")
    end
end

local function deployToTurtle()
    local targetId = SwarmUI.promptNumber("Enter turtle ID to deploy to: ", 1)
    
    print("")
    SwarmUI.showStatus("NOTE: Direct file transfer via modem is not supported by CC:Tweaked", "warning")
    print("Available methods:")
    print("1. Copy install.lua to a disk, transfer to turtle")
    print("2. Use pastebin if HTTP is enabled")
    print("3. Trigger remote installation (requires install.lua already on turtle)")
    print("")
    
    local choice = SwarmUI.promptChoice("Choose method", {"disk", "pastebin", "remote", "cancel"})
    
    if choice == "cancel" then
        return
    elseif choice == "remote" then
        if SwarmUI.confirm("Trigger remote install on turtle #" .. targetId .. "?") then
            print("Sending install command...")
            SwarmCommon.sendCommand(modem, "shell", {"install.lua"}, targetId)
            SwarmUI.showStatus("Command sent. Check turtle #" .. targetId .. " for results.", "info")
        end
    elseif choice == "disk" then
        showDiskInstructions()
    elseif choice == "pastebin" then
        showPastebinInstructions()
    end
end

function showDiskInstructions()
    print("\n=== Disk Transfer Method ===")
    print("1. Craft a floppy disk")
    print("2. Insert disk into this computer")
    print("3. Run: cp install.lua disk/install.lua")
    print("4. Take disk to target turtle")
    print("5. Insert disk into turtle")
    print("6. On turtle: cp disk/install.lua install.lua")
    print("7. On turtle: install.lua")
    print("8. Follow installation prompts")
    print("")
    SwarmUI.showStatus("Recommended method for reliability", "info")
end

function showPastebinInstructions()
    print("\n=== Pastebin Method ===")
    print("Prerequisites: HTTP API must be enabled")
    print("")
    print("1. Upload installer: pastebin put install.lua")
    print("2. Note the returned code (e.g., 'a1b2c3d4')")
    print("3. On each turtle: pastebin get <code> install.lua")
    print("4. On turtle: install.lua")
    print("")
    SwarmUI.showStatus("Requires HTTP API enabled in server config", "warning")
end

local function showManualInstructions()
    print("\n=== Complete Manual Transfer Guide ===")
    print("")
    print("Option 1: Copy via in-game disk (RECOMMENDED)")
    showDiskInstructions()
    
    print("\nOption 2: Use pastebin (if HTTP enabled)")
    showPastebinInstructions()
    
    print("\nOption 3: Type manually (not recommended)")
    print("  1. On turtle: edit install.lua")
    print("  2. Copy-paste the installer content")
    print("  3. Save (Ctrl+S) and exit (Ctrl+E)")
    print("  4. Run: install.lua")
    print("")
    
    print("Recovery Mode:")
    print("  - Create .recovery_mode file to disable auto-start")
    print("  - Delete .recovery_mode and reboot to re-enable")
    print("")
end

local function createQuickGuide()
    print("Creating deployment guide...")
    
    local guide = {
        "Quick Deployment Guide v3.0",
        "=================================",
        "",
        "Step-by-Step Deployment:",
        "",
        "1. Prepare Disk",
        "   - Craft a floppy disk",
        "   - Insert into your Pocket Computer",
        "   - Run: cp install.lua disk/install.lua",
        "",
        "2. Transfer to First Turtle",
        "   - Take disk to turtle",
        "   - Insert disk into turtle", 
        "   - Run: cp disk/install.lua install.lua",
        "   - Run: install.lua",
        "   - Follow prompts (y to install, y to reboot)",
        "",
        "3. Verify Installation",
        "   - Turtle should reboot automatically",
        "   - You should see \"Worker Turtle #X online v3.0\"",
        "   - From control computer: run puppetmaster.lua",
        "   - Choose \"1. Ping all turtles\"",
        "   - Should see response from turtle",
        "",
        "4. Deploy to Additional Turtles",
        "   - Repeat step 2 for each turtle",
        "   - Or copy install.lua to each turtle",
        "",
        "5. Fleet Management",
        "   - Use puppetmaster.lua for control",
        "   - Use fleet_manager.lua for bulk operations",
        "   - Use monitor.lua for real-time tracking",
        "",
        "Libraries (must be available in lib/):",
        "   - lib/swarm_common.lua",
        "   - lib/swarm_ui.lua", 
        "   - lib/swarm_worker_lib.lua",
        "",
        "Recovery:",
        "   - Create .recovery_mode file to disable auto-start",
        "   - Delete .recovery_mode and reboot to re-enable",
        "   - Backups stored in backups/ directory",
        "",
        "Version: 3.0",
        "Generated: " .. os.date()
    }
    
    local success, err = SwarmCommon.writeFile("DEPLOYMENT_GUIDE.txt", table.concat(guide, "\n"))
    if success then
        SwarmUI.showStatus("Created: DEPLOYMENT_GUIDE.txt", "success")
        print("You can copy this to disk for reference")
    else
        SwarmUI.showStatus("Could not create guide file: " .. err, "error")
    end
end

local function broadcastAnnouncement()
    if not SwarmUI.confirm("Broadcast version announcement to all turtles?") then
        return
    end
    
    print("Broadcasting version announcement...")
    SwarmCommon.sendCommand(modem, "shell", {"echo", "Distribution Tool v3.0 online"})
    
    local replies = SwarmCommon.collectReplies(3)
    SwarmUI.showStatus("Announcement sent to " .. #replies .. " turtles", "success")
end

-- Create main menu
local function createMainMenu()
    local menu = SwarmUI.Menu.new("Worker Distribution v3.0")
    
    menu:addOption("1", "Discover turtles", discoverTurtles)
    menu:addOption("2", "Deploy to specific turtle", deployToTurtle)
    menu:addOption("3", "Check installation status", checkStatus)
    menu:addOption("4", "Manual transfer instructions", showManualInstructions)
    menu:addOption("5", "Create deployment guide", createQuickGuide)
    menu:addOption("6", "Broadcast announcement", broadcastAnnouncement)
    menu:addOption("0", "Exit", function() return false end)
    
    return menu
end

-- Initialize
SwarmUI.showStatus("Installer ready for distribution", "success")
createQuickGuide()

-- Run main menu
local mainMenu = createMainMenu()
mainMenu:run()

print("Exiting distribution tool...")