#!/bin/bash
# Bash Build Script for Swarm Deployment
# Flattens swarm directory structure for ComputerCraft import

DEPLOYMENT_NAME="${1:-swarm_$(date +%Y%m%d_%H%M%S)}"
SWARM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$SWARM_ROOT/deployment/$DEPLOYMENT_NAME"
MANIFEST_FILE="$DEPLOYMENT_DIR/manifest.txt"

echo "=== Swarm v4.0 Build Script ==="
echo "Deployment Name: $DEPLOYMENT_NAME"
echo ""

# Create deployment directory
if [ -d "$DEPLOYMENT_DIR" ]; then
    echo "Cleaning existing deployment directory..."
    rm -rf "$DEPLOYMENT_DIR"
fi
mkdir -p "$DEPLOYMENT_DIR"

# Files to include (relative to swarm root)
FILES_TO_DEPLOY=(
    # Core programs
    "puppetmaster.lua"
    "worker.lua"
    "install.lua"
    "monitor.lua"
    "fleet_manager.lua"
    "distribute.lua"
    
    # Libraries
    "lib/swarm_common.lua"
    "lib/swarm_worker_lib.lua"
    "lib/swarm_ui.lua"
    "lib/roles.lua"
    
    # Role libraries
    "lib/roles/miner.lua"
    "lib/roles/courier.lua"
    "lib/roles/builder.lua"
    
    # Programs
    "programs/digDown.lua"
    "programs/stairs.lua"
    "programs/hello.lua"
)

# Create manifest
> "$MANIFEST_FILE"

echo "Flattening directory structure..."

for RELATIVE_PATH in "${FILES_TO_DEPLOY[@]}"; do
    SOURCE_FILE="$SWARM_ROOT/$RELATIVE_PATH"
    
    if [ ! -f "$SOURCE_FILE" ]; then
        echo "  [SKIP] $RELATIVE_PATH (not found)"
        continue
    fi
    
    # Create flattened filename: replace / with __
    FLAT_NAME="${RELATIVE_PATH//\//__}"
    DEST_FILE="$DEPLOYMENT_DIR/$FLAT_NAME"
    
    # Copy file
    cp "$SOURCE_FILE" "$DEST_FILE"
    
    # Add to manifest: flatname|originalpath
    echo "$FLAT_NAME|$RELATIVE_PATH" >> "$MANIFEST_FILE"
    
    echo "  [OK] $RELATIVE_PATH -> $FLAT_NAME"
done

echo ""
echo "Creating deployment script..."

# Create deploy.lua script
cat > "$DEPLOYMENT_DIR/deploy.lua" << 'EOF'
-- Swarm Deployment Script
-- Reconstructs directory structure from flattened deployment
-- Usage: deploy [target_dir]

local args = {...}
local targetDir = args[1] or "swarm"

print("=== Swarm v4.0 Deployment ===")
print("Target directory: " .. targetDir)
print("")

-- Read manifest
if not fs.exists("manifest.txt") then
    error("manifest.txt not found! Run this script in the deployment directory.")
end

local manifest = {}
local file = fs.open("manifest.txt", "r")
if not file then
    error("Could not open manifest.txt")
end

local line = file.readLine()
while line do
    local flatName, originalPath = line:match("^(.+)|(.+)$")
    if flatName and originalPath then
        manifest[flatName] = originalPath
    end
    line = file.readLine()
end
file.close()

print("Loaded manifest with " .. #manifest .. " files")
print("")

-- Create target directory
if fs.exists(targetDir) then
    print("Warning: " .. targetDir .. " already exists")
    print("Continue? (y/n)")
    local response = read()
    if response:lower() ~= "y" then
        print("Deployment cancelled")
        return
    end
    print("Removing existing directory...")
    fs.delete(targetDir)
end

fs.makeDir(targetDir)

-- Deploy files
local deployed = 0
local failed = 0

for flatName, originalPath in pairs(manifest) do
    local sourcePath = fs.combine(fs.getDir(shell.getRunningProgram()), flatName)
    local targetPath = fs.combine(targetDir, originalPath)
    
    if not fs.exists(sourcePath) then
        print("[SKIP] " .. flatName .. " (not found)")
        failed = failed + 1
    else
        -- Create parent directories
        local parentDir = fs.getDir(targetPath)
        if parentDir ~= "" and not fs.exists(fs.combine(targetDir, parentDir)) then
            fs.makeDir(fs.combine(targetDir, parentDir))
        end
        
        -- Copy file
        if fs.exists(targetPath) then
            fs.delete(targetPath)
        end
        fs.copy(sourcePath, targetPath)
        
        print("[OK] " .. originalPath)
        deployed = deployed + 1
    end
end

print("")
print("=== Deployment Complete ===")
print("Deployed: " .. deployed .. " files")
if failed > 0 then
    print("Failed: " .. failed .. " files")
end
print("")
print("Next steps:")
print("1. cd " .. targetDir)
print("2. Run 'install.lua' on turtles")
print("3. Run 'puppetmaster.lua' on advanced pocket computer")
print("4. Run 'monitor.lua' on advanced computer with monitor")
EOF

echo "  [OK] Created deploy.lua"

# Create README
cat > "$DEPLOYMENT_DIR/README.txt" << EOF
# Swarm Deployment Package: $DEPLOYMENT_NAME

This package contains a flattened version of the Swarm v4.0 system for easy import to ComputerCraft.

## Files Included

- $(wc -l < "$MANIFEST_FILE") Lua files from the swarm system
- manifest.txt - File mapping for reconstruction
- deploy.lua - Deployment script

## Deployment Instructions

### Method 1: Pastebin (Recommended for Small Deployments)

1. Upload deployment directory to pastebin or file sharing service
2. On ComputerCraft computer: \`pastebin get <code> deploy.lua\`
3. Run: \`deploy.lua\`
4. Follow prompts

### Method 2: Disk Transfer (Recommended for Full Deployment)

1. Copy entire deployment directory to a ComputerCraft disk
2. On ComputerCraft computer: \`cp disk/* .\`
3. Run: \`deploy.lua\`
4. Specify target directory (default: "swarm")

### Method 3: Import via Puppetmaster (Update Existing)

1. Drag individual \`__\` files onto running puppetmaster
2. Manually reconstruct directory structure
3. Use for updating specific files only

## What deploy.lua Does

1. Reads manifest.txt to understand directory structure
2. Creates target directory (default: "swarm")
3. Reconstructs all subdirectories (lib, lib/roles, programs)
4. Copies files to their original locations
5. Reports deployment status

## After Deployment

Navigate to the deployed directory:
\`cd swarm\`

Then proceed with normal swarm setup:
- Turtles: Run \`install.lua\`
- Control: Run \`puppetmaster.lua\` on Advanced Pocket Computer
- Monitor: Run \`monitor.lua\` on Advanced Computer with attached monitor

## Files Manifest

$(while IFS='|' read -r flat original; do echo "- $original"; done < "$MANIFEST_FILE")

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Swarm Version: 4.0
EOF

echo "  [OK] Created README.txt"

echo ""
echo "=== Build Complete ==="
echo "Deployment package: deployment/$DEPLOYMENT_NAME"
echo "Files: $(wc -l < "$MANIFEST_FILE")"
echo ""
echo "Next steps:"
echo "1. Copy deployment/$DEPLOYMENT_NAME to ComputerCraft disk"
echo "2. On CC computer: cd disk/$DEPLOYMENT_NAME"
echo "3. Run: deploy.lua"
echo ""
