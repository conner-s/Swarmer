-- Swarm Worker Library
-- Common functionality for worker turtles and programs
-- Version: 3.0

local SwarmCommon = require("lib.swarm_common")
local SwarmWorker = {}

-- Worker constants
SwarmWorker.DEFAULT_FUEL_THRESHOLD = 50
SwarmWorker.DEFAULT_REFUEL_ATTEMPTS = 16

-- Fuel management
function SwarmWorker.checkFuelLevel()
    local fuelLevel = turtle.getFuelLevel()
    
    if fuelLevel == "unlimited" then
        return true, "unlimited"
    end
    
    return fuelLevel, fuelLevel
end

function SwarmWorker.needsRefuel(threshold)
    threshold = threshold or SwarmWorker.DEFAULT_FUEL_THRESHOLD
    local isUnlimited, fuelLevel = SwarmWorker.checkFuelLevel()
    
    if isUnlimited == true then
        return false
    end
    
    return fuelLevel < threshold
end

function SwarmWorker.refuel(maxAttempts)
    maxAttempts = maxAttempts or SwarmWorker.DEFAULT_REFUEL_ATTEMPTS
    local startingFuel = turtle.getFuelLevel()
    
    -- Try each slot for fuel
    for slot = 1, maxAttempts do
        turtle.select(slot)
        if turtle.refuel(0) then -- Check if item is fuel
            local consumed = turtle.refuel(1) -- Consume one item
            if consumed then
                local newFuel = turtle.getFuelLevel()
                turtle.select(1) -- Reset to first slot
                return true, newFuel, newFuel - startingFuel
            end
        end
    end
    
    turtle.select(1) -- Reset to first slot
    return false, startingFuel, 0
end

function SwarmWorker.ensureFuel(threshold)
    threshold = threshold or SwarmWorker.DEFAULT_FUEL_THRESHOLD
    
    if not SwarmWorker.needsRefuel(threshold) then
        return true, "Fuel sufficient"
    end
    
    local success, newLevel, gained = SwarmWorker.refuel()
    if success then
        return true, "Refueled to " .. newLevel .. " (+" .. gained .. ")"
    else
        return false, "No fuel available"
    end
end

-- Status reporting utilities
SwarmWorker.statusCallback = nil

function SwarmWorker.setStatusCallback(callback)
    SwarmWorker.statusCallback = callback
end

function SwarmWorker.sendStatus(message, success)
    success = success ~= false -- Default to true unless explicitly false
    
    if SwarmWorker.statusCallback then
        SwarmWorker.statusCallback(message, success)
    elseif _G.sendStatus then
        _G.sendStatus(message, success)
    else
        local prefix = success and "[OK]" or "[ERROR]"
        print(prefix .. " " .. message)
    end
end

-- Movement with fuel checking
function SwarmWorker.safeMove(moveFunc, digFunc, attackFunc, fuelCheck)
    fuelCheck = fuelCheck ~= false -- Default to true
    
    if fuelCheck then
        local hasEnough, message = SwarmWorker.ensureFuel()
        if not hasEnough then
            SwarmWorker.sendStatus("Movement failed: " .. message, false)
            return false
        end
    end
    
    -- Attempt movement with digging/attacking if needed
    local attempts = 0
    local maxAttempts = 10
    
    while not moveFunc() and attempts < maxAttempts do
        attempts = attempts + 1
        
        if digFunc then
            digFunc()
        end
        if attackFunc then
            attackFunc()
        end
        
        os.sleep(0.5)
    end
    
    return attempts < maxAttempts
end

function SwarmWorker.forward(fuelCheck)
    return SwarmWorker.safeMove(turtle.forward, turtle.dig, turtle.attack, fuelCheck)
end

function SwarmWorker.back(fuelCheck)
    return SwarmWorker.safeMove(turtle.back, nil, nil, fuelCheck)
end

function SwarmWorker.up(fuelCheck)
    return SwarmWorker.safeMove(turtle.up, turtle.digUp, turtle.attackUp, fuelCheck)
end

function SwarmWorker.down(fuelCheck)
    return SwarmWorker.safeMove(turtle.down, turtle.digDown, turtle.attackDown, fuelCheck)
end

-- Progress tracking
SwarmWorker.ProgressTracker = {}
SwarmWorker.ProgressTracker.__index = SwarmWorker.ProgressTracker

function SwarmWorker.ProgressTracker.new(total, reportInterval)
    local self = setmetatable({}, SwarmWorker.ProgressTracker)
    self.total = total
    self.current = 0
    self.reportInterval = reportInterval or 10
    self.lastReport = 0
    return self
end

function SwarmWorker.ProgressTracker:increment()
    self.current = self.current + 1
    
    if self.current % self.reportInterval == 0 or self.current == self.total then
        SwarmWorker.sendStatus("Progress: " .. self.current .. "/" .. self.total, true)
        self.lastReport = self.current
    end
end

function SwarmWorker.ProgressTracker:setProgress(value)
    self.current = value
    
    if self.current - self.lastReport >= self.reportInterval or self.current == self.total then
        SwarmWorker.sendStatus("Progress: " .. self.current .. "/" .. self.total, true)
        self.lastReport = self.current
    end
end

function SwarmWorker.ProgressTracker:isComplete()
    return self.current >= self.total
end

function SwarmWorker.ProgressTracker:getPercentage()
    return math.floor((self.current / self.total) * 100)
end

-- Position tracking
SwarmWorker.position = {x = 0, y = 0, z = 0, facing = 0}

function SwarmWorker.updatePosition()
    local pos = SwarmCommon.getCurrentPosition()
    if pos then
        SwarmWorker.position.x = pos.x
        SwarmWorker.position.y = pos.y
        SwarmWorker.position.z = pos.z
    end
end

function SwarmWorker.getPosition()
    return SwarmWorker.position
end

function SwarmWorker.reportPosition()
    SwarmWorker.updatePosition()
    local posStr = SwarmCommon.formatPosition(SwarmWorker.position)
    SwarmWorker.sendStatus("Position: " .. posStr, true)
end

-- Task execution framework
SwarmWorker.Task = {}
SwarmWorker.Task.__index = SwarmWorker.Task

function SwarmWorker.Task.new(name, description)
    local self = setmetatable({}, SwarmWorker.Task)
    self.name = name or "Unnamed Task"
    self.description = description or ""
    self.steps = {}
    self.currentStep = 0
    self.completed = false
    self.failed = false
    return self
end

function SwarmWorker.Task:addStep(name, func)
    table.insert(self.steps, {
        name = name,
        func = func,
        completed = false
    })
end

function SwarmWorker.Task:execute()
    SwarmWorker.sendStatus("Starting task: " .. self.name, true)
    
    for i, step in ipairs(self.steps) do
        self.currentStep = i
        SwarmWorker.sendStatus("Step " .. i .. "/" .. #self.steps .. ": " .. step.name, true)
        
        local success, result = pcall(step.func)
        if not success then
            SwarmWorker.sendStatus("Step failed: " .. tostring(result), false)
            self.failed = true
            return false, "Step " .. i .. " failed: " .. tostring(result)
        elseif result == false then
            SwarmWorker.sendStatus("Step cancelled", false)
            self.failed = true
            return false, "Step " .. i .. " was cancelled"
        end
        
        step.completed = true
    end
    
    self.completed = true
    SwarmWorker.sendStatus("Task completed: " .. self.name, true)
    return true
end

function SwarmWorker.Task:getProgress()
    return self.currentStep, #self.steps
end

-- Mining utilities
function SwarmWorker.digDirection(direction, attempts)
    attempts = attempts or 10
    local digFunc, detectFunc
    
    if direction == "forward" then
        digFunc = turtle.dig
        detectFunc = turtle.detect
    elseif direction == "up" then
        digFunc = turtle.digUp
        detectFunc = turtle.detectUp
    elseif direction == "down" then
        digFunc = turtle.digDown
        detectFunc = turtle.detectDown
    else
        return false, "Invalid direction: " .. tostring(direction)
    end
    
    for i = 1, attempts do
        if not detectFunc() then
            return true -- Already clear
        end
        
        if not digFunc() then
            os.sleep(0.5) -- Wait for block to regenerate or be mineable
        else
            return true
        end
    end
    
    return false, "Could not dig " .. direction .. " after " .. attempts .. " attempts"
end

-- Inventory management
function SwarmWorker.getInventoryInfo()
    local info = {
        slots = {},
        freeSlots = 0,
        usedSlots = 0,
        totalItems = 0
    }
    
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            info.slots[slot] = item
            info.usedSlots = info.usedSlots + 1
            info.totalItems = info.totalItems + item.count
        else
            info.freeSlots = info.freeSlots + 1
        end
    end
    
    return info
end

function SwarmWorker.findItem(itemName)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == itemName then
            return slot, item
        end
    end
    return nil
end

function SwarmWorker.findFreeSlot()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return slot
        end
    end
    return nil
end

function SwarmWorker.dropAllItems(direction)
    direction = direction or "down"
    local dropFunc
    
    if direction == "forward" then
        dropFunc = turtle.drop
    elseif direction == "up" then
        dropFunc = turtle.dropUp
    else
        dropFunc = turtle.dropDown
    end
    
    local dropped = 0
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            if dropFunc() then
                dropped = dropped + 1
            end
        end
    end
    
    turtle.select(1)
    return dropped
end

-- Program execution helpers
function SwarmWorker.validateArgs(args, required)
    return SwarmCommon.validateArgs(args, required)
end

function SwarmWorker.getNumericArg(args, index, min, max, default)
    local value = args[index] or default
    if not value then
        return nil, "Missing argument " .. index
    end
    
    local valid, num = SwarmCommon.validateNumber(value, min, max)
    if not valid then
        return nil, "Invalid argument " .. index .. ": " .. num
    end
    
    return num
end

function SwarmWorker.getStringArg(args, index, validChoices, default)
    local value = args[index] or default
    if not value then
        return nil, "Missing argument " .. index
    end
    
    if validChoices then
        for _, choice in ipairs(validChoices) do
            if value:lower() == choice:lower() then
                return choice
            end
        end
        return nil, "Invalid choice '" .. value .. "'. Valid options: " .. table.concat(validChoices, ", ")
    end
    
    return value
end

-- Session management for worker programs
SwarmWorker.currentSession = {}

function SwarmWorker.initSession(args)
    SwarmWorker.currentSession = {
        args = args or {},
        startTime = os.epoch("utc"),
        startFuel = turtle.getFuelLevel(),
        startPosition = SwarmCommon.getCurrentPosition()
    }
    
    SwarmWorker.updatePosition()
    SwarmWorker.sendStatus("Session initialized", true)
end

function SwarmWorker.getSession()
    return SwarmWorker.currentSession
end

function SwarmWorker.endSession(success, message)
    local session = SwarmWorker.currentSession
    if not session.startTime then
        return -- No active session
    end
    
    local duration = os.epoch("utc") - session.startTime
    local fuelUsed = session.startFuel - turtle.getFuelLevel()
    
    local summary = string.format("Duration: %.1fs, Fuel used: %d", 
                                 duration / 1000, fuelUsed)
    
    if message then
        SwarmWorker.sendStatus(message .. " (" .. summary .. ")", success)
    else
        SwarmWorker.sendStatus("Session ended (" .. summary .. ")", success)
    end
    
    SwarmWorker.currentSession = {}
end

return SwarmWorker