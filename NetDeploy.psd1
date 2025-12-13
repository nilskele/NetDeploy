@{
    ModuleVersion = '1.0.0'
    GUID = 'd3f0a5b8-4f12-4c7e-bf4a-9e2d7b6c5e3a'
    Author = 'YourName'
    CompanyName = 'YourCompany'
    Description = 'NetDeploy – automated Cisco IOS network deployment via SSH.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    RootModule = 'NetDeploy.psm1'

    FunctionsToExport = @(
        'Invoke-DeviceDeployment',
        'Invoke-AllDeviceDeployment'
    )

    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()

    FileList = @(
        'NetDeploy.psm1',
        'Utils.ps1',
        'DeviceLoader.ps1',
        'DeviceValidator.ps1',
        'CommandBuilder.ps1',
        'SSHDeploy.ps1'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('Network','Cisco','SSH','Automation')
            ReleaseNotes = 'Initial stable release'
        }
    }
}
