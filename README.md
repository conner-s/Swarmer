# Turtle Swarm Management

Remote control system for CC:Tweaked turtles with wireless communication.

## Version 4.0 Update - Role-Based Architecture 🎭

**New in v4.0**: Role-based turtle management with specialized behaviors!

- **Assign roles** to turtles: Miner, Courier, Builder, Farmer, Lumberjack
- **Configure role-specific settings**: Home chests, fuel sources, delivery routes
- **Group commands**: Send commands to all turtles of a specific role
- **Specialized libraries**: Each role has dedicated functions for its tasks

**Quick Start**: See [ROLES_GUIDE.md](ROLES_GUIDE.md) for role system overview  
**Full Docs**: See [README_v4.md](README_v4.md) for complete v4.0 documentation

### Example: Mining Team

```lua
-- Assign miner role to turtle #10
assignRole miner

-- Configure home chest location
setRoleConfig homeChest {x=100,y=64,z=200}

-- Send to all miners: mine down 64 blocks
Target: role:miner
roleCommand mineShaft 64
```

## Version 3.0 Features

This project has been refactored to use a modular library system:

- **lib/**: Shared libraries for all components
- **Enhanced programs**: Better error handling, progress tracking, and UI
- **Backward compatibility**: Original APIs still supported
- **Role system**: v4.0 adds role-based management (see above)

## Quick Start

### Build & Deploy (Recommended)

Use the automated build system to package and deploy:

```powershell
# Windows
.\build.ps1 production

# Linux/Mac
./build.sh production
```

This creates a deployment package in `deployment/production/` that can be:
- Copied to a ComputerCraft disk
- Uploaded to pastebin
- Hosted on a web server

On ComputerCraft, run `deploy.lua` to reconstruct the directory structure automatically.

**See [BUILD_DEPLOYMENT.md](docs/BUILD_DEPLOYMENT.md) for complete build & deployment guide.**

### Manual Setup

#### Files You Need

- `install.lua` - Enhanced installer with library support
- `puppetmaster.lua` - Enhanced control interface
- `lib/` directory - Required libraries

#### Deploy to a Turtle

```bash
# Copy all required files to disk:
cp install.lua disk/install.lua
cp -r lib disk/lib

# On turtle: copy from disk and run
cp disk/install.lua install.lua
cp -r disk/lib lib
install.lua
# Press 'y' twice, turtle reboots as worker
```

### Control Your Fleet

```bash
puppetmaster.lua
# Option 1: Ping all turtles - Check online status
# Option 2: Check status - Fuel and position  
# Option 3: Run digDown - Mine down specified depth
# Option 4: Custom command - Execute any program
# Option 6: Enhanced Multi-Shell - Interactive control
```

## What Gets Installed

```text
turtle/
├── worker.lua          # v4.0 Worker with role support
├── startup.lua         # Auto-starts on boot
├── .turtle_role        # Role configuration (if assigned)
├── lib/                # Shared libraries
│   ├── swarm_common.lua
│   ├── swarm_worker_lib.lua
│   ├── roles.lua       # Role management
│   └── roles/          # Role-specific libraries
│       ├── miner.lua
│       ├── courier.lua
│       └── builder.lua
├── programs/           # Your custom programs
└── backups/            # Automatic backups
```

## Recovery

Turtle not responding? Press `Ctrl+R` to reboot.

Worker won't start? Create `.recovery_mode` file to disable auto-start, fix issues, then delete file and reboot.

## Optional Tools

- `fleet_manager.lua` - Bulk operations and role-based targeting
- `distribute.lua` - Distribution helper
- `monitor.lua` - Real-time fleet monitoring

---

Version 4.0 | Channels: 100 (command), 101 (reply), 102 (viewer)

📚 **Documentation:**

- [BUILD_DEPLOYMENT.md](docs/BUILD_DEPLOYMENT.md) - Build & deployment guide
- [ROLES_GUIDE.md](docs/ROLES_GUIDE.md) - Quick role system reference
- [README_v4.md](docs/README_v4.md) - Complete v4.0 documentation
- [CHANGELOG_v4.md](docs/CHANGELOG_v4.md) - What's new in v4.0
- [README_DEPLOYMENT.md](docs/README_DEPLOYMENT.md) - Deployment instructions
- [REFACTORING_SUMMARY.md](docs/REFACTORING_SUMMARY.md) - v3.0 refactoring details
