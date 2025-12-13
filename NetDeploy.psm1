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
        [switch]$DryRun
    )

    Validate-Device -Device $Device
    Deploy-Device -Device $Device -CommandDelay $CommandDelay -DryRun:$DryRun
}

function Invoke-AllDeviceDeployment {
    param(
        [Parameter(Mandatory)][array]$Devices,
        [int]$CommandDelay = 0,
        [switch]$Parallel,
        [switch]$DryRun
    )

    Validate-AllDevices -DeviceList $Devices
    Deploy-AllDevices -Devices $Devices -CommandDelay $CommandDelay -Parallel:$Parallel -DryRun:$DryRun
}

# -----------------------------------------------------------------
# Convenience/compat shim for the TUI: Load-Devices
# Expose a simple function that the TUI expects to load devices by path
# -----------------------------------------------------------------
function Load-Devices {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

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
Export-ModuleMember -Function Test-AllDevices, Load-Devices, Backup-DeviceConfig

# -------------------------
# Export ONLY public API
# -------------------------
Export-ModuleMember -Function `
    Invoke-DeviceDeployment, `
    Invoke-AllDeviceDeployment, `
    Load-Devices, `
    Backup-DeviceConfig
