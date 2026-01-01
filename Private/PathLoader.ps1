########################################################################################################################
# NETDEPLOY PATHS - CENTRAL PATH CONFIGURATION
########################################################################################################################

<#
.SYNOPSIS
    Central path configuration for NetDeploy module.

.DESCRIPTION
    This file defines all paths used throughout the NetDeploy project in one place.
    All scripts and functions reference these variables. Change paths here to update the entire project.
    
    This file is dot-sourced by all core scripts automatically.
    
.NOTES
    18/12/2025 - v1.0 - Initial version - NetDeploy Project
#>

# Module root directory (auto-detected)
if (-not $script:NetDeployRoot) {
    $script:NetDeployRoot = Split-Path -Parent $PSScriptRoot
}

# -------------------------
# DIRECTORY PATHS
# -------------------------

$script:NetDeployLogsDir = Join-Path $script:NetDeployRoot 'logs'
$script:NetDeployJobsDir = Join-Path $script:NetDeployRoot 'logs/jobs'
$script:NetDeployBackupsDir = Join-Path $script:NetDeployRoot 'logs/backups'
$script:NetDeployConfigsDir = Join-Path $script:NetDeployRoot 'configs'
$script:NetDeployDevicesDir = Join-Path $script:NetDeployRoot 'configs/devices'
$script:NetDeploySchemasDir = Join-Path $script:NetDeployRoot 'schemas'
$script:NetDeployExamplesDir = Join-Path $script:NetDeployRoot 'examples'

# -------------------------
# FILE PATHS
# -------------------------

$script:NetDeployDevicesJson = Join-Path $script:NetDeployRoot 'configs/devices/devices.json'
$script:NetDeployExecutionLog = Join-Path $script:NetDeployRoot 'logs/execution.log'

# Schema files
$script:NetDeployRouterSchema = Join-Path $script:NetDeployRoot 'schemas/router-schema.psd1'
$script:NetDeploySwitchSchema = Join-Path $script:NetDeployRoot 'schemas/switch-schema.psd1'
$script:NetDeployHostSchema = Join-Path $script:NetDeployRoot 'schemas/host-schema.psd1'

# -------------------------
# CONFIGURATION DEFAULTS
# -------------------------

$script:NetDeploySSHPort = 22
$script:NetDeploySSHTimeout = 10
$script:NetDeploySSHRetries = 3
$script:NetDeployCommandDelay = 1
$script:NetDeployThrottle = 10
