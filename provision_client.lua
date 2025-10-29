-- Provision Client v1.0
-- Lightweight client to receive files from provision server
-- Small enough to fit on disk for initial turtle setup

local COMMAND_CHANNEL = 100
local REPLY_CHANNEL = 101

-- Minimal modem init
local modem = peripheral.find("modem")
if not modem then
    error("No wireless modem found!")
end

if not modem.isWireless() then
    error("Modem must be wireless!")
end

modem.open(COMMAND_CHANNEL)
modem.open(REPLY_CHANNEL)

local myId = os.getComputerID()

print("=== Provision Client v1.0 ===")
print("Computer ID: " .. myId)
print("Listening on channels " .. COMMAND_CHANNEL .. "/" .. REPLY_CHANNEL)
print("")
print("Waiting for provisioning server...")
print("Press Ctrl+T to cancel")
print("")

-- Send initial ready signal
modem.transmit(REPLY_CHANNEL, COMMAND_CHANNEL, {
    id = myId,
    type = "ready",
    message = "Provision client ready",
    timestamp = os.epoch("utc")
})

-- File receiving state
local receivingFile = nil
local fileChunks = {}

local function sendReply(msgType, message, success)
    modem.transmit(REPLY_CHANNEL, COMMAND_CHANNEL, {
        id = myId,
        type = msgType,
        message = message,
        success = success ~= false,
        timestamp = os.epoch("utc")
    })
end

local function ensureDirectory(filePath)
    local dir = fs.getDir(filePath)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
        print("  Created directory: " .. dir)
    end
end

local function saveFile(filePath, content)
    ensureDirectory(filePath)
    
    -- Backup existing file
    if fs.exists(filePath) then
        local backupPath = filePath .. ".bak"
        if fs.exists(backupPath) then
            fs.delete(backupPath)
        end
        fs.copy(filePath, backupPath)
        print("  Backed up existing file")
    end
    
    local file = fs.open(filePath, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    file.write(content)
    file.close()
    return true
end

-- Main event loop
while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent()
    
    if event == "modem_message" and channel == COMMAND_CHANNEL then
        if type(message) == "table" then
            local command = message.command
            
            -- Check if message is for us (broadcast or specific ID)
            if not message.targetId or message.targetId == myId then
                
                if command == "ping" then
                    sendReply("pong", "Provision client ready", true)
                    
                elseif command == "startFile" then
                    local fileName = message.fileName
                    local fileSize = message.fileSize
                    local totalChunks = message.totalChunks
                    
                    print("Receiving: " .. fileName .. " (" .. fileSize .. " bytes, " .. totalChunks .. " chunks)")
                    
                    receivingFile = {
                        name = fileName,
                        size = fileSize,
                        totalChunks = totalChunks,
                        receivedChunks = 0
                    }
                    fileChunks = {}
                    
                    sendReply("fileStarted", "Ready to receive " .. fileName, true)
                    
                elseif command == "fileChunk" then
                    if not receivingFile then
                        sendReply("error", "No file transfer in progress", false)
                    else
                        local chunkNum = message.chunkNum
                        local chunkData = message.chunkData
                        
                        fileChunks[chunkNum] = chunkData
                        receivingFile.receivedChunks = receivingFile.receivedChunks + 1
                        
                        -- Progress indicator
                        if receivingFile.receivedChunks % 5 == 0 or receivingFile.receivedChunks == receivingFile.totalChunks then
                            print("  Progress: " .. receivingFile.receivedChunks .. "/" .. receivingFile.totalChunks)
                        end
                        
                        sendReply("chunkReceived", "Chunk " .. chunkNum .. " received", true)
                        
                        -- Check if complete
                        if receivingFile.receivedChunks == receivingFile.totalChunks then
                            -- Reassemble file
                            print("  Reassembling file...")
                            local content = ""
                            for i = 1, receivingFile.totalChunks do
                                if not fileChunks[i] then
                                    sendReply("error", "Missing chunk " .. i, false)
                                    receivingFile = nil
                                    fileChunks = {}
                                    break
                                end
                                content = content .. fileChunks[i]
                            end
                            
                            if receivingFile then
                                -- Save file
                                local success, err = saveFile(receivingFile.name, content)
                                if success then
                                    print("[OK] Saved: " .. receivingFile.name)
                                    sendReply("fileComplete", receivingFile.name .. " saved successfully", true)
                                else
                                    print("[X] Failed: " .. err)
                                    sendReply("error", "Failed to save: " .. err, false)
                                end
                                
                                receivingFile = nil
                                fileChunks = {}
                            end
                        end
                    end
                    
                elseif command == "verify" then
                    local fileName = message.fileName
                    local exists = fs.exists(fileName)
                    local size = exists and fs.getSize(fileName) or 0
                    
                    sendReply("verified", fileName .. ": " .. (exists and "exists (" .. size .. " bytes)" or "not found"), exists)
                    
                elseif command == "runInstall" then
                    print("")
                    print("Running installation...")
                    sendReply("installing", "Starting installation", true)
                    
                    if fs.exists("install.lua") then
                        print("Executing install.lua...")
                        shell.run("install.lua")
                    else
                        print("[X] install.lua not found!")
                        sendReply("error", "install.lua not found", false)
                    end
                    
                elseif command == "exit" then
                    print("")
                    print("Provisioning complete!")
                    sendReply("goodbye", "Exiting provision client", true)
                    break
                end
            end
        end
    end
end

modem.close(COMMAND_CHANNEL)
modem.close(REPLY_CHANNEL)
print("Provision client terminated")
