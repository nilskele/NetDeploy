Set-Location '/Users/nilskelecom/Documents/NetDeploy'
Import-Module -Force (Join-Path (Get-Location) 'NetDeploy.psd1') -Verbose
$devices = Load-Devices -Path './configs/devices'
. ./tui/Menu.ps1
Show-LoadedDevices -Devices $devices
Read-Host -Prompt 'Press Enter to finish'