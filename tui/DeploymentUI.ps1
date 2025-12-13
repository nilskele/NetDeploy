<#
.SYNOPSIS
    NetDeploy Text User Interface.
#>

Import-Module NetDeploy -Force

. "$PSScriptRoot/Menu.ps1"
. "$PSScriptRoot/DeviceSelector.ps1"

function Start-NetDeployUI {
    param(
        [string]$DevicePath = "$PSScriptRoot/../configs/devices"
    )

    try {
        $devices = Load-Devices -Path $DevicePath
    } catch {
        Write-Host "Failed to load devices: $_" -ForegroundColor Red
        return
    }

    while ($true) {
        Show-Menu -Title "NetDeploy" -Options @(
            "Deploy devices",
            "Exit"
        )

        $choice = Read-MenuChoice -Prompt "Select option" -Max 2

        switch ($choice) {
            1 {
                $selected = Select-Devices -Devices $devices
                if ($selected.Count -eq 0) {
                    Pause
                    continue
                }

                Write-Host
                Write-Host "Deploying $($selected.Count) device(s)..." -ForegroundColor Cyan

                Invoke-AllDeviceDeployment -Devices $selected

                Write-Host
                Write-Host "Deployment complete." -ForegroundColor Green
                Pause
            }
            2 {
                Write-Host "Exiting NetDeploy."
                break
            }
        }
    }
}

# Auto-start if run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-NetDeployUI
}
