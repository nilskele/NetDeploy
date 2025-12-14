# examples/quickDryRun.ps1
# Quick reproducible example: Import module, load devices, run a dry-run backup+deploy for R1.

# Run this from the repository root (pwsh ./examples/quickDryRun.ps1)

Import-Module -Force (Join-Path (Get-Location) 'NetDeploy.psd1') -Verbose

# Load device objects
$devices = Load-Devices -Path ./configs/devices

# Show device list and pick device by hostname
$devices | Select-Object Hostname, ManagementIP, @{Name='HasCreds';Expression={$_.Credentials -ne $null}}
$d = $devices | Where-Object Hostname -eq 'R1'
if (-not $d) { $d = $devices[0] }

Write-Host "Running DRY-RUN for device: $($d.Hostname) ($($d.ManagementIP))" -ForegroundColor Cyan

# Dry-run: previews backup path and command list (safe)
Invoke-DeviceDeployment -Device $d -DryRun -Verbose

# Optionally show the backups folder (dry-run will show the would-be path)
Write-Host "Backup folder (preview):" -ForegroundColor Cyan
Get-ChildItem -Path ./logs/backups -Force -ErrorAction SilentlyContinue | Format-Table -AutoSize
