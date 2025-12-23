<#
.SYNOPSIS
    Device selection UI for NetDeploy.
#>

. "$PSScriptRoot/Menu.ps1"

# Parse a selection string like '1,3-5' into zero-based indices
function Parse-SelectionString {
    <#
    .SYNOPSIS
        Parses device selection string into array indices.
    
    .DESCRIPTION
        Converts user-friendly selection strings into zero-based indices.
        Supports:
        - 'all' or 'a' for all devices
        - Single numbers: '3'
        - Comma-separated: '1,3,5'
        - Ranges: '2-4'
        - Combinations: '1,3-5,7'
        
        Validates indices are within valid range.
    
    .PARAMETER Selection
        Selection string from user.
    
    .PARAMETER MaxIndex
        Maximum valid index (device count).
    
    .EXAMPLE
        $indices = Parse-SelectionString -Selection "1,3-5" -MaxIndex 10
        
        Returns @(0, 2, 3, 4) for devices 1, 3, 4, 5.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)][string]$Selection,
        [Parameter(Mandatory)][int]$MaxIndex
    )

    $Selection = $Selection.Trim()
    Write-Host "DEBUG Parse: Input='$Selection', MaxIndex=$MaxIndex" -ForegroundColor Magenta
    if ($Selection -eq '') { return @() }

    if ($Selection -match '^(?i:a|all)$') {
        return 0..($MaxIndex - 1)
    }

    $parts = $Selection -split ','
    $indices = @()
    foreach ($p in $parts) {
        $p = $p.Trim()
        Write-Host "DEBUG Parse: Processing part '$p'" -ForegroundColor Magenta
        if ($p -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -gt $end) { throw "Invalid range: $p" }
            for ($i = $start; $i -le $end; $i++) { $indices += ($i-1) }
        }
        elseif ($p -match '^\d+$') {
            $idx = ([int]$p - 1)
            Write-Host "DEBUG Parse: Single number $p -> index $idx" -ForegroundColor Magenta
            $indices += $idx
        }
        else {
            throw "Invalid selection token: $p"
        }
    }

    Write-Host "DEBUG Parse: Before validation, indices=$($indices -join ',')" -ForegroundColor Magenta
    # Validate indices
    $indices = $indices | Where-Object { $_ -ge 0 -and $_ -lt $MaxIndex } | Select-Object -Unique
    Write-Host "DEBUG Parse: After validation, indices=$($indices -join ','), type=$($indices.GetType().Name), count=$($indices.Count)" -ForegroundColor Magenta
    return $indices
}


function Select-Devices {
    <#
    .SYNOPSIS
        Interactively or programmatically selects devices.
    
    .DESCRIPTION
        Displays device list with numbers and prompts for selection.
        Supports programmatic selection via Selection parameter.
        Returns array of selected device objects.
        
        Uses comma operator to force array return even for single device
        (fixes PowerShell unwrapping single-element arrays).
    
    .PARAMETER Devices
        Array of device objects to select from.
    
    .PARAMETER Selection
        Optional programmatic selection string (e.g., '1,3-5' or 'all').
        If omitted, prompts user interactively.
    
    .EXAMPLE
        $selected = Select-Devices -Devices $allDevices
        
        Interactively prompts user to select devices.
    
    .EXAMPLE
        $selected = Select-Devices -Devices $allDevices -Selection "1,3"
        
        Programmatically selects devices 1 and 3.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)][array]$Devices,
        [string]$Selection  # optional programmatic selection string (e.g. '1,3-5' or 'all')
    )

    if (-not $Devices -or $Devices.Count -eq 0) {
        Write-Host "No devices loaded." -ForegroundColor Red
        return @()
    }

    Write-Host "Select devices to operate on:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Devices.Count; $i++) {
        $d = $Devices[$i]
        Write-Host "[$($i+1)] $($d.Hostname) [$($d.DeviceType)] ($($d.ManagementIP))"
    }

    Write-Host "\nEnter selection: a|all for all, single number, comma-separated list (eg. 1,3,5) or ranges (eg. 2-4)." -ForegroundColor DarkGray

    if ($Selection) {
        try {
            $indices = Parse-SelectionString -Selection $Selection -MaxIndex $Devices.Count
        } catch {
            Write-Host "Invalid selection string: $_" -ForegroundColor Yellow
            return @()
        }
    } else {
        while ($true) {
            Write-Host -NoNewline "Selection: "
            $sel = Read-Host
            try {
                $indices = Parse-SelectionString -Selection $sel -MaxIndex $Devices.Count
                Write-Host "DEBUG Select: Received indices=$($indices -join ','), type=$($indices.GetType().Name), count=$($indices.Count)" -ForegroundColor Cyan
                break
            } catch {
                Write-Host "Invalid selection. Try again." -ForegroundColor Yellow
            }
        }
    }

    Write-Host "DEBUG Select: Checking indices - null?=$($null -eq $indices), count=$($indices.Count)" -ForegroundColor Cyan
    # Force array wrapper
    $indices = @($indices)
    Write-Host "DEBUG Select: After array wrap - count=$($indices.Count), type=$($indices.GetType().Name)" -ForegroundColor Cyan
    if ($indices.Count -eq 0) { 
        Write-Host "DEBUG: No indices selected or empty array" -ForegroundColor Red
        return @() 
    }

    Write-Host "DEBUG: Building result from indices: $($indices -join ',')" -ForegroundColor Yellow
    $result = @()
    foreach ($idx in $indices) { 
        Write-Host "DEBUG: Adding device at index $idx : $($Devices[$idx].Hostname)" -ForegroundColor Yellow
        $result += $Devices[$idx] 
    }
    Write-Host "DEBUG: Final result count before return: $($result.Count)" -ForegroundColor Yellow
    return ,$result  # Comma forces array return even with single element
}

