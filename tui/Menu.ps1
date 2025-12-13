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
