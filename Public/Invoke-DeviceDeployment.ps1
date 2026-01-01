function Invoke-DeviceDeployment {
    <#
    .SYNOPSIS
        Deploys configuration to a single network device.
    
    .DESCRIPTION
        Public API function for deploying configuration to one device.
        Validates device configuration, creates a job log, backs up current config,
        and deploys the new configuration via SSH.
    
    .PARAMETER Device
        The device object containing configuration and connection details.
    
    .PARAMETER CommandDelay
        Delay in seconds between commands. Defaults to 0.
    
    .PARAMETER DryRun
        If specified, validates and shows commands without connecting to device.
    
    .PARAMETER RunName
        Optional name for the deployment run (used in log files).
    
    .EXAMPLE
        Invoke-DeviceDeployment -Device $router -CommandDelay 1
        
        Deploys configuration to a single router with 1-second delay between commands.
    
    .EXAMPLE
        Invoke-DeviceDeployment -Device $switch -DryRun -RunName "test-deployment"
        
        Performs a dry-run deployment simulation with custom run name.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)] $Device,
        [int]$CommandDelay = 0,
        [switch]$DryRun,
        [string]$RunName
    )

    # Start a per-device job log for easier tracing of single-device runs
    try {
        $jobId = New-LogJob -RunName $RunName
        Write-Log "Starting deployment for device: $($Device.Hostname)" -Level INFO

        # Validate device config
        Write-Log "Validating device configuration..." -Level INFO
        Validate-Device -Device $Device

        # Build commands from config
        Write-Log "Building deployment commands..." -Level INFO
        $commands = Build-Commands -Device $Device

        if ($DryRun) {
            Write-Log "DRY-RUN mode: showing generated commands without deploying" -Level INFO
            Write-Host "`n--- Generated Commands for $($Device.Hostname) ---" -ForegroundColor Cyan
            foreach ($cmd in $commands) { Write-Host "  $cmd" }
            Write-Host "--- End of commands ---`n" -ForegroundColor Cyan
            return @{
                Success = $true
                DryRun = $true
                Device = $Device.Hostname
                Commands = $commands
            }
        }

        # Backup current config
        Write-Log "Backing up current configuration..." -Level INFO
        $backupFile = Backup-DeviceConfig -Device $Device

        # Deploy configuration
        Write-Log "Deploying configuration to $($Device.Hostname)..." -Level INFO
        $result = Deploy-Device -Device $Device -Commands $commands -CommandDelay $CommandDelay

        if ($result) {
            Write-Log "Deployment completed successfully for $($Device.Hostname)" -Level INFO
            return @{
                Success = $true
                Device = $Device.Hostname
                BackupFile = $backupFile
                CommandCount = $commands.Count
            }
        } else {
            Write-Log "Deployment failed for $($Device.Hostname)" -Level ERROR
            return @{
                Success = $false
                Device = $Device.Hostname
                BackupFile = $backupFile
            }
        }
    }
    catch {
        Write-Log "Exception during deployment for $($Device.Hostname): $_" -Level ERROR
        return @{
            Success = $false
            Device = $Device.Hostname
            Error = $_.Exception.Message
        }
    }
    finally {
        Close-LogJob -JobId $jobId
    }
}
