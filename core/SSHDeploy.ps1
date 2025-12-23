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
    <#
    .SYNOPSIS
        Establishes an SSH connection to a network device.
    
    .DESCRIPTION
        Connects to a device via SSH using Posh-SSH module with automatic retry logic.
        Tests host reachability before attempting connection and automatically accepts SSH host keys.
    
    .PARAMETER DeviceHost
        The hostname or IP address of the device to connect to.
    
    .PARAMETER Username
        The username for SSH authentication.
    
    .PARAMETER Password
        The password for SSH authentication (plain text).
    
    .PARAMETER Port
        The SSH port number. Defaults to 22.
    
    .PARAMETER Timeout
        Connection timeout in seconds. Defaults to 10.
    
    .PARAMETER Retries
        Number of connection retry attempts. Defaults to 3.
    
    .EXAMPLE
        $session = Connect-SSH -DeviceHost "192.168.1.1" -Username "admin" -Password "cisco"
        
        Establishes SSH connection to the device with default port and timeout.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)][string]$DeviceHost,
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$Password,
        [int]$Port = 22,
        [int]$Timeout = 30,
        [int]$Retries = 3
    )

    for ($i = 1; $i -le $Retries; $i++) {
        Write-Log ("Attempt " + $i + ": Testing IP connectivity to " + $DeviceHost) -Level INFO
        try {
            if (-not (Test-Connection -ComputerName $DeviceHost -Count 1 -Quiet -TimeoutSeconds 2)) {
                Write-Log "Ping failed: $DeviceHost is unreachable (skipping SSH attempt)" -Level WARN
                Start-Sleep -Seconds 2
                continue
            }
        } catch {
            Write-Log "Test-Connection error: $_" -Level WARN
            Start-Sleep -Seconds 2
            continue
        }

        Write-Log ("Attempt " + $i + ": Connecting to " + $DeviceHost + " via SSH...") -Level INFO
        try {
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
    <#
    .SYNOPSIS
        Backs up the running configuration of a network device.
    
    .DESCRIPTION
        Connects to a device via SSH and retrieves the running configuration using 'show running-config'.
        Saves the configuration to a timestamped file in the logs/backups directory.
        Uses SSH shell streams for reliable output capture from Cisco IOS devices.
    
    .PARAMETER Device
        The device object containing hostname, credentials, and connection details.
    
    .PARAMETER Timeout
        SSH connection timeout in seconds. Defaults to 30.
    
    .PARAMETER DryRun
        If specified, simulates the backup without actually connecting to the device.
    
    .EXAMPLE
        $backupFile = Backup-DeviceConfig -Device $router
        
        Creates a backup of the router's running configuration.
    
    .EXAMPLE
        Backup-DeviceConfig -Device $switch -Timeout 60 -DryRun
        
        Simulates backup with 60-second timeout.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
        Start-Sleep -Seconds 5
        
        # Read all available output
        $text = $stream.Read()
        
        # Clean up the output (remove command echo and prompts)
        $lines = $text -split "`r?`n"
        $configLines = @()
        $inConfig = $false
        
        foreach ($line in $lines) {
            # Start capturing from "Building configuration"
            if ($line -match "^Building configuration") { 
                $inConfig = $true 
            }
            
            # Stop at the end prompt (router# or switch#)
            if ($inConfig -and $line -match "^[A-Za-z0-9_-]+#\s*$") {
                break
            }
            
            if ($inConfig) { 
                $configLines += $line 
            }
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
    <#
    .SYNOPSIS
        Executes a series of commands on a device via an existing SSH session.
    
    .DESCRIPTION
        Sends commands to a device one at a time through an SSH session using Invoke-SSHCommand.
        Logs command output and errors. Supports configurable delay between commands.
    
    .PARAMETER Session
        The active SSH session object from Connect-SSH or New-SSHSession.
    
    .PARAMETER Commands
        Array of command strings to execute on the device.
    
    .PARAMETER DelayPerCommand
        Delay in seconds between each command. Defaults to 1 second.
    
    .EXAMPLE
        Invoke-SSHCommands -Session $session -Commands @("enable", "conf t", "hostname Router1") -DelayPerCommand 2
        
        Executes three commands with 2-second delays between them.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
        Note: This function is currently defined but not used in favor of direct shell stream execution.
    #>
    
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
    <#
    .SYNOPSIS
        Deploys configuration commands to a single network device.
    
    .DESCRIPTION
        Performs a complete deployment workflow for one device:
        1. Builds command list from device configuration
        2. Backs up current running configuration
        3. Connects via SSH
        4. Sends all commands via shell stream
        5. Closes SSH session
        
        Uses SSH shell streams for reliable command execution on Cisco IOS devices.
    
    .PARAMETER Device
        The device object containing configuration, credentials, and connection details.
    
    .PARAMETER CommandDelay
        Delay in seconds between each command. Defaults to 0 (uses 500ms minimum).
    
    .PARAMETER DryRun
        If specified, builds commands and simulates backup but does not connect to device.
    
    .EXAMPLE
        Deploy-Device -Device $router -CommandDelay 1
        
        Deploys configuration to router with 1-second delay between commands.
    
    .EXAMPLE
        Deploy-Device -Device $switch -DryRun
        
        Shows what commands would be deployed without actually connecting.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Deploys configuration commands to multiple network devices.
    
    .DESCRIPTION
        Orchestrates deployment to multiple devices either sequentially or in parallel.
        Automatically sorts devices by type (routers first, then switches, then hosts)
        to ensure proper deployment order.
        
        Parallel mode uses PowerShell jobs with configurable throttling to control
        concurrent deployments.
    
    .PARAMETER Devices
        Array of device objects to deploy configurations to.
    
    .PARAMETER CommandDelay
        Delay in seconds between each command sent to devices. Defaults to 0.
    
    .PARAMETER Parallel
        If specified, deploys to devices in parallel using PowerShell background jobs.
    
    .PARAMETER DryRun
        If specified, simulates deployment without connecting to devices.
    
    .PARAMETER Throttle
        Maximum number of concurrent deployments when using Parallel mode. Defaults to 10.
    
    .PARAMETER JobId
        Optional job ID for logging correlation.
    
    .EXAMPLE
        Deploy-AllDevices -Devices $deviceList -CommandDelay 1
        
        Deploys to all devices sequentially with 1-second delay between commands.
    
    .EXAMPLE
        Deploy-AllDevices -Devices $deviceList -Parallel -Throttle 5
        
        Deploys to devices in parallel with maximum 5 concurrent deployments.
    
    .EXAMPLE
        Deploy-AllDevices -Devices $deviceList -DryRun
        
        Shows what would be deployed without making changes.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
