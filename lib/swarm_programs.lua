-- Swarm Programs Library
-- Program registry and discovery system
-- Version: 4.0

local SwarmPrograms = {}
local SwarmFile = require("lib.swarm_file")

SwarmPrograms.PROGRAMS_DIR = "programs"

-- Program registry
local programRegistry = {}

-- Discover and register programs
function SwarmPrograms.discoverPrograms()
    programRegistry = {}
    
    if not fs.exists(SwarmPrograms.PROGRAMS_DIR) then
        SwarmFile.ensureDirectory(SwarmPrograms.PROGRAMS_DIR)
        return programRegistry
    end
    
    local files = fs.list(SwarmPrograms.PROGRAMS_DIR)
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            local programName = file:gsub("%.lua$", "")
            local programPath = SwarmPrograms.PROGRAMS_DIR .. "/" .. file
            
            -- Try to extract metadata from file
            local content, err = SwarmFile.readFile(programPath)
            if content then
                local metadata = SwarmPrograms.extractMetadata(content, programName)
                programRegistry[programName] = {
                    name = programName,
                    path = programPath,
                    metadata = metadata
                }
            end
        end
    end
    
    return programRegistry
end

-- Extract metadata from program file
function SwarmPrograms.extractMetadata(content, programName)
    local metadata = {
        name = programName,
        description = "No description available",
        usage = nil,
        version = "1.0"
    }
    
    -- Look for metadata comments at the top of the file
    for line in content:gmatch("[^\r\n]+") do
        -- Extract description
        local desc = line:match("^%-%-%s*([^%-].+)")
        if desc and not desc:match("^%s*$") then
            if not metadata.description:match("No description") then
                metadata.description = desc:gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
        
        -- Extract usage
        local usage = line:match("^%-%-%s*[Uu]sage:%s*(.+)")
        if usage then
            metadata.usage = usage:gsub("^%s+", ""):gsub("%s+$", "")
        end
        
        -- Extract version
        local version = line:match("^%-%-%s*[Vv]ersion:%s*(.+)")
        if version then
            metadata.version = version:gsub("^%s+", ""):gsub("%s+$", "")
        end
    end
    
    return metadata
end

-- Get all registered programs
function SwarmPrograms.listPrograms()
    if not next(programRegistry) then
        SwarmPrograms.discoverPrograms()
    end
    return programRegistry
end

-- Get a specific program
function SwarmPrograms.getProgram(name)
    if not next(programRegistry) then
        SwarmPrograms.discoverPrograms()
    end
    return programRegistry[name]
end

-- Format program list for display
function SwarmPrograms.formatProgramList()
    local programs = SwarmPrograms.listPrograms()
    local list = {}
    
    for name, program in pairs(programs) do
        table.insert(list, {
            name = name,
            description = program.metadata.description,
            usage = program.metadata.usage,
            version = program.metadata.version
        })
    end
    
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

return SwarmPrograms

