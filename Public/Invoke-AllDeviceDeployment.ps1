function Invoke-AllDeviceDeployment {
    <#
    .SYNOPSIS
        Deploys configurations to multiple network devices.
    
    .DESCRIPTION
        Public API function for deploying configurations to multiple devices.
        Supports both sequential and parallel deployment modes.
        Validates all devices before deployment and provides detailed results.
    
    .PARAMETER Devices
        Array of device objects to deploy to.
    
    .PARAMETER CommandDelay
        Delay in seconds between commands. Defaults to 0.
    
    .PARAMETER DryRun
        If specified, validates and shows commands without connecting to devices.
    
    .PARAMETER Parallel
        If specified, deploys to all devices simultaneously using background jobs.
    
    .PARAMETER RunName
        Optional name for the deployment run (used in log files).
    
    .EXAMPLE
        Invoke-AllDeviceDeployment -Devices $devices -CommandDelay 1
        
        Deploys to all devices sequentially with 1-second delay between commands.
    
    .EXAMPLE
        Invoke-AllDeviceDeployment -Devices $devices -Parallel -RunName "prod-deploy"
        
        Deploys to all devices in parallel with custom run name.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)] [array]$Devices,
        [int]$CommandDelay = 0,
        [switch]$DryRun,
        [switch]$Parallel,
        [string]$RunName
    )

    try {
        $jobId = New-LogJob -RunName $RunName
        Write-Log "Starting bulk deployment for $($Devices.Count) device(s)" -Level INFO

        # Validate all devices first
        Write-Log "Validating all device configurations..." -Level INFO
        Validate-AllDevices -Devices $Devices

        if ($Parallel) {
            Write-Log "Starting parallel deployment..." -Level INFO
            $result = Deploy-AllDevices -Devices $Devices -CommandDelay $CommandDelay -DryRun:$DryRun -Parallel
        } else {
            Write-Log "Starting sequential deployment..." -Level INFO
            $result = Deploy-AllDevices -Devices $Devices -CommandDelay $CommandDelay -DryRun:$DryRun
        }

        Write-Log "Bulk deployment completed. Successful: $($result.SuccessCount)/$($result.TotalCount)" -Level INFO
        return $result
    }
    catch {
        Write-Log "Exception during bulk deployment: $_" -Level ERROR
        throw
    }
    finally {
        Close-LogJob -JobId $jobId
    }
}
