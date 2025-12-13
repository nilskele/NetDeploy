<#
.SYNOPSIS
    Main deployment module for NetDeploy.

.DESCRIPTION
    Public API for loading, validating, and deploying network devices.
    Internals are hidden behind Invoke-* functions.
#>

# -------------------------
# Import internal modules
# -------------------------
. "$PSScriptRoot/Utils.ps1"
. "$PSScriptRoot/DeviceLoader.ps1"
. "$PSScriptRoot/DeviceValidator.ps1"
. "$PSScriptRoot/CommandBuilder.ps1"
. "$PSScriptRoot/SSHDeploy.ps1"

# -------------------------
# Public API
# -------------------------

function Invoke-DeviceDeployment {
    param(
        [Parameter(Mandatory)] $Device,
        [int]$CommandDelay = 0
    )

    Validate-Device -Device $Device
    Deploy-Device -Device $Device -CommandDelay $CommandDelay
}

function Invoke-AllDeviceDeployment {
    param(
        [Parameter(Mandatory)][array]$Devices,
        [int]$CommandDelay = 0,
        [switch]$Parallel
    )

    Validate-AllDevices -DeviceList $Devices
    Deploy-AllDevices -Devices $Devices -CommandDelay $CommandDelay -Parallel:$Parallel
}

# -------------------------
# Export ONLY public API
# -------------------------
Export-ModuleMember -Function `
    Invoke-DeviceDeployment, `
    Invoke-AllDeviceDeployment
