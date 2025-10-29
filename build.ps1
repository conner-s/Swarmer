# PowerShell Build Script for Swarm Deployment
# Flattens swarm directory structure for ComputerCraft import
# Creates separate server and worker packages to fit on CC disks

param(
    [string]$DeploymentName = "swarm_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    [ValidateSet("all", "server", "provision", "worker")]
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"

# Paths
$SwarmRoot = $PSScriptRoot
$DeploymentRoot = Join-Path $SwarmRoot "deployment\$DeploymentName"

Write-Host "=== Swarm v4.0 Build Script ===" -ForegroundColor Cyan
Write-Host "Deployment Name: $DeploymentName" -ForegroundColor Yellow
Write-Host "Target: $Target" -ForegroundColor Yellow
Write-Host ""

# Define file sets for each deployment type
$ServerFiles = @(
    "puppetmaster.lua",
    "monitor.lua",
    "fleet_manager.lua",
    "lib/swarm_common.lua",
    "lib/swarm_ui.lua",
    "lib/roles.lua"
)

$ProvisionFiles = @(
    # Server control files
    "provision_server.lua",
    "distribute.lua",
    
    # Server libraries
    "lib/swarm_common.lua",
    "lib/swarm_ui.lua",
    "lib/roles.lua",
    
    # Worker files (to provision to turtles)
    "worker.lua",
    "install.lua",
    "lib/swarm_worker_lib.lua",
    "lib/roles/miner.lua",
    "lib/roles/courier.lua",
    "lib/roles/builder.lua",
    "programs/digDown.lua",
    "programs/stairs.lua",
    "programs/hello.lua"
)

$WorkerFiles = @(
    "provision_client.lua",
    "worker.lua",
    "install.lua",
    "lib/swarm_common.lua",
    "lib/swarm_worker_lib.lua",
    "lib/swarm_ui.lua",
    "lib/roles.lua",
    "lib/roles/miner.lua",
    "lib/roles/courier.lua",
    "lib/roles/builder.lua",
    "programs/digDown.lua",
    "programs/stairs.lua",
    "programs/hello.lua"
)

function Build-Package {
    param(
        [string]$PackageName,
        [string[]]$FilesToDeploy,
        [string]$Description
    )
    
    $DeploymentDir = Join-Path $DeploymentRoot $PackageName
    $ManifestFile = Join-Path $DeploymentDir "manifest.txt"
    
    Write-Host "Building $Description..." -ForegroundColor Green
    
    # Create deployment directory
    if (Test-Path $DeploymentDir) {
        Remove-Item -Path $DeploymentDir -Recurse -Force
    }
    New-Item -Path $DeploymentDir -ItemType Directory -Force | Out-Null

    New-Item -Path $DeploymentDir -ItemType Directory -Force | Out-Null

    # Create manifest
    $ManifestContent = @()

    Write-Host "  Flattening files..." -ForegroundColor Gray

    foreach ($RelativePath in $FilesToDeploy) {
        $SourceFile = Join-Path $SwarmRoot $RelativePath
        
        if (-not (Test-Path $SourceFile)) {
            Write-Host "    [SKIP] $RelativePath (not found)" -ForegroundColor Yellow
            continue
        }
        
        # Create flattened filename: replace / and \ with __
        $FlatName = $RelativePath -replace '[/\\]', '__'
        $DestFile = Join-Path $DeploymentDir $FlatName
        
        # Copy file
        Copy-Item -Path $SourceFile -Destination $DestFile -Force
        
        # Add to manifest: flatname|originalpath
        $ManifestContent += "$FlatName|$RelativePath"
        
        Write-Host "    [OK] $RelativePath -> $FlatName" -ForegroundColor DarkGray
    }

    # Save manifest
    $ManifestContent | Set-Content -Path $ManifestFile -Encoding UTF8

    Write-Host "  Creating deployment script..." -ForegroundColor Gray

    Write-Host "  Creating deployment script..." -ForegroundColor Gray

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

-- Get the directory where this script is running from
local scriptDir = fs.getDir(shell.getRunningProgram())
local manifestPath = fs.combine(scriptDir, "manifest.txt")

-- Read manifest
if not fs.exists(manifestPath) then
    error("manifest.txt not found in " .. scriptDir .. "! Ensure all deployment files are present.")
end

local manifest = {}
local file = fs.open(manifestPath, "r")
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

-- Count manifest entries
local manifestCount = 0
for _ in pairs(manifest) do
    manifestCount = manifestCount + 1
end

print("Loaded manifest with " .. manifestCount .. " files")
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

    Write-Host "  Creating README..." -ForegroundColor Gray

    # Create README
    $ReadmeContent = @"
# Swarm v4.0 $Description Package

## Files Included

- $(($ManifestContent | Measure-Object).Count) Lua files
- manifest.txt - File mapping for reconstruction
- deploy.lua - Deployment script

## Quick Start

1. Copy this folder to a ComputerCraft disk
2. On CC computer: ``cd disk``
3. Run: ``deploy``
4. Follow prompts (default target: "swarm")

## What This Package Contains

$(if ($PackageName -eq "server") {
@"
SERVER PACKAGE - For control computers (Puppetmaster/Monitor):
- puppetmaster.lua - Main control interface (Advanced Pocket Computer)
- monitor.lua - Fleet monitoring display (Advanced Computer + Monitor)
- fleet_manager.lua - Fleet management backend
- Required libraries (swarm_common, swarm_ui, roles)

After deployment:
- Run ``puppetmaster`` on Advanced Pocket Computer
- Run ``monitor`` on Advanced Computer with attached monitor

NOTE: This package does NOT include provision_server. Use 'provision' package for wireless provisioning.
"@
} elseif ($PackageName -eq "provision") {
@"
PROVISION PACKAGE - For wireless turtle provisioning:
- provision_server.lua - Wireless file provisioning system
- distribute.lua - File distribution utility
- Required libraries (swarm_common, swarm_ui, roles)

WORKER FILES INCLUDED (to send to turtles):
- worker.lua, install.lua
- All worker libraries (swarm_worker_lib)
- All role libraries (miner, courier, builder)
- Sample programs (digDown, stairs, hello)

After deployment:
- Run ``provision_server`` to wirelessly provision turtles
- Sends complete worker package without disk space limits!

USAGE:
1. Copy provision_client.lua to turtle via disk (tiny file!)
2. On turtle: provision_client
3. On this computer: provision_server
4. Select turtle and file set to provision
"@
} else {
@"
WORKER PACKAGE - For turtles:
- provision_client.lua - Wireless provisioning receiver (RECOMMENDED!)
- worker.lua - Main turtle worker program
- install.lua - Turtle installation/setup script
- All role libraries (miner, courier, builder)
- Worker programs (digDown, stairs, hello)
- Required libraries (swarm_common, swarm_worker_lib, swarm_ui, roles)

After deployment:
- RECOMMENDED: Run ``provision_client`` then use provision_server from control computer
- OR manual: Run ``install`` on each turtle to set up
- Turtles will auto-start on reboot

RECOMMENDED: Use provision system to avoid disk space limits!
Only provision_client.lua needs to fit on disk initially (~7.6KB)
"@
})

## Files Manifest

$(foreach ($line in $ManifestContent) {
    $parts = $line -split '\|'
    "- $($parts[1])"
}) -join "`n"

---
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Swarm Version: 4.0
Package: $Description
"@

    $ReadmePath = Join-Path $DeploymentDir "README.txt"
    $ReadmeContent | Set-Content -Path $ReadmePath -Encoding UTF8

    Write-Host "  [DONE] $Description package complete" -ForegroundColor Green
    Write-Host "    Location: deployment\$DeploymentName\$PackageName" -ForegroundColor Cyan
    Write-Host "    Files: $(($ManifestContent | Measure-Object).Count)" -ForegroundColor Cyan
    Write-Host ""
    
    return ($ManifestContent | Measure-Object).Count
}

# Build requested packages
$totalFiles = 0

if ($Target -eq "all" -or $Target -eq "server") {
    $totalFiles += Build-Package -PackageName "server" -FilesToDeploy $ServerFiles -Description "Server Control"
}

if ($Target -eq "all" -or $Target -eq "provision") {
    $totalFiles += Build-Package -PackageName "provision" -FilesToDeploy $ProvisionFiles -Description "Provision System"
}

if ($Target -eq "all" -or $Target -eq "worker") {
    $totalFiles += Build-Package -PackageName "worker" -FilesToDeploy $WorkerFiles -Description "Worker Turtles"
}

Write-Host "=== Build Complete ===" -ForegroundColor Green
Write-Host "Deployment: deployment\$DeploymentName" -ForegroundColor Cyan
Write-Host "Total files: $totalFiles" -ForegroundColor Cyan
Write-Host ""
Write-Host "Package Descriptions:" -ForegroundColor Yellow
Write-Host "  server     - Puppetmaster, monitor, fleet manager (6 files)" -ForegroundColor White
Write-Host "  provision  - Wireless provisioning with all worker files (15 files)" -ForegroundColor White
Write-Host "  worker     - Turtle setup with provision_client (13 files)" -ForegroundColor White
Write-Host ""
Write-Host "Recommended Workflow:" -ForegroundColor Yellow
Write-Host "1. Copy 'provision' package to control computer" -ForegroundColor White
Write-Host "2. Copy ONLY provision_client.lua from 'worker' package to turtle disk" -ForegroundColor White
Write-Host "3. Run provision_client on turtle, provision_server on control computer" -ForegroundColor White
Write-Host "4. Wirelessly provision complete worker package" -ForegroundColor White
Write-Host ""
