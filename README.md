# Turtle Swarm Management

Remote control system for CC:Tweaked turtles with wireless communication.

## Quick Start

### Files You Need

- `install.lua` - Self-contained installer (copy to turtles)
- `puppetmaster_simple.lua` - Control interface

### Deploy to a Turtle

```bash
# On Pocket Computer: copy to disk
cp install.lua disk/install.lua

# On turtle: copy from disk and run
cp disk/install.lua install.lua
install.lua
# Press 'y' twice, turtle reboots as worker
```

### Control Your Fleet

```bash
puppetmaster_simple.lua
# Option 1: Shell Access - Remote control
# Option 2: Ping all - Check online turtles  
# Option 3: Status - Fuel and position
# Option 4: Run program - Execute on turtle
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
