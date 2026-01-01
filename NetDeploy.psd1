@{
    ModuleVersion = '1.0.0'
    GUID = 'd3f0a5b8-4f12-4c7e-bf4a-9e2d7b6c5e3a'
    Author = 'Nils Kelecom'
    CompanyName = 'Personal'
    Description = 'NetDeploy – automated Cisco IOS network deployment via SSH with validation, backups, and parallel execution.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')

    RootModule = 'NetDeploy.psm1'

    # Only export public functions
    FunctionsToExport = @(
        'Invoke-DeviceDeployment',
        'Invoke-AllDeviceDeployment',
        'Load-Devices',
        'Start-NetDeployUI'
    )

    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()

    # All module files
    FileList = @(
        'NetDeploy.psm1',
        'NetDeploy.psd1',
        'Public/Invoke-DeviceDeployment.ps1',
        'Public/Invoke-AllDeviceDeployment.ps1',
        'Public/Load-Devices.ps1',
        'Public/Start-NetDeployUI.ps1',
        'Private/Utils.ps1',
        'Private/DeviceLoader.ps1',
        'Private/deviceValidator.ps1',
        'Private/CommandBuilder.ps1',
        'Private/SSHDeploy.ps1'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('Network', 'Cisco', 'SSH', 'Automation', 'IOS', 'Deployment', 'Configuration')
            LicenseUri = 'https://github.com/nilskele/NetDeploy/blob/main/LICENSE'
            ProjectUri = 'https://github.com/nilskele/NetDeploy'
            ReleaseNotes = @'
v1.0.0 - Initial Release
- Automated deployment to Cisco IOS routers and switches
- SSH key and password authentication
- Configuration validation and backups
- Parallel and sequential deployment modes
- Interactive TUI for easy usage
- Dry-run mode for safe testing
- Support for OSPF, NAT, DHCP, VLANs, and more
'@
        }
    }
}
