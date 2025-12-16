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
