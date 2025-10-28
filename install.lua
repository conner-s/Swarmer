-- Disk-Based Turtle Deployment System v3.0
-- Loads worker and libraries from disk and installs to turtle
-- Updated to deploy new library structure

local WORKER_VERSION = "3.0"

-- Load required common library
local SwarmCommon = nil

-- First, check if we need to bootstrap library installation from disk
local function bootstrapLibraryFromDisk()
    local diskLibPaths = {"disk/lib", "disk0/lib", "disk1/lib"}
    
    for _, diskLibPath in ipairs(diskLibPaths) do
        if fs.exists(diskLibPath) and fs.isDir(diskLibPath) then
            print("[INFO] Found library directory at " .. diskLibPath)
            print("[INFO] Bootstrapping library installation...")
            
            -- Create local lib directory
            if not fs.exists("lib") then
                fs.makeDir("lib")
                print("[OK] Created lib directory")
            end
            
            -- Copy all .lua files from disk lib to local lib
            local libFiles = fs.list(diskLibPath)
            local copiedFiles = 0
            
            for _, fileName in ipairs(libFiles) do
                if fileName:match("%.lua$") then
                    local sourcePath = fs.combine(diskLibPath, fileName)
                    local targetPath = fs.combine("lib", fileName)
                    
                    -- Simple file copy using fs.copy
                    local success, err = pcall(fs.copy, sourcePath, targetPath)
                    if success then
                        print("[OK] Copied " .. fileName .. " to lib/")
                        copiedFiles = copiedFiles + 1
                    else
                        print("[ERROR] Failed to copy " .. fileName .. ": " .. tostring(err))
                        return false
                    end
                end
            end
            
            if copiedFiles > 0 then
                print("[OK] Bootstrap completed - " .. copiedFiles .. " library files installed")
                return true
            else
                print("[WARN] No .lua files found in " .. diskLibPath)
            end
        end
    end
    
    return false
end

-- Try to load library, bootstrap if needed
if fs.exists("lib/swarm_common.lua") then
    SwarmCommon = require("lib.swarm_common")
else
    -- Try to bootstrap from disk
    print("Library not found locally, checking disk...")
    if bootstrapLibraryFromDisk() then
        -- Try loading again after bootstrap
        if fs.exists("lib/swarm_common.lua") then
            SwarmCommon = require("lib.swarm_common")
        else
            error("ERROR: Bootstrap succeeded but swarm_common.lua still not found!")
        end
    else
        error("ERROR: swarm_common.lua library not found!\nPlease ensure lib/swarm_common.lua is available on disk or locally.")
    end
end

print("=== Turtle Worker Installer v3.0 ===")
print("Disk-based deployment system with library support")
print("")

-- Startup script template
local STARTUP_TEMPLATE = [[-- Auto-generated worker startup script
-- Version: %s
-- Generated: %s

    local function safeStart()
    -- Check for required files
    local requiredFiles = {"worker.lua", "lib/swarm_common.lua", "lib/swarm_ui.lua", "lib/swarm_worker_lib.lua"}
    local missing = {}    for _, file in ipairs(requiredFiles) do
        if not fs.exists(file) then
            table.insert(missing, file)
        end
    end
    
    if #missing > 0 then
        print("ERROR: Missing required files:")
        for _, file in ipairs(missing) do
            print("  " .. file)
        end
        print("Please re-run installer or restore from backups")
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
        print("Check logs or enable recovery mode")
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
    print("Available files:")
    local files = fs.list("")
    for _, file in ipairs(files) do
        if file:match("%%.lua$") then
            print("  " .. file)
        end
    end
    return
end

-- Startup delay
print("Worker starting in 3 seconds...")
print("Press Ctrl+T to abort and enable recovery mode")

local timer = os.startTimer(3)
while true do
    local event, param = os.pullEvent()
    if event == "timer" and param == timer then
        break
    elseif event == "terminate" then
        print("Startup aborted - enabling recovery mode")
        local file = fs.open(".recovery_mode", "w")
        if file then
            file.write("Recovery mode enabled: " .. os.date())
            file.close()
        end
        return
    end
end

safeStart()
]]

local function findSourceFiles()
    local requiredFiles = {"worker.lua"}
    
    -- Only require library files if they don't already exist locally
    if not (fs.exists("lib/swarm_common.lua") and fs.exists("lib/swarm_ui.lua") and fs.exists("lib/swarm_worker_lib.lua")) then
        table.insert(requiredFiles, "lib/swarm_common.lua")
        table.insert(requiredFiles, "lib/swarm_ui.lua")
        table.insert(requiredFiles, "lib/swarm_worker_lib.lua")
    end
    
    local installPath = shell.getRunningProgram()
    local installDir = fs.getDir(installPath)
    local searchPaths = {installDir, "disk", "disk0", "disk1"}
    return SwarmCommon.findFiles(requiredFiles, searchPaths)
end

local function installWorker(sourceFiles)
    SwarmCommon.logStep("Installing worker program...", "info")
    
    local workerSource = sourceFiles["worker.lua"]
    if not workerSource then
        SwarmCommon.logStep("Worker source not found", "error")
        return false
    end
    
    local workerCode, err = SwarmCommon.readFile(workerSource)
    if not workerCode then
        SwarmCommon.logStep("Failed to read worker source", "error")
        return false
    end
    
    -- Backup existing worker if present
    if fs.exists("worker.lua") then
        SwarmCommon.backupFile("worker.lua")
    end
    
    local success, writeErr = SwarmCommon.writeFile("worker.lua", workerCode)
    if success then
        SwarmCommon.logStep("Worker installed (" .. #workerCode .. " bytes)", "ok")
        return true
    else
        SwarmCommon.logStep("Failed to write worker", "error")
        return false
    end
end

local function install()
    print("Installation process starting...")
    print("")
    
    -- Step 1: Find all required source files
    SwarmCommon.logStep("Locating source files...", "info")
    local sourceFiles, missing = findSourceFiles()
    
    if #missing > 0 then
        SwarmCommon.logStep("ERROR: Missing required files!", "error")
        for _, file in ipairs(missing) do
            print("  Missing: " .. file)
        end
        print("")
        print("Make sure all files are available:")
        print("- worker.lua (required)")
        print("- lib/ directory on disk (will be copied automatically)")
        print("- OR individual library files: lib/swarm_common.lua, lib/swarm_ui.lua, lib/swarm_worker_lib.lua")
        return false
    end
    
    -- Step 2: Backup existing files
    local filesToBackup = {"startup.lua", "worker.lua"}
    for _, file in ipairs(filesToBackup) do
        if fs.exists(file) then
            SwarmCommon.backupFile(file)
        end
    end
    
    -- Step 3: Install libraries (if needed)
    local allLibsExist = fs.exists("lib/swarm_common.lua") and fs.exists("lib/swarm_ui.lua") and fs.exists("lib/swarm_worker_lib.lua")
    
    if allLibsExist then
        SwarmCommon.logStep("Libraries already installed, skipping library installation", "ok")
    else
        if not SwarmCommon.installLibraries(sourceFiles) then
            SwarmCommon.logStep("Library installation failed", "error")
            return false
        end
    end
    
    -- Step 4: Install worker
    if not installWorker(sourceFiles) then
        SwarmCommon.logStep("Worker installation failed", "error")
        return false
    end
    
    -- Step 5: Create startup script
    SwarmCommon.logStep("Creating startup.lua...", "info")
    local startupContent = string.format(STARTUP_TEMPLATE, 
        WORKER_VERSION, os.date("%Y-%m-%d %H:%M:%S"), WORKER_VERSION)
    
    local success, err = SwarmCommon.writeFile("startup.lua", startupContent)
    if success then
        SwarmCommon.logStep("Startup script created", "ok")
    else
        SwarmCommon.logStep("Failed to write startup.lua", "error")
        return false
    end
    
    -- Step 6: Create version file and directories
    local versionSuccess, versionErr = SwarmCommon.writeFile(".worker_version", WORKER_VERSION)
    if versionSuccess then
        SwarmCommon.logStep("Version tracking enabled", "ok")
    end
    
    -- Setup directories
    local directories = {"programs", "backups"}
    for _, dir in ipairs(directories) do
        if not fs.exists(dir) then
            fs.makeDir(dir)
            SwarmCommon.logStep("Created " .. dir .. " directory", "ok")
        end
    end
    
    -- Success!
    print("")
    print("=== Installation Complete! ===")
    print("Turtle ID: " .. os.getComputerID())
    print("Worker Version: " .. WORKER_VERSION)
    print("Auto-start: Enabled")
    print("")
    print("Installed files:")
    print("  worker.lua       - Main worker program")
    print("  lib/swarm_common.lua     - Common library")
    print("  lib/swarm_ui.lua         - UI library")
    print("  lib/swarm_worker_lib.lua - Worker library")
    print("  startup.lua          - Auto-boot script")
    print("  programs/            - Custom programs")
    print("  backups/             - Backup files")
    print("")
    print("Recovery options:")
    print("  Create '.recovery_mode' to disable auto-start")
    print("  Restore from backups/ directory if needed")
    print("  Check library files if worker fails to start")
    print("")
    
    return true
end

-- Check if this is an upgrade
local isUpgrade = fs.exists(".worker_version")
if isUpgrade then
    local file = fs.open(".worker_version", "r")
    local currentVersion = file and file.readAll() or "unknown"
    if file then file.close() end
    
    print("Existing installation detected (v" .. currentVersion .. ")")
    print("This will upgrade to v" .. WORKER_VERSION)
    print("")
end

-- Main installer flow
print("This will install the worker system v" .. WORKER_VERSION .. " on this turtle.")
print("")
print("Actions:")
print("  • Backup existing files (if present)")
print("  • Install worker program and libraries")
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
            print("Or run manually: worker.lua")
        end
    else
        print("")
        print("Installation failed. Check errors above.")
        print("Try recovery mode or restore from backups.")
    end
else
    print("Installation cancelled.")
end