function Start-NetDeployUI {
    <#
    .SYNOPSIS
        Launches the NetDeploy interactive text user interface.
    
    .DESCRIPTION
        Public API function for starting the NetDeploy TUI.
        Provides an interactive menu-driven interface for device deployment,
        backup viewing, and configuration management.
    
    .PARAMETER DevicePath
        Path to device configurations. Defaults to module's configs/devices directory.
    
    .EXAMPLE
        Start-NetDeployUI
        
        Launches TUI with default device path.
    
    .EXAMPLE
        Start-NetDeployUI -DevicePath "C:\NetworkConfigs\devices.json"
        
        Launches TUI with custom device configuration path.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [string]$DevicePath
    )

    # If no path specified, use module's default configs
    if (-not $DevicePath) {
        $moduleRoot = $PSScriptRoot | Split-Path -Parent
        $DevicePath = Join-Path $moduleRoot "configs/devices"
    }

    # Load TUI components
    $tuiPath = Join-Path ($PSScriptRoot | Split-Path -Parent) "tui"
    $menuPath = Join-Path $tuiPath "Menu.ps1"
    $selectorPath = Join-Path $tuiPath "DeviceSelector.ps1"
    $uiPath = Join-Path $tuiPath "DeploymentUI.ps1"

    if (-not (Test-Path $uiPath)) {
        Write-Error "TUI files not found. Expected at: $tuiPath"
        return
    }

    # Dot-source TUI components
    . $menuPath
    . $selectorPath
    . $uiPath

    # Launch UI
    Start-NetDeployUI -DevicePath $DevicePath
}
