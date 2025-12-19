<#
.SYNOPSIS
    Main deployment module for NetDeploy.

.DESCRIPTION
    Public API for loading, validating, and deploying network devices.
    Internals are hidden behind Invoke-* functions.
#>

# -------------------------
# Import internal modules (use Resolve-Path/Join-Path for robust dot-sourcing)
# -------------------------
$__nd_ModuleRoot = $PSScriptRoot
$__nd_InternalFiles = @(
    'core/PathLoader.ps1',
    'core/Utils.ps1',
    'core/DeviceLoader.ps1',
    'core/deviceValidator.ps1',
    'core/CommandBuilder.ps1',
    'core/SSHDeploy.ps1'
)

foreach ($__nd_f in $__nd_InternalFiles) {
    $__nd_path = Join-Path $__nd_ModuleRoot $__nd_f
    if (Test-Path $__nd_path) {
        . (Resolve-Path $__nd_path).Path
    } else {
        Write-Verbose "NetDeploy: internal file not found: $__nd_path"
    }
}

# -------------------------
# Public API
# -------------------------

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
        if ($RunName) { $null = New-LogJob -Name $RunName } else { $null = New-LogJob -Name $Device.Hostname }
    } catch {}
    try {
        Validate-Device -Device $Device
        Deploy-Device -Device $Device -CommandDelay $CommandDelay -DryRun:$DryRun
    } finally {
        try { Close-LogJob -Reason ($DryRun ? 'dryrun' : 'complete') } catch {}
    }
}

function Invoke-AllDeviceDeployment {
    <#
    .SYNOPSIS
        Deploys configuration to multiple network devices.
    
    .DESCRIPTION
        Public API function for batch device deployment.
        Validates all devices, creates a job log, and orchestrates deployment
        either sequentially or in parallel.
    
    .PARAMETER Devices
        Array of device objects to deploy.
    
    .PARAMETER CommandDelay
        Delay in seconds between commands. Defaults to 0.
    
    .PARAMETER Parallel
        If specified, deploys devices in parallel using PowerShell jobs.
    
    .PARAMETER DryRun
        If specified, validates and shows commands without connecting to devices.
    
    .PARAMETER Throttle
        Maximum concurrent deployments when using Parallel mode. Defaults to 10.
    
    .PARAMETER RunName
        Optional name for the deployment run (used in log files).
    
    .EXAMPLE
        Invoke-AllDeviceDeployment -Devices $deviceList
        
        Deploys configuration to all devices sequentially.
    
    .EXAMPLE
        Invoke-AllDeviceDeployment -Devices $deviceList -Parallel -Throttle 5 -RunName "prod-deploy"
        
        Deploys to devices in parallel (max 5 concurrent) with custom run name.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)][array]$Devices,
        [int]$CommandDelay = 0,
        [switch]$Parallel,
        [switch]$DryRun,
        [int]$Throttle = 10,
        [string]$RunName
    )

    Validate-AllDevices -DeviceList $Devices

    # Start a named job log for this run so logs are easy to find
    try {
        $jobName = if ($RunName) { $RunName } else { 'deploy' }
        $jobId = New-LogJob -Name $jobName
    } catch {
        # If logging helper isn't present, continue without job scoping
        $jobId = $null
    }

    try {
        Deploy-AllDevices -Devices $Devices -CommandDelay $CommandDelay -Parallel:$Parallel -DryRun:$DryRun -Throttle $Throttle -JobId $jobId
    } finally {
        try { Close-LogJob -Reason ($DryRun ? 'dryrun' : 'complete') } catch {}
    }
}


function Set-NetDeployPaths {
    <#
    .SYNOPSIS
        Configures custom paths for NetDeploy directories.
    
    .DESCRIPTION
        Allows customization of log, backup, job, and device configuration directories.
        Creates directories if they don't exist.
    
    .PARAMETER LogsPath
        Custom path for log files.
    
    .PARAMETER JobsPath
        Custom path for job-specific log files.
    
    .PARAMETER BackupsPath
        Custom path for device configuration backups.
    
    .PARAMETER DevicesPath
        Custom path for device configuration files.
    
    .EXAMPLE
        Set-NetDeployPaths -BackupsPath "C:\NetworkBackups"
        
        Sets custom backup directory.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [string]$LogsPath,
        [string]$JobsPath,
        [string]$BackupsPath,
        [string]$DevicesPath
    )

    if ($LogsPath) { $Global:NetDeployLogDir = (Resolve-AbsolutePath -Path $LogsPath) }
    if ($JobsPath) { $Global:NetDeployJobsDir = (Resolve-AbsolutePath -Path $JobsPath) }
    if ($BackupsPath) {
        $Global:NetDeployBackupsDir = (Resolve-AbsolutePath -Path $BackupsPath)
    }
    if ($DevicesPath) { $Global:NetDeployDevicesPath = (Resolve-AbsolutePath -Path $DevicesPath) }

    # Ensure directories exist
    foreach ($d in @($Global:NetDeployLogDir, $Global:NetDeployJobsDir, $Global:NetDeployBackupsDir)) {
        if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

function Get-NetDeployPaths {
    <#
    .SYNOPSIS
        Retrieves currently configured NetDeploy paths.
    
    .DESCRIPTION
        Returns an object containing current paths for logs, jobs, backups, and device configs.
    
    .EXAMPLE
        $paths = Get-NetDeployPaths
        Write-Host "Backups are stored in: $($paths.BackupsPath)"
        
        Gets current path configuration.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    return [pscustomobject]@{
        LogsPath = $Global:NetDeployLogDir
        JobsPath = $Global:NetDeployJobsDir
        BackupsPath = (Get-Variable -Name NetDeployBackupsDir -Scope Global -ErrorAction SilentlyContinue).Value
        DevicesPath = (Get-Variable -Name NetDeployDevicesPath -Scope Global -ErrorAction SilentlyContinue).Value
    }
}

# -----------------------------------------------------------------
# Convenience/compat shim for the TUI: Load-Devices
# Expose a simple function that the TUI expects to load devices by path
# -----------------------------------------------------------------
function Load-Devices {
    <#
    .SYNOPSIS
        Loads device configurations from JSON or PSD1 files.
    
    .DESCRIPTION
        Loads device configurations from a JSON file or directory of PSD1 files.
        Automatically detects file type and delegates to appropriate loader.
        Used by the TUI and can be called programmatically.
    
    .PARAMETER Path
        Path to devices.json file or directory containing device PSD1 files.
        If not specified, uses default configs/devices location.
    
    .EXAMPLE
        $devices = Load-Devices
        
        Loads devices from default location.
    
    .EXAMPLE
        $devices = Load-Devices -Path "C:\MyConfigs\devices.json"
        
        Loads devices from custom JSON file.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [string]$Path
    )

    # Allow optional path; fall back to configured global DevicesPath or the module's default
    if (-not $Path) {
        if ((Get-Variable -Name NetDeployDevicesPath -Scope Global -ErrorAction SilentlyContinue) -and $Global:NetDeployDevicesPath) {
            $Path = $Global:NetDeployDevicesPath
        } else {
            $Path = Join-Path $PSScriptRoot '../configs/devices'
        }
    }

    # Ensure the internal loader is available in this scope. In some import
    # scenarios the DeviceLoader file may not have been dot-sourced into the
    # current module scope (platform differences). If the helper isn't found,
    # dot-source the local DeviceLoader.ps1 explicitly.
    if (-not (Get-Command -Name Load-AllDevices -ErrorAction SilentlyContinue)) {
        # look in the core/ subfolder where the loader actually lives
        $loaderPath = Join-Path $PSScriptRoot 'core/DeviceLoader.ps1'
        if (Test-Path $loaderPath) {
            . (Resolve-Path $loaderPath).Path
        } else {
            throw "Internal loader not available and '$loaderPath' not found"
        }
    }

    # If the path points to a JSON file, use the JSON loader
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($resolved) {
        $item = Get-Item -LiteralPath $resolved.Path -ErrorAction SilentlyContinue
        if ($item -and -not $item.PSIsContainer) {
            if ($item.Extension -eq '.json') {
                if (-not (Get-Command -Name Load-AllDevicesFromJson -ErrorAction SilentlyContinue)) {
                    $loaderPath = Join-Path $PSScriptRoot 'core/DeviceLoader.ps1'
                    if (Test-Path $loaderPath) { . (Resolve-Path $loaderPath).Path } else { throw "Internal loader not available and '$loaderPath' not found" }
                }
                return Load-AllDevicesFromJson -File $item.FullName
            }
        }
    }

    return Load-AllDevices -Folder $Path
}

# -------------------------
# Test all devices wrapper
# -------------------------
function Test-AllDevices {
    <#
    .SYNOPSIS
        Loads and validates device configurations.
    
    .DESCRIPTION
        Loads devices from a folder and validates all configurations against schemas.
        Useful for testing device configurations without deploying.
    
    .PARAMETER Folder
        Path to folder containing device PSD1 files.
    
    .EXAMPLE
        $devices = Test-AllDevices -Folder "./configs/devices"
        
        Validates all device configurations in the specified folder.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $devices = Load-AllDevices -Folder $Folder
    Validate-AllDevices -DeviceList $devices
    return $devices
}

# Export the new helpers as part of the public API
Export-ModuleMember -Function Test-AllDevices, Load-Devices, Backup-DeviceConfig, Set-NetDeployPaths, Get-NetDeployPaths

# -------------------------
# Export ONLY public API
# -------------------------
Export-ModuleMember -Function `
    Invoke-DeviceDeployment, `
    Invoke-AllDeviceDeployment, `
    Load-Devices, `
    Backup-DeviceConfig, `
    Set-NetDeployPaths, `
    Get-NetDeployPaths, `
    Test-AllDevices
