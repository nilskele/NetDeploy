<#
.SYNOPSIS
    Device selection UI for NetDeploy.
#>

. "$PSScriptRoot/Menu.ps1"

function Select-Devices {
    param(
        [Parameter(Mandatory)][array]$Devices
    )

    if (-not $Devices -or $Devices.Count -eq 0) {
        Write-Host "No devices loaded." -ForegroundColor Red
        return @()
    }

    $options = @("ALL DEVICES")
    foreach ($d in $Devices) {
        $options += "$($d.Hostname) [$($d.DeviceType)]"
    }

    Show-Menu -Title "Select Devices" -Options $options
    $choice = Read-MenuChoice -Prompt "Select device" -Max $options.Count

    if ($choice -eq 1) {
        return $Devices
    }

    return @($Devices[$choice - 2])
}

