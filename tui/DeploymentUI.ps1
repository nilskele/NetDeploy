<#
.SYNOPSIS
    NetDeploy Text User Interface.
#>

# Import NetDeploy module
try {
    Import-Module NetDeploy -ErrorAction Stop -Force
} catch {
    $manifest = Join-Path $PSScriptRoot '..\NetDeploy.psd1'
    if (Test-Path $manifest) {
        Import-Module (Resolve-Path $manifest).Path -Force -ErrorAction Stop
    } else {
        Write-Host "Could not find NetDeploy module" -ForegroundColor Red
        exit 1
    }
}

. "$PSScriptRoot/Menu.ps1"
. "$PSScriptRoot/DeviceSelector.ps1"


function Start-NetDeployUI {
    <#
    .SYNOPSIS
        Launches the NetDeploy text user interface.
    
    .DESCRIPTION
        Main TUI entry point providing interactive menu for:
        - Device deployment (sequential or parallel)
        - Viewing loaded devices
        - Listing recent backups
        - Viewing backup contents
        
        Loads devices from specified path and presents menu-driven workflow.
        Supports dry-run mode and custom run names for job logs.
    
    .PARAMETER DevicePath
        Path to device configurations (JSON file or directory). 
        Defaults to ../configs/devices relative to TUI script location.
    
    .EXAMPLE
        Start-NetDeployUI
        
        Launches TUI with default device path.
    
    .EXAMPLE
        Start-NetDeployUI -DevicePath "C:\NetworkConfigs\devices.json"
        
        Launches TUI with custom device configuration path.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
            "Show loaded devices",
            "List recent backups",
            "View a backup",
            "Exit"
        )

        $choice = Read-MenuChoice -Prompt "Select option" -Max 5

        switch ($choice) {
            1 {
                $selected = Select-Devices -Devices $devices
                # Force array and check count
                $selected = @($selected)
                if ($selected.Count -eq 0) {
                    Pause
                    continue
                }

                Write-Host
                Write-Host "Selected $($selected.Count) device(s) to deploy." -ForegroundColor Cyan

                # Confirm and ask for parallel or sequential
                Write-Host "Choose deployment mode:" -ForegroundColor Cyan
                Write-Host "[1] Sequential (one-by-one)"
                Write-Host "[2] Parallel (start a job per device)"
                $mode = Read-MenuChoice -Prompt "Select mode" -Max 2

                # Build a preview summary
                Write-Host "`nPreview summary:" -ForegroundColor Cyan
                Write-Host "Devices to be deployed: $($selected.Count)" -ForegroundColor DarkCyan
                # list up to 50 names for preview
                $names = $selected | ForEach-Object { $_.Hostname }
                if ($names.Count -le 50) {
                    $i = 1
                    foreach ($n in $names) { Write-Host "  [$i] $n" -ForegroundColor DarkGray; $i++ }
                } else {
                    Write-Host ($names -join ', ') -ForegroundColor DarkGray
                }

                $isParallel = ($mode -eq 2)
                $throttle = 10
                if ($isParallel) {
                    $thInput = Read-Host "Enter throttle (max concurrent jobs) [default $throttle]"
                    if ($thInput -match '^[0-9]+$') { $throttle = [int]$thInput }
                }

                # DryRun prompt for safety
                $dryInput = Read-Host "Perform dry-run only? [Y/n] (default Y)"
                $dryrun = $true
                if ($dryInput -in @('n','N','no','No')) { $dryrun = $false }

                # Optional run name for logs
                $runName = Read-Host "Enter a name for this run (optional, used for job log filenames)"

                # Final confirmation
                Write-Host "`nAbout to deploy $($selected.Count) device(s). Mode: $($isParallel ? 'Parallel' : 'Sequential')" -ForegroundColor Yellow
                if ($isParallel) { Write-Host "Concurrency (throttle): $throttle" -ForegroundColor Yellow }
                Write-Host "DryRun: $($dryrun)" -ForegroundColor Yellow
                $ok = Read-Host "Continue? [y/N]"
                if ($ok -notin @('y','Y','yes','Yes')) {
                    Write-Host "Deployment cancelled." -ForegroundColor Yellow
                    Pause
                    continue
                }

                Write-Host
                Write-Host "Starting deployment..." -ForegroundColor Cyan

                if ($isParallel) {
                    if ($runName) { Invoke-AllDeviceDeployment -Devices $selected -Parallel -Throttle $throttle -DryRun:$dryrun -RunName $runName } else { Invoke-AllDeviceDeployment -Devices $selected -Parallel -Throttle $throttle -DryRun:$dryrun }
                } else {
                    if ($runName) { Invoke-AllDeviceDeployment -Devices $selected -Throttle $throttle -DryRun:$dryrun -RunName $runName } else { Invoke-AllDeviceDeployment -Devices $selected -Throttle $throttle -DryRun:$dryrun }
                }

                Write-Host
                Write-Host "Deployment complete." -ForegroundColor Green
                Pause
            }
            2 {
                # show loaded devices
                if (-not (Get-Command -Name Show-LoadedDevices -ErrorAction SilentlyContinue)) {
                    . "$PSScriptRoot/Menu.ps1"
                }
                Show-LoadedDevices -Devices $devices
                Write-Host "`nPress Enter to return to the menu..." -ForegroundColor DarkGray
                [void][System.Console]::ReadLine()
            }
            3 {
                # list recent backups
                if (-not (Get-Command -Name Show-RecentBackups -ErrorAction SilentlyContinue)) {
                    . "$PSScriptRoot/Menu.ps1"
                }
                Show-RecentBackups -Count 50
                Write-Host "`nPress Enter to return to the menu..." -ForegroundColor DarkGray
                [void][System.Console]::ReadLine()
            }
            4 {
                # view backup contents
                if (-not (Get-Command -Name Show-BackupContents -ErrorAction SilentlyContinue)) {
                    . "$PSScriptRoot/Menu.ps1"
                }
                Show-BackupContents -Count 100
            }
            5 {
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
