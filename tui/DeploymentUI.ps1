<#
.SYNOPSIS
    NetDeploy Text User Interface.
#>

# Try to import an installed module named 'NetDeploy' first. If it's not found,
# fall back to the local module manifest/psm1 in the repository so the TUI can
# be run directly from the project folder.
try {
    Import-Module NetDeploy -ErrorAction Stop -Force
} catch {
    # Look for local manifest or module file relative to the TUI script
    $manifest = Join-Path $PSScriptRoot '..\NetDeploy.psd1'
    $psm1     = Join-Path $PSScriptRoot '..\NetDeploy.psm1'

    if (Test-Path $manifest) {
        Import-Module (Resolve-Path $manifest).Path -Force -ErrorAction Stop
    } elseif (Test-Path $psm1) {
        Import-Module (Resolve-Path $psm1).Path -Force -ErrorAction Stop
    } else {
        Write-Host "Could not find NetDeploy module in module path or repository root." -ForegroundColor Red
        throw "NetDeploy module not available"
    }
}

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
                    return
            }
        }
    }
}

# Auto-start if run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-NetDeployUI
}
