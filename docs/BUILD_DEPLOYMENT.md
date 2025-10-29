# Swarm Build & Deployment Guide

This guide explains how to use the build scripts to package and deploy the Swarm system to ComputerCraft.

## Overview

The build system flattens the Swarm directory structure into a single directory with a deployment script that reconstructs the original structure on the ComputerCraft machine.

**Why flatten?**

- Easier to transfer via disk or pastebin
- Single import operation instead of recreating directory structure manually
- Automated reconstruction ensures correct file placement

## Build Scripts

### PowerShell (Windows)

```powershell
.\build.ps1 [deployment_name]
```

### Bash (Linux/Mac)

```bash
./build.sh [deployment_name]
```

**Parameters:**

- `deployment_name` (optional): Name for this deployment. Default: `swarm_YYYYMMDD_HHMMSS`

**Output:**

- Creates `deployment/{deployment_name}/` directory containing:
  - Flattened `.lua` files (e.g., `lib__roles__miner.lua`)
  - `manifest.txt` - File mapping (flatname|originalpath)
  - `deploy.lua` - Deployment script for ComputerCraft
  - `README.txt` - Deployment instructions

## What Gets Included

The build scripts package these files:

**Core Programs:**

- puppetmaster.lua
- worker.lua
- install.lua
- monitor.lua
- fleet_manager.lua
- distribute.lua

**Libraries:**

- lib/swarm_common.lua
- lib/swarm_worker_lib.lua
- lib/swarm_ui.lua
- lib/roles.lua

**Role Libraries:**

- lib/roles/miner.lua
- lib/roles/courier.lua
- lib/roles/builder.lua

**Programs:**

- programs/digDown.lua
- programs/stairs.lua
- programs/hello.lua

## Deployment Methods

### Method 1: Disk Transfer (Recommended)

**Best for:** Full system deployment, initial setup

1. Run build script:

   ```powershell
   .\build.ps1 production
   ```

2. Copy `deployment/production/` to ComputerCraft disk drive:
   - Place disk in real computer's disk drive
   - Copy folder to disk
   - OR use in-game disk drive with `/computercraft/computer/{id}/disk/`

3. In ComputerCraft, insert disk and run:

   ```lua
   cd disk/production
   deploy.lua
   ```

4. Follow prompts (default target: "swarm")

5. After deployment:

   ```lua
   cd swarm
   -- Proceed with normal setup
   ```

### Method 2: Pastebin (Individual Files)

**Best for:** Quick updates, single file changes

1. Run build script:

   ```powershell
   .\build.ps1 update
   ```

2. Upload files to pastebin:
   - Upload `deploy.lua`
   - Upload `manifest.txt`
   - Upload needed `.lua` files

3. In ComputerCraft:

   ```lua
   pastebin get <deploy_code> deploy.lua
   pastebin get <manifest_code> manifest.txt
   pastebin get <file_code> lib__roles__miner.lua
   -- etc...
   deploy.lua
   ```

### Method 3: HTTP Download (Advanced)

**Best for:** Server deployments, automated setups

1. Host `deployment/{name}/` on web server

2. In ComputerCraft (requires HTTP API):

   ```lua
   -- Download deploy script
   shell.run("wget", "http://yourserver.com/deploy.lua", "deploy.lua")
   shell.run("wget", "http://yourserver.com/manifest.txt", "manifest.txt")
   
   -- Download all files (script this based on manifest)
   -- Then run:
   shell.run("deploy.lua")
   ```

## Deployment Script Usage

The `deploy.lua` script reconstructs the directory structure:

### Basic Usage

```lua
deploy.lua [target_directory]
```

**Arguments:**

- `target_directory` (optional): Where to deploy swarm. Default: "swarm"

### Examples

Deploy to default "swarm" directory:

```lua
deploy.lua
```

Deploy to custom location:

```lua
deploy.lua my_swarm_v4
```

Deploy to root (not recommended):

```lua
deploy.lua .
```

### What It Does

1. **Reads manifest.txt**: Understands original directory structure
2. **Checks target**: Warns if directory exists, prompts for confirmation
3. **Creates directories**: lib/, lib/roles/, programs/
4. **Copies files**: Each flattened file to its original location
5. **Reports status**: Shows deployed/failed counts

### Example Output

```text
=== Swarm v4.0 Deployment ===
Target directory: swarm

Loaded manifest with 16 files

[OK] puppetmaster.lua
[OK] worker.lua
[OK] install.lua
[OK] monitor.lua
[OK] fleet_manager.lua
[OK] distribute.lua
[OK] lib/swarm_common.lua
[OK] lib/swarm_worker_lib.lua
[OK] lib/swarm_ui.lua
[OK] lib/roles.lua
[OK] lib/roles/miner.lua
[OK] lib/roles/courier.lua
[OK] lib/roles/builder.lua
[OK] programs/digDown.lua
[OK] programs/stairs.lua
[OK] programs/hello.lua

=== Deployment Complete ===
Deployed: 16 files
```

## Updating Existing Installation

To update an existing swarm installation:

### Option 1: Full Redeployment

```lua
cd /
deploy.lua swarm  -- Will prompt to overwrite
```

### Option 2: Selective Update

1. Build deployment package
2. Manually copy specific flattened files
3. Use puppetmaster's import function to deploy individual files

### Option 3: Git-Style Update (Manual)

1. Build new deployment
2. Deploy to temporary directory: `deploy.lua swarm_new`
3. Compare and copy changed files
4. Delete temporary directory

## Customizing Build

To include additional files, edit the build script:

**PowerShell (build.ps1):**

```powershell
$FilesToDeploy = @(
    # ... existing files ...
    "programs/my_custom_program.lua",
    "lib/roles/farmer.lua"  # When implemented
)
```

**Bash (build.sh):**

```bash
FILES_TO_DEPLOY=(
    # ... existing files ...
    "programs/my_custom_program.lua"
    "lib/roles/farmer.lua"  # When implemented
)
```

## Troubleshooting

### "manifest.txt not found"

- Ensure you're running `deploy.lua` from the deployment directory
- Check that `manifest.txt` was copied/downloaded correctly

### "No such file or directory" errors

- Verify all flattened files are present in deployment directory
- Check disk space on ComputerCraft computer
- Ensure files were copied correctly (not truncated)

### Files not in correct locations

- Check manifest.txt format: each line should be `flatname|originalpath`
- Verify no special characters in filenames
- Ensure original paths use forward slashes: `lib/roles/miner.lua`

### Overwrite prompts

- Deployment warns before overwriting existing directory
- Type 'y' to confirm, 'n' to cancel
- Delete target directory manually if needed: `rm -rf swarm`

## Best Practices

1. **Name deployments meaningfully:**

   ```powershell
   .\build.ps1 v4.0_stable
   .\build.ps1 v4.1_beta
   .\build.ps1 hotfix_miner_2025-10-28
   ```

2. **Keep deployment history:**
   - Deployment packages are gitignored by default
   - Consider backing up stable releases
   - Document what changed between deployments

3. **Test before deploying to production turtles:**
   - Deploy to test directory first
   - Verify all files present
   - Test on single turtle before fleet-wide update

4. **Use version comments:**
   - Update version strings in lua files before building
   - Include deployment date in comments
   - Document breaking changes

## Integration with Swarm Workflow

### Initial Setup

1. Build deployment package
2. Transfer to ComputerCraft
3. Run `deploy.lua`
4. Run `install.lua` on turtles
5. Run `puppetmaster.lua` on control computer

### Updates

1. Make changes to source files
2. Build new deployment
3. Transfer to ComputerCraft
4. Deploy to temporary location
5. Test changes
6. Redeploy to main location
7. Reboot affected turtles/computers

### Emergency Rollback

1. Keep previous deployment package
2. Redeploy previous version
3. Reboot systems
4. Investigate issues

## Files Reference

### Generated Files

**manifest.txt:**

```text
puppetmaster.lua|puppetmaster.lua
lib__roles__miner.lua|lib/roles/miner.lua
```

Format: `flatname|originalpath`

**deploy.lua:**

- Lua script for ComputerCraft
- Reconstructs directory structure
- ~90 lines, self-contained

**README.txt:**

- Deployment instructions
- File listing
- Generated timestamp

### Build Artifacts

All deployments stored in: `swarm/deployment/{name}/`

Gitignored to prevent repository bloat.

---

**Version:** 4.0  
**Last Updated:** 2025-10-28  
**Compatible with:** ComputerCraft 1.8+, CC:Tweaked
