<#
.SYNOPSIS
    Loads device configuration files for NetDeploy.

.DESCRIPTION
    Imports .psd1 device files, normalizes missing fields,
    attaches metadata, and outputs ready-to-validate device objects.

    Does NOT validate correctness — DeviceValidator.ps1 handles that.
    Example usage:
    $devices = Load-AllDevices -Folder 'configs/devices'
    $device = Load-DeviceByName -Folder 'configs/devices' -Name 'R1'
#>

. "$PSScriptRoot/Utils.ps1"  # fallback for legacy context

# Robustly dot-source Utils.ps1 relative to this script file
$__nd_scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$__nd_utils = Join-Path $__nd_scriptRoot 'Utils.ps1'
if (Test-Path $__nd_utils) {
    . (Resolve-Path $__nd_utils).Path
} else {
    Write-Verbose "DeviceLoader: Utils.ps1 not found at $__nd_utils"
}


# -------------------------------------------------------
# Default field templates for devices
# -------------------------------------------------------
$Global:DefaultRouterSchema = @{
    Hostname     = ""
    DeviceType   = "Router"
    ManagementIP = ""
    SSHPort      = 22

    Credentials = @{
        Username = ""
        Password = ""
    }

    Interfaces = @()

    Routing = @{
        OSPF = @{
            Enabled   = $false
            ProcessID = 1
            Networks  = @()
            PassiveInterfaces = @()
        }
    }

    NAT = @{
        Enabled = $false
        InsideInterface = ""
        OutsideInterface = ""
        InsideInterfaces = @()
        OutsideInterfaces = @()
        PAT = @{ Enabled = $false; ACLNumber = $null }
        Static = @()
        Pools = @()
    }

    DHCP = @{
        Enabled = $false
        Pools = @()
    }

    DNS = @{
        Enabled = $false
        DomainName = ""
        Domain = ""
        DNSServers = @()
        Hosts = @()
    }

    ACLs = @()
}


$Global:DefaultSwitchSchema = @{
    Hostname     = ""
    DeviceType   = "Switch"
    ManagementIP = ""
    SSHPort      = 22

    Credentials = @{
        Username = ""
        Password = ""
    }

    VLANs = @()
    Interfaces = @()
    EtherChannel = @{
        Enabled = $false
        ID = 1
        Mode = "active"
        Interfaces = @()
    }

    SVIs = @()

    ACLs = @()
    STP = @{ Mode = "pvst"; Priority = 32768 }
    DHCPRelay = @{ Enabled = $false; RelayIPs = @() }
    Logging = @{ Enabled = $false; Host = "" }
}


$Global:DefaultHostSchema = @{
    Hostname = ""
    DeviceType = "Host"

    ManagementIP = ""

    Credentials = @{
        Username = ""
        Password = ""
    }

    IP = ""
    Mask = ""
    Gateway = ""
    DNS = @()
}



# -------------------------------------------------------
# Merge user PSD1 data with defaults
# -------------------------------------------------------
function Merge-ConfigWithSchema {
    <#
    .SYNOPSIS
        Merges user-provided device configuration with default schema.
    
    .DESCRIPTION
        Recursively merges device configuration data with schema defaults.
        Fills in missing fields with default values while preserving user-provided values.
        Normalizes both hashtables and PSCustomObjects.
    
    .PARAMETER Data
        User-provided device configuration (hashtable or PSCustomObject).
    
    .PARAMETER Schema
        Default schema template (hashtable with default values).
    
    .EXAMPLE
        $merged = Merge-ConfigWithSchema -Data $userConfig -Schema $Global:DefaultRouterSchema
        
        Merges user router configuration with default router schema.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory)]
        [hashtable]$Schema
    )

    # Normalize incoming Data to a hashtable for consistent lookup
    if ($Data -is [hashtable]) {
        $dataHash = $Data
    } else {
        $dataHash = Convert-PSObjectToHashtable -Object $Data
    }

    $output = @{}

    foreach ($key in $Schema.Keys) {

        if ($dataHash.ContainsKey($key)) {
            # Recursively merge nested hashes
            if ($Schema[$key] -is [hashtable]) {
                $output[$key] = Merge-ConfigWithSchema -Data $dataHash[$key] -Schema $Schema[$key]
            }
            else {
                $output[$key] = $dataHash[$key]
            }
        }
        else {
            # Use default
            $output[$key] = $Schema[$key]
        }
    }

    return $output
}


# Convert a PSCustomObject (or object) to a plain hashtable for easier key lookup
function Convert-PSObjectToHashtable {
    <#
    .SYNOPSIS
        Converts PSCustomObject to hashtable.
    
    .DESCRIPTION
        Utility function to normalize PSCustomObject instances into hashtables
        for easier key-based lookups. Returns input unchanged if already a hashtable.
    
    .PARAMETER Object
        Object to convert (PSCustomObject, hashtable, or null).
    
    .EXAMPLE
        $hash = Convert-PSObjectToHashtable -Object $psobject
        
        Converts PowerShell custom object to hashtable.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)]
        $Object
    )

    if ($null -eq $Object) { return @{} }

    # If it's already a hashtable, return as-is
    if ($Object -is [hashtable]) { return $Object }

    $ht = @{}
    foreach ($p in $Object.PSObject.Properties) {
        $ht[$p.Name] = $p.Value
    }
    return $ht
}


# -------------------------------------------------------
# Load all devices from a single JSON file
# Expected JSON shapes supported:
# - An array of device objects: [ { Hostname: 'R1', DeviceType: 'Router', ... }, ... ]
# - An object with a top-level 'devices' array: { devices: [ ... ] }
# -------------------------------------------------------
function Load-AllDevicesFromJson {
    <#
    .SYNOPSIS
        Loads device configurations from a JSON file.
    
    .DESCRIPTION
        Parses a JSON file containing device configurations. Supports two formats:
        1. Array of devices: [{...}, {...}]
        2. Object with devices property: {devices: [{...}]}
        
        Merges each device with appropriate schema defaults (Router/Switch/Host).
        Adds metadata (SourcePath, ImportTimestamp, DeviceIndex) to each device.
        Sorts devices by deployment order (Routers → Switches → Hosts).
    
    .PARAMETER File
        Path to JSON file containing device configurations.
    
    .EXAMPLE
        $devices = Load-AllDevicesFromJson -File "configs/devices/devices.json"
        
        Loads all devices from JSON file.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$File
    )

    $absFile = Resolve-AbsolutePath $File
    if (-not (Test-Path $absFile)) { throw "JSON device file not found: $absFile" }

    Write-Log "Loading device configurations from JSON file: $absFile"

    try {
        $content = Get-Content -Path $absFile -Raw -ErrorAction Stop
        $json = ConvertFrom-Json -InputObject $content -Depth 10
    } catch {
        Write-Log -Message "Failed to parse JSON device file: $_" -Level ERROR
        throw "Failed to parse JSON device file: $absFile"
    }

    # Support both top-level array or object with 'devices' property
    if ($null -eq $json) { return @() }

    if ($json.PSObject.Properties.Name -contains 'devices') {
        $items = $json.devices
    }
    elseif ($json -is [System.Collections.IEnumerable] -and -not ($json -is [string])) {
        $items = $json
    }
    else {
        # Single device object
        $items = @($json)
    }

    $list = @()
    $index = 1

    foreach ($itm in $items) {
        # convert to hashtable for Merge logic
        $raw = Convert-PSObjectToHashtable -Object $itm

        if (-not $raw.ContainsKey('DeviceType')) {
            throw "Device entry missing DeviceType (item index $index) in $absFile"
        }

        switch ($raw.DeviceType) {
            'Router' {
                $final = Merge-ConfigWithSchema -Data $raw -Schema $Global:DefaultRouterSchema
            }
            'Switch' {
                $final = Merge-ConfigWithSchema -Data $raw -Schema $Global:DefaultSwitchSchema
            }
            'Host' {
                $final = Merge-ConfigWithSchema -Data $raw -Schema $Global:DefaultHostSchema
            }
            default {
                throw "Unknown DeviceType '$($raw.DeviceType)' in JSON file: $absFile (item $index)"
            }
        }

        $obj = [PSCustomObject]$final
        $obj | Add-Member -NotePropertyName SourcePath -NotePropertyValue $absFile
        $obj | Add-Member -NotePropertyName ImportTimestamp -NotePropertyValue (Get-Date)
        $obj | Add-Member -NotePropertyName DeviceIndex -NotePropertyValue $index

        $list += $obj
        $index++
    }

    $sorted = Sort-DevicesForDeployment -Devices $list
    Write-Log "Loaded $($sorted.Count) device configurations from JSON"
    return $sorted
}


# -------------------------------------------------------
# JSON-first device loading API
# From now on the loader expects a single JSON file (or a path to a folder
# that contains a devices.json file). PSD1-per-file support has been removed.
# -------------------------------------------------------
function Load-AllDevices {
    <#
    .SYNOPSIS
        Loads all device configurations from JSON file or directory.
    
    .DESCRIPTION
        Primary device loading function. Accepts either:
        - Path to devices.json file directly
        - Path to directory containing devices.json
        
        Automatically detects path type and delegates to Load-AllDevicesFromJson.
        PSD1-per-device files are no longer supported.
    
    .PARAMETER Folder
        Path to directory containing devices.json or path to JSON file directly.
    
    .EXAMPLE
        $devices = Load-AllDevices -Folder "configs/devices"
        
        Loads devices from configs/devices/devices.json.
    
    .EXAMPLE
        $devices = Load-AllDevices -Folder "C:\MyConfigs\custom-devices.json"
        
        Loads devices from specific JSON file.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    # Treat the incoming value as a path. It may be a file or a folder.
    $absPath = Resolve-AbsolutePath $Folder

    if (-not (Test-Path $absPath)) {
        throw "Device path not found: $absPath"
    }

    # If caller gave a directory, look for devices.json inside it
    $item = Get-Item -LiteralPath $absPath -ErrorAction Stop
    if ($item.PSIsContainer) {
        $candidate = Join-Path $absPath 'devices.json'
        if (-not (Test-Path $candidate)) {
            throw "JSON device file 'devices.json' not found in folder: $absPath. PSD1-per-device support has been removed."
        }
        return Load-AllDevicesFromJson -File $candidate
    }

    # If caller passed a file, ensure it's JSON
    if (-not $item.PSIsContainer) {
        if ($item.Extension -ne '.json') {
            throw "Unsupported device file type: $($item.Extension). Only .json is supported now."
        }
        return Load-AllDevicesFromJson -File $item.FullName
    }
}


# -------------------------------------------------------
# Load a specific device by hostname (JSON-based)
# -------------------------------------------------------
function Load-DeviceByName {
    <#
    .SYNOPSIS
        Loads a single device by hostname.
    
    .DESCRIPTION
        Loads all devices from JSON and filters for specific device by hostname.
        Throws error if device not found.
    
    .PARAMETER Folder
        Path to directory containing devices.json or path to JSON file directly.
    
    .PARAMETER Name
        Hostname of device to load.
    
    .EXAMPLE
        $router = Load-DeviceByName -Folder "configs/devices" -Name "R1"
        
        Loads configuration for router R1 only.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$Folder,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $devices = Load-AllDevices -Folder $Folder
    $match = $devices | Where-Object { $_.Hostname -eq $Name }

    if (-not $match) {
        throw "No device named '$Name' found in devices file/folder: $Folder"
    }

    return $match
}
