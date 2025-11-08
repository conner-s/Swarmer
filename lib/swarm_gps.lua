-- Swarm GPS Library
-- GPS and position utilities
-- Version: 4.0

local SwarmGPS = {}

-- GPS utilities
function SwarmGPS.getCurrentPosition(timeout)
    local x, y, z = gps.locate(timeout or 5, false)
    if x then
        return {x = x, y = y, z = z}
    end
    return nil
end

function SwarmGPS.formatPosition(position)
    if not position or not position.x then
        return "Unknown"
    end
    return string.format("X:%d Y:%d Z:%d", position.x, position.y, position.z)
end

return SwarmGPS

