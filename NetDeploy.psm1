<#
.SYNOPSIS
    NetDeploy - Network device configuration automation module for Cisco IOS.

.DESCRIPTION
    PowerShell module for automated deployment of network configurations to Cisco IOS
    routers and switches via SSH. Supports configuration validation, automatic backups,
    dry-run mode, and parallel deployments.

.NOTES
    Author: Nils Kelecom
    Version: 1.0.0
    Date: 2026-01-01
#>

# -------------------------
# Import required modules
# -------------------------
try {
    Import-Module Posh-SSH -ErrorAction Stop
} catch {
    Write-Warning "Posh-SSH module is required but not installed."
    Write-Warning "Install it with: Install-Module -Name Posh-SSH -Scope CurrentUser"
    throw "Missing required module: Posh-SSH"
}

# -------------------------
# Auto-load Private and Public functions
# -------------------------

# Get all function files
$PrivateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)
$PublicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)

# Dot-source all private functions (internal use only)
foreach ($import in $PrivateFunctions) {
    try {
        . $import.FullName
        Write-Verbose "Imported private function: $($import.BaseName)"
    }
    catch {
        Write-Error "Failed to import private function $($import.FullName): $_"
    }
}

# Dot-source all public functions (exported)
foreach ($import in $PublicFunctions) {
    try {
        . $import.FullName
        Write-Verbose "Imported public function: $($import.BaseName)"
    }
    catch {
        Write-Error "Failed to import public function $($import.FullName): $_"
    }
}

# Export only public functions
Export-ModuleMember -Function $PublicFunctions.BaseName

# Module loaded message
Write-Verbose "NetDeploy module loaded. Available commands: $($PublicFunctions.BaseName -join ', ')"
