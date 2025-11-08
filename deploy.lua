-- Unified Deployment Entry Point v4.0
-- Routes to appropriate deployment method based on context
-- Version: 4.0

local SwarmCommon = require("lib.swarm_common")
local SwarmUI = require("lib.swarm_ui")

print("=== Swarmer Deployment System v4.0 ===")
print("Unified entry point for turtle deployment")
print("")

-- Check for wireless modem
local modem, err = SwarmCommon.initModem()
local hasModem = modem ~= nil

if not hasModem then
    print("WARNING: No wireless modem found")
    print("Wireless provisioning will not be available")
    print("")
end

-- Main menu
local function createMainMenu()
    local menu = SwarmUI.Menu.new("Deployment System v4.0")
    
    if hasModem then
        menu:addOption("1", "Wireless Provisioning (Recommended)", function()
            print("")
            print("Starting provision server...")
            print("")
            shell.run("provision_server.lua")
        end)
    end
    
    menu:addOption(hasModem and "2" or "1", "Manual Disk Transfer Guide", function()
        print("\n=== Manual Disk Transfer ===")
        print("1. Craft a floppy disk")
        print("2. Insert disk into this computer")
        print("3. Run: cp install.lua disk/install.lua")
        print("4. Copy lib/ directory to disk: cp -r lib disk/lib")
        print("5. Take disk to target turtle")
        print("6. Insert disk into turtle")
        print("7. On turtle: cp disk/install.lua install.lua")
        print("8. On turtle: cp -r disk/lib lib")
        print("9. On turtle: install.lua")
        print("10. Follow installation prompts")
        print("")
        print("Press Enter to continue...")
        read()
    end)
    
    menu:addOption(hasModem and "3" or "2", "Pastebin Method Guide", function()
        print("\n=== Pastebin Method ===")
        print("Prerequisites: HTTP API must be enabled")
        print("")
        print("1. Upload installer: pastebin put install.lua")
        print("2. Note the returned code (e.g., 'a1b2c3d4')")
        print("3. On each turtle: pastebin get <code> install.lua")
        print("4. On turtle: install.lua")
        print("")
        print("Note: Libraries must still be transferred via disk")
        print("")
        print("Press Enter to continue...")
        read()
    end)
    
    menu:addOption(hasModem and "4" or "3", "Check Installation Status", function()
        if not hasModem then
            SwarmUI.showStatus("Wireless modem required for status check", "error")
            print("Press Enter to continue...")
            read()
            return
        end
        
        SwarmCommon.openChannels(modem, {SwarmCommon.REPLY_CHANNEL})
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
        
        print("\nPress Enter to continue...")
        read()
    end)
    
    menu:addOption(hasModem and "5" or "4", "About Deployment Methods", function()
        print("\n=== Deployment Methods ===")
        print("")
        print("1. Wireless Provisioning (RECOMMENDED)")
        print("   - No disk space limits")
        print("   - Fast and reliable")
        print("   - Can send complete packages")
        print("   - Requires: Wireless modem on both computers")
        print("")
        print("2. Manual Disk Transfer")
        print("   - Works without wireless modem")
        print("   - Reliable but slower")
        print("   - Limited by disk size (512KB)")
        print("   - Requires: Floppy disk")
        print("")
        print("3. Pastebin Method")
        print("   - Good for initial installer")
        print("   - Requires HTTP API enabled")
        print("   - Libraries still need disk transfer")
        print("")
        print("Press Enter to continue...")
        read()
    end)
    
    menu:addOption(hasModem and "0" or "0", "Exit", function() return false end)
    
    return menu
end

-- Run main menu
local mainMenu = createMainMenu()
mainMenu:run()

print("Exiting deployment system...")

