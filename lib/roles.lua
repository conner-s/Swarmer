-- Role Management System
-- Handles role assignment, configuration, and role-specific functionality
-- Version: 4.0

local SwarmCommon = require("lib.swarm_common")

local RoleManager = {}

-- Role registry and configuration
RoleManager.ROLE_CONFIG_FILE = ".turtle_role"
RoleManager.registeredRoles = {}
RoleManager.currentRole = nil

-- Role metadata structure
RoleManager.RoleMetadata = {}
RoleManager.RoleMetadata.__index = RoleManager.RoleMetadata

function RoleManager.RoleMetadata.new(id, name, description, color)
    local self = setmetatable({}, RoleManager.RoleMetadata)
    self.id = id
    self.name = name or id
    self.description = description or ""
    self.color = color or colors.gray -- Default color for monitor display
    self.configSchema = {} -- Defines what config fields this role needs
    self.commands = {} -- Role-specific commands
    self.libraryPath = nil -- Path to role library file
    return self
end

function RoleManager.RoleMetadata:addConfigField(fieldName, fieldType, required, defaultValue, description)
    self.configSchema[fieldName] = {
        type = fieldType, -- "string", "number", "position", "boolean"
        required = required or false,
        default = defaultValue,
        description = description or ""
    }
    return self
end

function RoleManager.RoleMetadata:addCommand(commandName, description, handler)
    self.commands[commandName] = {
        description = description,
        handler = handler
    }
    return self
end

function RoleManager.RoleMetadata:setLibrary(libraryPath)
    self.libraryPath = libraryPath
    return self
end

-- Role registration
function RoleManager.registerRole(metadata)
    if not metadata or not metadata.id then
        return false, "Invalid role metadata"
    end
    
    RoleManager.registeredRoles[metadata.id] = metadata
    return true
end

function RoleManager.getRole(roleId)
    return RoleManager.registeredRoles[roleId]
end

function RoleManager.listRoles()
    local roles = {}
    for id, metadata in pairs(RoleManager.registeredRoles) do
        table.insert(roles, {
            id = id,
            name = metadata.name,
            description = metadata.description
        })
    end
    table.sort(roles, function(a, b) return a.id < b.id end)
    return roles
end

-- Role instance (assigned to a turtle)
RoleManager.RoleInstance = {}
RoleManager.RoleInstance.__index = RoleManager.RoleInstance

function RoleManager.RoleInstance.new(roleId, config)
    local metadata = RoleManager.getRole(roleId)
    if not metadata then
        return nil, "Unknown role: " .. roleId
    end
    
    local self = setmetatable({}, RoleManager.RoleInstance)
    self.roleId = roleId
    self.metadata = metadata
    self.config = config or {}
    self.library = nil -- Will be loaded if role has a library
    
    -- Validate and apply defaults
    local valid, err = self:validateConfig()
    if not valid then
        return nil, err
    end
    
    -- Load role library if specified
    if metadata.libraryPath then
        local success, lib = pcall(require, metadata.libraryPath)
        if success then
            self.library = lib
        else
            print("Warning: Failed to load role library: " .. lib)
        end
    end
    
    return self
end

function RoleManager.RoleInstance:validateConfig()
    for fieldName, schema in pairs(self.metadata.configSchema) do
        local value = self.config[fieldName]
        
        -- Check required fields
        if schema.required and value == nil then
            return false, "Missing required config field: " .. fieldName
        end
        
        -- Apply defaults
        if value == nil and schema.default ~= nil then
            self.config[fieldName] = schema.default
        end
        
        -- Type validation
        if value ~= nil then
            if schema.type == "number" and type(value) ~= "number" then
                return false, "Field " .. fieldName .. " must be a number"
            elseif schema.type == "string" and type(value) ~= "string" then
                return false, "Field " .. fieldName .. " must be a string"
            elseif schema.type == "boolean" and type(value) ~= "boolean" then
                return false, "Field " .. fieldName .. " must be a boolean"
            elseif schema.type == "position" then
                if type(value) ~= "table" or not value.x or not value.y or not value.z then
                    return false, "Field " .. fieldName .. " must be a position table {x, y, z}"
                end
            end
        end
    end
    
    return true
end

function RoleManager.RoleInstance:getConfig(fieldName)
    return self.config[fieldName]
end

function RoleManager.RoleInstance:setConfig(fieldName, value)
    self.config[fieldName] = value
    return self:validateConfig()
end

function RoleManager.RoleInstance:hasCommand(commandName)
    return self.metadata.commands[commandName] ~= nil
end

function RoleManager.RoleInstance:executeCommand(commandName, args)
    local command = self.metadata.commands[commandName]
    if not command then
        return false, "Unknown command for role " .. self.roleId .. ": " .. commandName
    end
    
    if command.handler then
        return command.handler(self, args)
    end
    
    return false, "Command has no handler"
end

function RoleManager.RoleInstance:getLibrary()
    return self.library
end

function RoleManager.RoleInstance:toTable()
    return {
        roleId = self.roleId,
        config = self.config
    }
end

-- Persistence functions
function RoleManager.saveRole(roleInstance)
    if not roleInstance then
        return false, "No role instance provided"
    end
    
    local data = roleInstance:toTable()
    local success = SwarmCommon.writeJSON(RoleManager.ROLE_CONFIG_FILE, data)
    
    if success then
        RoleManager.currentRole = roleInstance
        return true
    else
        return false, "Failed to save role configuration"
    end
end

function RoleManager.loadRole()
    if not fs.exists(RoleManager.ROLE_CONFIG_FILE) then
        return nil, "No role assigned"
    end
    
    local data = SwarmCommon.readJSON(RoleManager.ROLE_CONFIG_FILE)
    if not data or not data.roleId then
        return nil, "Invalid role configuration"
    end
    
    local instance, err = RoleManager.RoleInstance.new(data.roleId, data.config)
    if not instance then
        return nil, err
    end
    
    RoleManager.currentRole = instance
    return instance
end

function RoleManager.getCurrentRole()
    return RoleManager.currentRole
end

function RoleManager.clearRole()
    if fs.exists(RoleManager.ROLE_CONFIG_FILE) then
        fs.delete(RoleManager.ROLE_CONFIG_FILE)
    end
    RoleManager.currentRole = nil
    return true
end

-- Role assignment and management
function RoleManager.assignRole(roleId, config)
    local instance, err = RoleManager.RoleInstance.new(roleId, config)
    if not instance then
        return false, err
    end
    
    local success, saveErr = RoleManager.saveRole(instance)
    if not success then
        return false, saveErr
    end
    
    return true, instance
end

function RoleManager.getRoleInfo()
    local role = RoleManager.getCurrentRole()
    if not role then
        return {
            assigned = false,
            roleId = nil,
            roleName = nil
        }
    end
    
    return {
        assigned = true,
        roleId = role.roleId,
        roleName = role.metadata.name,
        config = role.config
    }
end

-- Built-in roles (will be registered on load)
function RoleManager.registerBuiltinRoles()
    -- Base Worker (default, no special config)
    local baseWorker = RoleManager.RoleMetadata.new(
        "worker",
        "Base Worker",
        "General purpose worker with no specialization",
        colors.lightGray
    )
    RoleManager.registerRole(baseWorker)
    
    -- Miner role
    local miner = RoleManager.RoleMetadata.new(
        "miner",
        "Miner",
        "Specialized for mining operations with ore collection",
        colors.brown
    )
    miner:addConfigField("homeChest", "position", false, nil, "Position of chest to deposit ores")
    miner:addConfigField("fuelChest", "position", false, nil, "Position of chest to get fuel from")
    miner:addConfigField("keepCobblestone", "boolean", false, false, "Whether to keep cobblestone")
    miner:setLibrary("lib.roles.miner")
    RoleManager.registerRole(miner)
    
    -- Courier role
    local courier = RoleManager.RoleMetadata.new(
        "courier",
        "Courier",
        "Transport items between locations",
        colors.cyan
    )
    courier:addConfigField("pickupChest", "position", true, nil, "Position of pickup chest")
    courier:addConfigField("deliveryChest", "position", true, nil, "Position of delivery chest")
    courier:addConfigField("fuelChest", "position", false, nil, "Position of fuel chest")
    courier:setLibrary("lib.roles.courier")
    RoleManager.registerRole(courier)
    
    -- Builder role
    local builder = RoleManager.RoleMetadata.new(
        "builder",
        "Builder",
        "Construction and building operations",
        colors.orange
    )
    builder:addConfigField("materialChest", "position", false, nil, "Position of material supply chest")
    builder:addConfigField("fuelChest", "position", false, nil, "Position of fuel chest")
    builder:setLibrary("lib.roles.builder")
    RoleManager.registerRole(builder)
    
    -- Farmer role
    local farmer = RoleManager.RoleMetadata.new(
        "farmer",
        "Farmer",
        "Automated farming operations",
        colors.lime
    )
    farmer:addConfigField("harvestChest", "position", false, nil, "Position of harvest collection chest")
    farmer:addConfigField("seedChest", "position", false, nil, "Position of seed supply chest")
    farmer:addConfigField("farmArea", "table", false, nil, "Farm area boundaries")
    farmer:setLibrary("lib.roles.farmer")
    RoleManager.registerRole(farmer)
    
    -- Lumberjack role
    local lumberjack = RoleManager.RoleMetadata.new(
        "lumberjack",
        "Lumberjack",
        "Tree harvesting and replanting",
        colors.green
    )
    lumberjack:addConfigField("logChest", "position", false, nil, "Position of log collection chest")
    lumberjack:addConfigField("saplingChest", "position", false, nil, "Position of sapling supply")
    lumberjack:addConfigField("fuelChest", "position", false, nil, "Position of fuel chest")
    lumberjack:setLibrary("lib.roles.lumberjack")
    RoleManager.registerRole(lumberjack)
end

-- Initialize built-in roles
RoleManager.registerBuiltinRoles()

return RoleManager
