# PowerShell Build Script for Swarm Deployment
# Flattens swarm directory structure for ComputerCraft import

param(
    [string]$DeploymentName = "swarm_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

$ErrorActionPreference = "Stop"

# Paths
$SwarmRoot = $PSScriptRoot
$DeploymentDir = Join-Path $SwarmRoot "deployment\$DeploymentName"
$ManifestFile = Join-Path $DeploymentDir "manifest.txt"

Write-Host "=== Swarm v4.0 Build Script ===" -ForegroundColor Cyan
Write-Host "Deployment Name: $DeploymentName" -ForegroundColor Yellow
Write-Host ""

# Create deployment directory
if (Test-Path $DeploymentDir) {
    Write-Host "Cleaning existing deployment directory..." -ForegroundColor Yellow
    Remove-Item -Path $DeploymentDir -Recurse -Force
}
New-Item -Path $DeploymentDir -ItemType Directory -Force | Out-Null

# Files to include (relative to swarm root)
$FilesToDeploy = @(
    # Core programs
    "puppetmaster.lua",
    "worker.lua",
    "install.lua",
    "monitor.lua",
    "fleet_manager.lua",
    "distribute.lua",
    
    # Libraries
    "lib/swarm_common.lua",
    "lib/swarm_worker_lib.lua",
    "lib/swarm_ui.lua",
    "lib/roles.lua",
    
    # Role libraries
    "lib/roles/miner.lua",
    "lib/roles/courier.lua",
    "lib/roles/builder.lua",
    
    # Programs
    "programs/digDown.lua",
    "programs/stairs.lua",
    "programs/hello.lua"
)

# Create manifest
$ManifestContent = @()

Write-Host "Flattening directory structure..." -ForegroundColor Green

foreach ($RelativePath in $FilesToDeploy) {
    $SourceFile = Join-Path $SwarmRoot $RelativePath
    
    if (-not (Test-Path $SourceFile)) {
        Write-Host "  [SKIP] $RelativePath (not found)" -ForegroundColor Yellow
        continue
    }
    
    # Create flattened filename: replace / and \ with __
    $FlatName = $RelativePath -replace '[/\\]', '__'
    $DestFile = Join-Path $DeploymentDir $FlatName
    
    # Copy file
    Copy-Item -Path $SourceFile -Destination $DestFile -Force
    
    # Add to manifest: flatname|originalpath
    $ManifestContent += "$FlatName|$RelativePath"
    
    Write-Host "  [OK] $RelativePath -> $FlatName" -ForegroundColor Gray
}

# Save manifest
$ManifestContent | Set-Content -Path $ManifestFile -Encoding UTF8

Write-Host ""
Write-Host "Creating deployment script..." -ForegroundColor Green

# Create deploy.lua script
$DeployScript = @"
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
    local flatName, originalPath = line:match("^(.+)|(.+)`$")
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
"@

$DeployScriptPath = Join-Path $DeploymentDir "deploy.lua"
$DeployScript | Set-Content -Path $DeployScriptPath -Encoding UTF8

Write-Host "  [OK] Created deploy.lua" -ForegroundColor Gray

# Create README
$ReadmeContent = @"
# Swarm Deployment Package: $DeploymentName

This package contains a flattened version of the Swarm v4.0 system for easy import to ComputerCraft.

## Files Included

- $(($ManifestContent | Measure-Object).Count) Lua files from the swarm system
- manifest.txt - File mapping for reconstruction
- deploy.lua - Deployment script

## Deployment Instructions

### Method 1: Pastebin (Recommended for Small Deployments)

1. Upload deployment directory to pastebin or file sharing service
2. On ComputerCraft computer: ``pastebin get <code> deploy.lua``
3. Run: ``deploy.lua``
4. Follow prompts

### Method 2: Disk Transfer (Recommended for Full Deployment)

1. Copy entire deployment directory to a ComputerCraft disk
2. On ComputerCraft computer: ``cp disk/* .``
3. Run: ``deploy.lua``
4. Specify target directory (default: "swarm")

### Method 3: Import via Puppetmaster (Update Existing)

1. Drag individual ``__`` files onto running puppetmaster
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
``cd swarm``

Then proceed with normal swarm setup:
- Turtles: Run ``install.lua``
- Control: Run ``puppetmaster.lua`` on Advanced Pocket Computer
- Monitor: Run ``monitor.lua`` on Advanced Computer with attached monitor

## Files Manifest

$(foreach ($line in $ManifestContent) {
    $parts = $line -split '\|'
    "- $($parts[1])"
}) -join "`n"

---
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Swarm Version: 4.0
"@

$ReadmePath = Join-Path $DeploymentDir "README.txt"
$ReadmeContent | Set-Content -Path $ReadmePath -Encoding UTF8

Write-Host "  [OK] Created README.txt" -ForegroundColor Gray

Write-Host ""
Write-Host "=== Build Complete ===" -ForegroundColor Green
Write-Host "Deployment package: deployment\$DeploymentName" -ForegroundColor Cyan
Write-Host "Files: $(($ManifestContent | Measure-Object).Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Copy deployment\$DeploymentName to ComputerCraft disk" -ForegroundColor White
Write-Host "2. On CC computer: cd disk/$DeploymentName" -ForegroundColor White
Write-Host "3. Run: deploy.lua" -ForegroundColor White
Write-Host ""
