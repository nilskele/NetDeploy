Set-Location '/Users/nilskelecom/Documents/NetDeploy'
Import-Module -Force (Join-Path (Get-Location) 'NetDeploy.psd1') -Verbose
$devices = Load-Devices -Path './configs/devices'
. ./tui/DeviceSelector.ps1
# programmatic selection test: select devices 1,3-4
$selected = Select-Devices -Devices $devices -Selection '1,3-4'
$selected | Select-Object Hostname, DeviceType, ManagementIP | Format-Table -AutoSize
Read-Host -Prompt 'Press Enter to finish'