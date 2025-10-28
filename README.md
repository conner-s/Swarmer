# Turtle Swarm Management

Remote control system for CC:Tweaked turtles with wireless communication.

## Version 3.0 Update

This project has been refactored to use a modular library system:

- **lib/**: Shared libraries for all components
- **Enhanced programs**: Better error handling, progress tracking, and UI
- **Backward compatibility**: Original APIs still supported

## Quick Start

### Files You Need

- `install.lua` - Enhanced installer with library support
- `puppetmaster.lua` - Enhanced control interface
- `lib/` directory - Required libraries

### Deploy to a Turtle

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
├── worker.lua          # Worker program
├── startup.lua         # Auto-starts on boot
├── programs/           # Your custom programs
└── backups/            # Automatic backups
```

## Recovery

Turtle not responding? Press `Ctrl+R` to reboot.

Worker won't start? Create `.recovery_mode` file to disable auto-start, fix issues, then delete file and reboot.

## Optional Tools

- `fleet_manager.lua` - Bulk operations for large fleets
- `distribute.lua` - Distribution helper

---

Version 2.2 | Channels: 100 (command), 101 (reply)
