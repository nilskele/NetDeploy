function Load-Devices {
    <#
    .SYNOPSIS
        Loads network device configurations from JSON or directory.
    
    .DESCRIPTION
        Public API function for loading device configurations.
        Supports loading from JSON files or directories containing PSD1 files.
        Automatically normalizes and validates loaded configurations.
    
    .PARAMETER Path
        Path to JSON file or directory containing device configurations.
    
    .EXAMPLE
        $devices = Load-Devices -Path "configs/devices/devices.json"
        
        Loads devices from JSON file.
    
    .EXAMPLE
        $devices = Load-Devices -Path "configs/devices"
        
        Loads devices from directory.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        if (Test-Path $Path -PathType Leaf) {
            # Single JSON file
            if ($Path -match '\.json$') {
                Write-Verbose "Loading devices from JSON: $Path"
                return Load-AllDevicesFromJson -JsonFile $Path
            } else {
                throw "Unsupported file format. Expected .json file."
            }
        }
        elseif (Test-Path $Path -PathType Container) {
            # Directory - check for devices.json first
            $jsonPath = Join-Path $Path "devices.json"
            if (Test-Path $jsonPath) {
                Write-Verbose "Loading devices from JSON: $jsonPath"
                return Load-AllDevicesFromJson -JsonFile $jsonPath
            } else {
                # Fall back to PSD1 files
                Write-Verbose "Loading devices from directory: $Path"
                return Load-AllDevices -Folder $Path
            }
        }
        else {
            throw "Path not found: $Path"
        }
    }
    catch {
        Write-Error "Failed to load devices from '$Path': $_"
        throw
    }
}
