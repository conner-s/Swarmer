# Swarm v4.0 - Role-Based Turtle Management

## What's New in v4.0

Version 4.0 introduces a **role-based architecture** that allows you to:

- Assign specialized roles to turtles (Miner, Courier, Builder, Farmer, Lumberjack)
- Configure role-specific settings (home chest locations, fuel sources, etc.)
- Send commands to entire role groups at once
- Execute role-specific operations with dedicated libraries

## Architecture Overview

### Core Components

```text
lib/
├── roles.lua               # Role management system
├── swarm_common.lua        # Enhanced with role-based targeting
├── swarm_worker_lib.lua    # Base functionality all roles inherit
└── roles/                  # Role-specific libraries
    ├── miner.lua          # Mining operations
    ├── courier.lua        # Item transport
    └── builder.lua        # Construction tasks
```

### How It Works

1. **Base Functionality**: All turtles inherit core functions from `swarm_worker_lib.lua` (fuel, movement, inventory)
2. **Role Assignment**: Turtles can be assigned a role with specific configuration
3. **Role Libraries**: Each role has its own library with specialized functions
4. **Role Targeting**: Commands can target all turtles with a specific role

## Available Roles

### 1. Base Worker (default)

- **ID**: `worker`
- **Description**: General purpose worker with no specialization
- **Config**: None required
- **Use case**: Temporary tasks, general commands

### 2. Miner

- **ID**: `miner`
- **Description**: Specialized for mining operations with ore collection
- **Config Fields**:
  - `homeChest` (position): Location to deposit ores `{x=10, y=20, z=30}`
  - `fuelChest` (position): Location to get fuel from
  - `keepCobblestone` (boolean): Whether to keep cobblestone
- **Role Commands**:
  - `mineShaft <depth>` - Mine straight down
  - `stripMine <length> <spacing> <branches>` - Create strip mine
  - `returnHome` - Go to home chest and deposit items
  - `getFuel` - Navigate to fuel chest and refuel

### 3. Courier

- **ID**: `courier`
- **Description**: Transport items between locations
- **Config Fields** (required):
  - `pickupChest` (position): Pickup location
  - `deliveryChest` (position): Delivery location
  - `fuelChest` (position, optional): Fuel source
- **Role Commands**:
  - `pickup` - Collect items from pickup chest
  - `deliver` - Deliver items to delivery chest
  - `runCycle <count>` - Run pickup→deliver cycle N times
  - `goTo <x> <y> <z>` - Navigate to specific coordinates

### 4. Builder

- **ID**: `builder`
- **Description**: Construction and building operations
- **Config Fields**:
  - `materialChest` (position): Material supply location
  - `fuelChest` (position): Fuel source
- **Role Commands**:
  - `buildWall <length> <height> [slot]` - Build a wall
  - `buildFloor <width> <length> [slot]` - Build a floor/platform
  - `buildTower <height> [slot]` - Build vertical tower
  - `fillArea <w> <h> <d> <mode> [slot]` - Fill or clear area
  - `resupply` - Go to material chest and resupply

### 5. Farmer

- **ID**: `farmer`
- **Description**: Automated farming operations
- **Config Fields**:
  - `harvestChest` (position): Harvest collection location
  - `seedChest` (position): Seed supply location
  - `farmArea` (table): Farm boundaries
- **Status**: Library stub created (implement custom farming logic)

### 6. Lumberjack

- **ID**: `lumberjack`
- **Description**: Tree harvesting and replanting
- **Config Fields**:
  - `logChest` (position): Log collection location
  - `saplingChest` (position): Sapling supply location
  - `fuelChest` (position): Fuel source
- **Status**: Library stub created (implement custom forestry logic)

## Usage Guide

### Assigning Roles

#### From Puppetmaster (Option 9 - Role Management)

```text
Choice: 2 (Assign role to turtle)
Turtle ID: 5
Role ID: miner
Configure role now? y
```

#### From Fleet Manager (Option 5 - Role-based command)

```text
Target role: miner
Command: assignRole
Arguments: courier
```

#### Programmatically from another turtle

```lua
local RoleManager = require("lib.roles")
local success, instance = RoleManager.assignRole("miner", {
    homeChest = {x = 100, y = 64, z = 200},
    fuelChest = {x = 100, y = 64, z = 202},
    keepCobblestone = false
})
```

### Configuring Roles

#### Set Individual Config Field

From Puppetmaster → Role Management → Option 6:

```text
Turtle ID: 5
Config field name: homeChest
Config value: {x=100,y=64,z=200}
```

#### Get Config

From Puppetmaster → Role Management → Option 5:

```text
Turtle ID: 5
```

Response will show role and current configuration.

### Sending Role Commands

#### To a Specific Turtle

From Puppetmaster → Role Management → Option 8:

```text
Target: 5
Role command: mineShaft
Arguments: 50
```

This tells turtle #5 to execute its role-specific `mineShaft` command with depth 50.

#### To All Turtles of a Role

From Puppetmaster → Role Management → Option 8:

```text
Target: role:miner
Role command: returnHome
Arguments: 
```

This tells ALL turtles with the "miner" role to return home and deposit items.

#### From Fleet Manager

Fleet Manager → Option 5:

```text
Target role: courier
Command: roleCommand
Arguments: runCycle 10
```

### Group Operations

#### Assign Role to All Turtles

From Puppetmaster → Role Management → Option 3:

```text
Role ID: worker
Assign role 'worker' to ALL turtles? y
```

#### Reassign Role Group

From Puppetmaster → Role Management → Option 4:

```text
Target role group: worker
New role to assign: miner
```

This changes all "worker" turtles to "miner" role.

## Example Workflows

### Setting Up a Mining Operation

1. **Assign Role**:

   ```text
   Puppetmaster → Role Management → Assign role
   Turtle ID: 10
   Role: miner
   ```

2. **Configure Home Chest**:

   ```text
   Puppetmaster → Role Management → Set role config
   Turtle ID: 10
   Field: homeChest
   Value: {x=100,y=64,z=200}
   ```

3. **Configure Fuel Chest**:

   ```text
   Field: fuelChest
   Value: {x=100,y=64,z=202}
   ```

4. **Start Mining**:

   ```text
   Puppetmaster → Role Management → Send role command
   Target: 10
   Command: mineShaft
   Args: 50
   ```

5. **Return and Deposit**:

   ```text
   Command: returnHome
   Args: (none)
   ```

### Setting Up a Courier Route

1. **Assign courier role** to turtle #15
2. **Configure pickup location**: `{x=50, y=64, z=100}`
3. **Configure delivery location**: `{x=150, y=64, z=100}`
4. **Configure fuel location**: `{x=50, y=64, z=102}`
5. **Run delivery cycle**: `roleCommand runCycle 5`

### Managing Multiple Miners

1. Assign "miner" role to turtles #20-25
2. Configure each with same homeChest and fuelChest
3. Position turtles at different mining locations
4. Send to ALL miners: `role:miner → roleCommand mineShaft 64`
5. When done: `role:miner → roleCommand returnHome`

## Creating Custom Roles

### 1. Define Role Metadata

In `lib/roles.lua`, add your role:

```lua
local customRole = RoleManager.RoleMetadata.new(
    "gatherer",
    "Gatherer",
    "Collects items from the world"
)
customRole:addConfigField("storageChest", "position", true, nil, "Storage location")
customRole:addConfigField("collectRadius", "number", false, 10, "Collection radius")
customRole:setLibrary("lib.roles.gatherer")
RoleManager.registerRole(customRole)
```

### 2. Create Role Library

Create `lib/roles/gatherer.lua`:

```lua
local SwarmWorker = require("lib.swarm_worker_lib")
local SwarmCommon = require("lib.swarm_common")

local Gatherer = {}

function Gatherer.collectItems(roleInstance, radius)
    radius = radius or roleInstance:getConfig("collectRadius")
    
    SwarmWorker.initSession({radius = radius})
    SwarmWorker.sendStatus("Starting collection...", true)
    
    -- Your custom gathering logic here
    -- Use SwarmWorker functions for movement, inventory, etc.
    
    SwarmWorker.endSession(true, "Collection complete")
    return true
end

function Gatherer.handleCommand(roleInstance, command, args)
    if command == "collect" then
        local radius = tonumber(args[1])
        return Gatherer.collectItems(roleInstance, radius)
    elseif command == "returnStorage" then
        -- Navigate to storage and deposit
        local storagePos = roleInstance:getConfig("storageChest")
        -- ... navigation logic ...
        return true
    else
        return false, "Unknown gatherer command: " .. command
    end
end

return Gatherer
```

### 3. Deploy and Use

1. Copy new role library to turtles' `lib/roles/` directory
2. Assign role: `assignRole gatherer`
3. Configure: `setRoleConfig storageChest {x=10,y=20,z=30}`
4. Execute: `roleCommand collect 15`

## Control Programs

### Puppetmaster

Interactive control interface with new Role Management menu (Option 9):

- List available roles and their descriptions
- Assign/clear roles (individual turtles, all turtles, or role groups)
- Configure role-specific settings
- Get role information and current config
- Send role-specific commands to individuals or groups

### Fleet Manager

Bulk operations tool with role-based features:

- **Option 5**: Send role-based commands to entire groups
- **Option 9**: Show fleet status organized by role
- Fleet reports now include role information for each turtle

### Monitor

Real-time fleet visualization with role support:

- **Role Display**: Shows each turtle's assigned role name
- **Color Coding**: Visual identification by role
  - Miner: Brown background
  - Courier: Cyan background
  - Builder: Orange background
  - Farmer: Lime background
  - Lumberjack: Green background
  - Worker (default): Light Gray background
- **Layout**: `ID | ROLE | POSITION` - Easy to spot which turtles are doing what
- Automatically updates as turtles report status

Run `monitor.lua` on an Advanced Computer with a connected monitor to see your fleet at a glance.

## Technical Details

### Role Configuration Storage

Roles are stored in `.turtle_role` file on each turtle:

```json
{
  "roleId": "miner",
  "config": {
    "homeChest": {"x": 100, "y": 64, "z": 200},
    "fuelChest": {"x": 100, "y": 64, "z": 202},
    "keepCobblestone": false
  }
}
```

### Message Protocol

Role-based messages include:

```lua
{
  command = "roleCommand",
  args = {"mineShaft", "50"},
  targetRole = "miner",  -- Optional: target specific role
  targetId = nil,        -- Optional: target specific turtle
  timestamp = 1234567890
}
```

Worker responses include role info:

```lua
{
  id = 10,
  role = "miner",
  roleName = "Miner",
  message = "Mining complete",
  success = true,
  version = "4.0"
}
```

### Role Filtering Logic

Workers accept messages if:

1. No `targetId` specified (broadcast), OR
2. `targetId` matches turtle ID, OR
3. `targetRole` matches current role

This allows flexible targeting:

- Broadcast to all: no filters
- Target specific turtle: `targetId = 5`
- Target role group: `targetRole = "miner"`
- Target specific turtle's role command: both filters

## Best Practices

1. **GPS Required**: Role commands using navigation need GPS setup
2. **Fuel Management**: Configure fuelChest for autonomous operation
3. **Error Handling**: Role commands report failures; check responses
4. **Position Format**: Always use `{x=?, y=?, z=?}` format for positions
5. **Testing**: Test role commands on single turtle before broadcasting
6. **Backups**: Role config is backed up in worker startup.lua backups
7. **Recovery**: If role assignment fails, use `clearRole` and reassign

## Migration from v3.0

v4.0 is backward compatible:

- All v3.0 commands still work
- Turtles without roles function as "base worker"
- Existing programs in `programs/` directory unaffected
- Can gradually assign roles to fleet

To migrate:

1. Update worker.lua, puppetmaster.lua, fleet_manager.lua
2. Copy `lib/roles.lua` and `lib/roles/` directory
3. Turtles auto-load role on boot if assigned
4. Assign roles as needed; no role = base worker mode

## Troubleshooting

**Role command not executing:**

- Check turtle has role assigned: `getRoleInfo`
- Verify role library is deployed: `ls lib/roles`
- Check role config is valid: `getRoleConfig`

**Navigation failing:**

- Ensure GPS is set up and accessible
- Verify position configs are correct
- Check fuel level is sufficient

**Config not saving:**

- Check disk space: `df`
- Verify config value format matches field type
- Use `getRoleConfig` to confirm save

**Role targeting not working:**

- Confirm role name matches exactly (case-sensitive)
- Check worker version includes role support
- Verify messages on correct channels

---

**Version**: 4.0  
**Channels**: 100 (command), 101 (reply), 102 (viewer)  
**License**: MIT
