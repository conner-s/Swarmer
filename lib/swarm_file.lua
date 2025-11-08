-- Swarm File Library
-- File operations and utilities
-- Version: 4.0

local SwarmFile = {}

-- File utilities
function SwarmFile.ensureDirectory(path)
    if not fs.exists(path) then
        fs.makeDir(path)
        return true
    end
    return fs.isDir(path)
end

function SwarmFile.readFile(path)
    if not fs.exists(path) then
        return nil, "File not found: " .. path
    end
    
    local file = fs.open(path, "r")
    if not file then
        return nil, "Could not open file: " .. path
    end
    
    local content = file.readAll()
    file.close()
    return content
end

function SwarmFile.writeFile(path, content)
    local file = fs.open(path, "w")
    if not file then
        return false, "Could not create file: " .. path
    end
    
    file.write(content)
    file.close()
    return true
end

-- Enhanced logging with status symbols
function SwarmFile.logStep(message, status)
    local symbol = status == "ok" and "[OK]" or 
                  status == "error" and "[ERROR]" or 
                  status == "warn" and "[WARN]" or 
                  "[INFO]"
    print(symbol .. " " .. message)
end

-- File backup with timestamping
function SwarmFile.backupFile(filename, backupDir)
    backupDir = backupDir or "backups"
    
    if not fs.exists(filename) then
        return nil, "File not found: " .. filename
    end
    
    if not SwarmFile.ensureDirectory(backupDir) then
        return nil, "Could not create backup directory: " .. backupDir
    end
    
    local timestamp = os.epoch("utc")
    local backupName = fs.combine(backupDir, fs.getName(filename) .. "." .. timestamp)
    
    local success, err = pcall(fs.copy, filename, backupName)
    if success then
        SwarmFile.logStep("Backed up " .. filename .. " to " .. backupName, "ok")
        return backupName
    else
        return nil, "Backup failed: " .. tostring(err)
    end
end

-- Generic file discovery utility
function SwarmFile.findFiles(requiredFiles, searchPaths)
    searchPaths = searchPaths or {".", "disk", "disk0", "disk1"}
    
    local sourceFiles = {}
    local missing = {}
    
    for _, filename in ipairs(requiredFiles) do
        local found = false
        
        for _, searchPath in ipairs(searchPaths) do
            local fullPath = fs.combine(searchPath, filename)
            if fs.exists(fullPath) then
                sourceFiles[filename] = fullPath
                SwarmFile.logStep("Found " .. filename .. " at " .. fullPath, "ok")
                found = true
                break
            end
        end
        
        if not found then
            table.insert(missing, filename)
        end
    end
    
    return sourceFiles, missing
end

-- Library installation utility
function SwarmFile.installLibraries(sourceFiles, targetDir)
    targetDir = targetDir or "lib"
    
    SwarmFile.logStep("Installing library files...", "info")
    
    -- Create target directory
    if not SwarmFile.ensureDirectory(targetDir) then
        return false, "Could not create directory: " .. targetDir
    end
    
    -- Recursive function to copy directory contents
    local function copyDirectoryRecursive(sourcePath, targetPath)
        local items = fs.list(sourcePath)
        local copiedCount = 0
        
        for _, item in ipairs(items) do
            local sourceItem = fs.combine(sourcePath, item)
            local targetItem = fs.combine(targetPath, item)
            
            if fs.isDir(sourceItem) then
                -- Create subdirectory
                if not fs.exists(targetItem) then
                    fs.makeDir(targetItem)
                    SwarmFile.logStep("Created directory: " .. targetItem, "ok")
                end
                -- Recursively copy subdirectory contents
                copiedCount = copiedCount + copyDirectoryRecursive(sourceItem, targetItem)
            elseif item:match("%.lua$") then
                -- Copy Lua file
                local content, err = SwarmFile.readFile(sourceItem)
                if content then
                    local success, writeErr = SwarmFile.writeFile(targetItem, content)
                    if success then
                        SwarmFile.logStep("Installed " .. targetItem .. " (" .. #content .. " bytes)", "ok")
                        copiedCount = copiedCount + 1
                    else
                        SwarmFile.logStep("Failed to write " .. targetItem .. ": " .. tostring(writeErr), "error")
                        return 0
                    end
                else
                    SwarmFile.logStep("Failed to read " .. sourceItem .. ": " .. tostring(err), "error")
                    return 0
                end
            end
        end
        
        return copiedCount
    end
    
    -- Check if entire lib directory exists on disk and copy it over
    local diskLibPaths = {"disk/lib", "disk0/lib", "disk1/lib"}
    local foundDiskLib = false
    
    for _, diskLibPath in ipairs(diskLibPaths) do
        if fs.exists(diskLibPath) and fs.isDir(diskLibPath) then
            SwarmFile.logStep("Found library directory at " .. diskLibPath, "ok")
            
            -- Copy entire lib directory recursively (including subdirectories)
            local copiedCount = copyDirectoryRecursive(diskLibPath, targetDir)
            
            if copiedCount > 0 then
                SwarmFile.logStep("Library installation complete: " .. copiedCount .. " files", "ok")
                foundDiskLib = true
                break
            else
                SwarmFile.logStep("Failed to copy files from " .. diskLibPath, "error")
                return false, "Copy failed"
            end
        end
    end
    
    -- Fallback to individual file installation if no disk lib directory found
    if not foundDiskLib then
        SwarmFile.logStep("No disk lib directory found, installing individual files...", "info")
        
        local libraryFiles = {
            "lib/swarm_common.lua",
            "lib/swarm_ui.lua", 
            "lib/swarm_worker_lib.lua",
            "lib/roles.lua"
        }
        
        for _, libFile in ipairs(libraryFiles) do
            if sourceFiles[libFile] then
                local content, err = SwarmFile.readFile(sourceFiles[libFile])
                if not content then
                    SwarmFile.logStep("Failed to read " .. libFile .. ": " .. tostring(err), "error")
                    return false, "Read failed: " .. libFile
                end
                
                local targetPath = fs.combine(targetDir, fs.getName(libFile))
                local success, writeErr = SwarmFile.writeFile(targetPath, content)
                if not success then
                    SwarmFile.logStep("Failed to write " .. targetPath .. ": " .. tostring(writeErr), "error")
                    return false, "Write failed: " .. targetPath
                end
                
                SwarmFile.logStep("Installed " .. targetPath .. " (" .. #content .. " bytes)", "ok")
            end
        end
    end
    
    return true
end

-- Chunked file transfer utilities
SwarmFile.CHUNK_SIZE = 6000

function SwarmFile.splitIntoChunks(content, chunkSize)
    chunkSize = chunkSize or SwarmFile.CHUNK_SIZE
    local chunks = {}
    local pos = 1
    
    while pos <= #content do
        local chunk = content:sub(pos, pos + chunkSize - 1)
        table.insert(chunks, chunk)
        pos = pos + chunkSize
    end
    
    return chunks
end

function SwarmFile.assembleChunks(chunks)
    return table.concat(chunks)
end

return SwarmFile

