<#
.SYNOPSIS
    Generic menu helpers for NetDeploy TUI.
#>

function Show-Menu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string[]]$Options
    )

    Clear-Host
    Write-Host "==== $Title ====" -ForegroundColor Cyan
    Write-Host

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "[$($i + 1)] $($Options[$i])"
    }

    Write-Host
}

function Read-MenuChoice {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [int]$Max
    )

    while ($true) {
        Write-Host -NoNewline ("{0}: " -f $Prompt)
        $input = Read-Host

        if ($input -match '^\d+$') {
            $choice = [int]$input
            if ($choice -ge 1 -and $choice -le $Max) {
                return $choice
            }
        }

        Write-Host "Invalid selection. Try again." -ForegroundColor Yellow
    }
}


# Show recent backup files created by the deployer
function Show-RecentBackups {
    param([int]$Count = 10)

    $backupDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'logs/backups'
    if (-not (Test-Path $backupDir)) {
        Write-Host "No backups directory found: $backupDir" -ForegroundColor Yellow
        return
    }

    $items = Get-ChildItem -Path $backupDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First $Count
    if ($items.Count -eq 0) { Write-Host "No backup files found." -ForegroundColor Yellow; return }

    Write-Host "Recent backups (newest first):" -ForegroundColor Cyan
    foreach ($it in $items) {
        Write-Host ("{0}  {1}" -f $it.LastWriteTime.ToString('s'), $it.Name)
    }
}


# Show a table of loaded devices
function Show-LoadedDevices {
    param(
        [Parameter(Mandatory)][array]$Devices
    )

    if (-not $Devices -or $Devices.Count -eq 0) {
        Write-Host "No devices loaded." -ForegroundColor Yellow
        return
    }

    $out = $Devices | Select-Object @{Name='Index';Expression={if ($_.PSObject.Properties.Name -contains 'DeviceIndex') { $_.DeviceIndex } else { '' }}},
        Hostname, DeviceType, ManagementIP, @{Name='HasCreds';Expression={if ($_.PSObject.Properties.Name -contains 'Credentials') { ($_.Credentials -ne $null) } else { $false }}}

    $out | Format-Table -AutoSize
}


# View the contents of a selected backup file (paged)
function Show-BackupContents {
    param(
        [int]$Count = 50
    )

    $backupDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'logs/backups'
    if (-not (Test-Path $backupDir)) {
        Write-Host "No backups directory found: $backupDir" -ForegroundColor Yellow
        return
    }

    $items = Get-ChildItem -Path $backupDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First $Count
    if ($items.Count -eq 0) { Write-Host "No backup files found." -ForegroundColor Yellow; return }

    Write-Host "Recent backups (newest first):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $items.Count; $i++) {
        $it = $items[$i]
        Write-Host "[$($i+1)] $($it.LastWriteTime.ToString('s'))  $($it.Name)"
    }

    while ($true) {
        $sel = Read-MenuChoice -Prompt "Enter backup number to view (0 to cancel)" -Max $items.Count
        if ($sel -eq 0) { return }
        $file = $items[$sel - 1].FullName

        Write-Host "\n--- Viewing: $file ---\n" -ForegroundColor Green

        try {
            # Use Get-Content to stream; if large, show only head and tail with a note
            $lines = Get-Content -Path $file -ErrorAction Stop
            $lineCount = $lines.Count

            if ($lineCount -le 1000) {
                $lines | ForEach-Object { Write-Host $_ }
            } else {
                Write-Host "File is large ($lineCount lines). Showing first 500 and last 500 lines." -ForegroundColor Yellow
                $lines[0..499] | ForEach-Object { Write-Host $_ }
                Write-Host "... [skipped $([int]($lineCount - 1000)) lines] ..." -ForegroundColor DarkGray
                $lines[($lineCount-500)..($lineCount-1)] | ForEach-Object { Write-Host $_ }
            }

        } catch {
            Write-Host "Failed to read backup file: $_" -ForegroundColor Red
        }

        Write-Host "\nPress Enter to return to backup list..." -ForegroundColor DarkGray
        [void][System.Console]::ReadLine()
        Write-Host "\nRecent backups (newest first):" -ForegroundColor Cyan
        for ($i = 0; $i -lt $items.Count; $i++) { $it = $items[$i]; Write-Host "[$($i+1)] $($it.LastWriteTime.ToString('s'))  $($it.Name)" }
    }

}
