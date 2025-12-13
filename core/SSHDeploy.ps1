<#
.SYNOPSIS
    Deploys Cisco IOS commands to devices via SSH using Posh-SSH.

.DESCRIPTION
    Connects to devices using credentials provided in PSD1 configuration,
    runs commands in order, logs output, and supports sequential or parallel deployment.

    Requires Posh-SSH module.
#>

. "$PSScriptRoot/Utils.ps1"
. "$PSScriptRoot/CommandBuilder.ps1"

# -------------------------
# Connect via SSH with safety check
# -------------------------
function Connect-SSH {
    param(
        [Parameter(Mandatory)][string]$DeviceHost,
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$Password,
        [int]$Port = 22,
        [int]$Timeout = 10,
        [int]$Retries = 3
    )

    for ($i = 1; $i -le $Retries; $i++) {
        Write-Log ("Attempt " + $i + ": Connecting to " + $DeviceHost + " via SSH...") -Level INFO

        try {
            # Test if host is reachable
            if (-not (Test-Connection -ComputerName $DeviceHost -Count 1 -Quiet)) {
                Write-Log ("Host " + $DeviceHost + " is unreachable. Skipping...") -Level WARN
                return $null
            }

            $session = New-SSHSession -ComputerName $DeviceHost -Credential (
                New-Object System.Management.Automation.PSCredential(
                    $Username,
                    (ConvertTo-SecureString $Password -AsPlainText -Force)
                )
            ) -Port $Port -ConnectionTimeout $Timeout

            if ($session -and $session.SessionId -ne $null) {
                Write-Log "SSH session established with $DeviceHost (ID: $($session.SessionId))" -Level INFO
                return $session
            } else {
                Write-Log "SSH session creation failed for $DeviceHost" -Level WARN
            }
        } catch {
           Write-Log ("SSH connection error for " + $DeviceHost + ": " + $_) -Level ERROR


        }

        Start-Sleep -Seconds 2
    }

    Write-Log "All SSH connection attempts failed for $DeviceHost" -Level ERROR
    return $null
}


# -------------------------
# Backup running-config helper
# -------------------------
function Backup-DeviceConfig {
    param(
        [Parameter(Mandatory)][object]$Device,
        [int]$Timeout = 30,
        [switch]$DryRun
    )

    Write-Log "Backing up running-config for $($Device.Hostname)" -Level INFO

    # Determine repository/module root (parent of core/)
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $bakDir = Join-Path $moduleRoot 'logs'
    $bakDir = Join-Path $bakDir 'backups'

    # Ensure backup directory exists (idempotent)
    if (-not (Test-Path $bakDir)) {
        New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
    }

    $file = Join-Path $bakDir ("$($Device.Hostname)-$(Get-Date -Format yyyyMMdd-HHmmss).cfg")

    if ($DryRun) {
        Write-Log "DRY-RUN: would save backup to $file" -Level INFO
        return $file
    }

    $session = Connect-SSH -DeviceHost $Device.ManagementIP -Username $Device.Credentials.Username -Password $Device.Credentials.Password -Port $Device.SSHPort -Timeout $Timeout
    if (-not $session) {
        Write-Log "Backup skipped: SSH connection failed for $($Device.Hostname)" -Level WARN
        return $null
    }

    try {
        $output = Invoke-SSHCommand -SessionId $session.SessionId -Command 'show running-config'
        $text = if ($output.Output) { $output.Output -join "`n" } else { "" }

        $text | Out-File -FilePath $file -Encoding UTF8

        Write-Log "Backup saved: $file" -Level INFO
        return $file
    } catch {
        Write-Log "Error during backup for $($Device.Hostname): $_" -Level ERROR
        return $null
    } finally {
        if ($session) { Remove-SSHSession -SessionId $session.SessionId }
    }
}

# -------------------------
# Run commands on device
# -------------------------
function Invoke-SSHCommands {
    param(
        [Parameter(Mandatory)] $Session,
        [Parameter(Mandatory)][string[]]$Commands,
        [int]$DelayPerCommand = 0
    )

    $results = @()

    foreach ($cmd in $Commands) {
        try {
            Write-Log "[$($Session.ComputerName)] Sending: $cmd" -Level DEBUG
            $output = Invoke-SSHCommand -SessionId $Session.SessionId -Command $cmd

            if ($output.Output) {
                $results += $output.Output
                Write-Log "[$($Session.ComputerName)] Output: $($output.Output -join "`n")" -Level DEBUG
            }

            if ($DelayPerCommand -gt 0) { Start-Sleep -Seconds $DelayPerCommand }
        } catch {
            Write-Log "Error executing command '$cmd' on $($Session.ComputerName): $_" -Level ERROR
        }
    }

    return $results
}

# -------------------------
# Deploy commands to a single device
# -------------------------
function Deploy-Device {
    param(
        [Parameter(Mandatory)] $Device,
        [int]$CommandDelay = 0,
        [switch]$DryRun
    )

    Write-Log "Starting deployment for $($Device.Hostname)" -Level INFO

    $cmds = Build-Commands -Device $Device

    # Always attempt to backup the current running-config before making changes.
    # In DryRun mode the backup call will only return the intended backup path.
    try {
        $backupResult = Backup-DeviceConfig -Device $Device -Timeout 30 -DryRun:$DryRun
        if (-not $backupResult) {
            Write-Log "Backup failed for $($Device.Hostname). Aborting deployment to avoid pushing without a backup." -Level ERROR
            return
        }
        Write-Log "Backup result: $backupResult" -Level INFO
    } catch {
        Write-Log "Exception during backup for $($Device.Hostname): $_. Aborting deployment." -Level ERROR
        return
    }

    if ($DryRun) {
        Write-Log "DRY-RUN: Commands for $($Device.Hostname):`n$($cmds -join "`n")" -Level INFO
        return $cmds
    }

    $session = Connect-SSH -DeviceHost $Device.ManagementIP `
        -Username $Device.Credentials.Username `
        -Password $Device.Credentials.Password `
        -Port $Device.SSHPort

    if (-not $session) {
        Write-Log "Skipping $($Device.Hostname) due to connection failure" -Level WARN
        return
    }

    try {
        # Enable mode if required
        $enableCmds = @()
        if ($Device.Credentials.EnablePassword) {
            $enableCmds += "enable"
            $enableCmds += $Device.Credentials.EnablePassword
        }

        if ($enableCmds.Count -gt 0) {
            Invoke-SSHCommands -Session $session -Commands $enableCmds -DelayPerCommand $CommandDelay
        }

        # Disable paging to avoid "--More--"
        Invoke-SSHCommands -Session $session -Commands @("terminal length 0") -DelayPerCommand 1

        # Execute built commands
        Invoke-SSHCommands -Session $session -Commands $cmds -DelayPerCommand $CommandDelay

        Write-Log "Deployment completed for $($Device.Hostname)" -Level INFO
    } catch {
        Write-Log "Deployment error for $($Device.Hostname): $_" -Level ERROR
    } finally {
        if ($session) {
            Remove-SSHSession -SessionId $session.SessionId
            Write-Log "SSH session closed for $($Device.Hostname)" -Level DEBUG
        }
    }
}

# -------------------------
# Deploy multiple devices
# -------------------------
function Deploy-AllDevices {
    param(
        [Parameter(Mandatory)][array]$Devices,
        [int]$CommandDelay = 0,
        [switch]$Parallel,
        [switch]$DryRun
    )

    if ($Parallel) {
        $jobs = @()
        foreach ($dev in $Devices) {
            $jobs += Start-Job -ScriptBlock {
                param($d,$delay,$root)
                Import-Module Posh-SSH -Force
                . "$root/Utils.ps1"
                . "$root/CommandBuilder.ps1"
                . "$root/SSHDeploy.ps1"
                Deploy-Device -Device $d -CommandDelay $delay
            } -ArgumentList $dev, $CommandDelay, $PSScriptRoot
        }

        Write-Log "Waiting for parallel jobs to finish..." -Level INFO
        $jobs | Wait-Job | Out-Null
        $jobs | Receive-Job | Out-Null
        $jobs | Remove-Job
    } else {
        foreach ($dev in $Devices) {
            Deploy-Device -Device $dev -CommandDelay $CommandDelay -DryRun:$DryRun
        }
    }
}
