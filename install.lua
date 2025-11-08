-- Disk-Based Turtle Deployment System v4.0
-- Loads worker and libraries from disk and installs to turtle
-- Updated to deploy new library structure including role system

local WORKER_VERSION = "4.0"

-- Load required libraries
local SwarmCommon = nil
local SwarmFile = nil

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
            
            -- Recursive function to copy directory contents
            local function copyDirectory(sourcePath, targetPath)
                local items = fs.list(sourcePath)
                local copiedCount = 0
                
                for _, item in ipairs(items) do
                    local sourceItem = fs.combine(sourcePath, item)
                    local targetItem = fs.combine(targetPath, item)
                    
                    if fs.isDir(sourceItem) then
                        -- Create subdirectory and copy its contents
                        if not fs.exists(targetItem) then
                            fs.makeDir(targetItem)
                            print("[OK] Created directory: " .. targetItem)
                        end
                        copiedCount = copiedCount + copyDirectory(sourceItem, targetItem)
                    elseif item:match("%.lua$") then
                        -- Copy Lua file
                        local success, err = pcall(fs.copy, sourceItem, targetItem)
                        if success then
                            print("[OK] Copied " .. item .. " to " .. targetPath .. "/")
                            copiedCount = copiedCount + 1
                        else
                            print("[ERROR] Failed to copy " .. item .. ": " .. tostring(err))
                        end
                    end
                end
                
                return copiedCount
            end
            
            -- Copy all files and subdirectories
            local copiedFiles = copyDirectory(diskLibPath, "lib")
            
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

-- Try to load libraries, bootstrap if needed
if fs.exists("lib/swarm_common.lua") then
    SwarmCommon = require("lib.swarm_common")
    SwarmFile = require("lib.swarm_file")
else
    -- Try to bootstrap from disk
    print("Library not found locally, checking disk...")
    if bootstrapLibraryFromDisk() then
        -- Try loading again after bootstrap
        if fs.exists("lib/swarm_common.lua") then
            SwarmCommon = require("lib.swarm_common")
            SwarmFile = require("lib.swarm_file")
        else
            error("ERROR: Bootstrap succeeded but swarm_common.lua still not found!")
        end
    else
        error("ERROR: swarm_common.lua library not found!\nPlease ensure lib/swarm_common.lua is available on disk or locally.")
    end
end

print("=== Turtle Worker Installer v4.0 ===")
print("Disk-based deployment system with library and role support")
print("")

-- Startup script template
local STARTUP_TEMPLATE = [[-- Auto-generated worker startup script
-- Version: %s
-- Generated: %s

local function safeStart()
    -- Check for required files
    local requiredFiles = {
        "worker.lua",
      "lib/swarm_common.lua", 
        "lib/swarm_ui.lua", 
        "lib/swarm_worker_lib.lua",
        "lib/roles.lua"
    }
    local missing = {}
    
    for _, file in ipairs(requiredFiles) do
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
    local requiredLibs = {
        "lib/swarm_common.lua",
        "lib/swarm_ui.lua",
        "lib/swarm_worker_lib.lua",
        "lib/roles.lua"
    }
    
    local allLibsExist = true
    for _, lib in ipairs(requiredLibs) do
        if not fs.exists(lib) then
            allLibsExist = false
            break
        end
    end
    
    if not allLibsExist then
        for _, lib in ipairs(requiredLibs) do
            table.insert(requiredFiles, lib)
        end
    end
    
    local installPath = shell.getRunningProgram()
    local installDir = fs.getDir(installPath)
    local searchPaths = {installDir, "disk", "disk0", "disk1"}
    return SwarmFile.findFiles(requiredFiles, searchPaths)
end

local function installWorker(sourceFiles)
    SwarmFile.logStep("Installing worker program...", "info")
    
    local workerSource = sourceFiles["worker.lua"]
    if not workerSource then
        SwarmFile.logStep("Worker source not found", "error")
        return false
    end
    
    local workerCode, err = SwarmFile.readFile(workerSource)
    if not workerCode then
        SwarmFile.logStep("Failed to read worker source", "error")
        return false
    end
    
    -- Backup existing worker if present
    if fs.exists("worker.lua") then
        SwarmFile.backupFile("worker.lua")
    end
    
    local success, writeErr = SwarmFile.writeFile("worker.lua", workerCode)
    if success then
        SwarmFile.logStep("Worker installed (" .. #workerCode .. " bytes)", "ok")
        return true
    else
        SwarmFile.logStep("Failed to write worker", "error")
        return false
    end
end

local function install()
    print("Installation process starting...")
    print("")
    
    -- Step 1: Find all required source files
    SwarmFile.logStep("Locating source files...", "info")
    local sourceFiles, missing = findSourceFiles()
    
    if #missing > 0 then
        SwarmFile.logStep("ERROR: Missing required files!", "error")
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
            SwarmFile.backupFile(file)
        end
    end
    
    -- Step 3: Install libraries (if needed)
    local coreLibs = {
        "lib/swarm_common.lua",
        "lib/swarm_ui.lua",
        "lib/swarm_worker_lib.lua",
        "lib/roles.lua"
    }
    
    local allLibsExist = true
    for _, lib in ipairs(coreLibs) do
        if not fs.exists(lib) then
            allLibsExist = false
            break
        end
    end
    
    if allLibsExist then
        SwarmFile.logStep("Core libraries already installed, skipping library installation", "ok")
        
        -- Check for role libraries (optional but recommended)
        local roleLibsExist = fs.exists("lib/roles") and fs.isDir("lib/roles")
        if roleLibsExist then
            local roleLibs = fs.list("lib/roles")
            local roleCount = 0
            for _, file in ipairs(roleLibs) do
                if file:match("%.lua$") then
                    roleCount = roleCount + 1
                end
            end
            SwarmFile.logStep("Role libraries found: " .. roleCount .. " roles", "ok")
        else
            SwarmFile.logStep("Note: lib/roles/ directory not found (optional)", "info")
        end
    else
        if not SwarmFile.installLibraries(sourceFiles) then
            SwarmFile.logStep("Library installation failed", "error")
            return false
        end
    end
    
    -- Step 4: Install worker
    if not installWorker(sourceFiles) then
        SwarmFile.logStep("Worker installation failed", "error")
        return false
    end
    
    -- Step 5: Create startup script
    SwarmFile.logStep("Creating startup.lua...", "info")
    local startupContent = string.format(STARTUP_TEMPLATE, 
        WORKER_VERSION, os.date("%Y-%m-%d %H:%M:%S"), WORKER_VERSION)
    
    local success, err = SwarmFile.writeFile("startup.lua", startupContent)
    if success then
        SwarmFile.logStep("Startup script created", "ok")
    else
        SwarmFile.logStep("Failed to write startup.lua", "error")
        return false
    end
    
    -- Step 6: Create version file and directories
    local versionSuccess, versionErr = SwarmFile.writeFile(".worker_version", WORKER_VERSION)
    if versionSuccess then
        SwarmFile.logStep("Version tracking enabled", "ok")
    end
    
    -- Setup directories
    local directories = {"programs", "backups"}
    for _, dir in ipairs(directories) do
        if not fs.exists(dir) then
            fs.makeDir(dir)
            SwarmFile.logStep("Created " .. dir .. " directory", "ok")
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
    print("  worker.lua               - Main worker program v4.0")
    print("  lib/swarm_common.lua     - Common library")
    print("  lib/swarm_ui.lua         - UI library")
    print("  lib/swarm_worker_lib.lua - Worker library")
    print("  lib/roles.lua            - Role management system")
    if fs.exists("lib/roles") and fs.isDir("lib/roles") then
        local roleLibs = fs.list("lib/roles")
        local roleCount = 0
        for _, file in ipairs(roleLibs) do
            if file:match("%.lua$") then
                roleCount = roleCount + 1
                print("  lib/roles/" .. file .. string.rep(" ", 16 - #file) .. " - Role library")
            end
        end
        if roleCount == 0 then
            print("  lib/roles/               - (directory created, no roles yet)")
        end
    end
    print("  startup.lua              - Auto-boot script")
    print("  programs/                - Custom programs")
    print("  backups/                 - Backup files")
    print("")
    print("v4.0 Features:")
    print("  • Role-based task specialization")
    print("  • Persistent role configuration")
    print("  • Role-specific command routing")
    print("  • Backward compatible with v3.0")
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