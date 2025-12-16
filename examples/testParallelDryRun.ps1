# examples/testParallelDryRun.ps1
# Test parallel dry-run deployment (no SSH should be attempted)
Set-Location '/Users/nilskelecom/Documents/NetDeploy'
Import-Module -Force (Join-Path (Get-Location) 'NetDeploy.psd1') -Verbose
$devices = Load-Devices -Path './configs/devices'
# select first 4 devices for test
$selected = $devices[0..3]
Write-Host "Invoking parallel dry-run for $($selected.Count) devices"
Invoke-AllDeviceDeployment -Devices $selected -Parallel -DryRun -RunName 'manual-parallel-dryrun' -Verbose
Read-Host -Prompt 'Press Enter to finish'