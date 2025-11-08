-- Provision Server v4.0
-- Unified deployment system - wireless provisioning and manual deployment methods
-- Merged functionality from distribute.lua

local SwarmCommon = require("lib.swarm_common")
local SwarmUI = require("lib.swarm_ui")
local SwarmFile = require("lib.swarm_file")

print("=== Provision Server v4.0 ===")
print("Unified deployment system for turtle management")
print("Wireless provisioning and manual deployment methods")
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

-- File sets to provision
local FILE_SETS = {
    worker = {
        "worker.lua",
        "install.lua",
        "lib/swarm_common.lua",
        "lib/swarm_worker_lib.lua",
        "lib/swarm_ui.lua",
        "lib/roles.lua",
        "lib/roles/miner.lua",
        "lib/roles/courier.lua",
        "lib/roles/builder.lua",
        "programs/digDown.lua",
        "programs/stairs.lua",
        "programs/hello.lua"
    },
    minimal = {
        "worker.lua",
        "install.lua",
        "lib/swarm_common.lua",
        "lib/swarm_worker_lib.lua",
        "lib/swarm_ui.lua",
        "lib/roles.lua"
    },
    libraries_only = {
        "lib/swarm_common.lua",
        "lib/swarm_worker_lib.lua",
        "lib/swarm_ui.lua",
        "lib/roles.lua",
        "lib/roles/miner.lua",
        "lib/roles/courier.lua",
        "lib/roles/builder.lua"
    }
}

local CHUNK_SIZE = 4096  -- Smaller chunks for reliability

-- Helper functions
local function discoverClients()
    print("\nDiscovering provision clients...")
    
    SwarmCommon.sendCommand(modem, "ping")
    
    local clients = {}
    local endTime = os.epoch("utc") + 3000
    
    while os.epoch("utc") < endTime do
        local event, side, channel, replyChannel, message = os.pullEvent()
        
        if event == "modem_message" and channel == SwarmCommon.REPLY_CHANNEL then
            if type(message) == "table" and message.type == "pong" then
                clients[message.id] = {
                    id = message.id,
                    message = message.message,
                    timestamp = message.timestamp
                }
                print("  Found: Computer #" .. message.id .. " - " .. message.message)
            end
        end
    end
    
    local count = 0
    for _ in pairs(clients) do count = count + 1 end
    
    SwarmUI.showStatus("Discovery complete: " .. count .. " clients found", count > 0 and "success" or "warning")
    return clients
end

local function sendFile(targetId, filePath)
    -- Read file
    local content, err = SwarmFile.readFile(filePath)
    if not content then
        SwarmUI.showStatus("Failed to read " .. filePath .. ": " .. err, "error")
        return false
    end
    
    local fileSize = #content
    local totalChunks = math.ceil(fileSize / CHUNK_SIZE)
    
    print("  Sending: " .. filePath .. " (" .. fileSize .. " bytes, " .. totalChunks .. " chunks)")
    
    -- Send start signal
    modem.transmit(SwarmCommon.COMMAND_CHANNEL, SwarmCommon.REPLY_CHANNEL, {
        command = "startFile",
        targetId = targetId,
        fileName = filePath,
        fileSize = fileSize,
        totalChunks = totalChunks,
        timestamp = os.epoch("utc")
    })
    
    -- Wait for ready confirmation
    local fileStarted = false
    local startWaitEnd = os.epoch("utc") + 2000
    while os.epoch("utc") < startWaitEnd and not fileStarted do
        local event, side, channel, replyChannel, message = os.pullEvent()
        if event == "modem_message" and channel == SwarmCommon.REPLY_CHANNEL then
            if type(message) == "table" and message.id == targetId and message.type == "fileStarted" then
                fileStarted = true
            end
        end
    end
    
    if not fileStarted then
        print("  [X] Turtle did not acknowledge file start")
        return false
    end
    
    -- Send all chunks quickly without waiting for individual acks
    for i = 1, totalChunks do
        local startPos = (i - 1) * CHUNK_SIZE + 1
        local endPos = math.min(i * CHUNK_SIZE, fileSize)
        local chunk = content:sub(startPos, endPos)
        
        modem.transmit(SwarmCommon.COMMAND_CHANNEL, SwarmCommon.REPLY_CHANNEL, {
            command = "fileChunk",
            targetId = targetId,
            chunkNum = i,
            chunkData = chunk,
            timestamp = os.epoch("utc")
        })
        
        -- Small delay to prevent overwhelming the network
        sleep(0.05)
    end
    
    print("  All chunks sent, waiting for completion...")
    
    -- Wait for completion confirmation (longer timeout for reassembly)
    local confirmed = false
    local endTime = os.epoch("utc") + 10000  -- 10 seconds for large files
    
    while os.epoch("utc") < endTime and not confirmed do
        local event, side, channel, replyChannel, message = os.pullEvent()
        
        if event == "modem_message" and channel == SwarmCommon.REPLY_CHANNEL then
            if type(message) == "table" and message.id == targetId then
                print("  [DEBUG] Received: " .. tostring(message.type))
                if message.type == "fileComplete" then
                    print("  [OK] " .. message.message)
                    confirmed = true
                elseif message.type == "error" then
                    print("  [X] Error: " .. message.message)
                    return false
                elseif message.type == "chunkReceived" then
                    -- Progress update from client (every 5 chunks)
                    print("  [DEBUG] Progress ack received")
                end
            end
        end
    end
    
    if not confirmed then
        print("  [X] Timeout waiting for file completion")
    end
    
    return confirmed
end

local function provisionTurtle(targetId, fileSet)
    local files = FILE_SETS[fileSet]
    if not files then
        SwarmUI.showStatus("Unknown file set: " .. fileSet, "error")
        return false
    end
    
    print("\nProvisioning turtle #" .. targetId .. " with " .. fileSet .. " package")
    print("Files to send: " .. #files)
    print("")
    
    local success = 0
    local failed = 0
    
    for _, filePath in ipairs(files) do
        if sendFile(targetId, filePath) then
            success = success + 1
        else
            failed = failed + 1
            print("  [X] Failed: " .. filePath)
        end
    end
    
    print("")
    print("=== Provisioning Complete ===")
    print("Success: " .. success .. " files")
    print("Failed: " .. failed .. " files")
    print("")
    print("Press any key to continue...")
    read()
    
    if failed == 0 then
        SwarmUI.showStatus("All files transferred successfully!", "success")
        
        if SwarmUI.confirm("Run install.lua on turtle #" .. targetId .. "?") then
            print("Triggering installation...")
            modem.transmit(SwarmCommon.COMMAND_CHANNEL, SwarmCommon.REPLY_CHANNEL, {
                command = "runInstall",
                targetId = targetId,
                timestamp = os.epoch("utc")
            })
            SwarmUI.showStatus("Installation triggered on turtle #" .. targetId, "info")
        end
        
        return true
    else
        SwarmUI.showStatus("Some files failed to transfer", "error")
        return false
    end
end

local function provisionInteractive()
    local clients = discoverClients()
    
    if not next(clients) then
        SwarmUI.showStatus("No provision clients found!", "error")
        print("Make sure turtles are running provision_client.lua")
        return
    end
    
    print("")
    local targetId = SwarmUI.promptNumber("Enter turtle ID to provision: ", 1)
    
    if not clients[targetId] then
        SwarmUI.showStatus("Turtle #" .. targetId .. " not found in discovered clients", "warning")
        if not SwarmUI.confirm("Provision anyway?") then
            return
        end
    end
    
    print("\nAvailable file sets:")
    print("1. worker - Full worker package (12 files)")
    print("2. minimal - Core files only (6 files)")
    print("3. libraries_only - Just libraries (7 files)")
    print("")
    
    local choice = SwarmUI.promptChoice("Choose file set", {"worker", "minimal", "libraries_only", "cancel"})
    
    if choice == "cancel" then
        return
    end
    
    provisionTurtle(targetId, choice)
end

local function verifyFiles(targetId)
    print("\nVerifying files on turtle #" .. targetId .. "...")
    
    local filesToCheck = {
        "worker.lua",
        "install.lua",
        "lib/swarm_common.lua",
        "lib/swarm_worker_lib.lua",
        "lib/roles.lua"
    }
    
    for _, filePath in ipairs(filesToCheck) do
        modem.transmit(SwarmCommon.COMMAND_CHANNEL, SwarmCommon.REPLY_CHANNEL, {
            command = "verify",
            targetId = targetId,
            fileName = filePath,
            timestamp = os.epoch("utc")
        })
        sleep(0.2)
    end
    
    print("Verification commands sent. Check turtle #" .. targetId .. " for results.")
end

local function discoverTurtles()
    print("\nDiscovering turtles...")
    local turtles = SwarmCommon.discoverTurtles(modem, 3)
    
    local count = 0
    for id, turtle in pairs(turtles) do
        count = count + 1
        print("  Found: Turtle #" .. id .. " (v" .. (turtle.version or "unknown") .. ")")
    end
    
    SwarmUI.showStatus("Discovery complete: " .. count .. " turtles found", count > 0 and "success" or "warning")
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

local function showDiskInstructions()
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

local function showPastebinInstructions()
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
    print("Option 1: Wireless Provisioning (RECOMMENDED)")
    print("  - Use 'Provision turtle' option in this menu")
    print("  - No disk space limits!")
    print("  - Fast and reliable")
    print("")
    print("Option 2: Copy via in-game disk")
    showDiskInstructions()
    
    print("\nOption 3: Use pastebin (if HTTP enabled)")
    showPastebinInstructions()
    
    print("\nOption 4: Type manually (not recommended)")
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

local function showSetupInstructions()
    print("\n=== Deployment System Setup ===")
    print("")
    print("Method 1: Wireless Provisioning (RECOMMENDED)")
    print("  Step 1: Get provision_client.lua onto turtles")
    print("    - Copy provision_client.lua to disk")
    print("    - Transfer to each turtle via disk")
    print("    - Small file (~200 lines) - fits easily on disk!")
    print("")
    print("  Step 2: Start provision client on turtle")
    print("    - On turtle: provision_client")
    print("    - Client will wait for server")
    print("")
    print("  Step 3: Run this provision server")
    print("    - Choose 'Discover clients' to find turtles")
    print("    - Choose 'Provision turtle' to send files")
    print("    - Select file set (worker/minimal/libraries)")
    print("    - Files sent wirelessly in chunks")
    print("")
    print("  Step 4: After provisioning")
    print("    - Server can trigger install.lua automatically")
    print("    - Or manually run install.lua on turtle")
    print("    - Turtle reboots and becomes worker")
    print("")
    print("Method 2: Manual Disk Transfer")
    print("  - See 'Manual transfer instructions' option")
    print("")
    print("Advantages of Wireless Provisioning:")
    print("  - No disk space limits!")
    print("  - Can send full worker package")
    print("  - Updates existing turtles easily")
    print("  - Provision multiple turtles quickly")
    print("")
    SwarmUI.showStatus("Provision client must be running on turtle first for wireless method", "info")
end

local function createQuickStartGuide()
    local guide = {
        "Provision System Quick Start v1.0",
        "====================================",
        "",
        "OVERVIEW:",
        "Wirelessly provision turtles without disk space limits!",
        "",
        "INITIAL SETUP (one-time):",
        "1. Copy provision_client.lua to disk (~200 lines, very small)",
        "2. Transfer disk to turtle",
        "3. On turtle: cp disk/provision_client.lua provision_client.lua",
        "",
        "PROVISIONING WORKFLOW:",
        "1. On turtle: provision_client",
        "   - Shows 'Provision client ready'",
        "   - Waiting for server",
        "",
        "2. On this computer: provision_server",
        "   - Choose '1. Discover provision clients'",
        "   - Verify turtle appears in list",
        "",
        "3. Choose '2. Provision turtle'",
        "   - Enter turtle ID",
        "   - Select file set:",
        "     * worker = Full package (12 files)",
        "     * minimal = Core only (6 files)",
        "     * libraries_only = Just libs (7 files)",
        "",
        "4. Server sends files wirelessly",
        "   - Progress shown on both computers",
        "   - Chunks sent for reliability",
        "",
        "5. Optional: Auto-run install.lua",
        "   - Server prompts after provisioning",
        "   - Or manually run on turtle",
        "",
        "FILE SETS:",
        "",
        "worker (recommended for new turtles):",
        "  - worker.lua, install.lua",
        "  - All libraries (common, worker_lib, ui, roles)",
        "  - All role libraries (miner, courier, builder)",
        "  - Sample programs (digDown, stairs, hello)",
        "",
        "minimal (for basic setup):",
        "  - worker.lua, install.lua",
        "  - Core libraries only",
        "  - No role libraries or programs",
        "",
        "libraries_only (for updates):",
        "  - Just library files",
        "  - Use to update existing turtles",
        "",
        "VERIFICATION:",
        "  - Use option '3. Verify files' to check installation",
        "  - Client confirms file existence and size",
        "",
        "ADVANTAGES:",
        "  - No disk space limitations!",
        "  - Send complete worker package",
        "  - Update multiple turtles easily",
        "  - Faster than disk transfer",
        "",
        "Generated: " .. os.date(),
        "Version: 1.0"
    }
    
    local success, err = SwarmFile.writeFile("PROVISION_GUIDE.txt", table.concat(guide, "\n"))
    if success then
        SwarmUI.showStatus("Created: PROVISION_GUIDE.txt", "success")
    else
        SwarmUI.showStatus("Could not create guide: " .. err, "error")
    end
end

-- Main menu
local function createMainMenu()
    local menu = SwarmUI.Menu.new("Provision Server v4.0")
    
    menu:addOption("1", "Discover provision clients", discoverClients)
    menu:addOption("2", "Provision turtle (wireless)", provisionInteractive)
    menu:addOption("3", "Discover all turtles", discoverTurtles)
    menu:addOption("4", "Check worker status", checkStatus)
    menu:addOption("5", "Verify files on turtle", function()
        local id = SwarmUI.promptNumber("Enter turtle ID: ", 1)
        verifyFiles(id)
    end)
    menu:addOption("6", "Manual transfer instructions", showManualInstructions)
    menu:addOption("7", "Setup instructions", showSetupInstructions)
    menu:addOption("8", "Create quick start guide", createQuickStartGuide)
    menu:addOption("0", "Exit", function() return false end)
    
    return menu
end

-- Initialize
print("Provision server ready!")
print("Make sure turtles are running provision_client.lua")
print("")
createQuickStartGuide()

-- Run main menu
local mainMenu = createMainMenu()
mainMenu:run()

print("Exiting provision server...")
