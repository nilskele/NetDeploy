# examples/quickCustomPaths.ps1
# Example: Import the module, set custom paths, and run a dry-run deploy that uses the new paths.

Set-Location (Join-Path (Get-Location) '..\' -Resolve)

# Option A: define globals BEFORE importing the module (works even if Set-NetDeployPaths
# isn't available in the session yet). Use an absolute or relative path.
$Global:NetDeployLogDir = (Join-Path (Get-Location) 'temp-logs')
$Global:NetDeployJobsDir = (Join-Path $Global:NetDeployLogDir 'jobs')
$Global:NetDeployBackupsDir = (Join-Path $Global:NetDeployLogDir 'backups')
$Global:NetDeployDevicesPath = (Join-Path (Get-Location) 'configs/devices')

Import-Module -Force (Join-Path (Get-Location) 'NetDeploy.psd1') -Verbose

# Show configured paths
Get-NetDeployPaths | Format-List

# Load devices from configured path (Load-Devices will fall back to the configured global path)
$devices = Load-Devices

# Dry-run deploy first device using a custom run name
Invoke-DeviceDeployment -Device $devices[0] -DryRun -RunName 'test1'

Write-Host "Check the './temp-logs' folder for logs and job logs." -ForegroundColor Cyan
