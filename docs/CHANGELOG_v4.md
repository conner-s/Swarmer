# Swarm Version 4.0 - Changelog

**Release Date**: October 28, 2025  
**Version**: 4.0.0  
**Codename**: "Roles & Responsibilities"

## Summary

Version 4.0 introduces a **role-based architecture** for turtle specialization, allowing organized group management while maintaining the distributed peer-to-peer network design.

## Major Features

### Role-Based Architecture

- Complete role system for turtle specialization
- 6 built-in roles: worker, miner, courier, builder, farmer, lumberjack
- Role-specific command routing and execution
- Role-based group targeting (command all miners, couriers, etc.)
- Per-role configuration system with validation

### Role Management System

- `lib/roles.lua` - Central role management system
- `lib/roles/` directory - Role-specific libraries (miner, courier, builder)
- `.turtle_role` file - Persistent role configuration on turtles
- Role assignment, configuration, and clearing commands
- Role metadata with configurable schemas

## Enhanced Programs

### Puppetmaster v4.0

- **NEW**: Role Management menu (Option 9)
  - List available roles
  - Assign/clear roles (individual, all, or role groups)
  - Configure role-specific settings
  - Send role-specific commands
- Role information in status responses
- Role-based targeting in commands

### Fleet Manager v4.0

- **NEW**: Role-based command option (Option 5)
- **NEW**: Show fleet by role (Option 9)
- Fleet reports include role information
- Role filtering in operations

### Worker v4.0

- Role loading on startup
- Role-based message filtering
- 8 new role management commands:
  `assignRole`, `clearRole`, `getRoleInfo`, `setRoleConfig`,
  `getRoleConfig`, `listRoles`, `roleCommand`
- Status messages include role information

### Monitor v4.0

- **NEW**: Role display column showing each turtle's assigned role
- **NEW**: Role-based color coding for visual identification
  - Miner: Brown
  - Courier: Cyan
  - Builder: Orange
  - Farmer: Lime
  - Lumberjack: Green
  - Worker (default): Light Gray
- Enhanced layout: ID | ROLE | POSITION

## Library Enhancements

### swarm_common.lua

- **NEW**: `sendRoleCommand()` - Send commands to role groups
- **NEW**: JSON serialization utilities (`serializeJSON`, `readJSON`, `writeJSON`)
- Enhanced `sendCommand()` with `targetRole` parameter
- Enhanced message protocol with role information

### Role Libraries (NEW)

- **miner.lua**: Smart ore detection, strip mining, auto-return, auto-refuel
- **courier.lua**: Pickup/delivery cycles, GPS navigation, transport tracking
- **builder.lua**: Wall/floor/tower construction, area operations, material management
- **farmer.lua**: Stub (config schema defined, awaiting implementation)
- **lumberjack.lua**: Stub (config schema defined, awaiting implementation)

## Message Protocol Changes

Messages now support role-based targeting:

```lua
-- Commands with role targeting
{command = "status", targetRole = "miner", ...}

-- Responses include role info  
{id = 5, role = "miner", roleName = "Miner", ...}
```

## File Changes

### New Files

- `lib/roles.lua` - Role management system
- `lib/roles/miner.lua` - Miner role implementation
- `lib/roles/courier.lua` - Courier role implementation
- `lib/roles/builder.lua` - Builder role implementation
- `.turtle_role` - Role configuration file (on turtles when assigned)

### Modified Files

- `worker.lua` - Enhanced with role support (v4.0)
- `puppetmaster.lua` - Added role management menu (v4.0)
- `fleet_manager.lua` - Added role-based operations (v4.0)
- `monitor.lua` - Added role display and color coding (v4.0)
- `lib/swarm_common.lua` - Added role utilities and JSON support
- `README.md` - Updated with v4.0 highlights

### Unchanged Files

- `lib/swarm_worker_lib.lua` - Base functionality (inherited by all roles)
- `lib/swarm_ui.lua` - UI components
- `install.lua`, `distribute.lua` - Deployment tools
- `programs/*` - Example programs

## Backward Compatibility

✅ **100% backward compatible with v3.0**

- All v3.0 commands work unchanged
- Turtles without roles function as "base worker"
- No breaking changes to APIs
- Existing programs unaffected
- Gradual migration supported

### Migration from v3.0

1. Update control programs (puppetmaster, fleet_manager)
2. Update worker.lua on turtles
3. Deploy `lib/roles.lua` and `lib/roles/` directory
4. Roles auto-load on boot (if assigned)
5. No role = base worker mode

## Known Limitations

1. **GPS Required**: Navigation-based role commands require GPS setup
2. **Basic Pathfinding**: Navigation assumes mostly clear paths
3. **No Collision Avoidance**: Multiple turtles can conflict
4. **Manual Configuration**: No auto-discovery of chests
5. **Farmer/Lumberjack**: Libraries are stubs (config defined, implementation needed)

## Future Enhancements

See [README_v4.md](README_v4.md) for detailed roadmap.

**v4.1 (Short Term)**:

- Complete farmer and lumberjack implementations
- Enhanced pathfinding
- Chest auto-discovery

**v4.2 (Medium Term)**:

- Role-based task queuing
- Multi-turtle coordination
- Role inheritance

**v5.0 (Long Term)**:

- Optional central server (hybrid architecture)
- Web dashboard
- Advanced analytics

## Documentation

- **[README_v4.md](README_v4.md)** - Complete user guide and reference
- **[ROLES_GUIDE.md](ROLES_GUIDE.md)** - Quick reference for commands and workflows
- **[README_DEPLOYMENT.md](README_DEPLOYMENT.md)** - Deployment instructions

---

For complete usage guide and examples, see [README_v4.md](README_v4.md)
