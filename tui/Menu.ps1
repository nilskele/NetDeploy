<#
.SYNOPSIS
    Generic menu helpers for NetDeploy TUI.
#>

function Show-Menu {
    <#
    .SYNOPSIS
        Displays a numbered menu with title.
    
    .DESCRIPTION
        Clears screen and displays a formatted menu with title and numbered options.
        Used throughout the TUI for navigation.
    
    .PARAMETER Title
        Menu title to display at the top.
    
    .PARAMETER Options
        Array of menu option strings to display.
    
    .EXAMPLE
        Show-Menu -Title "Main Menu" -Options @("Deploy Devices", "View Backups", "Exit")
        
        Displays main menu with three options.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Reads and validates numeric menu choice.
    
    .DESCRIPTION
        Prompts for numeric input and validates it's within valid range (0 to Max).
        Loops until valid input is received. Allows 0 for cancel/back.
    
    .PARAMETER Prompt
        Prompt text to display.
    
    .PARAMETER Max
        Maximum valid selection number.
    
    .PARAMETER AllowZero
        Allow 0 as a valid choice (for cancel/back operations).
    
    .EXAMPLE
        $choice = Read-MenuChoice -Prompt "Select option" -Max 5
        
        Reads menu choice between 1 and 5.
    
    .EXAMPLE
        $choice = Read-MenuChoice -Prompt "Select option (0 to cancel)" -Max 5 -AllowZero
        
        Reads menu choice between 0 and 5.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [int]$Max,
        [switch]$AllowZero
    )

    while ($true) {
        Write-Host -NoNewline ("{0}: " -f $Prompt)
        $input = Read-Host

        if ($input -match '^\d+$') {
            $choice = [int]$input
            $min = if ($AllowZero) { 0 } else { 1 }
            if ($choice -ge $min -and $choice -le $Max) {
                return $choice
            }
        }

        Write-Host "Invalid selection. Try again." -ForegroundColor Yellow
    }
}


# Show recent backup files created by the deployer
function Show-RecentBackups {
    <#
    .SYNOPSIS
        Displays list of recent backup files.
    
    .DESCRIPTION
        Lists backup files from logs/backups directory sorted by newest first.
        Shows timestamp and filename for each backup.
    
    .PARAMETER Count
        Maximum number of backups to display. Defaults to 10.
    
    .EXAMPLE
        Show-RecentBackups -Count 20
        
        Displays 20 most recent backup files.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Displays table of loaded device configurations.
    
    .DESCRIPTION
        Shows formatted table with device Index, Hostname, DeviceType, ManagementIP,
        and credential status. Used to review loaded devices before deployment.
    
    .PARAMETER Devices
        Array of device objects to display.
    
    .EXAMPLE
        Show-LoadedDevices -Devices $deviceList
        
        Displays table of all loaded devices.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Interactively views backup file contents.
    
    .DESCRIPTION
        Lists recent backup files and allows user to select one to view.
        For large files (>1000 lines), shows first 500 and last 500 lines.
        User can return to list and view another backup.
    
    .PARAMETER Count
        Maximum number of backups to list. Defaults to 50.
    
    .EXAMPLE
        Show-BackupContents
        
        Displays backup list and allows interactive viewing.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
        $sel = Read-MenuChoice -Prompt "Enter backup number to view (0 to cancel)" -Max $items.Count -AllowZero
        if ($sel -eq 0) { return }
        $file = $items[$sel - 1].FullName

        Write-Host "\n--- Viewing: $file ---\n" -ForegroundColor Green

        try {
            # Use Get-Content to stream
            $lines = Get-Content -Path $file -ErrorAction Stop
            $lineCount = $lines.Count

            if ($lineCount -eq 0) {
                Write-Host "Backup file is empty." -ForegroundColor Yellow
            } elseif ($lineCount -le 100) {
                # Small file - show all
                $lines | ForEach-Object { Write-Host $_ }
            } else {
                # Large file - use More pagination or head/tail
                Write-Host "File has $lineCount lines. Displaying with pagination..." -ForegroundColor Yellow
                Write-Host "Press 'q' to stop viewing, 'Enter' to continue..." -ForegroundColor DarkGray
                Write-Host
                
                $pageSize = 50
                for ($i = 0; $i -lt $lineCount; $i += $pageSize) {
                    $end = [Math]::Min($i + $pageSize - 1, $lineCount - 1)
                    $lines[$i..$end] | ForEach-Object { Write-Host $_ }
                    
                    if ($end -lt ($lineCount - 1)) {
                        Write-Host "`n--- Line $($i + 1) to $($end + 1) of $lineCount (press Enter for more, 'q' to quit) ---" -ForegroundColor DarkGray
                        $key = [System.Console]::ReadLine()
                        if ($key -eq 'q') { break }
                    }
                }
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
