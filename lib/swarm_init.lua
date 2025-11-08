-- Swarm Initialization Library
-- Common startup patterns and initialization helpers
-- Version: 4.0

local SwarmInit = {}
local SwarmCommon = require("lib.swarm_common")

-- Initialize modem and open required channels
function SwarmInit.initModem(channels)
    channels = channels or {SwarmCommon.REPLY_CHANNEL}
    
    local modem, err = SwarmCommon.initModem()
    if not modem then
        return nil, err
    end
    
    SwarmCommon.openChannels(modem, channels)
    return modem, nil
end

-- Initialize worker environment
function SwarmInit.initWorker(options)
    options = options or {}
    
    local modem, err = SwarmInit.initModem({SwarmCommon.COMMAND_CHANNEL})
    if not modem then
        return nil, err
    end
    
    -- Ensure directories exist
    local SwarmFile = require("lib.swarm_file")
    SwarmFile.ensureDirectory("programs")
    SwarmFile.ensureDirectory("backups")
    
    return modem, nil
end

-- Initialize server environment
function SwarmInit.initServer(options)
    options = options or {}
    
    local modem, err = SwarmInit.initModem({SwarmCommon.REPLY_CHANNEL, SwarmCommon.VIEWER_CHANNEL})
    if not modem then
        return nil, err
    end
    
    return modem, nil
end

-- Initialize provision client environment
function SwarmInit.initProvisionClient()
    local modem, err = SwarmInit.initModem({SwarmCommon.COMMAND_CHANNEL, SwarmCommon.REPLY_CHANNEL})
    if not modem then
        return nil, err
    end
    
    return modem, nil
end

return SwarmInit

