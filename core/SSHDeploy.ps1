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
            ) -Port $Port -ConnectionTimeout $Timeout -AcceptKey

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
        # Use SSH Stream for Cisco devices (more reliable than exec channel)
        $stream = New-SSHShellStream -SessionId $session.SessionId
        
        # Clear initial banner/prompt
        Start-Sleep -Milliseconds 500
        $stream.Read() | Out-Null
        
        # Send terminal length 0 to disable pagination
        $stream.WriteLine("terminal length 0")
        Start-Sleep -Milliseconds 500
        $stream.Read() | Out-Null
        
        # Send show running-config command
        $stream.WriteLine("show running-config")
        Start-Sleep -Seconds 3
        
        $text = $stream.Read()
        
        # Clean up the output (remove command echo and prompt)
        $lines = $text -split "`n"
        $configLines = @()
        $inConfig = $false
        
        foreach ($line in $lines) {
            if ($line -match "^Building configuration") { $inConfig = $true }
            if ($inConfig) { $configLines += $line }
        }
        
        $cleanText = ($configLines -join "`n").Trim()
        
        $cleanText | Out-File -FilePath $file -Encoding UTF8

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
# Run commands on device using SSH Stream
# -------------------------
function Invoke-SSHCommands {
    param(
        [Parameter(Mandatory)] $Session,
        [Parameter(Mandatory)][string[]]$Commands,
        [int]$DelayPerCommand = 1
    )

    $results = @()

    if (-not $Session) {
        Write-Log "SSH session is null" -Level ERROR
        return $results
    }

    foreach ($cmd in $Commands) {
        try {
            Write-Log "[$($Session.ComputerName)] Sending: $cmd" -Level DEBUG
            
            $result = Invoke-SSHCommand -SessionId $Session.SessionId -Command $cmd -TimeOut 60
            
            if ($result) {
                $results += $result
                if ($result.Output) {
                    Write-Log "[$($Session.ComputerName)] Output: $($result.Output)" -Level DEBUG
                }
                if ($result.Error) {
                    Write-Log "[$($Session.ComputerName)] Error: $($result.Error)" -Level WARN
                }
            }
            
            if ($DelayPerCommand -gt 0) {
                Start-Sleep -Seconds $DelayPerCommand
            }
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

    $stream = $null
    try {
        # Wait for session to stabilize
        Start-Sleep -Seconds 3
        
        # Create shell stream (same method that works for backups)
        Write-Log "Creating SSH shell stream for deployment to $($Device.Hostname)" -Level DEBUG
        $stream = New-SSHShellStream -SessionId $session.SessionId -Columns 200
        
        if (-not $stream) {
            Write-Log "Failed to create SSH stream for $($Device.Hostname)" -Level ERROR
            return
        }
        
        # Wait for initial prompt and clear buffer
        Start-Sleep -Seconds 2
        $stream.Read() | Out-Null
        
        # Send all commands through the stream
        foreach ($cmd in $cmds) {
            Write-Log "[$($Device.Hostname)] Sending: $cmd" -Level DEBUG
            $stream.WriteLine($cmd)
            
            # Wait between commands
            if ($CommandDelay -gt 0) {
                Start-Sleep -Seconds $CommandDelay
            } else {
                Start-Sleep -Milliseconds 500
            }
            
            # Read output
            $output = $stream.Read()
            if ($output) {
                Write-Log "[$($Device.Hostname)] Output: $output" -Level DEBUG
            }
        }
        
        # Wait for final commands to complete
        Start-Sleep -Seconds 3
        $finalOutput = $stream.Read()
        if ($finalOutput) {
            Write-Log "[$($Device.Hostname)] Final output: $finalOutput" -Level DEBUG
        }

        Write-Log "Deployment completed for $($Device.Hostname)" -Level INFO
    } catch {
        Write-Log "Deployment error for $($Device.Hostname): $_" -Level ERROR
    } finally {
        if ($stream) {
            $stream.Dispose()
        }
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
        [switch]$DryRun,
        [int]$Throttle = 10,
        [string]$JobId = $null
    )

    if ($Parallel) {
        if ($Throttle -le 0) { $Throttle = $Devices.Count }

        $total = $Devices.Count
        $idx = 0
        $batchNumber = 1

        while ($idx -lt $total) {
            $end = [Math]::Min($idx + $Throttle - 1, $total - 1)
            $batch = $Devices[$idx..$end]

            $startDisplay = $idx + 1
            $endDisplay = $end + 1
            Write-Log ("Starting batch {0}: devices {1}-{2} of {3} (concurrency={4})" -f $batchNumber, $startDisplay, $endDisplay, $total, $Throttle) -Level INFO

            $jobs = @()
            foreach ($dev in $batch) {
                $jobs += Start-Job -ScriptBlock {
                    param($d,$delay,$root,$dryrun,$jobid,$joblog)
                    # Restore job id in the child process so Write-Log writes to per-job log
                    if ($jobid) { $Global:NetDeployJobId = $jobid }
                    if ($joblog) { $Global:NetDeployJobLogFile = $joblog }
                    # Try to import Posh-SSH in job, but tolerate missing module for DryRun tests
                    try { Import-Module Posh-SSH -Force -ErrorAction Stop } catch { }
                    . "$root/Utils.ps1"
                    . "$root/CommandBuilder.ps1"
                    . "$root/SSHDeploy.ps1"
                    Deploy-Device -Device $d -CommandDelay $delay -DryRun:$dryrun
                } -ArgumentList $dev, $CommandDelay, $PSScriptRoot, $DryRun, $JobId, $Global:NetDeployJobLogFile
            }

            Write-Log "Waiting for batch $batchNumber jobs to finish..." -Level INFO
            $jobs | Wait-Job | Out-Null
            $jobs | Receive-Job | Out-Null
            $jobs | Remove-Job

            $idx += $Throttle
            $batchNumber++
        }
    } else {
        # Ensure current process has JobId available so Write-Log writes into the right job log
        if ($JobId) {
            if (-not $Global:NetDeployJobId) { $Global:NetDeployJobId = $JobId }
            if (-not $Global:NetDeployJobLogFile -and (Get-Variable -Name NetDeployJobsDir -Scope Global -ErrorAction SilentlyContinue)) {
                # If a job log file wasn't set by New-LogJob, create a default one
                $Global:NetDeployJobLogFile = Join-Path $Global:NetDeployJobsDir ("run-{0}.log" -f $JobId)
            }
        }
        foreach ($dev in $Devices) {
            Deploy-Device -Device $dev -CommandDelay $CommandDelay -DryRun:$DryRun
        }
    }
}
