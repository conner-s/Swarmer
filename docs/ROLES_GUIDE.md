# Swarm v4.0 - Quick Reference Guide

> **For detailed documentation, see [README_v4.md](README_v4.md)**

## Command Syntax

### Role Management

```lua
assignRole <roleId> [config]       -- Assign role to turtle
clearRole                          -- Remove role assignment
getRoleInfo                        -- Query current role
setRoleConfig <field> <value>      -- Update role configuration
getRoleConfig [field]              -- Read role configuration
listRoles                          -- List available roles
```

### Role Execution

```lua
roleCommand <command> [args...]    -- Execute role-specific command
```

### Role Targeting

```lua
-- From puppetmaster or fleet_manager:
Target: role:miner                 -- All turtles with "miner" role
Target: 5                          -- Specific turtle #5
```

## Available Roles

| Role | ID | Purpose |
|------|----|---------|
| Base Worker | `worker` | General purpose (default) |
| Miner | `miner` | Mining operations with ore collection |
| Courier | `courier` | Item transport between locations |
| Builder | `builder` | Construction and building |
| Farmer | `farmer` | Farming operations (stub) |
| Lumberjack | `lumberjack` | Tree harvesting (stub) |

## Role Commands

### Miner

```lua
roleCommand mineShaft <depth>
roleCommand stripMine <length> <spacing> <branches>
roleCommand returnHome                    -- Go to homeChest and deposit
roleCommand getFuel                       -- Refuel from fuelChest
```

### Courier

```lua
roleCommand pickup                        -- Collect from pickupChest
roleCommand deliver                       -- Deliver to deliveryChest
roleCommand runCycle <count>              -- Run pickup→deliver N times
roleCommand goTo <x> <y> <z>              -- Navigate to coordinates
```

### Builder

```lua
roleCommand buildWall <length> <height> [slot]
roleCommand buildFloor <width> <length> [slot]
roleCommand buildTower <height> [slot]
roleCommand fillArea <w> <h> <d> <mode> [slot]
roleCommand resupply                      -- Get materials from materialChest
```

## Configuration

### Position Format

```lua
{x=100, y=64, z=200}                     -- Always use this format
```

### Common Config Fields

```lua
setRoleConfig homeChest {x=100,y=64,z=200}
setRoleConfig fuelChest {x=100,y=64,z=202}
setRoleConfig pickupChest {x=50,y=64,z=100}
setRoleConfig deliveryChest {x=150,y=64,z=100}
setRoleConfig materialChest {x=200,y=64,z=200}
setRoleConfig keepCobblestone true
```

## Common Workflows

## Common Workflows

### Mining Team

```bash
1. assignRole miner (turtles #10-15)
2. setRoleConfig homeChest {x=100,y=64,z=200}
3. setRoleConfig fuelChest {x=100,y=64,z=202}
4. Position turtles at mining locations
5. Target: role:miner → roleCommand mineShaft 64
6. Target: role:miner → roleCommand returnHome
```

### Courier Route

```bash
1. assignRole courier (turtle #20)
2. setRoleConfig pickupChest {x=50,y=64,z=100}
3. setRoleConfig deliveryChest {x=150,y=64,z=100}
4. setRoleConfig fuelChest {x=50,y=64,z=102}
5. roleCommand runCycle 999
```

### Construction Team

```bash
1. assignRole builder (turtles #30-35)
2. setRoleConfig materialChest {x=200,y=64,z=200}
3. Position at build locations
4. roleCommand buildWall 20 5
5. roleCommand buildFloor 10 10
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Role command fails | Check `getRoleInfo` - role assigned? |
| Navigation fails | GPS available? Fuel sufficient? |
| Config not saving | Verify position format: `{x=?,y=?,z=?}` |
| Unknown command | Check role has that command (`listRoles`) |

## Menu Shortcuts

**Puppetmaster** → Option 9 (Role Management)  
**Fleet Manager** → Option 5 (Role-based command) or Option 9 (Fleet by role)  
**Monitor** → Shows roles with color coding (Miner=Brown, Courier=Cyan, Builder=Orange, Farmer=Lime, Lumberjack=Green)

---

**For complete documentation:** [README_v4.md](README_v4.md)  
**For changelog:** [CHANGELOG_v4.md](CHANGELOG_v4.md)
