-- Swarm Config Library
-- Configuration management and JSON utilities
-- Version: 4.0

local SwarmConfig = {}
local SwarmFile = require("lib.swarm_file")

-- Configuration directory
SwarmConfig.CONFIG_DIR = "config"
SwarmConfig.CONFIG_FILE = "config/swarm_config.json"

-- JSON utilities (simple serialization for config files)
function SwarmConfig.serializeJSON(value, indent)
    indent = indent or 0
    local indentStr = string.rep("  ", indent)
    
    if type(value) == "table" then
        local items = {}
        local isArray = true
        local count = 0
        
        -- Check if it's an array
        for k, v in pairs(value) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                isArray = false
                break
            end
        end
        
        if isArray then
            -- Array format
            local parts = {}
            for i, v in ipairs(value) do
                table.insert(parts, indentStr .. "  " .. SwarmConfig.serializeJSON(v, indent + 1))
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indentStr .. "]"
        else
            -- Object format
            local parts = {}
            for k, v in pairs(value) do
                local key = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
                table.insert(parts, indentStr .. "  " .. key .. ": " .. SwarmConfig.serializeJSON(v, indent + 1))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indentStr .. "}"
        end
    elseif type(value) == "string" then
        return '"' .. value:gsub('"', '\\"') .. '"'
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    elseif value == nil then
        return "null"
    else
        return '""'
    end
end

function SwarmConfig.writeJSON(path, data)
    local json = SwarmConfig.serializeJSON(data)
    return SwarmFile.writeFile(path, json)
end

function SwarmConfig.readJSON(path)
    local content, err = SwarmFile.readFile(path)
    if not content then
        return nil, err
    end
    
    -- Use textutils.unserialiseJSON if available (CC:Tweaked 1.96+)
    if textutils.unserialiseJSON then
        local success, data = pcall(textutils.unserialiseJSON, content)
        if success then
            return data
        end
    end
    
    -- Fallback to textutils.unserialize for simple cases
    local success, data = pcall(textutils.unserialize, content)
    if success then
        return data
    end
    
    return nil, "Failed to parse JSON"
end

-- Configuration management
function SwarmConfig.init()
    SwarmFile.ensureDirectory(SwarmConfig.CONFIG_DIR)
end

function SwarmConfig.load()
    SwarmConfig.init()
    
    local config, err = SwarmConfig.readJSON(SwarmConfig.CONFIG_FILE)
    if not config then
        -- Return default config
        return {
            version = "4.0",
            worker = {
                autoStart = true,
                recoveryMode = false
            },
            roles = {},
            programs = {}
        }
    end
    
    return config
end

function SwarmConfig.save(config)
    SwarmConfig.init()
    return SwarmConfig.writeJSON(SwarmConfig.CONFIG_FILE, config)
end

function SwarmConfig.get(key, default)
    local config = SwarmConfig.load()
    local keys = {}
    for k in key:gmatch("[^.]+") do
        table.insert(keys, k)
    end
    
    local value = config
    for _, k in ipairs(keys) do
        if type(value) == "table" and value[k] ~= nil then
            value = value[k]
        else
            return default
        end
    end
    
    return value
end

function SwarmConfig.set(key, value)
    local config = SwarmConfig.load()
    local keys = {}
    for k in key:gmatch("[^.]+") do
        table.insert(keys, k)
    end
    
    local current = config
    for i = 1, #keys - 1 do
        local k = keys[i]
        if not current[k] or type(current[k]) ~= "table") then
            current[k] = {}
        end
        current = current[k]
    end
    
    current[keys[#keys]] = value
    return SwarmConfig.save(config)
end

return SwarmConfig

