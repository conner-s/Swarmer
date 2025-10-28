-- Disk-Based Turtle Deployment System v2.4
-- Loads worker.lua from disk and installs to turtle
-- Usage: Copy install.lua and worker.lua to disk, then run disk/install.lua on turtle
-- Perfect for disk-based distribution

local WORKER_VERSION = "2.4"

print("=== Turtle Worker Installer v2.4 ===")
print("Disk-based deployment system")
print("")

-- Startup script template
local STARTUP_TEMPLATE = [[-- Auto-generated worker startup script
-- Version: %s
-- Generated: %s

local function safeStart()
    if not fs.exists("worker.lua") then
        print("ERROR: worker.lua not found!")
        print("Please re-run installer")
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
    return
end

-- Startup delay
print("Worker starting in 3 seconds...")
print("Press Ctrl+T to abort")

local timer = os.startTimer(3)
while true do
    local event, param = os.pullEvent()
    if event == "timer" and param == timer then
        break
    elseif event == "terminate" then
        print("Startup aborted - recovery mode")
        local file = fs.open(".recovery_mode", "w")
        if file then
            file.write("Recovery mode: " .. os.date())
            file.close()
        end
        return
    end
end

safeStart()
]]

-- Utility functions
local function logStep(message, status)
    local symbol = status == "ok" and "[OK]" or status == "error" and "[ERROR]" or "[INFO]"
    print(symbol .. " " .. message)
end

local function backupFile(filename)
    if fs.exists(filename) then
        if not fs.exists("backups") then
            fs.makeDir("backups")
        end
        local timestamp = os.epoch("utc")
        local backupName = "backups/" .. filename .. "." .. timestamp
        fs.copy(filename, backupName)
        logStep("Backed up " .. filename, "ok")
        return backupName
    end
    return nil
end

local function readFile(filename)
    local file = fs.open(filename, "r")
    if file then
        local content = file.readAll()
        file.close()
        return content
    end
    return nil
end

local function writeFile(filename, content)
    local file = fs.open(filename, "w")
    if file then
        file.write(content)
        file.close()
        return true
    end
    return false
end

local function findWorkerSource()
    -- Get the directory where install.lua is located
    local installPath = shell.getRunningProgram()
    local installDir = fs.getDir(installPath)
    
    -- Look for worker.lua in the same directory as install.lua
    local workerPath = fs.combine(installDir, "worker.lua")
    
    if fs.exists(workerPath) then
        logStep("Found worker.lua at " .. workerPath, "ok")
        return workerPath
    end
    
    -- Fallback: check common disk locations
    local diskPaths = {"disk/worker.lua", "disk0/worker.lua", "disk1/worker.lua"}
    for _, path in ipairs(diskPaths) do
        if fs.exists(path) then
            logStep("Found worker.lua at " .. path, "ok")
            return path
        end
    end
    
    return nil
end

local function install()
    print("Installation process starting...")
    print("")
    
    -- Step 1: Find and load worker.lua
    logStep("Locating worker.lua...", "info")
    local workerSourcePath = findWorkerSource()
    
    if not workerSourcePath then
        logStep("ERROR: Cannot find worker.lua!", "error")
        print("")
        print("Make sure worker.lua is in the same directory as install.lua")
        print("Expected location: Same disk/directory as this installer")
        return false
    end
    
    logStep("Reading worker.lua from " .. workerSourcePath, "info")
    local workerCode = readFile(workerSourcePath)
    
    if not workerCode then
        logStep("Failed to read worker.lua", "error")
        return false
    end
    
    logStep("Worker code loaded (" .. #workerCode .. " bytes)", "ok")
    
    -- Step 2: Backup existing files
    if fs.exists("startup.lua") then
        backupFile("startup.lua")
    end
    if fs.exists("worker.lua") then
        backupFile("worker.lua")
    end
    
    -- Step 3: Write worker code to turtle
    logStep("Installing worker.lua to turtle...", "info")
    if writeFile("worker.lua", workerCode) then
        logStep("Worker code installed", "ok")
    else
        logStep("Failed to write worker.lua", "error")
        return false
    end
    
    -- Step 4: Create startup script
    logStep("Creating startup.lua...", "info")
    local startupContent = string.format(STARTUP_TEMPLATE, 
        WORKER_VERSION, os.date(), WORKER_VERSION)
    
    if writeFile("startup.lua", startupContent) then
        logStep("Startup script created", "ok")
    else
        logStep("Failed to write startup.lua", "error")
        return false
    end
    
    -- Step 5: Create version file
    if writeFile(".worker_version", WORKER_VERSION) then
        logStep("Version tracking enabled", "ok")
    end
    
    -- Step 6: Setup directories
    if not fs.exists("programs") then
        fs.makeDir("programs")
        logStep("Created programs directory", "ok")
    end
    
    if not fs.exists("backups") then
        fs.makeDir("backups")
        logStep("Created backups directory", "ok")
    end
    
    -- Success!
    print("")
    print("=== Installation Complete! ===")
    print("Turtle ID: " .. os.getComputerID())
    print("Worker Version: " .. WORKER_VERSION)
    print("Auto-start: Enabled")
    print("")
    print("Files created:")
    print("  worker.lua     - Worker program")
    print("  startup.lua    - Auto-boot script")
    print("  programs/      - Custom programs")
    print("  backups/       - Backup files")
    print("")
    print("Recovery options:")
    print("  Create '.recovery_mode' to disable auto-start")
    print("  Restore from backups/ directory if needed")
    print("")
    
    return true
end

-- Main installer flow
print("This will install the worker system on this turtle.")
print("")
print("Actions:")
print("  • Backup existing startup.lua (if present)")
print("  • Install worker.lua")
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
        end
    else
        print("")
        print("Installation failed. Check errors above.")
    end
else
    print("Installation cancelled.")
end
