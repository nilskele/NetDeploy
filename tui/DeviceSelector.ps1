<#
.SYNOPSIS
    Device selection UI for NetDeploy.
#>

. "$PSScriptRoot/Menu.ps1"

# Parse a selection string like '1,3-5' into zero-based indices
function Parse-SelectionString {
    param(
        [Parameter(Mandatory)][string]$Selection,
        [Parameter(Mandatory)][int]$MaxIndex
    )

    $Selection = $Selection.Trim()
    if ($Selection -eq '') { return @() }

    if ($Selection -match '^(?i:a|all)$') {
        return 0..($MaxIndex - 1)
    }

    $parts = $Selection -split ','
    $indices = @()
    foreach ($p in $parts) {
        $p = $p.Trim()
        if ($p -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -gt $end) { throw "Invalid range: $p" }
            for ($i = $start; $i -le $end; $i++) { $indices += ($i-1) }
        }
        elseif ($p -match '^\d+$') {
            $indices += ([int]$p - 1)
        }
        else {
            throw "Invalid selection token: $p"
        }
    }

    # Validate indices
    $indices = $indices | Where-Object { $_ -ge 0 -and $_ -lt $MaxIndex } | Select-Object -Unique
    return $indices
}


function Select-Devices {
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
                break
            } catch {
                Write-Host "Invalid selection. Try again." -ForegroundColor Yellow
            }
        }
    }

    if (-not $indices -or $indices.Count -eq 0) { return @() }

    $result = @()
    foreach ($idx in $indices) { $result += $Devices[$idx] }
    return ,$result  # Comma forces array return even with single element
}

