# Wireless Provisioning System

## Overview

The wireless provisioning system allows you to send complete file sets to turtles over wireless modem, bypassing ComputerCraft's 122KB disk space limitation.

## Components

### provision_client.lua (~200 lines)

- Lightweight receiver that runs on turtles
- Listens for files sent wirelessly
- Reassembles chunked file transfers
- Small enough to easily fit on disk for initial transfer

### provision_server.lua

- Runs on control computer (Advanced Computer or Pocket Computer)
- Sends complete file sets wirelessly to turtles
- Three predefined file sets: worker, minimal, libraries_only
- Handles chunking and reliability

## Workflow

### Initial Setup (One-Time)

1. **Get provision_client.lua on turtle**

   ```text
   # On control computer
   - Copy provision_client.lua to disk
   
   # On turtle
   - Insert disk
   - Run: cp disk/provision_client.lua provision_client.lua
   ```

2. **Start provision client on turtle**

   ```text
   provision_client
   ```

   - Shows "Provision client ready"
   - Waits for server connection

### Provisioning Files

1. **On control computer, run provision_server**

   ```text
   provision_server
   ```

2. **Discover clients (Option 1)**
   - Finds all turtles running provision_client
   - Displays turtle IDs

3. **Provision turtle (Option 2)**
   - Enter turtle ID
   - Choose file set:
     - **worker** - Full package (13 files: worker, install, all libs, role libs, programs)
     - **minimal** - Core only (6 files: worker, install, core libs)
     - **libraries_only** - Just libraries (7 files: all libs including roles)

4. **Files transfer wirelessly**
   - Progress shown on both computers
   - 4KB chunks for reliability
   - Automatic verification

5. **Optional: Auto-install**
   - Server can trigger install.lua after transfer
   - Or manually run `install` on turtle

## File Sets

### worker (Recommended for New Turtles)

- worker.lua
- install.lua
- lib/swarm_common.lua
- lib/swarm_worker_lib.lua
- lib/swarm_ui.lua
- lib/roles.lua
- lib/roles/miner.lua
- lib/roles/courier.lua
- lib/roles/builder.lua
- programs/digDown.lua
- programs/stairs.lua
- programs/hello.lua

**Total: 13 files, ~50-60KB** (too large for disk!)

### minimal (Basic Setup)

- worker.lua
- install.lua
- lib/swarm_common.lua
- lib/swarm_worker_lib.lua
- lib/swarm_ui.lua
- lib/roles.lua

Total: 6 files, ~30KB

### libraries_only (For Updates)

- lib/swarm_common.lua
- lib/swarm_worker_lib.lua
- lib/swarm_ui.lua
- lib/roles.lua
- lib/roles/miner.lua
- lib/roles/courier.lua
- lib/roles/builder.lua

Total: 7 files, ~25KB

## Advantages

✅ **No disk space limits** - Send complete worker package wirelessly  
✅ **Fast updates** - Update all turtles without disk swapping  
✅ **Reliable** - Chunked transfer with verification  
✅ **Easy setup** - Only need provision_client.lua on disk initially  
✅ **Scalable** - Provision multiple turtles quickly  

## Troubleshooting

"No provision clients found"

- Verify turtle is running provision_client.lua
- Check wireless modem is equipped on both computers
- Ensure turtles are in wireless range

"File transfer failed"

- Check turtle has enough disk space
- Verify file exists on server
- Try again - may be temporary wireless interference

"Missing chunk"

- Wireless interference during transfer
- Restart transfer - client will overwrite partial file

Turtle out of space during transfer

- Delete old files: `rm oldfile.lua`
- Check disk space: `df`
- Use minimal file set instead of worker

## Comparison: Provision vs Disk

| Method | Disk Transfer | Wireless Provision |
|--------|---------------|-------------------|
| Size limit | 122KB total | No limit |
| Initial setup | Full worker package | Just provision_client |
| Speed | Manual, slow | Automatic, fast |
| Updates | Re-copy entire disk | Send individual files |
| Scaling | One turtle at a time | Multiple turtles quickly |
| Best for | Single turtle setup | Fleet deployment |

## Example Session

```text
# On turtle #5
> provision_client
=== Provision Client v1.0 ===
Computer ID: 5
Listening on channels 100/101

Waiting for provisioning server...

# On control computer
> provision_server
=== Provision Server v1.0 ===
[Menu] Choose option: 1

Discovering provision clients...
  Found: Computer #5 - Provision client ready
Discovery complete: 1 clients found [OK]

[Menu] Choose option: 2

Enter turtle ID to provision: 5

Available file sets:
1. worker - Full worker package (13 files)
2. minimal - Core files only (6 files)
3. libraries_only - Just libraries (7 files)

Choose file set: worker

Provisioning turtle #5 with worker package
Files to send: 13

  Sending: worker.lua (15234 bytes, 4 chunks)
  [OK] worker.lua saved successfully
  Sending: install.lua (8765 bytes, 3 chunks)
  [OK] install.lua saved successfully
  [... 11 more files ...]

=== Provisioning Complete ===
Success: 13 files
Failed: 0 files

Run install.lua on turtle #5? (y/n): y
Triggering installation...
Installation triggered on turtle #5 [INFO]

# Back on turtle #5
Receiving: worker.lua (15234 bytes, 4 chunks)
  Progress: 4/4
  Reassembling file...
[OK] Saved: worker.lua
[... receives all files ...]

Running installation...
[Installation proceeds automatically...]
```

## Integration with Build System

The build script now includes provision files in deployment packages:

**Server package**: Includes `provision_server.lua` (8 files total)  
**Worker package**: Includes `provision_client.lua` (13 files total)

This allows you to:

1. Deploy server package to control computer
2. Deploy **only provision_client.lua** to turtle via disk (tiny file!)
3. Use provision_server to wirelessly send remaining files
4. Never worry about disk space limits again

---
**Version:** 1.0  
**Updated:** 2025-10-28
