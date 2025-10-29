# Swarm v4.0 Testing Checklist

This checklist helps verify all functionality is working correctly after deployment or updates.

## Testing Environment Setup

### Required Equipment

- [ ] 1x Advanced Computer (for puppetmaster)
- [ ] 1x Advanced Pocket Computer (alternative for puppetmaster)
- [ ] 2-3x Mining Turtles (for testing)
- [ ] 1x Advanced Computer + Monitor (for monitor testing)
- [ ] 1x Wireless Modem (per computer/turtle)
- [ ] 2-3x Chests (for role testing)
- [ ] GPS system (3+ computers at build height with modems)

### Pre-Test Setup

- [ ] GPS system is operational (`gps locate` returns coordinates)
- [ ] All computers have wireless modems equipped/attached
- [ ] Test chests placed at known coordinates (note locations)
- [ ] Fuel available for turtles (coal, lava buckets, etc.)

### Test Coordinates to Note

```
Home Chest:     X: _____  Y: _____  Z: _____
Fuel Chest:     X: _____  Y: _____  Z: _____
Pickup Chest:   X: _____  Y: _____  Z: _____
Delivery Chest: X: _____  Y: _____  Z: _____
Material Chest: X: _____  Y: _____  Z: _____
```

---

## 1. Build & Deployment System

### Build Script (PowerShell)

- [ ] Run `.\build.ps1 test_deployment`
- [ ] Verify `deployment/test_deployment/` directory created
- [ ] Check all 16 files present and flattened (e.g., `lib__roles__miner.lua`)
- [ ] Verify `manifest.txt` contains correct mappings
- [ ] Verify `deploy.lua` created (should be ~90 lines)
- [ ] Verify `README.txt` created with instructions

**Expected Output:**

```
=== Swarm v4.0 Build Script ===
Deployment Name: test_deployment

Flattening directory structure...
  [OK] puppetmaster.lua -> puppetmaster.lua
  [OK] lib/roles/miner.lua -> lib__roles__miner.lua
  ...
=== Build Complete ===
Files: 16
```

### Build Script (Bash) - Optional

- [ ] Run `./build.sh test_deployment`
- [ ] Verify same output as PowerShell version
- [ ] Compare files to PowerShell deployment (should be identical)

### Deploy Script (ComputerCraft)

- [ ] Copy `deployment/test_deployment/` to CC disk
- [ ] On CC computer: `cd disk/test_deployment`
- [ ] Run `deploy.lua`
- [ ] Verify directory structure created:
  - [ ] `swarm/` directory exists
  - [ ] `swarm/lib/` directory exists
  - [ ] `swarm/lib/roles/` directory exists
  - [ ] `swarm/programs/` directory exists
- [ ] Verify all 16 files in correct locations
- [ ] Check `ls swarm/lib/roles` shows miner.lua, courier.lua, builder.lua

**Expected Output:**

```
=== Swarm v4.0 Deployment ===
Target directory: swarm

Loaded manifest with 16 files

[OK] puppetmaster.lua
[OK] lib/roles/miner.lua
...
Deployed: 16 files
```

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 2. Worker Installation

### Turtle 1 Setup

- [ ] On turtle: `cd swarm`
- [ ] Run `install.lua`
- [ ] Confirm installation (press 'y')
- [ ] Confirm reboot (press 'y')
- [ ] Turtle reboots automatically
- [ ] After reboot, verify `worker.lua` is running
- [ ] Check `ls` shows:
  - [ ] `worker.lua`
  - [ ] `startup.lua`
  - [ ] `lib/` directory
  - [ ] `backups/` directory

**Expected Output:**

```
=== Turtle Worker Setup (v4.0) ===
Installing...
  [OK] Created startup.lua
  [OK] Created worker.lua
  [OK] Copied libraries
Ready to reboot! (y/n)
```

### Turtle 2 & 3 Setup

- [ ] Repeat installation on 2 more turtles
- [ ] Note turtle IDs: #_****, #****_, #_____
- [ ] All turtles should be running worker.lua after reboot

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 3. Puppetmaster Basic Functions

### Startup

- [ ] On control computer: `cd swarm`
- [ ] Run `puppetmaster.lua`
- [ ] Verify multishell tabs created (Menu | Response Log)
- [ ] Menu displays options 1-10
- [ ] Response Log tab shows timestamp header

**Expected Output:**

```
=== TURTLE SWARM CONTROL v4.0 ===
[Channels: CMD=100 REPLY=101 VIEW=102]

1. Ping all turtles
2. Check status
...
9. Role Management
```

### Option 1: Ping All Turtles

- [ ] Select option 1
- [ ] Switch to Response Log tab
- [ ] Verify all 3 turtles respond with "Pong"
- [ ] Timestamp shown for each response
- [ ] Turtle IDs displayed correctly

**Expected Output (Response Log):**

```
[10:23:45] #5: Pong! Worker v4.0
[10:23:45] #7: Pong! Worker v4.0
[10:23:45] #12: Pong! Worker v4.0
```

### Option 2: Check Status

- [ ] Select option 2
- [ ] Switch to Response Log tab
- [ ] Verify all turtles report:
  - [ ] Fuel level (number or "unlimited")
  - [ ] GPS position (X, Y, Z coordinates)
  - [ ] Version (4.0)

**Expected Output (Response Log):**

```
[10:24:01] #5: Fuel: 5000 | Pos: X:100 Y:64 Z:200
[10:24:01] #7: Fuel: 4823 | Pos: X:102 Y:64 Z:198
[10:24:01] #12: Fuel: unlimited | Pos: X:98 Y:65 Z:203
```

### Option 3: Get Version

- [ ] Select option 3
- [ ] Verify all turtles report "Version: 4.0"

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 4. Role System - Core Functions

### Option 9: Role Management Menu

- [ ] Select option 9 from main menu
- [ ] Verify Role Management submenu appears with 8 options
- [ ] Options include:
  1. List available roles
  2. Assign role to turtle
  3. Assign to all turtles
  4. Reassign role group
  5. Get role info
  6. Set role config
  7. Clear role
  8. Send role command

### List Available Roles

- [ ] Select option 1 (List available roles)
- [ ] Verify 6 roles displayed:
  - [ ] worker - Base Worker
  - [ ] miner - Miner
  - [ ] courier - Courier
  - [ ] builder - Builder
  - [ ] farmer - Farmer
  - [ ] lumberjack - Lumberjack

### Assign Role to Turtle

- [ ] Select option 2 (Assign role to turtle)
- [ ] Enter turtle ID: (first turtle ID)
- [ ] Enter role ID: `miner`
- [ ] Configure now? Enter `y`
- [ ] Enter homeChest: `{x=<X>,y=<Y>,z=<Z>}` (use test coordinates)
- [ ] Enter fuelChest: `{x=<X>,y=<Y>,z=<Z>}` (use test coordinates)
- [ ] Enter keepCobblestone: `false`
- [ ] Switch to Response Log
- [ ] Verify turtle confirms role assignment

**Expected Output (Response Log):**

```
[10:25:15] #5: Role assigned: miner
[10:25:16] #5: Config saved: homeChest, fuelChest, keepCobblestone
```

### Get Role Info

- [ ] Select option 5 (Get role info)
- [ ] Enter turtle ID with role assigned
- [ ] Verify response shows:
  - [ ] Role: miner
  - [ ] Role Name: Miner
  - [ ] Config fields with values

**Expected Output (Response Log):**

```
[10:26:01] #5: Role: miner (Miner)
           Config: homeChest={x=100,y=64,z=200}
                   fuelChest={x=100,y=64,z=202}
                   keepCobblestone=false
```

### Assign Different Roles to Other Turtles

- [ ] Assign turtle 2 as `courier`
  - [ ] Configure pickupChest
  - [ ] Configure deliveryChest
  - [ ] Configure fuelChest
- [ ] Assign turtle 3 as `builder`
  - [ ] Configure materialChest
  - [ ] Configure fuelChest

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 5. Role-Specific Commands

### Miner Role Commands

#### Test: mineShaft

- [ ] Select option 8 (Send role command)
- [ ] Target turtle: (miner turtle ID)
- [ ] Role command: `mineShaft`
- [ ] Arguments: `5`
- [ ] Observe turtle mine down 5 blocks
- [ ] Verify status messages in Response Log
- [ ] Turtle returns to starting position

**Expected Behavior:**

- Turtle digs down 5 blocks
- Reports progress
- Returns to surface

#### Test: returnHome

- [ ] Place items in turtle inventory
- [ ] Send role command: `returnHome`
- [ ] Observe turtle navigate to homeChest
- [ ] Verify items deposited in chest
- [ ] Turtle reports completion

**Expected Output (Response Log):**

```
[10:30:15] #5: Navigating to home chest...
[10:30:45] #5: Depositing items...
[10:30:47] #5: Returned home, items deposited
```

#### Test: getFuel

- [ ] Place fuel in fuel chest
- [ ] Reduce turtle fuel to below 1000
- [ ] Send role command: `getFuel`
- [ ] Observe turtle navigate to fuelChest
- [ ] Verify turtle refuels
- [ ] Check new fuel level

### Courier Role Commands

#### Test: pickup

- [ ] Place items in pickup chest
- [ ] Send role command to courier: `pickup`
- [ ] Observe turtle navigate to pickupChest
- [ ] Verify items collected from chest
- [ ] Turtle reports success

#### Test: deliver

- [ ] Send role command: `deliver`
- [ ] Observe turtle navigate to deliveryChest
- [ ] Verify items deposited
- [ ] Turtle reports completion

#### Test: runCycle

- [ ] Place items in pickup chest
- [ ] Send role command: `runCycle`
- [ ] Arguments: `3`
- [ ] Observe 3 pickup→deliver cycles
- [ ] Verify 3 deliveries completed

### Builder Role Commands

#### Test: buildWall

- [ ] Place blocks in turtle inventory or materialChest
- [ ] Send role command: `buildWall`
- [ ] Arguments: `5 3` (length height)
- [ ] Observe wall construction
- [ ] Verify wall is 5 blocks long, 3 blocks high

#### Test: buildFloor

- [ ] Send role command: `buildFloor`
- [ ] Arguments: `4 4` (width length)
- [ ] Observe floor construction
- [ ] Verify 4x4 floor created

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 6. Role Targeting

### Target Specific Role Group

- [ ] Place all 3 turtles with different roles
- [ ] From main menu, select option 4 (Custom command)
- [ ] Target ID: `role:miner` (or use role management option 8)
- [ ] Command: `status`
- [ ] Verify ONLY miner turtle responds
- [ ] Repeat with `role:courier`
- [ ] Verify ONLY courier turtle responds

### Assign All Turtles to Same Role

- [ ] Role Management → Option 3 (Assign to all)
- [ ] Role ID: `worker`
- [ ] Verify all turtles respond confirming role change
- [ ] Send command to `role:worker`
- [ ] Verify all turtles respond

### Reassign Role Group

- [ ] Assign all turtles back to different roles
- [ ] Role Management → Option 4 (Reassign role group)
- [ ] Target role: `worker`
- [ ] New role: `miner`
- [ ] Verify all worker turtles become miners

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 7. Fleet Manager

### Startup

- [ ] Run `fleet_manager.lua`
- [ ] Verify menu displays with 9 options
- [ ] Option 5 is "Role-based command"
- [ ] Option 9 is "Show fleet by role"

### Option 1: Ping Fleet

- [ ] Select option 1
- [ ] Verify all turtles respond
- [ ] Count displayed correctly

### Option 2: Status Report

- [ ] Select option 2
- [ ] Verify report shows all turtles with:
  - [ ] ID
  - [ ] Role
  - [ ] Fuel level
  - [ ] Position

**Expected Output:**

```
=== Fleet Status Report ===
Total turtles: 3

#5  [Miner]     Fuel: 4823  Pos: X:100 Y:64 Z:200
#7  [Courier]   Fuel: 5000  Pos: X:102 Y:64 Z:198
#12 [Builder]   Fuel: 3500  Pos: X:98 Y:65 Z:203
```

### Option 5: Role-Based Command

- [ ] Select option 5
- [ ] Target role: `miner`
- [ ] Command: `status`
- [ ] Verify only miners respond

### Option 9: Show Fleet by Role

- [ ] Select option 9
- [ ] Verify turtles grouped by role:
  - [ ] Miners section
  - [ ] Couriers section
  - [ ] Builders section
  - [ ] Count per role displayed

**Expected Output:**

```
=== Fleet By Role ===

[Miner] (1 turtle)
  #5 - Fuel: 4823 - X:100 Y:64 Z:200

[Courier] (1 turtle)
  #7 - Fuel: 5000 - X:102 Y:64 Z:198

[Builder] (1 turtle)
  #12 - Fuel: 3500 - X:98 Y:65 Z:203
```

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 8. Monitor Display

### Startup

- [ ] Attach monitor to advanced computer
- [ ] Run `monitor.lua`
- [ ] Verify multishell tabs created
- [ ] Monitor displays "FLEET MONITOR" header
- [ ] Status bar shows "ACTIVE: 0"

### Display Updates

- [ ] Send ping or status command from puppetmaster
- [ ] Observe monitor update in real-time
- [ ] Verify columns displayed:
  - [ ] ID column
  - [ ] ROLE column
  - [ ] POSITION column

### Role Color Coding

- [ ] Verify each turtle row has colored background:
  - [ ] Miner: Brown background
  - [ ] Courier: Cyan background
  - [ ] Builder: Orange background
  - [ ] Worker (if any): Light gray background

### Role Names Displayed

- [ ] Verify ROLE column shows role names:
  - [ ] "Miner" for miner role
  - [ ] "Courier" for courier role
  - [ ] "Builder" for builder role
  - [ ] "Worker" for no role or base worker

**Expected Display:**

```
╔════════════════════════════════════╗
║       FLEET MONITOR v4.0          ║
╠════════════════════════════════════╣
║ ACTIVE: 3                          ║
╠════════════════════════════════════╣
║ ID  ROLE      POSITION             ║
╠════════════════════════════════════╣
║ #5  Miner     X:100 Y:64 Z:200     ║  <- Brown
║ #7  Courier   X:102 Y:64 Z:198     ║  <- Cyan
║ #12 Builder   X:98 Y:65 Z:203      ║  <- Orange
╚════════════════════════════════════╝
```

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 9. Remote Shell

### Create Shell Session

- [ ] Puppetmaster → Option 6 (Remote shell)
- [ ] Enter turtle ID
- [ ] Verify shell prompt appears
- [ ] Prompt shows turtle working directory

### Basic Commands

- [ ] Test `ls` command
- [ ] Test `pwd` command
- [ ] Test `cd lib` command
- [ ] Test `cd ..` command

### Execute Lua

- [ ] Enter `lua` command
- [ ] Execute simple Lua: `print("test")`
- [ ] Exit lua shell

### Close Session

- [ ] Enter `exit` or use close shell option
- [ ] Verify session closed
- [ ] Return to main menu

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 10. Program Provisioning

### Import Program

- [ ] Puppetmaster → Option "I" (Import)
- [ ] Drag `programs/hello.lua` onto puppetmaster
- [ ] Verify file saved to programs/
- [ ] Provision? Enter `y`
- [ ] Verify all turtles receive program
- [ ] Check turtles have `programs/hello.lua`

### Run Provisioned Program

- [ ] Puppetmaster → Option 4 (Custom command)
- [ ] Target: specific turtle
- [ ] Program: `programs/hello`
- [ ] Verify turtle executes program
- [ ] Check response in Response Log

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 11. Error Handling & Edge Cases

### Invalid Role Assignment

- [ ] Try to assign non-existent role: `invalid_role`
- [ ] Verify error message
- [ ] Turtle not affected

### Missing GPS

- [ ] Disable GPS (break GPS computers temporarily)
- [ ] Try miner returnHome command
- [ ] Verify appropriate error message
- [ ] Re-enable GPS, test again

### Low Fuel Navigation

- [ ] Reduce turtle fuel to very low (<50)
- [ ] Try navigation command
- [ ] Verify fuel warning or auto-refuel

### Invalid Config Format

- [ ] Try setting role config with wrong format
- [ ] Example: `setRoleConfig homeChest invalid`
- [ ] Verify error message about format
- [ ] Correct format: `{x=?,y=?,z=?}`

### Role Command on Non-Role Turtle

- [ ] Clear role from turtle
- [ ] Try sending role command
- [ ] Verify error: "No role assigned"

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 12. Persistence & Recovery

### Role Config Persistence

- [ ] Assign role to turtle with full config
- [ ] Reboot turtle
- [ ] After reboot, check role info
- [ ] Verify role and config preserved

### Recovery Mode

- [ ] On turtle, create file: `.recovery_mode`
- [ ] Reboot turtle
- [ ] Verify worker does NOT auto-start
- [ ] Delete `.recovery_mode` file
- [ ] Reboot again
- [ ] Verify worker auto-starts

### Backup System

- [ ] Check turtle `backups/` directory
- [ ] Verify startup backups exist
- [ ] Try restoring from backup if needed

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 13. Backward Compatibility

### v3.0 Commands Still Work

- [ ] Send `ping` command (v3.0 style)
- [ ] Send `status` command (v3.0 style)
- [ ] Send `reboot` command (v3.0 style)
- [ ] All commands work without role system

### Turtles Without Roles

- [ ] Clear role from turtle
- [ ] Send regular commands
- [ ] Verify turtle functions as "base worker"
- [ ] All core functionality works

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## 14. Performance & Stress Tests

### Multiple Simultaneous Commands

- [ ] Send status to all turtles
- [ ] Immediately send another command
- [ ] Verify all responses received
- [ ] No messages lost

### Large Fleet (if available)

- [ ] Test with 10+ turtles if possible
- [ ] Monitor performance
- [ ] Check response times
- [ ] Verify all turtles respond

### Monitor Refresh Rate

- [ ] Send status commands every 3 seconds
- [ ] Observe monitor updates
- [ ] Verify no display glitches
- [ ] Timestamp updates correctly

**Result:** ✅ Pass / ❌ Fail  
**Notes:** ________________________________________________

---

## Test Summary

**Date:** _______________  
**Tester:** _______________  
**Version:** 4.0  

### Results Overview

| Category | Status | Notes |
|----------|--------|-------|
| Build & Deployment | ⬜ Pass / ⬜ Fail | |
| Worker Installation | ⬜ Pass / ⬜ Fail | |
| Puppetmaster Basic | ⬜ Pass / ⬜ Fail | |
| Role System Core | ⬜ Pass / ⬜ Fail | |
| Role Commands | ⬜ Pass / ⬜ Fail | |
| Role Targeting | ⬜ Pass / ⬜ Fail | |
| Fleet Manager | ⬜ Pass / ⬜ Fail | |
| Monitor Display | ⬜ Pass / ⬜ Fail | |
| Remote Shell | ⬜ Pass / ⬜ Fail | |
| Program Provisioning | ⬜ Pass / ⬜ Fail | |
| Error Handling | ⬜ Pass / ⬜ Fail | |
| Persistence | ⬜ Pass / ⬜ Fail | |
| Backward Compatibility | ⬜ Pass / ⬜ Fail | |
| Performance | ⬜ Pass / ⬜ Fail | |

### Critical Issues Found

```
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________
```

### Minor Issues Found

```
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________
```

### Recommendations

```
___________________________________________________
___________________________________________________
___________________________________________________
```

### Overall Assessment

- [ ] ✅ Ready for Production
- [ ] ⚠️ Ready with Known Issues
- [ ] ❌ Not Ready - Critical Bugs

**Signature:** _______________  
**Date:** _______________

---

## Quick Test (Minimal Validation)

For rapid verification, test these critical paths:

1. **Build**: Run `build.ps1`, verify 16 files created
2. **Deploy**: Run `deploy.lua`, verify directory structure
3. **Install**: Run `install.lua` on 1 turtle, verify reboot
4. **Ping**: Run puppetmaster, ping turtle, verify response
5. **Role Assign**: Assign miner role with config
6. **Role Command**: Send `mineShaft 3`, verify execution
7. **Monitor**: Run monitor, verify role display and colors
8. **Persistence**: Reboot turtle, verify role preserved

**Quick Test Time:** ~15-20 minutes  
**Full Test Time:** ~2-3 hours

---

_Swarm v4.0 Testing Checklist - Last Updated: 2025-10-28_
